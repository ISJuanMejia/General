DECLARE @endpoint nvarchar(500) = 'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?idCompania=4879&idSistema=2&idDocumento=220176&nombreDocumento=pedidos_maderkit_vtex_col';

IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL
    DROP TABLE #ordenes;

select * 
into #ordenes
from ordenes
where id_tienda = 1 
and id_estado = 3
AND (intentos <= 3 OR intentos is null)
AND ISNULL(endpoint, '') != @endpoint
AND id > 3;
--and id = 66

-- Verificar si la tabla temporal tiene datos
IF EXISTS (SELECT 1 FROM #ordenes)
BEGIN
   
IF OBJECT_ID('tempdb..#TempBodegasERP') IS NOT NULL
    DROP TABLE #TempBodegasERP;

CREATE TABLE #TempBodegasERP (
    ean NVARCHAR(50),
    warehouse_ecommerce NVARCHAR(10),
    bodega_erp NVARCHAR(10),
    cantidad_disponible INT
);

INSERT INTO #TempBodegasERP (ean, warehouse_ecommerce, bodega_erp, cantidad_disponible)
SELECT * FROM 
OPENROWSET(
    'SQLNCLI', 
    'Server=siesa-m3-sqlsw-db13.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_Maderkit_Real;UID=maderkit;PWD=Maderkit$12$%',
	'SELECT 
		v121_referencia AS ean,
		''1_1'' AS warehouse_ecommerce,
		f150_id AS bodega_erp,
		CONVERT(INT, f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1)) AS cantidad_disponible
	FROM v121 v121
		INNER JOIN t400_cm_existencia t400	ON f400_rowid_item_ext	= v121_rowid_item_ext
		INNER JOIN t150_mc_bodegas t150		ON f150_rowid			= f400_rowid_bodega
	WHERE t150.f150_id IN (''PTNT'', ''PT11'',''PT19'') 
		AND CONVERT(INT, f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1)) > 0
		AND v121_id_cia = 1'
);

IF OBJECT_ID('tempdb..#TempOrdenes') IS NOT NULL
    DROP TABLE #TempOrdenes;

CREATE TABLE #TempOrdenes (
    id_tienda INT,
    id_orden NVARCHAR(50),
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

