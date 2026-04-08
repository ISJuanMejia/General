-- VALIDACION CASOS EXTRA;OS QUE LA ORDEN QUEDE DUPLICADA
WITH Duplicados AS (
    SELECT id, id_tienda, id_orden, ROW_NUMBER() OVER (PARTITION BY id_tienda, id_orden ORDER BY id) AS fila
    FROM ordenes 
	WHERE id_tienda = 1)
DELETE FROM Duplicados 
WHERE fila > 1;

DECLARE @endpoint NVARCHAR(500) = 'http://localhost:82/v3.1/conectoresimportar?idCompania=6230&idSistema=2&idDocumento=205744&nombreDocumento=SPEEDO_PEDIDOS_INT_ECOMM'

-- VALIDACION CASOS EXTRA;OS QUE NO ACTUALICE EL ID DE ESTADO
UPDATE e SET orden_obj_destino = null, endpoint = null, intentos = 0, id_estado = id_estado + 1
FROM ordenes e
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t430_cm_pv_docto t 
ON t.f430_num_docto_referencia = '0' + CAST(e.id_tienda AS NVARCHAR) + ' ' + JSON_VALUE(e.orden_obj_origen, '$.sequence')
AND t.f430_ind_estado <> 9
WHERE id_tienda = 1 AND id_estado = 3;

-- VALIDACION CASOS EXTRA;OS QUE NO ACTUALICE EL ID DE ESTADO
UPDATE e SET orden_obj_destino = null, endpoint = null, intentos = 0, id_estado = id_estado + 1
-- select *
FROM ordenes e
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t430_cm_pv_docto t 
ON t.f430_num_docto_referencia = '0' + CAST(e.id_tienda AS NVARCHAR) + ' ' + JSON_VALUE(e.orden_obj_origen, '$.sequence')
AND t.f430_ind_estado <> 9
WHERE id_tienda = 1 AND id_estado = 4 AND intentos >= 2;


IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL DROP TABLE #ordenes;

SELECT *
INTO #ordenes
FROM ordenes
WHERE id_tienda = 1
AND id_estado = 3
AND orden_obj_destino is null
AND ISNULL(endpoint, '') != @endpoint;


IF OBJECT_ID('tempdb..#TempOrdenes') IS NOT NULL DROP TABLE #TempOrdenes;

CREATE TABLE #TempOrdenes (
    id_orden NVARCHAR(50),
    id_tienda INT,
    endpoint NVARCHAR(500),
    fecha_creacion DATETIME,
    orden_obj_destino NVARCHAR(MAX)
);

IF OBJECT_ID('tempdb..#ItemsNumReg') IS NOT NULL DROP TABLE #ItemsNumReg;

SELECT 
    o.id_orden,
    o.id_tienda,
    JSON_VALUE(item.value, '$.id') AS Id,
	JSON_VALUE(item.value, '$.uniqueId') AS UniqueId,
    ROW_NUMBER() OVER (PARTITION BY o.id_orden ORDER BY ISNULL(JSON_VALUE(item.value, '$.ean'), JSON_VALUE(item.value, '$.refId'))) AS f431_nro_registro
INTO #ItemsNumReg
FROM #ordenes o
CROSS APPLY OPENJSON(o.orden_obj_origen, '$.items') AS item
ORDER BY ISNULL(JSON_VALUE(item.value, '$.ean'), JSON_VALUE(item.value, '$.refId'))



