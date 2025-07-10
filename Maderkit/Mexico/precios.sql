/*  ONE HALF - DESCARGAR PRECIOS DESDE SIESA
    ------------------------------------------------------------------------------
    SCRIPT: Siesa_Descargar_Precios.sql
    PROYECTO: ONE HALF - Ecommerce Shopify Satelite
    DESCRIPCIÓN:
        Este script descarga y sincroniza los precios de productos desde SIESA 
        hacia la base de datos local utilizada por Shopify. Realiza la conexión 
        dinámica a la base de datos de SIESA, extrae información relevante de 
        productos, extensiones y precios, y actualiza la tabla local de precios 
        mediante un MERGE para reflejar los cambios detectados.

    FUNCIONALIDAD PRINCIPAL:
        - Permite alternar entre ambiente de pruebas y producción.
        - Obtiene la cadena de conexión y base de datos según el ambiente.
        - Descarga información de productos, extensiones y precios desde SIESA 
          usando OPENROWSET.
        - Construye objetos de precios en formato JSON para cada variante.
        - Realiza un MERGE sobre la tabla local de precios para insertar o 
          actualizar los registros según corresponda.
        - Permite la extensión para clasificar productos por planes y criterios 
          (comentado por defecto).

    PARÁMETROS:
        @testing            INT         Indica si el ambiente es de pruebas (1) o producción (0).
        @IdListaPrecio      VARCHAR(3)  Identificador de la lista de precios a descargar.
        @IdCia              VARCHAR(3)  Identificador de la compañía en SIESA.

    TABLAS TEMPORALES:
        @precios                        Almacena los precios descargados y actuales.
        @final                          Almacena los objetos JSON de precios para sincronización.
        @t120_mc_items                  Productos base.
        @t121_mc_items_extensiones      Extensiones de productos (códigos de barras).
        @t126_mc_items_precios          Precios de productos por variante.
        -- @t125_mc_items_criterios     (Opcional) Criterios y planes de productos.

    NOTAS:
        - El script utiliza consultas dinámicas y OPENROWSET para acceder a datos 
          remotos.
        - El objeto JSON generado para cada variante sigue la estructura requerida 
          por Shopify.
        - El proceso de MERGE asegura que solo se actualicen los precios que han 
          cambiado y se inserten los nuevos.
        - Para clasificar productos por planes y criterios, descomentar la sección 
          correspondiente.

    AUTOR: Juan Camilo Mejía Echavarría
    FECHA: 4/06/2025
    ------------------------------------------------------------------------------
*/
/*
    Si está en pruebas colocar 1, sino 0
*/
DECLARE @testing    INT =   0;

DECLARE @IdListaPrecio      VARCHAR(3) 	=   '01'
/*  
    Habilitar si se van a clasificar productos por planes y criterios
*/
/*
    DECLARE @IdPlan             VARCHAR(3)  =   ''   
    DECLARE @IdCriterioMayor    VARCHAR(4)	=   ''
*/
DECLARE @IdCia              VARCHAR(3)  =   1

DECLARE @precios    TABLE   (
    id_variante                 VARCHAR(50)
    ,sku_erp                    VARCHAR(50)
    ,price_erp                  DECIMAL
    ,price_shopify              DECIMAL
    ,compare_at_price_shopify   DECIMAL
)

DECLARE @final TABLE(
    id_variante VARCHAR(50)
    ,sku_erp    VARCHAR(50)
    ,precio_obj VARCHAR(MAX)
);

DECLARE @conexion   VARCHAR(200)
        ,@bd        VARCHAR(100)

SELECT TOP 1 
	@conexion   =   cadena_conexion
	,@bd        =   base_datos 
FROM conexiones
WHERE
    id  = 
        CASE
            WHEN @testing   =   1
                THEN    1
            WHEN @testing   =   0
                THEN    2
        END

DELETE @final

DECLARE @t120_mc_items TABLE(
    f120_id            VARCHAR(10)
    ,f120_rowid      VARCHAR(10)
    ,f120_descripcion VARCHAR(50)
);

