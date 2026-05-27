DECLARE @productVendor          NVARCHAR(255)   =   'Clemont Oficial';
DECLARE @productDefaultStatus   NVARCHAR(255)   =   'draft';
DECLARE @InventoryManagement    NVARCHAR(255)   =   'shopify';
DECLARE @TipoExtension1         NVARCHAR(5)     =   'Talla';

SELECT
    JSON_QUERY(
        (
            Select
            TRIM(f120_descripcion)		AS	[product.title],
            TRIM(f120_descripcion)		AS	[product.body_html],
            @productVendor				AS	[product.vendor],
            @productDefaultStatus		AS	[product.status],
            (
                SELECT DISTINCT
                    CASE
                        WHEN TRIM(f117_descripcion) != 'NO APLICA' THEN TRIM(f117_descripcion)
                        ELSE ''
                    END											AS	[option1],
                    -- CASE
                    --     WHEN TRIM(f119_descripcion) != 'NO APLICA' THEN TRIM(f119_descripcion)
                    --     ELSE ''
                    -- END											AS	[option2],
                    (
                        SELECT 
                            f126_precio
                        FROM t126_mc_items_precios
                        WHERE 
                            (   
                                f126_rowid_item =   f120_rowid
                                OR
                                f126_rowid_item_ext = f121_rowid
                            )
                            AND 
                            f126_fecha_ts_actualizacion = (
                                SELECT MAX(f126_fecha_ts_actualizacion)
                                FROM t126_mc_items_precios
                                WHERE 
                                f126_rowid_item =   f120_rowid
                                OR
                                f126_rowid_item_ext = f121_rowid
                            )
                    )											AS	[price],
                    f121_id_barras_principal	AS	[sku],
                    f121_id_barras_principal	AS	[barcode],
                    @InventoryManagement            AS	[inventory_management]
                FROM t121_mc_items_extensiones	AS	t121_variantes
                    INNER JOIN	t117_mc_extensiones1_detalle	AS	t117	ON
                        t117.f117_id	=	t121_variantes.f121_id_ext1_detalle
                        AND
                        t117.f117_id_cia	=	t121_variantes.f121_id_cia
                    -- INNER JOIN	t119_mc_extensiones2_detalle	AS	t119	ON 
                    --     t119.f119_id	=	t121_variantes.f121_id_ext2_detalle
                    --     AND
                    --     t119.f119_id_cia	=	t121_variantes.f121_id_cia
                    LEFT JOIN t126_mc_items_precios	AS	t126		ON
                        (
                            t126.f126_rowid_item	=	t120.f120_rowid
                            OR
                            t126.f126_rowid_item_ext = t121_variantes.f121_rowid
                        )
                WHERE
                    f121_rowid_item	=	f120_rowid
                    AND
                    f121_id_barras_principal IS NOT NULL
                FOR JSON PATH
            )	AS	[product.variants],
            (
                SELECT
                    [name],
                    JSON_QUERY('[' + STRING_AGG('"' + STRING_ESCAPE([values], 'json') + '"', ',') + ']') AS [values]
                FROM (
                    SELECT DISTINCT
                        @TipoExtension1				AS	[name],
                        f117_descripcion			AS	[values]
                    FROM t121_mc_items_extensiones	AS	t121_ext1
                        INNER JOIN t117_mc_extensiones1_detalle	ON 
                            f117_id = f121_id_ext1_detalle 
                            AND 
                            f117_id_cia = f121_id_cia
                    WHERE 
                        f121_rowid_item = f120_rowid
                        AND
                        f121_id_barras_principal IS NOT NULL
                        AND (
                            TRIM(f117_descripcion) IS NOT NULL 
                            OR 
                            TRIM(f117_descripcion) <> '' 
                            OR 
                            TRIM(f117_descripcion) != 'NO APLICA'
                        )
                ) AS options_union
                GROUP BY [name]
                FOR JSON PATH
            )	AS	[product.options]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    ) AS ProductJSON
FROM t120_mc_items AS t120
WHERE
    f120_referencia IN ('101426')