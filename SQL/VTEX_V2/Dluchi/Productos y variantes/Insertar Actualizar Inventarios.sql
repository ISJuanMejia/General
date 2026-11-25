-- Verificar y eliminar tablas temporales si existen
IF OBJECT_ID('tempdb..#Variantes') IS NOT NULL DROP TABLE #Variantes;
IF OBJECT_ID('tempdb..#InventarioERP') IS NOT NULL DROP TABLE #InventarioERP;
IF OBJECT_ID('tempdb..#ResultadoFinalDeduplicado') IS NOT NULL DROP TABLE #ResultadoFinalDeduplicado;
IF OBJECT_ID('tempdb..#ResultadoFinalDeduplicado_Deduplicado') IS NOT NULL DROP TABLE #ResultadoFinalDeduplicado_Deduplicado;

-- Paso 1: Extraer datos de variantes relevantes
SELECT 
    p.id_tienda,
    v.id AS id_variante,
    v.sku_erp,
    v.id_variante_ecommerce
INTO #Variantes
FROM variantes v
INNER JOIN productos p ON p.id_producto_ecommerce = v.id_producto_ecommerce
WHERE p.id_tienda = 1 AND v.sincronizado = 1
AND ISNULL(v.sku_erp,'') <> ''

-- Paso 2: Calcular cantidades del ERP por variante y bodega (OPENROWSET optimizado)
SELECT 
    p.id_tienda,
    v.id_variante_ecommerce,
    CASE
		WHEN erp.Bodega = 'LCM07' THEN 'ANDINO'
		WHEN erp.Bodega = 'LCM08' THEN 'CMAYOR'
		WHEN erp.Bodega = 'LCM11' THEN 'CHIPICHAPE'
		WHEN erp.Bodega = 'LCM03' THEN 'GPLAZA'
		WHEN erp.Bodega = 'LCM06' THEN 'SANBOGOTA'
		WHEN erp.Bodega = 'LCM04' THEN 'SANMEDELLIN'
		WHEN erp.Bodega = 'LCM10' THEN 'BARRANQUILLA'
		WHEN erp.Bodega = 'LCM02' THEN 'ENVIGADO'
		WHEN erp.Bodega = 'LCM13' THEN 'LACENTRAL'
		WHEN erp.Bodega = 'LCM09' THEN 'MULTIPLAZA'
		WHEN erp.Bodega = 'LCM05' THEN 'FABRICATO'
		WHEN erp.Bodega = 'LCM00' THEN 'LCM01'
		WHEN erp.Bodega = 'LCM20' THEN 'VIVATUNJA'
		WHEN erp.Bodega = 'LCM30' THEN 'BOCAGRANDE'
		WHEN erp.Bodega = 'LCD01' THEN '1_1'
	END AS id_bodega_ecommerce,
    SUM(CONVERT(INT,erp.disponible)) AS cantidad
INTO #InventarioERP
FROM variantes v
INNER JOIN productos p ON p.id_producto_ecommerce = v.id_producto_ecommerce
INNER JOIN OPENROWSET(
        'SQLNCLI11', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Comercbd_Real;Uid=Comercbd;Pwd=Comercbd$12$%;',
        '
        SELECT 
			f120_referencia,
			f121_id_barras_principal,
			f150_id AS Bodega,
			((f400_cant_existencia_1 - f400_cant_comprometida_1) - f400_cant_salida_sin_conf_1) AS Disponible
		FROM t400_cm_existencia E
		INNER JOIN t150_mc_bodegas B ON B.f150_rowid = E.f400_rowid_bodega
		INNER JOIN t121_mc_items_extensiones IE ON IE.f121_rowid = E.f400_rowid_item_ext AND IE.f121_id_barras_principal IS NOT NULL
		INNER JOIN t120_mc_items I ON I.f120_rowid = IE.f121_rowid_item
		WHERE 
			E.f400_id_cia = 1
			AND B.f150_id IN (''LCM00'',''LCM02'',''LCM03'',''LCM04'',''LCM05'',
							  ''LCM06'',''LCM07'',''LCM08'',''LCM09'',''LCM10'',
							  ''LCM11'',''LCM13'',''LCM20'',''LCM30'',''LCD01'')  
			-- Plan 013 Mayor 0001 indica que el item aplica para integracion
			AND EXISTS (
				SELECT 1
				FROM t125_mc_items_criterios C
				WHERE C.f125_rowid_item = I.f120_rowid
				  AND C.f125_id_plan = ''013''
				  AND C.f125_id_criterio_mayor = ''0001''
			)
			-- Plan 017 Mayor 0001 indica que el item integra las existencias de la bodega LCD01
			AND (
					B.f150_id <> ''LCD01''
				OR EXISTS (
					SELECT 1
					FROM t125_mc_items_criterios C2
					WHERE C2.f125_rowid_item = I.f120_rowid
					  AND C2.f125_id_plan = ''017''
					  AND C2.f125_id_criterio_mayor = ''0001''
				)
			)
        '
)  erp
ON CAST(erp.f121_id_barras_principal AS NVARCHAR) = v.sku_erp
    AND p.id_tienda = 1
