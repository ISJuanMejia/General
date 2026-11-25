DECLARE @json           NVARCHAR(MAX);
DECLARE @conexion       VARCHAR(200);
DECLARE @listaBodegas   NVARCHAR(MAX);
DECLARE @sql            NVARCHAR(MAX);

DECLARE @t120_mc_items TABLE
(
    f120_rowid  INT PRIMARY KEY,
    f120_id     NVARCHAR(255)
);

DECLARE @t121_mc_items_extensiones TABLE
(
    f121_rowid              INT PRIMARY KEY,
    f121_rowid_item         INT,
    f121_id_ext1_detalle    NVARCHAR(255),
    f121_id_ext2_detalle    NVARCHAR(255),
    INDEX IX_t121_item (f121_rowid_item)
);

DECLARE @t125_mc_items_criterios TABLE
(
    f125_rowid_item         INT PRIMARY KEY
);

DECLARE @t150_mc_bodegas TABLE
(
    f150_rowid  INT PRIMARY KEY,
    f150_id     VARCHAR(10),
    f150_id_cia INT
);

DECLARE @t400_cm_existencia TABLE
(
    f400_cant_existencia_1      DECIMAL(18,6),
    f400_cant_comprometida_1    DECIMAL(18,6),
    f400_cant_pos_1             DECIMAL(18,6),
    f400_rowid_item_ext         INT,
    f400_rowid_bodega           INT,
    f400_id_cia                 INT,
    INDEX IX_t400_item_bodega (f400_rowid_item_ext, f400_rowid_bodega)
);

