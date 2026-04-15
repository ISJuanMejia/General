SET XACT_ABORT ON;

DECLARE @json VARCHAR(MAX) = '';

DECLARE @final TABLE
(
    idDocumento         INT,
    indicaParalelismo   BIT,
    descripcion         VARCHAR(100),
    idOrden             VARCHAR(50),
    json                VARCHAR(MAX)
);

DECLARE @idDocumento        INT          = 220767,
        @indicaParalelismo  BIT          = 0,
        @descripcion        VARCHAR(100) = 'Ecommerce_Pedidos_Estandar';

DECLARE @counter INT = 1;
DECLARE @total   INT;
DECLARE @order   VARCHAR(30);

DECLARE @tmpDescuento TABLE
(
    f431_nro_registro INT,
    f432_vlr_uni      DECIMAL(18,2)
);

DECLARE @paymentType  NVARCHAR(MAX);
DECLARE @paymentValue NVARCHAR(MAX);
DECLARE @vendedor     NVARCHAR(MAX);

BEGIN TRY

    DECLARE @conexion   NVARCHAR(MAX) = (SELECT TOP 1 cadena_conexion FROM Conexiones);
    DECLARE @base_datos NVARCHAR(MAX) = (SELECT TOP 1 base_datos FROM Conexiones);

    DECLARE @tabla NVARCHAR(MAX) =
        @base_datos + '.dbo.t430_cm_pv_docto
         WHERE f430_ind_estado != 9
           AND f430_id_cia = 1';

    IF OBJECT_ID('tempdb..##tmp_OrdenesCreadas') IS NOT NULL
        DROP TABLE ##tmp_OrdenesCreadas;

    EXEC ('
        SELECT DISTINCT f430_referencia
        INTO ##tmp_OrdenesCreadas
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''SELECT f430_referencia FROM ' + @tabla + '''
        )
    ');

    IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL
        DROP TABLE #ordenes;

    SELECT TOP 10
        o.id_orden,
        o.orden_obj
    INTO #ordenes
    FROM ordenes o
    LEFT JOIN ##tmp_OrdenesCreadas oc
        ON oc.f430_referencia = REPLACE(o.id_orden, '"', '')
    WHERE
        o.id_estado = 2
        AND o.intentos <= 3
        AND oc.f430_referencia IS NULL

    SET @total = (SELECT COUNT(*) FROM #ordenes);

WHILE @counter <= @total
    BEGIN
        -- =========================================================
        -- LIMPIEZA PREVENTIVA DE TABLAS TEMPORALES
        -- =========================================================
        IF OBJECT_ID('tempdb..#pedidos') IS NOT NULL DROP TABLE #pedidos;
        IF OBJECT_ID('tempdb..#movimientos') IS NOT NULL DROP TABLE #movimientos;
        IF OBJECT_ID('tempdb..#Shipping_lines') IS NOT NULL DROP TABLE #Shipping_lines;
        -- =========================================================

        SELECT @json = orden_obj
        FROM (
            SELECT orden_obj,
                   ROW_NUMBER() OVER (ORDER BY id_orden) rn
            FROM #ordenes
        ) t
        WHERE rn = @counter;
        

        SET @order = JSON_VALUE(@json, '$.name');

        SET @vendedor =
            CASE JSON_VALUE(@json, '$.source_name')
                WHEN 'GENERICO' THEN 'Generico'
                WHEN 'LEYVA SOLANILLA JULIANA' THEN 'JLS'
                ELSE 'Generico'
            END;

        SELECT TOP 1
            @paymentType  = [value],
            @paymentValue =
                CASE
                    WHEN value = 'Sistecredito' THEN 'C005'
                    WHEN value = 'gift_card' THEN 'C006'
                    WHEN value = 'Addi Payment' THEN 'C004'
                    WHEN value = 'Wompi' THEN 'C009'
                    WHEN value IN (
                        'Checkout Mercado Pago',
                        'Mercado Pago Checkout Pro',
                        'Pago TC MercadoPago',
                        'Pago TD MercadoPago'
                    ) THEN 'C008'
                    ELSE '001'
                END
        FROM OPENJSON(@json, '$.payment_gateway_names')
        WHERE value <> 'gift_card'
        ORDER BY [key] DESC;

        DECLARE @consec_docto VARCHAR(50) = JSON_VALUE(@json, '$.order_number');
        DECLARE @fecha_actual  CHAR(8) = CONVERT(CHAR(8), GETDATE(), 112);
        DECLARE @fecha_entrega CHAR(8) = CONVERT(CHAR(8), DATEADD(DAY,1,GETDATE()),112);
        DECLARE @moneda VARCHAR(5) =
    ISNULL(
        JSON_VALUE(@json, '$.current_subtotal_price_set.presentment_money.currency_code'),
        JSON_VALUE(@json, '$.current_subtotal_price_set.shop_money.currency_code')
    );



        
            DECLARE @Flete VARCHAR(50) =
            CASE @moneda WHEN 'USD' THEN 'ENVIO USD' ELSE 'ENVIO PESOS' END;

        -- DECLARE @extension VARCHAR(10) =
        --     CASE JSON_VALUE(@json, '$.line_items.name')
        --         WHEN 'XXS' THEN '04/XXS'
        --         WHEN 'XS'  THEN '06/XS'
        --         WHEN 'S'   THEN '08/S'
        --         WHEN 'M'   THEN '10/M'
        --         WHEN 'L'   THEN '12/L'
        --         WHEN 'XXL' THEN '14/XXL'
        --         ELSE 'U'
        --     END;

        DECLARE @lista_precio VARCHAR(10) =
            CASE @moneda
                WHEN 'COP' THEN '999'
                WHEN 'USD' THEN '998'
                ELSE '997'
            END;

        SELECT
            f430_id_fecha              = @fecha_actual,
            f430_id_tercero_fact       = ISNULL(JSON_VALUE(@json,'$.billing_address.company'),
                                                JSON_VALUE(@json,'$.customer.default_address.company')),
            f430_id_tercero_rem        = ISNULL(JSON_VALUE(@json,'$.billing_address.company'),
                                                JSON_VALUE(@json,'$.customer.default_address.company')),
            f430_fecha_entrega         = @fecha_entrega,
            f430_num_dias_entrega      = 1,
            f430_num_docto_referencia  = @order,
            f430_referencia            = @order,
            f430_id_moneda_docto       = @moneda,
            f430_id_moneda_conv        = 'COP',
            f430_id_moneda_local       = 'COP',
            f430_notas                 = @order,
            f430_id_punto_envio        = '000',
            f430_id_tercero_vendedor   = @vendedor
        INTO #pedidos;

        SELECT
            f431_nro_registro       = ROW_NUMBER() OVER (ORDER BY JSON_VALUE(li.value,'$.id')),
            f431_referencia_item    = JSON_VALUE(li.value,'$.sku'),
            f431_codigo_barras     = '',
            f431_id_ext1_detalle    = CASE JSON_VALUE(li.value,'$.variant_title')
                               WHEN 'XXS' THEN '04/XXS'
                               WHEN 'XS'  THEN '06/XS'
                               WHEN 'S'   THEN '08/S'
                               WHEN 'M'   THEN '10/M'
                               WHEN 'L'   THEN '12/L'
                               WHEN 'XL'  THEN '14/XL'
                               WHEN 'XXL' THEN '16/XXL'
                               ELSE 'U'
                            END,
            f431_id_motivo          = '01',
            f431_fecha_entrega      = @fecha_entrega,
            f431_num_dias_entrega   = 1,
            f431_id_lista_precio    = @lista_precio,
            f431_id_unidad_medida   = 'UND',
            f431_cant_pedida_base   = CAST(JSON_VALUE(li.value,'$.quantity') AS INT),
            f431_precio_unitario    = CAST(JSON_VALUE(li.value,'$.price') AS DECIMAL(18,2))
        INTO #movimientos
        FROM OPENJSON(@json,'$.line_items') li;

 /* ================= FLETES ================= */

        IF OBJECT_ID('tempdb..#Shipping_lines') IS NOT NULL
            DROP TABLE #Shipping_lines;

        SELECT
            amount = JSON_VALUE(ShippingLines.value, '$.discount_allocations[0].amount')
        INTO #Shipping_lines
        FROM OPENJSON(@json,'$.shipping_lines') AS ShippingLines;

        IF NOT EXISTS (SELECT 1 FROM #Shipping_lines WHERE amount IS NOT NULL)
        BEGIN
            -- Especificar las columnas evita el Error 213 para siempre
            INSERT INTO #movimientos (
                f431_nro_registro,
                f431_referencia_item,
                f431_codigo_barras,    -- <--- LA COLUMNA NUEVA
                f431_id_ext1_detalle,
                f431_id_motivo,
                f431_fecha_entrega,
                f431_num_dias_entrega,
                f431_id_lista_precio,
                f431_id_unidad_medida,
                f431_cant_pedida_base,
                f431_precio_unitario
            )
            SELECT
                0,                 -- f431_nro_registro
                @Flete,            -- f431_referencia_item
                '',                -- f431_codigo_barras (Dato vacío para compensar)
                '',                -- f431_id_ext1_detalle (No aplica para fletes)
                '01',              -- f431_id_motivo
                @fecha_entrega,    -- f431_fecha_entrega
                1,                 -- f431_num_dias_entrega
                @lista_precio,     -- f431_id_lista_precio
                'UND',             -- f431_id_unidad_medida
                1,                 -- f431_cant_pedida_base (sin comillas, es número)
                CAST(JSON_VALUE(sl.value, '$.price') AS DECIMAL(18,2)) -- f431_precio_unitario
            FROM OPENJSON(@json, '$.shipping_lines') sl
            WHERE
                JSON_VALUE(sl.value, '$.price') NOT IN ('0','0.00')
                AND JSON_VALUE(sl.value, '$.is_removed') = 'false';
        END;

         /* ================= DESCUENTOS ================= */

        IF EXISTS (SELECT 1 FROM OPENJSON(@json,'$.discount_applications'))
        BEGIN
            INSERT INTO @tmpDescuento
            SELECT
                ROW_NUMBER() OVER (ORDER BY JSON_VALUE(li.value,'$.id')),
                CAST(JSON_VALUE(da.value,'$.amount') AS DECIMAL(18,2))
            FROM OPENJSON(@json,'$.line_items') li
            CROSS APPLY OPENJSON(li.value,'$.discount_allocations') da;
        END;

        INSERT INTO @final
        (
            idDocumento,
            indicaParalelismo,
            descripcion,
            idOrden,
            json
        )
        SELECT
            @idDocumento,
            @indicaParalelismo,
            @descripcion,
            @order,
            CAST((
                SELECT
                    (SELECT * FROM #pedidos FOR JSON PATH)      AS Pedidos,
                    (SELECT * FROM #movimientos FOR JSON PATH)  AS [Movto Pedidos comercial],
                    (SELECT * FROM @tmpDescuento FOR JSON PATH) AS Descuentos
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS VARCHAR(MAX));

        DELETE FROM @tmpDescuento;
        DROP TABLE #pedidos;
        DROP TABLE #movimientos;
        IF OBJECT_ID('tempdb..#Shipping_lines') IS NOT NULL DROP TABLE #Shipping_lines;

        SET @counter += 1;
    END
END TRY
BEGIN CATCH
    SELECT
        0    AS idDocumento,
        0    AS indicaParalelismo,
        ERROR_MESSAGE() AS descripcion,
        '0'  AS idOrden,
        NULL AS json;
END CATCH;

IF OBJECT_ID('tempdb..##tmp_OrdenesCreadas') IS NOT NULL DROP TABLE ##tmp_OrdenesCreadas;
IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL DROP TABLE #ordenes;

SELECT * FROM @final;

