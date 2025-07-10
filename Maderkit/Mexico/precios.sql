BEGIN TRY
    /*
    *   Pruebas
    */
    DECLARE @cadena_conexion_pruebas    VARCHAR(255)    =   'server=ec2-3-216-46-219.compute-1.amazonaws.com;uid=Maderkitmex;pwd=Maderkitmex$12$%';
    DECLARE @base_datos_pruebas         VARCHAR(255)    =   'UnoEE_Maderkitmex_Pruebas';

    /*
    *   Producción
    */
    DECLARE @cadena_conexion_produccion VARCHAR(255)    =   '';
    DECLARE @base_datos_produccion      VARCHAR(255)    =   '';

    /*
    *   Conexión al ERP
    */
    DECLARE @pruebas    BIT =   1;

    DECLARE @cadena_conexion     VARCHAR(255)    =
        CASE
            WHEN    @pruebas    =   0
                THEN    @cadena_conexion_produccion
            WHEN    @pruebas    =   1
                THEN    @cadena_conexion_pruebas
        END;

    DECLARE @base_datos VARCHAR(255)    =
        CASE
            WHEN    @pruebas    =   0
                THEN    @base_datos_produccion
            WHEN    @pruebas    =   1
                THEN    @base_datos_pruebas
        END;
    
    /*  Obtener información de la v121 del ERP  */
    DECLARE @v121    TABLE  (
        v121_id_cia                 INT,
        v121_id_barras_principal    VARCHAR(40),
        v121_rowid_item             INT
    );

    INSERT INTO @v121
    EXEC('
        SELECT 
            v121_id_cia
            ,v121_id_barras_principal
            ,v121_rowid_item
        FROM OPENROWSET(
            ''SQLNCLI''
            ,''' + @cadena_conexion + '''
            ,''
                SELECT 
                    v121_id_cia
                    ,v121_id_barras_principal
                    ,v121_rowid_item
                FROM ' + @base_datos + '.dbo.v121
                WHERE
                    v121_id_cia = 1
            ''
        )
    ')

    /*  Obtener información de la t126_mc_items_precios del ERP  */
    DECLARE @t126    TABLE  (
        f126_precio             DECIMAL(18, 2),
        f126_rowid_item         INT,
        f126_id_lista_precio    VARCHAR(3),
        f126_fecha_activacion   DATETIME,
        f126_id_cia             INT
    );

    INSERT INTO @t126
    EXEC('
        SELECT 
            f126_precio
            ,f126_rowid_item
            ,f126_id_lista_precio
            ,f126_fecha_activacion
            ,f126_id_cia
        FROM OPENROWSET(
            ''SQLNCLI''
            ,''' + @cadena_conexion + '''
            ,''
                SELECT 
                    f126_precio
                    ,f126_rowid_item
                    ,f126_id_lista_precio
                    ,f126_fecha_activacion
                    ,f126_id_cia
                FROM ' + @base_datos + '.dbo.t126_mc_items_precios
                WHERE
                    f126_id_cia = 1
            ''
        )
    ')

    SELECT * FROM @v121;
    SELECT * FROM @t126;

    MERGE INTO dbo.precios AS target
    USING (
        SELECT 
            productos.id_tienda,
            id_variante =   variantes.id,
            variantes.id_variante_ecommerce,
            variantes.sku_erp,
            precio_obj  =
                JSON_QUERY('
                    {
                        "markup": 0,
                        "basePrice": ' + FORMAT(t126.f126_precio, '####') + ',
                        "listPrice": ' + FORMAT(t126.f126_precio, '####') + ',
                        "fixedPrices": [
                            {
                                "tradePolicyId": "1",
                                "value": ' + FORMAT(t126.f126_precio, '####') + ',
                                "listPrice": ' + FORMAT(t126.f126_precio, '####') + ',
                                "minQuantity": 1
                            }
                        ]
                    }
                '),
            sincronizado    =   0, 
            fecha_sincronizacion    =   GETDATE()  
        FROM variantes
            INNER JOIN productos ON 
                productos.id_producto_ecommerce =   variantes.id_producto_ecommerce
            INNER JOIN @v121    ON
                v121_id_cia =  1
                AND
                v121_id_barras_principal    =  variantes.sku_erp
            INNER JOIN @t126 AS  t126    ON
                f126_id_cia     =   1
                AND
                f126_rowid_item =   v121_rowid_item
        WHERE 
            productos.id_tienda =   1
            AND
            variantes.sincronizado  =   1
            AND
            t126.f126_fecha_activacion  =   (
                SELECT
                    MAX(f126_fecha_activacion)
                FROM @t126 
                WHERE
                    f126_id_cia             =   1
                    AND
                    f126_rowid_item         =   t126.f126_rowid_item
                    AND
                    f126_id_lista_precio    =   t126.f126_id_lista_precio
                    AND
                    f126_fecha_activacion   <=  GETDATE()
                    AND
                    f126_id_lista_precio    =   '002'
            ) 
            AND
            t126.f126_precio    >   1
    ) AS source
    ON (target.id_variante_ecommerce = source.id_variante_ecommerce)

    WHEN
        MATCHED
        AND
        target.id_tienda    <>  source.id_tienda
        AND
        target.precio_obj   <>  source.precio_obj
        THEN
            UPDATE SET
                target.precio_obj           =   source.precio_obj,
                target.sincronizado         =   0,
                target.fecha_sincronizacion =   source.fecha_sincronizacion

    WHEN NOT MATCHED THEN
        INSERT (
            id_tienda,
            id_variante,
            id_variante_ecommerce,
            sku_erp,
            precio_obj,
            sincronizado,
            fecha_sincronizacion
        )
        VALUES (
            source.id_tienda,
            source.id_variante,
            source.id_variante_ecommerce,
            source.sku_erp, source.precio_obj,
            source.sincronizado,
            source.fecha_sincronizacion
        );

END TRY
BEGIN CATCH
    PRINT 'Error: ' + ERROR_MESSAGE();
END CATCH