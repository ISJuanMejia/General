MERGE INTO dbo.precios AS target
USING (
    SELECT 
        p.id_tienda,
        v.id AS id_variante,
        v.id_variante_ecommerce,
        v.sku_erp,
        JSON_QUERY('{
            "markup": 0,
            "basePrice": ' + FORMAT(erp.f126_precio, '####') + ',
            "listPrice": ' + FORMAT(erp.f126_precio, '####') + ',
            "fixedPrices": [
                {
                    "tradePolicyId": "1",
                    "value": ' + FORMAT(erp.f126_precio, '####') + ',
                    "listPrice": ' + FORMAT(erp.f126_precio, '####') + ',
                    "minQuantity": 1
                }
            ]
        }') AS precio_obj,
        0 AS sincronizado,
        GETDATE() AS fecha_sincronizacion
    FROM variantes v
    INNER JOIN productos p ON p.id_producto_ecommerce = v.id_producto_ecommerce
    INNER JOIN OPENROWSET(
        'SQLNCLI',
		'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
        '
        SELECT t126.*,
		       v121_id_barras_principal,
               v121.v121_referencia,
               v121.v121_rowid_item
        FROM dbo.t126_mc_items_precios t126
        INNER JOIN dbo.v121 v121
            ON t126.f126_id_cia = 2
            AND v121.v121_id_cia = 2
            AND t126.f126_rowid_item = v121.v121_rowid_item
        WHERE 
            t126.f126_precio > 1
            AND t126.f126_id_lista_precio = ''S01''
            AND t126.f126_fecha_activacion = (
                SELECT MAX(sub.f126_fecha_activacion)
                FROM dbo.t126_mc_items_precios sub
                WHERE sub.f126_id_cia = 2
                AND sub.f126_rowid_item = t126.f126_rowid_item
                AND sub.f126_id_lista_precio = t126.f126_id_lista_precio
                AND sub.f126_fecha_activacion <= GETDATE()
            )
        '
    ) AS erp
        ON erp.v121_id_barras_principal = JSON_VALUE(v.variante_obj, '$.RefId') COLLATE DATABASE_DEFAULT
    WHERE 
        p.id_tienda = 1
        AND v.sincronizado = 1
) AS source
ON (target.id_variante_ecommerce = source.id_variante_ecommerce)

--WHEN MATCHED AND target.id_tienda <> source.id_tienda AND target.precio_obj <> source.precio_obj THEN
--    UPDATE SET 
--        target.precio_obj = source.precio_obj,
--        target.sincronizado = 0,
--        target.fecha_sincronizacion = source.fecha_sincronizacion

WHEN MATCHED AND JSON_VALUE(target.precio_obj, '$.basePrice') <> JSON_VALUE(source.precio_obj, '$.basePrice')
THEN
    UPDATE SET 
        target.precio_obj = source.precio_obj,
        target.sincronizado = 0,
        target.fecha_sincronizacion = source.fecha_sincronizacion

WHEN NOT MATCHED THEN
    INSERT (id_tienda, id_variante, id_variante_ecommerce, sku_erp, precio_obj, sincronizado, fecha_sincronizacion)
    VALUES (source.id_tienda, source.id_variante, source.id_variante_ecommerce,
	source.sku_erp, source.precio_obj, source.sincronizado, source.fecha_sincronizacion);