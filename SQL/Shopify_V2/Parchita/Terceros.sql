/*	CLIENTES_IMP-RTE	-	PARCHITA	*/
BEGIN TRY
	/*
		*	Definición de tabla de resultados
	*/
	DECLARE @final	TABLE (
		idDocumento			INT,
		indicaParalelismo	BIT,
		descripcion			VARCHAR(50),
		idOrden				VARCHAR(50),
		json				VARCHAR(MAX)
	);

	/*
		*	Definición de información del conector: ID del documento, descripción y si indica paralelismo:
	*/
	DECLARE	@idDocumento			INT			=	196608,
			@descripcionConector	VARCHAR(50)	=	'CLIENTES_IMP-RTE',
			@indicaParalelismo		BIT			=	1;

--->================================================================================================================<---

	/*
		*	Configuración de ejecución del script
	*/
	DECLARE @batch_size		INT			=   25;	                         -- Órdenes por petición (lote de 25)
	DECLARE @max_intentos	INT			=	3;                           -- Límite estricto de intentos (< no <=)
	DECLARE @fecha_inicio	DATETIME	=	DATEADD(DAY, -30, GETDATE());-- Filtro de ordenes no más viejas a 30 días

	/*
		*	Origen de los datos del cliente/tercero
		*		1 = Desde la sección Customer
		*		2 = Desde la sección Billing Address
		*		3 = Desde la sección Customer y si no existe, desde Billing Address
		*		4 = Desde la sección Billing Address y si no existe, desde Customer
	*/
	DECLARE @client_origin_data	INT	=	4;

	DECLARE @path_customer	NVARCHAR(100)	=	'$.customer.default_address';
	DECLARE @path_billing	NVARCHAR(100)	=	'$.billing_address';
	DECLARE @path_shipping	NVARCHAR(100)	=	'$.shipping_address';

	/*
		*	Procesar clientes/terceros sin ID
		*		0 = No procesar clientes/terceros sin ID, incrementar el contador de intentos
		*		1 = Procesar clientes/terceros sin ID, cambiar el estado de la orden de 1 a 2 y colocar intentos a 0
	*/
	DECLARE @process_client_without_id	BIT	=	1;

	DECLARE @id_pais_defecto	NVARCHAR(3)	=	'169',
			@id_dpto_defecto	NVARCHAR(3)	=	'05',
			@id_ciudad_defecto	NVARCHAR(3)	=	'001';
	
	/*
		*	Definición de variables para la obtención de la ubicación desde Shopify
	*/
	DECLARE @location_origin_data	INT	=	4;

	/*
		*	Definición de variables para la asignación del vendedor
	*/
	DECLARE @id_vendedor_defecto	NVARCHAR(4) = '033';
	DECLARE @id_vendedor_manual		NVARCHAR(4) = '034';

	/*
		*	Id Tipo Cliente
	*/
	DECLARE @id_tipo_cli_addi			NVARCHAR(3) =   '004',
            @id_tipo_cli_defecto		NVARCHAR(3) =   '001',
            @id_tipo_cli_mercadopago	NVARCHAR(3) =   '007',
            @id_tipo_cli_sistecredito	NVARCHAR(3) =   '003',
            @id_tipo_cli_transferencia	NVARCHAR(3) =   '008',
            @id_tipo_cli_wompi			NVARCHAR(3) =   '006',
			@id_tipo_cli_gift_card		NVARCHAR(3)	=	'011';

