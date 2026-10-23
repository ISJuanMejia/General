-- =============================================
-- Inventarios Pisende - SincronizaciÃ³n ERP â†’ VTEX
-- Optimizado: eliminaciÃ³n de tablas temporales redundantes,
-- Ã­ndices de soporte, simplificaciÃ³n de lÃ³gica
-- =============================================

-- Verificar y eliminar tablas temporales si existen
IF OBJECT_ID('tempdb..#InventarioERP_Pisende') IS NOT NULL DROP TABLE #InventarioERP_Pisende;
IF OBJECT_ID('tempdb..#ResultadoFinal_Pisende') IS NOT NULL DROP TABLE #ResultadoFinal_Pisende;

-- Ãndices de soporte (idempotentes)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_productos_tienda_producto' AND object_id = OBJECT_ID('productos'))
    CREATE NONCLUSTERED INDEX IX_productos_tienda_producto 
    ON productos (id_tienda, id_producto_ecommerce);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_variantes_producto_sync' AND object_id = OBJECT_ID('variantes'))
    CREATE NONCLUSTERED INDEX IX_variantes_producto_sync 
    ON variantes (id_producto_ecommerce, sincronizado) 
    INCLUDE (id, sku_erp, id_variante_ecommerce);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_inventarios_tienda_variante_bodega' AND object_id = OBJECT_ID('inventarios'))
    CREATE NONCLUSTERED INDEX IX_inventarios_tienda_variante_bodega 
    ON inventarios (id_tienda, id_variante_ecommerce, id_bodega_ecommerce) 
    INCLUDE (cantidad);

-- Limpiar inventarios de bodegas no vÃ¡lidas
DELETE FROM [Connekta-Ecommerce-Vtex-Pisende].[dbo].[inventarios]
WHERE id_bodega_ecommerce NOT IN ('BD001', 'BDAPG', 'BDVIR', 'OUT01');

-- Paso 1: Inventario ERP agrupado por variante y bodega
-- Se elimina #Variantes_Pisende (redundante, el JOIN ya estÃ¡ aquÃ­)
-- Se elimina el CASE (f150_id ya viene filtrado con los valores exactos)
SELECT 
    p.id_tienda,
    MIN(v.id) AS id_variante,
    v.id_variante_ecommerce,
    MIN(v.sku_erp) AS sku_erp,
    erp.f150_id AS id_bodega_ecommerce,
    SUM(CAST(erp.disponible AS INT)) AS cantidad
