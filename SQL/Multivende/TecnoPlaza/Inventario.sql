-- Eliminar duplicados dejando solo el más reciente
WITH CTE AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY 
                warehouse, 
                sku 
            ORDER BY fecha_sincronizacion DESC
        ) AS rn
    FROM dbo.inventario
)
DELETE FROM CTE 
WHERE rn > 1;

DECLARE @conexion   NVARCHAR(MAX);
DECLARE @base_datos NVARCHAR(MAX);

SELECT
    @conexion   =   cadena_conexion,
    @base_datos =   base_datos
FROM conexiones;

DECLARE @productos  TABLE
(
    sku     NVARCHAR(200),
    marca   NVARCHAR(300)
);

INSERT INTO @productos
SELECT 
    [sku]   =   Variantes.SKU, 
    [marca] =   productos.marca
FROM productos
    INNER JOIN Variantes
        ON
            Variantes.productoid    =   productos.productoid
GROUP BY Variantes.SKU, productos.marca

DECLARE @stock_ecommerce    TABLE
(
    warehouse       NVARCHAR(1000),
    sku             NVARCHAR(1000),
    amount          NVARCHAR(1000),
    idStoreSiesa    NVARCHAR(1000),
    marca           NVARCHAR(300)
);

INSERT INTO @stock_ecommerce
SELECT
    [warehouse]     =   warehouse, 
    [sku]           =   stockProduct.sku, 
    [amount]        =   amount, 
    [idStoreSiesa]  =   idStoreSiesa, 
    [marca]         =   p.marca
FROM stockProduct 
    INNER JOIN warehouse 
        ON
            stockProduct.warehouse = warehouse.idStore
	INNER JOIN @productos p 
        ON
            stockProduct.sku = p.sku
ORDER BY stockProduct.sku, idStoreSiesa;

DECLARE @stock_siesa    TABLE
(
    cantidad    INT,
    codigo_barras   NVARCHAR(50),
    descripcion     NVARCHAR(200),
    bodega          NVARCHAR(5)
);

INSERT INTO @stock_siesa
EXEC(
'
    SELECT 
		[cantidad]      =   SUM(a.cantidad),
		[codigo_barras] =   a.codigo_barras,
		[descripcion]   =   a.descripcion,
		[bodega]        =   a.bodega
    FROM OPENROWSET(
        ''sqlncli'',
        ''' + @conexion + ''',
        ''
            SELECT 
			    [cantidad]      =   
                    CAST(
                        ISNULL(
                            (
                                f400_cant_existencia_1 - (
                                    f400_cant_comprometida_1 + f400_cant_pos_1
                                )
                            ),
                            0
                        ) AS INT
                    ),
			    [codigo_barras] =   v121_referencia,
			    [descripcion]   =   v121_descripcion,
			    [bodega]        =   f150_id
            FROM ' + @base_datos + '.dbo.t400_cm_existencia t400
                INNER JOIN ' + @base_datos + '.dbo.v121 v121
                    ON
                        v121.v121_rowid_item_ext    =   t400.f400_rowid_item_ext
                INNER JOIN ' + @base_datos + '.dbo.t150_mc_bodegas b 
                    ON
                        t400.f400_rowid_bodega  =   b.f150_rowid 
                        AND 
                        t400.f400_id_cia        =   b.f150_id_cia
            WHERE
                v121_referencia IS NOT NULL
                AND 
                f150_id IN (''''01'''',''''02'''')
        ''
    ) AS a
    GROUP BY a.codigo_barras, a.descripcion, a.bodega
');

MERGE INTO dbo.inventario AS TARGET
USING (
	SELECT
        [warehouse] =   a.warehouse, 
        [sku]       =   a.sku,
        [cantidad]  =   MAX(b.cantidad)
	FROM @stock_ecommerce AS a
		INNER JOIN @stock_siesa AS b
            ON
                CASE      
					WHEN
                        a.sku   LIKE    '%-%' 
                        AND 
                        UPPER(a.marca)  LIKE    '%HP%' 
						THEN
                            REPLACE(a.sku,'-','#')
					WHEN
                        a.sku   LIKE    '%-%' 
                        AND 
                        UPPER(a.marca)  LIKE    '%APPLE%'
						THEN
                            REPLACE(a.sku,'-','/')
					ELSE    a.sku
				END =   b.codigo_barras 
		        AND
                a.idStoreSiesa  =   b.bodega
	WHERE
        cantidad    <>  CAST(a.amount AS INT)
    GROUP BY
        a.warehouse,
        a.sku
) AS SOURCE
    ON
        TARGET.sku          =   SOURCE.sku 
        AND
        TARGET.warehouse    =   SOURCE.warehouse
    WHEN 
        MATCHED 
        AND 
        TARGET.errorStock   =   0
        AND
        TARGET.amount       !=  SOURCE.cantidad
        THEN
	        UPDATE SET
		        TARGET.inventario_obj       = 
                    JSON_QUERY(
                        (
				            SELECT 
					            [code]      =   source.sku,
					            [amount]    =   source.cantidad
				            FOR JSON PATH, 
                            WITHOUT_ARRAY_WRAPPER
                        )
                    ),
		        TARGET.amount               =   source.cantidad,
		        TARGET.sincronizado         =   0,
		        TARGET.fecha_sincronizacion =   NULL
    WHEN 
        NOT MATCHED BY TARGET 
        THEN
	        INSERT (
	            warehouse,
                sku,
                amount,
                sincronizado,
                fecha_sincronizacion,
                inventario_obj,
                errorStock
	        )
	        VALUES (
		        source.warehouse,  
		        source.sku,
		        source.cantidad,
		        0,
		        NULL,
		        JSON_QUERY(
                    (
			            SELECT 
				            [code]      =   source.sku,
				            [amount]    =   source.cantidad
			            FOR JSON PATH, 
                        WITHOUT_ARRAY_WRAPPER
                    )
                ),
		        0
	        );