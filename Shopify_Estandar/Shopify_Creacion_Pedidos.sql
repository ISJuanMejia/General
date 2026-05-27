
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
			@descripcionConector	VARCHAR(50)	=	'Ecommerce_Pedidos',
			@indicaParalelismo		BIT			=	0;

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
		*	
		*	Nota: Debe dejarse igual que lo que se coloque en la consulta de terceros.
	*/
	DECLARE @client_origin_data	INT	=	4;

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

--->================================================================================================================<---

	/*
		*	Definición de la sección de pedidos del conector
	*/
	DECLARE @pedidos	TABLE (
        f430_consec_docto           INT,
		f430_fecha_entrega          NVARCHAR(8),
        f430_id_co                  NVARCHAR(3),
        f430_id_co_fact             NVARCHAR(3),
        f430_id_cond_pago           NVARCHAR(3),
		f430_id_fecha               NVARCHAR(8),
        f430_id_sucursal_fact       NVARCHAR(3),
        f430_id_sucursal_rem        NVARCHAR(3),
		f430_id_tercero_fact        NVARCHAR(15),
		f430_id_tercero_rem         NVARCHAR(15),
        f430_id_tercero_vendedor    NVARCHAR(15),
        f430_id_tipo_cli_fact       NVARCHAR(4),
        f430_id_tipo_docto          NVARCHAR(3),
        f430_ind_estado             INT,
        f430_ind_backorder          INT,
		f430_notas                  NVARCHAR(2000),
		f430_num_dias_entrega		NVARCHAR(3),
        f430_num_docto_referencia   NVARCHAR(15),
		f430_referencia             NVARCHAR(10)
	);

	/*
		*	Definición de la sección de movimientos pedidos comercial del conector
	*/
	DECLARE @movto_pedidos_comercial	TABLE (
		f431_cant_pedida_base   DECIMAL(20, 4),
		f431_codigo_barras      NVARCHAR(20),
		f431_consec_docto       INT,
		f431_fecha_entrega      NVARCHAR(8),
		f431_id_bodega          NVARCHAR(5),
		f431_id_ccosto_movto    NVARCHAR(15),
		f431_id_co              NVARCHAR(3),
		f431_id_co_movto        NVARCHAR(3),
		f431_id_ext1_detalle    NVARCHAR(20),
		f431_id_ext2_detalle    NVARCHAR(20),
		f431_id_item            INT,
		f431_id_lista_precio    NVARCHAR(3),
		f431_id_motivo          NVARCHAR(2),
		f431_id_un_movto        NVARCHAR(20),
		f431_id_tipo_docto      NVARCHAR(3),
		f431_id_unidad_medida   NVARCHAR(4),
		f431_ind_backorder      INT,
		f431_ind_impto_asumido  INT,
		f431_ind_obsequio		INT,
		f431_ind_precio         INT,
		f431_notas              NVARCHAR(255),
		f431_nro_registro       INT,
		f431_num_dias_entrega   INT,
		f431_precio_unitario    DECIMAL(20, 4),
		f431_referencia_item    NVARCHAR(50)
	);

	/*
		*	Definición de la sección de descuentos del conector
	*/
	DECLARE @descuentos	TABLE (
		f430_consec_docto   INT,
		f430_id_co          NVARCHAR(3),
		f430_id_tipo_docto	NVARCHAR(3),
		f431_nro_registro	INT,
		f432_tasa			DECIMAL(7, 4),
		f432_vlr_uni		DECIMAL(20, 4)
	);

	/*
		*	Definición de la sección de criterios clientes del conector
	*/
	DECLARE @impuestos	TABLE (
		F430_CONSEC_DOCTO           INT,
		F430_ID_CO			        NVARCHAR(3),
		F433_ID_LLAVE_IMPUESTO      NVARCHAR(4),
		F433_ID_LLAVE_IMPUESTO_DESC	NVARCHAR(4),
		F430_ID_TIPO_DOCTO          NVARCHAR(3),
		F433_IND_ACCION	            INT,
		F433_IND_CALCULO            INT,
		F433_IND_DESCONTABLE        INT,
		F431_NRO_REGISTRO           INT,
		F433_PORCENTAJE_BASE	    DECIMAL(7, 4),
		F433_PORCENTAJE_BASE_DESC	DECIMAL(7, 4),
		F433_PORC_IMP_VALOR_DESC	DECIMAL(7, 4),
		F433_TASA                   DECIMAL(7, 4),
		F433_TASA_DESC	            DECIMAL(7, 4),
		F433_VLR_UNI                DECIMAL(20, 4)
	);
	
--->================================================================================================================<---

	DECLARE @ordenes TABLE (
		id_orden	NVARCHAR(20),
		orden_obj	NVARCHAR(MAX)
	);

	/*
		*	Obtener órdenes pendientes de procesamiento que se encuentran en estado 2 y 
		*	tienen menos de 3 intentos de procesamiento
	*/
	INSERT INTO @ordenes (id_orden, orden_obj)
	SELECT TOP (@batch_size)
		id_orden, 
		orden_obj
	FROM ordenes 
	WHERE 
		id_estado	=	2
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