DECLARE @json           NVARCHAR(MAX);
DECLARE @conexion       VARCHAR(200)
DECLARE @listaBodegas   NVARCHAR(MAX);
DECLARE @sql            NVARCHAR(MAX);

DECLARE @t121_mc_items_extensiones TABLE
(
    f121_rowid                  INT,
    f121_rowid_item             INT,
    f121_id_barras_principal    VARCHAR(20)
);

DECLARE @t131_mc_items_barras TABLE
(
    f131_id             VARCHAR(20), 
    f131_rowid_item_ext INT,
    f131_rowid_bodega   INT
);

DECLARE @t150_mc_bodegas TABLE
(
    f150_rowid  INT,
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
    f400_id_cia                 INT
);

BEGIN TRY
    SELECT TOP 1 
        @conexion   =   cadena_conexion 
    FROM    conexiones

    DECLARE @bodegas TABLE
    (
        id_location BIGINT,
        bodega_erp VARCHAR(6)
    )

    INSERT INTO @bodegas
    SELECT
        id_location,
        bodega_erp
    FROM bodegas
    where bodega_erp IS NOT NULL;

    IF NOT EXISTS(
        SELECT
            id_location
        FROM @bodegas
    )
    BEGIN
        SELECT 'No hay bodegas configuradas.'
        RETURN
    END

    SELECT
        @listaBodegas = STRING_AGG('''''' + bodega_erp + '''''', ',')
    FROM @bodegas;

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
            ''
        )
    ');

    DECLARE @inventarios TABLE
    (
        cantidad    DECIMAL(18,6),
        barcode     VARCHAR(20),
        bodega      VARCHAR(10)
    );

    INSERT INTO @inventarios
    SELECT DISTINCT
        cantidad    =
            CONVERT(
                INT,
                CASE 
                    WHEN
                        FORMAT(
                            (
                                f400_cant_existencia_1 - (
                                    f400_cant_comprometida_1 + f400_cant_pos_1
                                )
                            ), 
                            '####'
                        ) IS NULL 
                            THEN 0
                    ELSE
                        FORMAT(
                            (
                                f400_cant_existencia_1 - (
                                    f400_cant_comprometida_1 + f400_cant_pos_1
                                )
                            ), 
                            '####'
                        ) 
                END
            ),
        barcode =   f120_referencia,
        bodega  =   f150_id
    FROM @t121_mc_items_extensiones
        LEFT JOIN @t400_cm_existencia
            ON
                f121_rowid  =   f400_rowid_item_ext
        LEFT JOIN @t131_mc_items_barras
            ON
                f121_rowid  = f131_rowid_item_ext
        LEFT JOIN @t150_mc_bodegas
            ON
                f400_rowid_item_ext = f121_rowid 
                AND 
                (
                    f150_rowid = f131_rowid_bodega
                    OR
                    f150_rowid  = f400_rowid_bodega
                )
    WHERE
        (
            f121_id_barras_principal IS NOT NULL
            OR
            f131_id IS NOT NULL
        )
        AND
        f150_id IS NOT NULL;

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
        barcode = sku,
        cantidad    =
            ISNULL(
                CONVERT(
                    INT, 
                    cantidad
                ), 
                0
            ),
        b.id_location,
        bodega  =   
            ISNULL(
                b.bodega_erp, 
                (
                    SELECT TOP 1 
                    bodega_erp 
                    FROM @bodegas
                )
            )
    FROM inventario_bodega_ecommerce i
        LEFT JOIN @bodegas b 
            ON 
                i.id_location   =   b.id_location
        LEFT JOIN @inventarios iss 
            ON 
                i.sku   =   iss.barcode
    WHERE
        inventory_item_id   IS NOT NULL
        AND
        b.id_location IS NOT NULL

    MERGE INTO dbo.inventarios AS TARGET
    USING @inventarios_siesa_shopify AS source
        ON 
            target.sku_erp  =   source.barcode
            AND
            target.bodega   =   source.bodega
        WHEN
            MATCHED
            AND
            JSON_VALUE(target.inventario_obj, '$.available') <> CAST(source.cantidad AS NVARCHAR) 
            THEN
                UPDATE SET
                    target.sincronizado = 0,
                    target.fecha_sincronizacion = null,
                    target.inventario_obj=
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
    SELECT ERROR_MESSAGE() 'Error'
END CATCH