INSERT INTO #TempOrdenes (id_orden, id_tienda, endpoint, fecha_creacion, orden_obj_destino)
SELECT 
    id_orden,
    id_tienda,
    @endpoint AS endpoint,
    GETDATE() AS fecha_creacion,
    JSON_QUERY((
        SELECT
            -- Nodo Pedidos
            JSON_QUERY((
                SELECT 
                    '147' AS f430_id_co,
                    'EPV' AS f430_id_tipo_docto,
                    '1' AS f430_consec_docto,
                    CONVERT(VARCHAR(8), GETDATE(), 112) AS f430_id_fecha,
                    CASE 
						  WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = '' 
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
					END AS f430_id_tercero_fact,
                    '001' AS f430_id_sucursal_fact,
                     CASE 
						  WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = '' 
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
					END AS f430_id_tercero_rem,
                    '001' AS f430_id_sucursal_rem,
                    '147' AS f430_id_co_fact,
                    CONVERT(VARCHAR(8), GETDATE(), 112) AS f430_fecha_entrega,
                    '3' AS f430_num_dias_entrega,
                    '0' + CAST(id_tienda AS NVARCHAR) + ' ' + JSON_VALUE(orden_obj_origen, '$.sequence') AS f430_num_docto_referencia,
                    '000' AS f430_id_cond_pago,
                    CONCAT(
					    'OrderId: ', JSON_VALUE(orden_obj_origen, '$.orderId'),
					    ' Secuencia: ', JSON_VALUE(orden_obj_origen, '$.sequence'),
					   ' Metodo Pago: ', CASE 
											  WHEN JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = 'Assumed value by affiliate ADDI(DDD)'
											  THEN 'Addi' 
											  ELSE ISNULL(JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName'), '') END,
					    ' Tienda: ',
					    ISNULL((
					    SELECT 
					        CASE 
					            WHEN JSON_VALUE(logistics.value, '$.deliveryCompany') = 'Coordinadora' THEN 
					                CASE 
					                    WHEN SUBSTRING(JSON_VALUE(orden_obj_origen, '$.orderId'), 1, 3) = 'MLC' THEN 'Mercado Libre'
					                    WHEN SUBSTRING(JSON_VALUE(orden_obj_origen, '$.orderId'), 1, 3) = 'GVL' THEN 'AGAVAL'
					                    ELSE JSON_VALUE(orden_obj_origen, '$.sellers[0].name')
					                END
					            ELSE 
					                -- Si es punto de recogida (pickup-in-point), traemos el friendlyName
					                ISNULL((
					                    SELECT TOP 1 
					                        JSON_VALUE(sla.value, '$.pickupStoreInfo.friendlyName')
					                    FROM OPENJSON(logistics.value, '$.slas') AS sla
					                    WHERE JSON_VALUE(sla.value, '$.id') = JSON_VALUE(logistics.value, '$.selectedSla')
					                    AND JSON_VALUE(sla.value, '$.deliveryChannel') = 'pickup-in-point'
					                ), JSON_VALUE(logistics.value, '$.deliveryCompany'))
					        END
					    FROM OPENJSON(orden_obj_origen, '$.shippingData.logisticsInfo') AS logistics
					    WHERE logistics.[key] = '0'
					), 'SIN INFO COURIER')) AS f430_notas, 
                    '' AS f430_id_cli_contado,
                    '800130985' AS f430_id_tercero_vendedor,
                    LEFT(UPPER(CONCAT(
                        REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), '&', 'Y'), ' ',
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                    )), 40) AS f419_contacto,
                    LEFT(UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street')), 40) AS f419_direccion1,
                    LEFT(UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement')), 40) AS f419_direccion2,
                    LEFT(UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood')), 40) AS f419_direccion3,
                    LEFT(UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode')), 2) AS f419_id_depto,
                    SUBSTRING(UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode')), 3, 5) AS f419_id_ciudad,
                    REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), '+57', '') AS f419_telefono,
                    LEFT(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email')), 40) AS f419_email
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Pedidos,

            -- Nodo Movimientos
			JSON_QUERY((
			    SELECT *
			    FROM (
			        -- Movimientos por ítems
			        SELECT 
			            '147' AS f431_id_co,
			            'EPV' AS f431_id_tipo_docto,
			            '1' AS f431_consec_docto,
			            i.f431_nro_registro AS f431_nro_registro,
			            '' AS f431_referencia_item,
			            JSON_VALUE(item.value, '$.ean') AS f431_codigo_barras,
			            'BV147' AS f431_id_bodega,
			            CASE 
			                WHEN SUBSTRING(JSON_VALUE(orden_obj_origen, '$.orderId'), 1, 3) = 'MLC' THEN '25'
			                WHEN SUBSTRING(JSON_VALUE(orden_obj_origen, '$.orderId'), 1, 3) = 'GVL' THEN '26'
			                ELSE '13'
			            END AS f431_id_motivo,
			            '147' AS f431_id_co_movto,
			            '02' AS f431_id_un_movto,
			            CONVERT(VARCHAR(8), GETDATE(), 112) AS f431_fecha_entrega,
			            '3' AS f431_num_dias_entrega,
			            ISNULL(v121.v121_id_unidad_inventario, 'UND') AS f431_id_unidad_medida,
			            JSON_VALUE(item.value, '$.quantity') AS f431_cant_pedida_base,
			            CASE 
			                WHEN v121.v121_id_grupo_impositivo = '0001' 
			                    THEN CONVERT(INT, ROUND(CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) / 1.19 / 100.0, 0))
			                ELSE CONVERT(INT, ROUND(CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) / 100.0, 0))
			            END AS f431_precio_unitario
			        FROM OPENJSON(orden_obj_origen, '$.items') AS item
					INNER JOIN #ItemsNumReg i
						 ON i.id_orden = id_orden
						 AND i.id_tienda = id_tienda
						 AND JSON_VALUE(item.value, '$.id') = i.Id
						 AND JSON_VALUE(item.value, '$.uniqueId') = i.UniqueId
			        LEFT JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].[v121] v121
			            ON v121.v121_id_barras_principal = JSON_VALUE(item.value, '$.ean')
			            AND v121.v121_id_cia = 1
			
			        UNION ALL
			
			        -- Movimiento adicional por envío
			        SELECT 
			            '147' AS f431_id_co,
			            'EPV' AS f431_id_tipo_docto,
			            '1' AS f431_consec_docto,
			            (SELECT COUNT(*) FROM OPENJSON(orden_obj_origen, '$.items')) + 1 AS f431_nro_registro,
			            'FLETES' AS f431_referencia_item,
			            '' AS f431_codigo_barras,
			            'BV147' AS f431_id_bodega,
			            CASE 
			                WHEN SUBSTRING(JSON_VALUE(orden_obj_origen, '$.orderId'), 1, 3) = 'MLC' THEN '25'
			                WHEN SUBSTRING(JSON_VALUE(orden_obj_origen, '$.orderId'), 1, 3) = 'GVL' THEN '26'
			                ELSE '13'
			            END AS f431_id_motivo,
			            '147' AS f431_id_co_movto,
			            '01' AS f431_id_un_movto,
			            CONVERT(VARCHAR(8), GETDATE(), 112) AS f431_fecha_entrega,
			            '3' AS f431_num_dias_entrega,
			            'UND' AS f431_id_unidad_medida,
			            '1' AS f431_cant_pedida_base,
			            CONVERT(INT, ROUND(CAST(JSON_VALUE(shipping.value, '$.value') AS FLOAT) / 100.0, 0)) AS f431_precio_unitario
			        FROM OPENJSON(orden_obj_origen, '$.totals') AS shipping
			        WHERE JSON_VALUE(shipping.value, '$.id') = 'Shipping'
			              AND JSON_VALUE(shipping.value, '$.value') IS NOT NULL
						  AND CAST(JSON_VALUE(shipping.value, '$.value') AS INT) > 0
			    ) AS movimientos
			    FOR JSON PATH, INCLUDE_NULL_VALUES
			)) AS Movimientos,

			-- Nodo Impuestos
			JSON_QUERY((
			    SELECT *
			    FROM (
			        SELECT 
			            '147' AS F430_ID_CO,
			            'EPV' AS F430_ID_TIPO_DOCTO,
			            '1' AS F430_CONSEC_DOCTO,
			            i.f431_nro_registro AS F431_NRO_REGISTRO,
			            'IV02' AS F433_ID_LLAVE_IMPUESTO,
			            CASE 
			                WHEN v121.v121_id_grupo_impositivo = '0001' THEN 19 
			                ELSE 0 
			            END AS F433_TASA,
			            'IV02' AS F433_ID_LLAVE_IMPUESTO_DESC,
			            CASE 
			                WHEN v121.v121_id_grupo_impositivo = '0001' THEN 19 
			                ELSE 0 
			            END AS F433_TASA_DESC
			        FROM OPENJSON(orden_obj_origen, '$.items') AS item
					INNER JOIN #ItemsNumReg i
						 ON i.id_orden = id_orden
						 AND i.id_tienda = id_tienda
						 AND JSON_VALUE(item.value, '$.id') = i.Id
						 AND JSON_VALUE(item.value, '$.uniqueId') = i.UniqueId
			        INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].[v121] v121
			            ON v121.v121_id_barras_principal = JSON_VALUE(item.value, '$.ean')
			            AND v121.v121_id_cia = 1
			            AND v121_id_grupo_impositivo IS NOT NULL
			        WHERE NOT EXISTS (
			            SELECT 1 
			            FROM OPENJSON(orden_obj_origen, '$.ratesAndBenefitsData.rateAndBenefitsIdentifiers') 
			            WHERE JSON_VALUE(value, '$.name') = 'Impuesto en San Andres'
			        )
			    ) AS impuestos
			    FOR JSON PATH, INCLUDE_NULL_VALUES
			)) AS Impuestos,

    		-- Nodo Descuentos
			JSON_QUERY((
			    SELECT *
			    FROM (
			        SELECT 
			            '147' AS f430_id_co,
			            'EPV' AS f430_id_tipo_docto,
			            '1' AS f430_consec_docto,
						i.f431_nro_registro AS f431_nro_registro,
			            -- f432_vlr_uni con lógica fiel al modelo original
			            CASE 
			                WHEN EXISTS (
							    SELECT 1 
							    FROM OPENJSON(orden_obj_origen, '$.ratesAndBenefitsData.rateAndBenefitsIdentifiers') 
							    WHERE JSON_VALUE(value, '$.name') = 'Impuesto en San Andres'
							)  THEN 
			                    -- Si tiene impuesto San Andres
			                    CASE 
			                        WHEN 
			                            ROUND((CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) / 1.19) / 100.0, 0) = 
			                            ROUND(CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT) / 100.0, 0)
			                        THEN 0
			                        WHEN v121.v121_id_grupo_impositivo = '0001' THEN
									    -- San Andrés + grupo 0001 → quitar IVA al descuento
									    CONVERT(INT, ROUND(
									        ((CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) - 
									          CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT)) / 100.0) -
									        (((CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) / 1.19) / 100.0) * 0.19)
									    , 0))
									ELSE
									    -- San Andrés + otro grupo → NO se quita IVA
									   CONVERT(INT, ROUND(
									        ((CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) - 
									          CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT)) / 100.0) -
									        (((CAST(JSON_VALUE(item.value, '$.price') AS FLOAT)) / 100.0) * 0.19)
									    , 0))
			                    END
			
			                ELSE 
			                    -- Si NO tiene impuesto San Andres
			                    CASE 
			                        WHEN ABS(CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) - CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT)) < 1 THEN 
			                            CONVERT(INT, ROUND(CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) / 100.0, 0))
			                        ELSE 
			                            CASE 
			                                WHEN v121.v121_id_grupo_impositivo = '0001' THEN 
			                                    CONVERT(INT, ROUND(
			                                        ((CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) - 
			                                          CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT)) / 1.19) / 100.0, 0))
			                                ELSE 
			                                    CONVERT(INT, ROUND(
			                                        (CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) - 
			                                         CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT)) / 100.0, 0))
			                            END
			                    END
			            END AS f432_vlr_uni
			
			        FROM OPENJSON(orden_obj_origen, '$.items') AS item
					INNER JOIN #ItemsNumReg i
						 ON i.id_orden = id_orden
						 AND i.id_tienda = id_tienda
						 AND JSON_VALUE(item.value, '$.id') = i.Id
						 AND JSON_VALUE(item.value, '$.uniqueId') = i.UniqueId
			        LEFT JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].[v121] v121
			            ON v121.v121_id_barras_principal = ISNULL(JSON_VALUE(item.value, '$.ean'), JSON_VALUE(item.value, '$.refId'))
			            AND v121.v121_id_cia = 1
			        WHERE 
			            CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT) <> 0 AND
			            (
			                (CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) - CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT)) <> 0
			            )
			    ) AS descuentos
			    WHERE f432_vlr_uni > 0
			    FOR JSON PATH, INCLUDE_NULL_VALUES
			)) AS Descuento

        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER --, INCLUDE_NULL_VALUES
    ))
FROM #ordenes;

-- Aplicar los cambios a la tabla ordenes
UPDATE o
SET 
    o.endpoint = t.endpoint,
    o.intentos = 0,
    o.fecha_creacion = t.fecha_creacion,
    o.orden_obj_destino = t.orden_obj_destino
FROM ordenes o
JOIN #TempOrdenes t ON o.id_orden = t.id_orden AND o.id_tienda = t.id_tienda;