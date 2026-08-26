SET NOCOUNT ON;

DELETE FROM [Integracion-VeronaGroup-VTEX].[dbo].[inventarios]
WHERE 
    id_bodega_ecommerce != '1_1';

-- =============================================
-- CONFIGURACIÓN: Bodegas ERP de Verona
-- Modificar esta lista para agregar/quitar bodegas
-- =============================================
DECLARE @Bodegas_Verona TABLE (
    id_bodega VARCHAR(10) PRIMARY KEY
);

INSERT INTO @Bodegas_Verona (id_bodega)
VALUES
('10201'), ('10301'), ('10401'), ('10501'),
('10601'), ('10701'), ('10801'), ('10901'),
('11001'), ('11101'), ('11201'), ('11301'),
('11501');

-- Generar cláusula IN para OPENROWSET (ej: ''10201'', ''10301'', ...)
DECLARE @BodegasIN NVARCHAR(MAX);
SELECT @BodegasIN = STRING_AGG('''' + '''' + id_bodega + '''' + '''', ', ')
FROM @Bodegas_Verona;

-- =============================================
-- Variantes sincronizadas de la tienda
-- =============================================
CREATE TABLE #Variantes_verona (
    id_tienda              INT,
    id_variante            INT,
    sku_erp                NVARCHAR(20),
    id_variante_ecommerce  INT,
    refid                  VARCHAR(255),
    INDEX IX_Variantes_RefId       NONCLUSTERED (refid),
    INDEX IX_Variantes_Ecommerce   NONCLUSTERED (id_variante_ecommerce)
);

INSERT INTO #Variantes_verona (
    id_tienda,
    id_variante,
    sku_erp,
    id_variante_ecommerce,
    refid
)
SELECT
    p.id_tienda,
    v.id                                        AS id_variante,
    v.sku_erp,
    v.id_variante_ecommerce,
    JSON_VALUE(v.variante_obj, '$.RefId')       AS refid
FROM variantes v
INNER JOIN productos p
    ON p.id_producto_ecommerce = v.id_producto_ecommerce
WHERE
    p.id_tienda    = 1
    AND v.sincronizado = 1;

-- =============================================
-- Inventario calculado desde el ERP (SQL dinámico por OPENROWSET)
-- =============================================
CREATE TABLE #InventarioERP_verona (
    id_tienda              INT,
    id_variante_ecommerce  INT,
    id_bodega_ecommerce    NVARCHAR(10),
    cantidad               INT,
    INDEX IX_InventarioERP NONCLUSTERED (id_variante_ecommerce, id_bodega_ecommerce)
);

DECLARE @SqlERP NVARCHAR(MAX) = N'
SELECT
    v.id_tienda,
    v.id_variante_ecommerce,
    N''1_1''                              AS id_bodega_ecommerce,
    CASE
        WHEN CONVERT(INT, SUM(
            erp.f400_cant_existencia_1
            - (erp.f400_cant_comprometida_1 + erp.f400_cant_pos_1)
        )) < 0 THEN 0
        ELSE CONVERT(INT, SUM(
            erp.f400_cant_existencia_1
            - (erp.f400_cant_comprometida_1 + erp.f400_cant_pos_1)
        ))
    END                                   AS cantidad
FROM #Variantes_verona v
INNER JOIN OPENROWSET(
    ''SQLNCLI'',
    ''Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%'',
    ''
    SELECT
        v121_id_barras_principal,
        f400_cant_existencia_1,
        f400_cant_comprometida_1,
        f400_cant_pos_1,
        f150_id
    FROM v121
    INNER JOIN t400_cm_existencia
        ON f400_id_cia = 2
        AND f400_rowid_item_ext = v121_rowid_item_ext
    INNER JOIN dbo.t150_mc_bodegas t150
        ON t150.f150_id_cia = 2
        AND t150.f150_rowid  = f400_rowid_bodega
    WHERE
        v121_id_barras_principal IS NOT NULL
        AND f150_id IN (' + @BodegasIN + N')
    ''
) AS erp
    ON erp.v121_id_barras_principal = v.refid COLLATE DATABASE_DEFAULT
GROUP BY
    v.id_tienda,
    v.id_variante_ecommerce;';

INSERT INTO #InventarioERP_verona (id_tienda, id_variante_ecommerce, id_bodega_ecommerce, cantidad)
EXEC sp_executesql @SqlERP;

-- =============================================
-- Resultado final ensamblado
-- =============================================
CREATE TABLE #ResultadoFinal_Verona (
    id_tienda              INT,
    id_variante            INT,
    id_variante_ecommerce  INT,
    id_bodega_ecommerce    NVARCHAR(10),
    sku_erp                NVARCHAR(20),
    cantidad               INT,
    inventario_obj         NVARCHAR(MAX),
    sincronizado           BIT,
    fecha_sincronizacion   DATETIME2
);

INSERT INTO #ResultadoFinal_Verona (
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
SELECT
    v.id_tienda,
    v.id_variante,
    v.id_variante_ecommerce,
    '1_1'                                       AS id_bodega_ecommerce,
    v.sku_erp,
    ISNULL(i.cantidad, 0)                       AS cantidad,
    JSON_QUERY(
        '{"unlimitedQuantity": false, "quantity": '
        + CAST(ISNULL(i.cantidad, 0) AS VARCHAR(20))
        + ', "dateUtcOnBalanceSystem": "", "timeToRefill (deprecated)": ""}'
    )                                           AS inventario_obj,
    0                                           AS sincronizado,
    GETDATE()                                   AS fecha_sincronizacion
FROM #Variantes_verona v
LEFT JOIN #InventarioERP_verona i
    ON  v.id_variante_ecommerce = i.id_variante_ecommerce
    AND i.id_bodega_ecommerce   = '1_1';

-- =============================================
-- MERGE: upsert atómico (update si cambia cantidad, insert si no existe)
-- =============================================
MERGE dbo.inventarios AS target
USING #ResultadoFinal_Verona AS source
    ON  target.id_tienda             = source.id_tienda
    AND target.id_variante_ecommerce = source.id_variante_ecommerce
    AND target.id_bodega_ecommerce   = source.id_bodega_ecommerce
WHEN MATCHED AND ISNULL(target.cantidad, 0) <> ISNULL(source.cantidad, 0) THEN
    UPDATE SET
        target.cantidad              = source.cantidad,
        target.inventario_obj        = source.inventario_obj,
        target.sincronizado          = 0,
        target.fecha_sincronizacion  = source.fecha_sincronizacion
WHEN NOT MATCHED THEN
    INSERT (
        id_tienda, id_variante, id_variante_ecommerce, id_bodega_ecommerce,
        sku_erp, cantidad, inventario_obj, sincronizado, fecha_sincronizacion
    )
    VALUES (
        source.id_tienda, source.id_variante, source.id_variante_ecommerce,
        source.id_bodega_ecommerce, source.sku_erp, source.cantidad,
        source.inventario_obj, source.sincronizado, source.fecha_sincronizacion
    );

-- =============================================
-- Limpieza de tablas temporales
-- =============================================
DROP TABLE IF EXISTS #Variantes_verona;
DROP TABLE IF EXISTS #InventarioERP_verona;
DROP TABLE IF EXISTS #ResultadoFinal_Verona;