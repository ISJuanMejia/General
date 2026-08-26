DECLARE @endpoint NVARCHAR(500) = 'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?idCompania=7243&idSistema=2&idDocumento=214367&nombreDocumento=PEDIDOS_VENTA_ECOMERCE_INT';

IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL
    DROP TABLE #ordenes;
	
select *
into #ordenes
from ordenes
where id_tienda = 1 
AND id_estado = 3
AND ISNULL(endpoint, '') != @endpoint


-- Verificar si la tabla temporal tiene datos
IF EXISTS (SELECT 1 FROM #ordenes)
BEGIN
   
IF OBJECT_ID('tempdb..#TempBodegasERP') IS NOT NULL
    DROP TABLE #TempBodegasERP;

CREATE TABLE #TempBodegasERP (
    ean NVARCHAR(50),
	referencia NVARCHAR(50),
    warehouse_ecommerce NVARCHAR(10),
    bodega_erp NVARCHAR(10),
    cantidad_disponible INT
);

INSERT INTO #TempBodegasERP (ean, referencia, warehouse_ecommerce, bodega_erp, cantidad_disponible)
SELECT * FROM 
OPENROWSET(
    'SQLNCLI', 
    'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
	'SELECT 
		v121_id_barras_principal AS ean,
		v121_referencia AS referencia,
		f151_id  AS warehouse_ecommerce,
		f150_id AS bodega_erp,
		CONVERT(INT, f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1)) AS cantidad_disponible
	FROM v121
		INNER JOIN t400_cm_existencia			ON f400_rowid_item_ext = v121_rowid_item_ext	AND f400_id_cia = 2
		INNER JOIN t150_mc_bodegas				ON f150_rowid = f400_rowid_bodega				AND f150_id_cia = 2
		INNER JOIN t152_mc_bodega_grupo_bodega	ON f152_rowid_bodega = f150_rowid				and f152_id_cia = 2
		INNER JOIN t151_mc_grupo_bodega			ON f151_id = f152_id_grupo_bodega				and f151_id_cia = 2
	WHERE
			CONVERT(INT, f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1)) > 0
			and
			f150_id IN (''10201'',''10301'',''10401'',''10501'',''10601'',''10701'',''10801'',''10901'',''11001'',''11101'',''11201'',''11301'',''11501'')'
);

IF OBJECT_ID('tempdb..#TempReferenciERP') IS NOT NULL
    DROP TABLE #TempReferenciERP;

CREATE TABLE #TempReferenciERP (
    ean NVARCHAR(50),
	referencia NVARCHAR(50),
	referencia_ext NVARCHAR(50),
	barras NVARCHAR(50)
);

