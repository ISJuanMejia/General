/*
================================================================================
  SCRIPT: Sp_Connekta_Shopify_CrearProductos
  DESCRIPCIÓN:
    Extrae productos del ERP (UnoEE) y genera el JSON necesario para crear
    productos nuevos en Shopify via API REST.

  REGLAS DE NEGOCIO:
    - Solo se traen productos que tienen al menos una variante en el ERP.
    - Si al menos una variante de un producto ya existe en la tabla [variantes]
      (productos sincronizados previamente con Shopify), el producto entero
      se omite — no se crea duplicado.
    - Se respetan los criterios de precio y plan configurados.
    - Las extensiones vacías o "NO APLICA" se ignoran.

  PARÁMETROS CONFIGURABLES (Sección "CONFIGURACIÓN"):
    @id_cia_erp             : Código de la empresa en el ERP
    @id_plan                : Plan de precios
    @id_criterio_mayor      : Criterio mayor del plan
    @IdListaPrecio          : Lista de precios a usar
    @tipo_extension_1       : Nombre de la opción 1 en Shopify (ej: "Talla")
    @tipo_extension_2       : Nombre de la opción 2 en Shopify (ej: "Color")
    @product_vendor         : Vendor por defecto para productos nuevos
    @productDefaultStatus   : Estado inicial del producto en Shopify
    @InventoryManagement    : Modo de gestión de inventario en Shopify

  TABLAS LOCALES REQUERIDAS:
    conexiones  : Cadena de conexión al ERP
    bodegas     : Mapeo bodega ERP <-> location_id Shopify
    variantes   : Variantes ya sincronizadas con Shopify (sku_erp)

  AUTOR: Connekta / Siesa S.A.S.
  VERSIÓN: 2.0
================================================================================
*/

-- ============================================================
--  SECCIÓN 1: CONFIGURACIÓN
--  Ajustar estos valores según el cliente / ambiente
-- ============================================================
DECLARE @id_cia_erp             NVARCHAR(2)     = '7';
DECLARE @product_vendor         NVARCHAR(100)   = 'Womder';          -- Vendor Shopify
DECLARE @productDefaultStatus   NVARCHAR(10)    = 'draft';           -- Siempre debe de ser 'draft' 
DECLARE @id_plan                VARCHAR(3)      = '004';             -- Plan
DECLARE @id_criterio_mayor      VARCHAR(4)      = '01';              -- Criterio mayor del plan
DECLARE @IdListaPrecio          VARCHAR(3)      = '01';             -- Lista de precios
DECLARE @tipo_extension_1       VARCHAR(50)     = 'Talla';           -- Nombre opción 1 en Shopify
DECLARE @tipo_extension_2       VARCHAR(50)     = 'Color';           -- Nombre opción 2 en Shopify
DECLARE @InventoryManagement    NVARCHAR(10)    = 'shopify';         -- Siempre 'shopify'

-- ============================================================
--  SECCIÓN 2: VARIABLES INTERNAS
-- ============================================================
DECLARE @conexion       VARCHAR(200);
DECLARE @listaBodegas   NVARCHAR(MAX);

-- ============================================================
--  SECCIÓN 3: TABLAS TEMPORALES
-- ============================================================

-- Extensiones tipo 1 (ej: Talla) del ERP
DECLARE @t117_mc_extensiones1_detalle TABLE (
    f117_id             VARCHAR(255),
    f117_descripcion    NVARCHAR(255)
);

-- Extensiones tipo 2 (ej: Color) del ERP
DECLARE @t119_mc_extensiones2_detalle TABLE (
    f119_id             VARCHAR(255),
    f119_descripcion    NVARCHAR(255)
);

-- Maestro de ítems del ERP
DECLARE @t120_mc_items TABLE (
    f120_rowid          INT,
    f120_id             NVARCHAR(255),
    f120_descripcion    NVARCHAR(255)
);

-- Combinaciones de extensiones por ítem (variantes ERP)
DECLARE @t121_mc_items_extensiones TABLE (
    f121_rowid              INT,
    f121_rowid_item         INT,
    f121_id_ext1_detalle    NVARCHAR(255),
    f121_id_ext2_detalle    NVARCHAR(255)
);

