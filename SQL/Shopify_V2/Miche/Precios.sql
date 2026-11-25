-- ============================================================
-- SCRIPT DE SINCRONIZACIÓN DE PRECIOS SHOPIFY DESDE ERP (SIESA)
-- CLIENTE: MICHE
-- LÓGICA:
-- 1. Extrae precios vigentes de Lista Normal ('01') y Lista Descuento ('04') desde Siesa (Cía 2).
-- 2. Si un ítem tiene dos precios:
--    - El precio menor se asigna a 'price'.
--    - El precio mayor se asigna a 'compare_at_price'.
-- 3. Si solo se encuentra un precio por ítem:
--    - Se asigna a 'price' y 'compare_at_price' queda en NULL.
-- ============================================================

-- Declaraciones iniciales
DECLARE @final TABLE (
    id_variante VARCHAR(50) PRIMARY KEY,
    sku_erp     VARCHAR(50),
    precio_obj  VARCHAR(MAX)
);

DECLARE @conexion   VARCHAR(1000), 
        @bd         VARCHAR(100);

-- Obtener configuración de conexión
SELECT TOP 1 
    @conexion   = RTRIM(LTRIM(cadena_conexion)), 
    @bd         = RTRIM(LTRIM(base_datos)) 
FROM conexiones;

DECLARE @db_prefix VARCHAR(150) = CASE 
    WHEN ISNULL(@bd, '') <> '' THEN '[' + @bd + '].dbo.' 
    ELSE '' 
END;

-- ============================================================
-- TABLA TEMPORAL PARA PRECIOS (LISTAS 01 Y 04)
-- ============================================================
IF OBJECT_ID('tempdb..#tmpPrecio') IS NOT NULL 
    DROP TABLE #tmpPrecio;

CREATE TABLE #tmpPrecio (
    f126_rowid_item INT PRIMARY KEY,
    f126_precio_01  DECIMAL(18,2),
    f126_precio_04  DECIMAL(18,2)
);

-- ============================================================
-- OBTENER PRECIOS ACTIVOS DE LISTAS '01' Y '04' (UN SOLO OPENROWSET)
-- ============================================================
INSERT INTO #tmpPrecio (f126_rowid_item, f126_precio_01, f126_precio_04)
EXEC(N'
SELECT 
    f126_rowid_item,
    MAX(CASE WHEN f126_id_lista_precio = ''01'' THEN f126_precio END) AS f126_precio_01,
    MAX(CASE WHEN f126_id_lista_precio = ''04'' THEN f126_precio END) AS f126_precio_04
FROM (
    SELECT 
        f126_rowid_item,
        f126_id_lista_precio,
        f126_precio,
        ROW_NUMBER() OVER (
            PARTITION BY f126_rowid_item, f126_id_lista_precio 
            ORDER BY f126_fecha_activacion DESC
        ) AS rn
    FROM OPENROWSET(
        ''SQLNCLI'', 
        ''' + @conexion + ''',
        ''
            SELECT
                f126_rowid_item,
                f126_id_lista_precio,
                f126_precio,
                f126_fecha_activacion
            FROM ' + @db_prefix + 't126_mc_items_precios
            WHERE f126_id_cia = 2
              AND f126_id_lista_precio IN (''''01'''', ''''04'''')
              AND f126_precio > 0
              AND f126_fecha_activacion <= GETDATE()
              AND (f126_fecha_inactivacion IS NULL OR GETDATE() <= DATEADD(DAY, 1, f126_fecha_inactivacion))
        ''
    )
) AS T
WHERE rn = 1
GROUP BY f126_rowid_item;
');

-- ============================================================
-- OBTENER REFERENCIAS ERP DE LA VISTA V121
-- ============================================================
IF OBJECT_ID('tempdb..#tmpV121') IS NOT NULL 
    DROP TABLE #tmpV121;

CREATE TABLE #tmpV121 (
    v121_referencia VARCHAR(100) PRIMARY KEY,
    v121_rowid_item INT
);

INSERT INTO #tmpV121 (v121_referencia, v121_rowid_item)
EXEC(N'
SELECT
    v121_referencia,
    MIN(v121_rowid_item) AS v121_rowid_item
FROM OPENROWSET(
    ''SQLNCLI'', 
    ''' + @conexion + ''', 
    ''
        SELECT 
            v121_referencia, 
            v121_rowid_item 
        FROM ' + @db_prefix + 'v121
        WHERE v121_id_cia = 2
          AND v121_referencia IS NOT NULL
    '')
GROUP BY v121_referencia;
');

-- ============================================================
-- CONSTRUCCIÓN JSON SHOPIFY: MENOR EN price Y MAYOR EN compare_at_price
-- ============================================================
INSERT INTO @final (id_variante, sku_erp, precio_obj)
SELECT
    Products.id_variante,
    Products.sku_erp,
    precio_obj = (
        SELECT
            [variant.id]               = CAST(Products.id_variante AS NVARCHAR(20)),
            [variant.price]            = CAST(CAST(calc.precio_menor AS DECIMAL(18,0)) AS NVARCHAR(20)),
            [variant.compare_at_price] = CASE 
                                            WHEN calc.cant_precios > 1 AND calc.precio_mayor > calc.precio_menor 
                                            THEN CAST(CAST(calc.precio_mayor AS DECIMAL(18,0)) AS NVARCHAR(20))
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
        MIN(p.val)   AS precio_menor,
        MAX(p.val)   AS precio_mayor,
        COUNT(p.val) AS cant_precios
    FROM (VALUES 
        (tmp.f126_precio_01), 
        (tmp.f126_precio_04)
    ) AS p(val)
    WHERE p.val IS NOT NULL AND p.val > 0
) AS calc
WHERE calc.precio_menor IS NOT NULL;

-- ============================================================
-- RESULTADOS PREVIOS AL MERGE
-- ============================================================
SELECT * FROM @final;

-- ============================================================
-- ACTUALIZACIÓN EN DBO.PRECIOS (MERGE)
-- ============================================================
MERGE INTO dbo.precios AS target
USING @final AS source
    ON target.id_variante = source.id_variante
WHEN MATCHED AND target.precio_obj <> source.precio_obj THEN
    UPDATE SET
        target.precio_obj           = source.precio_obj,
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
        source.precio_obj, 
        0, 
        NULL
    );

-- Limpieza de tablas temporales
IF OBJECT_ID('tempdb..#tmpPrecio') IS NOT NULL DROP TABLE #tmpPrecio;
IF OBJECT_ID('tempdb..#tmpV121') IS NOT NULL DROP TABLE #tmpV121;