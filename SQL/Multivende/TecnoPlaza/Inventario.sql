DECLARE @conexion NVARCHAR(MAX) = (SELECT TOP 1 cadena_conexion FROM Conexiones);
DECLARE @base_datos NVARCHAR(MAX) = (SELECT TOP 1 base_datos FROM Conexiones);

IF OBJECT_ID('tempdb..#product') IS NOT NULL DROP TABLE #product;
IF OBJECT_ID('tempdb..#stockEcommerce') IS NOT NULL DROP TABLE #stockEcommerce;
IF OBJECT_ID('tempdb..##stockSiesa') IS NOT NULL DROP TABLE ##stockSiesa;


SELECT Variantes.SKU, productos.marca
  INTO #product
  FROM productos
       INNER JOIN Variantes ON Variantes.productoid = productos.productoid
 GROUP BY Variantes.SKU, productos.marca

SELECT warehouse, stockProduct.sku, amount, idStoreSiesa, p.marca
  INTO #stockEcommerce
  FROM stockProduct 
       INNER JOIN warehouse ON stockProduct.warehouse = warehouse.idStore
	   INNER JOIN #product p ON stockProduct.sku = p.sku
 ORDER BY stockProduct.sku, idStoreSiesa


EXEC(N'
SELECT 
		SUM(a.cantidad) AS cantidad,
		a.codigo_barras,
		a.descripcion,
		a.bodega
INTO ##stockSiesa
FROM OPENROWSET(
    ''sqlncli'',
    ''' + @conexion + ''',
    ''
    SELECT 
			CAST(ISNULL((f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1)),0) AS INT) AS cantidad,
			v121_referencia AS codigo_barras,
			v121_descripcion AS descripcion,
			f150_id AS bodega
      FROM ' + @base_datos + '.dbo.t400_cm_existencia t400
            INNER JOIN ' + @base_datos + '.dbo.v121 v121 ON v121.v121_rowid_item_ext = t400.f400_rowid_item_ext
            INNER JOIN ' + @base_datos + '.dbo.t150_mc_bodegas b ON t400.f400_rowid_bodega = b.f150_rowid AND t400.f400_id_cia = b.f150_id_cia
     WHERE v121_referencia IS NOT NULL
       AND f150_id IN (''''01'''',''''02'''')
    ''
) AS a
GROUP BY a.codigo_barras, a.descripcion, a.bodega
');


MERGE INTO dbo.inventario AS TARGET
USING (
		SELECT warehouse, sku, cantidad
		  FROM #stockEcommerce AS a
			   INNER JOIN ##stockSiesa AS b ON CASE      
													WHEN a.sku LIKE '%-%' AND UPPER(a.marca) LIKE '%HP%' 
														THEN REPLACE(a.sku,'-','#')
													WHEN a.sku LIKE '%-%' AND UPPER(a.marca) LIKE '%APPLE%'
														THEN REPLACE(a.sku,'-','/')
													ELSE a.sku
												END = b.codigo_barras 
		                                     AND a.idStoreSiesa = b.bodega
		 WHERE cantidad <> amount
		 GROUP BY warehouse, sku, cantidad
) AS SOURCE
ON TARGET.sku = SOURCE.sku AND TARGET.warehouse = SOURCE.warehouse
WHEN MATCHED AND TARGET.errorStock = 0
THEN
	UPDATE SET
		TARGET.inventario_obj = JSON_QUERY((
				SELECT 
					source.sku AS code,
					source.cantidad AS amount
				FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)),
		TARGET.amount = source.cantidad,
		TARGET.sincronizado = 0,
		TARGET.fecha_sincronizacion = NULL

WHEN NOT MATCHED BY TARGET THEN
	INSERT (
	      warehouse
		  ,sku
		  ,amount
		  ,sincronizado
		  ,fecha_sincronizacion
		  ,inventario_obj
		  ,errorStock
	)
	VALUES (
		source.warehouse,  
		source.sku,
		source.cantidad,
		0,
		null,
		JSON_QUERY((
			SELECT 
				source.sku AS code,
				source.cantidad AS amount
			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)),
		0
	);