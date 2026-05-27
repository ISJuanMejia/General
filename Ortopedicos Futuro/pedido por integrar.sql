-- ============================================================================================================================
-- SCRIPT  : PEDIDO_INTEGRACION_VTEX
-- AUTOR   : Connekta / Siesa S.A.S.
-- FECHA   : 2026-05-13
-- VERSION : 2.0
-- ----------------------------------------------------------------------------------------------------------------------------
-- DESCRIPCIÓN:
--   Transforma los pedidos de la tabla [ordenes] (formato JSON de origen VTEX) al formato JSON de destino
--   requerido por el conector Siesa (PEDIDO_INTEGRACION_VTEX), incluyendo:
--     - Nodo Pedidos        : encabezado del pedido comercial (f430_*)
--     - MovimientoPedidoComercial : ítems vendidos + envío como ítem separado (f431_*)
--     - Descuentos          : descuentos parciales por ítem (f432_*)
--
--   LÓGICA DE OBSEQUIOS (descuento 100 %):
--     Si el sellingPrice de un ítem es 0, se considera obsequio:
--       f431_ind_obsequio      = 1
--       f431_ind_impto_asumido = 1
--       f431_id_motivo         = '03'
--       f431_id_ccosto_movto   = '030805'
--     En caso contrario todos esos campos toman el valor "normal" (0, 0, '01', '').
--
--   ÍTEM DE ENVÍO:
--     Se agrega como f431_nro_registro = 300 cuando shippingData.logisticsInfo[0].price <> '0'.
--     Siempre lleva los valores normales (no obsequio).
--
--   DESCUENTOS PARCIALES:
--     Se generan desde $.items[*].priceTags cuando el value < 0.
--     El valor unitario se calcula como ABS(priceTags.value / 100) / quantity.
--
-- ----------------------------------------------------------------------------------------------------------------------------
-- PARÁMETROS CONFIGURABLES (ver sección "PARÁMETROS"):
--   @idCompania        : identificador de compañía en Siesa
--   @idSistema         : identificador de sistema en Siesa
--   @idDocumento       : identificador de documento en Siesa
--   @nombreDocumento   : nombre del documento en Siesa
--   @validarEstructura : bandera de validación de estructura (true/false)
--   @idOrden           : filtro por orden específica (NULL = todas)
--   @idEstado          : filtro por estado (NULL = todos)
--   @idCiaV121         : compañía usada para buscar la unidad de inventario en v121
--   @idItemEnvio       : referencia de ítem de envío
--   @idListaPrecio     : lista de precio a usar en todos los ítems
--   @ccostoObsequio    : centro de costo para ítems con descuento del 100 %
--   @motivoObsequio    : motivo para ítems con descuento del 100 %
--   @motivoNormal      : motivo para ítems sin descuento del 100 %
--   @nroRegistroEnvio  : número de registro reservado para el ítem de envío
--
-- ----------------------------------------------------------------------------------------------------------------------------
-- DEPENDENCIAS:
--   Tabla  : dbo.ordenes              (columnas: id_orden, id_estado, orden_obj_origen,
--                                                endpoint, intentos, fecha_creacion, orden_obj_destino)
--   Tabla  : UnoEE_PruebasProyectosCol.dbo.v121  (v121_id_barras_principal, v121_id_unidad_inventario, v121_id_cia)
--
-- ----------------------------------------------------------------------------------------------------------------------------
-- CAMBIOS:
--   v2.0 - 2026-05-13 : Refactoring completo. Variables de tabla, parámetros, obsequios, comentarios, manejo de errores.
--   v1.0 - Versión inicial.
-- ============================================================================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;   -- Aborta la transacción automáticamente ante cualquier error en tiempo de ejecución
SET TRANSACTION ISOLATION LEVEL READ COMMITTED; 