-- Ítems dentro del criterio de precio configurado
DECLARE @t125_mc_items_criterios TABLE (
    f125_rowid_item     INT
);

-- Precios vigentes por ítem / extensión
DECLARE @t126_mc_items_precios TABLE (
    f126_rowid_item             VARCHAR(10),
    f126_rowid_item_ext         VARCHAR(10),
    f126_precio                 DECIMAL(18, 2),
    f126_fecha_ts_actualizacion DATETIME
);

-- Bodegas configuradas en el ERP
DECLARE @t150_mc_bodegas TABLE (
    f150_rowid  INT,
    f150_id     VARCHAR(10)
);

-- Existencias por variante y bodega
DECLARE @t400_cm_existencia TABLE (
    f400_cant_existencia_1      DECIMAL(18, 6),
    f400_cant_comprometida_1    DECIMAL(18, 6),
    f400_cant_pos_1             DECIMAL(18, 6),
    f400_rowid_item_ext         INT,
    f400_rowid_bodega           INT
);

-- Bodegas del sistema Connekta con su location_id Shopify
DECLARE @bodegas TABLE (
    id_location BIGINT,
    bodega_erp  VARCHAR(6)
);

-- ============================================================
--  SECCIÓN 4: LÓGICA PRINCIPAL
-- ============================================================
BEGIN TRY

    -- 4.1 Obtener cadena de conexión al ERP
    SELECT TOP 1
        @conexion = cadena_conexion
    FROM conexiones;

    IF @conexion IS NULL
    BEGIN
        SELECT 'Error: No se encontró cadena de conexión en tabla [conexiones].' AS Error;
        RETURN;
    END

    -- 4.2 Cargar bodegas configuradas
    INSERT INTO @bodegas (id_location, bodega_erp)
    SELECT id_location, bodega_erp
    FROM   bodegas
    WHERE  bodega_erp IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM @bodegas)
    BEGIN
        SELECT 'Error: No hay bodegas configuradas en tabla [bodegas].' AS Error;
        RETURN;
    END

    -- Construir lista de bodegas para filtro dinámico en OPENROWSET
    SELECT @listaBodegas = STRING_AGG('''''' + bodega_erp + '''''', ',')
    FROM   @bodegas;

    -- 4.3 Cargar datos del ERP vía OPENROWSET

    -- Extensiones tipo 1 (Talla): excluir nulos y valores inválidos
    INSERT INTO @t117_mc_extensiones1_detalle (f117_id, f117_descripcion)
    EXEC('
        SELECT f117_id, f117_descripcion = TRIM(f117_descripcion)
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT f117_id, f117_descripcion
                FROM   t117_mc_extensiones1_detalle
                WHERE  f117_id_cia         =   ' + @id_cia_erp + '
                  AND  f117_descripcion    IS NOT NULL
                  AND  f117_descripcion    <>  ''''''''
            ''
        )
    ');

    -- Extensiones tipo 2 (Color): misma lógica
    INSERT INTO @t119_mc_extensiones2_detalle (f119_id, f119_descripcion)
    EXEC('
        SELECT f119_id, f119_descripcion = TRIM(f119_descripcion)
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT f119_id, f119_descripcion
                FROM   t119_mc_extensiones2_detalle
                WHERE  f119_id_cia         =   ' + @id_cia_erp + '
                  AND  f119_descripcion    IS NOT NULL
                  AND  f119_descripcion    <>  ''''''''
            ''
        )
    ');

    -- Maestro de ítems
    INSERT INTO @t120_mc_items (f120_rowid, f120_id, f120_descripcion)
    EXEC('
        SELECT f120_rowid, f120_id, f120_descripcion
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT f120_rowid, f120_id, f120_descripcion
                FROM   t120_mc_items
                WHERE  f120_id_cia = ' + @id_cia_erp + '
            ''
        )
    ');

    -- Combinaciones de extensiones (variantes ERP)
    INSERT INTO @t121_mc_items_extensiones (f121_rowid, f121_rowid_item, f121_id_ext1_detalle, f121_id_ext2_detalle)
    EXEC('
        SELECT f121_rowid, f121_rowid_item,
               f121_id_ext1_detalle = TRIM(f121_id_ext1_detalle),
               f121_id_ext2_detalle = TRIM(f121_id_ext2_detalle)
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT f121_rowid, f121_rowid_item,
                       f121_id_ext1_detalle, f121_id_ext2_detalle
                FROM   t121_mc_items_extensiones
                WHERE  f121_id_cia = ' + @id_cia_erp + '
            ''
        )
    ');

    -- Ítems dentro del criterio de precio
    INSERT INTO @t125_mc_items_criterios (f125_rowid_item)
    EXEC('
        SELECT f125_rowid_item
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT f125_rowid_item
                FROM   t125_mc_items_criterios
                WHERE  f125_id_cia            =   ' + @id_cia_erp + '
                  AND  f125_id_plan           =   ''''' + @id_plan + '''''
                  AND  f125_id_criterio_mayor =   ''''' + @id_criterio_mayor + '''''
            ''
        )
    ');

    -- Precios: precio más reciente por ítem/extensión
    INSERT INTO @t126_mc_items_precios (f126_rowid_item, f126_rowid_item_ext, f126_precio, f126_fecha_ts_actualizacion)
    EXEC('
        SELECT f126_rowid_item, f126_rowid_item_ext, f126_precio, f126_fecha_ts_actualizacion
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT f126_rowid_item, f126_rowid_item_ext, f126_precio, f126_fecha_ts_actualizacion
                FROM   t126_mc_items_precios
                WHERE  f126_id_cia       =   ' + @id_cia_erp + '
                  AND  f126_id_lista_precio     =   ''''' + @IdListaPrecio + '''''
            ''
        )
    ');

    -- Bodegas ERP (solo las que están en la configuración de bodegas)
    INSERT INTO @t150_mc_bodegas (f150_rowid, f150_id)
    EXEC('
        SELECT f150_rowid, f150_id
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT f150_rowid, f150_id
                FROM   t150_mc_bodegas
                WHERE  f150_id_cia =   ' + @id_cia_erp + '
                  AND  f150_id     IN  (' + @listaBodegas + ')
            ''
        )
    ');

    -- Existencias
    INSERT INTO @t400_cm_existencia (f400_cant_existencia_1, f400_cant_comprometida_1, f400_cant_pos_1, f400_rowid_item_ext, f400_rowid_bodega)
    EXEC('
        SELECT
            f400_cant_existencia_1      = CONVERT(INT, f400_cant_existencia_1),
            f400_cant_comprometida_1    = CONVERT(INT, f400_cant_comprometida_1),
            f400_cant_pos_1             = CONVERT(INT, f400_cant_pos_1),
            f400_rowid_item_ext,
            f400_rowid_bodega
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT f400_cant_existencia_1, f400_cant_comprometida_1,
                       f400_cant_pos_1, f400_rowid_item_ext, f400_rowid_bodega
                FROM   t400_cm_existencia
                WHERE  f400_id_cia = ' + @id_cia_erp + '
            ''
        )
    ');

    -- ============================================================
    --  SECCIÓN 5: FILTRADO DE PRODUCTOS ELEGIBLES
    --
    --  Reglas aplicadas:
    --    R1: El ítem debe estar en el criterio de precio configurado.
    --    R2: El ítem debe tener al menos una variante válida en @t121
    --        (con extensiones que existan en @t117 y @t119).
    --    R3: Si CUALQUIER variante del producto ya existe en [variantes]
    --        (tabla Shopify), el producto completo se excluye.
    -- ============================================================

    -- Helper: SKU compuesto de cada variante (f120_id + ext1 + ext2)
    -- Se usa en múltiples lugares; centralizado aquí para mantenibilidad.
    -- Formato: "ITEM-EXT1-EXT2" | "ITEM-EXT1" | "ITEM-EXT2" | "ITEM"

    -- Productos que cumplen R1, R2 y R3
    -- Nota: usamos EXISTS / NOT EXISTS para eficiencia (short-circuit)
    DECLARE @productos_elegibles TABLE (
        f120_rowid          INT,
        f120_id             NVARCHAR(255),
        f120_descripcion    NVARCHAR(255)
    );

    INSERT INTO @productos_elegibles (f120_rowid, f120_id, f120_descripcion)
    SELECT
        t120.f120_rowid,
        t120.f120_id,
        t120.f120_descripcion
    FROM @t120_mc_items AS t120
    -- R1: Debe estar en el plan/criterio de precio
    WHERE EXISTS (
        SELECT 1 FROM @t125_mc_items_criterios
        WHERE  f125_rowid_item = t120.f120_rowid
    )
    -- R2: Debe tener al menos una variante con extensiones válidas
    AND EXISTS (
        SELECT 1
        FROM   @t121_mc_items_extensiones   AS t121
            INNER JOIN @t117_mc_extensiones1_detalle AS t117 ON t117.f117_id = t121.f121_id_ext1_detalle
            INNER JOIN @t119_mc_extensiones2_detalle AS t119 ON t119.f119_id = t121.f121_id_ext2_detalle
        WHERE  t121.f121_rowid_item = t120.f120_rowid
    )
    -- R3: Ninguna variante del producto debe existir ya en Shopify
    AND NOT EXISTS (
        SELECT 1
        FROM   @t121_mc_items_extensiones AS t121
            INNER JOIN variantes AS v
                ON v.sku_erp = t120.f120_id
                    + CASE WHEN t121.f121_id_ext1_detalle IS NOT NULL THEN '-' + t121.f121_id_ext1_detalle ELSE '' END
                    + CASE WHEN t121.f121_id_ext2_detalle IS NOT NULL THEN '-' + t121.f121_id_ext2_detalle ELSE '' END
                    OR
                    v.sku_erp LIKE '%'+t120.f120_id+'%'
        WHERE  t121.f121_rowid_item = t120.f120_rowid
    );

    -- ============================================================
    --  SECCIÓN 6: GENERACIÓN DEL JSON DE PRODUCTOS PARA SHOPIFY
    -- ============================================================

    SELECT
        ProductJSON = JSON_QUERY(
            (
                SELECT
                    -- Campos del producto
                    [product.title]     = t120.f120_descripcion,
                    [product.body_html] = t120.f120_descripcion,
                    [product.vendor]    = @product_vendor,
                    [product.status]    = @productDefaultStatus,

                    -- Variantes: una por cada combinación ext1 + ext2 no existente en Shopify
                    [product.variants]  = (
                        SELECT DISTINCT
                            [option1]   = TRIM(t117.f117_id),
                            [option2]   = t119.f119_descripcion,
                            -- Precio: registro más reciente; TOP 1 garantiza escalar único
                            [price]     = (
                                SELECT TOP 1
                                    p.f126_precio
                                FROM @t126_mc_items_precios AS p
                                WHERE (
                                    p.f126_rowid_item     = CAST(t120.f120_rowid AS VARCHAR(10))
                                    OR
                                    p.f126_rowid_item_ext = CAST(t121v.f121_rowid AS VARCHAR(10))
                                )
                                ORDER BY p.f126_fecha_ts_actualizacion DESC
                            ),
                            -- SKU completo de la variante: ITEM-EXT1-EXT2
                            [sku]       = t120.f120_id
                                            + CASE WHEN t121v.f121_id_ext1_detalle IS NOT NULL THEN '-' + t121v.f121_id_ext1_detalle ELSE '' END
                                            + CASE WHEN t121v.f121_id_ext2_detalle IS NOT NULL THEN '-' + t121v.f121_id_ext2_detalle ELSE '' END,
                            [barcode]   = t120.f120_id,
                            [inventory_management] = @InventoryManagement
                        FROM @t121_mc_items_extensiones AS t121v
                            INNER JOIN @t117_mc_extensiones1_detalle AS t117 ON t117.f117_id = t121v.f121_id_ext1_detalle
                            INNER JOIN @t119_mc_extensiones2_detalle AS t119 ON t119.f119_id = t121v.f121_id_ext2_detalle
                            -- Confirmación adicional: esta variante específica no existe
                            LEFT  JOIN variantes AS v
                                ON v.sku_erp = t120.f120_id
                                    + CASE WHEN t121v.f121_id_ext1_detalle IS NOT NULL THEN '-' + t121v.f121_id_ext1_detalle ELSE '' END
                                    + CASE WHEN t121v.f121_id_ext2_detalle IS NOT NULL THEN '-' + t121v.f121_id_ext2_detalle ELSE '' END
                                    OR
                                    v.sku_erp LIKE '%'+t120.f120_id+'%'
                        WHERE
                            t121v.f121_rowid_item = t120.f120_rowid
                            AND v.sku_erp IS NULL
                        FOR JSON PATH
                    ),

                    -- Opciones agrupadas (para el objeto product.options de Shopify)
                    [product.options]   = (
                        SELECT
                            [name],
                            JSON_QUERY('[' + STRING_AGG('"' + STRING_ESCAPE([values], 'json') + '"', ',') + ']') AS [values],
                            position
                        FROM (
                            -- Opción 1: valores únicos de ext1 para este producto
                            SELECT DISTINCT
                                [name]      =   @tipo_extension_1,
                                [values]    =   TRIM(t117.f117_id),
                                [position]  =   1
                            FROM @t121_mc_items_extensiones AS t121e1
                                INNER JOIN @t117_mc_extensiones1_detalle AS t117 ON t117.f117_id = t121e1.f121_id_ext1_detalle
                                INNER JOIN @t119_mc_extensiones2_detalle AS t119 ON t119.f119_id = t121e1.f121_id_ext2_detalle
                                LEFT  JOIN variantes AS v
                                    ON v.sku_erp = t120.f120_id
                                        + CASE WHEN t121e1.f121_id_ext1_detalle IS NOT NULL THEN '-' + t121e1.f121_id_ext1_detalle ELSE '' END
                                        + CASE WHEN t121e1.f121_id_ext2_detalle IS NOT NULL THEN '-' + t121e1.f121_id_ext2_detalle ELSE '' END
                                        OR
                                        v.sku_erp LIKE '%'+t120.f120_id+'%'
                            WHERE t121e1.f121_rowid_item = t120.f120_rowid AND v.sku_erp IS NULL

                            UNION ALL

                            -- Opción 2: valores únicos de ext2 para este producto
                            SELECT DISTINCT
                                [name]      =   @tipo_extension_2,
                                [values]    =   t119.f119_descripcion,
                                [position]  =   2
                            FROM @t121_mc_items_extensiones AS t121e2
                                INNER JOIN @t117_mc_extensiones1_detalle AS t117 ON t117.f117_id = t121e2.f121_id_ext1_detalle
                                INNER JOIN @t119_mc_extensiones2_detalle AS t119 ON t119.f119_id = t121e2.f121_id_ext2_detalle
                                LEFT  JOIN variantes AS v
                                    ON v.sku_erp = t120.f120_id
                                        + CASE WHEN t121e2.f121_id_ext1_detalle IS NOT NULL THEN '-' + t121e2.f121_id_ext1_detalle ELSE '' END
                                        + CASE WHEN t121e2.f121_id_ext2_detalle IS NOT NULL THEN '-' + t121e2.f121_id_ext2_detalle ELSE '' END
                                        OR
                                        v.sku_erp LIKE '%'+t120.f120_id+'%'
                            WHERE t121e2.f121_rowid_item = t120.f120_rowid AND v.sku_erp IS NULL
                        ) AS options_union
                        GROUP BY [name], [position]
                        FOR JSON PATH
                    )

                FOR JSON PATH
            )
        )
    FROM @productos_elegibles AS t120;
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER()      AS ErrorNumero,
        ERROR_SEVERITY()    AS ErrorSeveridad,
        ERROR_STATE()       AS ErrorEstado,
        ERROR_PROCEDURE()   AS ErrorProcedimiento,
        ERROR_LINE()        AS ErrorLinea,
        ERROR_MESSAGE()     AS ErrorMensaje;
END CATCH;