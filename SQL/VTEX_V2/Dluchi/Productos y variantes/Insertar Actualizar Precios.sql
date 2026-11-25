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
        'SQLNCLI11', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Comercbd_Real;Uid=Comercbd;Pwd=Comercbd$12$%;',
        '
        SELECT 
		T126.f126_precio,
		f121_id_barras_principal
		FROM t126_mc_items_precios T126
		INNER JOIN t120_mc_items ON T126.f126_rowid_item = f120_rowid 
									AND T126.f126_id_cia = f120_id_cia 
									AND f120_id_unidad_orden = T126.f126_id_unidad_medida
		INNER JOIN t121_mc_items_extensiones ON f120_rowid = f121_rowid_item 
												AND f120_id_cia = f121_id_cia 
												AND f121_id_barras_principal IS NOT NULL
		WHERE T126.f126_rowid_item IS NOT NULL
		AND T126.f126_id_cia = 1
		AND T126.f126_precio > 1
		AND T126.f126_id_lista_precio = ''01''
		AND T126.f126_fecha_activacion = (
										SELECT MAX(sub.f126_fecha_activacion)
										FROM dbo.t126_mc_items_precios sub
										WHERE sub.f126_id_cia = 1
										AND T126.f126_id_unidad_medida = sub.f126_id_unidad_medida
										AND sub.f126_rowid_item = T126.f126_rowid_item
										AND sub.f126_id_lista_precio = T126.f126_id_lista_precio
										AND sub.f126_fecha_activacion <= GETDATE()
									)
		
		UNION ALL

		SELECT
		T126.f126_precio,
		f121_id_barras_principal
		FROM t126_mc_items_precios T126
		INNER JOIN t121_mc_items_extensiones ON T126.f126_rowid_item_ext = f121_rowid 
												AND T126.f126_id_cia = f121_id_cia 
												AND f121_id_barras_principal IS NOT NULL
		INNER JOIN t120_mc_items ON f121_rowid_item = f120_rowid 									
									AND f120_id_unidad_orden = T126.f126_id_unidad_medida
		WHERE T126.f126_rowid_item_ext IS NOT NULL
		AND T126.f126_id_cia = 1
		AND T126.f126_precio > 1
		AND T126.f126_id_lista_precio = ''01''
		AND T126.f126_fecha_activacion = (
										SELECT MAX(sub.f126_fecha_activacion)
										FROM dbo.t126_mc_items_precios sub
										WHERE sub.f126_id_cia = 1
										AND T126.f126_id_unidad_medida = sub.f126_id_unidad_medida
										AND sub.f126_rowid_item_ext = T126.f126_rowid_item_ext
										AND sub.f126_id_lista_precio = T126.f126_id_lista_precio
										AND sub.f126_fecha_activacion <= GETDATE()
									)
        '
    ) AS erp
        ON CAST(erp.f121_id_barras_principal AS NVARCHAR) = v.sku_erp COLLATE DATABASE_DEFAULT
    WHERE p.id_tienda = 1 
		AND v.sincronizado = 1
) AS source
ON (target.id_variante_ecommerce = source.id_variante_ecommerce)

WHEN MATCHED AND target.id_tienda = source.id_tienda AND target.precio_obj <> source.precio_obj THEN
    UPDATE SET 
        target.precio_obj = source.precio_obj,
        target.sincronizado = 0,
        target.fecha_sincronizacion = source.fecha_sincronizacion

WHEN NOT MATCHED THEN
    INSERT (id_tienda, id_variante, id_variante_ecommerce, sku_erp, precio_obj, sincronizado, fecha_sincronizacion)
    VALUES (source.id_tienda, source.id_variante, source.id_variante_ecommerce, source.sku_erp, source.precio_obj, source.sincronizado, source.fecha_sincronizacion);