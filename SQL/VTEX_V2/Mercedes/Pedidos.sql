DECLARE @id_compania        NVARCHAR(10)    =   9056,
        @id_sistema         NVARCHAR(10)    =   2,
        @id_documento       NVARCHAR(10)    =   213286,
        @nombre_documento   NVARCHAR(50)    = 'MercedesCampuzano_Pedidos';

DECLARE @endpoint NVARCHAR(500) =   
    'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?'   +   
    'idCompania='       +   @id_compania    +   
    '&idSistema='       +   @id_sistema     +
    '&idDocumento='     +   @id_documento   +   
    '&nombreDocumento=' +   @nombre_documento;

DECLARE @fecha_actual           NVARCHAR(8)     =   CONVERT(VARCHAR(8), GETDATE(), 112);
DECLARE @cadena_conexion_erp    VARCHAR(1000)  =   'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Rehemma_Real;UID=Rehemma;PWD=Rehemma$12$%';

UPDATE O
SET 
    O.id_estado         =   4,
    O.intentos          =   0,
	O.orden_obj_destino =   NULL,
	O.endpoint          =   NULL
FROM ORDENES O
    INNER JOIN OPENROWSET(
        'SQLNCLI11', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Rehemma_Real;UID=Rehemma;PWD=Rehemma$12$%', 
        '
            SELECT 
                f430_id_tipo_docto,
                f430_consec_docto,
                f430_num_docto_referencia
            FROM t430_cm_pv_docto
            WHERE 
                f430_id_cia = 1 
                AND 
                f430_id_tipo_docto IN (''CPE'')
                AND 
                F430_ID_CO = ''015''
        '
    )   t430 
        ON 
        t430.f430_num_docto_referencia = 
            CASE 
                WHEN 
                    LEN(
                        REPLACE(
                            JSON_VALUE(O.orden_obj_origen, '$.orderId'), 
                            '-', 
                            ''
                        )
                    ) <= 15 
                    THEN 
                        REPLACE(
                            JSON_VALUE(O.orden_obj_origen, '$.orderId'), 
                            '-', 
                            ''
                        ) 
                ELSE 
                    JSON_VALUE(O.orden_obj_origen, '$.sequence') 
            END
WHERE 
    O.id_tienda = 1
    AND 
    O.id_estado = 3;

DECLARE @ordenes    TABLE (
    id_tienda INT,
    id_orden NVARCHAR(50),
    orden_obj_origen NVARCHAR(MAX)
);

INSERT INTO @ordenes (
    id_tienda, 
    id_orden, 
    orden_obj_origen
)
SELECT TOP 25
    id_tienda,
    id_orden,
    orden_obj_origen
FROM ordenes
WHERE 
    id_tienda = 1 
    AND 
    id_estado = 3
    AND 
    ISNULL(endpoint, '') != @endpoint
    AND 
    JSON_VALUE(orden_obj_origen, '$.creationDate') >= '2025-07-01'

