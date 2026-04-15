
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
	DECLARE	@idDocumento			INT			=	'000000',
			@descripcionConector	VARCHAR(50)	=	'Ecommerce_Terceros_Clientes',
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
	DECLARE @client_origin_data	INT	=	4;

	DECLARE @path_customer	NVARCHAR(100)	=	'$.customer.default_address';
	DECLARE @path_billing	NVARCHAR(100)	=	'$.billing_address';

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
		*		1	->	id_tipo_cliente 1
		*		2	->	id_tipo_cliente 2
		*		3	->	id_tipo_cliente 3
		*		4	->	id_tipo_cliente 4
	*/
	DECLARE @id_tipo_cliente_1	NVARCHAR(4) =   '1', -- TODO -> Configurar según el caso, validar según reglas del cliente
            @id_tipo_cliente_2	NVARCHAR(4) =   '2', -- TODO -> Configurar según el caso, validar según reglas del cliente
            @id_tipo_cliente_3	NVARCHAR(4) =   '3', -- TODO -> Configurar según el caso, validar según reglas del cliente
            @id_tipo_cliente_4	NVARCHAR(4) =   '4'; -- TODO -> Configurar según el caso, validar según reglas del cliente
    
    /*
		TODO -> Configurar según el caso, validar según reglas del cliente, eliminar comentarios cuando finalice configuración
		*	Id lista de precios:
		*		1	->	Lista de precios 1
		*		2	->	Lista de precios 2
		*		3	->	Lista de precios 3
		*		4	->	Lista de precios 4
	*/
	DECLARE @id_lista_precios_1	NVARCHAR(3) =   '1', -- TODO -> Configurar según el caso, validar según reglas del cliente
            @id_lista_precios_2	NVARCHAR(3) =   '2'; -- TODO -> Configurar según el caso, validar según reglas del cliente

    /*
		TODO -> Configurar según el caso, validar según reglas del cliente, eliminar comentarios cuando finalice configuración
		*	Id valor tercero en impuestos y retenciones:
		*		1	->	Id valor tercero 1
		*		2	->	Id valor tercero 2
		*		3	->	Id valor tercero 3
		*		4	->	Id valor tercero 4
	*/
	DECLARE @f_id_valor_tercero_1   NVARCHAR(2) =   '1', -- TODO -> Configurar según el caso, validar según reglas del cliente
            @f_id_valor_tercero_2   NVARCHAR(2) =   '2', -- TODO -> Configurar según el caso, validar según reglas del cliente
            @f_id_valor_tercero_3   NVARCHAR(2) =   '3', -- TODO -> Configurar según el caso, validar según reglas del cliente
            @f_id_valor_tercero_4   NVARCHAR(2) =   '4'; -- TODO -> Configurar según el caso, validar según reglas del cliente

    /*
		TODO -> Configurar según el caso, validar según reglas del cliente, eliminar comentarios cuando finalice configuración
		*	Id maestro detalle tercero en entidades dinamicas tercero:
		*		1	->	Id maestro detalle tercero 1
		*		2	->	Id maestro detalle tercero 2
		*		3	->	Id maestro detalle tercero 3
		*		4	->	Id maestro detalle tercero 4
	*/
	DECLARE @id_maestro_detalle_tercero_1	NVARCHAR(2) =   '1', -- TODO -> Configurar según el caso, validar según reglas del cliente
            @id_maestro_detalle_tercero_2	NVARCHAR(2) =   '2', -- TODO -> Configurar según el caso, validar según reglas del cliente
            @id_maestro_detalle_tercero_3	NVARCHAR(2) =   '3', -- TODO -> Configurar según el caso, validar según reglas del cliente
            @id_maestro_detalle_tercero_4	NVARCHAR(2) =   '4'; -- TODO -> Configurar según el caso, validar según reglas del cliente

	/*
		TODO -> Configurar según el caso, validar según reglas del cliente, eliminar comentarios cuando finalice configuración
		*	Id CIIU del tercero:
		*		1	->	Id CIIU 1
		*		2	->	Id CIIU 2
		*		3	->	Id CIIU 3
		*		4	->	Id CIIU 4
	*/
	DECLARE @id_ciiu_1	VARCHAR(4)	=	'1', -- TODO -> Configurar según el caso, validar según reglas del cliente
			@id_ciiu_2	VARCHAR(4)	=	'2', -- TODO -> Configurar según el caso, validar según reglas del cliente
			@id_ciiu_3	VARCHAR(4)	=	'3', -- TODO -> Configurar según el caso, validar según reglas del cliente
			@id_ciiu_4	VARCHAR(4)	=	'4'; -- TODO -> Configurar según el caso, validar según reglas del cliente

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
	DECLARE @clientes	TABLE (
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
			DECLARE @base_path NVARCHAR(100) =
    		CASE 
    		    WHEN @location_origin_data = 1 THEN '$.customer.default_address'
    		    WHEN @location_origin_data = 2 THEN '$.billing_address'
    		    WHEN @location_origin_data = 3 THEN '$.shipping_address'
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

			DECLARE @id_cliente NVARCHAR(100) =
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
				END;
			
			IF ISNULL(@id_cliente, '') = ''
			BEGIN
				UPDATE ordenes
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
					COALESCE(
						CASE 
							WHEN @client_origin_data IN (1,3) 
								THEN 
									JSON_VALUE(@json, @path_customer + '.name') 
						END,
						CASE 
							WHEN @client_origin_data IN (2,4) 
								THEN 
									JSON_VALUE(@json, @path_billing  + '.name') 
						END,
						''
					)
				);

			DECLARE @nombre_cliente NVARCHAR(40) =
				UPPER(
					COALESCE(
						CASE 
							WHEN @client_origin_data IN (1,3) 
								THEN 
									JSON_VALUE(@json, @path_customer + '.first_name') 
						END,
						CASE 
							WHEN @client_origin_data IN (2,4) 
								THEN 
									JSON_VALUE(@json, @path_billing  + '.first_name') 
						END,
						''
					)
				);

			DECLARE @apellidos_cliente NVARCHAR(80) =
				UPPER(
					COALESCE(
						CASE 
							WHEN @client_origin_data IN (1,3) 
								THEN 
									JSON_VALUE(@json, @path_customer + '.last_name') 
						END,
						CASE 
							WHEN @client_origin_data IN (2,4) 
								THEN 
									JSON_VALUE(@json, @path_billing  + '.last_name') 
						END,
						''
					)
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
			INSERT INTO @clientes
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
				F015_CONTACTO				=	LEFT(@razon_social, 50),
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
						[Clientes] = (
							SELECT *
							FROM @clientes
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

			SET @counter = @counter + 1;
			DELETE @terceros;
			DELETE @clientes;
			DELETE @Imptos_y_Reten;
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
		DELETE @clientes;
		DELETE @Imptos_y_Reten;
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