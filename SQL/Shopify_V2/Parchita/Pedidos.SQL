/*  PARCHITA    -   PEDIDO_COMERCIAL_NUEVO
    -----------------------------------------------------------------------------------------
    Nombre del Script: PEDIDO_COMERCIAL_NUEVO.sql
    Descripción:
        Este procedimiento procesa pedidos comerciales nuevos provenientes de Shopify (Parchita),
        integrando información de órdenes, clientes, métodos de pago, descuentos y envíos.
    -----------------------------------------------------------------------------------------
*/
BEGIN TRY
	SET XACT_ABORT ON;
    /*
		*	Definición de tabla de resultados
	*/
	DECLARE @final	TABLE (
		idDocumento			INT,
		indicaParalelismo	BIT,
		descripcion 		VARCHAR(100),
		idOrden				VARCHAR(50),
		json 				VARCHAR(MAX)
	);

	/*
		*	Definición de información del conector
	*/
	DECLARE 
		@idDocumento		INT				=	197197,
		@indicaParalelismo	BIT				=	0,
		@descripcion		VARCHAR(100)	=	'PEDIDO_COMERCIAL_NUEVO';

--->================================================================================================================<---

	/*
		*	Configuración de ejecución del script
	*/
	DECLARE @batch_size		INT			=	25;                            -- Órdenes por petición (lote de 25)
    DECLARE @max_intentos	INT			=	3;                             -- Límite estricto de intentos (< no <=)
	DECLARE @fecha_inicio	DATETIME	=	DATEADD(DAY, -30, GETDATE());  -- Filtro de ordenes no más viejas a 30 días

	/*
		*	Origen de los datos del cliente/tercero
	*/
	DECLARE @client_origin_data	INT	=	4;

	DECLARE @path_customer	NVARCHAR(100)	=	'$.customer.default_address';
	DECLARE @path_billing	NVARCHAR(100)	=	'$.billing_address';
	DECLARE @path_shipping	NVARCHAR(100)	=	'$.shipping_address';

	/*
		*	Id motivo:
	*/
	DECLARE @id_motivo_items	NVARCHAR(3) =   '01',
            @id_motivo_giftcard	NVARCHAR(3) =   '05',
            @id_motivo_obsequio	NVARCHAR(3) =   '04';
	
	/*
		*	Ind Impto Asumido:
	*/
	DECLARE @ind_impto_asumido_items	INT	=   0,
            @ind_impto_asumido_flete	INT	=   0;

	/*
		*	Id Centro de Costos:
	*/
	DECLARE @id_ccostos_items	NVARCHAR(6) =   '020101',
            @id_ccostos_flete	NVARCHAR(6) =   '020103';

	/*
		*	Id Tipo Cliente Factura:
	*/
	DECLARE @id_tipo_cli_fact_addi			NVARCHAR(3) =   '004',
            @id_tipo_cli_fact_defecto		NVARCHAR(3) =   '001',
            @id_tipo_cli_fact_mercadopago	NVARCHAR(3) =   '007',
            @id_tipo_cli_fact_sistecredito	NVARCHAR(3) =   '003',
            @id_tipo_cli_fact_transferencia	NVARCHAR(3) =   '008',
            @id_tipo_cli_fact_wompi			NVARCHAR(3) =   '006',
			@id_tipo_cli_fact_gift_card		NVARCHAR(3)	=	'011';
	
	/*
		*	Id Vendedor:
	*/
	DECLARE @id_vendedor_defecto	NVARCHAR(10)	=	'43916731',
            @id_vendedor_manual		NVARCHAR(10)	=	'1039470748';

    /*
		*	Cliente ocasional cuando el cliente no tiene cédula
	*/
    DECLARE @id_cliente_ocasional   NVARCHAR(20)    =   '99999999';

	/*
		*	Referencia flete
	*/
	DECLARE @id_referencia_item_flete	NVARCHAR(20)	=	'0000715';

