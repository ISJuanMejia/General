/* =============================================================================
   SCRIPT  : sync_precios_siesa_shopify.sql
   MÓDULO  : Sincronización de precios ERP Siesa → Shopify

   DESCRIPCIÓN:
       Extrae los precios vigentes desde el ERP Siesa (vía OPENROWSET) y los
       consolida en la tabla local [dbo.precios], que luego es consumida por
       el proceso de sincronización hacia Shopify.

       El precio se toma de la lista de precios base configurada (@id_lista_precios_base)
       y se selecciona el registro más reciente por extensión o por ítem, según el modo.

       Soporta dos modos de operación según la configuración del catálogo en Siesa:

           Modo 1 — Con extensiones de ítem:
               El precio se vincula a nivel de extensión (f126_rowid_item_ext → t121).
               El barcode se resuelve desde f121_id_barras_principal.
               Usar cuando el cliente maneja tallas, colores u otras variantes
               con extensiones registradas en t121.

           Modo 2 — Sin extensiones de ítem:
               El precio se vincula a nivel de ítem base (f126_rowid_item → t120).
               El barcode se resuelve desde f120_referencia, sin pasar por t121.
               Usar cuando el cliente no maneja extensiones y el código de barras
               está registrado directamente en el campo referencia del ítem.

       Opcionalmente soporta clasificación por planes y criterios de Siesa
       para filtrar solo los ítems que pertenecen a un plan/criterio específico.

   PARÁMETROS DE CONFIGURACIÓN:
       @modo                       TINYINT
           1 = Con extensiones de ítem  (precio por f126_rowid_item_ext)
           2 = Sin extensiones de ítem  (precio por f126_rowid_item)

       @tiene_planes_y_criterios   BIT
           0 = No filtrar por plan/criterio  (default)
           1 = Filtrar usando @id_plan y @id_criterio_mayor

       @id_lista_precios_base      VARCHAR(3)
           Código de la lista de precios en Siesa (ej: 'LP1')

       @id_cia_erp                 INT
           ID de la compañía en Siesa

       @id_plan                    VARCHAR(3)   -- Solo si @tiene_planes_y_criterios = 1
       @id_criterio_mayor          VARCHAR(4)   -- Solo si @tiene_planes_y_criterios = 1

   TABLAS LOCALES REQUERIDAS:
       - conexiones    : cadena de conexión al ERP Siesa
       - variantes     : catálogo de variantes activas en Shopify (contiene sku_erp e id_variante)
       - dbo.precios   : tabla destino del MERGE

   TABLAS ERP (vía OPENROWSET):
       - t120_mc_items                 : maestro de ítems
       - t121_mc_items_extensiones     : extensiones de ítems (variantes)
       - t125_mc_items_criterios       : clasificación por planes y criterios (opcional)
       - t126_mc_items_precios         : precios por lista, ítem y extensión

   NOTAS:
       - El MERGE actualiza precios solo cuando el objeto JSON cambia.
       - Se marca sincronizado = 0 para que el proceso de Shopify lo envíe.
       - El campo compare_at_price de Shopify recibe el precio del ERP.

   AUTOR   : Integración Siesa–Shopify
   FECHA   : 2025
============================================================================= */

/* ---------------------------------------------------------------------------
   PARÁMETROS PRINCIPALES
   Ajustar según la configuración de cada cliente.
--------------------------------------------------------------------------- */
DECLARE @modo                       TINYINT     = 1;    -- 1: con extensiones | 2: sin extensiones
DECLARE @tiene_planes_y_criterios   BIT         = 0;    -- 0: sin filtro | 1: filtrar por plan/criterio
DECLARE @id_lista_precios_base      VARCHAR(3)  = '001';
DECLARE @id_cia_erp                 INT         = 1;

/*
   Habilitar y configurar solo si @tiene_planes_y_criterios = 1:

DECLARE @id_plan            VARCHAR(3) = '010';
DECLARE @id_criterio_mayor  VARCHAR(4) = '0001';
*/

