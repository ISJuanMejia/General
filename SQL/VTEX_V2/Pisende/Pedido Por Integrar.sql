DECLARE @endpoint NVARCHAR(500) = 'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?idCompania=6618&idSistema=2&idDocumento=217657&nombreDocumento=Ecommerce_Pedido';

IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL
    DROP TABLE #ordenes;
IF OBJECT_ID('tempdb..#PedidosERP') IS NOT NULL
    DROP TABLE #PedidosERP;

CREATE TABLE #PedidosERP(
	f430_num_docto_referencia NVARCHAR(50)
)

INSERT INTO #PedidosERP
SELECT
	f430_num_docto_referencia
FROM OPENROWSET(
    'SQLNCLI',
    'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=Pisende;Pwd=Pisende$12$%;',
    '
    SELECT  DISTINCT
		f430_num_docto_referencia   =   TRIM(f430_num_docto_referencia)
	FROM t430_cm_pv_docto
    WHERE
        f430_id_co = ''010''
        AND 
        f430_id_tipo_docto IN (''PED'', ''TMS'')
        AND
        f430_referencia =   ''ECOMMERCE''
    '
) AS t430;

UPDATE o
SET 
    id_estado           =   5,
    intentos            =   0,
    endpoint            =   NULL,
    orden_obj_destino   =   NULL
