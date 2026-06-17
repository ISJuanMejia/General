SET XACT_ABORT ON;

--Tablas
IF	OBJECT_ID('tempdb..#company_Ordenes')			IS NOT NULL DROP TABLE #company_Ordenes;
IF	OBJECT_ID('tempdb..##company_OrdenesCreadas')	IS NOT NULL DROP TABLE ##company_OrdenesCreadas;
IF	OBJECT_ID('tempdb..#company_Pedidos')			IS NOT NULL DROP TABLE #company_Pedidos;
IF	OBJECT_ID('tempdb..#company_Movimientos')		IS NOT NULL DROP TABLE #company_Movimientos;
IF	OBJECT_ID('tempdb..#company_Descuentos')		IS NOT NULL DROP TABLE #company_Descuentos;

BEGIN TRY

-- AJUSTAR CON LOS PARAMETROS DE TU CONECTOR.
DECLARE @idDocumento					INT				=	225805
		,@indicaParalelismo				BIT				=	0
		,@descripcion					VARCHAR(100)	=	'TecnoPlaza_PedidosDesc'


-- Variables
DECLARE @final							TABLE (idDocumento	INT,indicaParalelismo	BIT,descripcion	VARCHAR(100),idOrden VARCHAR(50), json	VARCHAR(MAX))
DECLARE @ImpuestoGI						TABLE (f120_id_cia INT, f120_referencia NVARCHAR(50), f037_id NVARCHAR(4), f037_tasa DECIMAL(15,2))
DECLARE @counter						INT				=	1;
DECLARE @total							INT;
DECLARE @tmpDescuento					TABLE ([row]	INT,amount	NVARCHAR(20))
DECLARE @json							VARCHAR(MAX)	=	'';
DECLARE @order							NVARCHAR(50);
DECLARE @tercero				        NVARCHAR(50);		
DECLARE @conexion						NVARCHAR(MAX)	=	(SELECT TOP 1 cadena_conexion FROM Conexiones)
DECLARE @base_datos						NVARCHAR(MAX)	=	(SELECT TOP 1 base_datos FROM Conexiones)
DECLARE @tabla							NVARCHAR(MAX)	=	@base_datos + '.dbo.t430_cm_pv_docto WHERE f430_ind_estado != 9 AND f430_id_cia = 1'


--Obtiene los pedidos ya procesados en el ERP
EXEC('
	SELECT DISTINCT
		   f430_referencia 
	  INTO ##company_OrdenesCreadas 
	  FROM OPENROWSET(
		   ''SQLNCLI''
		 , ''' + @conexion + '''
		 , ''
			 SELECT * 
			   FROM ' + @tabla + '''
	)'
)
	

--Actualizamos el estado de los registros ya procesados 
UPDATE o
  SET o.IdEstado = 4
 FROM Orders o
