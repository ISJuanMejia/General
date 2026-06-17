SELECT
    f120_referencia,
    f126_precio,
    f126_fecha_activacion
FROM t120_mc_items
    INNER JOIN t126_mc_items_precios ON f126_rowid_item = f120_rowid
WHERE 
    f126_id_lista_precio = 'LP1'
    AND
    f120_referencia = '25252525'