--->================================================================================================================<---

    /*
		*	Definición de la tabla de pedidos del ERP
	*/
	DECLARE @t430_cm_pv_docto TABLE (
		f430_referencia	NVARCHAR(100) PRIMARY KEY
	);

	/*
		*	Definición de la tabla de unidades de medida por extensiones
	*/
	DECLARE @unidades_de_medida_por_extensiones TABLE (
		f121_id_barras_principal	NVARCHAR(20),
		f122_id_unidad				NVARCHAR(4)
	);

--->================================================================================================================<---

    /*
        *   Obtener la cadena de conexión del ERP
    */
    DECLARE @conexion   NVARCHAR(MAX);
    DECLARE @base_datos NVARCHAR(MAX);

    SELECT TOP 1
        @conexion   =   cadena_conexion,
        @base_datos =   base_datos
    FROM [shopify-colombia-parchita].dbo.conexiones;

    /*
		*	Consulta a la tabla de pedidos del ERP
	*/
    INSERT INTO @t430_cm_pv_docto (f430_referencia)
	EXEC
    (
        '
        SELECT DISTINCT 
            f430_referencia
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT 
                    f430_referencia
                FROM ' + @base_datos + '.dbo.t430_cm_pv_docto
                WHERE 
                    f430_ind_estado	!=	9
                    AND 
                    f430_id_cia		=	1
            ''
        )
        '
    );

	INSERT INTO @unidades_de_medida_por_extensiones (f121_id_barras_principal, f122_id_unidad)
	EXEC('
		SELECT DISTINCT
			f121_id_barras_principal,
			f122_id_unidad
		FROM OPENROWSET(
			''SQLNCLI''
			, ''' + @conexion + '''
			, ''
				SELECT 
					f121_id_barras_principal	=	TRIM(f121_id_barras_principal),
					f122_id_unidad				=	TRIM(f122_id_unidad)
				FROM ' + @base_datos + '.dbo.t121_mc_items_extensiones AS ext
					INNER JOIN ' + @base_datos + '.dbo.t122_mc_items_unidades AS uni
						ON
							f122_rowid_item	=	f121_rowid_item 
			''
		)'
	);

--->================================================================================================================<---

    /*
        *   Actualizar a estado 3 pedidos ya existentes en ERP
    */
	UPDATE ord
    SET id_estado	=	3
    FROM [shopify-colombia-parchita].dbo.ordenes AS ord
        INNER JOIN @t430_cm_pv_docto
            ON f430_referencia = id_orden
    WHERE id_estado = 2;

	DECLARE @ordenes TABLE (
		id_seq      INT IDENTITY(1,1) PRIMARY KEY,
		id_orden	NVARCHAR(20),
		orden_obj	NVARCHAR(MAX)
	);

	/*
		*	Obtener máximo 25 órdenes pendientes en estado 2, no mayores a 30 días,
		*	excluyendo órdenes POS y ordenando por ID DESC.
	*/
	INSERT INTO @ordenes (id_orden, orden_obj)
	SELECT TOP (@batch_size)
		id_orden,
		orden_obj
	FROM [shopify-colombia-parchita].dbo.ordenes 
		LEFT JOIN @t430_cm_pv_docto
            ON f430_referencia = id_orden
	WHERE
		id_estado	=	2 
		AND 
		intentos	<=	@max_intentos
		AND 
		f430_referencia IS NULL
		AND
		fecha_creacion >= @fecha_inicio
	ORDER BY id DESC;

