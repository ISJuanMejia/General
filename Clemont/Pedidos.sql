--VERSION FINAL CLEMONT PEDIDOS - PRUEBAS
 
SET XACT_ABORT ON;
 
DECLARE @json NVARCHAR(MAX) = '';
 
DECLARE @final TABLE
(
    idDocumento         INT,
    indicaParalelismo   BIT,
    descripcion         VARCHAR(100),
    idOrden             VARCHAR(50),
    json                VARCHAR(MAX)
);
 
DECLARE
    @idDocumento        INT          = 228298,
    @indicaParalelismo  BIT          = 0,
    @descripcion        VARCHAR(100) = 'Ecommerce_Pedidos_Estandar',
    @counter            INT          = 1,
    @total              INT,
    @order              VARCHAR(30);
 
DECLARE @tmpDescuento TABLE
(
    f430_consec_docto VARCHAR(50),
    f431_nro_registro INT,
    f432_vlr_uni      DECIMAL(18,2)
);
 
DECLARE
    @paymentType  NVARCHAR(MAX),
    @paymentValue NVARCHAR(MAX),
    @paymentError NVARCHAR(200),
    @vendedor     NVARCHAR(MAX) = '901527979',
    @TipoProceso  VARCHAR(20)   = 'POS',
    --DECLARE @fecha_actual VARCHAR(8) = FORMAT(GETDATE(),'yyyyMMdd');
    @fecha_actual DATETIME2(0) = SYSDATETIME();
 
