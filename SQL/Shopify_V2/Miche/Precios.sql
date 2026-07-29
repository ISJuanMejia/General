-- ============================================================
-- SCRIPT DE SINCRONIZACIÓN DE PRECIOS SHOPIFY DESDE ERP (SIESA)
-- Lógica:
-- 1. Extrae precios de Lista Normal ('01') y Lista Descuento ('04').
-- 2. El precio menor activo se asigna a 'price'.
-- 3. El precio mayor activo se asigna a 'compare_at_price' (solo si es superior al precio menor).
-- ============================================================

-- Declaraciones iniciales
DECLARE @final TABLE(
    id_variante VARCHAR(50) PRIMARY KEY,
    sku_erp     VARCHAR(50),
    json        VARCHAR(MAX)
);

DECLARE @conexion   VARCHAR(1000), 
        @bd         VARCHAR(100);

-- Obtener configuración de conexión
SELECT TOP 1 
    @conexion   = cadena_conexion, 
    @bd         = base_datos 
FROM conexiones;

-- ============================================================
-- TABLA TEMPORAL PARA PRECIOS (LISTA 01 NORMAL Y LISTA 04 DESCUENTO)
-- ============================================================
IF OBJECT_ID('tempdb..#tmpPrecio') IS NOT NULL 
    DROP TABLE #tmpPrecio;

CREATE TABLE #tmpPrecio (
    f126_rowid_item        INT PRIMARY KEY,
    f126_precio_normal      DECIMAL(18,2),
    f126_precio_descuento   DECIMAL(18,2)
);

-- ============================================================
-- OBTENER PRECIOS ACTIVOS DE AMBAS LISTAS DE PRECIO
-- ============================================================
INSERT INTO #tmpPrecio (f126_rowid_item, f126_precio_normal, f126_precio_descuento)
EXEC(N'
SELECT 
    COALESCE(NORMAL.f126_rowid_item, DESCUENTO.f126_rowid_item) AS f126_rowid_item,
    NORMAL.f126_precio     AS f126_precio_normal,
    DESCUENTO.f126_precio  AS f126_precio_descuento
FROM 
    (
        SELECT f126_rowid_item, f126_precio
        FROM (
            SELECT 
                f126_rowid_item, 
                f126_precio,
                ROW_NUMBER() OVER(PARTITION BY f126_rowid_item ORDER BY f126_fecha_activacion DESC) AS rn
            FROM OPENROWSET(
                ''SQLNCLI'', 
                ''' + @conexion + ''',
                ''
                    SELECT
                        f126_rowid_item,
                        f126_precio,
                        f126_fecha_activacion
                    FROM t126_mc_items_precios
                    WHERE f126_id_lista_precio = ''''01''''
                      AND f126_precio > 0
                      AND f126_fecha_activacion <= GETDATE()
                      AND (f126_fecha_inactivacion IS NULL OR GETDATE() <= DATEADD(DAY, 1, f126_fecha_inactivacion))
                ''
            )
        ) AS T1 WHERE T1.rn = 1
    ) AS NORMAL
    FULL OUTER JOIN
    (
        SELECT f126_rowid_item, f126_precio
        FROM (
            SELECT 
                f126_rowid_item, 
                f126_precio,
                ROW_NUMBER() OVER(PARTITION BY f126_rowid_item ORDER BY f126_fecha_activacion DESC) AS rn
            FROM OPENROWSET(
                ''SQLNCLI'', 
                ''' + @conexion + ''',
                ''
                    SELECT
                        f126_rowid_item,
                        f126_precio,
                        f126_fecha_activacion
                    FROM t126_mc_items_precios
                    WHERE f126_id_lista_precio = ''''04''''
                      AND f126_precio > 0
                      AND f126_fecha_activacion <= GETDATE()
                      AND (f126_fecha_inactivacion IS NULL OR GETDATE() <= DATEADD(DAY, 1, f126_fecha_inactivacion))
                ''
            )
        ) AS T2 WHERE T2.rn = 1
    ) AS DESCUENTO
        ON DESCUENTO.f126_rowid_item = NORMAL.f126_rowid_item
');

-- ============================================================
-- OBTENER REFERENCIAS ERP DE LA VISTA V121
-- ============================================================
IF OBJECT_ID('tempdb..#tmpV121') IS NOT NULL 
    DROP TABLE #tmpV121;

CREATE TABLE #tmpV121 (
    v121_referencia VARCHAR(100),
    v121_rowid_item INT
);

