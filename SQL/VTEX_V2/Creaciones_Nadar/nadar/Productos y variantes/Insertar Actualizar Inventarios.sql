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
WHERE p.id_tienda = 2 AND v.sincronizado = 1;

-- Paso 2: Calcular cantidades del ERP por variante y bodega
SELECT 
    p.id_tienda,
    v.id_variante_ecommerce,
    CASE 
        WHEN t150.f150_id IN ('BV300') THEN '1'
    END AS id_bodega_ecommerce,
    SUM(CONVERT(INT, f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1))) AS cantidad
INTO #InventarioERP
FROM variantes v
INNER JOIN productos p ON p.id_producto_ecommerce = v.id_producto_ecommerce
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.v121 v121
    ON v121.v121_id_cia = 1
    AND v121.v121_id_barras_principal = v.sku_erp COLLATE DATABASE_DEFAULT
    AND p.id_tienda = 2
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.t400_cm_existencia t400
    ON t400.f400_id_cia = 1
    AND t400.f400_rowid_item_ext = v121.v121_rowid_item_ext
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.t150_mc_bodegas t150
    ON t150.f150_id_cia = 1
    AND t150.f150_rowid = t400.f400_rowid_bodega
WHERE t150.f150_id IN ('BV300')
GROUP BY p.id_tienda, v.id_variante_ecommerce, 
         CASE 
             WHEN t150.f150_id IN ('BV300') THEN '1'
         END;

-- Paso 3: Generar combinaciones de variantes con ambas bodegas
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
    }') AS inventario_obj, -- Generar inventario_obj
    0 AS sincronizado,
    GETDATE() AS fecha_sincronizacion
INTO #ResultadoFinalDeduplicado
FROM #Variantes v
CROSS JOIN (VALUES ('1')) b(id_bodega_ecommerce) -- Crear combinaciones explícitas para las dos bodegas
LEFT JOIN #InventarioERP i
    ON v.id_variante_ecommerce = i.id_variante_ecommerce
    AND b.id_bodega_ecommerce = i.id_bodega_ecommerce;

-- Paso 4: Eliminar duplicados en #ResultadoFinalDeduplicado
WITH CTE AS (
    SELECT * ,
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

-- Limpieza de tablas temporales
DROP TABLE #Variantes;
DROP TABLE #InventarioERP;
DROP TABLE #ResultadoFinalDeduplicado;
DROP TABLE #ResultadoFinalDeduplicado_Deduplicado;