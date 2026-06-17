------------------------------------------------------------
-- PASO 0: ELIMINAR DUPLICADOS EXISTENTES EN dbo.inventarios
-- Se deja solo el registro más reciente por llave lógica
------------------------------------------------------------
WITH CTE_Duplicados AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY id_tienda, id_variante_ecommerce, id_bodega_ecommerce
               ORDER BY fecha_sincronizacion DESC
           ) AS rn
    FROM dbo.inventarios
)
DELETE FROM CTE_Duplicados
WHERE rn > 1;

DECLARE @variantes TABLE
(
    id_tienda               INT,
    id_variante             NVARCHAR(255),
    sku_erp                 NVARCHAR(255),
    id_variante_ecommerce   NVARCHAR(255)
)

-- Paso 1: Extraer datos de variantes relevantes
INSERT INTO @variantes
SELECT 
    id_tienda               =   p.id_tienda,
    id_variante             =   v.id,
    sku_erp                 =   v.sku_erp,
    id_variante_ecommerce   =   v.id_variante_ecommerce
FROM    variantes   v
    INNER JOIN productos p
        ON
            p.id_producto_ecommerce =   v.id_producto_ecommerce
WHERE
    p.id_tienda     =   1 
    AND
    v.sincronizado  =   1;

DECLARE @inventario_erp TABLE
(
    id_tienda               INT,
    id_variante_ecommerce   NVARCHAR(255),
    id_bodega_ecommerce     NVARCHAR(255),
    cantidad                INT
);

-- Paso 2: Calcular cantidades del ERP por variante y bodega (OPENROWSET optimizado)
INSERT INTO @inventario_erp
SELECT 
    id_tienda               =   p.id_tienda,
    id_variante_ecommerce   =   v.id_variante_ecommerce,
    id_bodega_ecommerce     =   '148184e',
    cantidad                =   TRY_CONVERT(INT, erp.cantidad)
FROM variantes v
    INNER JOIN productos p
        ON
            p.id_producto_ecommerce = v.id_producto_ecommerce
    INNER JOIN OPENROWSET(
        'SQLNCLI',
        'Server=siesa-m3-sqlsw-db13.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_Maderkit_Real;UID=maderkit;PWD=Maderkit$12$%',
        '
		    SELECT 
			    codigo_barras,
			    f150_id,
			    SUM(cantidad) AS cantidad
		    FROM (
			    SELECT
			    	codigo_barras   =   IE.f121_id_barras_principal,
			    	t150.f150_id,
			    	cantidad    =   (ISNULL(f400_cant_existencia_1, 0) - (ISNULL(f400_cant_comprometida_1, 0) + ISNULL(f400_cant_pos_1,0)))
			    FROM t121_mc_items_extensiones IE 
			        INNER JOIN t400_cm_existencia
                        ON
                            f400_rowid_item_ext =   f121_rowid_item AND f400_id_cia = 1
			        INNER JOIN t150_mc_bodegas t150
                        ON
                            f150_rowid  =   f400_rowid_bodega AND t150.f150_id_cia = 1
			    WHERE
                    IE.f121_id_barras_principal IS NOT NULL
			    UNION ALL
			    SELECT
			    	codigo_barras   =   IB.f131_id,
			    	t150.f150_id,
			    	cantidad        =   (f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1))
			    FROM t121_mc_items_extensiones IE 
			        INNER JOIN t400_cm_existencia
                        ON
                            f400_rowid_item_ext =   f121_rowid_item 
                            AND 
                            f400_id_cia =   1
			        INNER JOIN t150_mc_bodegas t150 
                        ON
                            f150_rowid  =   f400_rowid_bodega 
                            AND 
                            t150.f150_id_cia    =   1
			        INNER JOIN t131_mc_items_barras IB 
                        ON
                            IB.f131_rowid_item_ext  =   IE.f121_rowid_item
			    WHERE 
                    IB.f131_id IS NOT NULL
                    AND 
                    NOT EXISTS (
			    	    SELECT 1
			    	    FROM t121_mc_items_extensiones IE2
			    	    WHERE
                            IE2.f121_id_barras_principal    =   IB.f131_id
			        )
                ) X
		WHERE 
            f150_id IN (''PT11'')
		GROUP BY codigo_barras, f150_id
    '
) AS erp
    ON
        erp.codigo_barras   =   v.sku_erp COLLATE DATABASE_DEFAULT
        AND
        p.id_tienda =   1
