/*
# Integración de terceros y clientes BeautyBrands desde órdenes pendientes

SECCIÓN: Descripción general

* Este procedimiento procesa órdenes pendientes del cliente **BeautyBrands** (máximo 3 intentos, estado = 1)
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
  Identifican el conector **Tercero_Cliente** y determinan si admite paralelismo.
* Variables de sucursal, moneda, listas de precios y centro de operaciones:
  Definen la configuración comercial para clientes nacionales (COP) y extranjeros (USD).
* @ordenes:
  Tabla temporal que almacena las órdenes pendientes de Padova a procesar.
* @Tercero, @Cliente, @Impuestos:
  Tablas temporales que almacenan la información procesada antes de generar el JSON final.

===========================================================
SECCIÓN: Flujo del proceso

1. **Obtención de órdenes pendientes**

   * Se consultan las órdenes de BeautyBrands con estado = 1 e intentos ≤ 3.
   * Se cargan en la tabla temporal @ordenes y se calcula el total a procesar.

2. **Iteración por cada orden**

   * Se obtiene el JSON de la orden y se extraen datos clave del cliente:

     * País, departamento y ciudad de facturación.
     * Identificación, razón social, nombres y apellidos.
     * Dirección, teléfono y correo electrónico.
     * Tipo de cliente según moneda (COP = nacional).
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
     * Descripción del conector BeautyBrands.
     * Indicador de paralelismo.
     * Id de la orden (Shopify).
     * JSON estructurado con Terceros, Clientes e Impuestos.

5. **Limpieza de tablas temporales**

   * Al finalizar cada iteración se limpian las tablas temporales para continuar
     con la siguiente orden.

6. **Manejo de errores**

   * Si ocurre un error al procesar una orden de BeautyBrands, se limpian las tablas
     temporales y se continúa con la siguiente.
   * Si el error es general, se retorna un mensaje con el detalle del error.

==================================================================
Fin de la documentación del procedimiento [TERCERO_CLIENTE]
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

    DECLARE @counter INT = 1;
    DECLARE @total   INT;
    DECLARE @order   VARCHAR(30);

    DECLARE @paisSiesa   NVARCHAR(3),
            @dptoSiesa   NVARCHAR(3),
            @CiudadSiesa NVARCHAR(3);

    DECLARE @idDocumento INT = 226453;
    DECLARE @descripcionConector VARCHAR(50) = 'Ecommerce_Terceros_Clientes';
    DECLARE @indicaParalelismo BIT = 1;

    DECLARE @vendedor NVARCHAR(4);
    DECLARE @un_mvto_factura NVARCHAR(3);

    DECLARE @Tercero TABLE (
        F200_ID NVARCHAR(15),
        F200_NIT NVARCHAR(25),
        F200_RAZON_SOCIAL NVARCHAR(100),
        F200_APELLIDO1 NVARCHAR(29),
        F200_APELLIDO2 NVARCHAR(29),
        F200_NOMBRES NVARCHAR(40),
        F200_NOMBRE_EST NVARCHAR(50),
        F015_CONTACTO NVARCHAR(50),
        F015_DIRECCION1 NVARCHAR(40),
        F015_DIRECCION2 NVARCHAR(40),
        F015_ID_PAIS NVARCHAR(3),
        F015_ID_DEPTO NVARCHAR(2),
        F015_ID_CIUDAD NVARCHAR(3),
        F015_TELEFONO NVARCHAR(20),
        F015_EMAIL NVARCHAR(255),
        F200_FECHA_NACIMIENTO NVARCHAR(8),
        F015_CELULAR NVARCHAR(50)
    );

    DECLARE @Cliente TABLE (
        F201_ID_TERCERO NVARCHAR(15),
        F201_DESCRIPCION_SUCURSAL NVARCHAR(40),
        F015_CONTACTO NVARCHAR(50),
        F015_DIRECCION1 NVARCHAR(40),
        F015_DIRECCION2 NVARCHAR(40),
        F015_ID_PAIS NVARCHAR(3),
        F015_ID_DEPTO NVARCHAR(2),
        F015_ID_CIUDAD NVARCHAR(3),
        F201_ID_VENDEDOR NVARCHAR(4),
        F201_ID_UN_MOVTO_FACTURA NVARCHAR(3),
        F015_TELEFONO NVARCHAR(20),
        F015_EMAIL NVARCHAR(255),
        F201_FECHA_INGRESO NVARCHAR(8),
        f015_celular NVARCHAR(50)
    );

    DECLARE @Impuestos TABLE ( 
        F_TIPO_REG NVARCHAR(2),
        F_ID_CLASE NVARCHAR(2),
        F_ID_TERCERO NVARCHAR(20)

    );

    DECLARE @ordenes TABLE (
        id_orden NVARCHAR(900),
        orden_obj NVARCHAR(MAX)
    );

    INSERT INTO @ordenes
    SELECT TOP 25 id_orden, orden_obj
    FROM ordenes
    WHERE 
        id_estado = 1
        AND 
        intentos <= 3;

    SET @total = (SELECT COUNT(*) FROM @ordenes);

    WHILE @counter <= @total
    BEGIN
        BEGIN TRY

        SET @json = (
            SELECT orden_obj
            FROM (
                SELECT orden_obj,
                       ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
                FROM @ordenes
            ) t
            WHERE rn = @counter
        );

        SET @paisSiesa = '';
        SET @dptoSiesa = '';
        SET @CiudadSiesa = '';

        /* =====================================================
           BLOQUE HOMOLOGACIÓN (MISMA LÓGICA ORIGINAL)
           SOLO SE ELIMINÓ EL LIKE '%'
        ===================================================== */

        SELECT TOP 1
            @paisSiesa   = ISNULL(f013_id_pais,''),
            @dptoSiesa   = ISNULL(f013_id_depto,''),
            @CiudadSiesa = ISNULL(f013_id,'')
        FROM locaciones_erp
        WHERE
            UPPER(TRANSLATE(LOWER(f011_descripcion) COLLATE Latin1_General_CI_AI,
                'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun'))
            =
            UPPER(TRANSLATE(LOWER(JSON_VALUE(@json, '$.customer.default_address.country')) COLLATE Latin1_General_CI_AI,
                'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun'))
        AND
        (
            /* Caso 1 Bogotá */
            (
                (
                    UPPER(TRANSLATE(LOWER(JSON_VALUE(@json,'$.customer.default_address.province')) COLLATE Latin1_General_CI_AI,
                        'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')) LIKE '%CUNDINAMARCA%'
                    OR
                    UPPER(TRANSLATE(LOWER(JSON_VALUE(@json,'$.customer.default_address.province')) COLLATE Latin1_General_CI_AI,
                        'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')) LIKE '%BOGOTA%'
                )
                AND
                UPPER(TRANSLATE(LOWER(JSON_VALUE(@json,'$.customer.default_address.city')) COLLATE Latin1_General_CI_AI,
                    'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')) LIKE '%BOGOTA%'
                AND
                UPPER(TRANSLATE(LOWER(f012_descripcion) COLLATE Latin1_General_CI_AI,
                    'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')) LIKE '%BOGOTA%'
                AND
                UPPER(TRANSLATE(LOWER(f013_descripcion) COLLATE Latin1_General_CI_AI,
                    'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')) LIKE '%BOGOTA%'
            )

            OR

            /* Caso 2 Cundinamarca */
            (
                (
                    TRANSLATE(LOWER(JSON_VALUE(@json,'$.customer.default_address.province')) COLLATE Latin1_General_CI_AI,
                        'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun') LIKE '%cundinamarca%'
                    OR
                    TRANSLATE(LOWER(JSON_VALUE(@json,'$.customer.default_address.province')) COLLATE Latin1_General_CI_AI,
                        'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun') LIKE '%bogota%'
                )
                AND
                TRANSLATE(LOWER(JSON_VALUE(@json,'$.customer.default_address.city')) COLLATE Latin1_General_CI_AI,
                    'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun') NOT LIKE 'bogota'
                AND
                TRANSLATE(LOWER(f012_descripcion) COLLATE Latin1_General_CI_AI,
                    'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun') LIKE '%cundinamarca%'
                AND
                TRANSLATE(LOWER(f013_descripcion) COLLATE Latin1_General_CI_AI,
                    'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')
                =
                TRANSLATE(LOWER(JSON_VALUE(@json,'$.customer.default_address.city')) COLLATE Latin1_General_CI_AI,
                    'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')
            )

            OR

            /* Caso 3 Cartagena */
            (
                TRANSLATE(LOWER(JSON_VALUE(@json,'$.customer.default_address.province')) COLLATE Latin1_General_CI_AI,
                    'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun') LIKE '%bolivar%'
                AND
                TRANSLATE(LOWER(f013_descripcion) COLLATE Latin1_General_CI_AI,
                    'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun') LIKE '%cartagena%'
                AND
                TRANSLATE(LOWER(JSON_VALUE(@json,'$.customer.default_address.city')) COLLATE Latin1_General_CI_AI,
                    'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun') LIKE '%cartagena%'
            )

            OR

            /* Caso 5 NOT EXISTS (original) */
            (
                NOT EXISTS (
                    SELECT 1
                    FROM locaciones_erp l2
                    WHERE
                        TRANSLATE(LOWER(l2.f011_descripcion) COLLATE Latin1_General_CI_AI,
                            'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')
                        =
                        TRANSLATE(LOWER(JSON_VALUE(@json,'$.customer.default_address.country')) COLLATE Latin1_General_CI_AI,
                            'ÁÉÍÓÚÜÑáéíóúüñ','AEIOUUNaeiouun')
                )
            )
        );

        /* ===== FALLBACK CONTROLADO SI NO ENCUENTRA ===== */
        IF @CiudadSiesa = ''
        BEGIN
            SELECT TOP 1
                @paisSiesa   = ISNULL(f013_id_pais,''),
                @dptoSiesa   = ISNULL(f013_id_depto,''),
                @CiudadSiesa = ISNULL(f013_id,'')
            FROM locaciones_erp
            WHERE f013_id_pais = '169';
        END

        /* =====================================================
           RESTO DEL SCRIPT ORIGINAL (SIN CAMBIOS)
        ===================================================== */
 
        SET @order=JSON_VALUE(@json, '$.name');
 
        DECLARE @F200_ID                NVARCHAR(40)    =  
            ISNULL(
                JSON_VALUE(@json, '$.billing_address.company'),
                JSON_VALUE(@json, '$.customer.default_address.company')
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

            SET @vendedor = 
                CASE 
                    WHEN UPPER(JSON_VALUE(@JSON, '$.tags')) like '%WHATSAPP%' 
                    THEN '002' 
                    ELSE '9999' 
                END

            SET @un_mvto_factura = 
                CASE 
                    WHEN UPPER(JSON_VALUE(@JSON, '$.tags')) like '%WHATSAPP%' 
                    THEN '002' 
                    ELSE '007' 
                END
 
            /*
                *   TERCERO
            */
            INSERT INTO @Tercero
            SELECT
                F200_ID                 =   LEFT(@F200_ID, 15),
                F200_NIT                =   LEFT(@F200_ID, 25),
                F200_RAZON_SOCIAL       =   LEFT(@F200_RAZON_SOCIAL, 100),
                F200_APELLIDO1          =  
                    LEFT(
                        LEFT(
                            UPPER(
                                JSON_VALUE(@json, '$.customer.default_address.last_name')
                            ),
                            CHARINDEX(
                                ' ',
                                UPPER(
                                    JSON_VALUE(@json, '$.customer.default_address.last_name')
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
                                    JSON_VALUE(@json, '$.customer.default_address.last_name')
                                ),
                                CHARINDEX(
                                    ' ',
                                    UPPER(
                                        JSON_VALUE(@json, '$.customer.default_address.last_name')
                                    ) + ' '
                                ),
                                LEN(
                                    UPPER(
                                        JSON_VALUE(@json, '$.customer.default_address.last_name')
                                    )
                                ) - CHARINDEX(
                                    ' ',
                                    UPPER(
                                        JSON_VALUE(@json, '$.customer.default_address.last_name')
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
                F015_ID_PAIS            =   @paisSiesa,
                F015_ID_DEPTO           =   @dptoSiesa,
                F015_ID_CIUDAD          =   @CiudadSiesa,
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
                F201_DESCRIPCION_SUCURSAL   =   LEFT(@F200_RAZON_SOCIAL, 40),
                F015_CONTACTO               =   LEFT(@F200_RAZON_SOCIAL, 50),
                F015_DIRECCION1             =   LEFT(@F015_DIRECCION1, 40),
                F015_DIRECCION2             =   LEFT(@F015_DIRECCION2, 40),
                F015_ID_PAIS                =   @paisSiesa,
                F015_ID_DEPTO               =   @dptoSiesa,
                F015_ID_CIUDAD              =   @CiudadSiesa,
                F201_ID_VENDEDOR            =   @vendedor,
                F201_ID_UN_MOVTO_FACTURA    =   @un_mvto_factura,
                F015_TELEFONO               =   @F015_TELEFONO,
                F015_EMAIL                  =   @F015_EMAIL,
                F201_FECHA_INGRESO          =   LEFT(@FECHA, 8),
                f015_celular                =   LEFT(@F015_TELEFONO, 50)  
 
            /*
                *   IMPUESTOS
            */
            INSERT INTO @Impuestos
             SELECT
                F_TIPO_REG          =   '46',
                F_ID_CLASE          =   '1',
                F_ID_TERCERO        =   LEFT(@F200_ID, 15)
                UNION ALL
            SELECT
                F_TIPO_REG          =   '47',
                F_ID_CLASE          =   '41',
                F_ID_TERCERO        =   LEFT(@F200_ID, 15)
 
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