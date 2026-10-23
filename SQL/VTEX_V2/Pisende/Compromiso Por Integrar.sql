DECLARE @endpoint NVARCHAR(500) = 'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?idCompania=6618&idSistema=2&idDocumento=217328&nombreDocumento=Ecommerce_Compromiso';

-- Filtrar ordenes vÃ¡lidas
IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL DROP TABLE #ordenes;

SELECT * INTO #ordenes
FROM ordenes
WHERE id_tienda = 1 
--and id_orden in ('1567570500364-01')
AND id_estado = 6
AND intentos < 3

IF EXISTS (SELECT 1 FROM #ordenes)
BEGIN
    -----------------------------------------
    -- TEMPORALES UNOEE
    -----------------------------------------

    -- 1. Existencias por bodega y lote
    IF OBJECT_ID('tempdb..#TempBodegasERP') IS NOT NULL DROP TABLE #TempBodegasERP;

    CREATE TABLE #TempBodegasERP (
        id_item NVARCHAR(50),
        bodega_erp NVARCHAR(10),
		ubicacion NVARCHAR(10),
		lote NVARCHAR(15),
        cantidad_disponible INT,
		unidad_orden NVARCHAR(10)
    );

    INSERT INTO #TempBodegasERP
    SELECT 
		f120_id,
		f150_id,
		f401_id_ubicacion_aux,
		f403_id,
		Disponible,
		f120_id_unidad_orden
    FROM OPENROWSET(
        'SQLNCLI',
        'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=Pisende;Pwd=Pisende$12$%',
        '
        WITH ranked_lotes AS (
			SELECT 
				t120.f120_id_cia,
				f120_id,
				f120_referencia,
				f150_id,
				f401_id_ubicacion_aux,
				ISNULL(t403.f403_id,'''') AS f403_id,
				t120.f120_id_unidad_inventario,
				t120.f120_id_unidad_orden,
				((t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1) - t401.f401_cant_salida_sin_conf_1) / f122_factor AS Disponible,
				ROW_NUMBER() OVER (
					PARTITION BY f150_id, f120_id 
					ORDER BY ((t401.f401_cant_existencia_1 - t401.f401_cant_comprometida_1) - t401.f401_cant_salida_sin_conf_1) DESC
				) as rn
			FROM t401_cm_existencia_lote t401
			INNER JOIN t150_mc_bodegas t150 
				ON t150.f150_rowid = t401.f401_rowid_bodega
				AND f150_id IN (''BD001'',''BDVIR'',''BDAPG'',''OUT01'')
			LEFT JOIN t403_cm_lotes t403 
				ON t403.f403_id = t401.f401_id_lote 
				AND t403.f403_id_cia = t401.f401_id_cia
				AND t403.f403_ind_estado = 1
			INNER JOIN t121_mc_items_extensiones t121 
				ON t121.f121_rowid = t401.f401_rowid_item_ext
			INNER JOIN t120_mc_items t120 
				ON t120.f120_rowid = t121.f121_rowid_item
			INNER JOIN t122_mc_items_unidades  
				ON f120_rowid = f122_rowid_item 
				AND f120_id_unidad_orden = f122_id_unidad
		)
		SELECT
			f120_id_cia,
			f120_id,
			f120_referencia,
			f150_id,
			f401_id_ubicacion_aux,
			f403_id,
			f120_id_unidad_inventario,
			f120_id_unidad_orden,
			Disponible
		FROM ranked_lotes
		WHERE rn = 1
		ORDER BY f150_id, Disponible DESC
        '
    );

    -- 2. RowID por Ã­tem (usando EAN - f120_id)
    IF OBJECT_ID('tempdb..#TempRegistroERP') IS NOT NULL DROP TABLE #TempRegistroERP;

    SELECT 
		f430_consec_docto,
        f120_id,
        f431_rowid,
		f430_num_docto_referencia
	INTO #TempRegistroERP
    FROM OPENROWSET(
        'SQLNCLI',
        'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=Pisende;Pwd=Pisende$12$%',
        '
        SELECT 
			f430_consec_docto,
			f120_id,
			f431_rowid,
			f430_num_docto_referencia
		FROM T431_cm_pv_movto
			INNER JOIN t121_mc_items_extensiones ON f121_rowid = f431_rowid_item_ext 
													AND f121_id_cia = 1
			INNER JOIN t120_mc_items ON f120_ROWid = f121_rowid_item
			LEFT JOIN t430_cm_pv_docto ON f430_rowid = f431_rowid_pv_docto
		WHERE f431_id_cia = 1 
			AND f430_id_tipo_docto = ''PED'' 
			AND F430_ID_CO = ''010''
        '
    );

    -- 3. Doctos
    IF OBJECT_ID('tempdb..#TempDoctoERP') IS NOT NULL DROP TABLE #TempDoctoERP;

    CREATE TABLE #TempDoctoERP (
        docto NVARCHAR(50),
        referencia VARCHAR(100)
    );

	INSERT INTO #TempDoctoERP
	SELECT 
        f430_consec_docto,
        f430_num_docto_referencia
    FROM OPENROWSET(
        'SQLNCLI',
        'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=Pisende;Pwd=Pisende$12$%',
        '
        SELECT 
            f430_consec_docto,
            f430_num_docto_referencia
        FROM t430_cm_pv_docto
        WHERE f430_id_cia = 1 
			AND f430_ID_co = ''010'' 
			AND f430_id_tipo_docto = ''PED''
        '
    ) AS t
	INNER JOIN #ordenes o ON  LEN(o.id_orden) >= 3 
							AND LEN(t.f430_num_docto_referencia) >= 2
							AND LEFT(o.id_orden,len(o.id_orden)-3) = LEFT(t.f430_num_docto_referencia,len(t.f430_num_docto_referencia)-2)

	-- 4. Tabla unificada: Items con su bodega (usando EAN)
	IF OBJECT_ID('tempdb..#TempItemsWarehouse') IS NOT NULL DROP TABLE #TempItemsWarehouse;

	CREATE TABLE #TempItemsWarehouse (
		id_tienda INT,
		id_orden NVARCHAR(50),
		item_id NVARCHAR(50),
		ean NVARCHAR(50),
		warehouse_id NVARCHAR(10),
		quantity INT,
		lock_id NVARCHAR(100)
	);

	-- Items sin componentes
	INSERT INTO #TempItemsWarehouse
	SELECT 
		o.id_tienda,
		o.id_orden,
		JSON_VALUE(i.value, '$.id') AS item_id,
		JSON_VALUE(i.value, '$.ean') AS ean,
		(
			SELECT TOP 1 JSON_VALUE(d.value, '$.warehouseId')
			FROM OPENJSON(JSON_QUERY(o.orden_obj_origen, '$.shippingData.logisticsInfo')) li
			CROSS APPLY OPENJSON(JSON_QUERY(li.value, '$.slas')) sla
			CROSS APPLY OPENJSON(JSON_QUERY(sla.value, '$.deliveryIds')) d
			WHERE JSON_VALUE(li.value, '$.itemId') = JSON_VALUE(i.value, '$.id')
				AND JSON_VALUE(sla.value, '$.id') = JSON_VALUE(li.value, '$.selectedSla')
				AND JSON_VALUE(d.value, '$.warehouseId') IS NOT NULL
		) AS warehouse_id,
		CAST(JSON_VALUE(i.value, '$.quantity') AS INT) AS quantity,
		JSON_VALUE(i.value, '$.lockId') AS lock_id
	FROM #ordenes o
	CROSS APPLY OPENJSON(o.orden_obj_origen, '$.items') i
	WHERE ISNULL(JSON_QUERY(i.value, '$.components'), '[]') = '[]';

	-- Componentes (extrae bodega especÃ­fica de kitItemDetails)
	INSERT INTO #TempItemsWarehouse
	SELECT 
		o.id_tienda,
		o.id_orden,
		JSON_VALUE(comp.value, '$.id') AS item_id,
		JSON_VALUE(comp.value, '$.ean') AS ean,
		JSON_VALUE(k.value, '$.WarehouseId') AS warehouse_id,
		CAST(JSON_VALUE(comp.value, '$.quantity') AS INT) AS quantity,
		JSON_VALUE(i.value, '$.lockId') AS lock_id
	FROM #ordenes o
	CROSS APPLY OPENJSON(o.orden_obj_origen, '$.items') i
	CROSS APPLY OPENJSON(i.value, '$.components') comp
	CROSS APPLY OPENJSON(JSON_QUERY(o.orden_obj_origen, '$.shippingData.logisticsInfo')) li
	CROSS APPLY OPENJSON(JSON_QUERY(li.value, '$.slas')) sla
	CROSS APPLY OPENJSON(JSON_QUERY(sla.value, '$.deliveryIds')) d
	CROSS APPLY OPENJSON(JSON_QUERY(d.value, '$.kitItemDetails')) k
	WHERE ISNULL(JSON_QUERY(i.value, '$.components'), '[]') != '[]'
		AND JSON_VALUE(li.value, '$.itemId') = JSON_VALUE(i.value, '$.id')
		AND JSON_VALUE(sla.value, '$.id') = JSON_VALUE(li.value, '$.selectedSla')
		AND JSON_VALUE(k.value, '$.ItemId') = JSON_VALUE(comp.value, '$.id');

	-- Consolidar cantidades pero mantener registros separados por item_id/ean
	IF OBJECT_ID('tempdb..#TempItemsWarehouseFinal') IS NOT NULL DROP TABLE #TempItemsWarehouseFinal;

	SELECT 
		id_tienda,
		id_orden,
		item_id,
		ean,
		warehouse_id,
		quantity,
		lock_id,
		ROW_NUMBER() OVER (PARTITION BY id_orden, ean ORDER BY item_id) as item_occurrence
	INTO #TempItemsWarehouseFinal
	FROM #TempItemsWarehouse

    -----------------------------------------
    -- ARMAR OBJETO JSON FINAL (AGRUPADO POR f431_nro_registro)
    -----------------------------------------
    IF OBJECT_ID('tempdb..#TempOrdenes') IS NOT NULL DROP TABLE #TempOrdenes;
    CREATE TABLE #TempOrdenes (
        id_tienda INT,
        id_orden NVARCHAR(50),
        endpoint NVARCHAR(500),
        fecha_creacion DATETIME,
        orden_obj_destino NVARCHAR(MAX)
    );

    INSERT INTO #TempOrdenes (id_tienda, id_orden, endpoint, fecha_creacion, orden_obj_destino)
	SELECT 
		o.id_tienda,
		o.id_orden,
		@endpoint AS endpoint,
		GETDATE() AS fecha_creacion,
		(
			SELECT 
				f430_id_co,
				f430_id_tipo_docto,
				f430_consec_docto,
				f431_id_item,
				f431_referencia_item,
				f431_id_bodega,
				f431_id_ubicacion_aux,
				f431_id_lote,
				f431_id_unidad_medida,
				f431_cant_base,
				f431_nro_registro,
				f405_cant_por_remisionar_base
			FROM (
				-- Items agrupados por f431_nro_registro (cada registro ERP por separado)
				SELECT 
					'010' AS f430_id_co,
					'PED' AS f430_id_tipo_docto,
					d.docto AS f430_consec_docto,
					RTRIM(b.id_item) AS f431_id_item,
					'' AS f431_referencia_item,
					ISNULL(COALESCE(iw.warehouse_id, b.bodega_erp), 'BD001') AS f431_id_bodega,
					TRIM(b.ubicacion) AS f431_id_ubicacion_aux,
					TRIM(b.lote) AS f431_id_lote,
					TRIM(b.unidad_orden) AS f431_id_unidad_medida,
					iw.quantity AS f431_cant_base,
					reg.f431_rowid AS f431_nro_registro,
					iw.quantity AS f405_cant_por_remisionar_base
				FROM #TempItemsWarehouseFinal iw
				LEFT JOIN #TempBodegasERP b ON b.id_item = iw.ean AND b.bodega_erp = iw.warehouse_id
				LEFT JOIN #TempRegistroERP reg ON reg.f120_id = iw.ean
												AND reg.f430_num_docto_referencia = SUBSTRING(iw.lock_id, CHARINDEX('-', iw.lock_id) + 1, CHARINDEX('-', iw.lock_id, CHARINDEX('-', iw.lock_id) + 1) - 4) + '01'
				INNER JOIN #TempDoctoERP d ON d.referencia = SUBSTRING(iw.lock_id, CHARINDEX('-', iw.lock_id) + 1, CHARINDEX('-', iw.lock_id, CHARINDEX('-', iw.lock_id) + 1) - 4) + '01'
				WHERE iw.id_orden = o.id_orden AND iw.id_tienda = o.id_tienda

				UNION

				-- Flete (Ãºnico por orden)
				SELECT TOP 1
					'010' AS f430_id_co,
					'PED' AS f430_id_tipo_docto,
					d.docto AS f430_consec_docto,
					'2400888' AS f431_id_item,
					'' AS f431_referencia_item,
					'BD001' AS f431_id_bodega,
					'' AS f431_id_ubicacion_aux,
					'' AS f431_id_lote,
					'UND' AS f431_id_unidad_medida,
					1 AS f431_cant_base,
					reg.f431_rowid AS f431_nro_registro,
					1 AS f405_cant_por_remisionar_base
				FROM #TempItemsWarehouseFinal iw
				LEFT JOIN #TempRegistroERP reg ON reg.f430_num_docto_referencia = SUBSTRING(iw.lock_id, CHARINDEX('-', iw.lock_id) + 1, CHARINDEX('-', iw.lock_id, CHARINDEX('-', iw.lock_id) + 1) - 4) + '02'
				INNER JOIN #TempDoctoERP d ON d.referencia = SUBSTRING(iw.lock_id, CHARINDEX('-', iw.lock_id) + 1, CHARINDEX('-', iw.lock_id, CHARINDEX('-', iw.lock_id) + 1) - 4) + '02'
				WHERE iw.id_orden = o.id_orden AND iw.id_tienda = o.id_tienda
			) AS Compromisos
			ORDER BY f431_nro_registro
			FOR JSON PATH, ROOT('Compromisos'), INCLUDE_NULL_VALUES
		) AS orden_obj_destino
	FROM #ordenes o;

	--Update en la tabla ordenes
    UPDATE o
    SET
        o.endpoint = t.endpoint,
        o.intentos = 0,
        o.fecha_creacion = t.fecha_creacion,
        o.orden_obj_destino = t.orden_obj_destino
    FROM ordenes o
    JOIN #TempOrdenes t ON o.id_tienda = t.id_tienda AND o.id_orden = t.id_orden;

	--SELECT * FROM #TempOrdenes

END