--->================================================================================================================<---

	DECLARE @pedidos TABLE (
		f430_id_fecha				NVARCHAR(8),
		f430_fecha_entrega			NVARCHAR(8),
		f430_referencia				NVARCHAR(50),
		f430_notas					NVARCHAR(50),
		f430_id_tercero_vendedor	NVARCHAR(10),
		f430_id_tercero_fact		NVARCHAR(15),
		f430_id_tercero_rem			NVARCHAR(15),
		f430_id_tipo_cli_fact		NVARCHAR(3)
	);

    DECLARE @Movto_Pedidos_comercial TABLE (
        id                      NVARCHAR(20),
		f431_nro_registro		INT,
		f431_precio_unitario	DECIMAL(18,2),
		f431_referencia_item	NVARCHAR(50),
		f431_codigo_barras		NVARCHAR(20),
		f431_fecha_entrega		NVARCHAR(8),
		f431_cant_pedida_base	DECIMAL(18,2),
		f431_notas				NVARCHAR(255),
		f431_id_motivo			NVARCHAR(2),
		f431_ind_impto_asumido	INT,
		f431_ind_obsequio		INT,
		f431_id_unidad_medida	NVARCHAR(4),
		f431_id_ccosto_movto	NVARCHAR(15)
    );

	DECLARE @Descuentos	TABLE (
		f431_nro_registro	NVARCHAR(10),
        f432_vlr_uni        NVARCHAR(20)
	);
	
--->================================================================================================================<---

	DECLARE @transacciones_orden	TABLE
	(
		id		NVARCHAR(100),
		gateway	NVARCHAR(30),
		status	NVARCHAR(30),
		amount	NVARCHAR(30)
	);

    DECLARE @line_items TABLE
    (
        id                      BIGINT,
        price                   DECIMAL(18,2),
        quantity                INT,
        sku                     NVARCHAR(200),
        variant_title           NVARCHAR(200),
        variant_id           	BIGINT,
		gift_card				BIT,
        discount_amount         DECIMAL(18,2)
    );

	DECLARE @shipping_lines TABLE (
		price	DECIMAL(18,2)
	);

