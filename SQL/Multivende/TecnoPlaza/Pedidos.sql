SET XACT_ABORT ON;

BEGIN TRY
	--->	AJUSTAR CON LOS PARAMETROS DE TU CONECTOR.
	DECLARE	@id_documento			INT				=	225805,
			@descripcion_conector	VARCHAR(100)	=	'TecnoPlaza_PedidosDesc',
			@indica_paralelismo		BIT				=	0;

	--->	Variables
	DECLARE @final	TABLE 
	(
		idDocumento			INT,
		indicaParalelismo	BIT,
		descripcion			VARCHAR(100),
		idOrden				VARCHAR(50), 
		json				VARCHAR(MAX)
	);

	--->	Tablas
	IF	OBJECT_ID('tempdb..#company_OrdenesCreadas')	IS NOT NULL DROP TABLE #company_OrdenesCreadas;
	IF	OBJECT_ID('tempdb..#company_Pedidos')			IS NOT NULL DROP TABLE #company_Pedidos;
	IF	OBJECT_ID('tempdb..#company_Movimientos')		IS NOT NULL DROP TABLE #company_Movimientos;
	IF	OBJECT_ID('tempdb..#company_Descuentos')		IS NOT NULL DROP TABLE #company_Descuentos;
	IF	OBJECT_ID('tempdb..#ItemsUnidad')				IS NOT NULL DROP TABLE #ItemsUnidad;

	DECLARE @ImpuestoGI	TABLE 
	(
		f120_id_cia		INT, 
		f120_referencia	NVARCHAR(50), 
		f037_id			NVARCHAR(4), 
		f037_tasa		DECIMAL(15,2)
	);

	DECLARE @counter		INT				=	1;
	DECLARE @total			INT;
	DECLARE @order			NVARCHAR(50);
	DECLARE @tercero		NVARCHAR(50);
	DECLARE @tipo_tercero	INT				=	NULL;
	DECLARE @conexion		NVARCHAR(MAX)	=	(SELECT TOP 1 cadena_conexion FROM dbo.Conexiones);
	DECLARE @base_datos		NVARCHAR(MAX)	=	(SELECT TOP 1 base_datos FROM dbo.Conexiones);

	IF @conexion IS NULL OR @base_datos IS NULL
	BEGIN
		RAISERROR('No se encontró configuración en la tabla Conexiones.', 16, 1);
		RETURN;
	END

	DECLARE @tabla NVARCHAR(MAX) = @base_datos + '.dbo.t430_cm_pv_docto WHERE f430_ind_estado != 9 AND f430_id_cia = 1';

	-- Pre-crear tabla temporal local de pedidos ya procesados en ERP
	CREATE TABLE #company_OrdenesCreadas
	(
		f430_referencia NVARCHAR(100)
	);

	DECLARE @sqlCreadas NVARCHAR(MAX) = N'
	INSERT INTO #company_OrdenesCreadas (f430_referencia)
	SELECT DISTINCT f430_referencia 
	FROM OPENROWSET(
		''SQLNCLI'',
		''' + REPLACE(@conexion, '''', '''''') + ''',
		''SELECT f430_referencia FROM ' + @tabla + '''
	);';

	EXEC sp_executesql @sqlCreadas;

	-- Actualizamos el estado de los registros ya procesados en ERP a IdEstado = 4
	UPDATE o
	SET
		o.IdEstado	=	4
	FROM Orders o
	WHERE
		o.IdEstado	=	3
		AND
		o.Intentos	<=	3
		AND 
		o.IdOrder IN (
			SELECT 
				o2.IdOrder
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
					SELECT 
						CASE 
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
				JOIN #company_OrdenesCreadas oc
					ON oc.f430_referencia = r.referenciaEsperada
		);

	-- Pre-cargar catálogo de unidades de inventario de ítems de Siesa (fuera del bucle)
	CREATE TABLE #ItemsUnidad
	(
		f120_referencia           NVARCHAR(50) NOT NULL PRIMARY KEY,
		f120_id_unidad_inventario NVARCHAR(10) NULL
	);

	DECLARE @sqlItems NVARCHAR(MAX) = N'
	INSERT INTO #ItemsUnidad (f120_referencia, f120_id_unidad_inventario)
	SELECT 
		RTRIM(f120_referencia), 
		f120_id_unidad_inventario
	FROM OPENROWSET(
		''SQLNCLI'',
		''' + REPLACE(@conexion, '''', '''''') + ''',
		''SELECT f120_referencia, f120_id_unidad_inventario FROM ' + @base_datos + '.dbo.t120_mc_items WHERE f120_id_cia = 1''
	);';

	EXEC sp_executesql @sqlItems;

	-- GRUPOS IMPOSITIVOS (Tasas de impuesto por ítem)
	DECLARE @queryClientesSiesa NVARCHAR(MAX) = N'
	SELECT
		f120_id_cia, 
		f120_referencia, 
		f037_id, 
		f037_tasa
	FROM OPENROWSET(
		''SQLNCLI'', 
		''' + REPLACE(@conexion, '''', '''''') + ''',
		''
		SELECT
			t120.f120_id_cia AS f120_id_cia, 
			RTRIM(t120.f120_referencia) AS f120_referencia, 
			t037.f037_id AS f037_id, 
			t037.f037_tasa AS f037_tasa
		FROM ' + @base_datos + '.dbo.t120_mc_items t120
		INNER JOIN ' + @base_datos + '.dbo.t114_mc_grupos_impo_impuestos t114 
			ON t114.f114_id_cia = t120.f120_id_cia  
		   AND t114.f114_grupo_impositivo = t120.f120_id_grupo_impositivo 
		   AND t114.f114_ind_tipo_indicador = 3
		INNER JOIN ' + @base_datos + '.dbo.t037_mm_llaves_impuesto t037 
			ON t037.f037_id_cia = t114.f114_id_cia
		   AND t114.f114_id_llave_impuesto = t037.f037_id
		ORDER BY t120.f120_referencia ASC
		''
	);';

	INSERT INTO @ImpuestoGI
	EXEC sp_executesql @queryClientesSiesa;

	DECLARE	@ordenes	TABLE
	(
		IdOrder			NVARCHAR(300),
		Order_jsonApi	NVARCHAR(MAX),
		Orden			INT,
		documentoTer	NVARCHAR(100),
		tipoTercero		INT
	);

	-- Filtramos por los registros a ser procesados
	INSERT INTO @ordenes
	SELECT TOP 25
		[IdOrder]		=	IdOrder,
		[Order_jsonApi]	=	Order_jsonApi,
		[Orden]			=	ROW_NUMBER() OVER (ORDER BY IdOrder),
		[documentoTer]	=	dbo.OnlyNumbers(JSON_VALUE(Order_jsonApi, '$.Client.taxId')),
		[tipoTercero]	=
			CASE
				WHEN JSON_VALUE(Order_jsonApi, '$.Client.taxId') LIKE '[789]%'
				 AND LEN(JSON_VALUE(Order_jsonApi, '$.Client.taxId')) >= 9
					THEN 2
				ELSE 1
			END
	FROM Orders   
	WHERE
		IdEstado = 3
		AND 
		Intentos <= 1 
		AND 
		id >= 2695
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
		AND
		(
			SWITCHOFFSET(
				TRY_CONVERT(datetimeoffset, JSON_VALUE(Order_jsonApi, '$.createdAt')),
				DATENAME(TzOffset, SYSDATETIMEOFFSET())
			) > 
			CASE
				WHEN JSON_VALUE(Order_jsonApi, '$.Warehouse.name') IN ('Bodega Ingram', 'Bodega Online', 'Bodega Bogota') 
					THEN    
						CASE
							WHEN DATEADD(DAY, -7, GETDATE()) <= '2026-06-12 17:00:00'
								THEN '2026-06-12 17:00:00'
							ELSE DATEADD(DAY, -7, GETDATE())
						END
				WHEN JSON_VALUE(Order_jsonApi, '$.Warehouse.name') IN ('FULL', 'FULL FALABELLA', 'FULL ML BOGOTA', 'FULL ML TIENDA OFICIAL') 
					THEN DATEADD(DAY, -7, GETDATE())
				ELSE 
					CASE
						WHEN DATEADD(DAY, -7, GETDATE()) <= '2026-06-12 17:00:00'
							THEN '2026-06-12 17:00:00'
						ELSE DATEADD(DAY, -7, GETDATE())
					END
			END 
		);

	--->	Recorremos los pedidos
	SET @total = (SELECT COUNT(*) FROM @ordenes);

	WHILE @counter <= @total
	BEGIN
		BEGIN TRY
			SET @tipo_tercero = NULL;

			-- Obtenemos el id de la orden y el tercero
			SELECT
				@order		=	IdOrder,
				@tercero	=	
					CASE
						WHEN tipoTercero = 2 
							THEN
								CASE
									WHEN LEN(documentoTer) > 9
										THEN LEFT(documentoTer, 9)
									ELSE documentoTer
								END 
						ELSE documentoTer
					END,
				@tipo_tercero = tipoTercero
			FROM @ordenes
			WHERE Orden = @counter;
			
			-- CABECERA PEDIDO
			SELECT
				CONVERT(VARCHAR, GETDATE(), 112)	                                                  AS	f430_id_fecha,
				@tercero							                                                  AS	f430_id_tercero_fact,
				@tercero							                                                  AS	f430_id_tercero_rem,
				CONVERT(VARCHAR(8), DATEADD(DAY, 1, GETDATE()), 112)	                              AS	f430_fecha_entrega,
				CASE 
					WHEN JSON_VALUE(Order_jsonApi, '$.origin') = 'mercadolibre' 
						THEN 
							(
								SELECT 
									CASE 
										WHEN LEN(cleanValue) > 15 
											THEN RIGHT(cleanValue, 15)
										ELSE cleanValue
									END
								FROM (
									SELECT 
										SUBSTRING(
											extNum,
											1 + PATINDEX('%[1-9]%', SUBSTRING(extNum, 2, LEN(extNum))),
											LEN(extNum)
										) AS cleanValue
									FROM (
										SELECT 
											JSON_VALUE(Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber') AS extNum
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
					WHEN JSON_VALUE(Order_jsonApi, '$.origin') = 'mercadolibre' 
						THEN 
							(
								SELECT 
									CASE 
										WHEN LEN(cleanValue) > 10 
											THEN RIGHT(cleanValue, 10)
										ELSE cleanValue
									END
								FROM (
									SELECT 
										SUBSTRING(
											extNum,
											1 + PATINDEX('%[1-9]%', SUBSTRING(extNum, 2, LEN(extNum))),
											LEN(extNum)
										) AS cleanValue
									FROM (
										SELECT 
											JSON_VALUE(Order_jsonApi, '$.CheckoutLinks[0].externalOrderNumber') AS extNum
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
				f419_contacto =
					CASE @tipo_tercero
						WHEN 1
							THEN
								CASE 
									WHEN LEN(UPPER(JSON_VALUE(Order_jsonApi, '$.Client.fullName'))) > 50 
										THEN ISNULL(LEFT(UPPER(JSON_VALUE(Order_jsonApi, '$.Client.fullName')), 50), '')
									ELSE ISNULL(UPPER(JSON_VALUE(Order_jsonApi, '$.Client.fullName')), '')
								END
						ELSE REPLACE(JSON_VALUE(Order_jsonApi, '$.Client.name'), '&', '')
					END
			INTO #company_Pedidos
			FROM @ordenes
			WHERE Orden = @counter;

			-- MOVIMIENTOS
			SELECT 
				ROW_NUMBER() OVER(ORDER BY JSON_VALUE(value, '$.ProductVersion._id'))                         AS f431_nro_registro,
				CASE 
					WHEN 
						JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' 
						AND 
						UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%HP%' 
						THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'), '-', '#')
					WHEN
						JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' 
						AND 
						UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%APPLE%'
						THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'), '-', '/')
					ELSE JSON_VALUE(value, '$.ProductVersion.code')
				END                                                                                            AS f431_referencia_item,
				CASE JSON_VALUE(Order_jsonApi, '$.Warehouse.name')
			    	WHEN 'Bodega Ingram'          THEN '01' 
					WHEN 'Bodega Online'          THEN '01'
					WHEN 'FULL'                   THEN '04' 
					WHEN 'Bodega Bogota'          THEN '02' 
					WHEN 'FULL FALABELLA'         THEN '08' 
					WHEN 'FULL ML BOGOTA'         THEN '11'
					WHEN 'FULL ML TIENDA OFICIAL' THEN '06'
			    	ELSE '01'
				END                                                                                            AS f431_id_bodega,
				CONVERT(VARCHAR(8), DATEADD(DAY, 1, GETDATE()), 112)                                           AS f431_fecha_entrega,
				'1'                                                                                            AS f431_num_dias_entrega,
				TRIM(ISNULL(t120.f120_id_unidad_inventario, 'UND'))                                            AS f431_id_unidad_medida,
				JSON_VALUE(value, '$.count')                                                                   AS f431_cant_pedida_base,
				CAST((
					(ISNULL(TRY_CAST(JSON_VALUE(value, '$.gross') AS DECIMAL(18,2)), 0) -
					 CAST(
						ISNULL(
							TRY_CAST(JSON_VALUE(value, '$.CheckoutItemDiscounts[0].discount') AS DECIMAL(18,2)) 
							/ NULLIF(CAST(JSON_VALUE(value, '$.count') AS INT), 0),
							0
						) AS DECIMAL(18,2)
					 ))
					/ ((ISNULL(impuesto.f037_tasa, 0) / 100.0) + 1.0)
				) AS DECIMAL(18,2))                                                                            AS f431_precio_unitario,
				''                                                                                             AS f431_notas
			INTO #company_Movimientos
			FROM @ordenes o
				CROSS APPLY OPENJSON(Order_jsonApi, '$.CheckoutItems')  
				LEFT JOIN #ItemsUnidad AS t120
					ON t120.f120_referencia =
						CASE
							WHEN JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' 
							 AND UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%HP%' 
								THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'), '-', '#')
							WHEN JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' 
							 AND UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%APPLE%'
								THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'), '-', '/')
							ELSE JSON_VALUE(value, '$.ProductVersion.code')
						END
				LEFT JOIN @ImpuestoGI AS impuesto 
					ON impuesto.f120_id_cia = 1 
				   AND impuesto.f120_referencia = 
						CASE 
							WHEN JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' 
							 AND UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%HP%'
								THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'), '-', '#')
							WHEN JSON_VALUE(value, '$.ProductVersion.code') LIKE '%-%' 
							 AND UPPER(JSON_VALUE(value, '$.ProductVersion.Product.name')) LIKE '%APPLE%'
								THEN REPLACE(JSON_VALUE(value, '$.ProductVersion.code'), '-', '/')
							ELSE JSON_VALUE(value, '$.ProductVersion.code')
						END
			WHERE Orden = @counter;

			INSERT INTO @final (
				idDocumento,
				indicaParalelismo,
				descripcion,
				idOrden,
				json
			)
			SELECT 
				@id_documento,
				@indica_paralelismo,
				@descripcion_conector,
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
						)
					FOR JSON PATH, 
					WITHOUT_ARRAY_WRAPPER
				) AS json;
		END TRY
		BEGIN CATCH
			-- Registrar novedad en consola para monitoreo sin interrumpir el lote
			PRINT CONCAT('Novedad procesando orden ', @order, ' (fila ', @counter, '): ', ERROR_MESSAGE());
		END CATCH;
			
		IF OBJECT_ID('tempdb..#company_Pedidos')     IS NOT NULL DROP TABLE #company_Pedidos;
		IF OBJECT_ID('tempdb..#company_Movimientos') IS NOT NULL DROP TABLE #company_Movimientos;
		IF OBJECT_ID('tempdb..#company_Descuentos')  IS NOT NULL DROP TABLE #company_Descuentos;
	
		SET @counter = @counter + 1;
	END;

	IF OBJECT_ID('tempdb..#company_OrdenesCreadas') IS NOT NULL DROP TABLE #company_OrdenesCreadas;
	IF OBJECT_ID('tempdb..#ItemsUnidad')            IS NOT NULL DROP TABLE #ItemsUnidad;
END TRY
BEGIN CATCH
	SELECT 
		CAST(1 AS BIT) AS indicaError, 
		CONCAT('Error general en Pedidos: ', ERROR_MESSAGE()) AS descripcionError;
	GOTO Cleanup;
END CATCH;

CLEANUP:
	BEGIN
		IF OBJECT_ID('tempdb..#company_OrdenesCreadas') IS NOT NULL DROP TABLE #company_OrdenesCreadas;
		IF OBJECT_ID('tempdb..#company_Pedidos')        IS NOT NULL DROP TABLE #company_Pedidos;
		IF OBJECT_ID('tempdb..#company_Movimientos')    IS NOT NULL DROP TABLE #company_Movimientos;
		IF OBJECT_ID('tempdb..#company_Descuentos')     IS NOT NULL DROP TABLE #company_Descuentos;
		IF OBJECT_ID('tempdb..#ItemsUnidad')            IS NOT NULL DROP TABLE #ItemsUnidad;
	END;

SELECT * FROM @final AS final_json;