BEGIN TRY
    SELECT TOP 1 
        @conexion   =   cadena_conexion 
    FROM conexiones;

    DECLARE @bodegas TABLE
    (
        id_location BIGINT,
        bodega_erp VARCHAR(6)
    );

    INSERT INTO @bodegas
    SELECT
        id_location,
        bodega_erp
    FROM bodegas
    WHERE bodega_erp IS NOT NULL;

    IF NOT EXISTS(
        SELECT id_location FROM @bodegas
    )
    BEGIN
        SELECT 'No hay bodegas configuradas.';
        RETURN;
    END

    SELECT
        @listaBodegas = STRING_AGG('''''' + bodega_erp + '''''', ',')
    FROM @bodegas;

    INSERT INTO @t120_mc_items
    EXEC('
        SELECT 
            f120_rowid,
            f120_id
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT 
                    f120_rowid,
                    f120_id
                FROM t120_mc_items
            ''
        )
    ');

    INSERT INTO @t121_mc_items_extensiones
    EXEC('
        SELECT 
            f121_rowid,
            f121_rowid_item,
            f121_id_ext1_detalle,
            f121_id_ext2_detalle
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT 
                    f121_rowid,
                    f121_rowid_item,
                    f121_id_ext1_detalle    =   TRIM(f121_id_ext1_detalle),
                    f121_id_ext2_detalle    =   TRIM(f121_id_ext2_detalle)
                FROM t121_mc_items_extensiones
            ''
        )
    ');

    INSERT INTO @t125_mc_items_criterios
    EXEC('
        SELECT
            f125_rowid_item
        FROM OPENROWSET(
            ''sqlncli'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f125_rowid_item
                FROM t125_mc_items_criterios 
                WHERE 
                    f125_id_cia = 7
                    AND 
                    f125_id_plan = ''''004'''' 
                    AND
                    f125_id_criterio_mayor = ''''01''''
            ''
        )
    ');

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
                    AND
                    f150_id_cia =   7
            ''
        )
    ');

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
                    f400_cant_existencia_1 = CONVERT(INT, f400_cant_existencia_1),
                    f400_cant_comprometida_1 = CONVERT(INT, f400_cant_comprometida_1),
                    f400_cant_pos_1 = CONVERT(INT, f400_cant_pos_1),
                    f400_rowid_item_ext,
                    f400_rowid_bodega,
                    f400_id_cia
                FROM t400_cm_existencia
                WHERE
                    f400_id_cia = 7
            ''
        )
    ');

    DECLARE @inventarios TABLE
    (
        cantidad    DECIMAL(18,6),
        barcode     VARCHAR(200),
        bodega      VARCHAR(10),
        INDEX IX_inv_barcode_bodega (barcode, bodega)
    );

    INSERT INTO @inventarios
    SELECT DISTINCT
        cantidad = ISNULL(CONVERT(INT, f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1)), 0),
        barcode  = CONVERT(VARCHAR(50), f120_id) + 
                   CASE 
                       WHEN f121_id_ext1_detalle IS NOT NULL 
                           THEN '-' + f121_id_ext1_detalle 
                       ELSE '-0' 
                   END + 
                   CASE 
                       WHEN f121_id_ext2_detalle IS NOT NULL 
                           THEN '-' + f121_id_ext2_detalle 
                       ELSE '-0' 
                   END,
        bodega   = f150_id
    FROM @t120_mc_items
        INNER JOIN @t121_mc_items_extensiones
            ON f120_rowid = f121_rowid_item
        INNER JOIN @t125_mc_items_criterios
            ON f125_rowid_item = f120_rowid
        LEFT JOIN @t400_cm_existencia
            ON f121_rowid  = f400_rowid_item_ext
        LEFT JOIN @t150_mc_bodegas
            ON f400_rowid_item_ext = f121_rowid 
            AND f150_rowid = f400_rowid_bodega
    WHERE
        f150_id IS NOT NULL
        AND f120_id IS NOT NULL;

    DECLARE @inventarios_siesa_shopify TABLE
    (
        inventory_item_id   BIGINT,
        barcode             VARCHAR(200),
        cantidad            INT,
        id_location         BIGINT,
        bodega              VARCHAR(10),
        PRIMARY KEY (inventory_item_id, bodega)
    );

    INSERT INTO @inventarios_siesa_shopify
    (
        inventory_item_id,
        barcode,
        cantidad,
        id_location,
        bodega
    )
    SELECT
        j.inv_item_id,
        v.sku_erp,
        SUM(ISNULL(CONVERT(INT, iss.cantidad), 0)),
        b.id_location,
        b.bodega_erp
    FROM variantes v
        CROSS JOIN @bodegas b
        CROSS APPLY (
            SELECT TRY_CAST(JSON_VALUE(v.variante_obj, '$.inventory_item_id') AS BIGINT) AS inv_item_id
        ) j
        LEFT JOIN @inventarios iss 
            ON v.sku_erp = iss.barcode
            AND b.bodega_erp = iss.bodega
    WHERE
        v.sku_erp IS NOT NULL
        AND j.inv_item_id IS NOT NULL
        AND b.id_location IS NOT NULL
    GROUP BY
        j.inv_item_id,
        v.sku_erp,
        b.id_location,
        b.bodega_erp;

    DELETE inv
    FROM dbo.inventarios inv
    WHERE NOT EXISTS (
        SELECT 1
        FROM @inventarios_siesa_shopify src
        WHERE src.inventory_item_id = TRY_CAST(JSON_VALUE(inv.inventario_obj, '$.inventory_item_id') AS BIGINT)
    );

    MERGE INTO dbo.inventarios AS TARGET
    USING @inventarios_siesa_shopify AS source
        ON 
            target.sku_erp  =   source.barcode
            AND
            target.bodega   =   source.bodega
            AND
            TRY_CAST(JSON_VALUE(target.inventario_obj, '$.inventory_item_id') AS BIGINT) = source.inventory_item_id
        WHEN
            MATCHED
            AND
            JSON_VALUE(target.inventario_obj, '$.available') <> CAST(source.cantidad AS NVARCHAR) 
            THEN
                UPDATE SET
                    target.sincronizado = 0,
                    target.fecha_sincronizacion = null,
                    target.inventario_obj =
                        (
                            json_query(
                                (
                                    select 
                                        source.id_location AS location_id, 
                                        source.inventory_item_id, 
                                        CONVERT(INT, source.cantidad) AS available 
                                    for json path, without_array_wrapper
                                )
                            )
                        )
        WHEN
            NOT MATCHED BY TARGET 
                THEN
                    INSERT  
                    (
                        id_variante,
                        bodega, 
                        sku_erp, 
                        inventario_obj, 
                        sincronizado, 
                        fecha_sincronizacion
                    )
                    VALUES
                    (
                        0, 
                        source.bodega, 
                        source.barcode,
                        json_query
                        (
                            (
                                select
                                    source.id_location as location_id, 
                                    source.inventory_item_id, 
                                    CONVERT(INT, source.cantidad) as available 
                                for json path, without_array_wrapper
                            )
                        ),
                        0, 
                        null
                    );
END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() 'Error';
END CATCH;