/* ---------------------------------------------------------------------------
   VARIABLES INTERNAS
--------------------------------------------------------------------------- */
DECLARE @conexion   VARCHAR(200),
        @bd         VARCHAR(200);

/* ---------------------------------------------------------------------------
   TABLA DESTINO INTERMEDIA
   Acumula el resultado final antes de ejecutar el MERGE.
--------------------------------------------------------------------------- */
DECLARE @final TABLE
(
    id_variante VARCHAR(50),
    sku_erp     VARCHAR(50),
    precio_obj  VARCHAR(MAX)
);

/* ---------------------------------------------------------------------------
   TABLAS TEMPORALES — ERP Siesa
   Se cargan mediante OPENROWSET desde el servidor ERP remoto.
--------------------------------------------------------------------------- */

-- Maestro de ítems — necesario en Modo 2 para llegar al precio por ítem base.
-- En Modo 1 también se carga porque el join t120→t121 es necesario para
-- resolver el barcode cuando el precio está a nivel de extensión.
DECLARE @t120_mc_items TABLE
(
    f120_id          VARCHAR(10),
    f120_rowid       VARCHAR(10),
    f120_descripcion VARCHAR(50),
    f120_referencia  VARCHAR(50)
);

-- Extensiones de ítems — contiene el barcode principal de cada variante.
-- Se usa en ambos modos para resolver f121_id_barras_principal → sku_erp.
DECLARE @t121_mc_items_extensiones TABLE
(
    f121_rowid               VARCHAR(10),
    f121_rowid_item          VARCHAR(10),
    f121_id_barras_principal VARCHAR(50)
);

-- Clasificación por planes y criterios — solo se carga si @tiene_planes_y_criterios = 1.
-- Permite filtrar únicamente los ítems que pertenecen a un plan/criterio específico.
DECLARE @t125_mc_items_criterios TABLE
(
    f125_id_plan           NVARCHAR(3),
    f125_id_criterio_mayor NVARCHAR(4),
    f125_rowid_item        VARCHAR(10)
);

-- Precios por lista — se trae solo el precio vigente (más reciente) por extensión o ítem.
-- La subquery en el OPENROWSET aplica ROW_NUMBER() para quedarse con el último registro.
DECLARE @t126_mc_items_precios TABLE
(
    f126_fecha_activacion DATETIME,
    f126_rowid_item       VARCHAR(10),
    f126_rowid_item_ext   VARCHAR(10),
    f126_precio           DECIMAL(18, 2)
);