FROM ordenes o
    INNER JOIN #PedidosERP 
        ON CASE 
            WHEN 
                LEN(REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-', '')) <= 15 
                    THEN REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-01', '01') 
            ELSE JSON_VALUE(o.orden_obj_origen, '$.sequence') 
        END =   #PedidosERP.f430_num_docto_referencia
WHERE
    id_tienda = 1 
    AND 
    id_estado = 4

SELECT o.*
INTO #ordenes
FROM    ordenes o
    LEFT JOIN #PedidosERP 
        ON 
            CASE 
                WHEN LEN(REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-', '')) <= 15 
                    THEN REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-01', '01') 
                ELSE JSON_VALUE(o.orden_obj_origen, '$.sequence') 
            END = #PedidosERP.f430_num_docto_referencia
WHERE 
    id_tienda   =   1 
    AND 
    id_estado   =   4
    AND 
    ISNULL(intentos,0) < 3
    AND
    f430_num_docto_referencia   IS NULL

IF OBJECT_ID('tempdb..#PedidosERP') IS NOT NULL
    DROP TABLE #PedidosERP;

-- tabla temporal con columna 'tiene_flete' evaluada por cada orden
IF OBJECT_ID('tempdb..#ordenes_con_flete') IS NOT NULL DROP TABLE #ordenes_con_flete;

SELECT *,
	CASE 
		WHEN JSON_VALUE(orden_obj_origen, '$.totals[2].id') = 'Shipping' 
			 AND TRY_CAST(JSON_VALUE(orden_obj_origen, '$.totals[2].value') AS DECIMAL(18, 2)) > 0 
		THEN 1
		ELSE 0
	END AS tiene_flete
INTO #ordenes_con_flete
FROM #ordenes;

-- Verificar si la tabla temporal tiene datos
IF EXISTS (SELECT 1 FROM #ordenes)
BEGIN

	-- vendedores ERP
	IF OBJECT_ID('tempdb..#VendedoresERP') IS NOT NULL 
		DROP TABLE #VendedoresERP;

    SELECT 
		 f210_id
		,f200_id 
	INTO #VendedoresERP
    FROM OPENROWSET(
        'SQLNCLI',
        'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=Pisende;Pwd=Pisende$12$%;',
        '
        SELECT 
			 f210_id
			,f200_id 
		FROM t210_mm_vendedores
		INNER JOIN t200_mm_terceros t 
			ON f210_rowid_tercero = f200_rowid 
			AND f200_id_cia = 1
        '
    );

	-- tabla con Ã³rdenes que tienen todos los EAN vÃ¡lidos
	IF OBJECT_ID('tempdb..#OrdenesEANValidos') IS NOT NULL 
		DROP TABLE #OrdenesEANValidos;

	SELECT DISTINCT 
		JSON_VALUE(orden_obj_origen, '$.orderId') as id_orden,
		id_tienda
	INTO #OrdenesEANValidos
	FROM #ordenes_con_flete o
	WHERE NOT EXISTS (
		-- Verificar que NO existan items sin EAN vÃ¡lido
		SELECT 1 
		FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
		WHERE ISNULL(JSON_QUERY(item.value, '$.components'), '[]') = '[]'
			AND (JSON_VALUE(item.value, '$.ean') IS NULL 
				 OR JSON_VALUE(item.value, '$.ean') = '' 
				 OR TRY_CAST(JSON_VALUE(item.value, '$.ean') AS INT) IS NULL)
    
		UNION ALL
    
		-- Verificar que NO existan componentes sin EAN vÃ¡lido
		SELECT 1
		FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
		CROSS APPLY OPENJSON(item.value, '$.components') AS comp
		WHERE ISNULL(JSON_QUERY(item.value, '$.components'), '[]') != '[]'
			AND (JSON_VALUE(comp.value, '$.ean') IS NULL 
				 OR JSON_VALUE(comp.value, '$.ean') = '' 
				 OR TRY_CAST(JSON_VALUE(comp.value, '$.ean') AS INT) IS NULL)
	);

	-- Ahora crear #ItemsNumReg solo con las Ã³rdenes vÃ¡lidas
	IF OBJECT_ID('tempdb..#ItemsNumReg') IS NOT NULL 
    DROP TABLE #ItemsNumReg;

	SELECT 
		id_orden,
		id_tienda,
		id,
		UniqueId,	
		ean,
		ref_id,
		price,
		sellingPrice,
		quantity,
		ROW_NUMBER() OVER (PARTITION BY id_orden ORDER BY id_orden) as f431_nro_registro,
		ISNULL(CAST(
        ROUND(
            (price - 
             CAST(
                 CASE 
                     WHEN sellingPrice IS NULL OR LEN(sellingPrice) < 3 
                     THEN '0' 
                     ELSE LEFT(sellingPrice, LEN(sellingPrice) - 2) 
                 END AS DECIMAL(18, 2)
             )) * 100.0 / NULLIF(price, 0),
            4
        ) AS DECIMAL(7, 4)
    ),0) AS f432_tasa
	INTO #ItemsNumReg 
	FROM (
		SELECT 
			JSON_VALUE(orden_obj_origen, '$.orderId') as id_orden,
			id_tienda,
			JSON_VALUE(item.value, '$.id') AS Id,
			JSON_VALUE(item.value, '$.uniqueId') AS UniqueId,
			JSON_VALUE(item.value, '$.ean') as ean,
			JSON_VALUE(item.value, '$.refId') as ref_id,
			CAST(JSON_VALUE(item.value, '$.price') AS DECIMAL(15,2)) / 100 as price,
			CAST(JSON_VALUE(item.value, '$.sellingPrice') AS DECIMAL(15,2)) / 100 AS sellingPrice,
			CAST(JSON_VALUE(item.value, '$.quantity') AS INT) as quantity
		FROM #ordenes_con_flete
		CROSS APPLY OPENJSON(orden_obj_origen, '$.items') AS item
		WHERE ISNULL(JSON_QUERY(item.value, '$.components'), '[]') = '[]'
			AND EXISTS (
				SELECT 1 FROM #OrdenesEANValidos v 
				WHERE v.id_orden = JSON_VALUE(orden_obj_origen, '$.orderId') 
					AND v.id_tienda = #ordenes_con_flete.id_tienda
			)

		UNION ALL

		SELECT 
			JSON_VALUE(orden_obj_origen, '$.orderId') as id_orden,
			id_tienda,
			JSON_VALUE(comp.value, '$.id') AS Id,
			JSON_VALUE(comp.value, '$.uniqueId') AS UniqueId,
			JSON_VALUE(comp.value, '$.ean') as ean,
			JSON_VALUE(comp.value, '$.refId') as ref_id,
			CAST(JSON_VALUE(comp.value, '$.price') AS DECIMAL(15,2)) / 100 AS price,
			CAST(JSON_VALUE(comp.value, '$.sellingPrice') AS DECIMAL(15,2)) / 100 AS sellingPrice,
			CAST(JSON_VALUE(comp.value, '$.quantity') AS INT) as quantity
		FROM #ordenes_con_flete
		CROSS APPLY OPENJSON(orden_obj_origen, '$.items') AS item
		CROSS APPLY OPENJSON(item.value, '$.components') AS comp
		WHERE ISNULL(JSON_QUERY(item.value, '$.components'), '[]') != '[]'
			AND EXISTS (
				SELECT 1 FROM #OrdenesEANValidos v 
				WHERE v.id_orden = JSON_VALUE(orden_obj_origen, '$.orderId') 
					AND v.id_tienda = #ordenes_con_flete.id_tienda
			)
	) AS order_items_extracted

	-- tabla temporal de ordenes
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
		o.id_tienda,
		o.id_orden,
		@endpoint as endpoint,
		getdate() as fecha_creacion,
		json_query((
    SELECT
        -- Pedidos
        json_query((
            SELECT *
            FROM (
                -- Pedido principal
                SELECT 
                    '010' AS f430_id_co,
                    'PED' AS f430_id_tipo_docto,
                    '1' AS f430_consec_docto,
                    CONVERT(VARCHAR(8), GETDATE(), 112) AS f430_id_fecha,
                    '2' AS f430_ind_estado,
                    CASE 
						   WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' 
						  THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END AS f430_id_tercero_fact,
                    '001' AS f430_id_sucursal_fact,
                    CASE 
						   WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' 
						  THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END AS f430_id_tercero_rem,
                    '001' AS f430_id_sucursal_rem,
                    '010' AS f430_id_co_fact,
                    CONVERT(VARCHAR(8), DATEADD(DAY,3,GETDATE()), 112) AS f430_fecha_entrega,
                    '3' AS f430_num_dias_entrega,
                    CASE 
                        WHEN LEN(REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-', '')) <= 15 
                            THEN REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-01', '01') 
                        ELSE JSON_VALUE(o.orden_obj_origen, '$.sequence') 
                    END AS f430_num_docto_referencia,
                    'ECOMMERCE' AS f430_referencia,
                    CONCAT(
                        'OrderId: ', JSON_VALUE(o.orden_obj_origen, '$.orderId'),
                        ' Secuencia: ', JSON_VALUE(o.orden_obj_origen, '$.sequence'),
                        ' Metodo Pago: ', JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName'),
                        ' Tienda: null'
                    ) AS f430_notas,
                    '000' AS f430_id_punto_envio,
                    ISNULL((
                        SELECT LTRIM(RTRIM(f200_id))
                        FROM #VendedoresERP
                        WHERE f210_id = ISNULL(JSON_VALUE(o.orden_obj_origen, '$.marketingData.utmiCampaign'), '9999')
                    ),'811015511') AS f430_id_tercero_vendedor

                UNION ALL

                -- Pedido de flete (si aplica)
                SELECT 
                    '010', 'TMS', '2', CONVERT(VARCHAR(8), GETDATE(), 112),'0',
                    CASE 
						   WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' 
						  THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END, 
					'001',
                    CASE 
						   WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' 
						  THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END, 
					'001',
                    '010', CONVERT(VARCHAR(8), DATEADD(DAY,3,GETDATE()), 112),
                    '3',
                    CASE 
                        WHEN LEN(REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-', '')) <= 15 
                            THEN REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-01', '02') 
                        ELSE JSON_VALUE(o.orden_obj_origen, '$.sequence') 
                    END,
                    'ECOMMERCE',
                    CONCAT(
                        'OrderId: ', JSON_VALUE(o.orden_obj_origen, '$.orderId'),
                        ' Secuencia: ', JSON_VALUE(o.orden_obj_origen, '$.sequence'),
                        ' Metodo Pago: ', JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName'),
                        ' Tienda: null'
                    ),
                    '000',
                    (
                        SELECT LTRIM(RTRIM(f200_id))
                        FROM #VendedoresERP
                        WHERE f210_id = ISNULL(JSON_VALUE(o.orden_obj_origen, '$.marketingData.utmiCampaign'), '9999')
                    )
                WHERE o.tiene_flete = 1
            ) AS pedidos_union
            FOR JSON PATH, INCLUDE_NULL_VALUES
        )) AS Pedidos,

        -- Movimientos
        json_query((
		SELECT * FROM (
            SELECT 
                '010' AS f431_id_co,
                'PED' AS f431_id_tipo_docto,
                '1' AS f431_consec_docto,
                CAST(i.f431_nro_registro AS VARCHAR(20)) AS f431_nro_registro,
                i.ean AS f431_id_item,
                '' AS f431_referencia_item,
                -- Bodega por movimiento: priorizar la bodega individual del componente
                -- en kitItemDetails; para artÃ­culos normales, usar warehouseId directo
                -- solo cuando sea una bodega individual y no una lista concatenada.
                ISNULL((
                    SELECT TOP (1)
                        CASE
                            WHEN JSON_VALUE(kit.value, '$.ItemId') = i.Id
                                THEN JSON_VALUE(kit.value, '$.WarehouseId')
                            ELSE JSON_VALUE(deliveryIds.value, '$.warehouseId')
                        END
                    FROM OPENJSON(
                        o.orden_obj_origen,
                        '$.shippingData.logisticsInfo'
                    ) logistics
                    CROSS APPLY OPENJSON(
                        JSON_QUERY(logistics.value, '$.deliveryIds')
                    ) deliveryIds
                    OUTER APPLY OPENJSON(
                        JSON_QUERY(deliveryIds.value, '$.kitItemDetails')
                    ) kit
                    WHERE
                        (
                            JSON_VALUE(kit.value, '$.ItemId') = i.Id
                            AND NULLIF(
                                LTRIM(RTRIM(JSON_VALUE(kit.value, '$.WarehouseId'))),
                                ''
                            ) IS NOT NULL
                            AND CHARINDEX(
                                '#',
                                JSON_VALUE(kit.value, '$.WarehouseId')
                            ) = 0
                        )
                        OR
                        (
                            JSON_VALUE(logistics.value, '$.itemId') = i.Id
                            AND NULLIF(
                                LTRIM(RTRIM(JSON_VALUE(deliveryIds.value, '$.warehouseId'))),
                                ''
                            ) IS NOT NULL
                            AND CHARINDEX(
                                '#',
                                JSON_VALUE(deliveryIds.value, '$.warehouseId')
                            ) = 0
                        )
                    ORDER BY
                        CASE
                            WHEN JSON_VALUE(kit.value, '$.ItemId') = i.Id THEN 0
                            ELSE 1
                        END
                ), 'BD001') AS f431_id_bodega,
                '010' AS f431_id_co_movto,
                '01' AS f431_id_un_movto,
                CONVERT(VARCHAR(8), DATEADD(DAY,3,GETDATE()), 112) AS f431_fecha_entrega,
                '3' AS f431_num_dias_entrega,
                '001' AS f431_id_lista_precio,
                ISNULL((
                    SELECT TOP 1 f120_id_unidad_orden
                    FROM OPENROWSET(
                        'SQLNCLI',
                        'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=pisende;Pwd=Pisende$12$%',
                        'SELECT f120_id,f120_referencia, f120_id_unidad_orden FROM dbo.t120_mc_items WHERE f120_id_cia = 1'
                    ) AS unidades
                    WHERE unidades.f120_id = i.ean
                ), 'UND') AS f431_id_unidad_medida,
                i.quantity AS f431_cant_pedida_base,
				i.price AS f431_precio_unitario
            FROM #ItemsNumReg i
            WHERE i.id_orden = JSON_VALUE(o.orden_obj_origen, '$.orderId') 
                AND i.id_tienda = o.id_tienda
			    AND (ean IS NOT NULL AND TRY_CAST(ean AS INT) IS NOT NULL)
            
            UNION ALL
            
            -- Movimiento de flete
            SELECT
                '010' AS f431_id_co,
                'TMS' AS f431_id_tipo_docto,
                '2' AS f431_consec_docto,
                '1' AS f431_nro_registro,
                '2400888' AS f431_id_item,
                '' AS f431_referencia_item,
                -- El artÃ­culo de flete 2400888 usa la bodega definida en Siesa.
                -- No tomar warehouseId del combo porque puede venir concatenado.
                'BD001' AS f431_id_bodega,
                '010' AS f431_id_co_movto,
                '01' AS f431_id_un_movto,
                CONVERT(VARCHAR(8), DATEADD(DAY,3,GETDATE()), 112) AS f431_fecha_entrega,
                '3' AS f431_num_dias_entrega,
                '001' AS f431_id_lista_precio,
                'UND' AS f431_id_unidad_medida,
                ROUND(CAST(
                    CAST(LEFT(JSON_VALUE(o.orden_obj_origen, '$.totals[2].value'), LEN(JSON_VALUE(o.orden_obj_origen, '$.totals[2].value')) - 2) AS DECIMAL(18, 2)) / 1000
                    AS FLOAT
                ),2) AS f431_cant_pedida_base,
				'1000' AS f431_precio_unitario
            WHERE o.tiene_flete = 1
                AND JSON_VALUE(o.orden_obj_origen, '$.totals[2].id') = 'Shipping'
                AND ISNULL(JSON_VALUE(o.orden_obj_origen, '$.totals[2].value'), '0') <> '0'
			) AS Movimientos_union
            FOR JSON PATH, INCLUDE_NULL_VALUES
        )) AS Movimientos,

        -- Descuentos
		json_query((
			SELECT * FROM (
				SELECT
					'1' AS f430_consec_docto,
					CAST(i.f431_nro_registro AS VARCHAR(20)) AS f431_nro_registro,
					i.f432_tasa
				FROM #ItemsNumReg i
				WHERE i.id_orden = JSON_VALUE(o.orden_obj_origen, '$.orderId') 
					AND i.id_tienda = o.id_tienda
					AND (ean IS NOT NULL AND TRY_CAST(ean AS INT) IS NOT NULL)
					AND i.f432_tasa IS NOT NULL
					AND i.f432_tasa > 0
			) AS Descuentos_union
			FOR JSON PATH, INCLUDE_NULL_VALUES
		)) AS Descuentos
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
))
 as orden_obj_destino 
	FROM #ordenes_con_flete o;

	--Realizar el UPDATE utilizando la tabla temporal
	UPDATE o
	SET 
		o.endpoint = t.endpoint,
		o.fecha_creacion = t.fecha_creacion,
		o.orden_obj_destino = t.orden_obj_destino
	FROM ordenes o
	JOIN #TempOrdenes t ON o.id_tienda = t.id_tienda AND o.id_orden = t.id_orden
	
END