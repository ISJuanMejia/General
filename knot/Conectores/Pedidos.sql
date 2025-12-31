SET XACT_ABORT ON;

DECLARE @json VARCHAR(MAX) = '';
DECLARE @final TABLE (
    idDocumento         INT,
    indicaParalelismo   BIT,
    descripcion         VARCHAR(100),
    idOrden             VARCHAR(50),
    json                VARCHAR(MAX)
);

DECLARE @idDocumento        INT             =   228557;
DECLARE @indicaParalelismo  BIT             =   0;
DECLARE @descripcion        VARCHAR(100)    =   'PEDIDOS_INTEGRACION';

DECLARE @counter    INT =   1;
DECLARE @total      INT;
DECLARE @order  VARCHAR(30);
DECLARE @tmpDescuento TABLE (
    f431_nro_registro   INT, 
    f432_vlr_uni        NVARCHAR(20), 
    f432_tasa           NVARCHAR(20)
);

DECLARE @paymentType    NVARCHAR(MAX);
DECLARE @paymentValue   NVARCHAR(MAX);

DECLARE @id_tercero_defecto VARCHAR(200)    =   '22222222';
DECLARE @ind_estado         VARCHAR(1)      =   '2';
DECLARE @id_sucursal        VARCHAR(3)      =   '001';
DECLARE @id_tipo_docto      VARCHAR(3)      =   'PDV';

