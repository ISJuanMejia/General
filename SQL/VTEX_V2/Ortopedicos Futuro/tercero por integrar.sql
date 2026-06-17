/*  TERCEROS CLIENTES - ORTOPEDICOS FUTURO*/
/*
 * ============================================================================
 * SCRIPT  : TERCERO_CLIENTE_VTEX
 * AUTOR   : Juan Camilo Mejía Echavarría
 * FECHA   : 2026-05-13
 * VERSION : 1.0
 * ENTORNO : Pruebas
 * ============================================================================
 * DESCRIPCIÓN:
 *   Este script tiene como objetivo extraer, transformar y cargar la información de terceros y clientes desde las 
 *   órdenes de VTEX, formatearla acorde a las necesidades del destino final, y actualizar la orden con la información 
 *   estructurada para su posterior integración a través de un endpoint específico. El proceso incluye la asignación de 
 *   códigos CIIU y tipos de cliente basados en reglas de negocio definidas, así como la construcción de un JSON con la 
 *   información requerida para cada orden.
 * 
 * DEPENDENCIAS:
 *   - Tablas: [ordenes, otras tablas necesarias para la extracción de datos]
 *   - Vistas/Funciones: [vistas o funciones necesarias para la transformación de datos]
 *   - Permisos requeridos: SELECT, UPDATE en dbo.ordenes
 * 
 * PARÁMETROS CRÍTICOS:
 *   @id_compania  : [descripción] - Validar contra catálogo de compañías
 *   @endpoint     : [descripción] - Validar formato URL y accesibilidad
 * 
 * SEGURIDAD:
 *   - Usar siempre TRY/CATCH con RAISERROR para trazabilidad
 *   - Validar que @endpoint no contenga inyección SQL (pattern check)
 *   - Limitar batch_size para evitar bloqueos prolongados
 *   - Nunca ejecutar UPDATE sin antes validar con SELECT de preview
 * ============================================================================
 */

SET NOCOUNT ON;           -- Evita mensajes de "X filas afectadas" que rompen JSON
SET XACT_ABORT ON;        -- Rollback automático ante errores de ejecución
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;  -- Balance entre consistencia y concurrencia