--->================================================================================================================<---

	DECLARE @order		NVARCHAR(30);
	DECLARE @json		NVARCHAR(MAX)	= 	'';
	DECLARE @total		INT	=	(SELECT COUNT(*) FROM @ordenes);
	DECLARE @counter	INT	=	1;

	DECLARE	@current_date				VARCHAR(8)		=	FORMAT(GETDATE(), 'yyyyMMdd');

	WHILE @counter <= @total
	BEGIN
		BEGIN TRY
			SELECT 
				@order	=	id_orden,
				@json	=	orden_obj
			FROM @ordenes
			WHERE id_seq = @counter;
            
            SET @order	=	JSON_VALUE(@json, '$.name');

			DECLARE @client_base_path	NVARCHAR(100)	=
				CASE @client_origin_data
					WHEN 1 THEN @path_customer
					WHEN 2 THEN @path_billing
					WHEN 3 THEN
						CASE WHEN NULLIF(TRIM(JSON_VALUE(@json, @path_customer + '.company')), '') IS NOT NULL THEN @path_customer ELSE @path_billing END
					WHEN 4 THEN
						CASE WHEN NULLIF(TRIM(JSON_VALUE(@json, @path_billing + '.company')), '') IS NOT NULL THEN @path_billing ELSE @path_customer END
				END;

			DECLARE @id_cliente NVARCHAR(100) =
				LEFT(REPLACE(NULLIF(TRIM(JSON_VALUE(@json, @client_base_path + '.company')), ''), '.', ''), 15);

            SET @id_cliente = dbo.fn_KeepNumbersHyphen(@id_cliente);

			DECLARE @id_vendedor	NVARCHAR(10)	=	NULL;

			SELECT TOP 1 
				@id_vendedor	= CASE WHEN [value] = 'manual' THEN @id_vendedor_manual ELSE @id_vendedor_defecto END
			FROM OPENJSON(@json, '$.payment_gateway_names') AS payment
			WHERE [value] != 'gift_card'
			ORDER BY [key] DESC;

			IF (@id_vendedor IS NULL) 
				SET @id_vendedor = @id_vendedor_defecto;

			/*
				*	Obtener las transacciones de la orden
			*/
			INSERT INTO @transacciones_orden (id, gateway, [status], amount)
			SELECT DISTINCT
				id			=	JSON_VALUE(transaccion_obj, '$.id'),
				gateway		=	JSON_VALUE(transaccion_obj, '$.gateway'),
				[status]	=	JSON_VALUE(transaccion_obj, '$.status'),
				amount		=	JSON_VALUE(transaccion_obj, '$.amount')
			FROM transacciones_ordenes AS [to]
			WHERE JSON_VALUE(@json, '$.id') = [to].id_orden;

			DECLARE	@notas				NVARCHAR(MAX)	=	NULL;
			DECLARE	@id_tipo_cli_fact	NVARCHAR(MAX)	=	NULL;
 
			/*	Validar métodos de pago	*/
			SELECT
				@notas				=	gateway,
				@id_tipo_cli_fact	=
					CASE 
						WHEN gateway = 'manual' THEN
							COALESCE(
								(
									SELECT TOP 1 
										CASE 
											WHEN split_value LIKE '%Sistecredito%'	THEN @id_tipo_cli_fact_sistecredito
											WHEN split_value LIKE '%Addi%'			THEN @id_tipo_cli_fact_addi
											WHEN split_value LIKE '%Wompi%'			THEN @id_tipo_cli_fact_wompi
											WHEN split_value LIKE '%Mercado Pago%'	THEN @id_tipo_cli_fact_mercadopago
											WHEN split_value LIKE '%transferencia%'	THEN @id_tipo_cli_fact_transferencia
										END
									FROM STRING_SPLIT(JSON_VALUE(@json, '$.tags'), ',') 
										CROSS APPLY (SELECT LTRIM(RTRIM(value)) AS split_value) AS clean_values
									WHERE split_value LIKE 'Manual%' AND split_value LIKE '%[^ ]%'
									ORDER BY 
										CASE
											WHEN split_value LIKE '%Sistecredito%'	THEN 1
											WHEN split_value LIKE '%Addi%'			THEN 2
											WHEN split_value LIKE '%Wompi%'			THEN 3
											WHEN split_value LIKE '%Mercado Pago%'	THEN 4
											WHEN split_value LIKE '%transferencia%'	THEN 5
											ELSE 6
										END
								),
								@id_tipo_cli_fact_transferencia
							)
						ELSE
							CASE 
								WHEN gateway = 'Sistecredito' THEN @id_tipo_cli_fact_sistecredito
								WHEN LOWER(gateway) LIKE '%addi%' THEN @id_tipo_cli_fact_addi
								WHEN gateway = 'Wompi' THEN @id_tipo_cli_fact_wompi
								WHEN LOWER(gateway) LIKE '%mercado pago%' OR LOWER(gateway) LIKE '%mercadopago%' THEN @id_tipo_cli_fact_mercadopago
							END
					END
			FROM @transacciones_orden AS [to]
			WHERE [status] != 'failure' AND gateway != 'gift_card';
			
			IF @notas IS NULL OR @id_tipo_cli_fact IS NULL
			BEGIN
				SELECT
					@notas				=	gateway,
					@id_tipo_cli_fact	=	@id_tipo_cli_fact_gift_card
				FROM @transacciones_orden AS [to]
				WHERE status != 'failure' AND gateway = 'gift_card';
				
				IF @notas IS NULL OR @id_tipo_cli_fact IS NULL
				BEGIN
					SELECT
						@notas				=	gateway,
						@id_tipo_cli_fact	=	@id_tipo_cli_fact_gift_card
					FROM @transacciones_orden AS [to]
					WHERE [status] != 'failure';
				END
			END;

--->================================================================================================================<---

			INSERT INTO @pedidos (
				f430_id_fecha, f430_fecha_entrega, f430_referencia, f430_notas,
				f430_id_tercero_vendedor, f430_id_tercero_fact, f430_id_tercero_rem, f430_id_tipo_cli_fact
			)
			SELECT 
				f430_id_fecha				=	@current_date,
				f430_fecha_entrega			=	@current_date,
				f430_referencia				=	@order,
				f430_notas					=	@order,
				f430_id_tercero_vendedor	=	@id_vendedor,
				f430_id_tercero_fact		=	LEFT(ISNULL(NULLIF(TRIM(@id_cliente), ''), @id_cliente_ocasional), 15),
				f430_id_tercero_rem			=	LEFT(ISNULL(NULLIF(TRIM(@id_cliente), ''), @id_cliente_ocasional), 15),
				f430_id_tipo_cli_fact		=	ISNULL(@id_tipo_cli_fact, @id_tipo_cli_fact_defecto);

