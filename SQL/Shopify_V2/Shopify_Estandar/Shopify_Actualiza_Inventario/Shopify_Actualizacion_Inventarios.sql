/* =============================================================================
   SCRIPT : sync_inventario_siesa_shopify.sql
   MÓDULO : Sincronización de inventario ERP Siesa → Shopify
   
   DESCRIPCIÓN:
       Extrae las existencias disponibles desde el ERP Siesa (vía OPENROWSET)
       y las consolida en la tabla local [dbo.inventarios], que luego es
       consumida por el proceso de sincronización hacia Shopify.
       
       El cálculo de disponibilidad es:
           disponible = existencia - (comprometido + POS)
       
       Soporta dos modos de operación según la configuración del catálogo
       de productos en Siesa:
       
           Modo 1 — Con extensiones de ítem:
               El barcode/SKU se toma de [t120_mc_items.f120_referencia].
               Se requiere que cada ítem tenga su extensión registrada en
               [t121_mc_items_extensiones].
               Usar cuando el cliente maneja tallas, colores u otras
               variantes con extensiones.
               
           Modo 2 — Sin extensiones de ítem:
               El barcode/SKU se toma de [t121_mc_items_extensiones]
               directamente, usando f121_id_barras_principal o f131_id
               como fallback.
               Usar cuando el cliente no maneja extensiones de ítem y
               el código de barras está directamente en la extensión
               o en la tabla de barras.

   PARÁMETRO DE CONFIGURACIÓN:
       @modo TINYINT
           1 = Con extensiones  (default)
           2 = Sin extensiones

   TABLAS LOCALES REQUERIDAS:
       - conexiones                    : cadena de conexión al ERP Siesa
       - bodegas                       : mapeo id_location (Shopify) ↔ bodega_erp (Siesa)
       - inventario_bodega_ecommerce   : catálogo de variantes activas en Shopify
       - dbo.inventarios               : tabla destino del MERGE

   TABLAS ERP (vía OPENROWSET):
       - t120_mc_items                 : maestro de ítems              (solo Modo 1)
       - t121_mc_items_extensiones     : extensiones de ítems
       - t131_mc_items_barras          : códigos de barras por bodega
       - t150_mc_bodegas               : maestro de bodegas
       - t400_cm_existencia            : existencias y compromisos

   AUTOR  : Juan Camilo Mejía Echavarría
   FECHA  : 12-03-2026
============================================================================= */

/* ---------------------------------------------------------------------------
   PARÁMETRO PRINCIPAL
   Cambiar @modo según la configuración del cliente:
       1 = El SKU viene de t120_mc_items (con extensiones de ítem)
       2 = El SKU viene de t121/t131     (sin extensiones de ítem)
--------------------------------------------------------------------------- */
DECLARE @modo TINYINT = 2;

/* ---------------------------------------------------------------------------
   VARIABLES INTERNAS
--------------------------------------------------------------------------- */
DECLARE @conexion       VARCHAR(200);
DECLARE @listaBodegas   NVARCHAR(MAX);

/* ---------------------------------------------------------------------------
   TABLAS TEMPORALES — ERP Siesa
   Se cargan mediante OPENROWSET desde el servidor ERP remoto.
--------------------------------------------------------------------------- */

-- Maestro de ítems (solo se carga en Modo 1)
DECLARE @t120_mc_items TABLE
(
    f120_rowid      INT,
    f120_referencia NVARCHAR(255)
);

-- Extensiones de ítems (variantes: talla, color, etc.)
DECLARE @t121_mc_items_extensiones TABLE
(
    f121_rowid                  INT,
    f121_rowid_item             INT,
    f121_id_barras_principal    VARCHAR(20)
);

-- Códigos de barras asociados a extensiones y bodegas
DECLARE @t131_mc_items_barras TABLE
(
    f131_id             VARCHAR(20),
    f131_rowid_item_ext INT,
    f131_rowid_bodega   INT
);

-- Maestro de bodegas (filtrado por las bodegas configuradas)
DECLARE @t150_mc_bodegas TABLE
(
    f150_rowid  INT,
    f150_id     VARCHAR(10),
    f150_id_cia INT
);

-- Existencias, comprometidos y reservas POS
DECLARE @t400_cm_existencia TABLE
(
    f400_cant_existencia_1      DECIMAL(18,6),
    f400_cant_comprometida_1    DECIMAL(18,6),
    f400_cant_pos_1             DECIMAL(18,6),
    f400_rowid_item_ext         INT,
    f400_rowid_bodega           INT,
    f400_id_cia                 INT
);

