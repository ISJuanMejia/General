/*	MARÍA SALOMÉ - CREACIÓN TERCEROS

	Descripción general:
	Este script realiza la integración de clientes (terceros) provenientes de órdenes de Shopify hacia el sistema Siesa, generando la estructura de datos necesaria para la creación de terceros, clientes, impuestos y retenciones, criterios de clasificación y entidades dinámicas, todo en formato JSON para su posterior procesamiento.

	Flujo principal:
	1. Obtiene la configuración de conexión y base de datos desde la tabla 'conexiones'.
	2. Recupera hasta 25 órdenes pendientes de integración desde la tabla 'ordenes'.
	3. Para cada orden:
		- Extrae y transforma los datos del cliente y su dirección desde el objeto JSON de la orden.
		- Realiza la normalización y limpieza de datos (acentos, mayúsculas, espacios, etc.).
		- Determina los códigos de país, departamento y ciudad según la información de la dirección.
		- Construye los registros para las tablas temporales de terceros, clientes, impuestos y retenciones, criterios de clasificación y entidades dinámicas.
		- Consulta información adicional de ciudades y criterios de clasificación según la ubicación.
		- Genera un objeto JSON consolidado con toda la información estructurada.
		- Inserta el resultado en la tabla temporal @final.
	4. Maneja errores mediante TRY...CATCH, devolviendo información descriptiva en caso de fallo.
	5. Al finalizar, retorna todos los registros generados en @final.

	Tablas temporales utilizadas:
	- @tercero: Información básica del tercero (cliente).
	- @cliente: Información específica del cliente.
	- @impuestos_y_retenciones: Estructura para impuestos y retenciones asociadas.
	- @entidades_dinamicas: Información dinámica adicional del cliente.
	- @criterios_clasificacion: Criterios de clasificación del cliente según ubicación y tags.
	- @final: Resultado final en formato JSON para cada orden procesada.

	Consideraciones:
	- Se realiza limpieza y normalización de datos para evitar errores de integración.
	- Se contemplan casos especiales para ciudades como Bogotá y Cartagena.
	- El script está preparado para ejecutarse en modo batch sobre varias órdenes.
	- Utiliza funciones auxiliares como dbo.fn_RemoveAccentMarks y dbo.fn_KeepNumbersHyphen para el tratamiento de cadenas.
	- El resultado final es un JSON estructurado listo para ser consumido por el conector de Siesa.

	Parámetros importantes:
	- @cliente_ocasional: ID por defecto para clientes sin identificación válida.
	- @idDocumento, @descripcionConector, @indicaParalelismo: Metadatos para el proceso de integración.

	Errores:
	- En caso de error, retorna un registro con indicaError = 1 y la descripción del error.
*/
BEGIN TRY
    /*
        *   Declaración de variable que va a contener el resultado de la consulta
    */
	DECLARE @final TABLE (
		idDocumento			INT,
        indicaParalelismo	BIT,
        descripcion		    VARCHAR(50),
        idOrden			    VARCHAR(50),
        json				VARCHAR(MAX)
	);

    /*
        *   Declaración de las variables que contienen la información del conector a utilizar y si las peticiones se 
        *   realizarán paralelamente o secuencialmente
    */
	DECLARE	@idDocumento			INT			=	203310,
            @descripcionConector	VARCHAR(50)	=	'TERCERO_CLIENTE_INTEGRACION',
            @indicaParalelismo		BIT			=	1;

    /*
		*	Definición de variables para la obtención de la ubicación desde Shopify
		*		1 = Obtener la ubicación desde la sección Customer.Default_Address
		*		2 = Obtener la ubicación desde la sección Billing_Address
		*		3 = Obtener la ubicación desde la sección Shipping_Address
	*/
	DECLARE @location_origin_data	INT	=	1;

    /*
        *   Obtener cadena de conexión a la base de datos del ERP
    */
	DECLARE	@conexion	NVARCHAR(MAX),
            @base_datos	NVARCHAR(MAX);

	SELECT TOP 1 
		@conexion	=	cadena_conexion,
        @base_datos =	base_datos
	FROM conexiones;

    /*
        *   Definición con variables con valores por defecto
    */
    DECLARE @id_pais_defecto	NVARCHAR(3)	    =	'169',	    --	*	Colombia
			@id_dpto_defecto	NVARCHAR(3)	    =	'05',	    --	*	Antioquia
			@id_ciudad_defecto	NVARCHAR(3)	    =	'999',	    --	*	Medellín
	        @cliente_ocasional  NVARCHAR(30)    =	'99999999'; --  *   Cliente ocasional

    /*
        *   Sección de terceros del conector
    */
	DECLARE	@tercero	TABLE(
		F200_ID					VARCHAR(15),
        F200_NIT				VARCHAR(25),
        F200_ID_TIPO_IDENT		VARCHAR(1),
        F200_IND_TIPO_TERCERO	VARCHAR(1),
        F200_RAZON_SOCIAL		VARCHAR(100),
        F200_APELLIDO1			VARCHAR(29),
        F200_APELLIDO2			VARCHAR(29),
        F200_NOMBRES			VARCHAR(40),
        F200_NOMBRE_EST		    VARCHAR(50),
        F015_CONTACTO			VARCHAR(50),
        F015_DIRECCION1		    VARCHAR(40),
        F015_DIRECCION2		    VARCHAR(40),
        F015_ID_PAIS			VARCHAR(3),
        F015_ID_DEPTO			VARCHAR(2),
        F015_ID_CIUDAD			VARCHAR(3),
        F015_TELEFONO			VARCHAR(20),
        F015_EMAIL				VARCHAR(255),
        F200_FECHA_NACIMIENTO	VARCHAR(8),
        F015_CELULAR			VARCHAR(50)
	);

    /*
        *   Sección de cliente del conector
    */
	DECLARE	@cliente	TABLE(
		F201_ID_TERCERO				VARCHAR(15),
        F201_DESCRIPCION_SUCURSAL	VARCHAR(40),
        F201_NOTAS					VARCHAR(255),
        F015_CONTACTO				VARCHAR(50),
        F015_DIRECCION1			    VARCHAR(40),
        F015_DIRECCION2			    VARCHAR(40),
        F015_ID_PAIS				VARCHAR(3),
        F015_ID_DEPTO				VARCHAR(2),
        F015_ID_CIUDAD				VARCHAR(3),
        F015_TELEFONO				VARCHAR(20),
        F015_EMAIL					VARCHAR(255),
        F201_FECHA_INGRESO			VARCHAR(8),
        f015_celular				VARCHAR(50)
	);

    /*
        *   Sección de impuestos y retenciones del conector
    */
	DECLARE	@impuestos_y_retenciones	TABLE(
		F_ID_TERCERO	VARCHAR(15),
        F_ID_LLAVE		VARCHAR(4)
	);

    /*
        *   Sección de entidades dinamicas del conector
    */
	DECLARE	@entidades_dinamicas	TABLE(
		f201_id_tercero	VARCHAR(15),
        f753_dato_texto VARCHAR(2000)
	);

    /*
        *   Sección de criterios de clasificacion del cliente del conector
    */
	DECLARE	@criterios_clasificacion	TABLE(
		F207_ID_TERCERO			NVARCHAR(25),
        F207_ID_PLAN_CRITERIOS	NVARCHAR(5),
        F207_ID_CRITERIO_MAYOR	NVARCHAR(5)
	);

    /*
        *   Tabla para validaciones de criterios de clasificación
    */
	DECLARE @criterios_ciudades	TABLE(
		plan_criterio_001	NVARCHAR(255),
        plan_criterio_002	NVARCHAR(255)   
	);

    /*
        *   Definición de la tabla que contendrá los pedidos por procesar
    */
	DECLARE	@Ordenes	TABLE(
		id_orden	VARCHAR(50),
        orden_obj	VARCHAR(MAX)
	);
	
	INSERT INTO @Ordenes
	SELECT TOP 100
		id_orden,
        orden_obj
	FROM ordenes 
	WHERE
		id_estado	=	1
		AND
		intentos	<=	3
        AND
        fecha_creacion  >   DATEADD(DAY, -15, GETDATE());
	
	DECLARE @json	NVARCHAR(MAX) = '';
	DECLARE @counter	INT = 1;
	DECLARE @total		INT;
	DECLARE @order		VARCHAR(30);
	SET @total = (SELECT COUNT(*) FROM @Ordenes);

	WHILE @counter <= @total
	BEGIN
        BEGIN TRY
            SET @json = (
                SELECT orden_obj
                FROM (
                    SELECT
                        orden_obj
                        ,ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                    FROM @Ordenes
                ) AS temp
                WHERE rn = @counter
            );

            DECLARE @na_tipo_doc                NVARCHAR(100)   =   NULL,
                    @na_documento               NVARCHAR(100)   =   NULL,
                    @na_email                   NVARCHAR(100)   =   NULL,
                    @na_telefono                NVARCHAR(100)   =   NULL,
                    @na_nombres                 NVARCHAR(100)   =   NULL,
                    @na_apellidos               NVARCHAR(100)   =   NULL,
                    @na_departamento            NVARCHAR(100)   =   NULL,
                    @na_ciudad                  NVARCHAR(100)   =   NULL,
                    @na_direccion_residencia    NVARCHAR(100)   =   NULL,
                    @na_direccion_residencia_2  NVARCHAR(100)   =   NULL,
                    @na_zoko_session_id         NVARCHAR(100)   =   NULL;

            SELECT
                @na_tipo_doc                =    MAX(CASE WHEN Nombre = 'tipodoc'                THEN Valor END),
                @na_documento               =    MAX(CASE WHEN Nombre = 'documento'              THEN Valor END),
                @na_email                   =    MAX(CASE WHEN Nombre = 'email'                  THEN Valor END),
                @na_telefono                =    MAX(CASE WHEN Nombre = 'telefono'               THEN Valor END),
                @na_nombres                 =    MAX(CASE WHEN Nombre = 'nombres'                THEN Valor END),
                @na_apellidos               =    MAX(CASE WHEN Nombre = 'apellidos'              THEN Valor END),
                @na_departamento            =    MAX(CASE WHEN Nombre = 'departamento'           THEN Valor END),
                @na_ciudad                  =    MAX(CASE WHEN Nombre = 'ciudad'                 THEN Valor END),
                @na_direccion_residencia    =    MAX(CASE WHEN Nombre = 'direccion_residencia'   THEN Valor END),
                @na_direccion_residencia_2  =    MAX(CASE WHEN Nombre = 'direccion_residencia_2' THEN Valor END),
                @na_zoko_session_id         =    MAX(CASE WHEN Nombre = 'zoko_session_id'        THEN Valor END)
            FROM
            (
                SELECT
                    Nombre = JSON_VALUE(value, '$.name'),
                    Valor  = JSON_VALUE(value, '$.value')
                FROM OPENJSON(@json, '$.note_attributes')
            ) AS NA;
            
            DECLARE @id_pais		    NVARCHAR(3)     =   NULL,
                    @id_departamento	NVARCHAR(3)     =   NULL,
                    @id_ciudad          NVARCHAR(3)     =   NULL,
                    @nombre_ciudad      NVARCHAR(20)    =   NULL;

            /*
				*	Variables para almacenar los valores de país, departamento, ciudad, dirección 1 y dirección 2 desde el pedido de Shopify
			*/
            IF (@na_departamento IS NULL AND @na_ciudad IS NULL AND @na_direccion_residencia IS NULL AND @na_direccion_residencia_2 IS NULL)
            BEGIN
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

                SELECT
                    @id_pais            =   NULL,
                    @id_departamento    =   NULL,
                    @id_ciudad          =   NULL,
                    @nombre_ciudad      =   NULL

                SELECT TOP 1
                    @id_pais		    =	ISNULL(f013_id_pais		,'169') ,
                    @id_departamento    =	ISNULL(f013_id_depto	,'05'),
                    @id_ciudad          =	ISNULL(f013_id			,'999'),
                    @nombre_ciudad      =   f013_descripcion
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
            END
            ELSE
            BEGIN
                SELECT
                    @id_pais                =   '169',
                    @id_departamento        =   @na_departamento,
                    @id_ciudad              =   RIGHT(LEFT(@na_ciudad, 5), 3),
                    @direccion_1_shopify    =   @na_direccion_residencia,
                    @direccion_2_shopify    =   @na_direccion_residencia_2;
                
                SELECT
                    @nombre_ciudad    =   f013_descripcion
                FROM locaciones_erp
                WHERE
                    f013_id_pais    =   '169'
                    AND
                    f013_id_depto   =   @id_departamento
                    AND
                    f013_id         =   @id_ciudad;
            END
        
            SELECT 
                @id_pais		    =	ISNULL(@id_pais, @id_pais_defecto),
                @id_departamento	=	ISNULL(@id_departamento, @id_dpto_defecto),
                @id_ciudad          =	ISNULL(@id_ciudad, @id_ciudad_defecto);

            SET	@order	=	JSON_VALUE(@json, '$.name');

            DECLARE @billing_address_company	NVARCHAR(100)	=   dbo.fn_KeepNumbersHyphen(JSON_VALUE(@json, '$.billing_address.company'));
            
            DECLARE @formatted_billing_address_company	NVARCHAR(100)	=
                REPLACE(
                    @billing_address_company
                    , '-'
                    , ''
                );
            
            DECLARE @customer_default_address_company	NVARCHAR(100)	=   dbo.fn_KeepNumbersHyphen(JSON_VALUE(@json, '$.customer.default_address.company'));

            DECLARE @formatted_customer_default_address_company	NVARCHAR(100)	=
                REPLACE(
                    @customer_default_address_company
                    , '-'
                    , ''
                );
        
            DECLARE	@F200_ID	NVARCHAR(40)	= 
                CASE
                    WHEN    @na_documento   IS NOT NULL
                        THEN    @na_documento
                    WHEN
                        @formatted_billing_address_company IS NOT NULL 
                        AND
                        @formatted_billing_address_company <> ''
                        THEN
                            @billing_address_company
                    WHEN
                        @formatted_customer_default_address_company IS NOT NULL 
                        AND
                        @formatted_customer_default_address_company <> ''
                        THEN
                            @customer_default_address_company
                    ELSE @cliente_ocasional
                END;
            
            SET @F200_ID = 
                CASE
                    WHEN dbo.fn_KeepNumbersHyphen(@F200_ID) = '' THEN @cliente_ocasional
                    ELSE dbo.fn_KeepNumbersHyphen(@F200_ID)
                END;

            IF @F200_ID != @cliente_ocasional
            BEGIN
                DECLARE @F200_ID_TIPO_IDENT NVARCHAR(10)    =
                    CASE
                        WHEN
                            @na_tipo_doc    =   'CC'
                            OR
                            @na_tipo_doc    IS  NULL
                            THEN    'C'
                        WHEN    @na_tipo_doc    !=  'CC'
                            THEN    'N'
                    END;
                
                DECLARE @F200_IND_TIPO_TERCERO  INT =
                    CASE
                        WHEN
                            @na_tipo_doc    =   'CC'
                            OR
                            @na_tipo_doc    IS  NULL
                            THEN    1
                        WHEN    @na_tipo_doc    !=  'CC'
                            THEN    2
                    END;

                DECLARE	@F200_RAZON_SOCIAL	NVARCHAR(100)	=
                    ISNULL(
                        UPPER(
                            dbo.fn_RemoveAccentMarks(
                                CASE
                                    WHEN @na_nombres    IS NOT NULL AND @na_apellidos IS NOT NULL
                                        THEN    CONCAT(@na_nombres, ' ', @na_apellidos)
                                    ELSE
                                        ISNULL(
                                            NULLIF(
                                                JSON_VALUE(@json, '$.billing_address.name')
                                                , ''
                                            )
                                            ,NULLIF(
                                                JSON_VALUE(@json, '$.customer.default_address.name')
                                                , ''
                                            )
                                        )
                                END
                            )
                        )
                        , 'NO INGRESADO'
                    )
                
                DECLARE	@F200_NOMBRE		NVARCHAR(40)	=
                    ISNULL(
                        NULLIF(
                            UPPER(
                                dbo.fn_RemoveAccentMarks(
                                    LEFT(
                                        CASE
                                            WHEN @na_nombres    IS NOT NULL AND @na_apellidos IS NOT NULL
                                                THEN    @na_nombres
                                            ELSE
                                                ISNULL(
                                                    NULLIF(
                                                        JSON_VALUE(@json, '$.billing_address.first_name')
                                                        , ''
                                                    )
                                                    ,JSON_VALUE(@json, '$.customer.default_address.first_name')
                                                )
                                        END, 
                                        40
                                    )
                                )
                            )
                            , ''
                        )
                        , 'NO INGRESADO'
                    )

                DECLARE @F200_APELLIDO1		NVARCHAR(29)	=
                    ISNULL(
                        UPPER(
                            dbo.fn_RemoveAccentMarks(
                                LEFT(
                                    LTRIM(
                                        RTRIM(
                                            LEFT(
                                                CASE
                                                    WHEN @na_nombres    IS NOT NULL AND @na_apellidos IS NOT NULL
                                                        THEN    @na_apellidos
                                                    ELSE
                                                        ISNULL(
                                                            NULLIF(
                                                                JSON_VALUE(@json, '$.billing_address.last_name')
                                                                , ''
                                                            )
                                                            ,NULLIF(
                                                                JSON_VALUE(@json, '$.customer.default_address.last_name')
                                                                , ''
                                                            )
                                                        )
                                                END,
                                                CHARINDEX(
                                                    ' ',
                                                    LTRIM(
                                                        RTRIM(
                                                            CASE
                                                                WHEN @na_nombres    IS NOT NULL AND @na_apellidos IS NOT NULL
                                                                    THEN    @na_apellidos
                                                                ELSE
                                                                    ISNULL(
                                                                        NULLIF(
                                                                            JSON_VALUE(@json, '$.billing_address.last_name')
                                                                            , ''
                                                                        )
                                                                        ,NULLIF(
                                                                            JSON_VALUE(@json, '$.customer.default_address.last_name')
                                                                            , ''
                                                                        )
                                                                    )
                                                            END
                                                        )
                                                    ) + ' '
                                                )
                                            )
                                        )
                                    ), 29
                                )
                            )
                        )
                        , 'NO INGRESADO'
                    )

                DECLARE @F200_APELLIDO2		NVARCHAR(40)	=
                    UPPER(
                        dbo.fn_RemoveAccentMarks(
                            LEFT(
                                LTRIM(
                                    SUBSTRING(
                                        LTRIM(
                                            RTRIM(
                                                CASE
                                                    WHEN @na_nombres    IS NOT NULL AND @na_apellidos IS NOT NULL
                                                        THEN    @na_apellidos
                                                    ELSE
                                                        ISNULL(
                                                            NULLIF(
                                                                JSON_VALUE(@json, '$.billing_address.last_name')
                                                                , ''
                                                            )
                                                            ,NULLIF(
                                                                JSON_VALUE(@json, '$.customer.default_address.last_name')
                                                                , ''
                                                            )
                                                        )
                                                END
                                            )
                                        ),
                                        CHARINDEX(
                                            ' ',
                                            LTRIM(
                                                RTRIM(
                                                    CASE
                                                        WHEN @na_nombres    IS NOT NULL AND @na_apellidos IS NOT NULL
                                                            THEN    @na_apellidos
                                                        ELSE
                                                            ISNULL(
                                                                NULLIF(
                                                                    JSON_VALUE(@json, '$.billing_address.last_name')
                                                                    , ''
                                                                )
                                                                ,NULLIF(
                                                                    JSON_VALUE(@json, '$.customer.default_address.last_name')
                                                                    , ''
                                                                )
                                                            )
                                                    END
                                                )
                                            ) + ' '
                                        ),
                                        LEN(
                                            CASE
                                                WHEN @na_nombres    IS NOT NULL AND @na_apellidos IS NOT NULL
                                                    THEN    @na_apellidos
                                                ELSE
                                                    ISNULL(
                                                        NULLIF(
                                                            JSON_VALUE(@json, '$.billing_address.last_name')
                                                            , ''
                                                        )
                                                        ,NULLIF(
                                                            JSON_VALUE(@json, '$.customer.default_address.last_name')
                                                            , ''
                                                        )
                                                    )
                                            END
                                        ) - CHARINDEX(
                                            ' ',
                                            LTRIM(
                                                RTRIM(
                                                    CASE
                                                        WHEN @na_nombres    IS NOT NULL AND @na_apellidos IS NOT NULL
                                                            THEN    @na_apellidos
                                                        ELSE
                                                            ISNULL(
                                                                NULLIF(
                                                                    JSON_VALUE(@json, '$.billing_address.last_name')
                                                                    , ''
                                                                )
                                                                ,NULLIF(
                                                                    JSON_VALUE(@json, '$.customer.default_address.last_name')
                                                                    , ''
                                                                )
                                                            )
                                                    END
                                                )
                                            )
                                        ) + 1
                                    )
                                ), 29
                            )
                        )
                    )

                DECLARE	@contacto	NVARCHAR(100)	=
                    UPPER(
                        dbo.fn_RemoveAccentMarks(
                            LEFT(
                                LTRIM(
                                    RTRIM(
                                        CASE
                                            WHEN @na_nombres    IS NOT NULL AND @na_apellidos IS NOT NULL
                                                THEN    CONCAT(@na_nombres, ' ', @na_apellidos)
                                            ELSE
                                                ISNULL(
                                                    JSON_VALUE(@json, '$.billing_address.last_name'),
                                                    JSON_VALUE(@json, '$.customer.default_address.last_name')
                                                ) 
                                                + ' ' + 
                                                ISNULL(
                                                    JSON_VALUE(@json, '$.billing_address.first_name'),
                                                    JSON_VALUE(@json, '$.customer.default_address.first_name')
                                                )
                                        END
                                    )
                                ), 100
                            )
                        )
                    )

                DECLARE	@F015_DIRECCION1	NVARCHAR(40)	=
                    ISNULL(
                        UPPER(
                            dbo.fn_RemoveAccentMarks(
                                @direccion_1_shopify
                            )
                        )
                        , ''
                    )

                DECLARE @F015_DIRECCION2	NVARCHAR(40)	=
                    ISNULL(
                        UPPER(
                            dbo.fn_RemoveAccentMarks(
                                @direccion_2_shopify
                            )
                        ),
                        ''
                    )

                DECLARE @F015_DIRECCION3	NVARCHAR(40)	=
                    ISNULL(
                        UPPER(
                            dbo.fn_RemoveAccentMarks(
                                JSON_VALUE(@json, '$.customer.default_address.address3')
                            )
                        )
                        ,''
                    )

                DECLARE	@F015_TELEFONO	NVARCHAR(20)	=
                    CASE
                        WHEN @na_telefono IS NOT NULL
                            THEN    @na_telefono
                        ELSE
                            REPLACE(
                                JSON_VALUE(@json, '$.customer.default_address.phone'),
                                '+57',
                                ''
                            )
                    END

                DECLARE	@F015_EMAIL	NVARCHAR(255)	=
                    CASE
                        WHEN    @na_email IS NOT NULL
                            THEN    @na_email
                        ELSE
                            dbo.fn_RemoveAccentMarks(
                                JSON_VALUE(@json, '$.customer.email')
                            )
                    END;

                DECLARE	@FECHA	NVARCHAR(40)	=
                    REPLACE(
                        CONVERT(
                            VARCHAR(10)
                            ,CAST(JSON_VALUE(@json, '$.customer.created_at') AS DATE)
                        ), 
                        '-', 
                        ''
                    )

                DECLARE	@criterio	NVARCHAR(40)	=
                    JSON_VALUE(@json, '$.tags');

                /*	TERCERO	*/
                INSERT INTO @tercero
                SELECT
                    F200_ID					=	LEFT(@F200_ID, 15),
                    F200_NIT				=	LEFT(@F200_ID, 25),
                    F200_ID_TIPO_IDENT		=	@F200_ID_TIPO_IDENT,
                    F200_IND_TIPO_TERCERO	=	@F200_IND_TIPO_TERCERO,
                    F200_RAZON_SOCIAL		=	@F200_RAZON_SOCIAL,
                    F200_APELLIDO1			=	@F200_APELLIDO1,
                    F200_APELLIDO2			=	@F200_APELLIDO2,
                    F200_NOMBRES			=	@f200_NOMBRE,
                    F200_NOMBRE_EST		    =	'',
                    F015_CONTACTO			=	@contacto,
                    F015_DIRECCION1		    =	@F015_DIRECCION1,
                    F015_DIRECCION2		    =	@F015_DIRECCION2,
                    F015_ID_PAIS			=	@id_pais,
                    F015_ID_DEPTO			=	@id_departamento,
                    F015_ID_CIUDAD			=	@id_ciudad,
                    F015_TELEFONO			=	@F015_TELEFONO,
                    F015_EMAIL				=	@F015_EMAIL,
                    F200_FECHA_NACIMIENTO	=	@FECHA,
                    F015_CELULAR			=	@F015_TELEFONO
            
                /*	CLIENTE	*/
                INSERT INTO @cliente
                SELECT
                    F201_ID_TERCERO             =   @F200_ID,
                    F201_DESCRIPCION_SUCURSAL   =   LEFT(@contacto, 40),
                    F201_NOTAS                  =   '',
                    F015_CONTACTO               =   LEFT(@contacto, 50),
                    F015_DIRECCION1             =   @F015_DIRECCION1,
                    F015_DIRECCION2             =   @F015_DIRECCION2,
                    F015_ID_PAIS                =	@id_pais,
                    F015_ID_DEPTO               =   @id_departamento,
                    F015_ID_CIUDAD              =   @id_ciudad,
                    F015_TELEFONO               =   @F015_TELEFONO,
                    F015_EMAIL                  =   @F015_EMAIL,
                    F201_FECHA_INGRESO          =   @FECHA,
                    f015_celular                =   @F015_TELEFONO

                /*	IMPUESTOS Y RETENCIONES	*/
                INSERT INTO @impuestos_y_retenciones
                SELECT
                    F_ID_TERCERO	=	LEFT(@F200_ID, 25),
                    F_ID_LLAVE		=	''

                INSERT INTO @criterios_ciudades
                SELECT 
                    plan_criterio_001	=	cc.plan_criterio_001, 
                    plan_criterio_002	=	cc.plan_criterio_002
                FROM codigosCriterios	AS	cc
                WHERE
                    LOWER(dbo.fn_RemoveAccentMarks(cc.nombre))	LIKE '%' + REPLACE(LOWER(dbo.fn_RemoveAccentMarks(@nombre_ciudad)), ', d.c.', '') + '%';

                INSERT INTO @criterios_clasificacion (F207_ID_TERCERO, F207_ID_PLAN_CRITERIOS, F207_ID_CRITERIO_MAYOR)
                    SELECT
                        F207_ID_TERCERO			=	LEFT(@F200_ID, 25),
                        F207_ID_PLAN_CRITERIOS	=	'001',
                        F207_ID_CRITERIO_MAYOR	=
                            ISNULL(
                                NULLIF(
                                    (
                                        SELECT TOP 1
                                            plan_criterio_001 
                                        FROM @criterios_ciudades
                                    ),
                                    ''
                                ), 
                                '0001'
                            )
                    UNION ALL
                    SELECT 
                        F207_ID_TERCERO			=	LEFT(@F200_ID, 25),
                        F207_ID_PLAN_CRITERIOS	=	'002',
                        F207_ID_CRITERIO_MAYOR	=
                            ISNULL(
                                NULLIF(
                                    (
                                        SELECT	TOP 1
                                            plan_criterio_002
                                        FROM @criterios_ciudades
                                    ),
                                    ''
                                ), 
                                '0001'
                            )
                    UNION ALL
                    SELECT 
                        F207_ID_TERCERO			=	LEFT(@F200_ID, 25),
                        F207_ID_PLAN_CRITERIOS	=	'005',
                        F207_ID_CRITERIO_MAYOR	=	'0004'
                    UNION ALL
                    SELECT 
                        F207_ID_TERCERO			=	LEFT(@F200_ID, 25),
                        F207_ID_PLAN_CRITERIOS	=	'006',
                        F207_ID_CRITERIO_MAYOR	=	'0004'
                    UNION ALL
                    SELECT 
                        F207_ID_TERCERO			=	LEFT(@F200_ID, 25),
                        F207_ID_PLAN_CRITERIOS	=	'007',
                        F207_ID_CRITERIO_MAYOR	=	
                            CASE
                                WHEN	NULLIF(TRIM(@criterio), '') IS NULL AND NULLIF(TRIM(@na_zoko_session_id), '') IS NULL THEN	'0029' --> Criterio por defecto 
                                ELSE	'0034' --> Criterio Whatsapp si tiene algún valor la etiqueta
                            END;

                /*	Entidades dinamicas	*/
                INSERT INTO @entidades_dinamicas
                SELECT
                    f201_id_tercero	=	LEFT(@F200_ID, 15),
                    f753_dato_texto	=	@F015_EMAIL
                
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
                    @order	AS	idOrden,
                    (
                        SELECT
                            [Terceros] = (
                                SELECT *
                                FROM @tercero
                                FOR JSON PATH
                                ,INCLUDE_NULL_VALUES
                            ),
                            [Clientes] = (
                                SELECT *
                                FROM @cliente
                                FOR JSON PATH
                                ,INCLUDE_NULL_VALUES
                            ),
                            [ImptosyReten] = (
                                SELECT *
                                FROM @impuestos_y_retenciones
                                FOR JSON PATH
                                ,INCLUDE_NULL_VALUES
                            ),
                            [CriteriosClientes] = (
                                SELECT *
                                FROM @criterios_clasificacion
                                FOR JSON PATH
                                ,INCLUDE_NULL_VALUES
                            ),
                            [Ent_Dinamica_Cliente] = (
                                SELECT *
                                FROM @entidades_dinamicas
                                FOR JSON PATH
                                ,INCLUDE_NULL_VALUES
                            )
                        FOR JSON PATH
                        ,WITHOUT_ARRAY_WRAPPER
                        ,INCLUDE_NULL_VALUES
                    );
            END
            ELSE
            BEGIN
                UPDATE ordenes
                SET execution_log = 'Tercero sin número de identificación válido'
                WHERE
                    id_orden    =   @order
                    AND
                    id_estado   =   1;
            END
        
            DELETE	@tercero
            DELETE	@cliente
            DELETE	@impuestos_y_retenciones
            DELETE	@criterios_clasificacion
            DELETE	@entidades_dinamicas
            DELETE	@criterios_ciudades
            SET @counter = @counter + 1;
        END TRY
        BEGIN CATCH
            DELETE	@tercero
            DELETE	@cliente
            DELETE	@impuestos_y_retenciones
            DELETE	@criterios_clasificacion
            DELETE	@entidades_dinamicas
            DELETE	@criterios_ciudades
            SET @counter = @counter + 1;
        END CATCH
	END
END TRY
BEGIN CATCH
	SELECT
		CAST(1 AS BIT)						AS	indicaError
		,CONCAT('Error: ', ERROR_MESSAGE())	AS	descripcionError
END CATCH
 
SELECT *
FROM @final AS final_json;
 