INSERT INTO #TempOrdenes (id_tienda, id_orden, endpoint, fecha_creacion, orden_obj_destino)
SELECT 
	id_tienda,
	id_orden,
    @endpoint as endpoint,
    getdate() as fecha_creacion,
    json_query(( 
	 select 
	        --########   Nodo Pedidos   ########
            json_query(( 
                select 
					convert(varchar(8), getdate(), 112)									as f430_id_fecha,
					json_value(orden_obj_origen, '$.clientProfileData.document')		as f430_id_tercero_fact,
					'001'																as f430_id_sucursal_fact,
					json_value(orden_obj_origen, '$.clientProfileData.document')		as f430_id_tercero_rem,
                    '001'																as f430_id_sucursal_rem,
					CONVERT(VARCHAR(8), DATEADD(DAY, 2, GETDATE()), 112)				as f430_fecha_entrega,
					CASE
						WHEN JSON_VALUE(orden_obj_origen, '$.orderId') LIKE 'GVL-%'		THEN 'G-' + PARSENAME(REPLACE(JSON_VALUE(orden_obj_origen, '$.orderId'), '-', '.'), 2)
						WHEN JSON_VALUE(orden_obj_origen, '$.orderId') LIKE 'DDD-%'		THEN 'D-' + PARSENAME(REPLACE(JSON_VALUE(orden_obj_origen, '$.orderId'), '-', '.'), 2)
						WHEN JSON_VALUE(orden_obj_origen, '$.orderId') LIKE 'VPC-%'		THEN 'P-' + PARSENAME(REPLACE(JSON_VALUE(orden_obj_origen, '$.orderId'), '-', '.'), 2)
						WHEN JSON_VALUE(orden_obj_origen, '$.orderId') LIKE '[0-9]%'	THEN LEFT(JSON_VALUE(orden_obj_origen, '$.orderId'), 15)
						ELSE JSON_VALUE(orden_obj_origen, '$.sequence')
					END AS f430_num_docto_referencia,
					CASE
						WHEN JSON_VALUE(orden_obj_origen, '$.orderId') LIKE 'GVL-%'		THEN 'GVL'
						WHEN JSON_VALUE(orden_obj_origen, '$.orderId') LIKE 'DDD-%'		THEN 'ADDI'
						WHEN JSON_VALUE(orden_obj_origen, '$.orderId') LIKE 'VPC-%'		THEN 'PCO'
						ELSE CONCAT('PW ',IIF(JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName')
								LIKE '%Pago Contraentrega%',JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName'),''))
					END AS f430_notas
                for json path, include_null_values
            )) as Pedidos,

			--########   Movimiento   ########
			json_query(( 
			    SELECT *
			    FROM (
			        SELECT
						ROW_NUMBER() OVER (ORDER BY (SELECT NULL))																AS f431_nro_registro,
						JSON_VALUE(item.value, '$.refId')																		AS f431_referencia_item,
						 CASE 
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'mktaddi'		 THEN '200322'
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'maderkit'		 THEN '200301'
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'agaval'		 THEN '200327'
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'puntoscolombia' THEN '200323'
							ELSE '200301'
						END																										AS f431_id_ccosto_movto,
						CONVERT(VARCHAR(8), DATEADD(DAY, 2, GETDATE()), 112)													AS f431_fecha_entrega,
			            JSON_VALUE(item.value, '$.quantity')																	AS f431_cant_pedida_base,
						CASE 
							WHEN TRY_CAST(JSON_VALUE(item.value, '$.price') AS DECIMAL(18,2)) IS NOT NULL
								THEN CAST(
										CAST(
											TRY_CAST(
												JSON_VALUE(item.value, '$.price') 
											AS DECIMAL(18,2)) / 100 
										AS BIGINT)
									AS VARCHAR(20))
							ELSE '0'
						END AS f431_precio_unitario

			        FROM OPENJSON(orden_obj_origen, '$.items') AS item
					LEFT JOIN #TempBodegasERP ON ean = JSON_VALUE(item.value, '$.RefId')
			        OUTER APPLY (
			            SELECT TOP 1 *
			            FROM OPENJSON(orden_obj_origen, '$.shippingData.logisticsInfo') logistics
			            WHERE JSON_VALUE(logistics.value, '$.itemId') = JSON_VALUE(item.value, '$.id')
			        ) AS logistics
                   
					UNION ALL

					SELECT 
						CAST((SELECT COUNT(*) FROM OPENJSON(orden_obj_origen, '$.items')) + 1 AS VARCHAR(20)) AS f431_nro_registro,
						'0005016' AS f431_referencia_item,

						CASE 
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'mktaddi'         THEN '200322'
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'maderkit'        THEN '200301'
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'agaval'          THEN '200327'
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'puntoscolombia'  THEN '200323'
							ELSE '200301'
						END AS f431_id_ccosto_movto,
						CONVERT(VARCHAR(8), DATEADD(DAY, 2, GETDATE()), 112) AS f431_fecha_entrega,
						'1' AS f431_cant_pedida_base,
						CASE 
							WHEN shipping.value IS NOT NULL
								THEN CAST(
										CAST(shipping.value / 100.0 AS DECIMAL(18,2)) 
									 AS VARCHAR(20))
							ELSE '0.00'
						END AS f431_precio_unitario

					FROM OPENJSON(orden_obj_origen, '$.totals')
					WITH (
						id NVARCHAR(50),
						value INT
					) AS shipping

					WHERE shipping.id = 'Shipping'
					AND shipping.value <> 0

					UNION ALL

					select 
                        CAST((SELECT COUNT(*) FROM OPENJSON(orden_obj_origen, '$.items')) + 2 AS VARCHAR(20))					AS f431_nro_registro,
                        '0012162'																								AS f431_referencia_item,
                        CASE 
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'mktaddi'		 THEN '200322'
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'maderkit'		 THEN '200301'
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'agaval'		 THEN '200327'
							WHEN TRIM(JSON_VALUE(orden_obj_origen, '$.marketplace.name')) = 'puntoscolombia' THEN '200323'
							ELSE '200301'
						END																										AS f431_id_ccosto_movto,
                        CONVERT(VARCHAR(8), DATEADD(DAY, 2, GETDATE()), 112)													AS f431_fecha_entrega,
						json_value(item.value, '$.bundleItems[0].quantity')														AS f431_cant_pedida_base,
						
						CASE 
							WHEN TRY_CAST(JSON_VALUE(item.value, '$.bundleItems[0].price') AS DECIMAL(18,2)) IS NOT NULL
								THEN CAST(
										CAST(
											TRY_CAST(
												JSON_VALUE(item.value, '$.bundleItems[0].price') 
											AS DECIMAL(18,2)) / 100 
										AS BIGINT)
									AS VARCHAR(20))
							ELSE '0'
						END AS f431_precio_unitario

					FROM OPENJSON(orden_obj_origen, '$.items') AS item
					WHERE JSON_VALUE(item.value, '$.bundleItems[0].id') = '5'

                ) as movimientos
                for json path, include_null_values
            )) as Movto_Pedidos_comercial,

			--########   Descuentos   ########
			json_query((
				SELECT *
				FROM (
					SELECT
						CAST(i.f431_nro_registro AS VARCHAR(20)) AS f431_nro_registro,

						CAST(
							CAST(
								ABS(
									CASE 
										WHEN d.rawValueStr LIKE '%.%' 
											THEN TRY_CAST(d.rawValueStr AS DECIMAL(18,4))
										ELSE TRY_CAST(d.rawValueStr AS DECIMAL(18,4)) / 100
									END
								) 
								/ COALESCE(TRY_CAST(JSON_VALUE(item.value, '$.quantity') AS DECIMAL(18,4)), 1)
							AS DECIMAL(18,4)) 
						AS VARCHAR(20)) AS f432_vlr_uni

					FROM OPENJSON(orden_obj_origen, '$.items') AS item

					CROSS APPLY (
						SELECT JSON_VALUE(item.value, '$.priceTags[0].rawValue') AS rawValueStr
					) d

					INNER JOIN #ItemsNumReg i
						ON i.id_orden = id_orden
						AND i.id_tienda = id_tienda
						AND JSON_VALUE(item.value, '$.id') = i.Id
						AND JSON_VALUE(item.value, '$.uniqueId') = i.UniqueId

					WHERE d.rawValueStr IS NOT NULL
					AND TRY_CAST(d.rawValueStr AS DECIMAL(18,4)) IS NOT NULL

					AND EXISTS (
						SELECT 1 
						FROM OPENJSON(JSON_QUERY(orden_obj_origen, '$.totals'))
						WITH (
							id NVARCHAR(50),
							value INT
						) AS totales
						WHERE id = 'Discounts' AND value <> 0
					)

				) AS descuentos
				FOR JSON PATH, INCLUDE_NULL_VALUES
			)) AS Descuentos

        for json path, without_array_wrapper
    )) as orden_obj_destino 
from #ordenes

--select * from #TempOrdenes
-- Realizar el UPDATE utilizando la tabla temporal
UPDATE o
SET 
    o.endpoint = t.endpoint,
    o.intentos = 0,
    o.fecha_creacion = t.fecha_creacion,
    o.orden_obj_destino = t.orden_obj_destino
FROM ordenes o
JOIN #TempOrdenes t ON o.id_tienda = t.id_tienda AND o.id_orden = t.id_orden;

END