/* ---------------------------------------------------------------------------
   EJECUCIÓN PRINCIPAL
--------------------------------------------------------------------------- */
BEGIN TRY

    -- Obtener cadena de conexión al ERP
    SELECT TOP 1
        @conexion = cadena_conexion
    FROM conexiones;

    -- Cargar mapeo de bodegas configuradas
    DECLARE @bodegas TABLE
    (
        id_location BIGINT,
        bodega_erp  VARCHAR(6)
    );

    INSERT INTO @bodegas
    SELECT
        id_location,
        bodega_erp
    FROM bodegas
    WHERE bodega_erp IS NOT NULL;

    -- Validar que haya bodegas configuradas antes de continuar
    IF NOT EXISTS (SELECT id_location FROM @bodegas)
    BEGIN
        SELECT 'No hay bodegas configuradas.' AS mensaje;
        RETURN;
    END;

    -- Construir lista de bodegas para filtrar en OPENROWSET
    SELECT
        @listaBodegas = STRING_AGG('''' + bodega_erp + '''', ',')
    FROM @bodegas;

    /* -----------------------------------------------------------------------
       CARGA DESDE ERP — Modo 1: con extensiones de ítem
       Solo se ejecuta si @modo = 1. Trae el maestro de ítems (t120)
       que contiene la referencia usada como SKU en Shopify.
    ----------------------------------------------------------------------- */
    IF @modo = 1
    BEGIN
        INSERT INTO @t120_mc_items
        EXEC('
            SELECT
                f120_rowid,
                f120_referencia
            FROM OPENROWSET(
                ''sqlncli'',
                ''' + @conexion + ''',
                ''
                    SELECT
                        f120_rowid,
                        f120_referencia
                    FROM t120_mc_items
                ''
            )
        ');
    END;

    /* -----------------------------------------------------------------------
       CARGA DESDE ERP — Extensiones de ítems (ambos modos)
       Contiene el vínculo entre el ítem base y sus variantes,
       así como el código de barras principal de cada extensión.
    ----------------------------------------------------------------------- */
    INSERT INTO @t121_mc_items_extensiones
    EXEC('
        SELECT
            f121_rowid,
            f121_rowid_item,
            f121_id_barras_principal
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f121_rowid,
                    f121_rowid_item,
                    f121_id_barras_principal
                FROM t121_mc_items_extensiones
            ''
        )
    ');

    /* -----------------------------------------------------------------------
       CARGA DESDE ERP — Códigos de barras por bodega (ambos modos)
       Permite obtener el código de barras asociado a cada extensión
       en una bodega específica como alternativa a f121_id_barras_principal.
    ----------------------------------------------------------------------- */
    INSERT INTO @t131_mc_items_barras
    EXEC('
        SELECT
            f131_id,
            f131_rowid_item_ext,
            f131_rowid_bodega
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f131_id,
                    f131_rowid_item_ext,
                    f131_rowid_bodega
                FROM t131_mc_items_barras
            ''
        )
    ');

    /* -----------------------------------------------------------------------
       CARGA DESDE ERP — Maestro de bodegas filtrado (ambos modos)
       Solo trae las bodegas que están configuradas en la tabla local.
    ----------------------------------------------------------------------- */
    INSERT INTO @t150_mc_bodegas
    EXEC('
        SELECT
            f150_rowid,
            f150_id,
            f150_id_cia
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f150_rowid,
                    f150_id,
                    f150_id_cia
                FROM t150_mc_bodegas
                WHERE
                    f150_id IN (' + @listaBodegas + ')
            ''
        )
    ');

    /* -----------------------------------------------------------------------
       CARGA DESDE ERP — Existencias (ambos modos)
       Trae existencia total, cantidad comprometida y reserva POS.
       Los valores se convierten a INT en origen para evitar decimales.
    ----------------------------------------------------------------------- */
    INSERT INTO @t400_cm_existencia
    EXEC('
        SELECT
            f400_cant_existencia_1,
            f400_cant_comprometida_1,
            f400_cant_pos_1,
            f400_rowid_item_ext,
            f400_rowid_bodega,
            f400_id_cia
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f400_cant_existencia_1   = CONVERT(INT, f400_cant_existencia_1),
                    f400_cant_comprometida_1 = CONVERT(INT, f400_cant_comprometida_1),
                    f400_cant_pos_1          = CONVERT(INT, f400_cant_pos_1),
                    f400_rowid_item_ext,
                    f400_rowid_bodega,
                    f400_id_cia
                FROM t400_cm_existencia
            ''
        )
    ');

    /* -----------------------------------------------------------------------
       CÁLCULO DE INVENTARIO DISPONIBLE
       
       Fórmula: disponible = existencia - (comprometido + POS)
       
       El barcode se resuelve según el modo:
           Modo 1: f120_referencia       (referencia del ítem base)
           Modo 2: f121_id_barras_principal o f131_id (barcode de la extensión)
       
       Si el resultado es NULL (ítem sin movimientos), se asigna 0.
    ----------------------------------------------------------------------- */
    DECLARE @inventarios TABLE
    (
        cantidad    DECIMAL(18,6),
        barcode     VARCHAR(20),
        bodega      VARCHAR(10)
    );

    INSERT INTO @inventarios
    SELECT DISTINCT
        cantidad =
            CONVERT(
                INT,
                ISNULL(
                    NULLIF(
                        FORMAT(
                            f400_cant_existencia_1 - (
                                f400_cant_comprometida_1 + f400_cant_pos_1
                            ),
                            '####'
                        ),
                        ''
                    ),
                    '0'
                )
            ),
        barcode =
            CASE @modo
                WHEN 1 THEN f120_referencia
                WHEN 2 THEN COALESCE(f121_id_barras_principal, f131_id)
            END,
        bodega = f150_id

    FROM @t121_mc_items_extensiones

        -- Modo 1: join al maestro de ítems para obtener f120_referencia
        -- Modo 2: el join no produce filas (condición @modo = 1 nunca se cumple)
        LEFT JOIN @t120_mc_items
            ON @modo = 1
            AND f120_rowid = f121_rowid_item

        LEFT JOIN @t400_cm_existencia
            ON f121_rowid = f400_rowid_item_ext

        LEFT JOIN @t131_mc_items_barras
            ON f121_rowid = f131_rowid_item_ext

        LEFT JOIN @t150_mc_bodegas
            ON f400_rowid_item_ext = f121_rowid
            AND (
                f150_rowid = f131_rowid_bodega
                OR
                f150_rowid = f400_rowid_bodega
            )

    WHERE
        -- Solo ítems que tienen algún código de barras identificable
        (
            f121_id_barras_principal IS NOT NULL
            OR f131_id IS NOT NULL
        )
        AND f150_id IS NOT NULL
        -- Modo 1: exige que exista la referencia del ítem base
        AND (
            @modo = 2
            OR (@modo = 1 AND f120_referencia IS NOT NULL)
        );

    /* -----------------------------------------------------------------------
       CRUCE CON CATÁLOGO SHOPIFY
       
       Une el inventario calculado con las variantes activas en Shopify
       (inventario_bodega_ecommerce) para obtener el inventory_item_id
       necesario para la API de Shopify.
       
       Si el SKU no tiene match en @inventarios (cantidad NULL), se asigna 0.
    ----------------------------------------------------------------------- */
    DECLARE @inventarios_siesa_shopify TABLE
    (
        inventory_item_id   BIGINT,
        barcode             VARCHAR(20),
        cantidad            INT,
        id_location         BIGINT,
        bodega              VARCHAR(10)
    );

    INSERT INTO @inventarios_siesa_shopify
    SELECT DISTINCT
        inventory_item_id,
        barcode     = sku,
        cantidad    = ISNULL(CONVERT(INT, iss.cantidad), 0),
        b.id_location,
        bodega      = ISNULL(
                        b.bodega_erp,
                        (SELECT TOP 1 bodega_erp FROM @bodegas)
                      )
    FROM inventario_bodega_ecommerce i
        LEFT JOIN @bodegas b
            ON i.id_location = b.id_location
        LEFT JOIN @inventarios iss
            ON i.sku = iss.barcode
    WHERE
        inventory_item_id IS NOT NULL
        AND b.id_location IS NOT NULL;

    /* -----------------------------------------------------------------------
       MERGE HACIA dbo.inventarios
       
       MATCHED + cantidad diferente → UPDATE
           Marca como pendiente de sincronización (sincronizado = 0)
           y actualiza el objeto JSON con la nueva cantidad.
       
       NOT MATCHED BY TARGET → INSERT
           Registra el ítem por primera vez con sincronizado = 0
           para que el proceso de Shopify lo envíe en la próxima ejecución.
       
       El objeto inventario_obj sigue el formato requerido por la API:
           { "location_id": ..., "inventory_item_id": ..., "available": ... }
    ----------------------------------------------------------------------- */
    MERGE INTO dbo.inventarios AS TARGET
    USING @inventarios_siesa_shopify AS source
        ON  target.sku_erp = source.barcode
        AND target.bodega  = source.bodega

    WHEN MATCHED
        AND JSON_VALUE(target.inventario_obj, '$.available') <> CAST(source.cantidad AS NVARCHAR)
        THEN UPDATE SET
            target.sincronizado         = 0,
            target.fecha_sincronizacion = NULL,
            target.inventario_obj =
                json_query((
                    SELECT
                        source.id_location          AS location_id,
                        source.inventory_item_id,
                        CONVERT(INT, source.cantidad) AS available
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                ))

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            id_variante,
            bodega,
            sku_erp,
            inventario_obj,
            sincronizado,
            fecha_sincronizacion
        )
        VALUES (
            0,
            source.bodega,
            source.barcode,
            json_query((
                SELECT
                    source.id_location            AS location_id,
                    source.inventory_item_id,
                    CONVERT(INT, source.cantidad) AS available
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )),
            0,
            NULL
        );

END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() AS Error;
END CATCH;