GROUP BY p.id_tienda, v.id_variante_ecommerce,cantidad;

DECLARE @resultado  TABLE
(
    id_tienda               INT,
    id_variante             NVARCHAR(255),
    id_variante_ecommerce   NVARCHAR(255),
    id_bodega_ecommerce     NVARCHAR(255),
    sku_erp                 NVARCHAR(255),
    cantidad                INT,
    inventario_obj          NVARCHAR(MAX),
    sincronizado            BIT,
    fecha_sincronizacion    DATETIME
);

-- Paso 3: Generar combinaciones de variantes con las bodegas ('PT11')
INSERT INTO @resultado
SELECT  
    id_tienda               =   v.id_tienda,
    id_variante             =   v.id_variante,
    id_variante_ecommerce   =   v.id_variante_ecommerce,
    id_bodega_ecommerce     =   b.id_bodega_ecommerce,
    sku_erp                 =   v.sku_erp,
    cantidad                =   ISNULL(i.cantidad, 0),
    inventario_obj          =   
        JSON_QUERY(
            '
                {
                    "unlimitedQuantity": false,
                    "quantity": ' + CAST(ISNULL(i.cantidad, 0) AS VARCHAR) + ',
                    "dateUtcOnBalanceSystem": "",
                    "timeToRefill (deprecated)": ""
                }
            '
        ),
    sincronizado            =0,
    fecha_sincronizacion    =GETDATE()
FROM @variantes v
CROSS JOIN (VALUES ('148184e')) b(id_bodega_ecommerce)
    LEFT JOIN @inventario_erp i
        ON v.id_variante_ecommerce = i.id_variante_ecommerce
        AND b.id_bodega_ecommerce = i.id_bodega_ecommerce;

DECLARE @resultado_sin_duplicados  TABLE
(
    id_tienda               INT,
    id_variante             NVARCHAR(255),
    id_variante_ecommerce   NVARCHAR(255),
    id_bodega_ecommerce     NVARCHAR(255),
    sku_erp                 NVARCHAR(255),
    cantidad                INT,
    inventario_obj          NVARCHAR(MAX),
    sincronizado            BIT,
    fecha_sincronizacion    DATETIME,
    rn                      INT
);

-- Paso 4: Eliminar duplicados en @resultado
WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY id_tienda, id_variante_ecommerce, id_bodega_ecommerce ORDER BY fecha_sincronizacion DESC) AS rn
    FROM @resultado
)
INSERT INTO @resultado_sin_duplicados
SELECT *
FROM CTE
WHERE rn = 1;

SELECT * FROM @resultado_sin_duplicados

/*
--Paso 5: MERGE para actualizar las filas que tienen diferencias
MERGE INTO dbo.inventarios AS target
USING (
    SELECT *
    FROM @resultado_sin_duplicados
) AS source
ON (target.id_tienda = source.id_tienda
    AND target.id_variante_ecommerce = source.id_variante_ecommerce 
    AND target.id_bodega_ecommerce = source.id_bodega_ecommerce)
WHEN MATCHED AND ISNULL(target.cantidad, 0) <> ISNULL(source.cantidad, 0) THEN
    UPDATE SET 
        target.cantidad = source.cantidad,
        target.inventario_obj = source.inventario_obj,
        target.sincronizado = 0,
        target.fecha_sincronizacion = source.fecha_sincronizacion
WHEN NOT MATCHED THEN
    INSERT (id_tienda, id_variante, id_variante_ecommerce, id_bodega_ecommerce,
	sku_erp, cantidad, inventario_obj, sincronizado, fecha_sincronizacion)
    VALUES (source.id_tienda, source.id_variante, source.id_variante_ecommerce,
	source.id_bodega_ecommerce, source.sku_erp, source.cantidad, source.inventario_obj, source.sincronizado, source.fecha_sincronizacion);
*/