
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
	DECLARE	@idDocumento			INT			=	'207135',
			@descripcionConector	VARCHAR(50)	=	'01_Ecommerce_Connekta_Terceros',
			@indicaParalelismo		BIT			=	1;

--->================================================================================================================<---

	/*
		*	Configuración de ejecución del script
	*/
	DECLARE @batch_size	INT	=   15;	--	*	Cuantas órdenes se traen por petición

	/*
		*	Origen de los datos del cliente/tercero
		*		1 = Desde la sección Customer
		*		2 = Desde la sección Billing Address
		*		3 = Desde la sección Customer y si no existe, desde Billing Address
		*		4 = Desde la sección Billing Address y si no existe, desde Customer
	*/
	DECLARE @client_origin_data	INT	=	3;

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

	DECLARE @id_pais_defecto	NVARCHAR(3)	=	'',
			@id_dpto_defecto	NVARCHAR(3)	=	'',
			@id_ciudad_defecto	NVARCHAR(3)	=	'';
	
	/*
		*	Definición de variables para la obtención de la ubicación desde Shopify
		*		1 = Obtener la ubicación desde la sección Customer.Default_Address
		*		2 = Obtener la ubicación desde la sección Billing_Address
		*		3 = Obtener la ubicación desde la sección Shipping_Address
	*/
	DECLARE @location_origin_data	INT	=	1;

	/*
		*	Id CIIU del tercero
	*/
	DECLARE @id_ciiu	VARCHAR(4)	=	'1111';

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
		F015_DIRECCION3			NVARCHAR(40),
		F015_ID_PAIS			NVARCHAR(3),
		F015_ID_DEPTO			NVARCHAR(2),
		F015_ID_CIUDAD			NVARCHAR(3),
		F015_TELEFONO			NVARCHAR(20),
		F015_EMAIL				NVARCHAR(255),
		F200_FECHA_NACIMIENTO	NVARCHAR(8),
		F200_ID_CIIU			NVARCHAR(4),
		F015_CELULAR			NVARCHAR(50)
	);

	/*
		*	Definición de la sección de clientes del conector
	*/
	DECLARE @cliente	TABLE (
		F015_CONTACTO				NVARCHAR(50),
		F201_ID_LISTA_PRECIO		NVARCHAR(3),
		F201_ID_CO_FACTURA			NVARCHAR(3),
		F015_DIRECCION1				NVARCHAR(40),
		F015_DIRECCION2				NVARCHAR(40),
		F015_DIRECCION3				NVARCHAR(40),
		F015_ID_PAIS				NVARCHAR(3),
		F015_ID_DEPTO				NVARCHAR(2),
		F015_ID_CIUDAD				NVARCHAR(3),
		F015_TELEFONO				NVARCHAR(20),
		F015_EMAIL					NVARCHAR(255),
		F201_FECHA_INGRESO			NVARCHAR(8),
		F201_ID_CO_MOVTO_FACTURA	NVARCHAR(3),
		F201_ID_UN_MOVTO_FACTURA	NVARCHAR(20),
		f201_id_cobrador			NVARCHAR(4),
		f015_celular				NVARCHAR(50),
		F201_ID_TERCERO				NVARCHAR(15),
		F201_ID_SUCURSAL			NVARCHAR(3),
		F201_DESCRIPCION_SUCURSAL	NVARCHAR(40),
		F201_ID_MONEDA				NVARCHAR(3),
		F201_ID_VENDEDOR			NVARCHAR(4),
		F201_ID_COND_PAGO			NVARCHAR(3),
		F201_ID_SUCURSAL_CORP		NVARCHAR(3),
		F201_ID_TIPO_CLI			NVARCHAR(4),
		F201_NOTAS					NVARCHAR(255)
	);

	/*
		*	Definición de la sección de impuestos y retenciones del conector
	*/
	DECLARE @Imptos_y_Reten	TABLE (
		F_TIPO_REG			NVARCHAR(4),
		F_ID_TERCERO		NVARCHAR(15),
		F_ID_SUCURSAL		NVARCHAR(3),
		F_ID_CLASE			NVARCHAR(3),
		F_ID_LLAVE			NVARCHAR(4)
	);

	/*
		*	Definición de la sección de criterios clientes del conector
	*/
	DECLARE @Criterios_Clientes	TABLE (
		F207_ID_TERCERO			NVARCHAR(15),
		F207_ID_SUCURSAL		NVARCHAR(15),
		F207_ID_PLAN_CRITERIOS	NVARCHAR(15),
		F207_ID_CRITERIO_MAYOR	NVARCHAR(10)
	);

	/*
		*	Definición de la sección de entidades dinamicas tercero del conector
	*/
	DECLARE @Ent_Dinamica_Tercero	TABLE (
		f200_id					NVARCHAR(15),
		f753_id_grupo_entidad	NVARCHAR(30),
		f753_id_entidad			NVARCHAR(30),
		f753_id_atributo		NVARCHAR(30),
		f753_dato_numerico		NVARCHAR(28),
		f753_dato_texto			NVARCHAR(2000),
		f753_dato_fecha_hora	NVARCHAR(8),
		f753_id_maestro			NVARCHAR(10),
		f753_id_maestro_detalle	NVARCHAR(20)
	);

	/*
		*	Definición de la sección de entidades dinamicas cliente del conector
	*/
	DECLARE @Ent_Dinamica_Cliente	TABLE (
		f201_id_tercero			NVARCHAR(15),
		f201_id_sucursal		NVARCHAR(3),
		f753_id_grupo_entidad	NVARCHAR(30),
		f753_id_entidad			NVARCHAR(30),
		f753_id_atributo		NVARCHAR(30)
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
	FROM ordenes 
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
			*/
			DECLARE @pais_shopify	NVARCHAR(100)	=	
				CASE
					WHEN @location_origin_data = 1 
						THEN dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.customer.default_address.country')))
					WHEN @location_origin_data = 2 
						THEN dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.billing_address.country')))
					WHEN @location_origin_data = 3 
						THEN dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.country')))
					ELSE ''
				END;

			DECLARE @dpto_shopify	NVARCHAR(100)	=	
				CASE
					WHEN @location_origin_data = 1 
						THEN dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.customer.default_address.province')))
					WHEN @location_origin_data = 2 
						THEN dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.billing_address.province')))
					WHEN @location_origin_data = 3 
						THEN dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.province')))
					ELSE ''
				END;

			DECLARE @ciudad_shopify	NVARCHAR(100)	=	
				CASE
					WHEN @location_origin_data = 1 
						THEN dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.customer.default_address.city')))
					WHEN @location_origin_data = 2 
						THEN dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.billing_address.city')))
					WHEN @location_origin_data = 3 
						THEN dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.city')))
					ELSE ''
				END;

			DECLARE @direccion_1_shopify	NVARCHAR(255)	=	
				CASE
					WHEN @location_origin_data = 1 
						THEN UPPER(JSON_VALUE(@json, '$.customer.default_address.address1'))
					WHEN @location_origin_data = 2 
						THEN UPPER(JSON_VALUE(@json, '$.billing_address.address1'))
					WHEN @location_origin_data = 3 
						THEN UPPER(JSON_VALUE(@json, '$.shipping_address.address1'))
					ELSE ''
				END;

			DECLARE @direccion_2_shopify	NVARCHAR(255)	=	
				CASE
					WHEN @location_origin_data = 1 
						THEN UPPER(JSON_VALUE(@json, '$.customer.default_address.address2'))
					WHEN @location_origin_data = 2 
						THEN UPPER(JSON_VALUE(@json, '$.billing_address.address2'))
					WHEN @location_origin_data = 3 
						THEN UPPER(JSON_VALUE(@json, '$.shipping_address.address2'))
					ELSE ''
				END;

			DECLARE @id_pais_erp	NVARCHAR(3);
			DECLARE @id_dptos_erp	NVARCHAR(2);
			DECLARE @id_ciudad_erp	NVARCHAR(3);

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

			SET @order	=	JSON_VALUE(@json, '$.name');	--	*	Obtener el número de la orden

			DECLARE @id_cliente		NVARCHAR(100)	=	
				CASE
					WHEN @client_origin_data	=	1	--	*	Desde la sección Customer
						THEN 
							NULLIF(
								TRIM(
									JSON_VALUE(@json, '$.customer.default_address.company')
								), 
								''
							)
					WHEN @client_origin_data	=	2	--	*	Desde la sección Billing Address
						THEN 
							NULLIF(
								TRIM(
									JSON_VALUE(@json, '$.billing_address.company')
								), 
								''
							)
					WHEN @client_origin_data	=	3	--	*	Desde la sección Customer o Billing Address
						THEN
							ISNULL(
								NULLIF(
									TRIM(
										JSON_VALUE(@json, '$.customer.default_address.company')
									),
									''
								), 
								JSON_VALUE(@json, '$.billing_address.company')
							)
					WHEN @client_origin_data	=	4	--	*	Desde la sección Billing Address o Customer
						THEN
							ISNULL(
								NULLIF(
									TRIM(
										JSON_VALUE(@json, '$.billing_address.company')
									),
									''
								), 
								JSON_VALUE(@json, '$.customer.default_address.company')
							)
					ELSE NULL
				END;
			
			IF (@id_cliente IS NULL OR @id_cliente = '')
			BEGIN
				IF (@process_client_without_id = 0)
				BEGIN
					--	*	Incrementar el contador de intentos y continuar con la siguiente orden
					UPDATE ordenes
					SET 
						intentos	=	intentos + 1
					WHERE 
						id_orden	=	@order;

					CONTINUE;
				END
				ELSE
				BEGIN
					--	*	Cambiar el estado de la orden a 2 (Pendiente de Revisión) y colocar intentos a 0
					UPDATE ordenes
					SET 
						id_estado	=	2,
						intentos	=	0
					WHERE 
						id_orden	=	@order;
					
					CONTINUE;
				END
			END;

			DECLARE @razon_social		NVARCHAR(100)	=	
				CASE
					WHEN @client_origin_data	=	1	--	*	Desde la sección Customer
						THEN 
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.customer.default_address.name')
								), 
								''
							)
					WHEN @client_origin_data	=	2	--	*	Desde la sección Billing Address
						THEN
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.billing_address.name')
								), 
								''
							)
					WHEN @client_origin_data	=	3	--	*	Desde la sección Customer o Billing Address
						THEN 
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.customer.default_address.name')
								),
								ISNULL(
									UPPER(
										JSON_VALUE(@json, '$.billing_address.name')
									), 
									''
								)
							)
					WHEN @client_origin_data	=	4	--	*	Desde la sección Billing Address o Customer
						THEN 
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.billing_address.name')
								),
								ISNULL(
									UPPER(
										JSON_VALUE(@json, '$.customer.default_address.name')
									), 
									''
								)
							)
					ELSE ''
				END;

			DECLARE @nombre_cliente		NVARCHAR(40)	=
				CASE
					WHEN @client_origin_data	=	1	--	*	Desde la sección Customer
						THEN 
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.customer.default_address.first_name')
								), 
								''
							)
					WHEN @client_origin_data	=	2	--	*	Desde la sección Billing Address
						THEN 
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.billing_address.first_name')
								), 
								''
							)
					WHEN @client_origin_data	=	3	--	*	Desde la sección Customer o Billing Address
						THEN 
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.customer.default_address.first_name')
								),
								ISNULL(
									UPPER(
										JSON_VALUE(@json, '$.billing_address.first_name')
									), 
									''
								)
							)
					WHEN @client_origin_data	=	4	--	*	Desde la sección Billing Address o Customer
						THEN 
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.billing_address.first_name')
								),
								ISNULL(
									UPPER(
										JSON_VALUE(@json, '$.customer.default_address.first_name')
									), 
									''
								)
							)
					ELSE ''
				END;

			DECLARE @apellidos_cliente	NVARCHAR(80)	=	
				CASE
					WHEN @client_origin_data	=	1	--	*	Desde la sección Customer
						THEN 
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.customer.default_address.last_name')
								), 
								''
							)
					WHEN @client_origin_data	=	2	--	*	Desde la sección Billing Address
						THEN
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.billing_address.last_name')
								), 
								''
							)
					WHEN @client_origin_data	=	3	--	*	Desde la sección Customer o Billing Address
						THEN 
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.customer.default_address.last_name')
								),
								ISNULL(
									UPPER(
										JSON_VALUE(@json, '$.billing_address.last_name')
									), 
									''
								)
							)
					WHEN @client_origin_data	=	4	--	*	Desde la sección Billing Address o Customer
						THEN 
							ISNULL(
								UPPER(
									JSON_VALUE(@json, '$.billing_address.last_name')
								),
								ISNULL(
									UPPER(
										JSON_VALUE(@json, '$.customer.default_address.last_name')
									), 
									''
								)
							)
					ELSE ''
				END;

			DECLARE @apellido_1_cliente	NVARCHAR(80) = 
				LEFT(
					UPPER(
						TRIM(@apellidos_cliente)
					), 
					CHARINDEX(
						' ', 
						UPPER(@apellidos_cliente) + ' '
					) - 1
				);

			DECLARE @apellido_2_cliente	NVARCHAR(80)	=
				LTRIM(
					SUBSTRING(
						UPPER(@apellidos_cliente),
						CHARINDEX(
							' ', 
							UPPER(@apellidos_cliente) + ' '
						), 
						LEN(
							UPPER(@apellidos_cliente)
						) - CHARINDEX(
							' ', 
							UPPER(@apellidos_cliente)
						) + 1
					)
				);

			DECLARE @telefono_cliente	NVARCHAR(50)	=	
				REPLACE(
					JSON_VALUE(@json, '$.customer.default_address.phone'),
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
				F015_DIRECCION3,
				F015_ID_PAIS,
				F015_ID_DEPTO,
				F015_ID_CIUDAD,
				F015_TELEFONO,
				F015_EMAIL,
				F200_FECHA_NACIMIENTO,
				F200_ID_CIIU,
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
				F200_NOMBRE_EST			=	LEFT(@nombre_cliente, 50),
				F015_CONTACTO			=	LEFT(@nombre_cliente, 50),
				F015_DIRECCION1			=	LEFT(@direccion_1_shopify, 40),
				F015_DIRECCION2			=	LEFT(@direccion_2_shopify, 40),
				F015_DIRECCION3			=	'',
				F015_ID_PAIS			=	LEFT(@id_pais_erp, 3),
				F015_ID_DEPTO			=	LEFT(@id_dptos_erp, 2),
				F015_ID_CIUDAD			=	LEFT(@id_ciudad_erp, 3),
				F015_TELEFONO			=	LEFT(@telefono_cliente, 20),
				F015_EMAIL				=	@email_cliente,
				F200_FECHA_NACIMIENTO	=	@fecha_creacion,
				F200_ID_CIIU			=	@id_ciiu,
				F015_CELULAR			=	LEFT(@telefono_cliente, 50);

			/*
				*	Sección de clientes del conector
			*/
			INSERT INTO @cliente
			(
				F015_CONTACTO,
				F201_ID_LISTA_PRECIO,
				F201_ID_CO_FACTURA,
				F015_DIRECCION1,
				F015_DIRECCION2,
				F015_DIRECCION3,
				F015_ID_PAIS,
				F015_ID_DEPTO,
				F015_ID_CIUDAD,
				F015_TELEFONO,
				F015_EMAIL,
				F201_FECHA_INGRESO,
				F201_ID_CO_MOVTO_FACTURA,
				F201_ID_UN_MOVTO_FACTURA,
				f201_id_cobrador,
				f015_celular,
				F201_ID_TERCERO,
				F201_ID_SUCURSAL,
				F201_DESCRIPCION_SUCURSAL,
				F201_ID_MONEDA,
				F201_ID_VENDEDOR,
				F201_ID_COND_PAGO,
				F201_ID_SUCURSAL_CORP,
				F201_ID_TIPO_CLI,
				F201_NOTAS
			)
			SELECT
				F015_CONTACTO				=	LEFT('', 50),
				F201_ID_LISTA_PRECIO		=	'',
				F201_ID_CO_FACTURA			=	'',
				F015_DIRECCION1				=	LEFT(@direccion_1_shopify, 40),
				F015_DIRECCION2				=	LEFT(@direccion_2_shopify, 40),
				F015_DIRECCION3				=	'',
				F015_ID_PAIS				=	LEFT(@id_pais_erp, 3),
				F015_ID_DEPTO				=	LEFT(@id_dptos_erp, 2),
				F015_ID_CIUDAD				=	LEFT(@id_ciudad_erp, 3),
				F015_TELEFONO				=	LEFT(@telefono_cliente, 20),
				F015_EMAIL					=	LEFT(@email_cliente, 255),
				F201_FECHA_INGRESO			=	@fecha_creacion,
				F201_ID_CO_MOVTO_FACTURA	=	'',
				F201_ID_UN_MOVTO_FACTURA	=	'',
				f201_id_cobrador			=	'',
				f015_celular				=	LEFT(@telefono_cliente, 50),
				F201_ID_TERCERO				=	LEFT(@id_cliente, 15),
				F201_ID_SUCURSAL			=	'',
				F201_DESCRIPCION_SUCURSAL	=	LEFT(@razon_social, 40),
				F201_ID_MONEDA				=	'',
				F201_ID_VENDEDOR			=	'',
				F201_ID_COND_PAGO			=	'',
				F201_ID_SUCURSAL_CORP		=	'',
				F201_ID_TIPO_CLI			=	'',
				F201_NOTAS					=	'';
			
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
				F_TIPO_REG,
				F_ID_TERCERO,
				F_ID_SUCURSAL,
				F_ID_CLASE,
				F_ID_LLAVE
			)
			SELECT
				F_TIPO_REG		=	'46',					-->	Impuestos cliente
				F_ID_TERCERO	=	LEFT(@id_cliente, 15),
				F_ID_SUCURSAL	=	LEFT('', 3),
				F_ID_CLASE		=	LEFT('', 3),
				F_ID_LLAVE		=	LEFT('', 4)
			UNION ALL
			SELECT
				F_TIPO_REG		=	'47',					-->	Retención cliente
				F_ID_TERCERO	=	LEFT(@id_cliente, 15),
				F_ID_SUCURSAL	=	LEFT('', 3),
				F_ID_CLASE		=	LEFT('', 3),
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
						[Cliente] = (
							SELECT *
							FROM @cliente
							FOR JSON PATH,
							INCLUDE_NULL_VALUES
						)						,
						[Imptos y Reten] = (
							SELECT *
							FROM @Imptos_y_Reten
      						FOR JSON PATH,
							INCLUDE_NULL_VALUES
    					)
						/*
						*	TODO EN DESARROLLO
						,
						[Criterios_Clientes] = (
							SELECT
								@id_cliente AS F207_ID_TERCERO,
								'001' AS F207_ID_SUCURSAL,
								'' AS F207_ID_PLAN_CRITERIOS,
								'' AS F207_ID_CRITERIO_MAYOR
								FOR JSON PATH, 
								INCLUDE_NULL_VALUES
						),
						[Ent_Dinamica_Cliente] = (
							SELECT
								@id_cliente AS f201_id_tercero,
								'001' AS f201_id_sucursal,
								'' AS f753_dato_texto
							FOR JSON PATH, 
							INCLUDE_NULL_VALUES
						)*/
					FOR JSON PATH,
					WITHOUT_ARRAY_WRAPPER,
					INCLUDE_NULL_VALUES
				);


		END TRY
		BEGIN CATCH
			--	*	Registrar el error en la orden y continuar con la siguiente
			UPDATE ordenes
			SET 
				intentos	=	intentos + 1
			WHERE 
				id_orden	=	@order;
		END CATCH;

		SET @counter = @counter + 1;
		DELETE @terceros;
	END

    SELECT * 
    FROM    @final AS final_json;