BEGIN TRY
 
    DECLARE
        @conexion   NVARCHAR(MAX) = (SELECT TOP 1 cadena_conexion FROM Conexiones),
        @base_datos NVARCHAR(MAX) = (SELECT TOP 1 base_datos FROM Conexiones);
 
    DECLARE @tabla NVARCHAR(MAX) =
        @base_datos + '.dbo.t430_cm_pv_docto
        WHERE f430_ind_estado != 9
          AND f430_id_cia = 1';
 
    IF OBJECT_ID('tempdb..##tmp_OrdenesCreadas') IS NOT NULL
        DROP TABLE ##tmp_OrdenesCreadas;
 
    EXEC('
        SELECT DISTINCT
            f430_referencia,
            f430_num_docto_referencia
        INTO ##tmp_OrdenesCreadas
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f430_referencia,
                    f430_num_docto_referencia
                FROM ' + @base_datos + '.dbo.t430_cm_pv_docto
                WHERE F430_id_tipo_docto = ''''CPS''''
            ''
        )
    ');
 
    IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL
        DROP TABLE #ordenes;
   
    SELECT TOP 25
        o.id_orden,
        o.orden_obj,
        o.fecha_creacion
    INTO #ordenes
    FROM ordenes o
        LEFT JOIN ##tmp_OrdenesCreadas oc
            ON
                LTRIM(
                    RTRIM(oc.f430_referencia)
                )
                =
                LTRIM(
                    RTRIM(
                        REPLACE(
                            o.id_orden,
                            '"',
                            ''
                        )
                    )
                )
                OR
                LTRIM(
                    RTRIM(oc.f430_num_docto_referencia)
                )
                =
                LTRIM(
                    RTRIM(
                        REPLACE(
                            o.id_orden,
                            '"',
                            ''
                        )
                    )
                )
    WHERE
        o.id_estado = 2
        AND
        o.intentos <= 3
        AND
        oc.f430_referencia IS NULL
        /*
        id_orden IN ('#32555', '#32529', '#31278')
        */
        --AND
        --EXISTS(
           -- SELECT 1
           -- FROM OPENJSON(o.orden_obj, '$.fulfillments') f
            /*
            WHERE JSON_VALUE(f.value, '$.location_id') = '81269391583'
            */
       -- );
        /*
        AND (
        (
            @TipoProceso = 'POS'
            AND (
                -- Caso vacío
                LTRIM(RTRIM(ISNULL(JSON_VALUE(o.orden_obj, '$.order.tags'), ''))) = ''
                -- Caso PERSONALSHOPPER
                OR CHARINDEX(
                    'personalshopper',
                    LOWER(ISNULL(JSON_VALUE(o.orden_obj, '$.order.tags'), ''))
                ) > 0
                -- Caso ecommerce
                OR CHARINDEX(
                    'ecommerce',
                    LOWER(ISNULL(JSON_VALUE(o.orden_obj, '$.order.tags'), ''))
                ) > 0
            )
        )
        OR (
            @TipoProceso = 'ONLINE'
            AND (
                -- ONLINE acepta vacíos o ecommerce
                LTRIM(RTRIM(ISNULL(JSON_VALUE(o.orden_obj, '$.order.tags'), ''))) = ''
                OR CHARINDEX(
                    'ecommerce',
                    LOWER(ISNULL(JSON_VALUE(o.orden_obj, '$.order.tags'), ''))
                ) > 0
            )
        )
        )
        */
 
    SET @total = (SELECT COUNT(*) FROM #ordenes);
 
    WHILE @counter <= @total
    BEGIN
        SET @paymentError = NULL;
 
        SET @json = (
            SELECT orden_obj
            FROM (
                SELECT orden_obj,
                       ROW_NUMBER() OVER (ORDER BY (SELECT id_orden)) AS rn
                FROM #ordenes
            ) t
            WHERE rn = @counter
        );
 
        SET @order = JSON_VALUE(@json,'$.name');
 
        DECLARE @tags NVARCHAR(MAX);
        /*
        SET @tags = LOWER(ISNULL(JSON_VALUE(@json,'$.order.tags'), ''));
 
        IF @tags IS NOT NULL
        BEGIN
            IF CHARINDEX('lorenacano', @tags) > 0
            BEGIN
                SET @vendedor = '1000398280'
            END
            ELSE IF CHARINDEX('santiagomartinez', @tags) > 0
            BEGIN
                SET @vendedor = '1010052735'
            END
            ELSE
            BEGIN
                SET @vendedor = '901527979' -- Asesor por defecto (CLEMONT.CO S.A.S)
                Si necesitas más asesores, los agregas aquí
            END
        END;
        */
 
        -- BLOQUE ORIGINAL (NO SE TOCA)
        SELECT
            @paymentType  = [value],
            @paymentValue =
                CASE
                    WHEN VALUE = 'Sistecredito'
                        THEN 'C005'
                    WHEN VALUE = 'gift_card'
                        THEN 'C006'
                    WHEN VALUE = 'Addi Payment'
                        THEN 'C004'
                    WHEN VALUE = 'Wompi'
                        THEN 'C009'
                    WHEN
                        VALUE IN (
                            'Checkout Mercado Pago',
                            'Mercado Pago Checkout Pro',
                            'Pago TC MercadoPago',
                            'Pago TD MercadoPago'
                        )
                        THEN 'C008'
                END
        FROM OPENJSON(@json,'$.payment_gateway_names')
        WHERE
            [value] !=  'gift_card'
        ORDER BY [key] DESC;
 
        -- RESET CONTROLADO
        SET @paymentType  = NULL;
        SET @paymentValue = NULL;
 
        ;WITH PaymentCTE AS
        (
            SELECT
                p.[value],
                payment_code =
                    CASE
                        WHEN p.[value] LIKE '%Sistecredito%'
                            THEN 'C005'
                        WHEN p.[value] LIKE '%Addi%'
                            THEN 'C004'
                        WHEN p.[value] LIKE '%Wompi%'
                            THEN 'C009'
                        WHEN p.[value] LIKE '%Mercado Pago%' OR p.[value] LIKE '%MercadoPago%'
                            THEN 'C008'
                        WHEN p.[value] LIKE '%gift%'
                            THEN 'C006'
                    END,
                prioridad =
                    CASE
                        WHEN p.[value] = 'Sistecredito'
                            THEN 1
                        WHEN p.[value] = 'Addi Payment'
                            THEN 2
                        WHEN p.[value] = 'Wompi'
                            THEN 3
                        WHEN p.[value] LIKE '%Mercado%'
                            THEN 4
                        WHEN p.[value] = 'gift_card'
                            THEN 5
                        ELSE 99
                    END
            FROM OPENJSON(@json,'$.payment_gateway_names') p
        )
        SELECT
            @paymentType  = [value],
            @paymentValue = payment_code
        FROM PaymentCTE
        WHERE
            payment_code IS NOT NULL
        ORDER BY prioridad;
 
        IF @paymentValue IS NULL
        BEGIN
            SET @paymentError = 'Metodo de pago no reconocido en la orden ' + ISNULL(@order,'');
            SET @paymentValue = '';
        END;
 
        DECLARE @consec_docto   VARCHAR(50) = JSON_VALUE(@json,'$.order_number');
        DECLARE @fecha_entrega  VARCHAR(8),
                @fecha_creacion VARCHAR(10)
 
        /*
        *   TOMANDO LA FECHA DESDE LA COLUMNA FECHA CREACION DE LA TABLA DE ORDENES
        SET @fecha_creacion =
        (
            SELECT fecha_creacion
            FROM (
                SELECT fecha_creacion,
                       ROW_NUMBER() OVER (ORDER BY (SELECT id_orden)) AS rn
                FROM #ordenes
            ) t
            WHERE rn = @counter
        );
        */
 
        /*
        *   TOMANDO LA INFORMACIÓN DESDE LA FECHA EN QUE FUE CREADO EL PEDIDO EN SHOPIFY
        */
        SELECT
            /*
            *   Fecha Creación
            fecha_creacion  =   FORMAT(CAST(JSON_VALUE(@json, '$.created_at') AS DATE),'yyyyMMdd'),
            */
            @fecha_creacion =   FORMAT(CAST(JSON_VALUE(@json, '$.updated_at') AS DATE),'yyyyMMdd'),                 --  fecha pago
            @fecha_entrega  =   FORMAT(DATEADD(DAY,1,CAST(JSON_VALUE(@json, '$.updated_at') AS DATE)),'yyyyMMdd')   --  Fecha entrega
 
        /* ========= PEDIDOS ========= */
        SELECT
            f430_consec_docto         = @consec_docto,
            f430_id_fecha             = @fecha_creacion,
            f430_id_tercero_fact      = ISNULL(JSON_VALUE(@json,'$.billing_address.company'),
                                               JSON_VALUE(@json,'$.customer.default_address.company')),
            f430_id_tercero_rem       = ISNULL(JSON_VALUE(@json,'$.billing_address.company'),
                                               JSON_VALUE(@json,'$.customer.default_address.company')),
            f430_id_tipo_cli_fact     = @paymentValue,
            f430_fecha_entrega        = @fecha_entrega,
            f430_referencia           = @order,
            f430_num_docto_referencia = @order,
            f430_notas                = @order,
            f430_id_tercero_vendedor  = ISNULL(@vendedor, '')
        INTO #pedidos;
 
        /* ========= MOVIMIENTOS ========= */
        SELECT
            f431_consec_docto     = @consec_docto,
            f431_nro_registro     = ROW_NUMBER() OVER (ORDER BY JSON_VALUE(li.value,'$.id')),
            f431_referencia_item  = JSON_VALUE(li.value,'$.sku'),
            f431_codigo_barras    = '',
            f431_id_motivo        = '01',
            f431_precio_unitario  = JSON_VALUE(li.value,'$.price'),
            f431_fecha_entrega    = @fecha_entrega,
            f431_num_dias_entrega = 1,
            f431_id_unidad_medida = 'UND',
            f431_cant_pedida_base = JSON_VALUE(li.value,'$.quantity')
        INTO #movimientos
        FROM OPENJSON(@json,'$.line_items') li;
 
        /* ========= SHIPPING ========= */
        SELECT
            amount = JSON_VALUE(sl.value,'$.discount_allocations[0].amount')
        INTO #Shipping_lines
        FROM OPENJSON(@json,'$.shipping_lines') sl;
 
        IF NOT EXISTS (SELECT 1 FROM #Shipping_lines WHERE amount IS NOT NULL)
        BEGIN
            INSERT INTO #movimientos
            SELECT
                @consec_docto,
                0,
                'FLETES',
                '',
                '01',
                JSON_VALUE(sl.value,'$.price'),
                @fecha_entrega,
                1,
                'UND',
                1
            FROM OPENJSON(@json,'$.shipping_lines') sl
            WHERE
                JSON_VALUE(sl.value,'$.price') NOT IN ('0','0.00')
                AND
                JSON_VALUE(sl.value,'$.is_removed') = 'false';
        END;
 
        /* ========= DESCUENTOS ========= */
        IF EXISTS (SELECT 1 FROM OPENJSON(@json,'$.discount_applications'))
        BEGIN
            SELECT *
            INTO #descuentostemp
            FROM OPENJSON(@json) WITH (
                target_type VARCHAR(50) '$.discount_applications[0].target_type'
            );
 
            IF EXISTS (SELECT 1 FROM #descuentostemp WHERE target_type='line_item')
            BEGIN
                INSERT INTO @tmpDescuento
                SELECT
                    @consec_docto,
                    ROW_NUMBER() OVER (ORDER BY JSON_VALUE(li.value,'$.id')),
                    CAST(JSON_VALUE(d.value,'$.amount') AS DECIMAL(18,2)) / CAST(JSON_VALUE(li.value,'$.quantity') AS DECIMAL(18,2))
                FROM OPENJSON(@json,'$.line_items') li
                CROSS APPLY OPENJSON(li.value,'$.discount_allocations') d;
            END;
        END;
 
        INSERT INTO @final
        SELECT
            @idDocumento,
            @indicaParalelismo,
            @descripcion,
            @order,
            (
                SELECT
                    (SELECT * FROM #pedidos FOR JSON PATH)               AS Pedidos,
                    (SELECT * FROM #movimientos FOR JSON PATH)           AS [Movto Pedidos comercial],
                    (SELECT * FROM @tmpDescuento FOR JSON PATH)          AS Descuentos
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
 
        DELETE @tmpDescuento;
        DROP TABLE IF EXISTS #pedidos,#movimientos,#descuentostemp,#Shipping_lines;
 
        SET @counter += 1;
    END;
 
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS #pedidos,#movimientos,#descuentostemp,#Shipping_lines;
    SELECT
        0 AS idDocumento,
        0 AS indicaParalelismo,
        ERROR_MESSAGE() AS descripcion,
        0 AS idOrden;
END CATCH;
 
SELECT * FROM @final;