-- Verificar si la tabla temporal tiene datos
IF EXISTS (SELECT 1 FROM @ordenes)
BEGIN
    DECLARE @temp_ordenes  TABLE (
        id_tienda           INT,
        id_orden            NVARCHAR(50),
        endpoint            NVARCHAR(500),
        fecha_creacion      DATETIME,
        orden_obj_destino   NVARCHAR(MAX)
    );

   DECLARE @ItemsNumReg TABLE (
        id_tienda           INT,
        id_orden            NVARCHAR(50),
        id                  NVARCHAR(50),
        UniqueId            NVARCHAR(50),
        f431_nro_registro   INT
    );

    INSERT INTO @ItemsNumReg (id_tienda, id_orden, id, UniqueId, f431_nro_registro)
    SELECT 
        id_tienda           =   o.id_tienda,
        id_orden            =   o.id_orden,
        id                  =   JSON_VALUE(item.value, '$.id'),
    	UniqueId            =   JSON_VALUE(item.value, '$.uniqueId'),
        f431_nro_registro   =   
            ROW_NUMBER() OVER (
                PARTITION BY 
                    o.id_orden 
                ORDER BY 
                    ISNULL(
                        JSON_VALUE(item.value, '$.ean'), 
                        JSON_VALUE(item.value, '$.refId')
                    )
            )
    FROM @ordenes o
        CROSS APPLY OPENJSON(o.orden_obj_origen, '$.items') AS item

    INSERT INTO @temp_ordenes (id_tienda, id_orden, endpoint, fecha_creacion, orden_obj_destino)
    SELECT 
	    id_tienda,
	    id_orden,
        endpoint            =   @endpoint,
        fecha_creacion      =   GETDATE(),
        orden_obj_destino   =
            JSON_QUERY(
                ( 
                    SELECT
                        -- Nodo Pedidos
                        Pedidos =   
                            JSON_QUERY(
                                (
                                    SELECT
                                        f430_id_fecha               =   @fecha_actual,
                                        f430_id_tercero_fact        =   json_value(orden_obj_origen, '$.clientProfileData.document'),
                                        f430_id_tercero_rem         =   json_value(orden_obj_origen, '$.clientProfileData.document'),
                                        f430_fecha_entrega          =   @fecha_actual,
                                        f430_num_docto_referencia   =
                                            CASE 
                                                WHEN 
                                                    LEN(
                                                        REPLACE(
                                                            JSON_VALUE(orden_obj_origen, '$.orderId'), 
                                                            '-', 
                                                            ''
                                                        )
                                                    )   <=  15
                                                    THEN
                                                        REPLACE(
                                                            JSON_VALUE(orden_obj_origen, '$.orderId'), 
                                                            '-', 
                                                            ''
                                                        )
                                                ELSE    JSON_VALUE(orden_obj_origen, '$.sequence')
                                            END,
                                        f430_referencia             =   JSON_VALUE(orden_obj_origen, '$.sequence'),
                                        f430_id_cond_pago           =
                                            CASE    JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName')
                                                WHEN 'American Express' 
                                                    THEN '00'
                                                WHEN 'Mastercard' 
                                                    THEN '00'
                                                WHEN 'Mastercard Debit' 
                                                    THEN '00'
                                                WHEN 'Nequi' 
                                                    THEN '00'
                                                WHEN 'PSE' 
                                                    THEN '00'
                                                WHEN 'Visa' 
                                                    THEN '00'
                                                WHEN 'Visa Electron' 
                                                    THEN '00'
                                                WHEN 'Addi' 
                                                    THEN '01'
                                                WHEN 'Assumed value by affiliate ADDI(DDD)' 
                                                    THEN '01'
                                                WHEN 'Assumed value by affiliate Dafiti - mercedescampuzano(DFT)' 
                                                    THEN '01'
                                                WHEN 'Assumed value by affiliate Exitocol(MPX)' 
                                                    THEN '01'
                                                WHEN 'Assumed value by affiliate Falabella(FLB)' 
                                                    THEN '01'
                                                WHEN 'Assumed value by affiliate Kliquea(KLQ)' 
                                                    THEN '01'
                                                WHEN 'Assumed value by affiliate Puntos Colombia(VPC)' 
                                                    THEN '01'
                                                WHEN 'Pago contra entrega' 
                                                    THEN '01'
                                                WHEN 'Pago WhatsApp' 
                                                    THEN '01'
                                                WHEN 'SisteCredito' 
                                                    THEN '01'
                                                WHEN 'Vale' 
                                                    THEN '01'
                                                WHEN 'Pago en tienda' 
                                                    THEN '01'
                                                WHEN 'Diners' 
                                                    THEN '01'
                                                ELSE '01' 
                                            END,
                                        f430_notas                  =
                                            CONCAT(
                                                JSON_VALUE(orden_obj_origen, '$.orderId'), 
                                                '|', 
                                                JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName')
                                            ),
                                        f419_contacto               =
                                            CONCAT(
                                                JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), 
                                                ' ', 
                                                JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                                            ),
                                        f419_direccion1             =
                                            LEFT(
                                                ISNULL(
                                                    JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), 
                                                    ''
                                                ), 
                                                40
                                            ),
                                        f419_direccion2             =
                                            CASE 
                                                WHEN    JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement') IS NULL 
                                                    THEN '' 
                                                ELSE 
                                                    LEFT(
                                                        JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement'), 
                                                        40
                                                    ) 
                                            END,
                                        f419_direccion3             =
                                            CASE 
                                                WHEN    JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood') IS NULL 
                                                    THEN '' 
                                                ELSE 
                                                    LEFT(
                                                        (
                                                            JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood')
                                                        ), 
                                                        40
                                                    ) 
                                            END,
                                        f419_id_depto               =
                                            LEFT(
                                                ISNULL(
                                                    JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 
                                                    ''
                                                ), 
                                                2
                                            ),
                                        f419_id_ciudad              =
                                            SUBSTRING(
                                                ISNULL(
                                                    JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 
                                                    ''
                                                ), 
                                                3, 
                                                LEN(
                                                    ISNULL(
                                                        JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 
                                                        ''
                                                    )
                                                )
                                            ),
                                        f419_telefono               =
                                            REPLACE(
                                                JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), 
                                                '+57', 
                                                ''
                                            ),
                                        f419_email                  =
                                            LEFT(
                                                JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), 
                                                50
                                            )
                                    FOR JSON PATH,
                                    INCLUDE_NULL_VALUES
                                )
                            ),

                        -- Movimiento de items vendidos
                        Movimientos =
                            JSON_QUERY(
                                ( 
                                    SELECT
                                        f431_nro_registro,
                                        f431_referencia_item,
                                        f431_codigo_barras,
                                        f431_id_motivo,
                                        f431_ind_obsequio,
                                        f431_id_un_movto,
                                        f431_fecha_entrega,
                                        f431_id_unidad_medida,
                                        f431_id_lista_precio,
                                        f431_cant_pedida_base,
                                        f431_precio_unitario,
                                        f431_ind_impto_asumido
                                    FROM (
                                        SELECT
                                            f431_nro_registro       =   i.f431_nro_registro,
                                            f431_referencia_item    =
                                                CASE 
                                                    WHEN 
                                                        ISNULL(
                                                            JSON_VALUE(item.value, '$.ean'), 
                                                            JSON_VALUE(item.value, '$.refId')
                                                        )   =   '7705520482567' --BONO NAVIDAD
                                                        THEN    '5900'
                                                    ELSE ''
                                                END,
                                            f431_codigo_barras      =
                                                CASE 
                                                    WHEN 
                                                        ISNULL(
                                                            JSON_VALUE(item.value, '$.ean'), 
                                                            JSON_VALUE(item.value, '$.refId')
                                                        )   =   '7705520482567'  --BONO NAVIDAD
                                                        THEN ''
                                                    ELSE 
                                                        ISNULL(
                                                            JSON_VALUE(item.value, '$.ean'), 
                                                            JSON_VALUE(item.value, '$.refId')
                                                        )
                                                END,
                                            f431_id_motivo          =
                                                CASE 
                                                    WHEN JSON_VALUE(item.value, '$.sellingPrice') = '0' 
                                                        THEN '03' 
                                                    ELSE '01'  
                                                END,
                                            f431_ind_obsequio       =
                                                CASE 
                                                    WHEN JSON_VALUE(item.value, '$.sellingPrice') = '0' 
                                                        THEN '1' 
                                                    ELSE '0'  
                                                END,
                                            f431_id_un_movto        =
                                                CASE 
                                                    WHEN 
                                                        ISNULL(
                                                            JSON_VALUE(item.value, '$.ean'), 
                                                            JSON_VALUE(item.value, '$.refId')
                                                        )   =   '7705520482567' --BONO NAVIDAD
                                                        THEN    '06'
                                                    WHEN JSON_VALUE(item.value, '$.sellingPrice') = '0' 
                                                        THEN    '06'
                                                    ELSE    ''
                                                END,
                                            f431_fecha_entrega      =   @fecha_actual,
                                            f431_id_unidad_medida   =
                                                ISNULL(
                                                    LTRIM(
                                                        RTRIM(v121_id_unidad_inventario)
                                                    ), 
                                                    'Un'
                                                ),
                                            f431_id_lista_precio    =
                                                CASE 
                                                    WHEN 
                                                        ISNULL(
                                                            JSON_VALUE(item.value, '$.ean'), 
                                                            JSON_VALUE(item.value, '$.refId')
                                                        )   =   '7705520482567' --BONO NAVIDAD
                                                        THEN 'P02'
                                                    ELSE 'P01'
                                                END,
                                            f431_cant_pedida_base   =   JSON_VALUE(item.value, '$.quantity'),
                                            f431_precio_unitario=
                                                CASE 
                                                    WHEN LEN(ISNULL(JSON_VALUE(item.value, '$.price'), '')) > 2 
                                                        THEN 
                                                            LEFT(
                                                                JSON_VALUE(item.value, '$.price'), 
                                                                LEN(
                                                                    JSON_VALUE(item.value, '$.price')
                                                                ) - 2
                                                            )
                                                    ELSE '0'
                                                END,
                                            f431_ind_impto_asumido  =
                                                CASE 
                                                    WHEN JSON_VALUE(item.value, '$.sellingPrice')   =   '0' 
                                                        THEN '1' 
                                                    ELSE '0'  
                                                END
                                        FROM OPENJSON(orden_obj_origen, '$.items')  AS  item
                                            INNER JOIN @ItemsNumReg i
                                                ON 
                                                    i.id_orden                              =   id_orden
                                                    AND 
                                                    i.id_tienda                             =   id_tienda
                                                    AND 
                                                    JSON_VALUE(item.value, '$.id')          =   i.Id
                                                    AND 
                                                    JSON_VALUE(item.value, '$.uniqueId')    =   i.UniqueId
                                            LEFT JOIN OPENROWSET(
                                                'SQLNCLI', 
                                                'Server=db5m5.siesacloudservices.com;Database=UnoEE_Rehemma_Real;UID=Rehemma;PWD=Rehemma$12$%', 
                                                '
                                                    SELECT
                                                        v121_id_barras_principal,
                                                        v121_id_cia,
                                                        v121_id_unidad_inventario
                                                    FROM dbo.v121'
                                            )   AS    v121
                                                ON 
                                                    v121.v121_id_barras_principal   =   ISNULL(
                                                        JSON_VALUE(item.value, '$.ean'), 
                                                        JSON_VALUE(item.value, '$.refId')
                                                    )	
                                                    AND 
                                                    v121.v121_id_cia	= 1
                                            OUTER APPLY (
                                                SELECT TOP 1 *
                                                FROM OPENJSON(orden_obj_origen, '$.shippingData.logisticsInfo') logistics
                                                WHERE 
                                                    JSON_VALUE(logistics.value, '$.itemId') =   JSON_VALUE(item.value, '$.id')
                                            )   AS  logistics

                                        -- Movimiento de Shipping
                                        UNION ALL
                                        SELECT
                                            f431_nro_registro       =    
                                                (
                                                    SELECT 
                                                        COUNT(*) 
                                                    FROM OPENJSON(orden_obj_origen, '$.items')
                                                )   +   1, -- cambiar esto a +2 cuando se agregue la bolsa
                                            f431_referencia_item    =   '1737',
                                            f431_codigo_barras      =   '',
                                            f431_id_motivo          =   '01',
                                            f431_ind_obsequio       =   '0',
                                            f431_id_un_movto        =   '',
                                            f431_fecha_entrega      =   @fecha_actual,
                                            f431_id_unidad_medida   =   'Un',
                                            f431_id_lista_precio    =   'P02',
                                            f431_cant_pedida_base   =   '1',
                                            f431_precio_unitario    =
                                                CASE 
                                                    WHEN 
                                                        LEN(
                                                            ISNULL(
                                                                JSON_VALUE(orden_obj_origen, '$.totals[2].value'), 
                                                                ''
                                                            )
                                                        ) > 2 
                                                        THEN 
                                                            LEFT(
                                                                JSON_VALUE(orden_obj_origen, '$.totals[2].value'), 
                                                                LEN(
                                                                    JSON_VALUE(orden_obj_origen, '$.totals[2].value')
                                                                ) - 2
                                                            )
                                                    ELSE '0'
                                                END,
                                            f431_ind_impto_asumido  =   '0'
                                        WHERE 
                                            JSON_VALUE(orden_obj_origen, '$.totals[2].id')  =   'Shipping'
                                            AND 
                                            ISNULL(
                                                JSON_VALUE(orden_obj_origen, '$.totals[2].value'), 
                                                '0'
                                            ) <> '0'

                                    ) AS movimientos
                                    FOR JSON PATH, 
                                    INCLUDE_NULL_VALUES
                                )
                            ),

                        -- Nodo Descuentos
                        Descuentos  =
                            JSON_QUERY(
                                (
                                    SELECT
                                        f431_nro_registro,
                                        f432_vlr_uni
                                    FROM (
                                        SELECT
                                            f431_nro_registro   =   i.f431_nro_registro,
                                            f432_vlr_uni        =
                                                CAST(
                                                    ROUND(
                                                        (
                                                            CAST(
                                                                JSON_VALUE(item.value, '$.price') AS DECIMAL(18,2)
                                                            ) - 
                                                            CAST(
                                                                JSON_VALUE(item.value, '$.sellingPrice') AS DECIMAL(18,2)
                                                            )
                                                        ) / 100.0, 
                                                        0
                                                    ) AS DECIMAL(18,0)
                                                )
                                        FROM OPENJSON(orden_obj_origen, '$.items') AS item
                                            INNER JOIN @ItemsNumReg i
                                                ON 
                                                    i.id_orden = id_orden
                                                    AND 
                                                    i.id_tienda = id_tienda
                                                    AND 
                                                    JSON_VALUE(item.value, '$.id') = i.Id
                                                    AND 
                                                    JSON_VALUE(item.value, '$.uniqueId') = i.UniqueId
                                        WHERE
                                            JSON_VALUE(item.value, '$.priceTags[0].value') IS NOT NULL
                                            AND 
                                            CAST(json_value(item.value, '$.price') AS FLOAT) - CAST(json_value(item.value, '$.sellingPrice') AS FLOAT) > 0
                                            AND 
                                            JSON_VALUE(item.value, '$.sellingPrice')    !=  '0'
                                    ) AS Descuentos
                                    FOR JSON PATH, 
                                    INCLUDE_NULL_VALUES
                                )
                            )
                    FOR JSON PATH,
                    WITHOUT_ARRAY_WRAPPER
                )
            ) 
    FROM @ordenes;

    --Realizar el UPDATE utilizando la tabla temporal
    UPDATE o
    SET 
        o.endpoint = t.endpoint,
        o.intentos = 0,
        o.fecha_creacion = t.fecha_creacion,
        o.orden_obj_destino = t.orden_obj_destino
    FROM ordenes o
        JOIN @temp_ordenes t ON o.id_tienda = t.id_tienda AND o.id_orden = t.id_orden;
END