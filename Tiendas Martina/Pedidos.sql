SET XACT_ABORT ON;

DECLARE @json VARCHAR(MAX) = '';

DECLARE @final TABLE (
	idDocumento            INT,
	indicaParalelismo      BIT,
	descripcion            VARCHAR(100),
	idOrden                VARCHAR(50),
	json                   VARCHAR(MAX)
);

DECLARE @TmpError TABLE (
	indicaError            INT,
	idDocumento            INT,
	indicaParalelismo      BIT,
	descripcionError       VARCHAR(MAX),
	idOrden                VARCHAR(50)
);

DECLARE @idDocumento       INT           = 207134,
		@indicaParalelismo BIT           = 0,
		@descripcion       VARCHAR(100)  = '02_Ecommerce_Connekta_Pedido';

DECLARE @counter            INT          = 1;
DECLARE @total              INT;
DECLARE @order              VARCHAR(30);
DECLARE @tmpDescuento       TABLE ([row] INT, amount NVARCHAR(20));
DECLARE @paymentType        NVARCHAR(MAX);
DECLARE @paymentValue       NVARCHAR(MAX);

BEGIN TRY

	DECLARE @conexion NVARCHAR(MAX) = (SELECT TOP 1 cadena_conexion FROM Conexiones);
	DECLARE @base_datos NVARCHAR(MAX) = (SELECT TOP 1 base_datos FROM Conexiones);
	DECLARE @tabla NVARCHAR(MAX) = @base_datos + '.dbo.t430_cm_pv_docto WHERE f430_ind_estado != 9 AND f430_id_cia = 1';

	EXEC('SELECT DISTINCT f430_referencia INTO ##tmp_OrdenesCreadas 
		  FROM OPENROWSET(''SQLNCLI'', ''' + @conexion + ''', ''SELECT * FROM ' + @tabla + ''')');

	SELECT  id_orden,
			orden_obj
	INTO    #ordenes
	FROM    ordenes 
	LEFT JOIN ##tmp_OrdenesCreadas oc ON oc.f430_referencia = REPLACE(id_orden, '"', '')
	WHERE   id_estado = 2 AND intentos <= 3;  -- Filtro principal

	SET @total = (SELECT COUNT(*) FROM #ordenes);

	WHILE @counter <= @total
	BEGIN
		SET @json = (
			SELECT orden_obj
			FROM (
				SELECT orden_obj, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
				FROM #ordenes
			) AS temp
			WHERE rn = @counter
		);

		SET @order = JSON_VALUE(@json, '$.name');

		-- validar métodos de pago
		SELECT TOP 1
				@paymentType = [value],
				@paymentValue = CASE 
									WHEN value = 'Sistecredito' THEN '0004'
									WHEN value = 'Addi Payment' THEN '0003'
									WHEN value = 'Wompi'		THEN '0006'
									WHEN value = 'Checkout Mercado Pago' OR value = 'Mercado Pago Checkout Pro' THEN '0005'
									ELSE '0001' 
								END
		FROM    OPENJSON(@json, '$.payment_gateway_names') AS payment
		WHERE   [value] != 'gift_card'
		ORDER BY [key] DESC;

		-- encabezado
		SELECT 
				FORMAT(GETDATE(), 'yyyyMMdd')																					 AS f430_id_fecha,
				FORMAT(GETDATE(), 'yyyyMMdd')																				     AS f430_fecha_entrega,
				'1'																												 AS f430_num_dias_entrega,
				JSON_VALUE(@json, '$.name')																						 AS f430_referencia,
				JSON_VALUE(@json, '$.name')																						 AS f430_notas,
				ISNULL(JSON_VALUE(@json, '$.billing_address.company'), JSON_VALUE(@json, '$.customer.default_address.company'))  AS f430_id_tercero_fact,
				ISNULL(JSON_VALUE(@json, '$.billing_address.company'), JSON_VALUE(@json, '$.customer.default_address.company'))  AS f430_id_tercero_rem,
				@paymentValue																									 AS f430_id_tipo_cli_fact
		INTO    #pedidos;

		-- movimiento (usa SKU del JSON como código de barras)
		SELECT
				ROW_NUMBER() OVER (ORDER BY (JSON_VALUE(LineItems.value, '$.id')))												 AS f431_nro_registro,
				JSON_VALUE(LineItems.value, '$.price')																			 AS f431_precio_unitario,
				2																												 AS f431_ind_precio,
				CAST('' AS VARCHAR(50))																							 AS f431_referencia_item,
				--JSON_VALUE(LineItems.value, '$.sku')																			 AS f431_codigo_barras,
				CASE 
					WHEN LEFT(JSON_VALUE(LineItems.value, '$.sku'),1)='0'
					THEN SUBSTRING(JSON_VALUE(LineItems.value, '$.sku'),2, LEN(JSON_VALUE(LineItems.value, '$.sku'))-1)
					ELSE JSON_VALUE(LineItems.value, '$.sku')
					END																											 AS f431_codigo_barras,
				FORMAT(GETDATE(), 'yyyyMMdd')																					 AS f431_fecha_entrega,
				1																												 AS f431_num_dias_entrega,
				JSON_VALUE(LineItems.value, '$.quantity')																		 AS f431_cant_pedida_base,
				'LP1'																											 AS f431_id_lista_precio,
				@paymentType																									 AS f431_notas
		INTO    #movimientos
		FROM    OPENJSON(@json, '$.line_items') AS LineItems
		ORDER BY JSON_VALUE(LineItems.value, '$.id');

		-- valida si tiene envío
		SELECT  JSON_VALUE(ShippingLines.value, '$.discount_allocations[0].amount')												 AS amount
		INTO    #Shipping_lines
		FROM    OPENJSON(@json, '$.shipping_lines') AS ShippingLines;

		IF NOT EXISTS (SELECT amount FROM #Shipping_lines WHERE amount IS NOT NULL)
		BEGIN
			INSERT INTO #movimientos (
				f431_nro_registro,
				f431_precio_unitario,
				f431_ind_precio,
				f431_referencia_item,
				f431_codigo_barras,
				f431_fecha_entrega,
				f431_num_dias_entrega,
				f431_cant_pedida_base,
				f431_id_lista_precio,
				f431_notas
			)
			SELECT 
				0                                                                                              AS f431_nro_registro,
				JSON_VALUE(sl.value, '$.price')                                                                AS f431_precio_unitario,
				2                                                                                              AS f431_ind_precio,
				CASE 
					WHEN JSON_VALUE(sl.value, '$.price') = '10000.00' THEN '0002692'  
					WHEN JSON_VALUE(sl.value, '$.price') = '14000.00' THEN '0002691'  
					ELSE '' 
				END																							   AS f431_referencia_item,
				''                                                                                             AS f431_codigo_barras,
				FORMAT(GETDATE(), 'yyyyMMdd')                                                                  AS f431_fecha_entrega,
				1                                                                                              AS f431_num_dias_entrega,
				1                                                                                              AS f431_cant_pedida_base,
				'LP1'                                                                                          AS f431_id_lista_precio,
				CASE 
					WHEN JSON_VALUE(sl.value, '$.price') = '10000.00' THEN 'Flete local'
					WHEN JSON_VALUE(sl.value, '$.price') = '14000.00' THEN 'Flete nacional'
					ELSE ''
				END																							   AS f431_notas
			FROM OPENJSON(@json, '$.shipping_lines') AS sl
			WHERE JSON_VALUE(sl.value, '$.price') NOT IN ('0.00', '0')
			  AND JSON_VALUE(sl.value, '$.is_removed') = 'false';
		END;

		-- valida el descuento
		IF EXISTS (SELECT value FROM OPENJSON(@json, '$.discount_applications'))
		BEGIN
			SELECT *, @json AS json
			INTO #descuentostemp
			FROM OPENJSON(@json)
			WITH (
				discount_applications NVARCHAR(MAX)                                                            '$.discount_applications[0].type',
				[value]                NVARCHAR(5)                                                             '$.discount_applications[0].value',
				[name]                 VARCHAR(10)                                                             '$.name',
				[target_type]          VARCHAR(50)                                                             '$.discount_applications[0].target_type',
				[value_type]           VARCHAR(50)                                                             '$.discount_applications[0].value_type'
			) AS c1;

			-- valida descuento por línea
			IF EXISTS (SELECT TOP 1 target_type FROM #descuentostemp WHERE target_type = 'line_item')
			BEGIN
				INSERT INTO @tmpDescuento
				SELECT  
					ROW_NUMBER() OVER (ORDER BY (JSON_VALUE(LineItems.value, '$.id')))                           AS [row],
					CONVERT(MONEY, JSON_VALUE(Discount.value, '$.amount')) / 
					CONVERT(MONEY, JSON_VALUE(LineItems.value, '$.quantity'))                                   AS amount
				FROM OPENJSON(@json, '$.line_items') AS LineItems
				CROSS APPLY OPENJSON(LineItems.value, '$.discount_allocations') AS Discount;
			END;
		END;

		-- valida si el precio del ecommerce difiere del ERP (lo toma como descuento)
		EXEC('SELECT DISTINCT f126_precio, f121_id_barras_principal INTO ##tmp_PreciosErp 
			  FROM OPENROWSET(''SQLNCLI'', ''' + @conexion + ''', 
			  ''SELECT * FROM t126_mc_items_precios 
				INNER JOIN t121_mc_items_extensiones 
				ON f121_rowid = f126_rowid_item_ext 
				WHERE f126_id_lista_precio = ''''P01'''' '')');

		INSERT INTO @tmpDescuento
		SELECT 
				m.f431_nro_registro                                                                            AS [row],
				p.f126_precio - JSON_VALUE(li.value, '$.price')                                                AS amount
		FROM    #movimientos m
		INNER JOIN ##tmp_PreciosErp p ON m.f431_codigo_barras = p.f121_id_barras_principal
		INNER JOIN OPENJSON(@json, '$.line_items') AS li 
				ON JSON_VALUE(li.value, '$.sku') = m.f431_codigo_barras
		WHERE   m.f431_codigo_barras IS NOT NULL
		  AND   p.f126_precio - JSON_VALUE(li.value, '$.price') > 0;

		-- genera el JSON final
		INSERT INTO @final (idDocumento, indicaParalelismo, descripcion, idOrden, json)
		SELECT 
				@idDocumento                                                                                   AS idDocumento,
				@indicaParalelismo                                                                             AS indicaParalelismo,
				@descripcion                                                                                   AS descripcion,
				@order                                                                                         AS idOrden,
				(
					SELECT
						[Pedidos]             = (SELECT * FROM #pedidos FOR JSON PATH),
						[MovtoPedidoscomercial] = (SELECT * FROM #movimientos FOR JSON PATH),
						[Descuentos]          = (SELECT [row] AS f431_nro_registro, amount AS f432_vlr_uni FROM @tmpDescuento FOR JSON PATH)
					FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
				)                                                                                              AS json;

		DELETE FROM @tmpDescuento;

		-- limpieza
		IF OBJECT_ID('tempdb..#descuentostemp') IS NOT NULL DROP TABLE #descuentostemp;
		IF OBJECT_ID('tempdb..#pedidos') IS NOT NULL DROP TABLE #pedidos;
		IF OBJECT_ID('tempdb..#movimientos') IS NOT NULL DROP TABLE #movimientos;
		IF OBJECT_ID('tempdb..#Shipping_lines') IS NOT NULL DROP TABLE #Shipping_lines;
		IF OBJECT_ID('tempdb..##tmp_PreciosErp') IS NOT NULL DROP TABLE ##tmp_PreciosErp;

		SET @counter = @counter + 1;
	END;
END TRY
BEGIN CATCH
	INSERT INTO @TmpError
	SELECT 1, 0, 0, ERROR_MESSAGE(), @order;
	GOTO Cleanup;
END CATCH

Cleanup:
BEGIN
	IF OBJECT_ID('tempdb..#descuentostemp') IS NOT NULL DROP TABLE #descuentostemp;
	IF OBJECT_ID('tempdb..#pedidos') IS NOT NULL DROP TABLE #pedidos;
	IF OBJECT_ID('tempdb..#movimientos') IS NOT NULL DROP TABLE #movimientos;
	IF OBJECT_ID('tempdb..#Shipping_lines') IS NOT NULL DROP TABLE #Shipping_lines;
	IF OBJECT_ID('tempdb..##tmp_PreciosErp') IS NOT NULL DROP TABLE ##tmp_PreciosErp;
	IF OBJECT_ID('tempdb..##tmp_OrdenesCreadas') IS NOT NULL DROP TABLE ##tmp_OrdenesCreadas;
	IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL DROP TABLE #ordenes;
END;

SELECT * FROM @final    AS final_json;
SELECT * FROM @TmpError AS errores;