INSERT INTO #TempReferenciERP (ean, referencia, referencia_ext, barras)
SELECT * FROM 
OPENROWSET(
    'SQLNCLI', 
    'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
	'select	
		rtrim(f120_referencia) + rtrim(f121_id_ext1_detalle) AS ean,
		rtrim(f120_referencia) AS referencia,
		f121_id_ext1_detalle AS referencia_ext,
		f121_id_barras_principal AS barras
	from t120_mc_items 
	inner join t121_mc_items_extensiones on f120_rowid = f121_rowid_item	
	where f120_id_cia = 2'
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
			-- Nodo Pedidos
            json_query(( 
                SELECT 
                    '1' AS f430_consec_docto,
                    CONVERT(VARCHAR(8),GETDATE(),112) AS f430_id_fecha,
                    JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') AS f430_id_tercero_fact,
					'001' AS f430_id_sucursal_fact,
					json_value(orden_obj_origen, '$.clientProfileData.document') AS f430_id_tercero_rem,
					'001' AS f430_id_sucursal_rem,
					CONVERT(VARCHAR(8),GETDATE(),112) AS f430_fecha_entrega,
					'3' AS f430_num_dias_entrega,
                    CASE 
						WHEN LEN(REPLACE(JSON_VALUE(orden_obj_origen, '$.orderId'), '-', '')) <= 15 
							THEN REPLACE(JSON_VALUE(orden_obj_origen, '$.orderId'), '-', '') 
						ELSE JSON_VALUE(orden_obj_origen, '$.sequence') 
					END AS f430_num_docto_referencia,
                    concat(
						'OrderId: ',
						json_value(orden_obj_origen, '$.orderId'), 
						' Secuencia: ',
						json_value(orden_obj_origen, '$.sequence'),
						' Metodo Pago: ',
						json_value(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName'),
						' Tienda:  null'
						) AS f430_notas,
					'1128280182' AS f430_id_tercero_vendedor                
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) as Pedidos,
			
		json_query((
			SELECT *
			FROM (
				-- Ítems
				SELECT
					'1' AS f431_consec_docto,
					cast(i.f431_nro_registro as varchar(20)) AS f431_nro_registro,
					(SELECT TOP 1 ltrim(rtrim(referencia))
						FROM #TempReferenciERP AS b
						WHERE b.barras = JSON_VALUE(item.value, '$.refId')) AS f431_referencia_item,
					(SELECT TOP 1 ltrim(rtrim(referencia_ext))
						FROM #TempReferenciERP AS b
						WHERE b.barras = JSON_VALUE(item.value, '$.refId')) AS f431_id_ext1_detalle,
					'' AS f431_codigo_barras,
					ISNULL((
						SELECT TOP 1 bodega_erp
						FROM #TempBodegasERP AS b
						WHERE b.ean = JSON_VALUE(item.value, '$.refId') 
							AND b.cantidad_disponible >= TRY_CONVERT(INT, JSON_VALUE(item.value, '$.quantity'))
						ORDER BY b.cantidad_disponible DESC
					), '10001') AS f431_id_bodega,
					CONVERT(VARCHAR(8), GETDATE(), 112) AS f431_fecha_entrega,
					'3' AS f431_num_dias_entrega,
					JSON_VALUE(item.value, '$.quantity') AS f431_cant_pedida_base,
					CASE 
						WHEN LEN(ISNULL(JSON_VALUE(item.value, '$.price'), '')) > 2 
							THEN LEFT(JSON_VALUE(item.value, '$.price'), LEN(JSON_VALUE(item.value, '$.price')) - 2)
						ELSE '0'
					END AS f431_precio_unitario
				FROM OPENJSON(orden_obj_origen, '$.items') AS item
				INNER JOIN #ItemsNumReg i ON i.id_orden = id_orden
					AND i.id_tienda = id_tienda
					AND JSON_VALUE(item.value, '$.id') = i.Id
					AND JSON_VALUE(item.value, '$.uniqueId') = i.UniqueId

				-- FLETEECOMMERCE - línea única por pedido
				UNION ALL

				SELECT 
					'1',
					CAST((SELECT COUNT(*) FROM OPENJSON(orden_obj_origen, '$.items')) + 1 AS VARCHAR(20)),
					'FLETEECOMERCE',
					'',
					'',
					'10001',
					CONVERT(VARCHAR(8), GETDATE(), 112),
					'3',
					'1',
					(
						SELECT TOP 1
							CASE 
								WHEN LEN(ISNULL(value, '')) > 2 
									THEN LEFT(value, LEN(value) - 2)
								ELSE '0'
							END
						FROM OPENJSON(orden_obj_origen, '$.totals')
						WITH (
							id NVARCHAR(50),
							value NVARCHAR(50)
						) AS t
						WHERE t.id = 'Shipping'
					)
					--CASE 
					--	WHEN LEN(ISNULL(JSON_VALUE(orden_obj_origen, '$.totals[2].value'), '')) > 2 
					--		THEN LEFT(JSON_VALUE(orden_obj_origen, '$.totals[2].value'), LEN(JSON_VALUE(orden_obj_origen, '$.totals[2].value')) - 2)
					--	ELSE '0'
					--END
				--WHERE JSON_VALUE(orden_obj_origen, '$.totals[2].id') = 'Shipping'
				--  AND ISNULL(JSON_VALUE(orden_obj_origen, '$.totals[2].value'), '0') <> '0'
				WHERE EXISTS (
					SELECT 1
					FROM OPENJSON(orden_obj_origen, '$.totals')
					WITH (
						id NVARCHAR(50),
						value NVARCHAR(50)
					) AS t
					WHERE t.id = 'Shipping'
					  AND ISNULL(t.value, '0') <> '0'
				)

			) AS movto_pedidos_comercial
			FOR JSON PATH, INCLUDE_NULL_VALUES
		)) AS Movto_Pedidos_comercial,

			-- Nodo Descuentos
			json_query((
			    select *
			    from (
			        -- Descuentos por Items con priceTags
			        select
			            '1' as f430_consec_docto,
						cast(i.f431_nro_registro as varchar(20)) as f431_nro_registro,
			            '0' as f432_tasa,
						cast(abs(cast(left(json_value(value, '$.priceTags[0].rawValue'), len(json_value(value, '$.priceTags[0].rawValue')) - 2) as int))as varchar(20)) as f432_vlr_uni
			        from openjson(orden_obj_origen, '$.items') AS item
					INNER JOIN #ItemsNumReg i
						 ON i.id_orden = id_orden
						 AND i.id_tienda = id_tienda
						 AND JSON_VALUE(item.value, '$.id') = i.Id
						 AND JSON_VALUE(item.value, '$.uniqueId') = i.UniqueId
			        where json_value(value, '$.priceTags[0].rawValue') is not null
					AND EXISTS (
									SELECT 1 FROM OPENJSON(JSON_QUERY(orden_obj_origen, '$.totals'))
									WITH (
										id NVARCHAR(50),
											value INT
										) AS totales
									WHERE id = 'Discounts' AND value <> 0
								)
			    ) as descuentos
			    for json path, include_null_values
			)) as Descuentos
		for json path, without_array_wrapper
	)) as orden_obj_destino 
from #ordenes;

--Select * from #TempOrdenes
--Realizar el UPDATE utilizando la tabla temporal
UPDATE o
SET 
    o.endpoint = t.endpoint,
    o.intentos = 0,
    o.fecha_creacion = t.fecha_creacion,
    o.orden_obj_destino = t.orden_obj_destino
FROM ordenes o
JOIN #TempOrdenes t ON o.id_tienda = t.id_tienda AND o.id_orden = t.id_orden;
  
END