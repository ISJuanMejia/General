SET NOCOUNT ON;

-- =============================================
-- Bodegas (valores fijos, tabla de referencia)
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

-- =============================================
-- Variantes sincronizadas de la tienda
-- =============================================
DECLARE @Variantes_verona TABLE (
    id_tienda              INT,
    id_variante            INT,
    sku_erp                VARCHAR(255),
    id_variante_ecommerce  VARCHAR(255),
    refid                  VARCHAR(255),
    INDEX IX_Variantes_RefId       NONCLUSTERED (refid),
    INDEX IX_Variantes_Ecommerce   NONCLUSTERED (id_variante_ecommerce)
);

INSERT INTO @Variantes_verona (
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
-- Inventario calculado desde el ERP
-- =============================================
DECLARE @InventarioERP_verona TABLE (
    id_tienda              INT,
    id_variante_ecommerce  VARCHAR(255),
    id_bodega_ecommerce    VARCHAR(10),
    cantidad               INT,
    INDEX IX_InventarioERP NONCLUSTERED (id_variante_ecommerce, id_bodega_ecommerce)
);

INSERT INTO @InventarioERP_verona (
    id_tienda,
    id_variante_ecommerce,
    id_bodega_ecommerce,
    cantidad
)
SELECT
    v.id_tienda,
    v.id_variante_ecommerce,
    '1_1'                              AS id_bodega_ecommerce,
    CONVERT(
        INT,
        SUM(
            erp.f400_cant_existencia_1
            - (erp.f400_cant_comprometida_1 + erp.f400_cant_pos_1)
        )
    )                                  AS cantidad
FROM @Variantes_verona v
INNER JOIN OPENROWSET(
    'SQLNCLI',
    'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
    '
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
        AND f150_id IN (
            ''10201'', ''10301'', ''10401'', ''10501'',
            ''10601'', ''10701'', ''10801'', ''10901'',
            ''11001'', ''11101'', ''11201'', ''11301'',
            ''11501''
        )
    '
) AS erp
    ON erp.v121_id_barras_principal = v.refid COLLATE DATABASE_DEFAULT
GROUP BY
    v.id_tienda,
    v.id_variante_ecommerce;

-- =============================================
-- Resultado final ensamblado
-- =============================================
DECLARE @ResultadoFinal_Verona TABLE (
    id_tienda              INT,
    id_variante            INT,
    id_variante_ecommerce  VARCHAR(255),
    id_bodega_ecommerce    VARCHAR(10),
    sku_erp                VARCHAR(255),
    cantidad               INT,
    inventario_obj         NVARCHAR(MAX),
    sincronizado           BIT,
    fecha_sincronizacion   DATETIME
);

INSERT INTO @ResultadoFinal_Verona (
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
FROM @Variantes_verona v
LEFT JOIN @InventarioERP_verona i
    ON  v.id_variante_ecommerce = i.id_variante_ecommerce
    AND i.id_bodega_ecommerce   = '1_1';

-- =============================================
-- UPDATE: actualizar registros con cambio de cantidad
-- =============================================
UPDATE target
SET
    target.cantidad              = source.cantidad,
    target.inventario_obj        = source.inventario_obj,
    target.sincronizado          = 0,
    target.fecha_sincronizacion  = source.fecha_sincronizacion
FROM dbo.inventarios target
INNER JOIN @ResultadoFinal_Verona source
    ON  target.id_tienda             = source.id_tienda
    AND target.id_variante_ecommerce = source.id_variante_ecommerce
    AND target.id_bodega_ecommerce   = source.id_bodega_ecommerce
WHERE
    ISNULL(target.cantidad, 0) <> ISNULL(source.cantidad, 0);

-- =============================================
-- INSERT: registros nuevos que no existen aún
-- =============================================
INSERT INTO dbo.inventarios (
    id_tienda, id_variante, id_variante_ecommerce, id_bodega_ecommerce,
    sku_erp, cantidad, inventario_obj, sincronizado, fecha_sincronizacion
)
SELECT
    source.id_tienda,
    source.id_variante,
    source.id_variante_ecommerce,
    source.id_bodega_ecommerce,
    source.sku_erp,
    source.cantidad,
    source.inventario_obj,
    source.sincronizado,
    source.fecha_sincronizacion
FROM @ResultadoFinal_Verona source
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.inventarios target
    WHERE
        target.id_tienda             = source.id_tienda
        AND target.id_variante_ecommerce = source.id_variante_ecommerce
        AND target.id_bodega_ecommerce   = source.id_bodega_ecommerce
);