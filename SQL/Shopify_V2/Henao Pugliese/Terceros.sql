
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
	DECLARE	@idDocumento			INT			=	'229584',
			@descripcionConector	VARCHAR(50)	=	'Ecommerce_Terceros_Clientes',
			@indicaParalelismo		BIT			=	1;

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
	DECLARE @client_origin_data	INT	=	1;

	/*
		*	Procesar clientes/terceros sin ID
		*		0 = No procesar clientes/terceros sin ID, incrementar el contador de intentos
		*		1 = Procesar clientes/terceros sin ID, cambiar el estado de la orden de 1 a 2 y colocar intentos a 0
	*/
	DECLARE @process_client_without_id	BIT	=	0;

	DECLARE @id_tipo_ident_defecto	NVARCHAR(1)	=	'C';

	DECLARE @id_pais_defecto	NVARCHAR(3)	=	'169',	--	*	Colombia
			@id_dpto_defecto	NVARCHAR(3)	=	'05',	--	*	Antioquia
			@id_ciudad_defecto	NVARCHAR(3)	=	'001';	--	*	Medellín
	
	/*
		*	Definición de variables para la obtención de la ubicación desde Shopify
		*		1 = Obtener la ubicación desde la sección Customer.Default_Address
		*		2 = Obtener la ubicación desde la sección Billing_Address
		*		3 = Obtener la ubicación desde la sección Shipping_Address
	*/
	DECLARE @location_origin_data	INT	=	1;

	DECLARE @order		NVARCHAR(30);
	DECLARE @json		NVARCHAR(MAX)	= 	'';

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
		F015_CELULAR			NVARCHAR(50)
	);
	
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

	/*
		*	Definición de variables para el procesamiento de las órdenes
	*/
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

			SELECT TOP 1 
				@id_pais_erp	=	ISNULL(f013_id_pais,	@id_pais_defecto),
				@id_dptos_erp	=	ISNULL(f013_id_depto,	@id_dpto_defecto),
				@id_ciudad_erp	=	ISNULL(f013_id,			@id_ciudad_defecto) 
			FROM locaciones_erp 
			WHERE
				dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = @pais_shopify
				AND 
				(
					-- Caso 1: Bogotá D.C. (ciudad y departamento son Bogotá)
					(
						(
							'%' + @dpto_shopify + '%' LIKE '%cundinamarca%' 
							OR
							'%' + @dpto_shopify + '%' LIKE '%bogota%' 
						)
						AND 
						@ciudad_shopify	LIKE    '%bogota%'
						AND
						dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion))   LIKE    '%bogota%'
						AND
						dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion))   LIKE    '%bogota%'
					)
					OR 
					-- Caso 2: Provincia es Bogotá pero ciudad NO es Bogotá
					(
						(
							'%' + @dpto_shopify + '%' LIKE '%cundinamarca%' 
							OR
							'%' + @dpto_shopify + '%' LIKE '%bogota%' 
						)
						AND 
						@ciudad_shopify	NOT LIKE 'bogota'
						AND
						dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) LIKE    '%cundinamarca%'
						AND
						dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = @ciudad_shopify
					)
					OR 
					-- Caso 3: Bolívar y Cartagena (caso especial)
					(
						@dpto_shopify  LIKE    '%bolivar%'
						AND
						(
							dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion))   LIKE    '%cartagena%'
							AND
							@ciudad_shopify LIKE '%cartagena%'
						)
					)
					OR
					-- Caso 4: Caso general (otros departamentos)
					(
						dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = @dpto_shopify
						AND 
						(
							@ciudad_shopify = dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion))
							OR 
							(
								NOT EXISTS (
									SELECT 1 FROM locaciones_erp l2
									WHERE 
										dbo.fn_RemoveAccentMarks(LOWER(l2.f011_descripcion))    =   @pais_shopify
										AND
										dbo.fn_RemoveAccentMarks(LOWER(l2.f012_descripcion))    =   @dpto_shopify
										AND
										@ciudad_shopify    =   dbo.fn_RemoveAccentMarks(LOWER(l2.f013_descripcion))
								)
								AND
								@ciudad_shopify    LIKE    '%' + dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) + '%'
							)
						)
					)
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
						THEN UPPER(JSON_VALUE(@json, '$.customer.default_address.name'))
					WHEN @client_origin_data	=	2	--	*	Desde la sección Billing Address
						THEN UPPER(JSON_VALUE(@json, '$.billing_address.name'))
					WHEN @client_origin_data	=	3	--	*	Desde la sección Customer o Billing Address
						THEN 
							ISNULL(
								UPPER(JSON_VALUE(@json, '$.customer.default_address.name')),
								UPPER(JSON_VALUE(@json, '$.billing_address.name'))
							)
					WHEN @client_origin_data	=	4	--	*	Desde la sección Billing Address o Customer
						THEN 
							ISNULL(
								UPPER(JSON_VALUE(@json, '$.billing_address.name')),
								UPPER(JSON_VALUE(@json, '$.customer.default_address.name'))
							)
					ELSE ''
				END;

			DECLARE @nombre_cliente		NVARCHAR(40)	=
				CASE
					WHEN @client_origin_data	=	1	--	*	Desde la sección Customer
						THEN UPPER(JSON_VALUE(@json, '$.customer.default_address.first_name'))
					WHEN @client_origin_data	=	2	--	*	Desde la sección Billing Address
						THEN UPPER(JSON_VALUE(@json, '$.billing_address.first_name'))
					WHEN @client_origin_data	=	3	--	*	Desde la sección Customer o Billing Address
						THEN 
							ISNULL(
								UPPER(JSON_VALUE(@json, '$.customer.default_address.first_name')),
								UPPER(JSON_VALUE(@json, '$.billing_address.first_name'))
							)
					WHEN @client_origin_data	=	4	--	*	Desde la sección Billing Address o Customer
						THEN 
							ISNULL(
								UPPER(JSON_VALUE(@json, '$.billing_address.first_name')),
								UPPER(JSON_VALUE(@json, '$.customer.default_address.first_name'))
							)
					ELSE ''
				END;

			DECLARE @apellidos_cliente	NVARCHAR(80)	=	
				CASE
					WHEN @client_origin_data	=	1	--	*	Desde la sección Customer
						THEN UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name'))
					WHEN @client_origin_data	=	2	--	*	Desde la sección Billing Address
						THEN UPPER(JSON_VALUE(@json, '$.billing_address.last_name'))
					WHEN @client_origin_data	=	3	--	*	Desde la sección Customer o Billing Address
						THEN 
							ISNULL(
								UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name')),
								UPPER(JSON_VALUE(@json, '$.billing_address.last_name'))
							)
					WHEN @client_origin_data	=	4	--	*	Desde la sección Billing Address o Customer
						THEN 
							ISNULL(
								UPPER(JSON_VALUE(@json, '$.billing_address.last_name')),
								UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name'))
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
			SELECT
				F200_ID					=	LEFT(@id_cliente, 15),
				F200_NIT				=	LEFT(@id_cliente, 25),
				F200_ID_TIPO_IDENT		=	'',
				F200_IND_TIPO_TERCERO	=	'',
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
				F015_CELULAR			=	LEFT(@telefono_cliente, 50);

			/*
			*	TODO EN DESARROLLO
			DECLARE @clientes TABLE (
				F201_ID_TERCERO				NVARCHAR(100),
				F201_DESCRIPCION_SUCURSAL	NVARCHAR(100),
				F201_ID_LISTA_PRECIO		NVARCHAR(20),
				F015_CONTACTO				NVARCHAR(50),
				F015_DIRECCION1				NVARCHAR(40),
				F015_DIRECCION2				NVARCHAR(40),
				F015_ID_PAIS				NVARCHAR(3),
				F015_ID_DEPTO				NVARCHAR(2),
				F015_ID_CIUDAD				NVARCHAR(3),
				F015_TELEFONO				NVARCHAR(20),
				F015_EMAIL					NVARCHAR(255),
				F201_FECHA_INGRESO			NVARCHAR(8),
				F015_CELULAR				NVARCHAR(50)
			)
			*/

			/*
				*	Sección de clientes del conector
			*/
			/*
			*	TODO EN DESARROLLO
			SELECT 
				F201_ID_TERCERO				=	@id_cliente,
				F201_DESCRIPCION_SUCURSAL	=	@razon_social,
				F201_ID_LISTA_PRECIO		=	'',
				F015_CONTACTO				=	@razon_social,
				F015_DIRECCION1				=	@direccion_1_shopify,
				F015_DIRECCION2				=	@direccion_2_shopify,
				F015_ID_PAIS				=	@id_pais_erp,
				F015_ID_DEPTO				=	@id_dptos_erp,
				F015_ID_CIUDAD				=	@id_ciudad_erp,
				F015_TELEFONO				=	@telefono_cliente,
				F015_EMAIL					=	@email_cliente,
				F201_FECHA_INGRESO			=	@fecha_creacion,
				F015_CELULAR				=	@telefono_cliente;
			*/
			
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
						/*
						*	TODO EN DESARROLLO
						,
						[Clientes] = (
							SELECT *
							FROM @clientes
							FOR JSON PATH,
							INCLUDE_NULL_VALUES
						),
						[Imptos y Reten] = (
							SELECT 
								@id_cliente as F_ID_TERCERO
      						FOR JSON PATH,
							INCLUDE_NULL_VALUES
    					),
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