WHERE erp.Bodega IN ('LCM00','LCM02','LCM03','LCM04','LCM05','LCM06','LCM07','LCM08','LCM09','LCM10','LCM11','LCM13','LCD01','LCM20','LCM30')
GROUP BY p.id_tienda, v.id_variante_ecommerce, 
         CASE
			WHEN erp.Bodega = 'LCM07' THEN 'ANDINO'
			WHEN erp.Bodega = 'LCM08' THEN 'CMAYOR'
			WHEN erp.Bodega = 'LCM11' THEN 'CHIPICHAPE'
			WHEN erp.Bodega = 'LCM03' THEN 'GPLAZA'
			WHEN erp.Bodega = 'LCM06' THEN 'SANBOGOTA'
			WHEN erp.Bodega = 'LCM04' THEN 'SANMEDELLIN'
			WHEN erp.Bodega = 'LCM10' THEN 'BARRANQUILLA'
			WHEN erp.Bodega = 'LCM02' THEN 'ENVIGADO'
			WHEN erp.Bodega = 'LCM13' THEN 'LACENTRAL'
			WHEN erp.Bodega = 'LCM09' THEN 'MULTIPLAZA'
			WHEN erp.Bodega = 'LCM05' THEN 'FABRICATO'
			WHEN erp.Bodega = 'LCM00' THEN 'LCM01'
			WHEN erp.Bodega = 'LCM20' THEN 'VIVATUNJA'
			WHEN erp.Bodega = 'LCM30' THEN 'BOCAGRANDE'
			WHEN erp.Bodega = 'LCD01' THEN '1_1'
		 END;

-- Paso 3: Generar combinaciones de variantes con las bodegas 
SELECT 
    v.id_tienda,
    v.id_variante,
    v.id_variante_ecommerce,
    b.id_bodega_ecommerce,
    v.sku_erp,
    ISNULL(i.cantidad, 0) AS cantidad,
    JSON_QUERY('{
        "unlimitedQuantity": false,
        "quantity": ' + CAST(ISNULL(i.cantidad, 0) AS VARCHAR) + ',
        "dateUtcOnBalanceSystem": "",
        "timeToRefill (deprecated)": ""
    }') AS inventario_obj,
    0 AS sincronizado,
    GETDATE() AS fecha_sincronizacion
INTO #ResultadoFinalDeduplicado
FROM #Variantes v
CROSS JOIN (VALUES 
('ANDINO'),
('CMAYOR'),
('CHIPICHAPE'),
('GPLAZA'),
('SANBOGOTA'),
('SANMEDELLIN'),
('BARRANQUILLA'),
('ENVIGADO'),
('LACENTRAL'),
('MULTIPLAZA'),
('FABRICATO'),
('LCM01'),
('VIVATUNJA'),
('BOCAGRANDE'),
('1_1')
) b(id_bodega_ecommerce)
LEFT JOIN #InventarioERP i
    ON v.id_variante_ecommerce = i.id_variante_ecommerce
    AND b.id_bodega_ecommerce = i.id_bodega_ecommerce
WHERE 
    b.id_bodega_ecommerce <> '1_1'
    OR i.id_variante_ecommerce IS NOT NULL;

-- Paso 4: Eliminar duplicados en #ResultadoFinalDeduplicado
WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY id_tienda, id_variante_ecommerce, id_bodega_ecommerce ORDER BY fecha_sincronizacion DESC) AS rn
    FROM #ResultadoFinalDeduplicado
)
SELECT *
INTO #ResultadoFinalDeduplicado_Deduplicado
FROM CTE
WHERE rn = 1;

-- Paso 5: MERGE para actualizar las filas que tienen diferencias
MERGE INTO dbo.inventarios AS target
USING #ResultadoFinalDeduplicado_Deduplicado AS source
ON (target.id_tienda = source.id_tienda
    AND target.id_variante_ecommerce = source.id_variante_ecommerce 
    AND target.id_bodega_ecommerce = source.id_bodega_ecommerce)
WHEN MATCHED AND (target.cantidad <> source.cantidad) THEN
    UPDATE SET 
        target.cantidad = source.cantidad,
        target.inventario_obj = source.inventario_obj,
        target.sincronizado = 0,
        target.fecha_sincronizacion = source.fecha_sincronizacion
WHEN NOT MATCHED THEN
    INSERT (id_tienda, id_variante, id_variante_ecommerce, id_bodega_ecommerce, sku_erp, cantidad, inventario_obj, sincronizado, fecha_sincronizacion)
    VALUES (source.id_tienda, source.id_variante, source.id_variante_ecommerce, source.id_bodega_ecommerce, source.sku_erp, source.cantidad, source.inventario_obj, source.sincronizado, source.fecha_sincronizacion);

DELETE FROM inventarios
WHERE id_bodega_ecommerce NOT IN (
    'ANDINO',
    'CMAYOR',
    'CHIPICHAPE',
    'GPLAZA',
    'SANBOGOTA',
    'SANMEDELLIN',
    'BARRANQUILLA',
    'ENVIGADO',
    'LACENTRAL',
    'MULTIPLAZA',
    'FABRICATO',
    'LCM01',
    'VIVATUNJA',
    'BOCAGRANDE',
 	'1_1'
)

-- Limpieza de tablas temporales
DROP TABLE #Variantes;
DROP TABLE #InventarioERP;
DROP TABLE #ResultadoFinalDeduplicado;
DROP TABLE #ResultadoFinalDeduplicado_Deduplicado;