BEGIN TRY
    /*
        *   Parámetros de Configuración General: Esta sección incluye la configuración general del conector, como la 
        *   identificación de la compañía, el sistema y el documento, así como el nombre del documento a integrar. Es 
        *   importante resaltar que estos parámetros deben ser ajustados acorde a las necesidades particulares de cada 
        *   caso, considerando la configuración y categorización establecida en el destino final para la identificación 
        *   de la compañía, el sistema y el documento, así como el nombre del documento a integrar.
    */
    DECLARE @id_compania                    NVARCHAR(4)     =   '4826',
            @id_sistema                     NVARCHAR(1)     =   '2',
            @id_documento_tercero           NVARCHAR(6)     =   '227300',
            @nombre_documento_tercero       NVARCHAR(255)   =   'TERCERO_CLIENTE_VTEX',
            @id_documento_punto_envio       NVARCHAR(6)     =   '244000',
            @nombre_documento_punto_envio   NVARCHAR(255)   =   'Puntos_De_Envio_Ortopedicos_Futuro',
            @validar_estructura             NVARCHAR(5)     =   'true';

    /*
        *   Endpoint: URL del endpoint al cual se enviará la información formateada y estructurada acorde a las 
        *   necesidades del destino final. Es importante resaltar que este endpoint debe ser ajustado acorde a las 
        *   necesidades particulares de cada caso, considerando los diferentes escenarios y casos de uso que se puedan 
        *   presentar en la operación real del conector, para asegurar una integración exitosa y sin contratiempos. 
        *   Además, es fundamental verificar que el endpoint esté correctamente configurado y sea accesible desde el 
        *   entorno donde se ejecutará el conector, para evitar posibles errores de conexión o de envío de datos.
    */
    DECLARE @endpoint_terceros  NVARCHAR(500)   =   'http://localhost:8083/v3.1/ConectoresImportar?idCompania='
                                                    +   @id_compania 
                                                    +   '&idSistema='
                                                    +   @id_sistema
                                                    +   '&idDocumento='
                                                    +   @id_documento_tercero
                                                    +   '&nombreDocumento='
                                                    +   @nombre_documento_tercero                                            
                                                    +   '&validarEstructura='
                                                    +   @validar_estructura;

    DECLARE @endpoint_puntos_envio  NVARCHAR(500)   =   'http://localhost:8083/v3.1/ConectoresImportar?idCompania='
                                                    +   @id_compania 
                                                    +   '&idSistema='
                                                    +   @id_sistema
                                                    +   '&idDocumento='
                                                    +   @id_documento_punto_envio
                                                    +   '&nombreDocumento='
                                                    +   @nombre_documento_punto_envio                                            
                                                    +   '&validarEstructura='
                                                    +   @validar_estructura;

    /*
        *   Parámetros de configuración de ejecución para la selección y procesamiento de las órdenes, tales como el tamaño 
        *   del lote, el número máximo de intentos para reintento en caso de fallas, así como la fecha actual para uso en el 
        *   formateo de datos. Es importante resaltar que estos parámetros deben ser ajustados acorde a las necesidades 
        *   particulares de cada caso, considerando los diferentes escenarios y casos de uso que se puedan presentar en la 
        *   operación real del conector, para asegurar una integración exitosa y sin contratiempos.
    */
    DECLARE @batch_size         INT         =   25,
            @num_max_intentos   INT         =   3,
            @fecha_actual       NVARCHAR(8) =   FORMAT(GETDATE(), 'yyyyMMdd');

    /*
        *   Parámetros de configuración de negocio para la asignación de código CIIU acorde al tipo de cliente, ya sea 
        *   persona natural o jurídica. Es importante resaltar que estos parámetros deben ser ajustados acorde a las 
        *   necesidades particulares de cada caso, considerando la actividad económica principal de los clientes a integrar, 
        *   así como la configuración y categorización establecida en el destino final para el código CIIU.
    */
    DECLARE @id_ciiu_natural    NVARCHAR(4)    =   '0010',
            @id_ciiu_juridica   NVARCHAR(4)    =   '9999';

    /*
        *   Parámetros de configuración de negocio para la asignación de tipo de cliente acorde al medio de pago utilizado 
        *   en la orden. Es importante resaltar que estos parámetros deben ser ajustados acorde a las necesidades particulares 
        *   de cada caso, considerando los diferentes medios de pago que se puedan presentar en la operación real del conector, 
        *   así como la configuración y categorización establecida en el destino final para cada tipo de cliente.
    */
    DECLARE @id_tio_cli_addi                NVARCHAR(4) =   'W001',
            @id_tio_cli_mercado_pago        NVARCHAR(4) =   'W002',
            @id_tio_cli_defecto             NVARCHAR(4) =   'W003',
            @id_tio_cli_pago_contra_entrega NVARCHAR(4) =   'W004',
            @id_tio_cli_payu_no_varix       NVARCHAR(4) =   'W005',
            @id_tio_cli_transferencias      NVARCHAR(4) =   'W006';

    ---<=================================================================================================>---

    /*
        *   Secciones del Conector
        *   1.  Terceros
        *   2.  Clientes
        *   3.  Impuestos y Retenciones
        *   4.  CriteriosClientes
        *   5.  Entidad Dinamica Tercero
        *   6.  Entidad Dinamica Cliente
    */

    /*
        *   Terceros: Esta sección puede ser utilizada para incluir la información específica de los terceros, de acuerdo a la
        *   configuración y necesidades particulares de cada caso. Es importante resaltar que la estructura y los datos 
        *   incluidos en esta sección pueden variar significativamente acorde a las necesidades particulares de cada caso, 
        *   por lo que se recomienda analizar cuidadosamente la información que se desea incluir y su formato, para asegurar 
        *   una integración exitosa y sin contratiempos.
    */
    DECLARE @terceros    TABLE
    (
        id_orden                NVARCHAR(50),
        F200_ID                 NVARCHAR(50),
        F200_NIT                NVARCHAR(50),
        F200_ID_TIPO_IDENT      NVARCHAR(10),
        F200_IND_TIPO_TERCERO   NVARCHAR(10),
        F200_RAZON_SOCIAl       NVARCHAR(255),
        F200_APELLIDO1          NVARCHAR(100),
        F200_APELLIDO2          NVARCHAR(100),
        F200_NOMBRES            NVARCHAR(100),
        F200_NOMBRE_EST         NVARCHAR(255),
        F015_CONTACTO           NVARCHAR(255),
        F015_DIRECCION1         NVARCHAR(40),
        F015_DIRECCION2         NVARCHAR(40),
        F015_ID_DEPTO           NVARCHAR(10),
        F015_ID_CIUDAD          NVARCHAR(10),
        F015_TELEFONO           NVARCHAR(20),
        F015_COD_POSTAL         NVARCHAR(10),
        F015_EMAIL              NVARCHAR(255),
        F200_FECHA_NACIMIENTO   NVARCHAR(8),
        F200_ID_CIIU            NVARCHAR(10),
        F015_CELULAR            NVARCHAR(20)
    );

    /*
        *   Clientes: Esta sección puede ser utilizada para incluir la información específica de los clientes, de acuerdo a la
        *   configuración y necesidades particulares de cada caso. Es importante resaltar que la estructura y los datos 
        *   incluidos en esta sección pueden variar significativamente acorde a las necesidades particulares de cada caso, 
        *   por lo que se recomienda analizar cuidadosamente la información que se desea incluir y su formato, para asegurar 
        *   una integración exitosa y sin contratiempos.
    */
    DECLARE @clientes    TABLE
    (
        id_orden                    NVARCHAR(50),
        F201_ID_TERCERO             NVARCHAR(50),
        F201_DESCRIPCION_SUCURSAL   NVARCHAR(255),
        F201_ID_MONEDA              NVARCHAR(10),
        F201_ID_TIPO_CLI            NVARCHAR(10),
        F015_CONTACTO               NVARCHAR(255),
        F015_DIRECCION1             NVARCHAR(40),
        F015_DIRECCION2             NVARCHAR(40),
        F015_ID_DEPTO               NVARCHAR(10),
        F015_ID_CIUDAD              NVARCHAR(10),
        F015_TELEFONO               NVARCHAR(20),
        F015_COD_POSTAL             NVARCHAR(10),
        F015_EMAIL                  NVARCHAR(255),
        F201_FECHA_INGRESO          NVARCHAR(8),
        f015_celular                NVARCHAR(20)
    );

    /*
        *   Impuestos y Retenciones: Esta sección puede ser utilizada para incluir la información de impuestos y retenciones 
        *   asociada al tercero, de acuerdo a la configuración y necesidades particulares de cada caso. Es importante resaltar 
        *   que la estructura y los datos incluidos en esta sección pueden variar significativamente acorde a las necesidades 
        *   particulares de cada caso, por lo que se recomienda analizar cuidadosamente la información que se desea incluir y 
        *   su formato, para asegurar una integración exitosa y sin contratiempos.
    */
    DECLARE @impuestos_y_retenciones  TABLE
    (
        id_orden            NVARCHAR(50),
        F_TIPO_REG          NVARCHAR(2),
        F_ID_TERCERO        NVARCHAR(50),
        F_ID_CLASE          NVARCHAR(2),
        F_ID_VALOR_TERCERO  NVARCHAR(2),
        F_ID_LLAVE          NVARCHAR(2)
    );

    /*
        *   CriteriosClientes: Esta sección puede ser utilizada para asignar criterios específicos a los clientes, de acuerdo 
        *   a la configuración y necesidades particulares de cada caso. Es importante resaltar que la estructura y los datos 
        *   incluidos en esta sección pueden variar significativamente acorde a las necesidades particulares de cada caso, 
        *   por lo que se recomienda analizar cuidadosamente la información que se desea incluir y su formato, para asegurar 
        *   una integración exitosa y sin contratiempos.
    */
    DECLARE @criterios_clientes   TABLE
    (
        id_orden                NVARCHAR(50),
        F207_ID_TERCERO         NVARCHAR(50),
        F207_ID_PLAN_CRITERIOS  NVARCHAR(50),
        F207_ID_CRITERIO_MAYOR  NVARCHAR(50)
    );

    /*
        *   Entidad Dinamica Tercero: Esta sección puede ser utilizada para incluir información adicional del tercero que
        *   no se haya contemplado en las secciones anteriores, o para realizar alguna transformación o formateo específico
        *   de algún dato que se requiera en el destino final. Es importante resaltar que la estructura y los datos
        *   incluidos en esta sección pueden variar significativamente acorde a las necesidades particulares de cada caso, 
        *   por lo que se recomienda analizar cuidadosamente la información que se desea incluir y su formato, para asegurar 
        *   una integración exitosa y sin contratiempos.
    */
    DECLARE @entidad_dinamica_tercero   TABLE
    (
        id_orden                NVARCHAR(50),
        f200_id                 NVARCHAR(50),
        f753_id_grupo_entidad   NVARCHAR(50),
        f753_id_entidad         NVARCHAR(50),
        f753_id_atributo        NVARCHAR(50),
        f753_id_maestro         NVARCHAR(50),
        f753_id_maestro_detalle NVARCHAR(50)
    );

    /*
        *   Entidad Dinamica Cliente: Esta sección puede ser utilizada para incluir información adicional del cliente que 
        *   no se haya contemplado en las secciones anteriores, o para realizar alguna transformación o formateo específico 
        *   de algún dato que se requiera en el destino final. Es importante resaltar que la estructura y los datos 
        *   incluidos en esta sección pueden variar significativamente acorde a las necesidades particulares de cada caso, 
        *   por lo que se recomienda analizar cuidadosamente la información que se desea incluir y su formato, para asegurar 
        *   una integración exitosa y sin contratiempos.
    */
    DECLARE @entidad_dinamica_cliente   TABLE
    (
        id_orden        NVARCHAR(50),
        f201_id_tercero NVARCHAR(50),
        f753_dato_texto NVARCHAR(50)
    );

    ---<=================================================================================================>---

    DECLARE @t200_mm_terceros TABLE
    (
        f200_id         NVARCHAR(50)
    );

    ---<=================================================================================================>---

    /*
        *   Extracción de las órdenes a procesar acorde a los filtros definidos en la sección de parámetros de ejecución,
        *   así como a la configuración de negocio establecida para la selección de las órdenes. Es importante resaltar que
        *   esta sección debe ser ajustada acorde a las necesidades particulares de cada caso, considerando los diferentes
        *   escenarios y casos de uso que se puedan presentar en la operación real del conector.
    */
    DECLARE @ordenes    TABLE
    (
        id_orden            NVARCHAR(MAX),
        orden_obj_origen    NVARCHAR(MAX)
    );

    /*
        *   Extracción de las órdenes a procesar acorde a los filtros definidos en la sección de parámetros de ejecución, 
        *   así como a la configuración de negocio establecida para la selección de las órdenes. Es importante resaltar que 
        *   esta sección debe ser ajustada acorde a las necesidades particulares de cada caso, considerando los diferentes 
        *   escenarios y casos de uso que se puedan presentar en la operación real del conector.
    */
    INSERT INTO @ordenes
    SELECT  TOP (@batch_size)
        id_orden,
        orden_obj_origen
    FROM ordenes
    WHERE 
        id_estado   =   1 
        AND 
        (
            intentos    <=  @num_max_intentos
            OR
            intentos IS NULL
        )
        AND 
        ISNULL(endpoint,'') !=  @endpoint_terceros 
        AND 
        ISNULL(endpoint,'') !=  @endpoint_puntos_envio;

    /*
        *   Extracción de la información relevante de la orden para su posterior formateo y estructuración acorde a las
        *   necesidades del destino final
    */
    DECLARE @order_data    TABLE
    (
        id_orden            NVARCHAR(50),
        id                  NVARCHAR(50),
        email               NVARCHAR(255),
        firstName           NVARCHAR(100),
        lastName            NVARCHAR(100),
        documentType        NVARCHAR(50),
        document            NVARCHAR(100),
        phone               NVARCHAR(20),
        corporateName       NVARCHAR(255),
        tradeName           NVARCHAR(255),
        corporateDocument   NVARCHAR(255),
        stateInscription    NVARCHAR(255),
        corporatePhone      NVARCHAR(255),
        isCorporate         NVARCHAR(10),
        street              NVARCHAR(255),
        complement          NVARCHAR(255),
        neighborhood        NVARCHAR(255),
        postalCode          NVARCHAR(50),
        currencyCode        NVARCHAR(10),
        paymentSystemName   NVARCHAR(255)
    );

    /*
        *   Formateo y estructuración de los datos del cliente
    */
    DECLARE @datos_formateados_cliente  TABLE
    (
        id_orden            NVARCHAR(50),
        id_persona_natural  NVARCHAR(50),
        id_persona_juridica NVARCHAR(50),
        es_persona_juridica BIT,
        email               NVARCHAR(255),
        nombre              NVARCHAR(100),
        apellido            NVARCHAR(100),
        nombre_completo     NVARCHAR(200),
        nombre_empresa      NVARCHAR(255),
        tipo_documento      NVARCHAR(50),
        telefono            NVARCHAR(50),
        codigo_postal       NVARCHAR(50),
        direccion_1         NVARCHAR(255),
        direccion_2         NVARCHAR(255),
        id_departamento     NVARCHAR(10),
        id_ciudad           NVARCHAR(10),
        moneda              NVARCHAR(10),
        tipo_pago           NVARCHAR(255),
        endpoint            NVARCHAR(255)
    );

    --<=================================================================================================================>---

    /*
        *   Extracción de la información relevante de la orden para su posterior formateo y estructuración acorde a las 
        *   necesidades del destino final
    */
    INSERT INTO @order_data
    SELECT 
        id_orden,
        id                  =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.id')),
        email               =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email')),
        firstName           =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName')),
        lastName            =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')),
        documentType        =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType')),
        document            =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')),
        phone               =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone')),
        corporateName       =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateName')),
        tradeName           =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.tradeName')),
        corporateDocument   =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')),
        stateInscription    =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.stateInscription')),
        corporatePhone      =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporatePhone')),
        isCorporate         =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.isCorporate')),
        street              =   UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street')),
        complement          =   UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement')),
        neighborhood        =   UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood')),
        postalCode          =   UPPER(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode')),
        currencyCode        =   UPPER(JSON_VALUE(orden_obj_origen, '$.storePreferencesData.currencyCode')),
        paymentSystemName   =   UPPER(JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName'))
    FROM @ordenes;

    /*
        *   Formateo y estructuración de la información del cliente para su posterior uso en las diferentes secciones del 
        *   conector, así como para la integración final
    */

    INSERT INTO @datos_formateados_cliente
    SELECT 
        id_orden,
        id_persona_natural  =   
            REPLACE(
                REPLACE(
                    document, 
                    '.', 
                    ''
                ), 
                ' ', 
                ''
            ),
        id_persona_juridica =   
            REPLACE(
                REPLACE(
                    corporateDocument, 
                    '.', 
                    ''
                ), 
                ' ', 
                ''
            ),
        es_persona_juridica =   CAST(isCorporate AS BIT),
        email               =   
            CASE 
                WHEN CHARINDEX('@', email) > 0
                THEN
                    LEFT(email, CHARINDEX('@', email) - 1)
                    + '@' +
                    CASE
                        WHEN CHARINDEX(
                                '-', 
                                SUBSTRING(
                                    email,
                                    CHARINDEX('@', email) + 1,
                                    LEN(email)
                                )
                            ) > 0
                        THEN
                            LEFT(
                                SUBSTRING(
                                    email,
                                    CHARINDEX('@', email) + 1,
                                    LEN(email)
                                ),
                                CHARINDEX(
                                    '-',
                                    SUBSTRING(
                                        email,
                                        CHARINDEX('@', email) + 1,
                                        LEN(email)
                                    )
                                ) - 1
                            )
                        ELSE
                            SUBSTRING(
                                email,
                                CHARINDEX('@', email) + 1,
                                LEN(email)
                            )
                    END
                ELSE
                    email
            END
            ,
        nombre              =   UPPER(firstName),
        apellido            =   UPPER(lastName),
        nombre_completo     =   UPPER(CONCAT(firstName, ' ', lastName)),
        nombre_empresa      =   UPPER(corporateName),
        tipo_documento      =   UPPER(documentType),
        telefono            =   
            REPLACE(
                REPLACE(
                    phone, 
                    ' ', 
                    ''
                ), 
                '+57', 
                ''
            ),
        codigo_postal       =   postalCode,
        direccion_1         =   
            LEFT(
                CONCAT(
                    street,
                    ' ',
                    complement
                ),
                40
            ),
        direccion_2         =   
            LEFT(
                neighborhood, 
                40
            ),
        id_departamento     =   LEFT(postalCode, 2),
        id_ciudad           =   
            SUBSTRING(
                postalCode,
                3,
                LEN(postalCode)
            ),
        moneda              =   currencyCode,
        tipo_pago           =   paymentSystemName,
        endpoint            =   @endpoint_terceros
    FROM @order_data
        LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t200_mm_terceros]
            ON  CASE CAST(isCorporate AS BIT) WHEN 0 THEN REPLACE(
                REPLACE(
                    document, 
                    '.', 
                    ''
                ), 
                ' ', 
                ''
            )
            WHEN 1 THEN REPLACE(
                REPLACE(
                    corporateDocument, 
                    '.', 
                    ''
                ), 
                ' ', 
                ''
            ) END = f200_id;

    --<=================================================================================================================>---

    /*
        *   Sección 1: Terceros
    */
    INSERT INTO @terceros
    SELECT
        o.id_orden,
        F200_ID                 =
            CASE    es_persona_juridica
                WHEN    1
                    THEN    id_persona_juridica
                ELSE
                    id_persona_natural
            END,
        F200_NIT                =   
            CASE    es_persona_juridica
                WHEN    1
                    THEN    id_persona_juridica
                ELSE
                    id_persona_natural
            END,
        F200_ID_TIPO_IDENT      =
            CASE    es_persona_juridica
                WHEN    1
                    THEN    'N'
                ELSE
                    'C'
            END,
        F200_IND_TIPO_TERCERO   =
            CASE    es_persona_juridica
                WHEN    1
                    THEN    '2'
                ELSE
                    '1'
            END,
        F200_RAZON_SOCIAl       =
            CASE    es_persona_juridica
                WHEN    1
                    THEN    nombre_empresa
                ELSE
                    nombre_completo
            END,
        F200_APELLIDO1          =
            CASE
                WHEN    CHARINDEX(' ', apellido) > 0
                    THEN
                        LEFT(
                            apellido, 
                            CHARINDEX(
                                ' ', 
                                apellido
                            ) - 1
                        )
                ELSE    apellido
            END,
        F200_APELLIDO2          =
            LTRIM(
                CASE
                    WHEN CHARINDEX(' ', apellido) > 0
                        THEN SUBSTRING(
                            apellido,
                            CHARINDEX(
                                ' ', 
                                apellido
                            ) + 1,
                            LEN(apellido))
                    ELSE ''
                END
            ),
        F200_NOMBRES            =   nombre,
        F200_NOMBRE_EST         =   
            CASE    es_persona_juridica
                WHEN    1
                    THEN    nombre_empresa
                ELSE
                    nombre_completo
            END,
        F015_CONTACTO           =   nombre_completo,
        F015_DIRECCION1         =   direccion_1,
        F015_DIRECCION2         =   direccion_2,
        F015_ID_DEPTO           =   id_departamento,
        F015_ID_CIUDAD          =   id_ciudad,
        F015_TELEFONO           =   telefono,
        F015_COD_POSTAL         =   LEFT(codigo_postal, 8),
        F015_EMAIL              =   email,
        F200_FECHA_NACIMIENTO   =   @fecha_actual,
        F200_ID_CIIU            =   
            CASE    es_persona_juridica
                WHEN    1
                    THEN    @id_ciiu_juridica
                ELSE @id_ciiu_natural 
            END,
        F015_CELULAR            =   telefono
    FROM    @ordenes    AS  o
        LEFT JOIN   @datos_formateados_cliente AS  dfc
            ON  dfc.id_orden =   o.id_orden

    /*
        *   Sección 2: Clientes
    */
    INSERT INTO @clientes
    SELECT
        o.id_orden,
        F201_ID_TERCERO             =
            CASE    es_persona_juridica
                WHEN    1
                    THEN    id_persona_juridica
                ELSE
                    id_persona_natural
            END,
        F201_DESCRIPCION_SUCURSAL   =   nombre_completo,
        F201_ID_MONEDA              =   moneda,
        F201_ID_TIPO_CLI            =
            CASE
                WHEN 
                    tipo_pago   LIKE    '%ADDI%'
                    THEN    @id_tio_cli_addi
                WHEN 
                    tipo_pago   LIKE    '%MERCADO%'
                    THEN    @id_tio_cli_mercado_pago
    /*
                WHEN
                    JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') IN
                    ('Diners', 'Mastercard', 'Visa', 'PSE', 'Efecty')
                    THEN @id_tio_cli_defecto
    */
                WHEN 
                    tipo_pago   =   'PAGO CONTRA ENTREGA'
                    THEN    @id_tio_cli_pago_contra_entrega
                WHEN 
                    tipo_pago   =   'PAYU NO VARIX'
                    THEN    @id_tio_cli_payu_no_varix
                WHEN 
                    tipo_pago   =   'TRANSFERENCIAS'
                    THEN    @id_tio_cli_transferencias
                ELSE @id_tio_cli_defecto
            END,
        F015_CONTACTO               =   nombre_completo,
        F015_DIRECCION1             =   direccion_1,
        F015_DIRECCION2             =   direccion_2,
        F015_ID_DEPTO               =   id_departamento,
        F015_ID_CIUDAD              =   id_ciudad,
        F015_TELEFONO               =   telefono,
        F015_COD_POSTAL             =   LEFT(codigo_postal, 8),
        F015_EMAIL                  =   email,
        F201_FECHA_INGRESO          =   @fecha_actual,
        F015_CELULAR                =   telefono
    FROM    @ordenes    AS  o
        LEFT JOIN   @datos_formateados_cliente AS  dfc
            ON  dfc.id_orden =   o.id_orden

    /*
        *   Sección 3: Impuestos y Retenciones
    */
    INSERT INTO @impuestos_y_retenciones
    SELECT
        o.id_orden,
        F_TIPO_REG          =   '46',
        F_ID_TERCERO        = 
            CASE    es_persona_juridica
                WHEN    1
                    THEN    id_persona_juridica
                ELSE
                    id_persona_natural
            END,
        F_ID_CLASE          =   '1',
        F_ID_VALOR_TERCERO  =   '1',
        F_ID_LLAVE          =   ''
    FROM    @ordenes    AS  o
        LEFT JOIN   @datos_formateados_cliente AS  dfc
            ON  dfc.id_orden =   o.id_orden

    /*
        *   Sección 4: Criterios de Clientes
    */
    INSERT INTO @criterios_clientes
    SELECT
        o.id_orden,
        F207_ID_TERCERO         = 
            CASE    es_persona_juridica
                WHEN    1
                    THEN    id_persona_juridica
                ELSE
                    id_persona_natural
            END,
        F207_ID_PLAN_CRITERIOS  =   '002', 
        F207_ID_CRITERIO_MAYOR  =   '002'
    FROM    @ordenes    AS  o
        LEFT JOIN   @datos_formateados_cliente AS  dfc
            ON  dfc.id_orden =   o.id_orden;

    /*
        *   Sección 5: Entidad Dinamica Tercero
    */
    INSERT INTO @entidad_dinamica_tercero
    SELECT
        o.id_orden,
        f200_id =
            CASE    es_persona_juridica
                WHEN    1
                    THEN    id_persona_juridica
                ELSE
                    id_persona_natural
            END,
        f753_id_grupo_entidad   =   'ID PROCEDENCIA FE2.1',
        f753_id_entidad         =   'EUNOECO036',
        f753_id_atributo        =   'co036_id_procedencia_org', 
        f753_id_maestro         =   'MUNOECO043', 
        f753_id_maestro_detalle =   '10'
    FROM    @ordenes    AS  o
        LEFT JOIN   @datos_formateados_cliente AS  dfc
            ON  dfc.id_orden =   o.id_orden;

    /*
        *   Sección 6: Entidad Dinamica Cliente   
    */
    INSERT INTO @entidad_dinamica_cliente
    SELECT
        o.id_orden,
        f201_id_tercero = 
            CASE    es_persona_juridica
                WHEN    1
                    THEN    id_persona_juridica
                ELSE
                    id_persona_natural
            END,
        f753_dato_texto =   email
    FROM    @ordenes    AS  o
        LEFT JOIN   @datos_formateados_cliente AS  dfc
            ON  dfc.id_orden =   o.id_orden;

    --<=================================================================================================================>---

    /*
        *   Integración: Actualización de la orden con la información formateada y estructurada para el destino final
    */
    UPDATE ordenes
    SET
        endpoint            =   dfc.endpoint,
        id_estado           =   1,
        intentos            =   0,
        fecha_creacion      =   GETDATE(),
        orden_obj_destino   =
            JSON_QUERY(
                (
                    SELECT
                        [Terceros]=
                            JSON_QUERY(
                                (
                                    SELECT *
                                    FROM @terceros  AS t
                                    WHERE t.id_orden = o.id_orden
                                    FOR JSON PATH, INCLUDE_NULL_VALUES
                                )
                            ),
                        [Clientes]=
                            JSON_QUERY(
                                (
                                    SELECT *
                                    FROM @clientes  AS t
                                    WHERE t.id_orden = o.id_orden
                                    FOR JSON PATH, INCLUDE_NULL_VALUES
                                )
                            ),
                        [ImpuestosYRetenciones]=
                            JSON_QUERY(
                                (
                                    SELECT *
                                    FROM @impuestos_y_retenciones  AS ip
                                    WHERE ip.id_orden = o.id_orden
                                    FOR JSON PATH, INCLUDE_NULL_VALUES
                                )
                            ),
                        [CriteriosClientes]=
                            JSON_QUERY(
                                (
                                    SELECT *
                                    FROM @criterios_clientes  AS cc
                                    WHERE cc.id_orden = o.id_orden
                                    FOR JSON PATH, INCLUDE_NULL_VALUES
                                )
                            ),
                        [EntidadDinamicaTercero]=
                            JSON_QUERY(
                                (
                                    SELECT *
                                    FROM @entidad_dinamica_tercero  AS edt
                                    WHERE edt.id_orden = o.id_orden
                                    FOR JSON PATH, INCLUDE_NULL_VALUES
                                )
                            ),
                        [EntidadDinamicaCliente]=
                            JSON_QUERY(
                                (
                                    SELECT *
                                    FROM @entidad_dinamica_cliente  AS edc
                                    WHERE edc.id_orden = o.id_orden
                                    FOR JSON PATH, INCLUDE_NULL_VALUES
                                )
                            )
                    FOR JSON PATH, 
                    WITHOUT_ARRAY_WRAPPER, 
                    INCLUDE_NULL_VALUES
                )
            )
    FROM    @ordenes    AS  o
        INNER JOIN  ordenes     AS  ord
            ON  ord.id_orden =   o.id_orden
        INNER JOIN @datos_formateados_cliente AS  dfc
            ON  dfc.id_orden =   o.id_orden;
    
END TRY
BEGIN CATCH

    -- ===========================================================
    -- SECCIÓN 8: MANEJO DE ERRORES
    -- ===========================================================

    DECLARE @errorMsg     NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @errorSev     INT            = ERROR_SEVERITY();
    DECLARE @errorState   INT            = ERROR_STATE();
    DECLARE @errorLine    INT            = ERROR_LINE();
    DECLARE @errorProc    NVARCHAR(200)  = ISNULL(ERROR_PROCEDURE(), N'Script inline');

    -- Mensaje de error enriquecido con contexto
    DECLARE @msgFinal NVARCHAR(4000) = CONCAT(
        N'[PEDIDO_INTEGRACION_VTEX] Error en línea ',  CAST(@errorLine  AS NVARCHAR), N' | ',
        N'Procedimiento: ',                             @errorProc,                    N' | ',
        N'Mensaje: ',                                   @errorMsg
    );

    RAISERROR(@msgFinal, @errorSev, @errorState);

END CATCH;
/*
DECLARE @endpoint NVARCHAR(500) = 'http://localhost:8083/v3.1/ConectoresImportar?idCompania=4826&idSistema=2&idDocumento=227300&nombreDocumento=TERCERO_CLIENTE_VTEX&validarEstructura=true'
UPDATE ordenes
SET 
    endpoint = @endpoint,
	id_estado = 1,
    intentos = 0,
    fecha_creacion = GETDATE(),
    orden_obj_destino = JSON_QUERY(( 
        SELECT
		--Nodo Terceros

		JSON_QUERY((
                    SELECT *
                    FROM(
                        SELECT
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')AS F200_ID,
                        CASE JSON_VALUE(orden_obj_origen, '$.clientProfileData.isCorporate')
                        WHEN 'True' THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
                        ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')END AS F200_NIT,

                        CASE JSON_VALUE(orden_obj_origen, '$.clientProfileData.isCorporate')
                        WHEN 'True' THEN 'N'
                        ELSE 'C' END
                        AS F200_ID_TIPO_IDENT, -- - VALIDAR JSON
                        CASE JSON_VALUE(orden_obj_origen, '$.clientProfileData.isCorporate')
                        WHEN 'True' THEN '2'
                        ELSE '1' END AS F200_IND_TIPO_TERCERO, ----VALIDAR JSON
                        --CONCAT(
                            --JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ',
                            --JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                            --)AS F200_RAZON_SOCIAL, -- - VALIDAR ERP
                        CASE JSON_VALUE(orden_obj_origen, '$.clientProfileData.isCorporate')
                        WHEN 'True' THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateName')
                        ELSE '' END AS F200_RAZON_SOCIAl,
                        CASE
                        WHEN CHARINDEX(' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')) > 0
                        THEN LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'), CHARINDEX(' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')) - 1)
                        ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                        END AS F200_APELLIDO1,
                        LTRIM(
                            CASE
                            WHEN CHARINDEX(' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')) > 0
                            THEN SUBSTRING(
                                JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'),
                                CHARINDEX(' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')) + 1,
                                LEN(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')))
                            ELSE ''
                            END)AS F200_APELLIDO2,
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName')AS F200_NOMBRES,
                        CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ',
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))AS F200_NOMBRE_EST,
                        CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ',
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))AS F015_CONTACTO,
                        LEFT(CONCAT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), ' ', JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement')), 40)AS F015_DIRECCION1,

                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood'), 40)as F015_DIRECCION2,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2)AS F015_ID_DEPTO,
                        SUBSTRING(
                            JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'),
                            3,
                            LEN(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode')))AS F015_ID_CIUDAD,
                        REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), '+57', '')AS F015_TELEFONO,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 8)as F015_COD_POSTAL,
                        CASE 
    WHEN CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.clientProfileData.email')) > 0
    THEN LEFT(
            JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'),
            CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.clientProfileData.email')) - 1
         )
    ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.email') end AS F015_EMAIL,
                        FORMAT(GETDATE(), 'yyyyMMdd')AS F200_FECHA_NACIMIENTO,
                        CASE JSON_VALUE(orden_obj_origen, '$.clientProfileData.isCorporate')
                        WHEN 'True' THEN '9999'
                        ELSE '0010' END AS F200_ID_CIIU,
                        REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), '+57', '')AS F015_CELULAR)AS Terceros
                    FOR JSON PATH, INCLUDE_NULL_VALUES))AS Terceros,

            --Nodo Clientes
            JSON_QUERY((
                    SELECT
                    JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')AS F201_ID_TERCERO,

                    CONCAT(
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ',
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))as F201_DESCRIPCION_SUCURSAL,
                    JSON_VALUE(orden_obj_origen, '$.storePreferencesData.currencyCode')AS F201_ID_MONEDA,
                    CASE
                    WHEN UPPER(JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName')) LIKE '%ADDI%'
							THEN 'W001'


                        --WHEN JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName')IN
                        --('Diners', 'Mastercard', 'Visa', 'PSE', 'Efecty')
                        --THEN 'W003'

                        WHEN JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = 'PayU No Varix'
                        THEN 'W005'

                        WHEN JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName')LIKE '%Mercado%'
                        THEN 'W002'

                        WHEN JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = 'Pago contra entrega'
                        THEN 'W004'

                        WHEN JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = 'Transferencias'
                        THEN 'W006'

                        ELSE 'W003'
                        END AS F201_ID_TIPO_CLI,
                    CONCAT(
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ',
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))AS F015_CONTACTO,
                    LEFT(CONCAT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), ' ', JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement')), 40)AS F015_DIRECCION1,

                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood'), 40)as F015_DIRECCION2,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2)AS F015_ID_DEPTO,
                    SUBSTRING(
                        JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'),
                        3,
                        LEN(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode')))AS F015_ID_CIUDAD,
                    REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), '+57', '')AS F015_TELEFONO,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 8)AS F015_COD_POSTAL,
                     CASE 
    WHEN CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.clientProfileData.email')) > 0
    THEN LEFT(
            JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'),
            CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.clientProfileData.email')) - 1
         )
    ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.email') end AS F015_EMAIL,
                    FORMAT(GETDATE(), 'yyyyMMdd')AS F201_FECHA_INGRESO,
                    REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), '+57', '')AS f015_celular

                    FOR JSON PATH, INCLUDE_NULL_VALUES))AS Clientes,

            --Nodo Impuestos y Retenciones
            JSON_QUERY((
                    SELECT *
                    FROM(
                        SELECT
                        '46' AS F_TIPO_REG,
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')AS F_ID_TERCERO,
                        '1' AS F_ID_CLASE,
                        '1' AS F_ID_VALOR_TERCERO,
                        '' AS F_ID_LLAVE)AS ImpuestosYRetenciones
                    FOR JSON PATH, INCLUDE_NULL_VALUES))AS ImpuestosYRetenciones,

            --Nodo CriteriosClientes
            JSON_QUERY((
                    SELECT *
                    FROM(
                        SELECT

                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')AS F207_ID_TERCERO,
                        '002' AS 'F207_ID_PLAN_CRITERIOS', '002' AS 'F207_ID_CRITERIO_MAYOR')AS CriteriosClientes
                    FOR JSON PATH, INCLUDE_NULL_VALUES))AS CriteriosClientes,
            --Nodo Ent_Dinamica_Tercero
            JSON_QUERY((
                    SELECT *
                    FROM(
                        -- - naturales
                        SELECT
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')AS f200_id, 
                        'ID PROCEDENCIA FE2.1' AS 'f753_id_grupo_entidad', 
                        'EUNOECO036' AS 'f753_id_entidad', 
                        'co036_id_procedencia_org' AS 'f753_id_atributo', 
                        'MUNOECO043' AS 'f753_id_maestro', 
                        '10' AS 'f753_id_maestro_detalle')AS EntidadDinamicaTercero
                    FOR JSON PATH, INCLUDE_NULL_VALUES))AS EntidadDinamicaTercero,

            --NODO Ent_Dinamica_Cliente
            JSON_QUERY((
                    SELECT *
                    FROM(
                        SELECT

                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')AS f201_id_tercero,
                         CASE 
    WHEN CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.clientProfileData.email')) > 0
    THEN LEFT(
            JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'),
            CHARINDEX('-', JSON_VALUE(orden_obj_origen, '$.clientProfileData.email')) - 1
         )
    ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.email') end AS f753_dato_texto
                      ) AS EntidadDinamicaCliente
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS EntidadDinamicaCliente

        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    )) 
FROM ordenes
WHERE 
    id_estado = 1 
    AND (intentos <= 3 or intentos is null)
    AND ISNULL(endpoint,'') != @endpoint;
*/