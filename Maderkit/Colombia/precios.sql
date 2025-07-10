/*
*   Pruebas
*/
DECLARE @server_pruebas     VARCHAR(255)    =   '';
DECLARE @base_datos_pruebas VARCHAR(255)    =   '';

/*
*   Producción
*/
DECLARE @server_produccion      VARCHAR(255)    =   '';
DECLARE @base_datos_produccion  VARCHAR(255)    =   '';

/*
*   Conexión al ERP
*/
DECLARE @pruebas    BIT =   1;

DECLARE @server     VARCHAR(255)    =
    CASE
        WHEN    @pruebas    =   0
            THEN    @server_produccion
        WHEN    @pruebas    =   1
            THEN    @server_pruebas
    END;

DECLARE @base_datos VARCHAR(255)    =
    CASE
        WHEN    @pruebas    =   0
            THEN    @base_datos_produccion
        WHEN    @pruebas    =   1
            THEN    @base_datos_pruebas
    END;

MERGE INTO dbo.precios AS target
USING (
    SELECT 
	    productos.id_tienda,
        variantes.id AS id_variante,
        variantes.id_variante_ecommerce,
        variantes.sku_erp,
        JSON_QUERY('{
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
        }') AS precio_obj,
        0 AS sincronizado, 
        GETDATE() AS fecha_sincronizacion 
    FROM 
        variantes
    INNER JOIN 
        productos ON productos.id_producto_ecommerce = variantes.id_producto_ecommerce
    INNER JOIN 
        EDMERPDB.unoee.dbo.v121 ON v121_id_cia = 1
        AND v121_id_barras_principal = variantes.sku_erp
    INNER JOIN 
        EDMERPDB.unoee.dbo.t126_mc_items_precios AS t126 ON f126_id_cia = 1
        AND f126_rowid_item = v121_rowid_item
    WHERE 
        productos.id_tienda = 1
        AND variantes.sincronizado = 1
        AND t126.f126_fecha_activacion = (
            SELECT MAX(f126_fecha_activacion)
            FROM EDMERPDB.unoee.dbo.t126_mc_items_precios 
            WHERE f126_id_cia = 1
            AND f126_rowid_item = t126.f126_rowid_item
            AND f126_id_lista_precio = t126.f126_id_lista_precio
            AND f126_fecha_activacion <= GETDATE()
            AND f126_id_lista_precio = '002'
        ) 
        AND t126.f126_precio > 1
) AS source
ON (target.id_variante_ecommerce = source.id_variante_ecommerce)

WHEN MATCHED AND target.id_tienda <> source.id_tienda AND target.precio_obj <> source.precio_obj THEN
    UPDATE SET 
        target.precio_obj = source.precio_obj,
        target.sincronizado = 0,
        target.fecha_sincronizacion = source.fecha_sincronizacion

WHEN NOT MATCHED THEN
    INSERT (id_tienda, id_variante, id_variante_ecommerce, sku_erp, precio_obj, sincronizado, fecha_sincronizacion)
    VALUES (source.id_tienda, source.id_variante, source.id_variante_ecommerce, source.sku_erp, source.precio_obj, source.sincronizado, source.fecha_sincronizacion);