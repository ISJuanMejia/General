---QUERY TERCEROS CLEMONT CON REMOVEACCENTMARKS---
 
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
	DECLARE	@idDocumento			INT			=	'228302',
			@descripcionConector	VARCHAR(50)	=	'Terceros_Cliente_Clemont',
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
	DECLARE @process_client_without_id	BIT	=	1;

	/*
		*	Id tipo de cliente:
		*		C004	->	id_tipo_cliente Addi
		*		C001	->	id_tipo_cliente Manual
		*		C008	->	id_tipo_cliente Mercado Libre
		*		C006	->	id_tipo_cliente Gift Card
		*		C005	->	id_tipo_cliente Sistecredito
		*		C009	->	id_tipo_cliente Wompi
		*		C013	->	id_tipo_cliente Bold
	*/
	DECLARE @id_tipo_cliente_addi           NVARCHAR(4) =   'C004',
            @id_tipo_cliente_manual         NVARCHAR(4) =   'C001',
            @id_tipo_cliente_MercadoLibre	NVARCHAR(4) =   'C008',
            @id_tipo_cliente_GiftCard       NVARCHAR(4) =   'C006',
            @id_tipo_cliente_Sistecredito	NVARCHAR(4) =   'C005',
            @id_tipo_cliente_Wompi          NVARCHAR(4) =   'C009',
            @id_tipo_cliente_Bold	        NVARCHAR(4) =   'C013';
    
    DECLARE @id_pais_defecto	NVARCHAR(3)	=	'',
			@id_dpto_defecto	NVARCHAR(3)	=	'',
			@id_ciudad_defecto	NVARCHAR(3)	=	'';
    
    /*
		*	Definición de variables para la obtención de la ubicación desde Shopify
		*		1 = Obtener la ubicación desde la sección Customer.Default_Address
		*		2 = Obtener la ubicación desde la sección Billing_Address
		*		3 = Obtener la ubicación desde la sección Shipping_Address
        *		4 = Obtener la ubicación desde la sección Customer.Default_Address y si no la encuentra, la obtiene desde 
        *           Billing_Address
		*		5 = Obtener la ubicación desde la sección Billing_Address y si no la encuentra, la obtiene desde 
        *           Customer.Default_Address
	*/
	DECLARE @location_origin_data	INT	=	5;

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
		F201_ID_TIPO_CLI			NVARCHAR(4),
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
		F_ID_TERCERO		NVARCHAR(15)
	);
	
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
		intentos	<=	3;

--->================================================================================================================<---

	/*
		*	Definición de variables para el procesamiento de las órdenes
	*/
	DECLARE @order		NVARCHAR(30);
	DECLARE @json		NVARCHAR(MAX)	= 	'';
	DECLARE @total		INT	=	(SELECT COUNT(*) FROM @ordenes);	--	*	Total de órdenes a procesar
	DECLARE @counter	INT	=	1;

--->================================================================================================================<---

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
			DECLARE @base_path NVARCHAR(100) =
            CASE 
                WHEN @location_origin_data = 1 THEN '$.customer.default_address'
                WHEN @location_origin_data = 2 THEN '$.billing_address'
                WHEN @location_origin_data = 3 THEN '$.shipping_address'
                WHEN @location_origin_data = 4 THEN
                    CASE
                        WHEN JSON_VALUE(@json, '$.customer.default_address.city') IS NOT NULL
                            THEN '$.customer.default_address'
                        ELSE '$.billing_address'
                    END
                WHEN @location_origin_data = 5 THEN
                    CASE
                        WHEN JSON_VALUE(@json, '$.billing_address.city') IS NOT NULL
                            THEN '$.billing_address'
                        ELSE '$.customer.default_address'
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

            DECLARE @id_tipo_cli    NVARCHAR(4) =   @id_tipo_cliente_manual;
 
            SELECT TOP 1
                @id_tipo_cli =
                    CASE
                        WHEN    JSON_VALUE(transaccion_obj, '$.gateway') = 'Addi Payment'
                            THEN    @id_tipo_cliente_addi
                        WHEN    JSON_VALUE(transaccion_obj, '$.gateway') IN ('Checkout Mercado Pago', 'Pago TC MercadoPago', 'Pago TD MercadoPago')
                            THEN    @id_tipo_cliente_MercadoLibre
                        WHEN    JSON_VALUE(transaccion_obj, '$.gateway') = 'gift_card'
                            THEN    @id_tipo_cliente_GiftCard
                        WHEN    JSON_VALUE(transaccion_obj, '$.gateway') = 'Sistecredito'
                            THEN    @id_tipo_cliente_Sistecredito
                        WHEN    JSON_VALUE(transaccion_obj, '$.gateway') = 'Wompi'
                            THEN    @id_tipo_cliente_Wompi
                        WHEN    JSON_VALUE(transaccion_obj, '$.gateway') LIKE '%Bold%'
                            THEN    @id_tipo_cliente_Bold
                        ELSE    @id_tipo_cliente_manual
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
				F200_RAZON_SOCIAL		=	LEFT(@razon_social, 100),
				F200_APELLIDO1			=	LEFT(@apellido_1_cliente, 29),
				F200_APELLIDO2			=	LEFT(@apellido_2_cliente, 29),
				F200_NOMBRES			=	LEFT(@nombre_cliente, 40),
				F200_NOMBRE_EST			=	LEFT(@nombre_cliente, 50),
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
			INSERT INTO @clientes
			(
                F201_ID_TERCERO,
                F201_DESCRIPCION_SUCURSAL,
                F201_ID_TIPO_CLI,
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
				F201_ID_TIPO_CLI			=	@id_tipo_cli,
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
				F_ID_TERCERO
			)
			SELECT
				F_ID_TERCERO	=	LEFT(@id_cliente, 15);
 
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
 
    SELECT * from @final AS final_json;
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
END CATCH