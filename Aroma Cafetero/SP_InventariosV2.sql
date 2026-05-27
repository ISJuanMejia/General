DECLARE @json           NVARCHAR(MAX);
DECLARE @conexion       VARCHAR(200);
DECLARE @bd             VARCHAR(200);
DECLARE @listaBodegas   NVARCHAR(MAX);

EXEC Sp_ConsultaConexionSiesa @conexion OUTPUT, @bd OUTPUT;

BEGIN TRY
    DECLARE @batch_size INT = 100,
            @bodega_erp     NVARCHAR(MAX)   =   '001',
            @bodega_shopify NVARCHAR(100)   =   '64470581290';

    -- Obtener conexión y base de datos

    DECLARE @inventarios_erp TABLE
    (
        cantidad        INT,
        codigo_barras   VARCHAR(50),
        descripcion     VARCHAR(255),
        bodega          VARCHAR(5)
    );

    INSERT INTO @inventarios_erp
    EXEC(N'
        SELECT
            cantidad,
            codigo_barras,
            descripcion,
            bodega
        FROM OPENROWSET(
            ''sqlncli'',
            '+@conexion+',
            ''
                SELECT 
                    cantidad    =
                        CASE
                            WHEN
                                FORMAT((f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1)), ''''####'''') IS NULL
                                THEN 0
                            ELSE
                                FORMAT((f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1)), ''''####'''')
                        END,
                    codigo_barras   =   f120_referencia,
                    descripcion     =   f120_descripcion,
                    bodega          =   f150_id
                FROM '+@bd+'.dbo.t120_mc_items
                    INNER JOIN '+@bd+'.dbo.t121_mc_items_extensiones
                        ON
                            f120_rowid = f121_rowid_item
                    INNER JOIN '+@bd+'.dbo.t400_cm_existencia
                        ON
                            f400_rowid_item_ext = f121_rowid
                    INNER JOIN '+@bd+'.dbo.t150_mc_bodegas
                        ON
                            f150_rowid = f400_rowid_bodega
                WHERE
                    f120_referencia IS NOT NULL 
                    -- AND 
                    -- f150_id IN (' + @listaBodegas + ')
            '') AS a'
        );
    
    DECLARE @inventarios_siesa_shopify TABLE
    (
        inventory_item_id   BIGINT,
        barcode             VARCHAR(20),
        cantidad            INT,
        id_location         BIGINT,
        -- bodega              VARCHAR(10),
        id_variante         BIGINT,
        inventario_obj      VARCHAR(MAX)
    );

    INSERT INTO @inventarios_siesa_shopify
    SELECT DISTINCT 
        inventory_item_id,
        Sku             AS barcode,
        agg.cantidad_total                                  AS cantidad,   -- ✅ cantidad agregada
        @bodega_shopify                                         AS id_location,
        -- b.bodega_erp                                        AS bodega,
        VariantId                  AS id_variante,
        (
            JSON_QUERY(
                (
                    SELECT
                        CAST(@bodega_shopify AS VARCHAR(30))                      AS location_id,
                        Inventory_item_id       AS inventory_item_id,
                        agg.cantidad_total                                       AS available
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )
            )
        ) AS inventario_obj
    FROM Products
        INNER JOIN (
            SELECT
                codigo_barras,
                SUM(cantidad) AS cantidad_total
            FROM @inventarios_erp
            GROUP BY codigo_barras
        ) agg ON agg.codigo_barras = Sku
    -- INNER JOIN @bodegas b      ON b.bodega_erp = agg.bodega;

    -- SELECT * FROM Products

    -- SELECT BARCODE, count(*) FROM @inventarios_siesa_shopify group by barcode having count(*) > 1;

    SELECT * 
    FROM @inventarios_siesa_shopify 
    WHERE 
        barcode IN 
        (
            SELECT BARCODE 
            FROM @inventarios_siesa_shopify 
            GROUP BY barcode 
            HAVING count(*) > 1
        )
    ORDER BY barcode;

    SELECT * 
    FROM Products 
    WHERE 
        Sku IN 
        (
            SELECT BARCODE 
            FROM @inventarios_siesa_shopify 
            GROUP BY barcode 
            HAVING count(*) > 1
        )
    ORDER BY Sku;

    SELECT
        batch_size = @batch_size;

    -- SELECT
    --     id_variante         =   VariantId,
    --     bodega,
    --     referencia_item     =   codigo_barras,
    --     cantidad,
    --     descripcion,
    --     Inventory_item_id
    -- FROM @inventarios_erp
    --     INNER JOIN Products ON Sku = codigo_barras;

    -- SELECT
    --     COUNT(*),
    --     Inventory_item_id
    -- FROM @inventarios_erp
    --     INNER JOIN Products ON Sku = codigo_barras
    -- group by Inventory_item_id;

END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() AS Error;
END CATCH

SELECT
    f120_referencia, 
    f120_descripcion,
    f150_id, f150_descripcion, 
    f400_cant_existencia_1, 
    f400_cant_comprometida_1, 
    f400_cant_pendiente_salir_1
FROM t120_mc_items
    INNER JOIN t121_mc_items_extensiones
        ON
            f120_rowid = f121_rowid_item
    INNER JOIN t400_cm_existencia
        ON
            f400_rowid_item_ext = f121_rowid
    INNER JOIN t150_mc_bodegas
        ON
            f150_rowid = f400_rowid_bodega