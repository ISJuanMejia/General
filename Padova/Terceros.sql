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
* @Tercero, @Cliente, @Impuestos:
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
	DECLARE @json   NVARCHAR(MAX) = '';
	DECLARE @final  TABLE 
    (
		idDocumento         INT,
		indicaParalelismo   BIT,
		descripcion         VARCHAR(50),
		idOrden             VARCHAR(50),
		json                VARCHAR(max)
	);

	DECLARE @counter    INT =   1;
	DECLARE @total      INT;

	DECLARE @order			VARCHAR(30);

	DECLARE @paisSiesa		NVARCHAR(3),
			@dptoSiesa		NVARCHAR(3),
			@ciudadSiesa	NVARCHAR(3);

	--* INFORMACIÓN DEL CONECTOR *--
	DECLARE @idDocumento            INT         =   225464;
	DECLARE @descripcionConector    VARCHAR(50) =   'Tercero_Cliente_Padova_Shopify';
	DECLARE @indicaParalelismo      BIT         =   1;

    /*
        *   INFORMACIÓN DE TIPO DE TERCERO
        *   TIPO CLIENTE
    */
    DECLARE @id_consumidor_final        NVARCHAR(15)    =   '222222222222';
    DECLARE @F200_ID_TIPO_IDENT         NVARCHAR(10)    =   'C';
	DECLARE @F200_IND_TIPO_TERCERO      NVARCHAR(10)    =   '1';
    DECLARE @id_tipo_cliente_nacional   NVARCHAR(4)     =   '0001';
    DECLARE @id_tipo_cliente_extranjero NVARCHAR(4)     =   '0002';

    /*
        *   CONDICIÓN DE PAGO
        *   IDENTIFICACIÓN DE SUCURSAL
        *   LISTAS DE PRECIOS
        *   CENTRO DE OPERACIONES
    */
    DECLARE @id_cond_pago           NVARCHAR(10)    =   'CRC';
	DECLARE @Id_sucursal            NVARCHAR(10)    =	'001';
    DECLARE @id_lista_precios_cop   NVARCHAR(3)     =   '001';
    DECLARE @id_lista_precios_usd   NVARCHAR(3)     =   '002';
    DECLARE @id_co                  NVARCHAR(3)     =   '001';

	/* TABLAS TEMPORALES */
	DECLARE @Tercero	TABLE (
		F200_ID						NVARCHAR(15),
		F200_NIT					NVARCHAR(25),
		F200_ID_TIPO_IDENT			NVARCHAR(1),
		F200_IND_TIPO_TERCERO		NVARCHAR(1),
		F200_RAZON_SOCIAL			NVARCHAR(100),
		F200_APELLIDO1				NVARCHAR(29),
		F200_APELLIDO2				NVARCHAR(29),
		F200_NOMBRES				NVARCHAR(40),
		F200_NOMBRE_EST				NVARCHAR(50),
		F015_CONTACTO				NVARCHAR(50),
		F015_DIRECCION1				NVARCHAR(40),
		F015_DIRECCION2				NVARCHAR(40),
		F015_DIRECCION3				NVARCHAR(40),
		F015_ID_PAIS				NVARCHAR(3),
		F015_ID_DEPTO				NVARCHAR(2),
		F015_ID_CIUDAD				NVARCHAR(3),
		F015_TELEFONO				NVARCHAR(20),
		F015_EMAIL					NVARCHAR(255),
		F200_FECHA_NACIMIENTO		NVARCHAR(8),
		F015_CELULAR				NVARCHAR(50)
	);

	DECLARE @Cliente	TABLE (
		F201_ID_TERCERO				NVARCHAR(15),
	--	F201_ID_SUCURSAL			NVARCHAR(10),
		F201_DESCRIPCION_SUCURSAL	NVARCHAR(40),
		F201_ID_MONEDA				NVARCHAR(3),
	--	F201_ID_COND_PAGO			NVARCHAR(5),
		F201_ID_TIPO_CLI			NVARCHAR(4),
		F201_ID_LISTA_PRECIO		NVARCHAR(3),
		F201_ID_CO_FACTURA			NVARCHAR(3),
		F015_CONTACTO				NVARCHAR(50),
		F015_DIRECCION1				NVARCHAR(40),
		F015_DIRECCION2				NVARCHAR(40),
		F015_DIRECCION3				NVARCHAR(40),
		F015_ID_PAIS				NVARCHAR(3),
		F015_ID_DEPTO				NVARCHAR(2),
		F015_ID_CIUDAD				NVARCHAR(3),
		F015_TELEFONO				NVARCHAR(20),
		F015_EMAIL					NVARCHAR(255),
		F201_FECHA_INGRESO			NVARCHAR(8),
		f015_celular				NVARCHAR(50)
	);

	DECLARE @Impuestos	TABLE	(
		F_ID_TERCERO		NVARCHAR(20),
		F_ID_SUCURSAL		NVARCHAR(10),
        F_ID_VALOR_TERCERO  NVARCHAR(1)
	);

	DECLARE @ordenes TABLE (
       id_orden    NVARCHAR(900),
       orden_obj   NVARCHAR(MAX)
   );

    INSERT INTO @ordenes
	SELECT TOP 20
        id_orden, 
        orden_obj
	FROM ordenes 
	WHERE 
        id_estado =1 
	    AND 
        intentos<=3

	SET @total = (SELECT COUNT(*) FROM @ordenes);

	WHILE @counter <= @total
	BEGIN 
        BEGIN TRY
        SET @json = (
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

        SELECT TOP 1 
            @paisSiesa      =   ISNULL(f013_id_pais,'169') ,
            @dptoSiesa      =   ISNULL(f013_id_depto,'05') ,
            @ciudadSiesa    =   ISNULL(f013_id,'001') 
        FROM locaciones_erp 
        WHERE 
            -- dbo.fn_RemoveAccentMarks(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(
                                        LOWER(f011_descripcion), 
                                        'ü', 
                                        'u'
                                    ), 
                                    'á', 
                                    'a'
                                ),
                                'é',
                                'e'
                            ),
                            'í',
                            'i'
                        ),
                        'ó',
                        'o'
                    ),
                    'ú',
                    'u'
                )
            -- )
            =
            -- dbo.fn_RemoveAccentMarks(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(
                                        LOWER(JSON_VALUE(@json, '$.customer.default_address.country')), 
                                        'ü', 
                                        'u'
                                    ), 
                                    'á', 
                                    'a'
                                ),
                                'é',
                                'e'
                            ),
                            'í',
                            'i'
                        ),
                        'ó',
                        'o'
                    ),
                    'ú',
                    'u'
                )
            -- )
            and   
            -- dbo.fn_RemoveAccentMarks(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(
                                        LOWER(f012_descripcion), 
                                        'ü', 
                                        'u'
                                    ), 
                                    'á', 
                                    'a'
                                ),
                                'é',
                                'e'
                            ),
                            'í',
                            'i'
                        ),
                        'ó',
                        'o'
                    ),
                    'ú',
                    'u'
                )
            -- )
            =
            -- dbo.fn_RemoveAccentMarks(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(
                                        LOWER(JSON_VALUE(@json, '$.customer.default_address.province')), 
                                        'ü', 
                                        'u'
                                    ), 
                                    'á', 
                                    'a'
                                ),
                                'é',
                                'e'
                            ),
                            'í',
                            'i'
                        ),
                        'ó',
                        'o'
                    ),
                    'ú',
                    'u'
                )
            -- )
            and   
            -- dbo.fn_RemoveAccentMarks(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(
                                        LOWER(f013_descripcion), 
                                        'ü', 
                                        'u'
                                    ), 
                                    'á', 
                                    'a'
                                ),
                                'é',
                                'e'
                            ),
                            'í',
                            'i'
                        ),
                        'ó',
                        'o'
                    ),
                    'ú',
                    'u'
                )
            -- )
            =
            -- dbo.fn_RemoveAccentMarks(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(
                                        LOWER(JSON_VALUE(@json, '$.customer.default_address.city')), 
                                        'ü', 
                                        'u'
                                    ), 
                                    'á', 
                                    'a'
                                ),
                                'é',
                                'e'
                            ),
                            'í',
                            'i'
                        ),
                        'ó',
                        'o'
                    ),
                    'ú',
                    'u'
                );
            -- ) ;
        
        SET @order=JSON_VALUE(@json, '$.name');

        DECLARE @F200_ID                NVARCHAR(40)    =   
            ISNULL(
                JSON_VALUE(@json, '$.billing_address.company'),
                JSON_VALUE(@json, '$.customer.default_address.company')
            );
        
        SET @F200_ID    =   
            ISNULL(
                NULLIF(
                    NULLIF(
                        TRIM(
                            REPLACE(
                                TRANSLATE(
                                    UPPER(@F200_ID), 
                                    'AÁÄBCDEÉËFGHIÍÏJKLMNÑOÓÖPQRSTUÚÜVWXYZ,.@', 
                                    '****************************************'
                                ), 
                                '*', 
                                ''
                            )
                        ), 
                        ''
                    ),
                    '-'
                ),
                @id_consumidor_final
            );

        DECLARE @F200_RAZON_SOCIAL      NVARCHAR(100)   =   
            UPPER(
                ISNULL(
                    JSON_VALUE(@json, '$.billing_address.name'),
                    JSON_VALUE(@json, '$.customer.default_address.name')
                )
            );
        DECLARE @F015_DIRECCION1        NVARCHAR(40)    =   
            UPPER(
                ISNULL(
                    JSON_VALUE(@json, '$.billing_address.address1'),
                    JSON_VALUE(@json, '$.customer.default_address.address1')
                )
            );
        DECLARE @F015_DIRECCION2        NVARCHAR(40)    =   
            UPPER(
                ISNULL(
                    JSON_VALUE(@json, '$.billing_address.address2'),
                    JSON_VALUE(@json, '$.customer.default_address.address2')
                )
            );
        DECLARE @F015_DIRECCION3        NVARCHAR(40)    =   
            UPPER(
                ISNULL(
                    JSON_VALUE(@json, '$.billing_address.address3'),
                    JSON_VALUE(@json, '$.customer.default_address.address3')
                )
            );
        DECLARE @F015_TELEFONO          NVARCHAR(20)    =   
            LEFT(
                REPLACE(
                    REPLACE(
                        TRIM(
                            REPLACE(
                                JSON_VALUE(@json, '$.customer.default_address.phone'),
                                '+57',
                                ''
                            )
                        ), 
                        ' ', 
                        ''
                    ),
                    '-',
                    ''
                ),
                20
            );
            DECLARE @F015_EMAIL             NVARCHAR(255)   =   LEFT(JSON_VALUE(@json, '$.customer.email'), 255);
            DECLARE @FECHA                  NVARCHAR(8)    =   
                REPLACE(
                    CONVERT(
                        VARCHAR(10), 
                        CAST(JSON_VALUE(@json, '$.customer.created_at') AS DATE)
                    ), 
                    '-', 
                    ''
                );
            DECLARE @F201_ID_MONEDA         NVARCHAR(3)     =   UPPER(JSON_VALUE(@json, '$.presentment_currency'));
            DECLARE @F201_ID_TIPO_CLI       NVARCHAR(4)     = 
                CASE
                    WHEN    @F201_ID_MONEDA =   'COP' 
                        THEN @id_tipo_cliente_nacional 
                    WHEN    @F201_ID_MONEDA =   'USD'
                        THEN @id_tipo_cliente_extranjero 
                    ELSE @id_tipo_cliente_nacional 
                END;

            /*
                *   TERCERO
            */
            INSERT INTO @Tercero
            SELECT 
                F200_ID                 =   LEFT(@F200_ID, 15),
                F200_NIT                =	LEFT(@F200_ID, 25),
                F200_ID_TIPO_IDENT      =   @F200_ID_TIPO_IDENT,
                F200_IND_TIPO_TERCERO   =   @F200_IND_TIPO_TERCERO,
                F200_RAZON_SOCIAL       =   LEFT(@F200_RAZON_SOCIAL, 100),
                F200_APELLIDO1          =   
                    LEFT(
                        LEFT(
                            UPPER(
                                TRIM(JSON_VALUE(@json, '$.customer.default_address.last_name'))
                            ), 
                            CHARINDEX(
                                ' ', 
                                UPPER(
                                    TRIM(JSON_VALUE(@json, '$.customer.default_address.last_name'))
                                ) + ' '
                            ) - 1
                        ), 
                        29
                    ),
                F200_APELLIDO2          =     
                    LEFT(
                        LTRIM(
                            SUBSTRING(
                                UPPER(
                                    TRIM(JSON_VALUE(@json, '$.customer.default_address.last_name'))
                                ),
                                CHARINDEX(
                                    ' ', 
                                    UPPER(
                                        TRIM(JSON_VALUE(@json, '$.customer.default_address.last_name'))
                                    ) + ' '
                                ), 
                                LEN(
                                    UPPER(
                                        TRIM(JSON_VALUE(@json, '$.customer.default_address.last_name'))
                                    )
                                ) - CHARINDEX(
                                    ' ', 
                                    UPPER(
                                        TRIM(JSON_VALUE(@json, '$.customer.default_address.last_name'))
                                    )
                                ) + 1
                            )
                        ),
                        29
                    ),
                F200_NOMBRES            =
                    LEFT(
                        UPPER(
                            ISNULL(
                                JSON_VALUE(@json, '$.customer.default_address.first_name'),
                                JSON_VALUE(@json, '$.customer.default_address.first_name')
                            )
                        ), 
                        40
                    ),
                F200_NOMBRE_EST         =   LEFT(@F200_RAZON_SOCIAL, 50),
                F015_CONTACTO           =   LEFT(@F200_RAZON_SOCIAL, 50),
                F015_DIRECCION1         =   @F015_DIRECCION1,
                F015_DIRECCION2         =   @F015_DIRECCION2,
                F015_DIRECCION3         =   @F015_DIRECCION3,
                F015_ID_PAIS            =   @paisSiesa,
                F015_ID_DEPTO           =   @dptoSiesa,
                F015_ID_CIUDAD          =   @ciudadSiesa,
                F015_TELEFONO           =   @F015_TELEFONO,
                F015_EMAIL              =   @F015_EMAIL,
                F200_FECHA_NACIMIENTO   =   LEFT(@FECHA, 8),
                F015_CELULAR            =   LEFT(@F015_TELEFONO, 20)

            /*
                *   CLIENTE
            */
            INSERT INTO @Cliente
            SELECT 
                F201_ID_TERCERO             =   LEFT(@F200_ID, 15),
            --  F201_ID_SUCURSAL            =   @Id_sucursal,
                F201_DESCRIPCION_SUCURSAL   =   LEFT(@F200_RAZON_SOCIAL, 40),
                F201_ID_MONEDA              =   @F201_ID_MONEDA,
            --  F201_ID_COND_PAGO           =   @id_cond_pago,
                F201_ID_TIPO_CLI            =   @F201_ID_TIPO_CLI,
                F201_ID_LISTA_PRECIO        =
                    CASE
                        WHEN    @F201_ID_MONEDA =   'COP' 
                            THEN    @id_lista_precios_cop 
                        WHEN    @F201_ID_MONEDA =   'USD'
                            THEN    @id_lista_precios_usd 
                        ELSE    @id_lista_precios_cop 
                    END,
                F201_ID_CO_FACTURA          =   @id_co,
                F015_CONTACTO               =   LEFT(@F200_RAZON_SOCIAL, 50),
                F015_DIRECCION1             =   LEFT(@F015_DIRECCION1, 40),
                F015_DIRECCION2             =   LEFT(@F015_DIRECCION2, 40),
                F015_DIRECCION3             =   LEFT(@F015_DIRECCION3, 40),
                F015_ID_PAIS                =	@paisSiesa,
                F015_ID_DEPTO               =	@dptoSiesa,
                F015_ID_CIUDAD              =	@ciudadSiesa,
                F015_TELEFONO               =	@F015_TELEFONO,
                F015_EMAIL                  =   @F015_EMAIL,
                F201_FECHA_INGRESO          =   LEFT(@FECHA, 8),
                f015_celular                =   LEFT(@F015_TELEFONO, 50)  

            /*
                *   IMPUESTOS
            */
            INSERT INTO @Impuestos
            SELECT
                F_ID_TERCERO        =   LEFT(@F200_ID, 15),
                F_ID_SUCURSAL       =   @Id_sucursal,
                F_ID_VALOR_TERCERO  =
                    CASE 
                        WHEN    @F201_ID_MONEDA =   'COP'
                            THEN    '1' 
                        ELSE    '0'
                    END;

            IF (@F200_ID != @id_consumidor_final)
            BEGIN
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
                    idOrden             =   @order,
                    (
                        SELECT
                            [Terceros] = (
                                SELECT *
                                FROM @tercero
                                FOR JSON PATH,
                                INCLUDE_NULL_VALUES
                            ),
                            [Clientes] = (
                                SELECT *
                                FROM @cliente
                                FOR JSON PATH,
                                INCLUDE_NULL_VALUES
                            ),
                            [Imptos y Reten] = (
                                SELECT * 
                                FROM @impuestos
                                FOR JSON PATH,
                                INCLUDE_NULL_VALUES
                            )
                        FOR JSON PATH,
                        WITHOUT_ARRAY_WRAPPER,
                        INCLUDE_NULL_VALUES
                    );
            END
            ELSE
            BEGIN
                UPDATE ordenes
                SET
                    id_estado   =   2
                WHERE
                    id_orden    =   @order
            END

            DELETE @Tercero;
            DELETE @Cliente;
            DELETE @Impuestos;
            SET @counter = @counter + 1;
        END TRY
        BEGIN CATCH
            SELECT
                indicaError         =   CAST(1 AS BIT), 
                descripcionError    =   CONCAT('Error: ', ERROR_MESSAGE())
            DELETE @Tercero;
            DELETE @Cliente;
            DELETE @Impuestos;
            SET @counter = @counter + 1;
        END CATCH
    END
    SELECT * from @final AS final_json; 
END TRY
BEGIN CATCH
    SELECT
        indicaError         =   CAST(1 AS BIT), 
        descripcionError    =   CONCAT('Error: ', ERROR_MESSAGE())
END CATCH
