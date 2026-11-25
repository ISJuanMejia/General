-- ============================================================================
-- SECCIÓN 1: DECLARACIÓN DE VARIABLES
-- ============================================================================
-- Define el endpoint de la API donde se enviarán los datos procesados
DECLARE @endpoint nvarchar(500) = 'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?idCompania=9082&idSistema=2&idDocumento=225741&nombreDocumento=Pedidos_Dluchi';

-- ============================================================================
-- SECCIÓN 2: VALIDACIÓN Y ACTUALIZACIÓN DE ÓRDENES DUPLICADAS
-- ============================================================================
-- Valida si el sequence existe en otro pedido y marca la orden como cancelada (estado 4)
UPDATE O SET O.id_estado = 4, O.orden_obj_destino=NULL, O.endpoint=NULL, O.intentos=0
FROM ORDENES O
INNER JOIN OPENROWSET(
        'SQLNCLI11', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Comercbd_Real;Uid=Comercbd;Pwd=Comercbd$12$%;',
        '	SELECT 
			f430_id_tipo_docto,
			f430_consec_docto,
			f430_num_docto_referencia
			FROM t430_cm_pv_docto
			WHERE f430_id_cia = 1 
			AND f430_id_tipo_docto IN (''CPW'',''CPM'',''CPT'')
			AND F430_ID_CO = ''001''
		') B ON B.f430_num_docto_referencia = JSON_VALUE(O.orden_obj_origen,'$.sequence')
WHERE id_tienda = 1 
AND id_estado = 3

-- ============================================================================
-- SECCIÓN 3: PREPARACIÓN DE TABLA TEMPORAL CON ÓRDENES A PROCESAR
-- ============================================================================
-- Elimina la tabla temporal si existe
IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL
    DROP TABLE #ordenes;

SELECT *
INTO #ordenes
FROM ordenes
WHERE id_tienda = 1 
AND id_estado = 3
AND ISNULL(intentos, 0) < 3

-- ============================================================================
-- SECCIÓN 4: PROCESAMIENTO PRINCIPAL (SI EXISTEN ÓRDENES)
-- ============================================================================
-- Verificar si la tabla temporal tiene datos
IF EXISTS (SELECT 1 FROM #ordenes)
BEGIN

	-- ============================================================================
	-- SECCIÓN 4.1: EXTRACCIÓN Y TRANSFORMACIÓN DE DATOS DE ÓRDENES
	-- ============================================================================
	-- Elimina tabla temporal si existe
	IF OBJECT_ID('tempdb..#DatosExtraidos') IS NOT NULL
		DROP TABLE #DatosExtraidos;

	SELECT 
		o.id_tienda,
		o.id_orden,
		JSON_VALUE(o.orden_obj_origen, '$.sequence') AS NumeroSequence,
		ROW_NUMBER() OVER (PARTITION BY JSON_VALUE(o.orden_obj_origen, '$.orderId') ORDER BY JSON_VALUE(item.value, '$.id')) AS RegistroPorOrden,
		COALESCE(
			JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'),
			JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
		) AS DocumentoTercero,
		JSON_VALUE(item.value, '$.id') AS ItemId,
		JSON_VALUE(item.value, '$.name') AS NombreItem,
		JSON_VALUE(item.value, '$.quantity') AS Cantidad,
		ISNULL(JSON_VALUE(item.value, '$.ean'), JSON_VALUE(item.value, '$.refId')) AS EAN,
		CASE
			WHEN LEN(JSON_VALUE(item.value, '$.price')) > 2
			THEN CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) / 100
		ELSE CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) END AS Price,
		CASE
			WHEN LEN(JSON_VALUE(item.value, '$.sellingPrice')) > 2
			THEN CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT) /100
		ELSE CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT) END AS sellingPrice,
		(
			(
		CASE
			WHEN LEN(JSON_VALUE(item.value, '$.price')) > 2
			THEN CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) /100
		ELSE CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) END   -
		CASE
			WHEN LEN(JSON_VALUE(item.value, '$.sellingPrice')) > 2
			THEN CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT) /100
		ELSE CAST(JSON_VALUE(item.value, '$.sellingPrice') AS FLOAT) END
			) * 100 
		) / CASE
				WHEN LEN(JSON_VALUE(item.value, '$.price')) > 2
				THEN CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) /100
			ELSE CAST(JSON_VALUE(item.value, '$.price') AS FLOAT) END AS ValorDescuento,
		JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') AS MetodoPago,
		f120_id_unidad_inventario AS UnidadMedida,
		CASE
			WHEN LEN(JSON_VALUE(orden_obj_origen,'$.totals[2].value')) > 2
			THEN CAST(JSON_VALUE(orden_obj_origen,'$.totals[2].value') AS FLOAT) /100
		ELSE CAST(JSON_VALUE(orden_obj_origen,'$.totals[2].value') AS FLOAT) END AS Envio,
		TRIM(JSON_VALUE(orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryIds[0].warehouseId')) AS Bodega
	INTO #DatosExtraidos
	FROM #ordenes o
		CROSS APPLY OPENJSON(o.orden_obj_origen, '$.items') AS item
	LEFT JOIN 
    OPENROWSET(
        'SQLNCLI11', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Comercbd_Real;Uid=Comercbd;Pwd=Comercbd$12$%;',
        'SELECT f120_id,
                f120_referencia,
                f121_id_barras_principal,
                f120_id_unidad_inventario
         FROM t120_mc_items
         INNER JOIN t121_mc_items_extensiones 
             ON f120_rowid = f121_rowid_item'
    ) AS u
    ON JSON_VALUE(item.value, '$.ean') = u.f121_id_barras_principal 

	UPDATE #DatosExtraidos SET Bodega = CASE 
											WHEN Bodega = '1_1' THEN 'LCD01'
											WHEN Bodega = 'Melonn' THEN 'LEC02'
											WHEN Bodega = '1953bc6' THEN 'LEC03'
											WHEN Bodega = 'Melonnbog' THEN 'LEC04'
											WHEN Bodega = 'Melonncali' THEN 'LEC05'
											WHEN Bodega = 'LCM01' THEN 'LCM00'
											WHEN Bodega = 'ENVIGADO' THEN 'LCM02'
											WHEN Bodega = 'GPLAZA' THEN 'LCM03'
											WHEN Bodega = 'SANMEDELLIN' THEN 'LCM04'
											WHEN Bodega = 'FABRICATO' THEN 'LCM05'
											WHEN Bodega = 'SANBOGOTA' THEN 'LCM06'
											WHEN Bodega = 'ANDINO' THEN 'LCM07'
											WHEN Bodega = 'CMAYOR' THEN 'LCM08'
											WHEN Bodega = 'MULTIPLAZA' THEN 'LCM09'
											WHEN Bodega = 'BARRANQUILLA' THEN 'LCM10'
											WHEN Bodega = 'CHIPICHAPE' THEN 'LCM11'
											WHEN Bodega = 'LACENTRAL' THEN 'LCM13'
											WHEN Bodega = 'LCM20' THEN 'LCM20'
											WHEN Bodega = 'LCM30' THEN 'LCM30'
											WHEN Bodega = 'LCM40' THEN 'LCM40'
										END

	-- ============================================================================
	-- SECCIÓN 4.2: CONSTRUCCIÓN DE JSON DE DESTINO
	-- ============================================================================
	-- Elimina tabla temporal si existe
	IF OBJECT_ID('tempdb..#TempOrdenes') IS NOT NULL
		DROP TABLE #TempOrdenes;

	CREATE TABLE #TempOrdenes (
		id_tienda INT,
		id_orden NVARCHAR(50),
		endpoint NVARCHAR(500),
		fecha_creacion DATETIME,
		orden_obj_destino NVARCHAR(MAX)
	);

	INSERT INTO #TempOrdenes (id_tienda, id_orden, endpoint, fecha_creacion, orden_obj_destino)
	SELECT 
		de.id_tienda,
		de.id_orden,
		@endpoint AS endpoint,
		GETDATE() AS fecha_creacion,
		JSON_QUERY(( 
			SELECT 

				-- Nodo Pedidos
				JSON_QUERY(( 
					SELECT 
						CASE
							WHEN MAX(de2.Bodega) = 'LCD01' THEN 'CPW'
							WHEN MAX(de2.Bodega) IN ('LEC02', 'LEC03', 'LEC04', 'LEC05') THEN 'CPM'
							WHEN MAX(de2.Bodega) IN ('LCM00','LCM02','LCM03','LCM04','LCM05','LCM06',
													 'LCM07','LCM08','LCM09','LCM10','LCM11','LCM13',
													 'LCM20','LCM30','LCM40') THEN 'CPT'
							ELSE 'CPW'
						END
						 AS f430_id_tipo_docto,
						CONVERT(VARCHAR(8), GETDATE(), 112) AS f430_id_fecha,
						MAX(de2.DocumentoTercero) AS f430_id_tercero_fact,
						MAX(de2.DocumentoTercero) AS f430_id_tercero_rem,
						CONVERT(VARCHAR(8), DATEADD(DAY,3,GETDATE()), 112) AS f430_fecha_entrega,
						'3' AS f430_num_dias_entrega,
						REPLACE(MAX(de2.NumeroSequence), '-', '') AS f430_num_docto_referencia,
						CONCAT('Orden: ', MAX(de2.id_orden), ' | ','Sequence: ', MAX(de2.NumeroSequence), ' | ', 'MetodoPago: ', MAX(de2.MetodoPago), ' | ', 'Ecommerce') AS f430_notas
					FROM #DatosExtraidos de2
					WHERE de2.id_tienda = de.id_tienda and de2.id_orden = de.id_orden
					FOR JSON PATH, INCLUDE_NULL_VALUES
				)) AS Pedidos,

				-- Movimiento de items vendidos
				JSON_QUERY(( 
					SELECT *
					FROM (
						SELECT
							CASE
								WHEN MAX(de3.Bodega) = 'LCD01' THEN 'CPW'
								WHEN MAX(de3.Bodega) IN ('LEC02', 'LEC03', 'LEC04', 'LEC05') THEN 'CPM'
								WHEN MAX(de3.Bodega) IN ('LCM00','LCM02','LCM03','LCM04','LCM05','LCM06',
														 'LCM07','LCM08','LCM09','LCM10','LCM11','LCM13',
														 'LCM20','LCM30','LCM40') THEN 'CPT'
								ELSE 'CPW'
							END AS f431_id_tipo_docto,
							de3.RegistroPorOrden AS f431_nro_registro,
							'' AS f431_referencia_item,
							de3.EAN AS f431_codigo_barras,
							de3.Bodega AS f431_id_bodega,
							CASE WHEN de3.Price = 0 THEN '66' ELSE '06' END AS f431_id_motivo,
							CASE WHEN de3.Price = 0 THEN 1 ELSE 0 END AS f431_ind_obsequio,
							CASE WHEN de3.Price = 0 THEN '200600' ELSE '' END AS f431_id_ccosto_movto,
							CONVERT(varchar(8), DATEADD(DAY,3,GETDATE()), 112) AS f431_fecha_entrega,
							'3' AS f431_num_dias_entrega,
							ISNULL(de3.UnidadMedida,'UND') AS f431_id_unidad_medida,
							de3.Cantidad AS f431_cant_pedida_base,
							de3.Price AS f431_precio_unitario,
							CASE WHEN de3.Price = 0 THEN 1 ELSE 0 END AS f431_ind_impto_asumido
						FROM #DatosExtraidos de3
						WHERE de3.id_tienda = de.id_tienda 
							AND de3.id_orden = de.id_orden
						group by de3.RegistroPorOrden,de3.EAN,de3.Bodega,de3.Price,de3.UnidadMedida,de3.Cantidad

						UNION ALL

						-- Movimientos de gastos de envío (como artículo de servicio)
						SELECT
							CASE
								WHEN de3_max.Bodega = 'LCD01' THEN 'CPW'
								WHEN de3_max.Bodega IN ('LEC02','LEC03','LEC04','LEC05') THEN 'CPM'
								WHEN de3_max.Bodega IN ('LCM00','LCM02','LCM03','LCM04','LCM05','LCM06',
														 'LCM07','LCM08','LCM09','LCM10','LCM11','LCM13',
														 'LCM20','LCM30','LCM40') THEN 'CPT'
								ELSE 'CPW'
							END AS f431_id_tipo_docto,
							de3_max.MaxRegistro + 1 AS f431_nro_registro,
							'SERV01' AS f431_referencia_item,
							'' AS f431_codigo_barras,
							'LCD01' AS f431_id_bodega,
							'06' AS f431_id_motivo,
							0 AS f431_ind_obsequio,
							'' AS f431_id_ccosto_movto,
							CONVERT(VARCHAR(8), DATEADD(DAY,3,GETDATE()), 112) AS f431_fecha_entrega,
							'3' AS f431_num_dias_entrega,
							'UND' AS f431_id_unidad_medida,
							1 AS f431_cant_pedida_base,
							de3_max.Envio AS f431_precio_unitario,
							0 AS f431_ind_impto_asumido
						FROM (
							SELECT 
								deE.id_tienda,
								deE.id_orden,
								MAX(deE.RegistroPorOrden) AS MaxRegistro,
								MAX(deE.Envio) AS Envio,
								MAX(deE.Bodega) AS Bodega
							FROM #DatosExtraidos deE
							WHERE deE.id_tienda = de.id_tienda
							  AND deE.id_orden = de.id_orden
							GROUP BY deE.id_tienda, deE.id_orden
							HAVING MAX(deE.Envio) > 0
						) de3_max
					) AS movimientos
					FOR JSON PATH, INCLUDE_NULL_VALUES
				)) as Movimientos,

				-- Nodo Descuentos
				JSON_QUERY((
					SELECT *
					FROM (
						SELECT
							CASE
								WHEN de4.Bodega = 'LCD01' THEN 'CPW'
								WHEN de4.Bodega IN ('LEC02','LEC03','LEC04','LEC05') THEN 'CPM'
								WHEN de4.Bodega IN ('LCM00','LCM02','LCM03','LCM04','LCM05','LCM06',
													'LCM07','LCM08','LCM09','LCM10','LCM11','LCM13',
													'LCM20','LCM30','LCM40') THEN 'CPT'
								ELSE 'CPW'
							END AS f430_id_tipo_docto,
							de4.RegistroPorOrden AS f431_nro_registro,
							ROUND(de4.ValorDescuento,2) AS f432_tasa
						FROM #DatosExtraidos de4
						WHERE de4.id_tienda = de.id_tienda
						  AND de4.id_orden = de.id_orden
						  AND de4.ValorDescuento > 0
					) AS descuentos
					FOR JSON PATH, INCLUDE_NULL_VALUES
				)) AS Descuentos

			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		)) AS orden_obj_destino 
	FROM (SELECT DISTINCT id_tienda, id_orden FROM #DatosExtraidos) de

	-- ============================================================================
	-- SECCIÓN 4.3: ACTUALIZACIÓN DE ÓRDENES CON DATOS TRANSFORMADOS
	-- ============================================================================
	-- Actualiza la tabla ORDENES con el JSON generado, endpoint y reinicia intentos
	UPDATE o
	SET 
		o.endpoint = t.endpoint,
		o.intentos = 0,
		o.fecha_creacion = t.fecha_creacion,
		o.orden_obj_destino = t.orden_obj_destino
	FROM ordenes o
	JOIN #TempOrdenes t ON o.id_tienda = t.id_tienda AND o.id_orden = t.id_orden

	--SELECT * FROM #TempOrdenes

	-- ============================================================================
	-- SECCIÓN 4.4: LIMPIEZA DE TABLAS TEMPORALES
	-- ============================================================================
	-- Elimina tabla temporal de datos extraídos para liberar espacio
	DROP TABLE #DatosExtraidos;

END