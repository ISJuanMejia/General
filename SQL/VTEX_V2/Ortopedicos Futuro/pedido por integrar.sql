SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRY
    -- ===========================================================
    -- SECCIÓN 1: PARÁMETROS
    -- ===========================================================
    DECLARE @id_compania        NVARCHAR(4)     = '4826',
            @id_sistema         NVARCHAR(1)     = '2',
            @id_documento       NVARCHAR(6)     = '242570',
            @nombre_documento   NVARCHAR(255)   = 'PEDIDO_INTEGRACION_VTEX',
            @validar_estructura NVARCHAR(5)     = 'true';

    DECLARE @endpoint NVARCHAR(500) =
        'http://localhost:8092/v3.1/ConectoresImportar?idCompania='
        + @id_compania
        + '&idSistema='      + @id_sistema
        + '&idDocumento='    + @id_documento
        + '&nombreDocumento='+ @nombre_documento
        + '&validarEstructura=' + @validar_estructura;

    DECLARE @batch_size         INT         = 25,
            @num_max_intentos   INT         = 3,
            @fecha_actual       NVARCHAR(8) = FORMAT(GETDATE(), 'yyyyMMdd');

    DECLARE @id_cia_erp         INT          = 1;
    DECLARE @id_item_envio      NVARCHAR(20) = N'99999977';
    DECLARE @id_lista_precio    NVARCHAR(10) = N'V01';
    DECLARE @nro_registro_envio INT          = 300;

    DECLARE @id_ccosto_obsequio NVARCHAR(20) = N'030805',
            @id_ccosto_normal   NVARCHAR(20) = N'';

    DECLARE @id_motivo_obsequio NVARCHAR(10) = N'03',
            @id_motivo_normal   NVARCHAR(10) = N'01';

    -- ===========================================================
    -- SECCIÓN 2: TABLAS DE TRABAJO
    -- ===========================================================

    -- CORRECCIÓN 7: se eliminan @pedido, @movimiento_pedido_comercial
    -- y @descuentos porque son código muerto (nunca se leen ni insertan).

    DECLARE @OrdenesDestino TABLE (
        id_orden          NVARCHAR(50)  NOT NULL,
        endpoint          NVARCHAR(500) NOT NULL,
        fecha_creacion    DATETIME      NOT NULL,
        orden_obj_destino NVARCHAR(MAX)     NULL
    );

    DECLARE @ordenes TABLE (
        id_orden         NVARCHAR(MAX),
        orden_obj_origen NVARCHAR(MAX)
    );

    INSERT INTO @ordenes
    SELECT TOP (@batch_size)
        id_orden,
        orden_obj_origen
    FROM ordenes
    -- WHERE
        -- id_estado = 3
        -- AND 
        -- (
        --     intentos <= @num_max_intentos 
        --     OR 
        --     intentos IS NULL
        -- )
        -- AND 
        -- ISNULL(endpoint, '') != @endpoint;
    ORDER BY ID DESC

    IF NOT EXISTS (SELECT 1 FROM @ordenes)
        RETURN;
    
    SELECT
        id_orden,
        document            =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')),
        corporateDocument   =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')),
        isCorporate         =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.isCorporate')),
        street              =   REPLACE(REPLACE(UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street')), 'CARRERA', 'KRR'), 'CALLE', 'CLL'),
        complement          =   REPLACE(UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement')), 'APARTAMENTO ', 'APT '),
        neighborhood        =   UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood')),
        postalCode          =   UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode')),
        paymentSystemName   =   UPPER(JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName'))
    FROM @ordenes

    /*
    -- ===========================================================
    -- SECCIÓN 3: TRANSFORMACIÓN
    -- ===========================================================
    INSERT INTO @OrdenesDestino (id_orden, endpoint, fecha_creacion, orden_obj_destino)
    SELECT
        id_orden       = o.id_orden,
        endpoint       = @endpoint,
        fecha_creacion = GETDATE(),
        orden_obj_destino =
        (
            SELECT
                -- ── Pedidos ──────────────────────────────────────────────
                Pedidos =
                (
                    SELECT
                        f430_id_fecha             = CONVERT(VARCHAR(8), GETDATE(), 112),
                        f430_id_tercero_fact       = JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'),
                        f430_id_tercero_rem        = JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'),
                        f430_id_tipo_cli_fact      =
                            CASE
                                WHEN UPPER(JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName')) LIKE '%ADDI%'
                                    THEN N'W001'
                                WHEN JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = N'PayU No Varix'
                                    THEN N'W005'
                                WHEN JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%Mercado%'
                                    THEN N'W002'
                                WHEN JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = N'Pago contra entrega'
                                    THEN N'W004'
                                WHEN JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = N'Transferencias'
                                    THEN N'W006'
                                ELSE N'W003'
                            END,
                        f430_fecha_entrega         = CONVERT(VARCHAR(8), GETDATE(), 112),
                        f430_notas                 =
                            CASE
                                WHEN JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%ADDI%'
                                    THEN CONCAT(
                                            JSON_VALUE(o.orden_obj_origen, '$.orderId'), 
                                            N'-',
                                            JSON_VALUE(o.orden_obj_origen, '$.sequence')
                                         )
                                WHEN JSON_VALUE(o.orden_obj_origen, '$.orderId') LIKE '[A-Z]%'
                                    THEN SUBSTRING(
                                            JSON_VALUE(o.orden_obj_origen, '$.orderId'),
                                            CHARINDEX('-', JSON_VALUE(o.orden_obj_origen, '$.orderId')) + 1,
                                            CHARINDEX('-', JSON_VALUE(o.orden_obj_origen, '$.orderId'),
                                                CHARINDEX('-', JSON_VALUE(o.orden_obj_origen, '$.orderId')) + 1)
                                            - CHARINDEX('-', JSON_VALUE(o.orden_obj_origen, '$.orderId')) - 1
                                         )
                                ELSE JSON_VALUE(o.orden_obj_origen, '$.sequence')
                            END,
                        f430_id_punto_envio        = N'000',
                        f430_num_docto_referencia  =
                            LEFT(
                                CONCAT(
                                    JSON_VALUE(o.orden_obj_origen, '$.orderId'),
                                    N' (', JSON_VALUE(o.orden_obj_origen, '$.sequence'), N')'
                                ),
                                50
                            ) + ' - 1'
                    FOR JSON PATH
                ),

                -- ── MovimientoPedidoComercial ─────────────────────────
                MovimientoPedidoComercial =
                (
                    -- Items vendidos
                    SELECT
                    *
                    FROM
                    (
                        SELECT
                        ROW_NUMBER() OVER (ORDER BY CAST(item.[key] AS INT))
                            AS f431_nro_registro,
                        N''
                            AS f431_referencia_item,
                        -- CORRECCIÓN 6: CASE para EAN especial
                        CASE JSON_VALUE(item.value, '$.ean')
                            WHEN '99999991' THEN '7707066001509'
                            ELSE JSON_VALUE(item.value, '$.ean')
                        END
                            AS f431_codigo_barras,
                        CONVERT(VARCHAR(8), GETDATE(), 112)
                            AS f431_fecha_entrega,
                        ISNULL(LTRIM(RTRIM(v121.v121_id_unidad_inventario)), N'UN')
                            AS f431_id_unidad_medida,
                        JSON_VALUE(item.value, '$.quantity')
                            AS f431_cant_pedida_base,
                        @id_lista_precio
                            AS f431_id_lista_precio,
                        CASE
                            WHEN LEN(ISNULL(JSON_VALUE(item.value, '$.listPrice'), N'')) > 2
                                THEN LEFT(JSON_VALUE(item.value, '$.listPrice'),
                                          LEN(JSON_VALUE(item.value, '$.listPrice')) - 2)
                            ELSE N'0'
                        END
                            AS f431_precio_unitario,
                        CASE
                            WHEN ISNULL(TRY_CAST(JSON_VALUE(item.value, '$.sellingPrice') AS DECIMAL(18,2)), 0) = 0
                                THEN 1 ELSE 0
                        END AS f431_ind_obsequio,
                        CASE
                            WHEN ISNULL(TRY_CAST(JSON_VALUE(item.value, '$.sellingPrice') AS DECIMAL(18,2)), 0) = 0
                                THEN 1 ELSE 0
                        END AS f431_ind_impto_asumido,
                        CASE
                            WHEN ISNULL(TRY_CAST(JSON_VALUE(item.value, '$.sellingPrice') AS DECIMAL(18,2)), 0) = 0
                                THEN @id_motivo_obsequio
                            ELSE @id_motivo_normal
                        END AS f431_id_motivo,
                        CASE
                            WHEN ISNULL(TRY_CAST(JSON_VALUE(item.value, '$.sellingPrice') AS DECIMAL(18,2)), 0) = 0
                                THEN @id_ccosto_obsequio
                            ELSE N''
                        END AS f431_id_ccosto_movto,
                        CASE
                            WHEN JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%ADDI%'
                                THEN CONCAT(
                                        JSON_VALUE(o.orden_obj_origen, '$.orderId'), N'-',
                                        JSON_VALUE(o.orden_obj_origen, '$.sequence')
                                     )
                            WHEN JSON_VALUE(o.orden_obj_origen, '$.orderId') LIKE '[A-Z]%'
                                THEN SUBSTRING(
                                        JSON_VALUE(o.orden_obj_origen, '$.orderId'),
                                        CHARINDEX('-', JSON_VALUE(o.orden_obj_origen, '$.orderId')) + 1,
                                        CHARINDEX('-', JSON_VALUE(o.orden_obj_origen, '$.orderId'),
                                            CHARINDEX('-', JSON_VALUE(o.orden_obj_origen, '$.orderId')) + 1)
                                        - CHARINDEX('-', JSON_VALUE(o.orden_obj_origen, '$.orderId')) - 1
                                     )
                            ELSE JSON_VALUE(o.orden_obj_origen, '$.sequence')
                        END AS f431_notas

                    FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
                    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[v121] AS v121
                        ON  v121.v121_id_barras_principal = ISNULL(
                                JSON_VALUE(item.value, '$.ean'),
                                JSON_VALUE(item.value, '$.refId')
                            )
                        AND v121.v121_id_cia = @id_cia_erp

                    UNION ALL

                    -- CORRECCIÓN 4: ítem de envío con los 4 campos de obsequio presentes
                    SELECT
                        @nro_registro_envio     AS f431_nro_registro,
                        @id_item_envio          AS f431_referencia_item,
                        N''                     AS f431_codigo_barras,
                        CONVERT(VARCHAR(8), GETDATE(), 112)
                                                AS f431_fecha_entrega,
                        N'UN'                   AS f431_id_unidad_medida,
                        1                       AS f431_cant_pedida_base,
                        @id_lista_precio        AS f431_id_lista_precio,
                        ISNULL((
                            SELECT CAST(JSON_VALUE(total.value, '$.value') AS BIGINT) / 100
                            FROM OPENJSON(o.orden_obj_origen, '$.totals') AS total
                            WHERE JSON_VALUE(total.value, '$.id') = N'Shipping'
                        ), 0)                   AS f431_precio_unitario,
                        -- Envío nunca es obsequio → valores normales
                        0                       AS f431_ind_obsequio,
                        0                       AS f431_ind_impto_asumido,
                        @id_motivo_normal       AS f431_id_motivo,
                        N''                     AS f431_id_ccosto_movto,
                        N'Shipping'             AS f431_notas

                    WHERE JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].price') <> N'0'
                    ) AS M

                    FOR JSON PATH
                ),

                -- ── Descuentos ────────────────────────────────────────
                -- CORRECCIÓN 5: excluir ítems obsequio (sellingPrice = 0)
                Descuentos =
                (
                    SELECT
                        CAST(item.[key] AS INT) + 1
                            AS f431_nro_registro,
                        CASE
                            WHEN JSON_VALUE(tag.value, '$.value') IS NOT NULL
                                THEN CAST(
                                        (ABS(TRY_CAST(JSON_VALUE(tag.value, '$.value') AS DECIMAL(18,2))) / 100.0)
                                        / NULLIF(TRY_CAST(JSON_VALUE(item.value, '$.quantity') AS DECIMAL(18,2)), 0)
                                    AS DECIMAL(18,2))
                            ELSE NULL
                        END AS f432_vlr_uni,
                        0   AS f432_tasa

                    FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
                    CROSS APPLY OPENJSON(item.value, '$.priceTags') AS tag
                    WHERE TRY_CAST(JSON_VALUE(tag.value, '$.value') AS DECIMAL(18,2)) < 0
                      AND ISNULL(TRY_CAST(JSON_VALUE(item.value, '$.sellingPrice') AS DECIMAL(18,2)), 0) <> 0

                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )

            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    FROM @ordenes AS o;
    */

    -- Vista previa (comentar en producción)
    -- SELECT * FROM @OrdenesDestino;

    -- ===========================================================
    -- SECCIÓN 4: UPDATE (descomentar en producción)
    -- ===========================================================
    /*
    UPDATE o
    SET
        o.endpoint          = d.endpoint,
        o.id_estado         =   4,
        o.intentos          = 0,
        o.fecha_creacion    = d.fecha_creacion,
        o.orden_obj_destino = d.orden_obj_destino
    FROM dbo.ordenes AS o
    -- CORRECCIÓN 1: ON faltante en el JOIN
    INNER JOIN @OrdenesDestino AS d ON o.id_orden = d.id_orden;
    */

    SELECT @@ROWCOUNT AS filas_actualizadas, GETDATE() AS fecha_ejecucion;

END TRY
BEGIN CATCH
    DECLARE @errorMsg   NVARCHAR(4000) = ERROR_MESSAGE(),
            @errorSev   INT            = ERROR_SEVERITY(),
            @errorState INT            = ERROR_STATE(),
            @errorLine  INT            = ERROR_LINE(),
            @errorProc  NVARCHAR(200)  = ISNULL(ERROR_PROCEDURE(), N'Script inline');

    RAISERROR(
        N'[PEDIDO_INTEGRACION_VTEX] Error en línea %d | Procedimiento: %s | Mensaje: %s',
        @errorSev, @errorState, @errorLine, @errorProc, @errorMsg
    );
END CATCH;