INSERT INTO #tmpV121 (v121_referencia, v121_rowid_item)
EXEC(N'
SELECT
    v121_referencia,
    v121_rowid_item
FROM OPENROWSET(
    ''SQLNCLI'', 
    ''' + @conexion + ''', 
    ''
        SELECT 
            v121_referencia, 
            v121_rowid_item 
        FROM [' + @bd + '].dbo.v121
        WHERE v121_id_cia = 2
          AND v121_referencia IS NOT NULL
    '')
');

CREATE INDEX IX_tmpV121_referencia ON #tmpV121(v121_referencia);
CREATE INDEX IX_tmpV121_item ON #tmpV121(v121_rowid_item);

-- ============================================================
-- QUERY PRINCIPAL: DETERMINAR PRECIO MENOR (price) Y MAYOR (compare_at_price)
-- ============================================================
INSERT INTO @final (id_variante, sku_erp, json)
SELECT
    Products.id_variante,
    Products.sku_erp,
    json = (
        SELECT
            [variant.id]               = CAST(Products.id_variante AS NVARCHAR(20)),
            [variant.price]            = CAST(CAST(calc.precio_inferior AS DECIMAL(18,0)) AS NVARCHAR(20)),
            [variant.compare_at_price] = CASE 
                                            WHEN calc.cant_precios > 1 AND calc.precio_superior > calc.precio_inferior 
                                            THEN CAST(CAST(calc.precio_superior AS DECIMAL(18,0)) AS NVARCHAR(20))
                                            ELSE NULL 
                                         END
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    )
FROM variantes AS Products
INNER JOIN #tmpV121 AS v121 
    ON v121.v121_referencia = Products.sku_erp
INNER JOIN #tmpPrecio AS tmp 
    ON tmp.f126_rowid_item = v121.v121_rowid_item
CROSS APPLY (
    SELECT 
        MIN(p.val)   AS precio_inferior,
        MAX(p.val)   AS precio_superior,
        COUNT(p.val) AS cant_precios
    FROM (VALUES 
        (tmp.f126_precio_normal), 
        (tmp.f126_precio_descuento)
    ) AS p(val)
    WHERE p.val IS NOT NULL AND p.val > 0
) AS calc
WHERE calc.precio_inferior IS NOT NULL;

-- ============================================================
-- MOSTRAR RESULTADOS GENERADOS
-- ============================================================
SELECT * FROM @final;

-- ============================================================
-- ACTUALIZACIÓN EN DBO.PRECIOS (MERGE)
-- ============================================================
MERGE INTO dbo.precios AS target
USING @final AS source
    ON target.id_variante = source.id_variante
WHEN MATCHED AND target.precio_obj <> source.json THEN
    UPDATE SET
        target.precio_obj           = source.json,
        target.sincronizado         = 0,
        target.fecha_sincronizacion = NULL
WHEN NOT MATCHED BY TARGET THEN
    INSERT (
        id_variante, 
        sku_erp, 
        precio_obj, 
        sincronizado, 
        fecha_sincronizacion
    )
    VALUES (
        source.id_variante, 
        source.sku_erp, 
        source.json, 
        0, 
        NULL
    );

-- Limpieza de tablas temporales
IF OBJECT_ID('tempdb..#tmpPrecio') IS NOT NULL DROP TABLE #tmpPrecio;
IF OBJECT_ID('tempdb..#tmpV121') IS NOT NULL DROP TABLE #tmpV121;