END TRY
BEGIN CATCH
    SELECT 
        ERROR_NUMBER()		AS	ErrorNumber,
        ERROR_SEVERITY()	AS	ErrorSeverity,
        ERROR_STATE()		AS	ErrorState,
        ERROR_PROCEDURE()	AS	ErrorProcedure,
        ERROR_LINE()		AS	ErrorLine,
        ERROR_MESSAGE()		AS	ErrorMessage;
END CATCH;


--     SET @json = (
--         SELECT orden_obj
--         FROM (
--             SELECT orden_obj, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
--             FROM #ordenes
--         ) AS temp
--         WHERE rn = @counter
--     );

--  select top 1 @paisSiesa=isnull(f013_id_pais,'169') ,@dptoSiesa=isnull(f013_id_depto,'05') ,@ciudadSiesa=isnull(f013_id,'001') 
--  from locaciones_erp 
--  where 
-- 		replace(replace(replace(replace(replace(lower(f011_descripcion),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')=replace(replace(replace(replace(replace(lower(JSON_VALUE(@json, '$.customer.default_address.country')),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')
--  and	replace(replace(replace(replace(replace(lower(f012_descripcion),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')=replace(replace(replace(replace(replace(lower(JSON_VALUE(@json, '$.customer.default_address.province')),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')
--  and	replace(replace(replace(replace(replace(lower(f013_descripcion),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')=replace(replace(replace(replace(replace(lower(JSON_VALUE(@json, '$.customer.default_address.city')),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')
 
--  SET @order=JSON_VALUE(@json, '$.name')

--  declare @F200_ID nvarchar(40)= isnull(JSON_VALUE(@json, '$.billing_address.company'),JSON_VALUE(@json, '$.customer.default_address.company'))
--  declare @F200_RAZON_SOCIAL nvarchar(100)=upper(isnull(JSON_VALUE(@json, '$.billing_address.name'),JSON_VALUE(@json, '$.customer.default_address.name')))
--  declare @F015_DIRECCION1 nvarchar(40)=upper(JSON_VALUE(@json, '$.customer.default_address.address1'))
--  declare @F015_DIRECCION2 nvarchar(40)=upper(JSON_VALUE(@json, '$.customer.default_address.address2'))
--  declare @F015_TELEFONO nvarchar(20)=replace(JSON_VALUE(@json, '$.customer.default_address.phone'),'+57','')
--  declare @F015_EMAIL nvarchar(255)=JSON_VALUE(@json, '$.customer.email')
--  declare @FECHA nvarchar(40)=replace(convert(varchar(10), cast(JSON_VALUE(@json, '$.customer.created_at') as date)), '-', '')

--  --tercero
--  select F200_ID=		  @F200_ID
-- 	   ,F200_NIT=		  @F200_ID
-- 	   ,F200_RAZON_SOCIAL=@F200_RAZON_SOCIAL
-- 	   ,F200_APELLIDO1=   upper(JSON_VALUE(@json, '$.customer.default_address.last_name')) 
-- 	   ,F200_APELLIDO2 =   ''
-- 	   ,F200_NOMBRES=    upper(JSON_VALUE(@json, '$.customer.default_address.first_name'))
-- 	   ,F015_CONTACTO=   CONCAT(upper(JSON_VALUE(@json, '$.customer.default_address.first_name')),' ',upper(JSON_VALUE(@json, '$.customer.default_address.last_name')))
-- 	   ,F015_DIRECCION1=@F015_DIRECCION1
-- 	   ,F015_DIRECCION2=@F015_DIRECCION2
-- 		,F015_ID_PAIS   = ISNULL(@paisSiesa, '169')
-- 		,F015_ID_DEPTO  = ISNULL(@dptoSiesa, '05')
-- 		,F015_ID_CIUDAD = ISNULL(@ciudadSiesa, '001')														
-- 	   ,F015_TELEFONO=  @F015_TELEFONO
-- 	   ,F015_EMAIL=     @F015_EMAIL									
-- 	   ,F200_FECHA_NACIMIENTO=@FECHA
-- 	   ,F015_CELULAR=   @F015_TELEFONO
-- 	   into #tercero

-- --cliente
-- select F201_ID_TERCERO=           @F200_ID
-- 	  ,F201_DESCRIPCION_SUCURSAL= @F200_RAZON_SOCIAL
-- 	  ,F201_ID_LISTA_PRECIO =''
-- 	  ,F015_CONTACTO =            @F200_RAZON_SOCIAL
-- 	  ,F015_DIRECCION1 =		  @F015_DIRECCION1
-- 	  ,F015_DIRECCION2 =		  @F015_DIRECCION2
-- 	  ,F015_ID_PAIS   = ISNULL(@paisSiesa, '169')
-- 	   ,F015_ID_DEPTO  = ISNULL(@dptoSiesa, '05')
-- 		,F015_ID_CIUDAD = ISNULL(@ciudadSiesa, '001')	
-- 	  ,F015_TELEFONO=			  @F015_TELEFONO
-- 	  ,F015_EMAIL=                @F015_EMAIL
-- 	  ,F201_FECHA_INGRESO =       @FECHA
-- 	  ,F015_CELULAR=              @F015_TELEFONO  
-- 	  into #cliente


-- insert into @final(idDocumento,descripcion,indicaParalelismo,idOrden,json)
-- select  @idDocumento ,@descripcionConector,@indicaParalelismo ,@order as idOrden,(
-- SELECT
--     [Terceros] = (
--       SELECT *
--       FROM #tercero
--       FOR JSON PATH,INCLUDE_NULL_VALUES
--     ),
--     [Clientes] = (
--       SELECT *
--       FROM #cliente
--       FOR JSON PATH,INCLUDE_NULL_VALUES
--     ),
--     [ImptosyReten] = (
--       SELECT @F200_ID as F_ID_TERCERO
--       FOR JSON PATH,INCLUDE_NULL_VALUES
--     )
-- FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
