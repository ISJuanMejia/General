
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
		*		ID del documento: Consultar en Connekta el Id del Conector.
		*		Descripción: Nombre del conector
		*		Indica paralelismo: 1 = Sí, 0 = No, dependiendo si el conector soporta múltiples hilos de ejecución.
	*/
	DECLARE	@idDocumento			INT			=	'240654',
			@descripcionConector	VARCHAR(50)	=	'Ecommerce_Terceros_Clientes',
			@indicaParalelismo		BIT			=	1;

--->================================================================================================================<---

	/*
		*	Configuración de ejecución del script
	*/
	DECLARE @batch_size	INT	=   25;	--	*	Cuantas órdenes se traen por petición

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
	DECLARE @process_client_without_id	BIT	=	0;

	/*
		*	Tipo de identificación:
		*		C	->	Cédula
		*		N	->	NIT
	*/
	DECLARE @id_tipo_ident_defecto		NVARCHAR(1)	=	'C';

	/*
		*	Tipo de tercero:
		*		0	->	Sin identificación
		*		1	->	Persona natural
		*		2	->	Persona juridica
	*/
	DECLARE @ind_tipo_tercero_defecto	NVARCHAR(1)	=	'1';

	/*
		TODO -> Configurar según el caso, validar según reglas del cliente, eliminar comentarios cuando finalice configuración
		*	Id tipo de cliente:
		*		1	->	id_cond_pago Wompi
		*		2	->	id_cond_pago Addi Payment
	*/
	DECLARE @id_cond_pago_wompi			NVARCHAR(4) =   'WO+',
            @id_cond_pago_addi			NVARCHAR(4) =   'ADD',
            @id_cond_pago_bold			NVARCHAR(4) =   'BO+',
            @id_cond_pago_sistecredito	NVARCHAR(4) =   'SIS';

	DECLARE @id_pais_defecto	NVARCHAR(3)	=	'169',
			@id_dpto_defecto	NVARCHAR(3)	=	'11',
			@id_ciudad_defecto	NVARCHAR(3)	=	'001';
	
	/*
		*	Definición de variables para la obtención de la ubicación desde Shopify
		*		1 = Obtener la ubicación desde la sección Customer.Default_Address
		*		2 = Obtener la ubicación desde la sección Billing_Address
		*		3 = Obtener la ubicación desde la sección Shipping_Address
	*/
	DECLARE @location_origin_data	INT	=	1;

