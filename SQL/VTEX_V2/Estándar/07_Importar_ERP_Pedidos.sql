/* =========================================================================================
   PROYECTO: VTEX ESTÁNDAR V2
   PROCESO: 07.2 IMPORTAR AL ERP - CONECTOR DE PEDIDOS (SIESA / UNOEE)
   TABLA DESTINO: dbo.ordenes (endpoint, id_estado, orden_obj_destino)
   DESCRIPCIÓN: Prepara el payload JSON completo con la estructura requerida por el Conector de
                Importación de Pedidos de Connekta Cloud / Siesa UnoEE (Nodos Pedidos,
                Movimientos de Ítems, Fletes/Envío, Impuestos y Descuentos).
   ========================================================================================= */

SET NOCOUNT ON;

DECLARE @id_tienda       INT = 1;
DECLARE @id_cia          INT = 1;
DECLARE @id_co           VARCHAR(10)  = '300';
DECLARE @id_tipo_docto   VARCHAR(10)  = 'PVW';
DECLARE @id_bodega       VARCHAR(10)  = 'BV300';
DECLARE @id_vendedor     VARCHAR(20)  = '0126';
DECLARE @endpoint        NVARCHAR(500)= 'http://localhost:82/v3.1/conectoresimportar?idCompania=6230&idSistema=2&idDocumento=205744&nombreDocumento=PEDIDOS_ECOMMERCE';

-- 1. CONTROL DE DUPLICADOS: Eliminar posibles duplicados huérfanos por tienda y orden
;WITH Duplicados AS (
    SELECT id, id_tienda, id_orden, ROW_NUMBER() OVER (PARTITION BY id_tienda, id_orden ORDER BY id) AS rn
    FROM [dbo].[ordenes] 
    WHERE id_tienda = @id_tienda
)
DELETE FROM Duplicados WHERE rn > 1;

-- 2. VALIDACIÓN DE EXISTENCIA EN ERP: Si el pedido ya existe en Siesa, avanzar a Estado 4 (Entidades/Siguiente fase)
UPDATE o 
SET 
    o.orden_obj_destino = NULL, 
    o.endpoint          = NULL, 
    o.intentos          = 0, 
    o.id_estado         = 4
FROM [dbo].[ordenes] o
INNER JOIN [UnoEE_ERP].[dbo].[t430_cm_pv_docto] t 
    ON t.f430_num_docto_referencia = CONCAT('0', CAST(o.id_tienda AS VARCHAR), ' ', JSON_VALUE(o.orden_obj_origen, '$.sequence')) 
   AND t.f430_id_cia = @id_cia
   AND t.f430_ind_estado <> 9 -- No anulado
WHERE o.id_tienda = @id_tienda 
  AND o.id_estado = 3;

-- 3. TABLA TEMPORAL: Numeración secuencial exacta de ítems por orden
IF OBJECT_ID('tempdb..#ItemsNumerados') IS NOT NULL DROP TABLE #ItemsNumerados;

SELECT 
    o.id_orden,
    o.id_tienda,
    [ItemId]     = JSON_VALUE(item.value, '$.id'),
    [UniqueId]   = JSON_VALUE(item.value, '$.uniqueId'),
    [Ean]        = JSON_VALUE(item.value, '$.ean'),
    [RefId]      = JSON_VALUE(item.value, '$.refId'),
    [nro_reg]    = ROW_NUMBER() OVER (PARTITION BY o.id_orden ORDER BY ISNULL(JSON_VALUE(item.value, '$.ean'), JSON_VALUE(item.value, '$.refId')))
INTO #ItemsNumerados
FROM [dbo].[ordenes] o
CROSS APPLY OPENJSON(o.orden_obj_origen, '$.items') AS item
WHERE o.id_tienda = @id_tienda
  AND o.id_estado = 3;

