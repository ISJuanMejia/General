------------------------------------------------------------
-- LIMPIEZA INICIAL DE TABLAS TEMPORALES
------------------------------------------------------------
IF OBJECT_ID('tempdb..#MapeoBodegas_Mercedes') IS NOT NULL DROP TABLE #MapeoBodegas_Mercedes;
IF OBJECT_ID('tempdb..#Variantes_Mercedes') IS NOT NULL DROP TABLE #Variantes_Mercedes;
IF OBJECT_ID('tempdb..#InventarioERP_Mercedes') IS NOT NULL DROP TABLE #InventarioERP_Mercedes;
IF OBJECT_ID('tempdb..#ResultadoFinal_Mercedes') IS NOT NULL DROP TABLE #ResultadoFinal_Mercedes;

------------------------------------------------------------
-- PASO 0: MAPEO DE BODEGAS ERP -> VTEX
------------------------------------------------------------
CREATE TABLE #MapeoBodegas_Mercedes (
    id_bodega_erp VARCHAR(10) PRIMARY KEY,
    id_bodega_ecommerce VARCHAR(50) NOT NULL
);

INSERT INTO #MapeoBodegas_Mercedes (id_bodega_erp, id_bodega_ecommerce)
VALUES 
    ('C100', '100'),
    ('T113', '10f8df5'),
    ('T26',  '26'),
    ('T17',  '17'),
    ('T67',  '67'),
    ('T112', '1dd846f'),
    ('T02',  '2'),
    ('T14',  '14'),
    ('T16',  '16');

------------------------------------------------------------
-- PASO 1: ELIMINAR REGISTROS DUPLICADOS U OBSOLETOS EN TABLA DESTINO
------------------------------------------------------------
WITH CTE_Duplicados AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY id_tienda, id_variante_ecommerce, id_bodega_ecommerce
               ORDER BY fecha_sincronizacion DESC, id DESC
           ) AS rn
    FROM dbo.inventarios
    WHERE id_tienda = 1
)
DELETE FROM dbo.inventarios
WHERE id IN (SELECT id FROM CTE_Duplicados WHERE rn > 1);

