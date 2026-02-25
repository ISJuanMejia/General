SET XACT_ABORT ON;
 
DECLARE @json VARCHAR(MAX) = '';
 
DECLARE @final table
(
    idDocumento         int,
    indicaParalelismo   bit,
    descripcion         varchar(100),
    idOrden             varchar(50),
    json                varchar(max)
)
DECLARE @idDocumento        INT             =   228298,
        @indicaParalelismo  BIT             =   0,
        @descripcion        VARCHAR(100)    =   'Ecommerce_Pedidos_Estandar';

DECLARE @counter        INT = 1;
DECLARE @total          INT;
DECLARE @order          varchar(30)
DECLARE @tmpDescuento   TABLE
(
    f430_consec_docto   VARCHAR(50),
    f431_nro_registro   INT,
    f432_vlr_uni           NVARCHAR(20)
)
DECLARE @paymentType    NVARCHAR(MAX)
DECLARE @paymentValue   NVARCHAR(MAX)
DECLARE @vendedor       NVARCHAR(MAX)
 
BEGIN TRY
    DECLARE @conexion   NVARCHAR(MAX)   =   (SELECT TOP 1 cadena_conexion FROM Conexiones)
    DECLARE @base_datos NVARCHAR(MAX)   =   (SELECT TOP 1 base_datos FROM Conexiones)
    
    DECLARE @tabla  NVARCHAR(MAX)   =
        @base_datos + '.dbo.t430_cm_pv_docto 
        WHERE 
            f430_ind_estado != 9 
            AND 
            f430_id_cia = 1'

    EXEC('
        SELECT DISTINCT 
            f430_referencia 
        INTO ##tmp_OrdenesCreadas 
        FROM OPENROWSET(
            ''SQLNCLI'', 
            ''' + @conexion + ''', 
            ''
                SELECT 
                    f430_referencia 
                FROM ' + @tabla + '
            ''
        )'
    );

    SELECT top 10  
        id_orden, 
        orden_obj
    INTO #ordenes
    FROM ordenes
        LEFT JOIN ##tmp_OrdenesCreadas oc 
            ON 
                oc.f430_referencia  =   REPLACE(id_orden, '"', '')
    WHERE
        id_estado   =   2
        AND
        intentos    <=  3 
        AND 
        oc.f430_referencia IS NULL
 
    SET @total = (SELECT COUNT(*) FROM #ordenes);
    
    WHILE @counter <= @total
    BEGIN
        SET @json = (
            SELECT
                orden_obj
            FROM (
                SELECT
                    orden_obj,
                    rn  =   ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
                FROM #ordenes
            ) AS temp
            WHERE 
                rn  =   @counter
        );
 
        SET @order  =   JSON_VALUE(@json, '$.name')
 
        SET @vendedor   =
            CASE
                WHEN JSON_VALUE(@json, '$.source_name') = 'CLEMONT.CO S.A.S' THEN '001'
                WHEN JSON_VALUE(@json, '$.source_name') = 'MARTINEZ SANTIAGO MARTINEZ' THEN '021'
                WHEN JSON_VALUE(@json, '$.source_name') = 'CANO LORENA CANO' THEN '029'
                ELSE '001'
            END

        --validar metodos de pago
        SELECT TOP 1
            @paymentType    =   [value],
            @paymentValue   = 
                CASE
                    WHEN VALUE = 'Sistecredito'
                        THEN    'C005'
                    WHEN VALUE = 'gift_card'
                        THEN    'C006'
                    WHEN VALUE = 'Addi Payment'
                        THEN    'C004'
                    WHEN VALUE = 'Wompi'
                        THEN    'C009'
                    WHEN
                        VALUE = 'Checkout Mercado Pago' 
                        OR 
                        VALUE = 'Mercado Pago Checkout Pro' 
                        OR 
                        VALUE = 'Pago TC MercadoPago' 
                        OR 
                        VALUE = 'Pago TD MercadoPago' 
                        THEN 'C008'
                    ELSE '001'
                END
        FROM OPENJSON(@json, '$.payment_gateway_names') AS  payment
        WHERE
            [value] !=  'gift_card'
        ORDER BY [key] desc
    
        DECLARE @consec_docto VARCHAR(50) = JSON_VALUE(@json, '$.order_number');

        DECLARE @fecha_actual   VARCHAR(8)  =   FORMAT(GETDATE(), 'yyyyMMdd');
        DECLARE @fecha_entrega  VARCHAR(8)  =   FORMAT(DATEADD(day, 1, GETDATE()), 'yyyyMMdd');
 
        /*
        *   PEDIDOS
        */
        select
            f430_consec_docto           =   @consec_docto,
            f430_id_fecha               =   @fecha_actual,
            isnull(JSON_VALUE(@json, '$.billing_address.company'),JSON_VALUE(@json, '$.customer.default_address.company')) as f430_id_tercero_fact
            ,isnull(JSON_VALUE(@json, '$.billing_address.company'),JSON_VALUE(@json, '$.customer.default_address.company')) as f430_id_tercero_rem
            ,f430_id_tipo_cli_fact      =   @paymentValue
            ,f430_fecha_entrega         =   @fecha_entrega
            ,f430_referencia            =   @order
            ,f430_num_docto_referencia  =   @order
            ,f430_notas                 =   @order
            ,f430_id_tercero_vendedor   =   @vendedor
        into #pedidos
 
        /*
        *   MOVIMIENTO
        */
        SELECT
            f431_consec_docto       =   @consec_docto,
            f431_nro_registro       =   ROW_NUMBER() OVER (ORDER BY (JSON_VALUE(LineItems.value, '$.id'))),
            f431_referencia_item    =   JSON_VALUE(LineItems.value, '$.sku'),
            f431_codigo_barras      =   '',
            f431_id_motivo          =   '01',
            f431_precio_unitario    =   JSON_VALUE(LineItems.value, '$.price'),
            f431_fecha_entrega      =   @fecha_entrega,
            f431_num_dias_entrega   =   1,
            f431_id_unidad_medida   =   'UND',
            f431_cant_pedida_base   =   JSON_VALUE(LineItems.value, '$.quantity')
        INTO #movimientos
        FROM OPENJSON(@json, '$.line_items') AS LineItems
        ORDER BY JSON_VALUE(LineItems.value, '$.id')
 
        /*
        *   Valida si tiene envio
        */
        SELECT
            amount  =   JSON_VALUE(ShippingLines.value, '$.discount_allocations[0].amount')
        INTO #Shipping_lines
        FROM OPENJSON(@json,'$.shipping_lines') AS ShippingLines
 
        IF NOT EXISTS (SELECT amount FROM #Shipping_lines WHERE amount is not null)
        BEGIN
            INSERT INTO #movimientos
            SELECT
                f431_consec_docto   =   @consec_docto,
                f431_nro_registro   =   0,
                f431_referencia_item    =   'FLETES',
                f431_codigo_barras      =   '',
                f431_id_motivo          =   '01',
                f431_precio_unitario    =   JSON_VALUE(sl.value, '$.price'),
                f431_fecha_entrega      =   @fecha_entrega,
                f431_num_dias_entrega   =   1,
                f431_id_unidad_medida   =   'UND',
                f431_cant_pedida_base   =   1
            FROM OPENJSON(@json, '$.shipping_lines') as sl
            WHERE 
                JSON_VALUE(sl.value, '$.price')         !=  '0.00'
                AND 
                JSON_VALUE(sl.value, '$.price')         !=  '0'
                AND 
                JSON_VALUE(sl.value, '$.is_removed')    =   'false'
        end
 
        /*
        *   Valida el descuento
        */
        IF EXISTS (SELECT value FROM OPENJSON(@json,'$.discount_applications'))
        BEGIN
            SELECT * ,@json as json
            INTO #descuentostemp
            FROM OPENJSON(@json) WITH (
                discount_applications nvarchar(max) '$.discount_applications[0].type',
                [value] nvarchar(5) '$.discount_applications[0].value',
                [name] varchar(10) '$.name',
                [target_type] varchar(50) '$.discount_applications[0].target_type',
                [value_type] varchar(50) '$.discount_applications[0].value_type'
            ) AS c1
 
            /*
            *   Valida descuento por linea
            */
            IF EXISTS (select top 1 target_type from #descuentostemp where target_type='line_item')
            BEGIN
                insert into @tmpDescuento  
                SELECT  
                    f430_consec_docto = @consec_docto,
                    f431_nro_registro   =   ROW_NUMBER() OVER (ORDER BY (JSON_VALUE(LineItems.value, '$.id'))),
                    f432_vlr_uni           =   JSON_VALUE(Discount.VALUE, '$.amount')
                FROM OPENJSON(@json, '$.line_items') AS LineItems
                CROSS APPLY OPENJSON(LineItems.value, '$.discount_allocations') AS Discount
            END
        END
 
        INSERT INTO @final(idDocumento,indicaParalelismo,descripcion,idOrden,json)
        SELECT 
            @idDocumento,
            @indicaParalelismo, 
            @descripcion,
            idOrden =   @order,
            (
                SELECT
                    [Pedidos] = (
                        SELECT *
                        FROM #pedidos
                        FOR JSON PATH
                    ),
                    [Movto Pedidos comercial] = (
                        SELECT *
                        FROM #movimientos
                        FOR JSON PATH
                    ),
                    [Descuentos] = (
                        SELECT *
                        FROM @tmpDescuento
                        FOR JSON PATH
                    )
            FOR JSON PATH,
            WITHOUT_ARRAY_WRAPPER
        );
 
        DELETE @tmpDescuento
        IF OBJECT_ID('tempdb..#descuentostemp') IS NOT NULL DROP TABLE #descuentostemp;
        IF OBJECT_ID('tempdb..#pedidos') IS NOT NULL DROP TABLE #pedidos;
        IF OBJECT_ID('tempdb..#movimientos') IS NOT NULL DROP TABLE #movimientos;
        IF OBJECT_ID('tempdb..#descuentos') IS NOT NULL DROP TABLE #descuentos;
        IF OBJECT_ID('tempdb..#tmpDescuento') IS NOT NULL DROP TABLE #tmpDescuento;
        IF OBJECT_ID('tempdb..#Shipping_lines') IS NOT NULL DROP TABLE #Shipping_lines;
        IF OBJECT_ID('tempdb..##tmp_PreciosErp') IS NOT NULL DROP TABLE ##tmp_PreciosErp;
 
        SET @counter = @counter + 1;
    END
END TRY
BEGIN CATCH
    SELECT 
        idDocumento         =   0,
        indicaParalelismo   =   0, 
        descripcion         =   ERROR_MESSAGE(),
        idOrden             =   0
GOTO Cleanup;
END CATCH
Cleanup:
BEGIN
    IF OBJECT_ID('tempdb..#descuentostemp') IS NOT NULL DROP TABLE #descuentostemp;
    IF OBJECT_ID('tempdb..#pedidos') IS NOT NULL DROP TABLE #pedidos;
    IF OBJECT_ID('tempdb..#movimientos') IS NOT NULL DROP TABLE #movimientos;
    IF OBJECT_ID('tempdb..#descuentos') IS NOT NULL DROP TABLE #descuentos;
    IF OBJECT_ID('tempdb..#tmpDescuento') IS NOT NULL DROP TABLE #tmpDescuento;
    IF OBJECT_ID('tempdb..#Shipping_lines') IS NOT NULL DROP TABLE #Shipping_lines;
    IF OBJECT_ID('tempdb..##tmp_PreciosErp') IS NOT NULL DROP TABLE ##tmp_PreciosErp;
    IF OBJECT_ID('tempdb..##tmp_OrdenesCreadas') IS NOT NULL DROP TABLE ##tmp_OrdenesCreadas;
    IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL DROP TABLE #ordenes;
END
 
SELECT * from @final AS final_json;