INTO #InventarioERP_Pisende
FROM variantes v
INNER JOIN productos p 
    ON p.id_producto_ecommerce = v.id_producto_ecommerce
    AND p.id_tienda = 1
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
            f403_id,
            t120.f120_id_unidad_inventario,
            t120.f120_id_unidad_orden,
            -- AplicaciÃ³n combinada de reglas de negocio:
            CASE 
                -- Si es de Pisos y Paredes (C24 = 1) Y maneja lote: exige umbral > 5, de lo contrario envÃ­a 0
                WHEN c24.f125_id_criterio_mayor = ''1'' AND t403.f403_id IS NOT NULL THEN 
                    CASE 
                        WHEN (((t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1) - t401.f401_cant_salida_sin_conf_1) / f122_factor) > 5 
                        THEN ((t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1) - t401.f401_cant_salida_sin_conf_1) / f122_factor
                        ELSE 0 
                    END
                -- Para el resto de productos: regla normal de stock > 0
                ELSE 
                    CASE 
                        WHEN ((t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1) - t401.f401_cant_salida_sin_conf_1) / f122_factor > 0 
                        THEN ((t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1) - t401.f401_cant_salida_sin_conf_1) / f122_factor
                        ELSE 0 
                    END
            END AS Disponible,
            ROW_NUMBER() OVER (
                PARTITION BY f150_id, f120_referencia 
                ORDER BY ((t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1) - t401.f401_cant_salida_sin_conf_1) DESC
            ) as rn
        FROM t401_cm_existencia_lote t401
        INNER JOIN t150_mc_bodegas t150 
            ON t150.f150_rowid = t401.f401_rowid_bodega
            AND f150_id IN (''BD001'',''BDVIR'',''BDAPG'',''OUT01'')
        LEFT JOIN t403_cm_lotes t403
            ON t403.f403_id_cia = t401.f401_id_cia
            AND t403.f403_id = t401.f401_id_lote
            AND t403.f403_rowid_item_ext = t401.f401_rowid_item_ext
            AND t403.f403_ind_estado = 1
        INNER JOIN t121_mc_items_extensiones t121 
            ON t121.f121_rowid = t401.f401_rowid_item_ext
        INNER JOIN t120_mc_items t120 
            ON t120.f120_rowid = t121.f121_rowid_item
        INNER JOIN t122_mc_items_unidades  
            ON f120_rowid = f122_rowid_item 
            AND f120_id_unidad_orden = f122_id_unidad
        -- Criterio C29 (Obligatorio para que se integre a e-commerce)
        INNER JOIN t125_mc_items_criterios c29
            ON c29.f125_rowid_item = f120_rowid 
            AND c29.f125_id_cia = 1
            AND c29.f125_id_plan = ''C29''
            AND c29.f125_id_criterio_mayor = ''001''
        -- Criterio C24 (Para identificar Pisos y Paredes)
        LEFT JOIN t125_mc_items_criterios c24 
            ON c24.f125_rowid_item = f120_rowid 
            AND c24.f125_id_cia = 1
            AND c24.f125_id_plan = ''C24''
        WHERE (
            (t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1 - t401.f401_cant_salida_sin_conf_1) >= 0
        )
    )
    SELECT
        f120_id_cia,
        f120_id,
        f120_referencia,
        f150_id,
        f403_id,
        f120_id_unidad_inventario,
        f120_id_unidad_orden,
        Disponible
    FROM ranked_lotes
    WHERE rn = 1
    '
) AS erp
    ON CAST(erp.f120_id AS NVARCHAR(20)) = v.sku_erp
WHERE v.sincronizado = 1
GROUP BY p.id_tienda, v.id_variante_ecommerce, erp.f150_id;

-- Ãndice en la temporal para acelerar el MERGE y DELETE
CREATE CLUSTERED INDEX IX_tmp_inv ON #InventarioERP_Pisende (id_tienda, id_variante_ecommerce, id_bodega_ecommerce);

-- Paso 2: Construir resultado final con JSON
-- Se elimina el CROSS JOIN + INNER JOIN redundante
-- Se elimina la deduplicaciÃ³n (GROUP BY del Paso 1 ya garantiza unicidad)
SELECT 
    ie.id_tienda,
    ie.id_variante,
    ie.id_variante_ecommerce,
    ie.id_bodega_ecommerce,
    ie.sku_erp,
    ie.cantidad,
    '{"unlimitedQuantity":false,"quantity":' + CAST(ie.cantidad AS VARCHAR(10)) + ',"dateUtcOnBalanceSystem":"","timeToRefill (deprecated)":""}' AS inventario_obj,
    CAST(0 AS BIT) AS sincronizado,
    GETDATE() AS fecha_sincronizacion
INTO #ResultadoFinal_Pisende
FROM #InventarioERP_Pisende ie;

CREATE CLUSTERED INDEX IX_tmp_res ON #ResultadoFinal_Pisende (id_tienda, id_variante_ecommerce, id_bodega_ecommerce);

-- Paso 3: Eliminar inventarios sin correspondencia en ERP
DELETE inv 
FROM inventarios inv 
LEFT JOIN #ResultadoFinal_Pisende rfp 
    ON inv.id_tienda = rfp.id_tienda
    AND inv.id_variante_ecommerce = rfp.id_variante_ecommerce
    AND inv.id_bodega_ecommerce = rfp.id_bodega_ecommerce
WHERE rfp.id_tienda IS NULL;

-- Paso 4: MERGE para sincronizar inventarios
MERGE INTO dbo.inventarios AS target
USING #ResultadoFinal_Pisende AS source
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

-- Limpieza
DROP TABLE #InventarioERP_Pisende;
DROP TABLE #ResultadoFinal_Pisende;