BEGIN TRY
    DECLARE @conexion   NVARCHAR(MAX);
    DECLARE @base_datos NVARCHAR(MAX);
    
    SELECT TOP 1 
        @conexion   =   cadena_conexion,
        @base_datos    =   base_datos
    FROM Conexiones;

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
                FROM ' + @base_datos + '.dbo.t430_cm_pv_docto 
                WHERE 
                    f430_ind_estado !=  9 
                    AND 
                    f430_id_cia     =   1
            ''
        )
    ');

    SELECT TOP 100
        id_orden, 
        orden_obj
    INTO #ordenes
    FROM ordenes
        LEFT JOIN ##tmp_OrdenesCreadas  oc
            ON
                oc.f430_referencia  =   REPLACE(id_orden, '"', '')
    WHERE
        id_estado   =   2
        AND
        intentos    <=  3
    ORDER BY id_orden;

    SET @total = (SELECT COUNT(*) FROM #ordenes);

    WHILE @counter <= @total
    BEGIN
        SET @json = (
            SELECT orden_obj
            FROM (
                SELECT orden_obj, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                FROM #ordenes
            ) AS temp
            WHERE rn = @counter
        );

        SET @order = JSON_VALUE(@json, '$.name');

        -- Pago
        SELECT TOP 1
            @paymentType    =   [value],
            @paymentValue   =
                CASE
                    WHEN    value   =   'Sistecredito'
                        THEN    '003'
                    WHEN    value   =   'Addi Payment'
                        THEN    '004'
                    WHEN    value   =   'Wompi'
                        THEN    '006'
                    WHEN    value   =   'Checkout Mercado Pago' OR  value   =   'Mercado Pago Checkout Pro'
                        THEN    '007'
                    ELSE    '001'
            END
        FROM OPENJSON(@json, '$.payment_gateway_names') AS payment
        WHERE
            [value] !=  'gift_card'
        ORDER BY [key] DESC;

        -- Encabezado solo con campos requeridos
        SELECT
            f430_id_tipo_docto          =   @id_tipo_docto,
            f430_consec_docto           =   CAST(@idDocumento AS VARCHAR(10)),
            f430_id_fecha               =   FORMAT(GETDATE(), 'yyyyMMdd'),
            f430_ind_estado             =   @ind_estado,
            f430_id_tercero_fact        =
                ISNULL(
                    NULLIF(
                        TRIM(
                            ISNULL(
                                JSON_VALUE(@json, '$.billing_address.company'), 
                                JSON_VALUE(@json, '$.customer.default_address.company')
                            )
                        ), 
                        ''
                    ),
                    @id_tercero_defecto
                ),
            f430_id_sucursal_fact       =   @id_sucursal,
            f430_id_tercero_rem         =
                ISNULL(
                    NULLIF(
                        TRIM(
                            ISNULL(
                                JSON_VALUE(@json, '$.billing_address.company'), 
                                JSON_VALUE(@json, '$.customer.default_address.company')
                            )
                        ), 
                        ''
                    ),
                    @id_tercero_defecto
                ),
            f430_id_sucursal_rem        =   @id_sucursal,
            f430_fecha_entrega          =   FORMAT(GETDATE(), 'yyyyMMdd'),
            f430_num_dias_entrega       =   CAST('1' AS VARCHAR(2)),
            f430_num_docto_referencia   =   JSON_VALUE(@json, '$.name')
        INTO #pedidos;

        -- Movimientos solo con campos requeridos
        SELECT
            f431_id_tipo_docto      =   @id_tipo_docto,
            f431_consec_docto       =   CAST(@idDocumento AS VARCHAR(10)),
            f431_nro_registro       =   ROW_NUMBER() OVER (ORDER BY (JSON_VALUE(LineItems.value, '$.id'))),
            f431_referencia_item    =   CAST('' AS VARCHAR(50)),
            f431_codigo_barras      =   JSON_VALUE(LineItems.value, '$.sku'),
            f431_id_ext1_detalle    =   CAST('' AS VARCHAR(50)),
            f431_id_ext2_detalle    =   CAST('' AS VARCHAR(50)),
            f431_id_bodega          =   CAST('00301' AS VARCHAR(10)),
            f431_fecha_entrega      =   FORMAT(GETDATE(), 'yyyyMMdd'),
            f431_num_dias_entrega   =   CAST('1' AS VARCHAR(2)),
            f431_id_unidad_medida   =   CAST('PAR' AS VARCHAR(10)),
            f431_cant_pedida_base   =   JSON_VALUE(LineItems.value, '$.quantity'),
            f431_precio_unitario    =   JSON_VALUE(LineItems.value, '$.price'),
            f431_notas              =   @paymentType
        INTO #movimientos
        FROM OPENJSON(@json, '$.line_items') AS LineItems
        ORDER BY JSON_VALUE(LineItems.value, '$.id');

        -- Envío: solo si hay shipping con precio > 0 y no removido, y si no hay descuentos de shipping_lines
        SELECT
            amount  =   JSON_VALUE(ShippingLines.value, '$.discount_allocations[0].amount')
        INTO #Shipping_lines
        FROM OPENJSON(@json, '$.shipping_lines') AS ShippingLines;

        IF NOT EXISTS (SELECT amount FROM #Shipping_lines WHERE amount IS NOT NULL)
        BEGIN
            INSERT INTO #movimientos (
                f431_id_tipo_docto, 
                f431_consec_docto, 
                f431_nro_registro,
                f431_referencia_item, 
                f431_codigo_barras, 
                f431_id_ext1_detalle,
                f431_id_ext2_detalle, 
                f431_id_bodega, 
                f431_fecha_entrega,
                f431_num_dias_entrega, 
                f431_id_unidad_medida, 
                f431_cant_pedida_base,
                f431_precio_unitario, 
                f431_notas
            )
            SELECT
                @id_tipo_docto				AS f431_id_tipo_docto,
                CAST(@idDocumento AS VARCHAR(10))		AS f431_consec_docto,
                0										AS f431_nro_registro,
                'FLETES NACIONAL WEB'					AS f431_referencia_item,
                ''										AS f431_codigo_barras,
                ''										AS f431_id_ext1_detalle,
                ''										AS f431_id_ext2_detalle,
                CAST('00301' AS VARCHAR(10))			AS f431_id_bodega,
                FORMAT(GETDATE(), 'yyyyMMdd')			AS f431_fecha_entrega,
                '1'										AS f431_num_dias_entrega,
                'UND'									AS f431_id_unidad_medida,
                '1'										AS f431_cant_pedida_base,
                JSON_VALUE(sl.value, '$.price')			AS f431_precio_unitario,
                'FLETES NACIONAL WEB'					AS f431_notas
            FROM OPENJSON(@json, '$.shipping_lines')	AS sl
            WHERE JSON_VALUE(sl.value, '$.price') NOT IN ('0.00', '0')
              AND JSON_VALUE(sl.value, '$.is_removed') = 'false';
        END

        -- Descuentos (solo target_type = line_item)
        IF EXISTS (SELECT value FROM OPENJSON(@json, '$.discount_applications'))
        BEGIN
            SELECT *
            INTO #descuentostemp
            FROM OPENJSON(@json) WITH (
                discount_applications NVARCHAR(MAX) '$.discount_applications[0].type',
                [value] NVARCHAR(20)                '$.discount_applications[0].value',
                [name] VARCHAR(50)                  '$.name',
                [target_type] VARCHAR(50)           '$.discount_applications[0].target_type',
                [value_type] VARCHAR(50)            '$.discount_applications[0].value_type'
            ) AS c1;

            IF EXISTS (SELECT TOP 1 target_type FROM #descuentostemp WHERE target_type = 'line_item')
            BEGIN
                INSERT INTO @tmpDescuento (f431_nro_registro, f432_vlr_uni, f432_tasa)
                SELECT
                    ROW_NUMBER() OVER (ORDER BY (JSON_VALUE(LineItems.value, '$.id'))) AS f431_nro_registro,
                    CONVERT(MONEY, JSON_VALUE(Discount.value, '$.amount')) / NULLIF(CONVERT(MONEY, JSON_VALUE(LineItems.value, '$.quantity')), 0) AS f432_vlr_uni,
                    JSON_VALUE(Discount.value, '$.amount') AS f432_tasa
                FROM OPENJSON(@json, '$.line_items') AS LineItems
                CROSS APPLY OPENJSON(LineItems.value, '$.discount_allocations') AS Discount;
            END
        END

        -- Insertar en @final con SOLO los campos permitidos y nombres requeridos
        INSERT INTO @final (idDocumento, indicaParalelismo, descripcion, idOrden, json)
        SELECT
            @idDocumento,
            @indicaParalelismo,
            @descripcion,
            @order AS idOrden,
            (
                SELECT
                    [Pedidos] = (
                        SELECT *
                        FROM #pedidos
                        FOR JSON PATH
                    ),
                    [Movto_Pedidos_comercial] = (
                        SELECT *
                        FROM #movimientos
                        FOR JSON PATH
                    ),
                    [Descuentos] = (
                        SELECT
                            f430_id_tipo_docto  =   @id_tipo_docto,
                            CAST(@idDocumento AS VARCHAR(10)) AS f430_consec_docto,
                            f431_nro_registro,
                            f432_tasa,
                            f432_vlr_uni
                        FROM @tmpDescuento
                        FOR JSON PATH
                    )
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

        DELETE FROM @tmpDescuento;

        IF OBJECT_ID('tempdb..#descuentostemp') IS NOT NULL DROP TABLE #descuentostemp;
        IF OBJECT_ID('tempdb..#pedidos') IS NOT NULL DROP TABLE #pedidos;
        IF OBJECT_ID('tempdb..#movimientos') IS NOT NULL DROP TABLE #movimientos;
        IF OBJECT_ID('tempdb..#Shipping_lines') IS NOT NULL DROP TABLE #Shipping_lines;
        IF OBJECT_ID('tempdb..#descuentos') IS NOT NULL DROP TABLE #descuentos;
        IF OBJECT_ID('tempdb..#tmpDescuento') IS NOT NULL DROP TABLE #tmpDescuento;
        IF OBJECT_ID('tempdb..##tmp_PreciosErp') IS NOT NULL DROP TABLE ##tmp_PreciosErp;

        SET @counter = @counter + 1;
    END
END TRY
BEGIN CATCH
    SELECT
        0 AS idDocumento, 
        0 AS indicaParalelismo, 
        ERROR_MESSAGE() AS descripcion, 
        0 AS idOrden;
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

SELECT * FROM @final AS final_json; 