--->================================================================================================================<---

	/*
		*	Tabla de terceros empleados
	*/
	DECLARE @terceros_empleados	TABLE
	(
		f200_id		NVARCHAR(100) PRIMARY KEY
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
		*	Obtener las cédulas de los terceros empleados
	*/
	INSERT INTO @terceros_empleados
	EXEC
    ('
        SELECT DISTINCT 
            f200_id
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT 
                    f200_id
                FROM ' + @base_datos + '.dbo.t200_mm_terceros
                WHERE 
                    f200_ind_empleado	=	1
            ''
        )
	');

--->================================================================================================================<---

	/*
		*	Definición de la sección de terceros del conector
	*/
	DECLARE @terceros	TABLE (
		F200_ID					NVARCHAR(15),
		F200_NIT				NVARCHAR(25),
		F200_RAZON_SOCIAL		NVARCHAR(100),
		F200_APELLIDO1			NVARCHAR(29),
		F200_APELLIDO2			NVARCHAR(29),
		F200_NOMBRES			NVARCHAR(40),
		F015_CONTACTO			NVARCHAR(50),
		F015_DIRECCION1			NVARCHAR(40),
		F015_DIRECCION2			NVARCHAR(40),
		F015_ID_PAIS			NVARCHAR(3),
		F015_ID_DEPTO			NVARCHAR(2),
		F015_ID_CIUDAD			NVARCHAR(3),
		F015_TELEFONO			NVARCHAR(20),
		F015_EMAIL				NVARCHAR(255),
		F200_FECHA_NACIMIENTO	NVARCHAR(8),
		F015_CELULAR			NVARCHAR(50)
	);

	/*
		*	Definición de la sección de clientes del conector
	*/
	DECLARE @cliente	TABLE (
		F015_CONTACTO				NVARCHAR(50),
		F015_DIRECCION1				NVARCHAR(40),
		F015_DIRECCION2				NVARCHAR(40),
		F015_ID_PAIS				NVARCHAR(3),
		F015_ID_DEPTO				NVARCHAR(2),
		F015_ID_CIUDAD				NVARCHAR(3),
		F015_TELEFONO				NVARCHAR(20),
		F015_EMAIL					NVARCHAR(255),
		F201_FECHA_INGRESO			NVARCHAR(8),
		f015_celular				NVARCHAR(50),
		F201_ID_TERCERO				NVARCHAR(15),
		F201_DESCRIPCION_SUCURSAL	NVARCHAR(40),
		F201_ID_VENDEDOR			NVARCHAR(4),
		F201_ID_TIPO_CLI			NVARCHAR(4)
	);

	/*
		*	Definición de la sección de impuestos y retenciones del conector
	*/
	DECLARE @Imptos_y_Reten	TABLE (
		F_ID_TERCERO		NVARCHAR(15)
	);
	
--->================================================================================================================<---

	DECLARE @transacciones_orden	TABLE
	(
		id		NVARCHAR(100),
		gateway	NVARCHAR(30),
		status	NVARCHAR(30),
		amount	NVARCHAR(30)
	);

--->================================================================================================================<---

	DECLARE @ordenes TABLE (
		id_seq      INT IDENTITY(1,1) PRIMARY KEY,
		id_orden	NVARCHAR(20),
		orden_obj	NVARCHAR(MAX)
	);

	/*
		*	Obtener máximo 25 órdenes pendientes (id_estado = 1), no mayores a 30 días,
		*	excluyendo órdenes POS y ordenando por ID DESC.
	*/
	INSERT INTO @ordenes (id_orden, orden_obj)
	SELECT TOP (@batch_size)
		id_orden, 
		orden_obj
	FROM [shopify-colombia-parchita].dbo.ordenes 
	WHERE 
		id_estado	=	1
		AND
		intentos	<=	@max_intentos
		AND
		fecha_creacion	>= @fecha_inicio
	ORDER BY id DESC;

--->================================================================================================================<---

	/*
		*	Definición de variables para el procesamiento iterativo
	*/
	DECLARE @order		NVARCHAR(30);
	DECLARE @json		NVARCHAR(MAX)	= 	'';
	DECLARE @total		INT	=	(SELECT COUNT(*) FROM @ordenes);
	DECLARE @counter	INT	=	1;

	WHILE @counter <= @total
	BEGIN
		BEGIN TRY
			/*
				*	Obtener la orden actual de forma determinística por id_seq
			*/
			SELECT 
				@order	=	id_orden,
				@json	=	orden_obj
			FROM @ordenes
			WHERE id_seq = @counter;
			
			DECLARE @location_base_path NVARCHAR(100)	=
				CASE 
					WHEN	@location_origin_data	=	1 THEN	@path_customer
					WHEN	@location_origin_data	=	2 THEN	@path_billing
					WHEN	@location_origin_data	=	3 THEN	@path_shipping
					WHEN	@location_origin_data	=	4 THEN
						CASE WHEN JSON_VALUE(@json, @path_customer + '.city') IS NOT NULL THEN @path_customer ELSE @path_billing END
					WHEN	@location_origin_data	=	5 THEN
						CASE WHEN JSON_VALUE(@json, @path_billing + '.city') IS NOT NULL THEN @path_billing ELSE @path_customer END
					ELSE ''
				END;

			DECLARE @pais_shopify NVARCHAR(100) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, @location_base_path + '.country')));
			DECLARE @dpto_shopify NVARCHAR(100) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, @location_base_path + '.province')));
			DECLARE @ciudad_shopify NVARCHAR(100) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, @location_base_path + '.city')));

			DECLARE @direccion_1_shopify NVARCHAR(255) = UPPER(JSON_VALUE(@json, @location_base_path + '.address1'));
			DECLARE @direccion_2_shopify NVARCHAR(255) = UPPER(JSON_VALUE(@json, @location_base_path + '.address2'));

			DECLARE @id_pais_erp	NVARCHAR(3);
			DECLARE @id_dptos_erp	NVARCHAR(2);
			DECLARE @id_ciudad_erp	NVARCHAR(3);

            SELECT
				@id_pais_erp	=	id_pais_erp,
				@id_dptos_erp	=	id_dptos_erp,
				@id_ciudad_erp	=	id_ciudad_erp
            FROM dbo.fn_GetLocationIds(
                @pais_shopify,
                @dpto_shopify,
                @ciudad_shopify,
                @id_pais_defecto,
                @id_dpto_defecto,
                @id_ciudad_defecto
            );

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

			/*
				*	Validar si es un tercero empleado, si es así se omite la creación de tercero y pasa a estado 2
			*/
			IF EXISTS (SELECT 1 FROM @terceros_empleados WHERE f200_id = @id_cliente)
			BEGIN
				UPDATE [shopify-colombia-parchita].dbo.ordenes
				SET id_estado = 2
				WHERE id_orden = @order AND id_estado = 1;

				SET @counter = @counter + 1;
				CONTINUE;
			END
			
			/*
				*	Validar identificación del cliente
			*/
			IF (@id_cliente IS NULL OR dbo.fn_KeepNumbersHyphen(@id_cliente) = '')
			BEGIN
				UPDATE [shopify-colombia-parchita].dbo.ordenes
				SET 
					intentos	=	CASE WHEN @process_client_without_id = 0 THEN intentos + 1 ELSE 0 END,
					id_estado	=	CASE 
										WHEN @process_client_without_id = 1 THEN 2 
										WHEN intentos + 1 > @max_intentos THEN 99 
										ELSE id_estado 
									END
				WHERE id_orden = @order AND id_estado = 1;

				SET @counter = @counter + 1;
				CONTINUE;
			END;

			DECLARE @razon_social NVARCHAR(100) = UPPER(JSON_VALUE(@json, @client_base_path  + '.name'));
			DECLARE @nombre_cliente NVARCHAR(40) = UPPER(JSON_VALUE(@json, @client_base_path + '.first_name'));
			DECLARE @apellidos_cliente NVARCHAR(80) = UPPER(JSON_VALUE(@json, @client_base_path + '.last_name'));

			DECLARE @apellido_1_cliente	NVARCHAR(80) = LEFT(@apellidos_cliente, CHARINDEX(' ', @apellidos_cliente + ' ') - 1);
			DECLARE @apellido_2_cliente NVARCHAR(80) = LTRIM(SUBSTRING(@apellidos_cliente, CHARINDEX(' ', @apellidos_cliente + ' '), LEN(@apellidos_cliente)));

			DECLARE @telefono_cliente	NVARCHAR(50) = REPLACE(JSON_VALUE(@json, @path_customer + '.phone'), '+57', '');
			DECLARE @email_cliente		NVARCHAR(255) = JSON_VALUE(@json, '$.customer.email');
			DECLARE @fecha_creacion		NVARCHAR(8) = REPLACE(CONVERT(VARCHAR(10), CAST(JSON_VALUE(@json, '$.customer.created_at') AS DATE)), '-', '');

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
						
			DECLARE	@id_tipo_cli NVARCHAR(MAX) = NULL;
 
			/*	Validar métodos de pago	*/
			SELECT
				@id_tipo_cli	=
					CASE 
						WHEN gateway = 'manual' THEN
							COALESCE(
								(
									SELECT TOP 1 
										CASE 
											WHEN split_value LIKE '%Sistecredito%'	THEN @id_tipo_cli_sistecredito
											WHEN split_value LIKE '%Addi%'			THEN @id_tipo_cli_addi
											WHEN split_value LIKE '%Wompi%'			THEN @id_tipo_cli_wompi
											WHEN split_value LIKE '%Mercado Pago%'	THEN @id_tipo_cli_mercadopago
											WHEN split_value LIKE '%transferencia%'	THEN @id_tipo_cli_transferencia
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
								@id_tipo_cli_transferencia
							)
						ELSE
							CASE 
								WHEN gateway = 'Sistecredito' THEN @id_tipo_cli_sistecredito
								WHEN LOWER(gateway) LIKE '%addi%' THEN @id_tipo_cli_addi
								WHEN gateway = 'Wompi' THEN @id_tipo_cli_wompi
								WHEN LOWER(gateway) LIKE '%mercado pago%' OR LOWER(gateway) LIKE '%mercadopago%' THEN @id_tipo_cli_mercadopago
							END
					END
			FROM @transacciones_orden AS [to]
			WHERE [status] != 'failure' AND gateway != 'gift_card';
			
			IF @id_tipo_cli IS NULL
			BEGIN
				SELECT @id_tipo_cli = @id_tipo_cli_gift_card
				FROM @transacciones_orden AS [to]
				WHERE status != 'failure' AND gateway = 'gift_card';
				
				IF @id_tipo_cli IS NULL
				BEGIN
					SELECT @id_tipo_cli = @id_tipo_cli_gift_card
					FROM @transacciones_orden AS [to]
					WHERE [status] != 'failure';
				END
			END;

			DECLARE	@id_vendedor NVARCHAR(3) = @id_vendedor_defecto;

			SELECT TOP 1 
				@id_vendedor = CASE WHEN [value] = 'manual' THEN @id_vendedor_manual ELSE @id_vendedor_defecto END
			FROM OPENJSON(@json, '$.payment_gateway_names')
			WHERE [value] != 'gift_card'
			ORDER BY [key] DESC;

			/*
				*	Sección de terceros del conector
			*/
			INSERT INTO @terceros (
				F200_ID, F200_NIT, F200_RAZON_SOCIAL, F200_APELLIDO1, F200_APELLIDO2, F200_NOMBRES,
				F015_CONTACTO, F015_DIRECCION1, F015_DIRECCION2, F015_ID_PAIS, F015_ID_DEPTO,
				F015_ID_CIUDAD, F015_TELEFONO, F015_EMAIL, F200_FECHA_NACIMIENTO, F015_CELULAR
			)
			SELECT
				F200_ID					=	@id_cliente,
				F200_NIT				=	@id_cliente,
				F200_RAZON_SOCIAL		=	LEFT(@razon_social, 100),
				F200_APELLIDO1			=	LEFT(@apellido_1_cliente, 29),
				F200_APELLIDO2			=	LEFT(@apellido_2_cliente, 29),
				F200_NOMBRES			=	LEFT(@nombre_cliente, 40),
				F015_CONTACTO			=	LEFT(@nombre_cliente, 50),
				F015_DIRECCION1			=	LEFT(@direccion_1_shopify, 40),
				F015_DIRECCION2			=	LEFT(@direccion_2_shopify, 40),
				F015_ID_PAIS			=	LEFT(@id_pais_erp, 3),
				F015_ID_DEPTO			=	LEFT(@id_dptos_erp, 2),
				F015_ID_CIUDAD			=	LEFT(@id_ciudad_erp, 3),
				F015_TELEFONO			=	LEFT(@telefono_cliente, 20),
				F015_EMAIL				=	@email_cliente,
				F200_FECHA_NACIMIENTO	=	@fecha_creacion,
				F015_CELULAR			=	LEFT(@telefono_cliente, 50);

			/*
				*	Sección de clientes del conector
			*/
			INSERT INTO @cliente (
				F015_CONTACTO, F015_DIRECCION1, F015_DIRECCION2, F015_ID_PAIS, F015_ID_DEPTO,
				F015_ID_CIUDAD, F015_TELEFONO, F015_EMAIL, F201_FECHA_INGRESO, f015_celular,
				F201_ID_TERCERO, F201_DESCRIPCION_SUCURSAL, F201_ID_VENDEDOR, F201_ID_TIPO_CLI
			)
			SELECT
				F015_CONTACTO				=	LEFT(@razon_social, 50),
				F015_DIRECCION1				=	LEFT(@direccion_1_shopify, 40),
				F015_DIRECCION2				=	LEFT(@direccion_2_shopify, 40),
				F015_ID_PAIS				=	LEFT(@id_pais_erp, 3),
				F015_ID_DEPTO				=	LEFT(@id_dptos_erp, 2),
				F015_ID_CIUDAD				=	LEFT(@id_ciudad_erp, 3),
				F015_TELEFONO				=	LEFT(@telefono_cliente, 20),
				F015_EMAIL					=	LEFT(@email_cliente, 255),
				F201_FECHA_INGRESO			=	@fecha_creacion,
				f015_celular				=	LEFT(@telefono_cliente, 50),
				F201_ID_TERCERO				=	@id_cliente,
				F201_DESCRIPCION_SUCURSAL	=	LEFT(@razon_social, 40),
				F201_ID_VENDEDOR			=	@id_vendedor,
				F201_ID_TIPO_CLI			=	@id_tipo_cli;

			INSERT INTO @Imptos_y_Reten (F_ID_TERCERO)
			SELECT F_ID_TERCERO = @id_cliente;

			INSERT INTO @final(idDocumento, descripcion, indicaParalelismo, idOrden, json)
			SELECT 
				@idDocumento,
				@descripcionConector,
				@indicaParalelismo,
				@order AS idOrden,
				(
					SELECT
						[Terceros] = (SELECT * FROM @terceros FOR JSON PATH, INCLUDE_NULL_VALUES),
						[Clientes] = (SELECT * FROM @cliente FOR JSON PATH, INCLUDE_NULL_VALUES),
						[Imptos y Reten] = (SELECT * FROM @Imptos_y_Reten FOR JSON PATH, INCLUDE_NULL_VALUES)
					FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
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
				AND id_estado = 1;
		END CATCH;

		SET @counter = @counter + 1;
		DELETE @terceros;
		DELETE @cliente;
		DELETE @Imptos_y_Reten;
		DELETE @transacciones_orden;
	END

    SELECT * FROM @final AS final_json;
END TRY
BEGIN CATCH
    SELECT
		indicaError         =   CAST(1 AS BIT), 
        descripcionError    =   CONCAT('Error: ', ERROR_MESSAGE()),
        ErrorNumber         =   ERROR_NUMBER(),
        ErrorSeverity       =   ERROR_SEVERITY(),
        ErrorState          =   ERROR_STATE(),
        ErrorProcedure      =   ERROR_PROCEDURE(),
        ErrorLine           =   ERROR_LINE(),
        ErrorMessage        =   ERROR_MESSAGE();
END CATCH;