/* ---------------------------------------------------------------------------
   EJECUCIÓN PRINCIPAL
--------------------------------------------------------------------------- */
BEGIN TRY

    -- Obtener cadena de conexión al ERP
    SELECT TOP 1
        @conexion   =   cadena_conexion,
        @bd         =   base_datos
    FROM conexiones;

    /* -----------------------------------------------------------------------
       CARGA DESDE ERP — Maestro de ítems (ambos modos)
       Se necesita en Modo 1 para resolver el join t120→t121→barcode,
       y en Modo 2 para vincular el precio directamente al ítem base.
    ----------------------------------------------------------------------- */
    INSERT INTO @t120_mc_items (f120_id, f120_rowid, f120_descripcion, f120_referencia)
    EXEC('
        SELECT
            f120_id,
            f120_rowid,
            f120_descripcion,
            f120_referencia
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f120_id,
                    f120_rowid,
                    f120_descripcion,
                    f120_referencia
                FROM ' + @bd + '.dbo.t120_mc_items
                WHERE
                    f120_id_cia = ' + @id_cia_erp + '
            ''
        )
    ');

    /* -----------------------------------------------------------------------
       CARGA DESDE ERP — Extensiones de ítems (ambos modos)
       Vincula el ítem base con sus variantes y expone el barcode principal
       de cada extensión, que es el SKU usado en Shopify.
    ----------------------------------------------------------------------- */
    INSERT INTO @t121_mc_items_extensiones (f121_rowid, f121_rowid_item, f121_id_barras_principal)
    EXEC('
        SELECT
            f121_rowid,
            f121_rowid_item,
            f121_id_barras_principal
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f121_rowid,
                    f121_rowid_item,
                    f121_id_barras_principal
                FROM ' + @bd + '.dbo.t121_mc_items_extensiones
                WHERE
                    f121_id_cia = ' + @id_cia_erp + '
            ''
        )
    ');

    /* -----------------------------------------------------------------------
       CARGA DESDE ERP — Planes y criterios (condicional)
       Solo se ejecuta si @tiene_planes_y_criterios = 1.
       Filtra los ítems que pertenecen al plan y criterio configurados,
       permitiendo sincronizar solo un subconjunto del catálogo.
       
       Para activar: descomentar @id_plan y @id_criterio_mayor arriba
       y cambiar @tiene_planes_y_criterios = 1.
    ----------------------------------------------------------------------- */
    IF @tiene_planes_y_criterios = 1
    BEGIN
        INSERT INTO @t125_mc_items_criterios (f125_id_plan, f125_id_criterio_mayor, f125_rowid_item)
        EXEC('
            SELECT DISTINCT
                f125_id_plan,
                f125_id_criterio_mayor,
                f125_rowid_item
            FROM OPENROWSET(
                ''SQLNCLI'',
                ''' + @conexion + ''',
                ''
                    SELECT DISTINCT
                        f125_id_plan,
                        f125_id_criterio_mayor,
                        f125_rowid_item
                    FROM ' + @bd + '.dbo.t125_mc_items_criterios
                    WHERE
                        f125_id_cia = ' + @id_cia_erp + '
                ''
            )
        ');
        /*
           NOTA: Los parámetros @id_plan y @id_criterio_mayor se aplican
           en el INSERT INTO @final más abajo, dentro del JOIN condicional,
           no en el OPENROWSET, para mantener la lógica centralizada.
        */
    END;

    /* -----------------------------------------------------------------------
       CARGA DESDE ERP — Precios vigentes por lista (ambos modos)
       
       Se trae solo el precio más reciente usando ROW_NUMBER():
           Modo 1: partición por f126_rowid_item_ext (precio por extensión)
           Modo 2: partición por f126_rowid_item     (precio por ítem base)
       
       Se aplica filtro por lista de precios (@id_lista_precios_base)
       y por compañía (@id_cia_erp) directamente en el ERP para reducir
       el volumen de datos transferidos por OPENROWSET.
    ----------------------------------------------------------------------- */
    INSERT INTO @t126_mc_items_precios (f126_fecha_activacion, f126_rowid_item, f126_rowid_item_ext, f126_precio)
    EXEC('
        SELECT
            f126_fecha_activacion,
            f126_rowid_item,
            f126_rowid_item_ext,
            f126_precio
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f126_fecha_activacion,
                    f126_rowid_item,
                    f126_rowid_item_ext,
                    f126_precio
                FROM (
                    SELECT
                        f126_fecha_activacion,
                        f126_rowid_item,
                        f126_rowid_item_ext,
                        f126_precio,
                        ROW_NUMBER() OVER (
                            PARTITION BY
                                CASE
                                    WHEN f126_rowid_item_ext IS NOT NULL THEN f126_rowid_item_ext
                                    ELSE f126_rowid_item
                                END
                            ORDER BY f126_fecha_activacion DESC
                        ) AS rn
                    FROM ' + @bd + '.dbo.t126_mc_items_precios
                    WHERE
                        f126_id_lista_precio = ''''' + @id_lista_precios_base + '''''
                        AND f126_id_cia = ' + @id_cia_erp + '
                ) AS precios_vigentes
                WHERE rn = 1
            ''
        )
    ');

    /* -----------------------------------------------------------------------
       CONSTRUCCIÓN DEL RESULTADO FINAL
       
       Modo 1 — precio vinculado a extensión (f126_rowid_item_ext → f121_rowid):
           t126 → t121 → variantes
           El barcode es f121_id_barras_principal.
       
       Modo 2 — precio vinculado a ítem base (f126_rowid_item → f120_rowid):
           t126 → t120 → t121 → variantes
           El barcode también es f121_id_barras_principal pero se llega
           a través del ítem base.
       
       En ambos modos se aplica el filtro de planes/criterios si corresponde.
       
       Se usa DISTINCT para evitar duplicados en caso de que el mismo
       ítem tenga precio a nivel de extensión y de ítem base simultáneamente.
    ----------------------------------------------------------------------- */
    INSERT INTO @final (id_variante, sku_erp, precio_obj)
    SELECT DISTINCT
        v.id_variante,
        v.sku_erp,
        precio_obj = (
            SELECT
                v.id_variante   AS [variant.id],
                p.f126_precio   AS [variant.compare_at_price]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    FROM @t126_mc_items_precios p

    -- ── Modo 1: precio por extensión ──────────────────────────────────────
    INNER JOIN @t121_mc_items_extensiones ext1
        ON @modo = 1
        AND p.f126_rowid_item_ext = ext1.f121_rowid

    INNER JOIN variantes v
        ON @modo = 1
        AND v.sku_erp = ext1.f121_id_barras_principal

    -- Filtro opcional por plan/criterio (Modo 1)
    LEFT JOIN @t125_mc_items_criterios crit1
        ON @tiene_planes_y_criterios = 1
        AND crit1.f125_rowid_item = ext1.f121_rowid_item

    WHERE
        @modo = 1
        AND ext1.f121_rowid IS NOT NULL
        AND (
            @tiene_planes_y_criterios = 0
            OR crit1.f125_rowid_item IS NOT NULL
        )

    UNION

    SELECT DISTINCT
        v.id_variante,
        v.sku_erp,
        precio_obj = (
            SELECT
                v.id_variante   AS [variant.id],
                p.f126_precio   AS [variant.compare_at_price]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    FROM @t126_mc_items_precios p

    -- ── Modo 2: precio por ítem base, barcode desde f120_referencia ───────
    -- No se necesita t121 porque el barcode está directamente en t120.
    INNER JOIN @t120_mc_items item
        ON @modo = 2
        AND p.f126_rowid_item = item.f120_rowid

    INNER JOIN variantes v
        ON @modo = 2
        AND v.sku_erp = item.f120_referencia

    -- Filtro opcional por plan/criterio (Modo 2)
    LEFT JOIN @t125_mc_items_criterios crit2
        ON @tiene_planes_y_criterios = 1
        AND crit2.f125_rowid_item = item.f120_rowid

    WHERE
        @modo = 2
        AND item.f120_rowid IS NOT NULL
        AND item.f120_referencia IS NOT NULL
        AND (
            @tiene_planes_y_criterios = 0
            OR crit2.f125_rowid_item IS NOT NULL
        );

    /* -----------------------------------------------------------------------
       MERGE HACIA dbo.precios

       MATCHED + precio_obj diferente → UPDATE
           Marca como pendiente de sincronización (sincronizado = 0)
           y actualiza el objeto JSON con el nuevo precio.

       NOT MATCHED BY TARGET → INSERT
           Registra el precio por primera vez con sincronizado = 0
           para que el proceso de Shopify lo envíe en la próxima ejecución.

       El objeto precio_obj sigue el formato requerido por la API:
           { "variant": { "id": ..., "compare_at_price": ... } }
    ----------------------------------------------------------------------- */
    MERGE INTO dbo.precios AS TARGET
    USING (
        SELECT
            id_variante,
            sku_erp,
            precio_obj
        FROM @final
    ) AS source
        ON target.id_variante = source.id_variante

    WHEN MATCHED
        AND target.precio_obj <> source.precio_obj
        THEN UPDATE SET
            target.precio_obj           = source.precio_obj,
            target.sincronizado         = 0,
            target.fecha_sincronizacion = NULL

    WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            id_variante,
            sku_erp,
            precio_obj,
            sincronizado,
            fecha_sincronizacion
        )
        VALUES (
            source.id_variante,
            source.sku_erp,
            source.precio_obj,
            0,
            NULL
        );

END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() AS Error;
END CATCH;