BEGIN TRY

    -- ===========================================================
    -- SECCIÓN 1: PARÁMETROS
    -- ===========================================================

    -- ---- Endpoint Siesa ----
    /*
        *   Parámetros de Configuración General: Esta sección incluye la configuración general del conector, como la 
        *   identificación de la compañía, el sistema y el documento, así como el nombre del documento a integrar. Es 
        *   importante resaltar que estos parámetros deben ser ajustados acorde a las necesidades particulares de cada 
        *   caso, considerando la configuración y categorización establecida en el destino final para la identificación 
        *   de la compañía, el sistema y el documento, así como el nombre del documento a integrar.
    */
    DECLARE @id_compania        NVARCHAR(4)     =   '6695',
            @id_sistema         NVARCHAR(1)     =   '2',
            @id_documento       NVARCHAR(6)     =   '242570',
            @nombre_documento   NVARCHAR(255)   =   'PEDIDO_INTEGRACION_VTEX',
            @validar_estructura NVARCHAR(5)     =   'true';

    /*
        *   Endpoint: URL del endpoint al cual se enviará la información formateada y estructurada acorde a las 
        *   necesidades del destino final. Es importante resaltar que este endpoint debe ser ajustado acorde a las 
        *   necesidades particulares de cada caso, considerando los diferentes escenarios y casos de uso que se puedan 
        *   presentar en la operación real del conector, para asegurar una integración exitosa y sin contratiempos. 
        *   Además, es fundamental verificar que el endpoint esté correctamente configurado y sea accesible desde el 
        *   entorno donde se ejecutará el conector, para evitar posibles errores de conexión o de envío de datos.
    */
    DECLARE @endpoint   NVARCHAR(500)   =   'http://localhost:8083/v3.1/ConectoresImportar?idCompania='
                                            +   @id_compania 
                                            +   '&idSistema='
                                            +   @id_sistema
                                            +   '&idDocumento='
                                            +   @id_documento
                                            +   '&nombreDocumento='
                                            +   @nombre_documento                                            
                                            +   '&validarEstructura='
                                            +   @validar_estructura;

    /*
        *   Parámetros de configuración de ejecución para la selección y procesamiento de las órdenes, tales como el tamaño 
        *   del lote, el número máximo de intentos para reintento en caso de fallas, así como la fecha actual para uso en el 
        *   formateo de datos. Es importante resaltar que estos parámetros deben ser ajustados acorde a las necesidades 
        *   particulares de cada caso, considerando los diferentes escenarios y casos de uso que se puedan presentar en la 
        *   operación real del conector, para asegurar una integración exitosa y sin contratiempos.
    */
    DECLARE @batch_size         INT         =   25,
            @num_max_intentos   INT         =   3,
            @fecha_actual       NVARCHAR(8) =   FORMAT(GETDATE(), 'yyyyMMdd');

    /**/
    DECLARE @id_cia INT =   1;

    /**/
    DECLARE @id_item_envio  NVARCHAR(20)    =   N'99999977';    -- Referencia del ítem de envío

    /**/
    DECLARE @id_lista_precio    NVARCHAR(10)    =   N'P01';     -- Lista de precio aplicada a todos los ítems

    /**/
    DECLARE @nro_registro_envio INT =   300;    -- Número de registro reservado para el ítem de envío

    -- ---- Configuración de obsequios (descuento 100 %) ----
    DECLARE @id_ccosto_obsequio NVARCHAR(20)  = N'030805',  -- Centro de costo para ítems obsequio
            @id_ccosto_normal   NVARCHAR(20)  = N'';        -- Centro de costo para ítems obsequio

    DECLARE @id_motivo_obsequio    NVARCHAR(10)  = N'03',   -- Motivo: obsequio
            @id_motivo_normal      NVARCHAR(10)  = N'01';   -- Motivo: venta normal

    ---<=================================================================================================>---

    /*
        *   Secciones del Conector
        *   1.  Pedidos
        *   2.  MovimientoPedidoComercial
        *   3.  Descuentos
    */

    DECLARE @pedido TABLE (
        a NVARCHAR(10)
    );

    DECLARE @movimiento_pedido_comercial TABLE (
        a NVARCHAR(10)
    );

    DECLARE @descuentos TABLE (
        a NVARCHAR(10)
    );

    ---<=================================================================================================>---
    -- Destino: resultado transformado listo para el UPDATE final
    DECLARE @OrdenesDestino TABLE (
        id_orden           NVARCHAR(50)   NOT NULL,
        endpoint           NVARCHAR(500)  NOT NULL,
        fecha_creacion     DATETIME       NOT NULL,
        orden_obj_destino  NVARCHAR(MAX)      NULL
    );

    /*
        *   Extracción de las órdenes a procesar acorde a los filtros definidos en la sección de parámetros de ejecución,
        *   así como a la configuración de negocio establecida para la selección de las órdenes. Es importante resaltar que
        *   esta sección debe ser ajustada acorde a las necesidades particulares de cada caso, considerando los diferentes
        *   escenarios y casos de uso que se puedan presentar en la operación real del conector.
    */
    DECLARE @ordenes    TABLE
    (
        id_orden            NVARCHAR(MAX),
        orden_obj_origen    NVARCHAR(MAX)
    );

    /*
        *   Extracción de las órdenes a procesar acorde a los filtros definidos en la sección de parámetros de ejecución, 
        *   así como a la configuración de negocio establecida para la selección de las órdenes. Es importante resaltar que 
        *   esta sección debe ser ajustada acorde a las necesidades particulares de cada caso, considerando los diferentes 
        *   escenarios y casos de uso que se puedan presentar en la operación real del conector.
    */
    INSERT INTO @ordenes
    SELECT  TOP (@batch_size)
        id_orden,
        orden_obj_origen
    FROM ordenes
    WHERE 
        id_estado   =   2 
        AND 
        (
            intentos    <=  @num_max_intentos
            OR
            intentos IS NULL
        )
        AND 
        ISNULL(endpoint,'') !=  @endpoint;


    -- Salida anticipada si no hay datos que procesar
    IF NOT EXISTS (SELECT 1 FROM @Ordenes)
    BEGIN
        -- RAISERROR(N'[PEDIDO_INTEGRACION_VTEX] No se encontraron órdenes con los filtros indicados.', 16, 1);
        RETURN;
    END;

    -- ===========================================================
    -- SECCIÓN 4: FUNCIÓN INLINE - Cálculo de f430_notas / f431_notas
    -- ===========================================================
    --
    -- La lógica para derivar el campo "notas" se repite en Pedidos e ítems.
    -- Se documenta aquí para mantener una sola fuente de verdad.
    -- Se aplica directamente en el SELECT mediante CASE.
    --
    -- REGLA:
    --   ADDI                  → CONCAT(orderId, '-', sequence)
    --   orderId inicia con letra (NO VARIX) → segmento medio del orderId
    --   orderId numérico       → sequence

    -- ===========================================================
    -- SECCIÓN 5: TRANSFORMACIÓN JSON → FORMATO DESTINO
    -- ===========================================================

    INSERT INTO @OrdenesDestino (id_orden, endpoint, fecha_creacion, orden_obj_destino)
    SELECT
        o.id_orden,
        @endpoint                   AS endpoint,
        GETDATE()                   AS fecha_creacion,

        -- -------------------------------------------------------
        -- NODO RAÍZ: Objeto destino completo
        -- -------------------------------------------------------
        JSON_QUERY((
            SELECT

                -- -----------------------------------------------
                -- NODO: Pedidos (encabezado f430)
                -- -----------------------------------------------
                JSON_QUERY((
                    SELECT
                        CONVERT(VARCHAR(8), GETDATE(), 112)
                            AS f430_id_fecha,

                        JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document')
                            AS f430_id_tercero_fact,

                        JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document')
                            AS f430_id_tercero_rem,

                        -- Tipo de cliente según medio de pago
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
                        END AS f430_id_tipo_cli_fact,

                        -- Fecha de entrega estimada (formato YYYYMMDD)
                        CONVERT(
                            VARCHAR(8),
                            -- TRY_CAST(
                            --     LEFT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].shippingEstimateDate'), 19)
                            --     AS DATETIME
                            -- ),
                            GETDATE(),
                            112
                        ) AS f430_fecha_entrega,

                        -- Referencia: orderId (sequence)
                        LEFT(
                            CONCAT(
                                JSON_VALUE(o.orden_obj_origen, '$.orderId'),
                                N' (',
                                JSON_VALUE(o.orden_obj_origen, '$.sequence'),
                                N')'
                            ),
                            50
                        ) + ' - 1' AS f430_num_docto_referencia,

                        -- Notas: derivadas según origen del pago / formato orderId
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
                        END AS f430_notas,
                        f430_id_punto_envio = ''

                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )) AS Pedidos,


                -- -----------------------------------------------
                -- NODO: MovimientoPedidoComercial (ítems f431)
                -- -----------------------------------------------
                JSON_QUERY((
                    SELECT *
                    FROM (

                        -- ----------------------------------------
                        -- SELECT 1: Ítems del pedido
                        -- ----------------------------------------
                        SELECT
                            ROW_NUMBER() OVER (ORDER BY CAST(item.[key] AS INT))
                                AS f431_nro_registro,

                            N''
                                AS f431_referencia_item,

                            CASE JSON_VALUE(item.value, '$.ean')
                                WHEN '99999991' THEN '7707066001509'
                                ELSE JSON_VALUE(item.value, '$.ean')
                            END
                                AS f431_codigo_barras,

                            CONVERT(
                                VARCHAR(8),
                                -- TRY_CAST(
                                --     LEFT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].shippingEstimateDate'), 19)
                                --     AS DATETIME
                                -- ),
                                GETDATE(),
                                112
                            ) AS f431_fecha_entrega,

                            ISNULL(LTRIM(RTRIM(v121.v121_id_unidad_inventario)), N'UN')
                                AS f431_id_unidad_medida,

                            JSON_VALUE(item.value, '$.quantity')
                                AS f431_cant_pedida_base,

                            @id_lista_precio
                                AS f431_id_lista_precio,

                            -- Precio unitario: listPrice sin los 2 últimos dígitos decimales implícitos
                            CASE
                                WHEN LEN(ISNULL(JSON_VALUE(item.value, '$.listPrice'), N'')) > 2
                                    THEN LEFT(JSON_VALUE(item.value, '$.listPrice'), LEN(JSON_VALUE(item.value, '$.listPrice')) - 2)
                                ELSE N'0'
                            END AS f431_precio_unitario,

                            -- ---- Campos de obsequio (descuento 100 %: sellingPrice = 0) ----
                            CASE
                                WHEN ISNULL(TRY_CAST(JSON_VALUE(item.value, '$.sellingPrice') AS DECIMAL(18,2)), 0) = 0
                                    THEN 1
                                ELSE 0
                            END AS f431_ind_obsequio,

                            CASE
                                WHEN ISNULL(TRY_CAST(JSON_VALUE(item.value, '$.sellingPrice') AS DECIMAL(18,2)), 0) = 0
                                    THEN 1
                                ELSE 0
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

                            -- Notas (misma lógica que f430_notas)
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
                            END AS f431_notas

                        FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
                        LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[v121] AS v121
                            ON  v121.v121_id_barras_principal = ISNULL(
                                    JSON_VALUE(item.value, '$.ean'),
                                    JSON_VALUE(item.value, '$.refId')
                                )
                            AND v121.v121_id_cia = @id_cia

                        UNION ALL

                        -- ----------------------------------------
                        -- SELECT 2: Ítem de envío (siempre al final, nro 300)
                        -- Solo se incluye cuando el costo de envío es distinto de 0
                        -- ----------------------------------------
                        SELECT
                            @nro_registro_envio       AS f431_nro_registro,
                            @id_item_envio            AS f431_referencia_item,
                            N''                     AS f431_codigo_barras,

                            CONVERT(
                                VARCHAR(8),
                                -- TRY_CAST(
                                --     LEFT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].shippingEstimateDate'), 19)
                                --     AS DATETIME
                                -- ),
                                GETDATE(),
                                112
                            )                       AS f431_fecha_entrega,

                            N'UN'                   AS f431_id_unidad_medida,
                            1                       AS f431_cant_pedida_base,
                            @id_lista_precio          AS f431_id_lista_precio,

                            -- Valor del envío desde el nodo totals (Shipping), dividido 100 por decimales implícitos
                            ISNULL((
                                SELECT CAST(JSON_VALUE(total.value, '$.value') AS BIGINT) / 100
                                FROM OPENJSON(o.orden_obj_origen, '$.totals') AS total
                                WHERE JSON_VALUE(total.value, '$.id') = N'Shipping'
                            ), 0)                   AS f431_precio_unitario,

                            -- El envío nunca es obsequio
                            0                       AS f431_ind_obsequio,
                            0                       AS f431_ind_impto_asumido,
                            @id_motivo_normal           AS f431_id_motivo,
                            N''                     AS f431_id_ccosto_movto,
                            N'Shipping'             AS f431_notas

                        -- Condición: solo agregar el ítem si el envío tiene costo
                        WHERE JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].price') <> N'0'

                    ) AS MovimientoPedidoComercial
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )) AS MovimientoPedidoComercial,


                -- -----------------------------------------------
                -- NODO: Descuentos (f432) — solo descuentos parciales
                -- Un ítem con descuento 100 % se mapea como obsequio (arriba),
                -- por lo que aquí solo aparecen ítems con descuento < 100 %.
                -- -----------------------------------------------
                JSON_QUERY((
                    SELECT
                        CAST(item.[key] AS INT) + 1
                            AS f431_nro_registro,

                        -- Valor unitario del descuento = ABS(priceTags.value / 100) / quantity
                        CASE
                            WHEN JSON_VALUE(tag.value, '$.value') IS NOT NULL
                                THEN CAST(
                                        (
                                            ABS(TRY_CAST(JSON_VALUE(tag.value, '$.value') AS DECIMAL(18,2))) / 100.0
                                        )
                                        / NULLIF(TRY_CAST(JSON_VALUE(item.value, '$.quantity') AS DECIMAL(18,2)), 0)
                                    AS DECIMAL(18,2))
                            ELSE NULL
                        END AS f432_vlr_uni,

                        0 AS f432_tasa

                    FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
                    CROSS APPLY OPENJSON(item.value, '$.priceTags') AS tag

                    -- Solo priceTags con valor negativo (descuento) y que NO sean descuento del 100 %
                    WHERE TRY_CAST(JSON_VALUE(tag.value, '$.value') AS DECIMAL(18,2)) < 0
                      AND ISNULL(TRY_CAST(JSON_VALUE(item.value, '$.sellingPrice') AS DECIMAL(18,2)), 0) <> 0

                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )) AS Descuentos

            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS orden_obj_destino

    FROM @Ordenes AS o;


    -- ===========================================================
    -- SECCIÓN 6: RESULTADO — VISTA PREVIA
    -- ===========================================================
    --
    -- Esta sección muestra el resultado de la transformación para validación.
    -- Comentar o eliminar en producción si solo se va a ejecutar el UPDATE.
    --

    SELECT
        id_orden,
        endpoint,
        fecha_creacion,
        orden_obj_destino,
        json_value(orden_obj_destino, '$.Pedidos[0].f430_num_docto_referencia') AS f430_num_docto_referencia
    FROM @OrdenesDestino;


    -- ===========================================================
    -- SECCIÓN 7: APLICACIÓN — UPDATE en tabla origen
    -- ===========================================================
    --
    -- Descomentar para aplicar los cambios en producción.
    -- Siempre ejecutar primero la SECCIÓN 6 para validar el JSON generado.
    --

    /*
    UPDATE o
    SET
        o.endpoint          = d.endpoint,
        o.intentos          = 0,
        o.fecha_creacion    = d.fecha_creacion,
        o.orden_obj_destino = d.orden_obj_destino
    FROM dbo.ordenes AS o
    INNER JOIN @OrdenesDestino AS d
        o.id_orden  = d.id_orden;

    -- Confirmación del UPDATE
    SELECT
        @@ROWCOUNT AS filas_actualizadas,
        GETDATE()  AS fecha_ejecucion;
    */


END TRY
BEGIN CATCH

    -- ===========================================================
    -- SECCIÓN 8: MANEJO DE ERRORES
    -- ===========================================================

    DECLARE @errorMsg     NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @errorSev     INT            = ERROR_SEVERITY();
    DECLARE @errorState   INT            = ERROR_STATE();
    DECLARE @errorLine    INT            = ERROR_LINE();
    DECLARE @errorProc    NVARCHAR(200)  = ISNULL(ERROR_PROCEDURE(), N'Script inline');

    -- Mensaje de error enriquecido con contexto
    DECLARE @msgFinal NVARCHAR(4000) = CONCAT(
        N'[PEDIDO_INTEGRACION_VTEX] Error en línea ',  CAST(@errorLine  AS NVARCHAR), N' | ',
        N'Procedimiento: ',                             @errorProc,                    N' | ',
        N'Mensaje: ',                                   @errorMsg
    );

    RAISERROR(@msgFinal, @errorSev, @errorState);

END CATCH;