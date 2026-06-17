-- Verificar y eliminar tablas temporales si existen
IF OBJECT_ID('tempdb..#Variantes_Pisende') IS NOT NULL DROP TABLE #Variantes_Pisende;
IF OBJECT_ID('tempdb..#InventarioERP_Pisende') IS NOT NULL DROP TABLE #InventarioERP_Pisende;
IF OBJECT_ID('tempdb..#ResultadoFinalDeduplicado_Pisende') IS NOT NULL DROP TABLE #ResultadoFinalDeduplicado_Pisende;
IF OBJECT_ID('tempdb..#ResultadoFinalDeduplicado_Deduplicado_Pisende') IS NOT NULL DROP TABLE #ResultadoFinalDeduplicado_Deduplicado_Pisende;

-- Paso 1: Extraer datos de variantes relevantes
SELECT 
    p.id_tienda,
    v.id AS id_variante,
    v.sku_erp,
    v.id_variante_ecommerce
INTO #Variantes_Pisende
FROM variantes v
INNER JOIN productos p ON p.id_producto_ecommerce = v.id_producto_ecommerce
WHERE p.id_tienda = 1 AND v.sincronizado = 1;

-- Paso 2: Calcular cantidades del ERP por variante y bodega (OPENROWSET optimizado)
SELECT 
    p.id_tienda,
    v.id_variante_ecommerce,
    CASE 
        WHEN erp.f150_id IN ('BD001') THEN 'BD001'
        WHEN erp.f150_id IN ('BDAPG') THEN 'BDAPG'
        WHEN erp.f150_id IN ('BDVIR') THEN 'BDVIR'
		WHEN erp.f150_id IN ('OUT01') THEN 'OUT01'
    END AS id_bodega_ecommerce,
    SUM(CONVERT(INT,disponible)) AS cantidad
INTO #InventarioERP_Pisende
FROM variantes v
INNER JOIN productos p ON p.id_producto_ecommerce = v.id_producto_ecommerce
INNER JOIN OPENROWSET(
    'SQLNCLI',
	'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=Pisende;Pwd=Pisende$12$%;',
    '
     WITH ranked_lotes AS (
		SELECT 
			t120.f120_id_cia,
			f120_id,
			f120_referencia,
			f150_id,
			--f150_descripcion,
			--t401.f401_id_ubicacion_aux,
			f403_id,
			t120.f120_id_unidad_inventario,
			t120.f120_id_unidad_orden,
			((t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1) - t401.f401_cant_salida_sin_conf_1) / f122_factor AS Disponible,
			ROW_NUMBER() OVER (
				PARTITION BY f150_id, f120_referencia 
				ORDER BY ((t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1) - t401.f401_cant_salida_sin_conf_1) DESC
			) as rn
		FROM t401_cm_existencia_lote t401
		INNER JOIN t150_mc_bodegas t150 
			ON t150.f150_rowid = t401.f401_rowid_bodega
			AND f150_id IN (''BD001'',''BDVIR'',''BDAPG'',''OUT01'')
		LEFT JOIN t403_cm_lotes t403 
			ON t403.f403_id = t401.f401_id_lote 
			AND t403.f403_id_cia = t401.f401_id_cia
			AND t403.f403_ind_estado = 1 
		INNER JOIN t121_mc_items_extensiones t121 
			ON t121.f121_rowid = t401.f401_rowid_item_ext
		INNER JOIN t120_mc_items t120 
			ON t120.f120_rowid = t121.f121_rowid_item
		INNER JOIN t122_mc_items_unidades  
			ON f120_rowid = f122_rowid_item 
			AND f120_id_unidad_orden = f122_id_unidad
		INNER JOIN t125_mc_items_criterios 
			ON f125_rowid_item = f120_rowid 
			AND f125_id_cia = 1
		WHERE (
			(t403.f403_id IS NOT NULL AND 
			 ((t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1 - t401.f401_cant_salida_sin_conf_1) / f122_factor) > 2) 
			OR
			(t403.f403_id IS NULL AND 
			 (t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1 - t401.f401_cant_salida_sin_conf_1) > 0)
		) AND (f125_id_plan = ''C29''
	 	AND f125_id_criterio_mayor = ''001'')
	)
	SELECT
		f120_id_cia,
		f120_id,
		f120_referencia,
		f150_id,
		--f150_descripcion,
		--f401_id_ubicacion_aux,
		f403_id,
		f120_id_unidad_inventario,
		f120_id_unidad_orden,
		Disponible
	FROM ranked_lotes
	WHERE rn = 1
	ORDER BY f150_id, Disponible DESC
    '
) AS erp
    ON CAST(erp.f120_id AS NVARCHAR) = v.sku_erp 
    AND p.id_tienda = 1
WHERE erp.f150_id IN ('BD001','BDAPG','BDVIR','OUT01')
GROUP BY p.id_tienda, v.id_variante_ecommerce, 
         CASE 
             WHEN erp.f150_id IN ('BD001') THEN 'BD001'
             WHEN erp.f150_id IN ('BDAPG') THEN 'BDAPG'
             WHEN erp.f150_id IN ('BDVIR') THEN 'BDVIR'
			 WHEN erp.f150_id IN ('OUT01') THEN 'OUT01'
         END;

-- Paso 3: Generar combinaciones de variantes con las bodegas ('BD001','BDAPG','BDVIR','OUT01')
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
INTO #ResultadoFinalDeduplicado_Pisende
FROM #Variantes_Pisende v
CROSS JOIN (VALUES ('BD001'), ('BDAPG'), ('BDVIR'), ('OUT01')) b(id_bodega_ecommerce)
LEFT JOIN #InventarioERP_Pisende i
    ON v.id_variante_ecommerce = i.id_variante_ecommerce
    AND b.id_bodega_ecommerce = i.id_bodega_ecommerce;

-- Paso 4: Eliminar duplicados en #ResultadoFinalDeduplicado_Pisende
WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY id_tienda, id_variante_ecommerce, id_bodega_ecommerce ORDER BY fecha_sincronizacion DESC) AS rn
    FROM #ResultadoFinalDeduplicado_Pisende
)
SELECT *
INTO #ResultadoFinalDeduplicado_Deduplicado_Pisende
FROM CTE
WHERE rn = 1;

-- Paso 5: MERGE para actualizar las filas que tienen diferencias
MERGE INTO dbo.inventarios AS target
USING #ResultadoFinalDeduplicado_Deduplicado_Pisende AS source
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

-- Limpieza de tablas temporales
DROP TABLE #Variantes_Pisende;
DROP TABLE #InventarioERP_Pisende;
DROP TABLE #ResultadoFinalDeduplicado_Pisende;
DROP TABLE #ResultadoFinalDeduplicado_Deduplicado_Pisende;