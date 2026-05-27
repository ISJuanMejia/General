/** CLEMONT - CREACIÓN DE PRODUCTOS EN SHOPIFY DESDE SIESA **/
DECLARE @t117_mc_extensiones1_detalle TABLE   (
    f117_descripcion    NVARCHAR(255)
    ,f117_id            VARCHAR(255)
    ,f117_id_cia        VARCHAR(2)
);

DECLARE @t119_mc_extensiones2_detalle TABLE   (
    f119_descripcion    NVARCHAR(255)
    ,f119_id            VARCHAR(255)
    ,f119_id_cia        VARCHAR(2)
);

DECLARE @t120_mc_items TABLE   (
    f120_rowid          VARCHAR(10)
    ,f120_descripcion   NVARCHAR(255)
);

DECLARE @t121_mc_items_extensiones TABLE   (
    f121_rowid                  VARCHAR(10)
    ,f121_rowid_item            VARCHAR(10)
    ,f121_id_ext1_detalle       VARCHAR(50)
    ,f121_id_ext2_detalle       VARCHAR(50)
    ,f121_id_cia                VARCHAR(2)
    ,f121_id_barras_principal   NVARCHAR(50)
);

DECLARE @t125_mc_items_criterios TABLE (
    f125_id_plan                NVARCHAR(3)
    ,f125_id_criterio_mayor     NVARCHAR(4)
    ,f125_rowid_item            VARCHAR(10)
);

DECLARE @t126_mc_items_precios TABLE (
    f126_rowid_item                 VARCHAR(10)
    ,f126_rowid_item_ext            VARCHAR(10)
    ,f126_precio                    DECIMAL(18, 2)
    ,f126_fecha_ts_actualizacion    DATETIME
);

DECLARE	@conexion	            VARCHAR(200)
		,@bd		            VARCHAR(100)

DECLARE	@product_vendor			NVARCHAR(10)	=	'CLEMONT'
DECLARE	@productDefaultStatus	NVARCHAR(10)	=	'draft'
-- DECLARE @IdPlan                 VARCHAR(3)  	=   '010'
DECLARE @FechaInicio            DATETIME    	=   '2026-04-24'
DECLARE @IdListaPrecio         	VARCHAR(3) 		=   'LP1'
DECLARE @TipoExtension1         VARCHAR(5)  	=   'Color'
DECLARE @TipoExtension2         VARCHAR(5)  	=   'Talla'
-- DECLARE @IdCriterioMayor        VARCHAR(4)		=   '0001'
DECLARE @InventoryManagement    NVARCHAR(10)	=	'shopify'
 
SELECT TOP 1 
	@conexion   =   cadena_conexion,
    @bd         =   base_datos 
FROM conexiones

SELECT
        @conexion   =   'server=ec2-3-216-46-219.compute-1.amazonaws.com;Database=UnoEE_Clemontco_Pruebas;UID=Clemontco;PWD=Clemontco$12$%;', 
        @bd         =   'UnoEE_Clemontco_Pruebas'