--->================================================================================================================<---

	/*
		*	Definición de la sección de terceros del conector
	*/
	DECLARE @terceros	TABLE (
		F200_ID					NVARCHAR(15),
		F200_NIT				NVARCHAR(25),
		F200_ID_TIPO_IDENT		NVARCHAR(1),
		F200_IND_TIPO_TERCERO	NVARCHAR(1),
		F200_RAZON_SOCIAL		NVARCHAR(100),
		F200_APELLIDO1			NVARCHAR(29),
		F200_APELLIDO2			NVARCHAR(29),
		F200_NOMBRES			NVARCHAR(40),
		F200_NOMBRE_EST			NVARCHAR(50),
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
	DECLARE @clientes	TABLE (
		F201_ID_TERCERO				NVARCHAR(15),
		F201_DESCRIPCION_SUCURSAL	NVARCHAR(40),
		F201_ID_COND_PAGO			NVARCHAR(3),
		F015_CONTACTO				NVARCHAR(50),
		F015_DIRECCION1				NVARCHAR(40),
		F015_DIRECCION2				NVARCHAR(40),
		F015_ID_PAIS				NVARCHAR(3),
		F015_ID_DEPTO				NVARCHAR(2),
		F015_ID_CIUDAD				NVARCHAR(3),
		F015_TELEFONO				NVARCHAR(20),
		F015_EMAIL					NVARCHAR(255),
		F201_FECHA_INGRESO			NVARCHAR(8),
		f015_celular				NVARCHAR(50)
	);

	/*
		*	Definición de la sección de impuestos y retenciones del conector
	*/
	DECLARE @Imptos_y_Reten	TABLE (
		F_ID_TERCERO	NVARCHAR(15),
		F_ID_CLASE		NVARCHAR(3),
		F_ID_LLAVE		NVARCHAR(1)
	);

	/*
		*	Definición de la sección de entidades dinamicas cliente del conector
	*/
	DECLARE @Ent_Dinamica_Cliente	TABLE (
		f201_id_tercero					NVARCHAR(15),
		f201_id_sucursal				NVARCHAR(3),
		f753_id_grupo_entidad			NVARCHAR(30),
		f753_id_entidad					NVARCHAR(30),
		f753_id_atributo				NVARCHAR(30),
		f753_dato_numerico				NVARCHAR(28),
		f753_dato_texto					NVARCHAR(2000),
		f753_dato_fecha_hora			NVARCHAR(8),
		f753_id_maestro					NVARCHAR(10),
		f753_id_maestro_detalle			NVARCHAR(20),
		f753_id_maestro_interno_detalle	NVARCHAR(100),
		f753_id_maestro_interno			NVARCHAR(10)
	)
	
--->================================================================================================================<---

	DECLARE @ordenes TABLE (
		id_orden	NVARCHAR(20),
		orden_obj	NVARCHAR(MAX)
	);

	/*
		*	Obtener órdenes pendientes de procesamiento que se encuentran en estado 1 y 
		*	tienen menos de 3 intentos de procesamiento
	*/
	INSERT INTO @ordenes (id_orden, orden_obj)
	SELECT TOP (@batch_size)
		id_orden, 
		orden_obj
	FROM [shopify-colombia-womder].dbo.ordenes 
	WHERE 
		id_estado	=	1
		AND
		intentos	<=	3

--->================================================================================================================<---

	/*
		*	Definición de variables para el procesamiento de las órdenes
	*/
	DECLARE @order		NVARCHAR(30);
	DECLARE @json		NVARCHAR(MAX)	= 	'';
	DECLARE @total		INT	=	(SELECT COUNT(*) FROM @ordenes);	--	*	Total de órdenes a procesar
	DECLARE @counter	INT	=	1;									--	*	Contador de órdenes procesadas
	WHILE @counter <= @total
	BEGIN
		BEGIN TRY
			/*
				*	Obtener el JSON de la orden actual
			*/
			SET @json	=	(
				SELECT
					orden_obj
				FROM (
					SELECT 
						orden_obj, 
						ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
					FROM @ordenes
				) AS temp
				WHERE
					rn = @counter
			);
			
			/*
				*	Variables para almacenar los valores de país, departamento, ciudad, dirección 1 y dirección 2 desde el pedido de Shopify
                *		@location_origin_data   =   1   --> Obtener la ubicación desde la sección Customer.Default_Address
		        *		@location_origin_data   =   2   --> Obtener la ubicación desde la sección Billing_Address
		        *		@location_origin_data   =   3   --> Obtener la ubicación desde la sección Shipping_Address
		        *		@location_origin_data   =   4   --> Obtener la ubicación desde la sección Customer.Default_Address 
                *                                           y si no la encuentra, la obtiene desde Billing_Address
		        *		@location_origin_data   =   5   --> Obtener la ubicación desde la sección Billing_Address 
                *                                           y si no la encuentra, la obtiene desde Customer.Default_Address
			*/
			DECLARE @base_path NVARCHAR(100)	=
				CASE 
					WHEN	@location_origin_data	=	1 
						THEN	@path_customer
					WHEN	@location_origin_data	=	2 
						THEN	@path_billing
					WHEN	@location_origin_data	=	3
						THEN	@path_shipping
					WHEN	@location_origin_data	=	4 
						THEN
							CASE
								WHEN	JSON_VALUE(@json, @path_customer + '.city') IS NOT NULL
									THEN	@path_customer
								ELSE	@path_billing
							END
					WHEN	@location_origin_data	=	5 
						THEN
							CASE
								WHEN	JSON_VALUE(@json, @path_billing + '.city') IS NOT NULL
									THEN	@path_billing
								ELSE	@path_customer
							END
					ELSE ''
				END;

			DECLARE @pais_shopify NVARCHAR(100) =
				dbo.fn_RemoveAccentMarks(
					LOWER(
						JSON_VALUE(@json, @base_path + '.country')
					)
				);

			DECLARE @dpto_shopify NVARCHAR(100) =
				dbo.fn_RemoveAccentMarks(
					LOWER(
						JSON_VALUE(@json, @base_path + '.province')
					)
				);

			DECLARE @ciudad_shopify NVARCHAR(100) =
				dbo.fn_RemoveAccentMarks(
					LOWER(
						JSON_VALUE(@json, @base_path + '.city')
					)
				);

			DECLARE @direccion_1_shopify NVARCHAR(255) =
				UPPER(
					JSON_VALUE(@json, @base_path + '.address1')
				);

			DECLARE @direccion_2_shopify NVARCHAR(255) =
				UPPER(
					JSON_VALUE(@json, @base_path + '.address2')
				);

			DECLARE @id_pais_erp	NVARCHAR(3);
			DECLARE @id_dptos_erp	NVARCHAR(2);
			DECLARE @id_ciudad_erp	NVARCHAR(3);

			SELECT
				@id_pais_erp	=	@id_pais_defecto,
				@id_dptos_erp	=	@id_dpto_defecto,
				@id_ciudad_erp	=	@id_ciudad_defecto

			/*
            SELECT
				@id_pais_erp	=	id_pais_erp,
				@id_dptos_erp	=	id_dptos_erp,
				@id_ciudad_erp	=	id_ciudad_erp
            FROM dbo.fn_GetLocationIds(
                @pais_shopify,      -- país
                @dpto_shopify,      -- departamento
                @ciudad_shopify,    -- ciudad
                @id_pais_defecto,   -- id_pais_defecto
                @id_dpto_defecto,   -- id_depto_defecto
                @id_ciudad_defecto  -- id_ciudad_defecto
            );
			*/

			SET @order	=	JSON_VALUE(@json, '$.name');	--	*	Obtener el número de la orden

			DECLARE @id_cliente NVARCHAR(100) =
				LEFT(
                    REPLACE(
						CASE @client_origin_data
							WHEN 1 
								THEN 
									NULLIF(
										TRIM(
											JSON_VALUE(@json, @path_customer + '.company')
										)
										, ''
									)
							WHEN 2 
								THEN 
									NULLIF(
										TRIM(
											JSON_VALUE(@json, @path_billing  + '.company')
										)
										, ''
									)
							WHEN 3 
								THEN 
									COALESCE(
										NULLIF(
											TRIM(
												JSON_VALUE(@json, @path_customer + '.company')
											)
											, ''
										),
										NULLIF(
											TRIM(
												JSON_VALUE(@json, @path_billing  + '.company')
											)
											, ''
										)
									)
							WHEN 4 
								THEN 
									COALESCE(
										NULLIF(
											TRIM(
												JSON_VALUE(@json, @path_billing  + '.company')
											)
											, ''
										),
										NULLIF(
											TRIM(
												JSON_VALUE(@json, @path_customer + '.company')
											)
											, ''
										)
									)
						END,
				    	'.',
				    	''
				    ),
                    15
                );
			
			IF ISNULL(@id_cliente, '') = ''
			BEGIN
				UPDATE [shopify-colombia-womder].[dbo].ordenes
				SET 
					intentos	=
						CASE
							WHEN @process_client_without_id = 0 
								THEN 
									intentos + 1 
							ELSE 0 
						END,
					id_estado	=
						CASE 
							WHEN @process_client_without_id = 1 
								THEN 2 
							ELSE id_estado 
						END
				WHERE
					id_orden	=	@order;

				SET @counter = @counter + 1;
				CONTINUE;
			END;

			DECLARE @razon_social NVARCHAR(100) =
				UPPER(
					JSON_VALUE(@json, @base_path  + '.name')
				);

			DECLARE @nombre_cliente NVARCHAR(40) =
				UPPER(
					JSON_VALUE(@json, @base_path + '.first_name')
				);

			DECLARE @apellidos_cliente NVARCHAR(80) =
				UPPER(
					JSON_VALUE(@json, @base_path + '.last_name')
				);

			DECLARE @apellido_1_cliente	NVARCHAR(80) = 
				LEFT(
					@apellidos_cliente, 
					CHARINDEX(
						' ', 
						@apellidos_cliente + ' '
					) - 1
				);

			DECLARE @apellido_2_cliente NVARCHAR(80) =
				LTRIM(
					SUBSTRING(
						@apellidos_cliente,
						CHARINDEX(' ', @apellidos_cliente + ' '),
						LEN(@apellidos_cliente)
					)
				);

			DECLARE @telefono_cliente	NVARCHAR(50)	=	
				REPLACE(
					JSON_VALUE(@json, @path_customer + '.phone'),
					'+57',
					''
				);

			DECLARE @email_cliente		NVARCHAR(255)	=	JSON_VALUE(@json, '$.customer.email');

			DECLARE @fecha_creacion		NVARCHAR(8)	=	
				REPLACE(
					CONVERT(
						VARCHAR(10), 
						CAST(
							JSON_VALUE(@json, '$.customer.created_at') AS DATE
						)
					), 
					'-', 
					''
				);

			DECLARE @id_cond_pago	NVARCHAR(3)	=	NULL;

			SELECT TOP 1
                @id_cond_pago	=
                    CASE
                        WHEN    JSON_VALUE(transaccion_obj, '$.gateway') = 'Addi Payment'
                            THEN    @id_cond_pago_addi
                        WHEN    JSON_VALUE(transaccion_obj, '$.gateway') = 'Sistecredito'
                            THEN    @id_cond_pago_Sistecredito
                        WHEN    JSON_VALUE(transaccion_obj, '$.gateway') = 'Wompi'
                            THEN    @id_cond_pago_Wompi
                        WHEN    JSON_VALUE(transaccion_obj, '$.gateway') LIKE '%Bold%'
                            THEN    @id_cond_pago_Bold
                    END
            FROM transacciones_ordenes
            WHERE
                id_orden = JSON_VALUE(@json, '$.id')
                AND
                JSON_VALUE(transaccion_obj, '$.status') =   'success';

			/*
				*	Sección de terceros del conector
			*/
			INSERT INTO @terceros
			(
				F200_ID,
				F200_NIT,
				F200_ID_TIPO_IDENT,
				F200_IND_TIPO_TERCERO,
				F200_RAZON_SOCIAL,
				F200_APELLIDO1,
				F200_APELLIDO2,
				F200_NOMBRES,
				F200_NOMBRE_EST,
				F015_CONTACTO,
				F015_DIRECCION1,
				F015_DIRECCION2,
				F015_ID_PAIS,
				F015_ID_DEPTO,
				F015_ID_CIUDAD,
				F015_TELEFONO,
				F015_EMAIL,
				F200_FECHA_NACIMIENTO,
				F015_CELULAR
			)
			SELECT
				F200_ID					=	LEFT(@id_cliente, 15),
				F200_NIT				=	LEFT(@id_cliente, 25),
				F200_ID_TIPO_IDENT		=	@id_tipo_ident_defecto,
				F200_IND_TIPO_TERCERO	=	@ind_tipo_tercero_defecto,
				F200_RAZON_SOCIAL		=	LEFT(@razon_social, 100),
				F200_APELLIDO1			=	LEFT(@apellido_1_cliente, 29),
				F200_APELLIDO2			=	LEFT(@apellido_2_cliente, 29),
				F200_NOMBRES			=	LEFT(@nombre_cliente, 40),
				F200_NOMBRE_EST			=	LEFT(@razon_social, 50),
				F015_CONTACTO			=	LEFT(@razon_social, 50),
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
			INSERT INTO @clientes
			(
				F201_ID_TERCERO,
				F201_DESCRIPCION_SUCURSAL,
				F201_ID_COND_PAGO,
				F015_CONTACTO,
				F015_DIRECCION1,
				F015_DIRECCION2,
				F015_ID_PAIS,
				F015_ID_DEPTO,
				F015_ID_CIUDAD,
				F015_TELEFONO,
				F015_EMAIL,
				F201_FECHA_INGRESO,
				f015_celular
			)
			SELECT
				F201_ID_TERCERO				=	LEFT(@id_cliente, 15),
				F201_DESCRIPCION_SUCURSAL	=	LEFT(@razon_social, 40),
				F201_ID_COND_PAGO			=	@id_cond_pago,
				F015_CONTACTO				=	LEFT(@razon_social, 50),
				F015_DIRECCION1				=	LEFT(@direccion_1_shopify, 40),
				F015_DIRECCION2				=	LEFT(@direccion_2_shopify, 40),
				F015_ID_PAIS				=	LEFT(@id_pais_erp, 3),
				F015_ID_DEPTO				=	LEFT(@id_dptos_erp, 2),
				F015_ID_CIUDAD				=	LEFT(@id_ciudad_erp, 3),
				F015_TELEFONO				=	LEFT(@telefono_cliente, 20),
				F015_EMAIL					=	LEFT(@email_cliente, 255),
				F201_FECHA_INGRESO			=	@fecha_creacion,
				f015_celular				=	LEFT(@telefono_cliente, 50);
			
			/*
				*	Sección de clientes del Impuestos y retenciones
				*	-	F_TIPO_REG
				*			46	->	Impuestos cliente
				*			47	->	Retención cliente
				*			49	->	Impuestos proveedor
				*			50	->	Retención proveedor
			*/
			INSERT INTO @Imptos_y_Reten
			(
				F_ID_TERCERO,
				F_ID_CLASE,
				F_ID_LLAVE
			)
			SELECT				-->	Impuestos cliente
				F_ID_TERCERO	=	LEFT(@id_cliente, 15),
				F_ID_CLASE		=	1,
				F_ID_LLAVE		=	LEFT('', 4)
			UNION ALL
			SELECT				-->	Retención cliente
				F_ID_TERCERO	=	LEFT(@id_cliente, 15),
				F_ID_CLASE		=	21,
				F_ID_LLAVE		=	LEFT('', 4)
			
			INSERT INTO @final(
				idDocumento,
				descripcion,
				indicaParalelismo,
				idOrden,
				json
			)
			SELECT 
				@idDocumento,
				@descripcionConector,
				@indicaParalelismo,
				@order as idOrden,
				(
					SELECT
						[Terceros] = (
							SELECT *
							FROM @terceros
							FOR JSON PATH,
							INCLUDE_NULL_VALUES
						)
						,
						[Clientes] = (
							SELECT *
							FROM @clientes
							FOR JSON PATH,
							INCLUDE_NULL_VALUES
						),
						[Imptos y Reten] = (
							SELECT *
							FROM @Imptos_y_Reten
      						FOR JSON PATH,
							INCLUDE_NULL_VALUES
    					)
					FOR JSON PATH,
					WITHOUT_ARRAY_WRAPPER,
					INCLUDE_NULL_VALUES
				);

			SET @counter = @counter + 1;
			DELETE @terceros;
			DELETE @clientes;
			DELETE @Imptos_y_Reten;
		END TRY
		BEGIN CATCH
			--	*	Registrar el error en la orden y continuar con la siguiente
			/*
			SELECT 
				indicaError         =   CAST(1 AS BIT), 
				descripcionError    =   CONCAT('Error: ', ERROR_MESSAGE()),
				ErrorNumber         =   ERROR_NUMBER(),
				ErrorSeverity       =   ERROR_SEVERITY(),
				ErrorState          =   ERROR_STATE(),
				ErrorProcedure      =   ERROR_PROCEDURE(),
				ErrorLine           =   ERROR_LINE(),
				ErrorMessage        =   ERROR_MESSAGE();
			*/
			
			UPDATE [shopify-colombia-womder].[dbo].ordenes
			SET 
				intentos	=	intentos + 1
			WHERE 
				id_orden	=	@order;
		END CATCH;

		SET @counter = @counter + 1;
		DELETE @terceros;
		DELETE @clientes;
		DELETE @Imptos_y_Reten;
	END

    SELECT * 
    FROM    @final AS final_json;
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