WHERE o.IdEstado = 3
  AND o.Intentos <= 3
  AND o.IdOrder IN (

        SELECT o2.IdOrder
        FROM Orders o2
        CROSS APPLY (
            SELECT  
                JSON_VALUE(o2.Order_jsonApi, '$.origin') AS origin,
                JSON_VALUE(o2.Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber') AS extNum
        ) j
        CROSS APPLY (
            SELECT 
                SUBSTRING(
                    j.extNum,
                    1 + PATINDEX('%[1-9]%', SUBSTRING(j.extNum, 2, LEN(j.extNum))),
                    LEN(j.extNum)
                ) AS cleanedValue
        ) c
        CROSS APPLY (
            SELECT CASE 
                    WHEN j.origin = 'mercadolibre' THEN 
                        CASE WHEN LEN(c.cleanedValue) > 10 
                             THEN RIGHT(c.cleanedValue, 10)
                             ELSE c.cleanedValue
                        END
                    ELSE 
                        CASE WHEN LEN(j.extNum) > 10 
                             THEN RIGHT(j.extNum, 10)
                             ELSE j.extNum
                        END
                END AS referenciaEsperada
        ) r
        JOIN ##company_OrdenesCreadas oc
            ON oc.f430_referencia = r.referenciaEsperada
  );


--GRUPOS IMPOSITIVOS
-- Variable para query de ejecución vía rowset para clientes SIESA.
DECLARE @queryClientesSiesa NVARCHAR(MAX)

-- La consulta que extrae los datos de los terceros clientes de SIESA Activos.
SET @queryClientesSiesa = 
N'
SELECT
	f120_id_cia, f120_referencia, f037_id, f037_tasa
FROM OPENROWSET(
	''SQLNCLI'', 
	'''+@conexion+''',
	''
	SELECT
		t120.f120_id_cia AS f120_id_cia, 
		RTRIM(t120.f120_referencia) AS f120_referencia, 
		t037.f037_id AS f037_id, 
		t037.f037_tasa AS f037_tasa
	FROM '+ @base_datos +'.dbo.t120_mc_items t120
	INNER JOIN	'+ @base_datos +'.dbo.t114_mc_grupos_impo_impuestos t114 ON t114.f114_id_cia = t120.f120_id_cia  
	AND t114.f114_grupo_impositivo = t120.f120_id_grupo_impositivo AND t114.f114_ind_tipo_indicador = 3
	INNER JOIN	'+ @base_datos +'.dbo.t037_mm_llaves_impuesto t037 ON t037.f037_id_cia = t114.f114_id_cia
	AND t114.f114_id_llave_impuesto = t037.f037_id
	ORDER BY t120.f120_referencia ASC
	''
)
'

INSERT INTO @ImpuestoGI
EXEC (@queryClientesSiesa);
	
PRINT('llenar datos')


--Filtramos por los registros a ser procesados
SELECT TOP 25
	   IdOrder
	   ,Order_jsonApi
	   ,ROW_NUMBER() OVER (ORDER BY (SELECT IdOrder)) AS Orden
  INTO #company_Ordenes
  FROM Orders   
 WHERE IdEstado = 3
   AND Intentos <= 1 
   AND id >= 2695
   AND 
   (
        (
             FechaCreacion >= '2026-04-06 00:00:00'
             AND
             FechaCreacion < '2026-04-09 16:55:00'
             AND 
             JSON_VALUE(Order_jsonApi, '$.Warehouse.name') IN ('FULL', 'Bodega Bogota', 'FULL FALABELLA', 'FULL ML BOGOTA', 'FULL ML TIENDA OFICIAL')
        )
        OR
        FechaCreacion >= '2026-04-09 16:55:00'
   )

   --AND IdOrder IN (
   --'3c42537b-f722-4163-a79a-d6fc3cdc41e5'
   --)

    
--Recorremos los pedidos
SET @total = (SELECT COUNT(*) FROM #company_Ordenes);
WHILE @counter <= @total
BEGIN

	--Obtenemos el id de la orden y el tercero
	SELECT @order = IdOrder, @tercero = JSON_VALUE(Order_jsonApi, '$.Client.taxId') 
	  FROM #company_Ordenes
	 WHERE Orden = @counter;
        
	-- PEDIDO
	 SELECT CONVERT(VARCHAR, GETDATE(), 112)	                                                  AS	f430_id_fecha,
			@tercero							                                                  AS	f430_id_tercero_fact,
			'002'								                                                  AS	f430_id_sucursal_fact,
			@tercero							                                                  AS	f430_id_tercero_rem,
			'002'								                                                  AS	f430_id_sucursal_rem,
			CONVERT(VARCHAR(8), DATEADD(DAY, 1, GETDATE()), 112)	                              AS	f430_fecha_entrega,
			'1'									                                                  AS	f430_num_dias_entrega,
			CASE 
				WHEN JSON_VALUE(Order_jsonApi, '$.origin') = 'mercadolibre' THEN 
				(
					SELECT 
						CASE 
							WHEN LEN(cleanValue) > 15 THEN RIGHT(cleanValue, 15)
							ELSE cleanValue
						END
					FROM (
						SELECT 
							-- limpiar: eliminar primer '2' + ceros consecutivos
							SUBSTRING(
								extNum,
								1 + PATINDEX('%[1-9]%', SUBSTRING(extNum, 2, LEN(extNum))),
								LEN(extNum)
							) AS cleanValue
						FROM (
							SELECT JSON_VALUE(Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber') AS extNum
						) AS x
					) AS z
				)
				ELSE 
					CASE 
						WHEN LEN(JSON_VALUE(Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber')) > 15 
							THEN RIGHT(JSON_VALUE(Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber'), 15)
						ELSE JSON_VALUE(Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber')
					END
			END									                                                  AS	f430_num_docto_referencia,
			CASE 
				WHEN JSON_VALUE(Order_jsonApi, '$.origin') = 'mercadolibre' THEN 
				(
					SELECT 
						CASE 
							WHEN LEN(cleanValue) > 10 THEN RIGHT(cleanValue, 10)
							ELSE cleanValue
						END
					FROM (
						SELECT 
							-- limpiar: eliminar primer '2' + ceros consecutivos
							SUBSTRING(
								extNum,
								1 + PATINDEX('%[1-9]%', SUBSTRING(extNum, 2, LEN(extNum))),
								LEN(extNum)
							) AS cleanValue
						FROM (
							SELECT JSON_VALUE(Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber') AS extNum
						) AS x
					) AS z
				)
				ELSE 
					CASE 
						WHEN LEN(JSON_VALUE(Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber')) > 10 
							THEN RIGHT(JSON_VALUE(Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber'), 10)
						ELSE JSON_VALUE(Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber')
					END
			END                                                                                   AS	f430_referencia,
			CONCAT(
				'Orden: ', IdOrder,
				'   Pedido de: ', JSON_VALUE(Order_jsonApi, '$.origin'), 
				'   Venta: ', JSON_VALUE(Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber'),
				'   Bodega: ', JSON_VALUE(Order_jsonApi, '$.Warehouse.name')
			)                                                                                      AS	f430_notas,
			'' 									                                                   AS	f430_id_tercero_vendedor,
			CASE 
				WHEN LEN(UPPER(JSON_VALUE(Order_jsonApi, '$.Client.fullName'))) > 50 
					THEN ISNULL(LEFT(UPPER(JSON_VALUE(Order_jsonApi, '$.Client.fullName')), 50),'')
				ELSE ISNULL(UPPER(JSON_VALUE(Order_jsonApi, '$.Client.fullName')),'')
		   END                                                                                     AS   f419_contacto
		INTO #company_Pedidos
		FROM #company_Ordenes
		WHERE Orden = @counter;


	 -- MOVIMIENTOS
	 SELECT ROW_NUMBER() OVER(ORDER BY JSON_VALUE(value, '$.ProductVersion._id'))                         AS f431_nro_registro,
			CASE WHEN JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' AND UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%HP%' 
					  THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'),'-','#')
				 WHEN JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' AND UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%APPLE%'
					  THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'),'-','/')
				 ELSE JSON_VALUE(value, '$.ProductVersion.code')
			END                                                                                            AS f431_referencia_item,
			CASE JSON_VALUE(Order_jsonApi, '$.Warehouse.name')
			     WHEN 'Bodega Ingram' THEN '01' 
				 WHEN 'Bodega Online' THEN '01'
				 WHEN 'FULL' THEN '04' 
				 WHEN 'Bodega Bogota' THEN '02' 
				 WHEN 'FULL FALABELLA' THEN '08' 
				 WHEN 'FULL ML BOGOTA' THEN '11'
				 WHEN 'FULL ML TIENDA OFICIAL' THEN '06'
			     ELSE '01'
			END                                                                                            AS f431_id_bodega,
			CONVERT(VARCHAR(8), DATEADD(DAY, 1, GETDATE()), 112)                                           AS f431_fecha_entrega,
			'1'                                                                                            AS f431_num_dias_entrega,
			TRIM(ISNULL(f120_id_unidad_inventario, 'UND'))                                                 AS f431_id_unidad_medida,
			JSON_VALUE(value, '$.count')                                                                   AS f431_cant_pedida_base,

			CAST(((JSON_VALUE(value, '$.gross')-CAST(
				ISNULL(
					TRY_CAST(JSON_VALUE(value, '$.CheckoutItemDiscounts[0].discount') AS DECIMAL(18,2)) 
					/ NULLIF(CAST(JSON_VALUE(value, '$.count') AS INT), 0),
					0
				) AS DECIMAL(18,2)
			))
			/((ISNULL(impuesto.f037_tasa,0) / 100)+ 1)) AS DECIMAL(18,2))                                  AS f431_precio_unitario,
			''                                                                                             AS f431_notas
		INTO #company_Movimientos
		FROM #company_Ordenes o
		CROSS APPLY OPENJSON(Order_jsonApi, '$.CheckoutItems')  
		LEFT JOIN OPENROWSET(
			'SQLNCLI',
			'server=siesa-m3-sqlsw-sbs01.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=SUnoEE_TecnoPlaza_Real;uid=tecnoplaza;pwd=Tecnoplaza$12$%',
			'SELECT * FROM t120_mc_items'
		) AS t120
		ON f120_referencia = CASE WHEN JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' AND UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%HP%' 
										THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'),'-','#')
									WHEN JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' AND UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%APPLE%'
										THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'),'-','/')
									ELSE JSON_VALUE(value, '$.ProductVersion.code')
							 END
		LEFT JOIN @ImpuestoGI AS impuesto ON impuesto.f120_id_cia = 1 AND impuesto.f120_referencia = CASE WHEN JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' AND UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%HP%' 
																											  THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'),'-','#')
																										 WHEN JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' AND UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%APPLE%'
																											  THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'),'-','/')
																										 ELSE JSON_VALUE(value, '$.ProductVersion.code')
																									END
		WHERE Orden = @counter;


		-- DESCUENTOS
		--SELECT ROW_NUMBER() OVER (ORDER BY JSON_VALUE(value, '$.ProductVersion._id')) AS f431_nro_registro,
		--		CAST(
		--		ISNULL(
		--			TRY_CAST(JSON_VALUE(value, '$.CheckoutItemDiscounts[0].discount') AS DECIMAL(18,4)) 
		--			/ NULLIF(CAST(JSON_VALUE(value, '$.count') AS INT), 0),
		--			0
		--		) AS DECIMAL(18,4)
		--	) AS f432_vlr_uni
		--INTO #company_Descuentos
		--FROM #company_Ordenes o
		--CROSS APPLY OPENJSON(Order_jsonApi, '$.CheckoutItems')  
		--LEFT JOIN OPENROWSET(
		--	'SQLNCLI',
		--	'server=siesa-m3-sqlsw-sbs01.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=SUnoEE_TecnoPlaza_Real;uid=tecnoplaza;pwd=Tecnoplaza$12$%',
		--	'SELECT * FROM t120_mc_items'
		--) AS t120
		--ON f120_referencia = JSON_VALUE(value, '$.ProductVersion.Product.code')
		--WHERE Orden = @counter;


		INSERT INTO @final (
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
			@order AS idOrden,
			(
				SELECT
					[Pedidos] = (
						SELECT 
							p.*
						FROM #company_Pedidos p
						FOR JSON PATH
					),
					[MovtoPedidosComercial] = (
						SELECT 
							m.*
						FROM #company_Movimientos m
						FOR JSON PATH
					)--,
					--[Descuentos] = JSON_QUERY(
					--	CASE 
					--		WHEN EXISTS (
					--			SELECT 1 
					--			FROM #company_Descuentos d
					--			WHERE ISNULL(d.f432_vlr_uni, 0) <> 0
					--		)
					--		THEN (
					--			SELECT 
					--				d.*
					--			FROM #company_Descuentos d
					--			WHERE ISNULL(d.f432_vlr_uni, 0) <> 0
					--			FOR JSON PATH
					--		)
					--	END
					--)
				FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
			) AS json;

		
		IF	OBJECT_ID('tempdb..#company_Pedidos')			IS NOT NULL DROP TABLE #company_Pedidos;
		IF	OBJECT_ID('tempdb..#company_Movimientos')		IS NOT NULL DROP TABLE #company_Movimientos;
		IF	OBJECT_ID('tempdb..#company_Descuentos')		IS NOT NULL DROP TABLE #company_Descuentos;
		
		SET @counter = @counter + 1;
	END

	IF	OBJECT_ID('tempdb..#company_Ordenes')			IS NOT NULL DROP TABLE #company_Ordenes;
	IF	OBJECT_ID('tempdb..##company_OrdenesCreadas')	IS NOT NULL DROP TABLE ##company_OrdenesCreadas;

END TRY
BEGIN CATCH
	SELECT CAST(1 AS BIT) AS indicaError, CONCAT('Error: ', ERROR_MESSAGE()) AS descripcionError
	GOTO Cleanup;
END CATCH
CLEANUP:
	BEGIN
		IF	OBJECT_ID('tempdb..#company_Ordenes')			IS NOT NULL DROP TABLE #company_Ordenes;
		IF	OBJECT_ID('tempdb..##company_OrdenesCreadas')	IS NOT NULL DROP TABLE ##company_OrdenesCreadas;
		IF	OBJECT_ID('tempdb..#company_Pedidos')			IS NOT NULL DROP TABLE #company_Pedidos;
		IF	OBJECT_ID('tempdb..#company_Movimientos')		IS NOT NULL DROP TABLE #company_Movimientos;
		IF	OBJECT_ID('tempdb..#company_Descuentos')		IS NOT NULL DROP TABLE #company_Descuentos;
	END

SELECT * FROM @final AS final_json;