-- 4. GENERAR PAYLOAD COMPLETO DEL CONECTOR DE PEDIDOS
UPDATE o
SET 
    o.endpoint          = @endpoint,
    o.intentos          = 0,
    o.fecha_creacion    = GETDATE(),
    o.orden_obj_destino = JSON_QUERY((
        SELECT
            -- -----------------------------------------------------------------------------
            -- NODO 1: PEDIDOS (Encabezado Documento f430 y Despacho f419)
            -- -----------------------------------------------------------------------------
            JSON_QUERY((
                SELECT 
                    [f430_id_co]                    = @id_co,
                    [f430_id_tipo_docto]            = @id_tipo_docto,
                    [f430_consec_docto]             = '1',
                    [f430_id_fecha]                 = CONVERT(VARCHAR(8), GETDATE(), 112), -- Obligatorio fecha actual
                    [f430_id_tercero_fact]          = CASE 
                                                          WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), '') = '' 
                                                          THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                                                          ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') 
                                                      END,
                    [f430_id_sucursal_fact]         = '001',
                    [f430_id_tercero_rem]           = CASE 
                                                          WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), '') = '' 
                                                          THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                                                          ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') 
                                                      END,
                    [f430_id_sucursal_rem]          = '001',
                    [f430_id_co_fact]               = @id_co,
                    [f430_fecha_entrega]            = CONVERT(VARCHAR(8), GETDATE(), 112),
                    [f430_num_dias_entrega]         = '3',
                    [f430_num_docto_referencia]     = CONCAT('0', CAST(o.id_tienda AS VARCHAR), ' ', JSON_VALUE(o.orden_obj_origen, '$.sequence')),
                    [f430_id_cond_pago]             = '000',
                    [f430_notas]                    = CONCAT(
                                                          'VTEX: ', JSON_VALUE(o.orden_obj_origen, '$.orderId'),
                                                          ' | Sec: ', JSON_VALUE(o.orden_obj_origen, '$.sequence'),
                                                          ' | Pago: ', ISNULL(JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName'), 'Web'),
                                                          ' | Entrega: ', ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany'), 'Transportadora')
                                                      ), 
                    [f430_id_cli_contado]           = '',
                    [f430_id_tercero_vendedor]      = @id_vendedor,
                    [f419_contacto]                 = SUBSTRING(UPPER(CONCAT(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'), ' ', ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'), ''))), 1, 40),
                    [f419_direccion1]               = SUBSTRING(UPPER(REPLACE(CONCAT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.street'), ' ', ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.number'), '')), '''', '')), 1, 40),
                    [f419_direccion2]               = SUBSTRING(UPPER(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.complement'), '')), 1, 40),
                    [f419_direccion3]               = SUBSTRING(UPPER(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.neighborhood'), '')), 1, 40),
                    [f419_id_depto]                 = SUBSTRING(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.postalCode'), 1, 2),
                    [f419_id_ciudad]                = SUBSTRING(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.postalCode'), 3, 3),
                    [f419_telefono]                 = SUBSTRING(REPLACE(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.phone'), '0'), '+57', ''), 1, 15),
                    [f419_email]                    = SUBSTRING(LOWER(TRIM(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.email'), 'facturacion@ecommerce.com'))), 1, 40)
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Pedidos,

            -- -----------------------------------------------------------------------------
            -- NODO 2: MOVIMIENTOS (Detalle de Ítems f431 y Registro Adicional de Flete)
            -- -----------------------------------------------------------------------------
            JSON_QUERY((
                SELECT *
                FROM (
                    -- A. Movimientos de Ítems Comprados
                    SELECT 
                        [f431_id_co]             = @id_co,
                        [f431_id_tipo_docto]     = @id_tipo_docto,
                        [f431_consec_docto]      = '1',
                        [f431_nro_registro]      = it.nro_reg,
                        [f431_referencia_item]   = '',
                        [f431_codigo_barras]     = JSON_VALUE(item.value, '$.ean'),
                        [f431_id_bodega]         = @id_bodega,
                        [f431_id_motivo]         = '13',
                        [f431_id_co_movto]       = @id_co,
                        [f431_id_un_movto]       = '01',
                        [f431_fecha_entrega]     = CONVERT(VARCHAR(8), GETDATE(), 112),
                        [f431_num_dias_entrega]  = '3',
                        [f431_id_unidad_medida]  = 'UND',
                        [f431_cant_pedida_base]  = CAST(JSON_VALUE(item.value, '$.quantity') AS INT),
                        [f431_precio_unitario]   = CASE 
                                                       WHEN ISNULL(v121.v121_id_grupo_impositivo, '0001') = '0001' 
                                                       THEN CONVERT(INT, ROUND((CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) / 1.19) / 100.0, 0))
                                                       ELSE CONVERT(INT, ROUND(CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) / 100.0, 0))
                                                   END
                    FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
                    INNER JOIN #ItemsNumerados it 
                        ON it.id_orden = o.id_orden 
                       AND it.id_tienda = o.id_tienda 
                       AND it.ItemId = JSON_VALUE(item.value, '$.id') 
                       AND it.UniqueId = JSON_VALUE(item.value, '$.uniqueId')
                    LEFT JOIN [UnoEE_ERP].[dbo].[v121] v121 
                        ON v121.v121_id_barras_principal = JSON_VALUE(item.value, '$.ean') 
                       AND v121.v121_id_cia = @id_cia

                    UNION ALL

                    -- B. Movimiento Adicional por Fletes / Transporte (si aplica costo mayor a 0)
                    SELECT 
                        [f431_id_co]             = @id_co,
                        [f431_id_tipo_docto]     = @id_tipo_docto,
                        [f431_consec_docto]      = '1',
                        [f431_nro_registro]      = (SELECT COUNT(*) FROM OPENJSON(o.orden_obj_origen, '$.items')) + 1,
                        [f431_referencia_item]   = 'FLETES',
                        [f431_codigo_barras]     = '',
                        [f431_id_bodega]         = @id_bodega,
                        [f431_id_motivo]         = '13',
                        [f431_id_co_movto]       = @id_co,
                        [f431_id_un_movto]       = '01',
                        [f431_fecha_entrega]     = CONVERT(VARCHAR(8), GETDATE(), 112),
                        [f431_num_dias_entrega]  = '3',
                        [f431_id_unidad_medida]  = 'UND',
                        [f431_cant_pedida_base]  = 1,
                        [f431_precio_unitario]   = CONVERT(INT, ROUND(CAST(JSON_VALUE(shipping.value, '$.value') AS FLOAT) / 100.0, 0))
                    FROM OPENJSON(o.orden_obj_origen, '$.totals') AS shipping
                    WHERE JSON_VALUE(shipping.value, '$.id') = 'Shipping'
                      AND CAST(ISNULL(JSON_VALUE(shipping.value, '$.value'), 0) AS INT) > 0
                ) AS movimientos
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Movimientos,

            -- -----------------------------------------------------------------------------
            -- NODO 3: IMPUESTOS (Tasas de IVA por ítem f433)
            -- -----------------------------------------------------------------------------
            JSON_QUERY((
                SELECT 
                    [F430_ID_CO]             = @id_co,
                    [F430_ID_TIPO_DOCTO]     = @id_tipo_docto,
                    [F430_CONSEC_DOCTO]      = '1',
                    [F431_NRO_REGISTRO]      = it.nro_reg,
                    [F433_ID_LLAVE_IMPUESTO] = 'IV02',
                    [F433_TASA]              = CASE WHEN ISNULL(v121.v121_id_grupo_impositivo, '0001') = '0001' THEN 19 ELSE 0 END
                FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
                INNER JOIN #ItemsNumerados it 
                    ON it.id_orden = o.id_orden 
                   AND it.id_tienda = o.id_tienda 
                   AND it.ItemId = JSON_VALUE(item.value, '$.id') 
                   AND it.UniqueId = JSON_VALUE(item.value, '$.uniqueId')
                LEFT JOIN [UnoEE_ERP].[dbo].[v121] v121 
                    ON v121.v121_id_barras_principal = JSON_VALUE(item.value, '$.ean') 
                   AND v121.v121_id_cia = @id_cia
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Impuestos,

            -- -----------------------------------------------------------------------------
            -- NODO 4: DESCUENTOS (Descuentos comerciales aplicados en checkout)
            -- -----------------------------------------------------------------------------
            JSON_QUERY((
                SELECT 
                    [f430_id_co]         = @id_co,
                    [f430_id_tipo_docto] = @id_tipo_docto,
                    [f430_consec_docto]  = '1',
                    [f431_nro_registro]  = it.nro_reg,
                    [f432_id_dscto]      = '01',
                    [f432_tasa]          = 0,
                    [f432_valor]         = CONVERT(INT, ROUND(ABS(CAST(JSON_VALUE(item.value, '$.priceTags[0].value') AS FLOAT)) / 100.0, 0))
                FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
                INNER JOIN #ItemsNumerados it 
                    ON it.id_orden = o.id_orden 
                   AND it.id_tienda = o.id_tienda 
                   AND it.ItemId = JSON_VALUE(item.value, '$.id') 
                   AND it.UniqueId = JSON_VALUE(item.value, '$.uniqueId')
                WHERE CAST(ISNULL(JSON_VALUE(item.value, '$.priceTags[0].value'), 0) AS INT) < 0
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Descuentos

        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    ))
FROM [dbo].[ordenes] o
WHERE o.id_tienda = @id_tienda
  AND o.id_estado = 3
  AND ISNULL(o.intentos, 0) <= 3
  AND ISNULL(o.endpoint, '') <> @endpoint;

-- Limpieza
IF OBJECT_ID('tempdb..#ItemsNumerados') IS NOT NULL DROP TABLE #ItemsNumerados;