INSERT INTO @t120_mc_items(f120_id, f120_rowid, f120_descripcion)
EXEC('
    SELECT
        f120_id
        ,f120_rowid
        ,f120_descripcion 
    FROM OPENROWSET(
        ''SQLNCLI''
        , '''+@conexion+'''
        , ''
            SELECT
                f120_id
                ,f120_rowid
                ,f120_descripcion
            FROM ' + @bd + '.dbo.t120_mc_items
            WHERE
                f120_id_cia = ' + @IdCia + '
        ''
    )
')

DECLARE @t121_mc_items_extensiones TABLE(
    f121_rowid            VARCHAR(10)
    ,f121_rowid_item      VARCHAR(10)
    ,f121_id_barras_principal VARCHAR(50)
);

INSERT INTO @t121_mc_items_extensiones(f121_rowid, f121_rowid_item, f121_id_barras_principal)
EXEC('
    SELECT
        f121_rowid
        ,f121_rowid_item
        ,f121_id_barras_principal 
    FROM OPENROWSET(
        ''SQLNCLI''
        , '''+@conexion+'''
        , ''
            SELECT
                f121_rowid
                ,f121_rowid_item
                ,f121_id_barras_principal
            FROM ' + @bd + '.dbo.t121_mc_items_extensiones
            WHERE
                f121_id_cia = ' + @IdCia + '
        ''
    )
')

DECLARE @t126_mc_items_precios TABLE(
    f126_fecha_activacion   DATETIME
    ,f126_rowid_item        VARCHAR(10)
    ,f126_rowid_item_ext    VARCHAR(10)
    ,f126_precio            DECIMAL(18, 2)
);

INSERT INTO @t126_mc_items_precios(f126_fecha_activacion, f126_rowid_item, f126_rowid_item_ext, f126_precio)
EXEC('
    SELECT
        f126_fecha_activacion,
        f126_rowid_item,
        f126_rowid_item_ext,
        f126_precio
    FROM OPENROWSET(
        ''SQLNCLI'',
        ''' + @conexion + ''',
        ''
            SELECT
                f126_fecha_activacion,
                f126_rowid_item,
                f126_rowid_item_ext,
                f126_precio
            FROM (
                SELECT
                    f126_fecha_activacion,
                    f126_rowid_item,
                    f126_rowid_item_ext,
                    f126_precio
                    ,ROW_NUMBER() OVER (PARTITION BY f126_rowid_item_ext ORDER BY f126_fecha_activacion DESC) AS rn_1
                    ,ROW_NUMBER() OVER (PARTITION BY f126_rowid_item ORDER BY f126_fecha_activacion DESC) AS rn_2
                FROM ' + @bd + '.dbo.t126_mc_items_precios
                WHERE
                f126_id_lista_precio = ''''' + @IdListaPrecio + '''''
                AND
                f126_id_cia = ' + @IdCia + '
            ) AS subquery
            WHERE 
                rn_1 = 1
                OR
                rn_2 = 1
        ''
    )
')

/*  Habilitar si se van a clasificar productos por planes y criterios   */

/* 
DECLARE @t125_mc_items_criterios TABLE (
    f125_id_plan                NVARCHAR(3)
    ,f125_id_criterio_mayor     NVARCHAR(4)
    ,f125_rowid_item            VARCHAR(10)
);

INSERT INTO @t125_mc_items_criterios (f125_id_plan, f125_id_criterio_mayor, f125_rowid_item)
EXEC('
	SELECT DISTINCT
		f125_id_plan
		,f125_id_criterio_mayor
		,f125_rowid_item
	FROM OPENROWSET(
		''sqlncli''
 		,''' + @conexion + '''
 		,
		''
			SELECT DISTINCT
				f125_id_plan
				,f125_id_criterio_mayor
				,f125_rowid_item
			FROM	' + @bd + '.dbo.t125_mc_items_criterios
			WHERE
				f125_id_plan    =   ''''' + @IdPlan + '''''  
    			AND
				f125_id_criterio_mayor  =   ' + @IdCriterioMayor + '
                AND
                f125_id_cia = ' + @IdCia + '
		''
	)
')
*/

INSERT INTO @precios(id_variante, sku_erp, price_erp, price_shopify, compare_at_price_shopify)
SELECT 
    id_variante
    ,sku_erp
    ,price_erp                  =   f126_precio
    ,price_shopify              =   JSON_VALUE(variante_obj, '$.price') 
    ,compare_at_price_shopify   =   
        NULLIF(
            CONVERT(
                DECIMAL
                ,JSON_VALUE(variante_obj, '$.compare_at_price')
            )
            , 0
        )
FROM @t126_mc_items_precios
    LEFT JOIN @t121_mc_items_extensiones 
        ON f126_rowid_item_ext  =   f121_rowid
    INNER JOIN variantes 
        ON sku_erp              =   f121_id_barras_principal
WHERE 
    f121_rowid IS NOT NULL
UNION ALL
SELECT 
    id_variante
    ,sku_erp
    ,price_erp                  = f126_precio
    ,price_shopify              =   JSON_VALUE(variante_obj, '$.price') 
    ,compare_at_price_shopify   =
        NULLIF(
            CONVERT(
                DECIMAL
                ,JSON_VALUE(variante_obj, '$.compare_at_price')
            )
            , 0
        )
FROM @t126_mc_items_precios
    LEFT JOIN @t120_mc_items 
        ON f126_rowid_item  =   f120_rowid
    INNER JOIN @t121_mc_items_extensiones 
        ON f120_rowid       =   f121_rowid_item
    INNER JOIN variantes 
        ON sku_erp          =   f121_id_barras_principal
WHERE 
    f120_rowid IS NOT NULL 
    AND 
    f121_id_barras_principal IS NOT NULL;

INSERT INTO @final(id_variante, sku_erp, precio_obj)
SELECT 
    id_variante,
    sku_erp,
    [precio_obj] = (
        SELECT 
            [variant.id]                =   id_variante
            ,[variant.price]            =   
                CASE
                    WHEN    compare_at_price_shopify IS NULL
                        THEN price_erp
                    ELSE NULL
                END
            ,[variant.compare_at_price] =   
                CASE
                    WHEN    compare_at_price_shopify IS NULL
                        THEN NULL
                    ELSE price_erp
                END
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )
FROM @precios

/*  Realizar el MERGE   */
MERGE INTO dbo.precios AS TARGET
USING (
    SELECT 
        id_variante
        ,sku_erp
        ,precio_obj
    FROM @final
) AS source
    ON target.id_variante = source.id_variante
WHEN MATCHED AND target.precio_obj <> source.precio_obj 
    THEN
        UPDATE SET
            target.precio_obj               =   source.precio_obj
            ,target.sincronizado            =   0
            ,target.fecha_sincronizacion    =   NULL
WHEN NOT MATCHED BY TARGET
    THEN
        INSERT (id_variante, sku_erp, precio_obj, sincronizado, fecha_sincronizacion)
        VALUES (source.id_variante, source.sku_erp, source.precio_obj, 0, NULL);