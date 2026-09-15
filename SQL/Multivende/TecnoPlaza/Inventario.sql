SET XACT_ABORT ON;

BEGIN TRY
	DECLARE @conexion   NVARCHAR(MAX) = (SELECT TOP 1 cadena_conexion FROM dbo.Conexiones);
	DECLARE @base_datos NVARCHAR(MAX) = (SELECT TOP 1 base_datos FROM dbo.Conexiones);

	IF @conexion IS NULL OR @base_datos IS NULL
	BEGIN
		RAISERROR('No se encontró configuración activa en la tabla Conexiones.', 16, 1);
		RETURN;
	END

	IF OBJECT_ID('tempdb..#product') IS NOT NULL DROP TABLE #product;
	IF OBJECT_ID('tempdb..#stockEcommerce') IS NOT NULL DROP TABLE #stockEcommerce;
	IF OBJECT_ID('tempdb..#stockSiesa') IS NOT NULL DROP TABLE #stockSiesa;

	-- Extraer productos y variantes con su marca
	SELECT 
		Variantes.SKU, 
		productos.marca
	INTO #product
	FROM dbo.productos
	INNER JOIN dbo.Variantes 
		ON Variantes.productoid = productos.productoid
	GROUP BY 
		Variantes.SKU, 
		productos.marca;

	-- Extraer inventario actual de eCommerce sanitizando amount numérico
	SELECT 
		sp.warehouse, 
		sp.sku, 
		sp.amount, 
		ISNULL(TRY_CAST(sp.amount AS INT), 0) AS amount_num,
		w.idStoreSiesa, 
		p.marca
	INTO #stockEcommerce
	FROM dbo.stockProduct sp
	INNER JOIN dbo.warehouse w 
		ON sp.warehouse = w.idStore
	INNER JOIN #product p 
		ON sp.sku = p.sku;

	-- Pre-crear tabla temporal local para recibir existencias remotas
	CREATE TABLE #stockSiesa
	(
		cantidad      INT,
		codigo_barras NVARCHAR(100),
		bodega        NVARCHAR(10)
	);

	-- Extracción remota de existencias netas de Siesa
	DECLARE @sqlSiesa NVARCHAR(MAX) = N'
	INSERT INTO #stockSiesa (cantidad, codigo_barras, bodega)
	SELECT 
		CASE WHEN SUM(a.cantidad) < 0 THEN 0 ELSE SUM(a.cantidad) END AS cantidad,
		a.codigo_barras,
		a.bodega
	FROM OPENROWSET(
		''sqlncli'',
		''' + REPLACE(@conexion, '''', '''''') + ''',
		''SELECT 
			CAST(ISNULL((f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1)), 0) AS INT) AS cantidad,
			v121_referencia AS codigo_barras,
			f150_id AS bodega
		  FROM ' + @base_datos + '.dbo.t400_cm_existencia t400
		  INNER JOIN ' + @base_datos + '.dbo.v121 v121 
			  ON v121.v121_rowid_item_ext = t400.f400_rowid_item_ext
		  INNER JOIN ' + @base_datos + '.dbo.t150_mc_bodegas b 
			  ON t400.f400_rowid_bodega = b.f150_rowid 
			 AND t400.f400_id_cia = b.f150_id_cia
		 WHERE v121_referencia IS NOT NULL
		   AND f150_id IN (''''01'''', ''''02'''')''
	) AS a
	GROUP BY 
		a.codigo_barras, 
		a.bodega;';

	EXEC sp_executesql @sqlSiesa;

	-- Sincronizar diferencias hacia dbo.Inventario
	MERGE INTO dbo.inventario AS TARGET
	USING (
		SELECT 
			a.warehouse, 
			a.sku, 
			MAX(b.cantidad) AS cantidad
		FROM #stockEcommerce AS a
		INNER JOIN #stockSiesa AS b 
			ON CASE      
				WHEN a.sku LIKE '%-%' AND UPPER(a.marca) LIKE '%HP%' 
					THEN REPLACE(a.sku, '-', '#')
				WHEN a.sku LIKE '%-%' AND UPPER(a.marca) LIKE '%APPLE%'
					THEN REPLACE(a.sku, '-', '/')
				ELSE a.sku
			   END = b.codigo_barras 
		   AND a.idStoreSiesa = b.bodega
		WHERE b.cantidad <> a.amount_num
		GROUP BY 
			a.warehouse, 
			a.sku
	) AS SOURCE
	ON TARGET.sku = SOURCE.sku 
	AND TARGET.warehouse = SOURCE.warehouse
	WHEN MATCHED AND TARGET.errorStock = 0 AND (ISNULL(TRY_CAST(TARGET.amount AS INT), -1) <> SOURCE.cantidad OR TARGET.inventario_obj IS NULL)
	THEN
		UPDATE SET
			TARGET.inventario_obj       = JSON_QUERY((
				SELECT 
					SOURCE.sku      AS code,
					SOURCE.cantidad AS amount
				FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
			)),
			TARGET.amount               = CAST(SOURCE.cantidad AS NVARCHAR(1000)),
			TARGET.sincronizado         = 0,
			TARGET.fecha_sincronizacion = NULL

	WHEN NOT MATCHED BY TARGET 
	THEN
		INSERT (
			warehouse,
			sku,
			amount,
			sincronizado,
			fecha_sincronizacion,
			inventario_obj,
			errorStock
		)
		VALUES (
			SOURCE.warehouse,  
			SOURCE.sku,
			CAST(SOURCE.cantidad AS NVARCHAR(1000)),
			0,
			NULL,
			JSON_QUERY((
				SELECT 
					SOURCE.sku      AS code,
					SOURCE.cantidad AS amount
				FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
			)),
			0
		);

	SELECT 
		CAST(0 AS BIT) AS indicaError, 
		'Inventario sincronizado exitosamente.' AS mensaje;

	IF OBJECT_ID('tempdb..#product') IS NOT NULL DROP TABLE #product;
	IF OBJECT_ID('tempdb..#stockEcommerce') IS NOT NULL DROP TABLE #stockEcommerce;
	IF OBJECT_ID('tempdb..#stockSiesa') IS NOT NULL DROP TABLE #stockSiesa;
END TRY
BEGIN CATCH
	IF OBJECT_ID('tempdb..#product') IS NOT NULL DROP TABLE #product;
	IF OBJECT_ID('tempdb..#stockEcommerce') IS NOT NULL DROP TABLE #stockEcommerce;
	IF OBJECT_ID('tempdb..#stockSiesa') IS NOT NULL DROP TABLE #stockSiesa;

	SELECT 
		CAST(1 AS BIT) AS indicaError, 
		CONCAT('Error en Inventario: ', ERROR_MESSAGE()) AS mensaje;
END CATCH;