-- Eliminar inventarios de bodegas no mapeadas para la tienda
DELETE FROM dbo.inventarios
WHERE id_tienda = 1 
  AND id_bodega_ecommerce NOT IN (SELECT DISTINCT id_bodega_ecommerce FROM #MapeoBodegas_Mercedes);

------------------------------------------------------------
-- PASO 2: VARIANTES ACTIVAS DE LA TIENDA
------------------------------------------------------------
SELECT 
    p.id_tienda,
    v.id AS id_variante,
    v.sku_erp,
    v.id_variante_ecommerce,
    JSON_VALUE(v.variante_obj, '$.RefId') COLLATE DATABASE_DEFAULT AS ref_id
INTO #Variantes_Mercedes
FROM dbo.variantes v WITH (NOLOCK)
INNER JOIN dbo.productos p WITH (NOLOCK)
    ON p.id_producto_ecommerce = v.id_producto_ecommerce
WHERE p.id_tienda = 1 
  AND v.sincronizado = 1;

CREATE UNIQUE CLUSTERED INDEX CIX_Variantes ON #Variantes_Mercedes(ref_id, id_variante_ecommerce);

------------------------------------------------------------
-- PASO 3: CONSULTA E AGREGACIÓN DE INVENTARIO ERP
------------------------------------------------------------
SELECT 
    v.id_tienda,
    v.id_variante_ecommerce,
    mb.id_bodega_ecommerce,
    SUM(CONVERT(INT, erp.f400_cant_existencia_1 - (erp.f400_cant_comprometida_1 + erp.f400_cant_pos_1))) AS cantidad
INTO #InventarioERP_Mercedes
FROM #Variantes_Mercedes v
INNER JOIN OPENROWSET('SQLNCLI', 
    'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Rehemma_Real;UID=Rehemma;PWD=Rehemma$12$%', 
    'SELECT 
        v121_id_barras_principal, 
        f400_cant_existencia_1,
        f400_cant_comprometida_1,
        f400_cant_pos_1,
        f150_id
     FROM v121 WITH (NOLOCK)
     INNER JOIN t400_cm_existencia WITH (NOLOCK)
        ON f400_id_cia = 1 AND f400_rowid_item_ext = v121_rowid_item_ext
     INNER JOIN t150_mc_bodegas WITH (NOLOCK)
        ON f150_id_cia = 1 AND f150_rowid = f400_rowid_bodega
     WHERE v121_id_barras_principal IS NOT NULL'
) AS erp ON erp.v121_id_barras_principal = v.ref_id
INNER JOIN #MapeoBodegas_Mercedes mb ON mb.id_bodega_erp = erp.f150_id
GROUP BY 
    v.id_tienda, 
    v.id_variante_ecommerce,
    mb.id_bodega_ecommerce;

------------------------------------------------------------
-- PASO 4: GENERACIÓN DE COMBINACIONES (MATRIZ COMPLETA DE BODEGAS)
------------------------------------------------------------
SELECT 
    v.id_tienda,
    v.id_variante,
    v.id_variante_ecommerce,
    b.id_bodega_ecommerce,
    v.sku_erp,
    ISNULL(i.cantidad, 0) AS cantidad,
    JSON_QUERY('{
        "unlimitedQuantity": false,
        "quantity": ' + CAST(ISNULL(i.cantidad, 0) AS VARCHAR(20)) + ',
        "dateUtcOnBalanceSystem": "",
        "timeToRefill (deprecated)": ""
    }') AS inventario_obj,
    0 AS sincronizado,
    GETDATE() AS fecha_sincronizacion
INTO #ResultadoFinal_Mercedes
FROM #Variantes_Mercedes v
CROSS JOIN (SELECT DISTINCT id_bodega_ecommerce FROM #MapeoBodegas_Mercedes) b
LEFT JOIN #InventarioERP_Mercedes i
    ON v.id_variante_ecommerce = i.id_variante_ecommerce
   AND b.id_bodega_ecommerce = i.id_bodega_ecommerce;

------------------------------------------------------------
-- PASO 5: MERGE A LA TABLA DESTINO (INVENTARIOS)
------------------------------------------------------------
MERGE INTO dbo.inventarios AS target
USING #ResultadoFinal_Mercedes AS source
ON (
    target.id_tienda = source.id_tienda
    AND target.id_variante_ecommerce = source.id_variante_ecommerce
    AND target.id_bodega_ecommerce = source.id_bodega_ecommerce
)
WHEN MATCHED AND ISNULL(target.cantidad, 0) <> ISNULL(source.cantidad, 0) THEN
    UPDATE SET 
        target.cantidad = source.cantidad,
        target.inventario_obj = source.inventario_obj,
        target.sincronizado = 0,
        target.fecha_sincronizacion = source.fecha_sincronizacion
WHEN NOT MATCHED THEN
    INSERT (
        id_tienda,
        id_variante,
        id_variante_ecommerce,
        id_bodega_ecommerce,
        sku_erp,
        cantidad,
        inventario_obj,
        sincronizado,
        fecha_sincronizacion
    )
    VALUES (
        source.id_tienda,
        source.id_variante,
        source.id_variante_ecommerce,
        source.id_bodega_ecommerce,
        source.sku_erp,
        source.cantidad,
        source.inventario_obj,
        source.sincronizado,
        source.fecha_sincronizacion
    );

------------------------------------------------------------
-- LIMPIEZA FINAL DE TABLAS TEMPORALES
------------------------------------------------------------
DROP TABLE #MapeoBodegas_Mercedes;
DROP TABLE #Variantes_Mercedes;
DROP TABLE #InventarioERP_Mercedes;
DROP TABLE #ResultadoFinal_Mercedes;


-- SELECT COUNT(*) FROM inventarios
-- SELECT COUNT(*) FROM inventarios WHERE sincronizado = 0