/*	t117	-	Extensiones Detalle 1	*/
INSERT INTO @t117_mc_extensiones1_detalle (f117_descripcion, f117_id, f117_id_cia)
EXEC('
	SELECT
		TRIM(f117_descripcion)	AS	f117_descripcion
		,f117_id
		,f117_id_cia
	FROM OPENROWSET(
		''sqlncli''
 		,''' + @conexion + '''
 		,
		''
			SELECT
				f117_descripcion
				,f117_id
				,f117_id_cia
			FROM '+ @bd + '.dbo.t117_mc_extensiones1_detalle
			WHERE
				f117_descripcion	IS NOT NULL
				OR
				f117_descripcion	<>	''''''''
				OR	
				f117_descripcion	!=	''''NO APLICA''''
		''
	)
');

/*	t119	-	Extensiones Detalle 2	*/
INSERT INTO @t119_mc_extensiones2_detalle (f119_descripcion, f119_id, f119_id_cia)
EXEC('
	SELECT
		TRIM(f119_descripcion)	AS	f119_descripcion
		,f119_id
		,f119_id_cia
	FROM OPENROWSET(
		''sqlncli''
 		,''' + @conexion + '''
 		,
		''
			SELECT
				f119_descripcion
				,f119_id
				,f119_id_cia
			FROM '+ @bd + '.dbo.t119_mc_extensiones2_detalle
			WHERE
				f119_descripcion	IS NOT NULL
				OR
				f119_descripcion	<>	''''''''
				OR	
				f119_descripcion	!=	''''NO APLICA''''
		''
	)
');

/*	t120	-	Items	*/

INSERT INTO @t120_mc_items (f120_rowid, f120_descripcion)
EXEC('
	SELECT
		f120_rowid
		,f120_descripcion
	FROM	OPENROWSET(
		''sqlncli''
 		,''' + @conexion + '''
 		,
		''
			SELECT DISTINCT
				f120_rowid
				,f120_descripcion
			FROM	' + @bd + '.dbo.t120_mc_items
			WHERE
				f120_ts > ''''' + @FechaInicio + '''''
		''
	)
');

/*	t121	-	Item extensiones	*/

INSERT INTO @t121_mc_items_extensiones (f121_rowid, f121_rowid_item, f121_id_ext1_detalle, f121_id_ext2_detalle, f121_id_cia, f121_id_barras_principal)
EXEC('
	SELECT DISTINCT
		f121_rowid
		,f121_rowid_item
		,f121_id_ext1_detalle
		,f121_id_ext2_detalle
		,f121_id_cia
		,f121_id_barras_principal
	FROM OPENROWSET(
		''sqlncli''
 		,''' + @conexion + '''
 		,
		''
			SELECT DISTINCT
				f121_rowid
				,f121_rowid_item
				,f121_id_ext1_detalle
				,f121_id_ext2_detalle
				,f121_id_cia
				,f121_id_barras_principal
			FROM	' + @bd + '.dbo.t121_mc_items_extensiones
            WHERE
                (
                    f121_fecha_actualizacion    >   ''''' + @FechaInicio + '''''
                    OR
                    f121_fecha_creacion         >   ''''' + @FechaInicio + '''''
                )
                -- AND
                -- (
                --     f121_id_barras_principal IS NOT NULL
                --     AND
                --     TRIM(f121_id_barras_principal) <> ''''''''
                -- )
		''
	)
');

/*	t125	-	Items Criterios	*/

-- INSERT INTO @t125_mc_items_criterios (f125_id_plan, f125_id_criterio_mayor, f125_rowid_item)
-- EXEC('
-- 	SELECT DISTINCT
-- 		f125_id_plan
-- 		,f125_id_criterio_mayor
-- 		,f125_rowid_item
-- 	FROM OPENROWSET(
-- 		''sqlncli''
--  		,''' + @conexion + '''
--  		,
-- 		''
-- 			SELECT DISTINCT
-- 				f125_id_plan
-- 				,f125_id_criterio_mayor
-- 				,f125_rowid_item
-- 			FROM	' + @bd + '.dbo.t125_mc_items_criterios
-- 			WHERE
-- 				f125_id_plan    =   ''''' + @IdPlan + '''''  
--     			AND
-- 				f125_id_criterio_mayor  =   ' + @IdCriterioMayor + '
-- 		''
-- 	)
-- ')

/*	t126	-	Lista de precios	*/

INSERT INTO @t126_mc_items_precios (f126_rowid_item, f126_rowid_item_ext, f126_precio, f126_fecha_ts_actualizacion)
EXEC('
	SELECT DISTINCT
		f126_rowid_item
        ,f126_rowid_item_ext
		,f126_precio
		,f126_fecha_ts_actualizacion
	FROM OPENROWSET(
		''sqlncli''
 		,''' + @conexion + '''
 		,
		''
			SELECT DISTINCT
				f126_rowid_item
                ,f126_rowid_item_ext
				,f126_precio
				,f126_fecha_ts_actualizacion
			FROM	' + @bd + '.dbo.t126_mc_items_precios
			WHERE
				f126_id_lista_precio    =   ''''' + @IdListaPrecio + '''''
		''
	)
');

SELECT
    JSON_QUERY((
        SELECT
            TRIM(t120.f120_descripcion)		AS	[product.title],
            TRIM(t120.f120_descripcion)		AS	[product.body_html],
            @product_vendor				AS	[product.vendor],
            SUBSTRING(
                f120_descripcion,
                1,
                CHARINDEX(' ', f120_descripcion + ' ') - 1
            )						AS	[product.product_type],
            @productDefaultStatus		AS	[product.status],
            (
                SELECT DISTINCT
                    CASE
                        WHEN TRIM(f117_descripcion) != 'NO APLICA' THEN TRIM(f117_descripcion)
                        ELSE ''
                    END											AS	[option1],
                    CASE
                        WHEN TRIM(f119_descripcion) != 'NO APLICA' THEN TRIM(f119_descripcion)
                        ELSE ''
                    END											AS	[option2],
                    (
                        SELECT 
                            f126_precio
                        FROM @t126_mc_items_precios
                        WHERE 
                            (   
                                f126_rowid_item =   f120_rowid
                                OR
                                f126_rowid_item_ext = f121_rowid
                            )
                            AND 
                            f126_fecha_ts_actualizacion = (
                                SELECT MAX(f126_fecha_ts_actualizacion)
                                FROM @t126_mc_items_precios
                                WHERE 
                                f126_rowid_item =   f120_rowid
                                OR
                                f126_rowid_item_ext = f121_rowid
                            )
                    )											AS	[price],
                    t121_variantes.f121_id_barras_principal	AS	[sku],
                    t121_variantes.f121_id_barras_principal	AS	[barcode],
                    @InventoryManagement            AS	[inventory_management]
                FROM @t121_mc_items_extensiones	AS	t121_variantes
                    INNER JOIN	@t117_mc_extensiones1_detalle	AS	t117	ON
                        t117.f117_id	=	t121_variantes.f121_id_ext1_detalle
                        AND
                        t117.f117_id_cia	=	t121_variantes.f121_id_cia
                    LEFT JOIN	@t119_mc_extensiones2_detalle	AS	t119	ON 
                        t119.f119_id	=	t121_variantes.f121_id_ext2_detalle
                        AND
                        t119.f119_id_cia	=	t121_variantes.f121_id_cia
                    LEFT JOIN @t126_mc_items_precios	AS	t126		ON
                        (
                            t126.f126_rowid_item	=	t120.f120_rowid
                            OR
                            t126.f126_rowid_item_ext = t121_variantes.f121_rowid
                        )
                    LEFT JOIN variantes	AS	v	ON
                        v.sku_erp = t121_variantes.f121_id_barras_principal
                WHERE
                    f121_rowid_item	=	f120_rowid
                    AND
                    v.sku_erp	IS NULL
                FOR JSON PATH
            )	AS	[product.variants],
            (
                SELECT
                    [name],
                    JSON_QUERY('[' + STRING_AGG('"' + STRING_ESCAPE([values], 'json') + '"', ',') + ']') AS [values]
                FROM (
                    SELECT DISTINCT
                        @TipoExtension1				AS	[name],
                        f117_descripcion			AS	[values]
                    FROM @t121_mc_items_extensiones	AS	t121_ext1
                        INNER JOIN @t117_mc_extensiones1_detalle	ON 
                            f117_id = f121_id_ext1_detalle 
                            AND 
                            f117_id_cia = f121_id_cia
                        LEFT JOIN variantes	AS	v	ON
                            v.sku_erp = t121_ext1.f121_id_barras_principal
                    WHERE 
                        f121_rowid_item = f120_rowid 
                        AND
                        v.sku_erp IS NULL
                        AND (
                            TRIM(f117_descripcion) IS NOT NULL 
                            OR 
                            TRIM(f117_descripcion) <> '' 
                            OR 
                            TRIM(f117_descripcion) != 'NO APLICA'
                        )
                    UNION ALL
                    SELECT DISTINCT 
                        @TipoExtension2				AS	[name],
                        f119_descripcion			AS	[values]
                    FROM @t121_mc_items_extensiones	AS	t121_ext2
                        INNER JOIN @t119_mc_extensiones2_detalle	ON 
                            f119_id = f121_id_ext2_detalle 
                            AND 
                            f119_id_cia = f121_id_cia
                        LEFT JOIN variantes	AS	v	ON
                            v.sku_erp = t121_ext2.f121_id_barras_principal
                    WHERE 
                        f121_rowid_item = f120_rowid 
                        AND
                        v.sku_erp IS NULL
                        AND 
                        (
                            TRIM(f119_descripcion) IS NOT NULL 
                            AND 
                            TRIM(f119_descripcion) <> '' 
                            AND 
                            TRIM(f119_descripcion) != 'NO APLICA'
                        )
                ) AS options_union
                GROUP BY [name]
                FOR JSON PATH
            )	AS	[product.options]
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )) AS ProductJSON
FROM @t120_mc_items AS t120
WHERE
    EXISTS (
		SELECT *
        FROM @t121_mc_items_extensiones	AS	t121_variantes
            INNER JOIN	@t117_mc_extensiones1_detalle	AS	t117	ON
                t117.f117_id	=	t121_variantes.f121_id_ext1_detalle
                AND
                t117.f117_id_cia	=	t121_variantes.f121_id_cia
            LEFT JOIN	@t119_mc_extensiones2_detalle	AS	t119	ON 
                t119.f119_id	=	t121_variantes.f121_id_ext2_detalle
                AND
                t119.f119_id_cia	=	t121_variantes.f121_id_cia
            LEFT JOIN @t126_mc_items_precios	AS	t126		ON
                t126.f126_rowid_item	=	t120.f120_rowid
                OR
                t126.f126_rowid_item_ext = t121_variantes.f121_rowid
            LEFT JOIN variantes	AS	v	ON
                v.sku_erp = t121_variantes.f121_id_barras_principal
		WHERE
            f121_rowid_item	=	f120_rowid
            AND
            v.sku_erp	IS NULL
    )
    AND 
	EXISTS (
        SELECT DISTINCT
			@TipoExtension1				AS	[name],
            f117_descripcion			AS	[value]
            FROM @t121_mc_items_extensiones	AS	t121_ext1
                INNER JOIN @t117_mc_extensiones1_detalle	ON 
                    f117_id = f121_id_ext1_detalle 
                    AND 
                    f117_id_cia = f121_id_cia
                LEFT JOIN variantes	AS	v	ON
                    v.sku_erp = t121_ext1.f121_id_barras_principal
            WHERE 
                f121_rowid_item = f120_rowid 
                AND
                v.sku_erp IS NULL
                AND (
                    TRIM(f117_descripcion) IS NOT NULL 
                    OR 
                    TRIM(f117_descripcion) <> '' 
                    OR 
                    TRIM(f117_descripcion) != 'NO APLICA'
                )
                UNION ALL
                SELECT DISTINCT 
                    @TipoExtension2				AS	[name],
                    f119_descripcion			AS	[value]
                FROM @t121_mc_items_extensiones	AS	t121_ext2
                    INNER JOIN @t119_mc_extensiones2_detalle	ON 
                        f119_id = f121_id_ext2_detalle 
                        AND 
                        f119_id_cia = f121_id_cia
                    LEFT JOIN variantes	AS	v	ON
                        v.sku_erp = t121_ext2.f121_id_barras_principal
                WHERE 
                    f121_rowid_item = f120_rowid 
                    AND
                    v.sku_erp IS NULL
                    AND 
                    (
                        TRIM(f119_descripcion) IS NOT NULL 
                        AND 
                        TRIM(f119_descripcion) <> '' 
                        AND 
                        TRIM(f119_descripcion) != 'NO APLICA'
                    )
    );
    -- AND
    -- EXISTS (
    --     SELECT * 
    --     FROM @t125_mc_items_criterios AS t125
    --     WHERE t125.f125_rowid_item = f120_rowid
    -- );