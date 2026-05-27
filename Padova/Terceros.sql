/*
# Integración de terceros y clientes Padova desde órdenes pendientes

SECCIÓN: Descripción general

* Este procedimiento procesa órdenes pendientes del cliente **Padova** (máximo 3 intentos, estado = 1)
  para generar la información de terceros, clientes e impuestos que será integrada
  al sistema ERP **Siesa**, a partir de órdenes provenientes de **Shopify**.
* La información se extrae de la estructura JSON de las órdenes, se normaliza y se adapta
  a los códigos internos de país, departamento y ciudad.
* El resultado final es un JSON estructurado que agrupa:

  * Terceros
  * Clientes
  * Impuestos y retenciones
    (Las secciones de criterios y entidad dinámica se encuentran comentadas para uso opcional).

===========================================================
SECCIÓN: Variables principales

* @idDocumento, @descripcionConector, @indicaParalelismo:
  Identifican el conector **Tercero_Cliente_Padova_Shopify** y determinan si admite paralelismo.
* Variables de sucursal, moneda, listas de precios y centro de operaciones:
  Definen la configuración comercial para clientes nacionales (COP) y extranjeros (USD).
* @ordenes:
  Tabla temporal que almacena las órdenes pendientes de Padova a procesar.
* @Terceros, @Cliente, @Impuestos:
  Tablas temporales que almacenan la información procesada antes de generar el JSON final.

===========================================================
SECCIÓN: Flujo del proceso

1. **Obtención de órdenes pendientes**

   * Se consultan las órdenes de Padova con estado = 1 e intentos ≤ 3.
   * Se cargan en la tabla temporal @ordenes y se calcula el total a procesar.

2. **Iteración por cada orden**

   * Se obtiene el JSON de la orden y se extraen datos clave del cliente:

     * País, departamento y ciudad de facturación.
     * Identificación, razón social, nombres y apellidos.
     * Dirección, teléfono y correo electrónico.
     * Tipo de cliente según moneda (COP = nacional, USD = extranjero).
     * Fecha de creación del cliente en Shopify.
   * Se homologan los datos geográficos contra la tabla de locaciones de Siesa.

3. **Construcción de tablas temporales**

   * **@Tercero**:

     * Información general del tercero/cliente (identificación, razón social,
       nombres, direcciones y datos de contacto).
   * **@Cliente**:

     * Información comercial del cliente Padova, incluyendo moneda,
       tipo de cliente, lista de precios y centro de operaciones.
   * **@Impuestos**:

     * Asociación básica de impuestos/retenciones por tercero.

4. **Generación del JSON final**

   * Por cada orden se genera un registro en @final con:

     * idDocumento del conector.
     * Descripción del conector Padova.
     * Indicador de paralelismo.
     * Id de la orden (Shopify).
     * JSON estructurado con Terceros, Clientes e Impuestos.

5. **Limpieza de tablas temporales**

   * Al finalizar cada iteración se limpian las tablas temporales para continuar
     con la siguiente orden.

6. **Manejo de errores**

   * Si ocurre un error al procesar una orden de Padova, se limpian las tablas
     temporales y se continúa con la siguiente.
   * Si el error es general, se retorna un mensaje con el detalle del error.

==================================================================
Fin de la documentación del procedimiento [TERCERO_CLIENTE_PADOVA]
==================================================================
*/

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
	DECLARE	@idDocumento			INT			=	'220762',
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

	/*
		*	Procesar clientes/terceros sin ID
		*		0 = No procesar clientes/terceros sin ID, incrementar el contador de intentos
		*		1 = Procesar clientes/terceros sin ID, cambiar el estado de la orden de 1 a 2 y colocar intentos a 0
	*/
	DECLARE @process_client_without_id	BIT	=	1;

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
		*	Id sucursal:
		*		001	->	Clientes nacionales
		*		002	->	Clientes extranjeros
	*/
	DECLARE @id_sucursal_cop	NVARCHAR(3) =   '001',
            @id_sucursal_usd	NVARCHAR(3) =   '002';
    
    /*
		*	Id tipo de cliente:
		*		0001	->	Clientes nacionales
		*		0002	->	Clientes extranjeros
	*/
	DECLARE @id_tipo_cliente_nacional   NVARCHAR(4) =   '0001',
            @id_tipo_cliente_extranjero NVARCHAR(4) =   '0002';
    
    /*
		*	Id lista de precios:
		*		001	->	Lista de precios COP
		*		002	->	Lista de precios USD
	*/
	DECLARE @id_lista_precios_cop   NVARCHAR(3) =   '001',
            @id_lista_precios_usd   NVARCHAR(3) =   '002';

    /*
		*	Id valor tercero en impuestos y retenciones:
		*		1	->	Id valor tercero COP
		*		0	->	Id valor tercero USD
	*/
	DECLARE @f_id_valor_tercero_cop   NVARCHAR(2) =   '1',
            @f_id_valor_tercero_usd   NVARCHAR(2) =   '0';

    /*
		*	Id maestro detalle tercero en entidades dinamicas tercero:
		*		10	->	Residente
		*		11	->	No residente
	*/
	DECLARE @id_maestro_detalle_tercero_cop   NVARCHAR(2) =   '10',
            @id_maestro_detalle_tercero_usd   NVARCHAR(2) =   '11';

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
    DECLARE @Terceros TABLE (
        F200_ID                 NVARCHAR(15),
        F200_NIT                NVARCHAR(25),
        F200_RAZON_SOCIAL       NVARCHAR(100),
        F200_APELLIDO1          NVARCHAR(29),
        F200_APELLIDO2          NVARCHAR(29),
        F200_NOMBRES            NVARCHAR(40),
        F200_NOMBRE_EST         NVARCHAR(50),
        F015_CONTACTO           NVARCHAR(50),
        F015_DIRECCION1         NVARCHAR(40),
        F015_DIRECCION2         NVARCHAR(40),
        F015_ID_PAIS            NVARCHAR(3),
        F015_ID_DEPTO           NVARCHAR(2),
        F015_ID_CIUDAD          NVARCHAR(3),
        F015_TELEFONO           NVARCHAR(20),
        F015_EMAIL              NVARCHAR(255),
        F200_FECHA_NACIMIENTO   NVARCHAR(8),
        F015_CELULAR            NVARCHAR(50)
    );

    /*
		*	Definición de la sección de clientes del conector
	*/
    DECLARE @Clientes TABLE (
        F201_ID_TERCERO             NVARCHAR(15),
		F201_ID_SUCURSAL			NVARCHAR(3),
        F201_DESCRIPCION_SUCURSAL   NVARCHAR(40),
        F201_ID_MONEDA              NVARCHAR(3),
        F201_ID_TIPO_CLI            NVARCHAR(4),
        F201_ID_LISTA_PRECIO        NVARCHAR(3),
        F015_CONTACTO               NVARCHAR(50),
        F015_DIRECCION1             NVARCHAR(40),
        F015_DIRECCION2             NVARCHAR(40),
        F015_ID_PAIS                NVARCHAR(3),
        F015_ID_DEPTO               NVARCHAR(2),
        F015_ID_CIUDAD              NVARCHAR(3),
        F015_TELEFONO               NVARCHAR(20),
        F015_EMAIL                  NVARCHAR(255),
        F201_FECHA_INGRESO          NVARCHAR(8),
        f015_celular                NVARCHAR(50)
    );

    /*
		*	Definición de la sección de impuestos y retenciones del conector
	*/
	DECLARE @Imptos_y_Reten	TABLE (
		F_ID_TERCERO		NVARCHAR(15),
		F_ID_SUCURSAL		NVARCHAR(3),
        F_ID_VALOR_TERCERO  NVARCHAR(2)
	);

    /*
		*	Definición de la sección de entidades dinamicas tercero del conector
	*/
	DECLARE @Ent_Dinamica_Tercero	TABLE (
		f200_id					NVARCHAR(15),
		f753_id_maestro_detalle	NVARCHAR(20)
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
	FROM [shopify-colombia-padova].dbo.ordenes 
	WHERE 
		-- id_estado	=	1
		-- AND
		-- intentos	<=	3;
		id_orden = '#22325'

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

			DECLARE @direccion_1_erp	NVARCHAR(400)	=
				LEFT(@direccion_1_shopify, 40);

			DECLARE @direccion_2_shopify NVARCHAR(255) =
				UPPER(
					JSON_VALUE(@json, @base_path + '.address2')
				);

			DECLARE @direccion_2_erp	NVARCHAR(400)	=
				LEFT(	
					CASE
						WHEN
							LTRIM(
								SUBSTRING(
									@direccion_1_shopify,
									40,
									LEN(
										@direccion_1_shopify
									)
								)
							) != ''
							THEN
							LTRIM(
								SUBSTRING(
									@direccion_1_shopify,
									40,
									LEN(
										@direccion_1_shopify
									)
								)
							) + ' - '
						END +
					@direccion_2_shopify,
					40
				);

			DECLARE @id_pais_erp	NVARCHAR(3);
			DECLARE @id_dptos_erp	NVARCHAR(2);
			DECLARE @id_ciudad_erp	NVARCHAR(3);

            SELECT
				@id_pais_erp	=	id_pais_erp,
				@id_dptos_erp	=	id_dptos_erp,
				@id_ciudad_erp	=	id_ciudad_erp
            FROM [shopify-colombia-padova].dbo.fn_GetLocationIds(
                @pais_shopify,      -- país
                @dpto_shopify,      -- departamento
                @ciudad_shopify,    -- ciudad
                @id_pais_defecto,   -- id_pais_defecto
                @id_dpto_defecto,   -- id_depto_defecto
                @id_ciudad_defecto  -- id_ciudad_defecto
            );

			SET @order	=	JSON_VALUE(@json, '$.name');	--	*	Obtener el número de la ordenn

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
				UPDATE [shopify-colombia-padova].dbo.ordenes
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

            DECLARE @id_moneda  NVARCHAR(3) =
                UPPER(
                    JSON_VALUE(@json,'$.presentment_currency')
                );
                
            DECLARE @id_sucursal	NVARCHAR(3) =
                CASE
                    WHEN @id_moneda =   'USD'
                        THEN @id_sucursal_usd
                    ELSE @id_sucursal_cop
                END;

			
			DECLARE @id_tipo_cli    NVARCHAR(4) =
                CASE
                    WHEN @id_moneda =   'USD'
                        THEN @id_tipo_cliente_extranjero
                    ELSE @id_tipo_cliente_nacional
                END;

            DECLARE @id_lista_precios NVARCHAR(3) = 
                CASE
                    WHEN @id_moneda =   'USD'
                        THEN @id_lista_precios_usd
                    ELSE @id_lista_precios_cop
                END;
            
            DECLARE @f_id_valor_tercero NVARCHAR(2) =
                CASE
                    WHEN @id_moneda =   'USD'
                        THEN @f_id_valor_tercero_usd
                    ELSE @f_id_valor_tercero_cop
                END;
            
            DECLARE @id_maestro_detalle_tercero NVARCHAR(2) =
                CASE
                    WHEN @id_moneda =   'USD'
                        THEN @id_maestro_detalle_tercero_usd
                    ELSE @id_maestro_detalle_tercero_cop
                END;

			-- ===============================
			-- INSERT TERCERO
			-- ===============================
			INSERT INTO @Terceros
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
				F200_ID                 =   @id_cliente,
				F200_NIT                =   @id_cliente,
				F200_RAZON_SOCIAL       =   @razon_social,
				F200_APELLIDO1          =   @apellido_1_cliente,
				F200_APELLIDO2          =   @apellido_2_cliente,
				F200_NOMBRES            =   @nombre_cliente,
				F200_NOMBRE_EST         =   @razon_social,
				F015_CONTACTO           =   @razon_social,
				F015_DIRECCION1         =   @direccion_1_erp,
				F015_DIRECCION2         =   @direccion_2_erp,
				F015_ID_PAIS            =   @id_pais_erp,
				F015_ID_DEPTO           =   @id_dptos_erp,
				F015_ID_CIUDAD          =   @id_ciudad_erp,
				F015_TELEFONO           =   @telefono_cliente,
				F015_EMAIL              =   @email_cliente,
				F200_FECHA_NACIMIENTO   =   @fecha_creacion,
				F015_CELULAR            =   @telefono_cliente;

			/*
				*	Sección de clientes del conector
			*/
			INSERT INTO @Clientes
			(
				F015_CONTACTO,
				F201_ID_SUCURSAL,
				F201_ID_LISTA_PRECIO,
				F015_DIRECCION1,
				F015_DIRECCION2,
				F015_ID_PAIS,
				F015_ID_DEPTO,
				F015_ID_CIUDAD,
				F015_TELEFONO,
				F015_EMAIL,
				F201_FECHA_INGRESO,
				f015_celular,
				F201_ID_TERCERO,
				F201_DESCRIPCION_SUCURSAL,
				F201_ID_MONEDA,
				F201_ID_TIPO_CLI
			)
			SELECT
				F015_CONTACTO				=	LEFT(@razon_social, 50),
				F201_ID_SUCURSAL			=	@id_sucursal,
				F201_ID_LISTA_PRECIO		=	@id_lista_precios,
				F015_DIRECCION1				=	@direccion_1_erp,
				F015_DIRECCION2				=	@direccion_2_erp,
				F015_ID_PAIS				=	LEFT(@id_pais_erp, 3),
				F015_ID_DEPTO				=	LEFT(@id_dptos_erp, 2),
				F015_ID_CIUDAD				=	LEFT(@id_ciudad_erp, 3),
				F015_TELEFONO				=	LEFT(@telefono_cliente, 20),
				F015_EMAIL					=	LEFT(@email_cliente, 255),
				F201_FECHA_INGRESO			=	@fecha_creacion,
				f015_celular				=	LEFT(@telefono_cliente, 50),
				F201_ID_TERCERO				=	LEFT(@id_cliente, 15),
				F201_DESCRIPCION_SUCURSAL	=	LEFT(@razon_social, 40),
				F201_ID_MONEDA				=	@id_moneda,
				F201_ID_TIPO_CLI			=	@id_tipo_cli;

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
				F_ID_SUCURSAL,
                F_ID_VALOR_TERCERO
			)
			SELECT
				F_ID_TERCERO	    =	LEFT(@id_cliente, 15),
				F_ID_SUCURSAL		=	@id_sucursal,
                F_ID_VALOR_TERCERO  =   @f_id_valor_tercero;

            /*
				*	Sección de Entidades dinamicas del tercero del conector
			*/
            INSERT INTO @Ent_Dinamica_Tercero
            (
                f200_id,
                f753_id_maestro_detalle
            )
            SELECT
                f200_id                 =   LEFT(@id_cliente, 15),
                f753_id_maestro_detalle =   @id_maestro_detalle_tercero;
            
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
							FROM @Terceros
							FOR JSON PATH,
							INCLUDE_NULL_VALUES
						)
						,
						[Clientes] = (
							SELECT *
							FROM @Clientes
							FOR JSON PATH,
							INCLUDE_NULL_VALUES
						),
						[Imptos y Reten] = (
							SELECT *
							FROM @Imptos_y_Reten
      						FOR JSON PATH,
							INCLUDE_NULL_VALUES
    					),
						[Ent Dinamica Tercero] = (
							SELECT *
							FROM @Ent_Dinamica_Tercero
      						FOR JSON PATH,
							INCLUDE_NULL_VALUES
    					)
					FOR JSON PATH,
					WITHOUT_ARRAY_WRAPPER,
					INCLUDE_NULL_VALUES
				);

			SET @counter = @counter + 1;
			DELETE @Terceros;
			DELETE @Clientes;
			DELETE @Imptos_y_Reten;
			DELETE @Ent_Dinamica_Tercero;
        END TRY
		BEGIN CATCH
			--	*	Registrar el error en la orden y continuar con la siguiente

			-- SELECT 
			-- 	indicaError         =   CAST(1 AS BIT), 
			-- 	descripcionError    =   CONCAT('Error: ', ERROR_MESSAGE()),
			-- 	ErrorNumber         =   ERROR_NUMBER(),
			-- 	ErrorSeverity       =   ERROR_SEVERITY(),
			-- 	ErrorState          =   ERROR_STATE(),
			-- 	ErrorProcedure      =   ERROR_PROCEDURE(),
			-- 	ErrorLine           =   ERROR_LINE(),
			-- 	ErrorMessage        =   ERROR_MESSAGE();

			UPDATE [shopify-colombia-padova].dbo.ordenes
			SET 
				intentos	=	intentos + 1
			WHERE 
				id_orden	=	@order;
		END CATCH;

		SET @counter = @counter + 1;
		DELETE @Terceros;
		DELETE @Clientes;
		DELETE @Imptos_y_Reten;
		DELETE @Ent_Dinamica_Tercero;
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