--->================================================================================================================<---

            INSERT INTO @line_items
            SELECT
                id                      =   CAST(JSON_VALUE(LI.value, '$.id') AS BIGINT),
                price                   =   CAST(JSON_VALUE(LI.value, '$.price_set.presentment_money.amount') AS DECIMAL(18,2)),
                quantity                =   CAST(JSON_VALUE(LI.value, '$.quantity') AS INT),
                sku                     =   
					CASE 
						WHEN CAST(JSON_VALUE(LI.value, '$.gift_card') AS BIT) = 0 THEN JSON_VALUE(LI.value, '$.sku')
						ELSE
							CASE CAST(JSON_VALUE(LI.value, '$.price_set.presentment_money.amount') AS DECIMAL(18,2))
								WHEN 50000  THEN '770981450300001'
								WHEN 100000 THEN '770981450300002'
								WHEN 150000 THEN '770981450300003'
								WHEN 200000 THEN '770981450300004'
								WHEN 250000 THEN '770981450300005'
								WHEN 300000 THEN '770981450300006'
								ELSE 'sku_no_valido'
							END
					END,
                variant_title           =   JSON_VALUE(LI.value, '$.variant_title'),
                variant_id				=   CAST(JSON_VALUE(LI.value, '$.variant_id') AS BIGINT),
                gift_card				=   CAST(JSON_VALUE(LI.value, '$.gift_card') AS BIT),
                discount_amount         =
                    CAST(
                        (
							SELECT SUM(CAST(JSON_VALUE(DA.value, '$.amount') AS DECIMAL(10,4))) / CAST(JSON_VALUE(LI.value, '$.quantity') AS INT)
                        	FROM OPENJSON(LI.VALUE, '$.discount_allocations') AS DA
						)
                    AS DECIMAL(18,2))
            FROM OPENJSON(@json,'$.line_items') AS LI;

			INSERT INTO @movto_Pedidos_Comercial (
				id, f431_nro_registro, f431_precio_unitario, f431_referencia_item, f431_codigo_barras,
				f431_fecha_entrega, f431_cant_pedida_base, f431_notas, f431_id_motivo, f431_ind_impto_asumido,
				f431_ind_obsequio, f431_id_unidad_medida, f431_id_ccosto_movto
			)
			SELECT
				id						=	LI.id,
				f431_nro_registro		=	ROW_NUMBER() OVER (ORDER BY LI.id),
				f431_precio_unitario	=	CASE WHEN LI.price > 0 THEN LI.price ELSE 1 END,
				f431_referencia_item	=	'',
				f431_codigo_barras		=	ISNULL(LI.sku, 'sku_no_valido'),
				f431_fecha_entrega		=	@current_date,
				f431_cant_pedida_base	=	LI.quantity,
				f431_notas				=	@notas,
				f431_id_motivo			=
					CASE
						WHEN li.gift_card = 1 THEN @id_motivo_giftcard
						WHEN LI.gift_card = 0 THEN
							CASE
								WHEN LI.discount_amount IS NULL OR LI.discount_amount = 0 THEN @id_motivo_items
								WHEN LI.discount_amount > 0 THEN
									CASE LI.price - LI.discount_amount WHEN 0 THEN @id_motivo_obsequio ELSE @id_motivo_items END
							END
					END,
				f431_ind_impto_asumido	=	@ind_impto_asumido_items,
				f431_ind_obsequio		=
					CASE
						WHEN LI.discount_amount IS NULL OR LI.discount_amount = 0 THEN 0
						WHEN LI.discount_amount > 0 THEN
							CASE LI.price - LI.discount_amount WHEN 0 THEN 1 ELSE 0 END
					END,
				f431_id_unidad_medida	=	ISNULL(u.f122_id_unidad, 'UND'),
				f431_id_ccosto_movto	=	@id_ccostos_items
			FROM @line_items AS LI
				LEFT JOIN @unidades_de_medida_por_extensiones AS u
					ON u.f121_id_barras_principal = LI.sku
			ORDER BY LI.id;
	
			/*	Líneas de envío	*/
			INSERT INTO @shipping_lines
			SELECT price = SUM(CAST(JSON_VALUE(sl.value, '$.price') AS DECIMAL(18,2)))
			FROM OPENJSON(@json,'$.shipping_lines') AS SL
			WHERE JSON_VALUE(sl.value, '$.is_removed') = 'false'
			GROUP BY JSON_VALUE(sl.value, '$.price');
		
			INSERT INTO @movto_Pedidos_Comercial (
				id, f431_nro_registro, f431_precio_unitario, f431_referencia_item, f431_codigo_barras,
				f431_fecha_entrega, f431_cant_pedida_base, f431_notas, f431_id_motivo, f431_ind_impto_asumido,
				f431_ind_obsequio, f431_id_unidad_medida, f431_id_ccosto_movto
			)
			SELECT
				id						=	'',
				f31_nro_registro		=	0,
				f431_precio_unitario	=	price,
				f431_referencia_item	=	@id_referencia_item_flete,
				f431_codigo_barras	 	=	'',
				f431_fecha_entrega		=	@current_date,
				f431_cant_pedida_base	=	1,
				f431_notas				=	'Flete nacional',
				f431_id_motivo			=	@id_motivo_items,
				f431_ind_impto_asumido	=	0,
				f431_ind_obsequio		=	0,
				f431_id_unidad_medida	=	'UND',
				f431_id_ccosto_movto	=	@id_ccostos_flete
			FROM @shipping_lines AS sl
			WHERE price > 0;
	
			INSERT INTO @Descuentos
			SELECT 
				f431_nro_registro		=	MPC.f431_nro_registro,
				f432_vlr_uni			=	LI.discount_amount
			FROM @line_items AS LI
				INNER JOIN @movto_Pedidos_Comercial AS MPC
					ON MPC.id = LI.id
			WHERE LI.discount_amount > 0;

			INSERT INTO @final(idDocumento, indicaParalelismo, descripcion, idOrden, json)
			SELECT 
				@idDocumento,
				@indicaParalelismo,
				@descripcion,
				idOrden	=	@order,
				(
					SELECT
						[Pedidos] = (SELECT * FROM @pedidos FOR JSON PATH),
						[Movto Pedidos comercial] = (SELECT * FROM @movto_Pedidos_Comercial FOR JSON PATH),
						[Descuentos] = (SELECT * FROM @Descuentos FOR JSON PATH)
					FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
				);
		END TRY
        BEGIN CATCH
            -- Incrementa número de intentos y marca estado 99 si supera max_intentos para evitar bloqueos infinitos
            UPDATE [shopify-colombia-parchita].dbo.ordenes
            SET 
				intentos	=	intentos + 1,
				id_estado   =   CASE WHEN intentos + 1 > @max_intentos THEN 99 ELSE id_estado END
            WHERE
                id_orden	=	@order
				AND id_estado = 2;
        END CATCH
			
		DELETE @pedidos;
		DELETE @movto_Pedidos_Comercial;
		DELETE @Descuentos;
		DELETE @shipping_lines;
		DELETE @transacciones_orden;
		DELETE @line_items;

		SET @counter = @counter + 1;
	END
END TRY
BEGIN CATCH
	SELECT
		indicaError			=	CAST(1 AS BIT),
		descripcionError	=	CONCAT('Error: ', @order + ' ', ERROR_MESSAGE());
END CATCH;

SELECT * FROM @final AS final_json;