/*  TERCEROS CLIENTES - ORTOPEDICOS FUTURO*/
/*
 * ============================================================================
 * SCRIPT  : TERCERO_CLIENTE_VTEX
 * AUTOR   : Juan Camilo Mejía Echavarría
 * FECHA   : 2026-05-13
 * VERSION : 1.1 (Modificado para bifurcación cliente nuevo/existente)
 * ENTORNO : Pruebas
 * ============================================================================
 * DESCRIPCIÓN:
 *   Script modificado para diferenciar entre clientes nuevos y existentes:
 *   - Cliente NUEVO: Genera estructura completa (Terceros, Clientes, Impuestos, etc.) 
 *     y envía a @endpoint_terceros
 *   - Cliente EXISTENTE: Genera solo información de Punto de Envío y envía a 
 *     @endpoint_puntos_envio
 * 
 * DEPENDENCIAS:
 *   - Tablas: [ordenes, t200_mm_terceros]
 *   - Permisos: SELECT en dbo.ordenes y dbo.t200_mm_terceros, UPDATE en dbo.ordenes
 * 
 * SEGURIDAD:
 *   - Validación de endpoints contra inyección SQL
 *   - TRY/CATCH con trazabilidad de errores
 *   - Batch controlado para evitar bloqueos
 * ============================================================================
 */

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRY
    /* =============================================
       PARÁMETROS DE CONFIGURACIÓN GENERAL
       ============================================= */
    DECLARE @id_compania                    NVARCHAR(4)     =   '4826',
            @id_sistema                     NVARCHAR(1)     =   '2',
            @id_documento_tercero           NVARCHAR(6)     =   '227300',
            @nombre_documento_tercero       NVARCHAR(255)   =   'TERCERO_CLIENTE_VTEX',
            @id_documento_punto_envio       NVARCHAR(6)     =   '244000',
            @nombre_documento_punto_envio   NVARCHAR(255)   =   'Puntos_De_Envio_Ortopedicos_Futuro',
            @validar_estructura             NVARCHAR(5)     =   'true';

    /* =============================================
       ENDPOINTS CON VALIDACIÓN DE SEGURIDAD
       ============================================= */
    DECLARE @endpoint_terceros      NVARCHAR(500),
            @endpoint_puntos_envio  NVARCHAR(500);

    SET @endpoint_terceros  =   'http://localhost:8083/v3.1/ConectoresImportar?idCompania='
                            +   @id_compania + '&idSistema=' + @id_sistema
                            +   '&idDocumento=' + @id_documento_tercero
                            +   '&nombreDocumento=' + @nombre_documento_tercero                                            
                            +   '&validarEstructura=' + @validar_estructura;

    SET @endpoint_puntos_envio  =   'http://localhost:8083/v3.1/ConectoresImportar?idCompania='
                                +   @id_compania + '&idSistema=' + @id_sistema
                                +   '&idDocumento=' + @id_documento_punto_envio
                                +   '&nombreDocumento=' + @nombre_documento_punto_envio                                            
                                +   '&validarEstructura=' + @validar_estructura;

    /* 🔒 Validación contra inyección SQL en endpoints */
    IF  @endpoint_terceros      LIKE    '%;%' 
        OR 
        @endpoint_terceros      LIKE    '%--%' 
        OR 
        @endpoint_terceros      LIKE    '%/*%'
        OR 
        @endpoint_puntos_envio  LIKE    '%;%' 
        OR 
        @endpoint_puntos_envio  LIKE    '%--%' 
        OR 
        @endpoint_puntos_envio  LIKE    '%/*%'
    BEGIN
        RAISERROR('Error de seguridad: Endpoint con caracteres sospechosos detectado', 16, 1);
        RETURN;
    END

    /* =============================================
       PARÁMETROS DE EJECUCIÓN Y NEGOCIO
       ============================================= */
    DECLARE @batch_size         INT         =   25,
            @num_max_intentos   INT         =   3,
            @fecha_actual       NVARCHAR(8) =   FORMAT(GETDATE(), 'yyyyMMdd');

    DECLARE @id_ciiu_natural    NVARCHAR(4) =   '0010',
            @id_ciiu_juridica   NVARCHAR(4) =   '9999';

    DECLARE @id_tio_cli_addi                NVARCHAR(4) =   'W001',
            @id_tio_cli_mercado_pago        NVARCHAR(4) =   'W002',
            @id_tio_cli_defecto             NVARCHAR(4) =   'W003',
            @id_tio_cli_pago_contra_entrega NVARCHAR(4) =   'W004',
            @id_tio_cli_payu_no_varix       NVARCHAR(4) =   'W005',
            @id_tio_cli_transferencias      NVARCHAR(4) =   'W006';

    /* =============================================
       TABLAS TEMPORALES PARA CONSTRUCCIÓN DE JSON
       ============================================= */

    DECLARE @terceros TABLE
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

    DECLARE @clientes TABLE
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

    DECLARE @impuestos_y_retenciones TABLE
    (
        id_orden            NVARCHAR(50),
        F_TIPO_REG          NVARCHAR(2),
        F_ID_TERCERO        NVARCHAR(50),
        F_ID_CLASE          NVARCHAR(2),
        F_ID_VALOR_TERCERO  NVARCHAR(2),
        F_ID_LLAVE          NVARCHAR(2)
    );

    DECLARE @criterios_clientes TABLE
    (
        id_orden                NVARCHAR(50),
        F207_ID_TERCERO         NVARCHAR(50),
        F207_ID_PLAN_CRITERIOS  NVARCHAR(50),
        F207_ID_CRITERIO_MAYOR  NVARCHAR(50)
    );

    DECLARE @entidad_dinamica_tercero TABLE
    (
        id_orden                NVARCHAR(50),
        f200_id                 NVARCHAR(50),
        f753_id_grupo_entidad   NVARCHAR(50),
        f753_id_entidad         NVARCHAR(50),
        f753_id_atributo        NVARCHAR(50),
        f753_id_maestro         NVARCHAR(50),
        f753_id_maestro_detalle NVARCHAR(50)
    );

    DECLARE @entidad_dinamica_cliente TABLE
    (
        id_orden        NVARCHAR(50),
        f201_id_tercero NVARCHAR(50),
        f753_dato_texto NVARCHAR(255)
    );

    /* =============================================
       TABLA PARA PUNTOS DE ENVÍO (Cliente Existente)
       ============================================= */
    DECLARE @puntos_de_envio TABLE
    (
        id_orden                    NVARCHAR(50),
        F215_ID                     NVARCHAR(3),
        F215_ID_TERCERO             NVARCHAR(50),
        F215_DESCRIPCION            NVARCHAR(255),
        F015_CONTACTO               NVARCHAR(255),
        F015_DIRECCION1             NVARCHAR(40),
        F015_DIRECCION2             NVARCHAR(40),
        F015_ID_DEPTO               NVARCHAR(10),
        F015_ID_CIUDAD              NVARCHAR(10),
        F015_COD_POSTAL             NVARCHAR(10),
        F015_TELEFONO               NVARCHAR(20),
        F015_CELULAR                NVARCHAR(20),
        F015_EMAIL                  NVARCHAR(255)
    );

    /* =============================================
       EXTRACCIÓN DE ÓRDENES A PROCESAR
       ============================================= */
    DECLARE @ordenes TABLE
    (
        id_orden            NVARCHAR(50),
        orden_obj_origen    NVARCHAR(MAX)
    );

    INSERT INTO @ordenes
    SELECT TOP (@batch_size)
        id_orden,
        orden_obj_origen
    FROM ordenes WITH (NOLOCK)
    WHERE 
        id_estado = 1 
        AND 
        (
            intentos <= @num_max_intentos 
            OR 
            intentos IS NULL
        )
        AND 
        ISNULL(endpoint,'') NOT IN (@endpoint_terceros, @endpoint_puntos_envio)
    ORDER BY id_orden;  -- Orden para procesamiento consistente

    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'No hay órdenes pendientes para procesar en este batch.';
        RETURN;
    END

    /* =============================================
       EXTRACCIÓN Y PARSEO DE DATOS DESDE JSON VTEX
       ============================================= */
    DECLARE @order_data TABLE
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

    INSERT INTO @order_data
    SELECT 
        id_orden,
        id                  =   UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.id')),
        email               =   LOWER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email')),
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

    /* =============================================
       FORMATEO DE DATOS CON VERIFICACIÓN DE EXISTENCIA
       ============================================= */
    DECLARE @datos_formateados_cliente TABLE
    (
        id_orden                NVARCHAR(50),
        id_persona_natural      NVARCHAR(50),
        id_persona_juridica     NVARCHAR(50),
        es_persona_juridica     BIT,
        email                   NVARCHAR(255),
        nombre                  NVARCHAR(100),
        apellido                NVARCHAR(100),
        nombre_completo         NVARCHAR(200),
        nombre_empresa          NVARCHAR(255),
        tipo_documento          NVARCHAR(50),
        telefono                NVARCHAR(50),
        codigo_postal           NVARCHAR(50),
        direccion_1             NVARCHAR(255),
        direccion_2             NVARCHAR(255),
        id_departamento         NVARCHAR(10),
        id_ciudad               NVARCHAR(10),
        moneda                  NVARCHAR(10),
        tipo_pago               NVARCHAR(255),
        endpoint                NVARCHAR(500),
        cliente_existe          BIT DEFAULT 0  -- ← NUEVO: Control de bifurcación
    );

    INSERT INTO @datos_formateados_cliente
    SELECT 
        od.id_orden,
        id_persona_natural  =   REPLACE(REPLACE(od.document, '.', ''), ' ', ''),
        id_persona_juridica =   REPLACE(REPLACE(od.corporateDocument, '.', ''), ' ', ''),
        es_persona_juridica =   CAST(CASE WHEN UPPER(od.isCorporate) IN ('TRUE','1') THEN 1 ELSE 0 END AS BIT),
        email               =
        CASE 
            WHEN    CHARINDEX('@', od.email) > 0 
                THEN
                    LEFT(
                        od.email, 
                        CHARINDEX(
                            '@', 
                            od.email
                        ) - 1
                    ) + '@' +
                    CASE
                        WHEN    
                            CHARINDEX(
                                '-', 
                                SUBSTRING(
                                    od.email, 
                                    CHARINDEX(
                                        '@', 
                                        od.email
                                    ) + 1, 
                                    LEN(od.email)
                                )
                            ) > 0 
                            THEN
                                LEFT(SUBSTRING(od.email, CHARINDEX('@', od.email) + 1, LEN(od.email)),
                                CHARINDEX('-', SUBSTRING(od.email, CHARINDEX('@', od.email) + 1, LEN(od.email))) - 1)
                        ELSE    SUBSTRING(od.email, CHARINDEX('@', od.email) + 1, LEN(od.email))
                    END
            ELSE    od.email 
        END,
        nombre              =   UPPER(od.firstName),
        apellido            =   UPPER(od.lastName),
        nombre_completo     =   UPPER(CONCAT(od.firstName, ' ', od.lastName)),
        nombre_empresa      =   UPPER(od.corporateName),
        tipo_documento      =   UPPER(od.documentType),
        telefono            =   REPLACE(REPLACE(od.phone, ' ', ''), '+57', ''),
        codigo_postal       =   od.postalCode,
        direccion_1         =   LEFT(CONCAT(od.street, ' ', od.complement), 40),
        direccion_2         =   LEFT(od.neighborhood, 40),
        id_departamento     =   LEFT(od.postalCode, 2),
        id_ciudad           =   SUBSTRING(od.postalCode, 3, LEN(od.postalCode)),
        moneda              =   od.currencyCode,
        tipo_pago           =   od.paymentSystemName,
        endpoint            =
            CASE 
                WHEN    tmm.f200_id IS NOT NULL 
                    THEN    @endpoint_puntos_envio  -- Cliente existe
                ELSE @endpoint_terceros                                    -- Cliente nuevo
            END,
        cliente_existe      = 
            CASE 
                WHEN tmm.f200_id IS NOT NULL 
                    THEN 1 
                ELSE 0 
            END
    FROM @order_data od
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t200_mm_terceros] tmm WITH (NOLOCK)
        ON CASE CAST(CASE WHEN UPPER(od.isCorporate) IN ('TRUE','1') THEN 1 ELSE 0 END AS BIT)
            WHEN 0 THEN REPLACE(REPLACE(od.document, '.', ''), ' ', '')
            WHEN 1 THEN REPLACE(REPLACE(od.corporateDocument, '.', ''), ' ', '')
           END = tmm.f200_id;

    /* =============================================
       SECCIÓN 1: TERCEROS (Solo si cliente NUEVO)
       ============================================= */
    INSERT INTO @terceros
    SELECT
        o.id_orden,
        F200_ID = CASE dfc.es_persona_juridica WHEN 1 THEN dfc.id_persona_juridica ELSE dfc.id_persona_natural END,
        F200_NIT = CASE dfc.es_persona_juridica WHEN 1 THEN dfc.id_persona_juridica ELSE dfc.id_persona_natural END,
        F200_ID_TIPO_IDENT = CASE dfc.es_persona_juridica WHEN 1 THEN 'N' ELSE 'C' END,
        F200_IND_TIPO_TERCERO = CASE dfc.es_persona_juridica WHEN 1 THEN '2' ELSE '1' END,
        F200_RAZON_SOCIAl = CASE dfc.es_persona_juridica WHEN 1 THEN dfc.nombre_empresa ELSE dfc.nombre_completo END,
        F200_APELLIDO1 = CASE WHEN CHARINDEX(' ', dfc.apellido) > 0 THEN LEFT(dfc.apellido, CHARINDEX(' ', dfc.apellido) - 1) ELSE dfc.apellido END,
        F200_APELLIDO2 = LTRIM(CASE WHEN CHARINDEX(' ', dfc.apellido) > 0 THEN SUBSTRING(dfc.apellido, CHARINDEX(' ', dfc.apellido) + 1, LEN(dfc.apellido)) ELSE '' END),
        F200_NOMBRES = dfc.nombre,
        F200_NOMBRE_EST = CASE dfc.es_persona_juridica WHEN 1 THEN dfc.nombre_empresa ELSE dfc.nombre_completo END,
        F015_CONTACTO = dfc.nombre_completo,
        F015_DIRECCION1 = dfc.direccion_1,
        F015_DIRECCION2 = dfc.direccion_2,
        F015_ID_DEPTO = dfc.id_departamento,
        F015_ID_CIUDAD = dfc.id_ciudad,
        F015_TELEFONO = dfc.telefono,
        F015_COD_POSTAL = LEFT(dfc.codigo_postal, 8),
        F015_EMAIL = dfc.email,
        F200_FECHA_NACIMIENTO = @fecha_actual,
        F200_ID_CIIU = CASE dfc.es_persona_juridica WHEN 1 THEN @id_ciiu_juridica ELSE @id_ciiu_natural END,
        F015_CELULAR = dfc.telefono
    FROM @ordenes o
    INNER JOIN @datos_formateados_cliente dfc ON dfc.id_orden = o.id_orden
    WHERE dfc.cliente_existe = 0;  -- ← Solo clientes nuevos

    /* =============================================
       SECCIÓN 2: CLIENTES (Solo si cliente NUEVO)
       ============================================= */
    INSERT INTO @clientes
    SELECT
        o.id_orden,
        F201_ID_TERCERO = CASE dfc.es_persona_juridica WHEN 1 THEN dfc.id_persona_juridica ELSE dfc.id_persona_natural END,
        F201_DESCRIPCION_SUCURSAL = dfc.nombre_completo,
        F201_ID_MONEDA = dfc.moneda,
        F201_ID_TIPO_CLI = CASE
            WHEN dfc.tipo_pago LIKE '%ADDI%' THEN @id_tio_cli_addi
            WHEN dfc.tipo_pago LIKE '%MERCADO%' THEN @id_tio_cli_mercado_pago
            WHEN dfc.tipo_pago = 'PAGO CONTRA ENTREGA' THEN @id_tio_cli_pago_contra_entrega
            WHEN dfc.tipo_pago = 'PAYU NO VARIX' THEN @id_tio_cli_payu_no_varix
            WHEN dfc.tipo_pago = 'TRANSFERENCIAS' THEN @id_tio_cli_transferencias
            ELSE @id_tio_cli_defecto
        END,
        F015_CONTACTO = dfc.nombre_completo,
        F015_DIRECCION1 = dfc.direccion_1,
        F015_DIRECCION2 = dfc.direccion_2,
        F015_ID_DEPTO = dfc.id_departamento,
        F015_ID_CIUDAD = dfc.id_ciudad,
        F015_TELEFONO = dfc.telefono,
        F015_COD_POSTAL = LEFT(dfc.codigo_postal, 8),
        F015_EMAIL = dfc.email,
        F201_FECHA_INGRESO = @fecha_actual,
        F015_CELULAR = dfc.telefono
    FROM @ordenes o
    INNER JOIN @datos_formateados_cliente dfc ON dfc.id_orden = o.id_orden
    WHERE dfc.cliente_existe = 0;  -- ← Solo clientes nuevos

    /* =============================================
       SECCIÓN 3-6: SOLO PARA CLIENTES NUEVOS
       ============================================= */

    /* Impuestos y Retenciones */
    INSERT INTO @impuestos_y_retenciones
    SELECT o.id_orden, '46',
        CASE dfc.es_persona_juridica WHEN 1 THEN dfc.id_persona_juridica ELSE dfc.id_persona_natural END,
        '1', '1', ''
    FROM @ordenes o
    INNER JOIN @datos_formateados_cliente dfc ON dfc.id_orden = o.id_orden
    WHERE dfc.cliente_existe = 0;

    /* Criterios de Clientes */
    INSERT INTO @criterios_clientes
    SELECT o.id_orden,
        CASE dfc.es_persona_juridica WHEN 1 THEN dfc.id_persona_juridica ELSE dfc.id_persona_natural END,
        '002', '002'
    FROM @ordenes o
    INNER JOIN @datos_formateados_cliente dfc ON dfc.id_orden = o.id_orden
    WHERE dfc.cliente_existe = 0;

    /* Entidad Dinámica Tercero */
    INSERT INTO @entidad_dinamica_tercero
    SELECT o.id_orden,
        CASE dfc.es_persona_juridica WHEN 1 THEN dfc.id_persona_juridica ELSE dfc.id_persona_natural END,
        'ID PROCEDENCIA FE2.1', 'EUNOECO036', 'co036_id_procedencia_org', 'MUNOECO043', '10'
    FROM @ordenes o
    INNER JOIN @datos_formateados_cliente dfc ON dfc.id_orden = o.id_orden
    WHERE dfc.cliente_existe = 0;

    /* Entidad Dinámica Cliente */
    INSERT INTO @entidad_dinamica_cliente
    SELECT o.id_orden,
        CASE dfc.es_persona_juridica WHEN 1 THEN dfc.id_persona_juridica ELSE dfc.id_persona_natural END,
        dfc.email
    FROM @ordenes o
    INNER JOIN @datos_formateados_cliente dfc ON dfc.id_orden = o.id_orden
    WHERE dfc.cliente_existe = 0;

    /* =============================================
       SECCIÓN PUNTOS DE ENVÍO (Solo si cliente EXISTENTE)
       ============================================= */
    IF NOT EXISTS(
        SELECT 1 
        FROM @ordenes o
            INNER JOIN @datos_formateados_cliente dfc 
                ON dfc.id_orden = o.id_orden
            INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t200_mm_terceros] t200
                ON 
                    CASE CAST(CASE WHEN UPPER(dfc.es_persona_juridica) IN ('TRUE','1') THEN 1 ELSE 0 END AS BIT)
                        WHEN 0 
                            THEN REPLACE(REPLACE(dfc.id_persona_natural, '.', ''), ' ', '')
                        WHEN 1 
                            THEN REPLACE(REPLACE(dfc.id_persona_juridica, '.', ''), ' ', '')
                    END = t200.f200_id
            INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t215_mm_puntos_envio_cliente] AS t215
                ON
                    t215.f215_rowid_tercero = t200.f200_rowid
            INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t015_mm_contactos] AS t015
                ON
                    t015.f015_rowid = t215.f215_rowid_contacto
                    AND
                    t015.f015_direccion1 = dfc.direccion_1
                    AND
                    t015.f015_direccion2 = dfc.direccion_2
                    AND
                    t015.f015_id_depto = dfc.id_departamento
                    AND
                    t015.f015_id_ciudad = dfc.id_ciudad
        WHERE 
            dfc.cliente_existe = 1
    )
    BEGIN
        INSERT INTO @puntos_de_envio
        (
            id_orden,
            F215_ID,
            F215_ID_TERCERO,
            F215_DESCRIPCION,
            F015_CONTACTO,
            F015_DIRECCION1,
            F015_DIRECCION2,
            F015_ID_DEPTO,
            F015_ID_CIUDAD,
            F015_COD_POSTAL,
            F015_TELEFONO,
            F015_CELULAR,
            F015_EMAIL
        )
        SELECT DISTINCT
            o.id_orden,
            F215_ID         =   (
                SELECT TOP 1 
                    FORMAT(CAST(f215_id AS INT) + 1, '000')  
                FROM [UnoEE_PruebasProyectosCol].[dbo].[t215_mm_puntos_envio_cliente]
                    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t200_mm_terceros] t200
                        ON 
                            CASE CAST(CASE WHEN UPPER(dfc.es_persona_juridica) IN ('TRUE','1') THEN 1 ELSE 0 END AS BIT)
                                WHEN 0 
                                    THEN REPLACE(REPLACE(dfc.id_persona_natural, '.', ''), ' ', '')
                                WHEN 1 
                                    THEN REPLACE(REPLACE(dfc.id_persona_juridica, '.', ''), ' ', '')
                            END = t200.f200_id
                WHERE 
                    f215_rowid_tercero = t200.f200_rowid
                    AND
                    FORMAT(CAST(f215_id AS INT) + 1, '000') NOT IN (
                        SELECT f215_id FROM [UnoEE_PruebasProyectosCol].[dbo].[t215_mm_puntos_envio_cliente] 
                        WHERE f215_rowid_tercero = t200.f200_rowid
                    )
                ORDER BY f215_rowid DESC),
            F215_ID_TERCERO = CASE dfc.es_persona_juridica WHEN 1 THEN dfc.id_persona_juridica ELSE dfc.id_persona_natural END,
            F215_DESCRIPCION = dfc.nombre_completo,
            F015_CONTACTO = dfc.nombre_completo,
            F015_DIRECCION1 = dfc.direccion_1,
            F015_DIRECCION2 = dfc.direccion_2,
            F015_ID_DEPTO = dfc.id_departamento,
            F015_ID_CIUDAD = dfc.id_ciudad,
            F015_COD_POSTAL = LEFT(dfc.codigo_postal, 8),
            F015_TELEFONO = dfc.telefono,
            F015_CELULAR = dfc.telefono,
            F015_EMAIL = dfc.email
        FROM @ordenes o
            INNER JOIN @datos_formateados_cliente dfc 
                ON dfc.id_orden = o.id_orden
        WHERE 
            dfc.cliente_existe = 1  -- ← Solo clientes existentes
    END
    ELSE
    BEGIN
        UPDATE ord
        SET
            endpoint = null,
            id_estado = 2,
            orden_obj_destino = null,
            fecha_creacion = GETDATE()
        FROM Ordenes AS ord
            INNER JOIN
                (
                    SELECT DISTINCT o.id_orden
                    FROM @ordenes o
                        INNER JOIN @datos_formateados_cliente dfc 
                            ON dfc.id_orden = o.id_orden
                    WHERE 
                        dfc.cliente_existe = 1
                )   AS  o
                ON
                    ord.id_orden = o.id_orden
    END

    /* =============================================
       ACTUALIZACIÓN FINAL CON BIFURCACIÓN DE JSON
       ============================================= */
    UPDATE ord
    SET
        endpoint = dfc.endpoint,
        id_estado = 1,
        intentos = 0,
        fecha_creacion = GETDATE(),
        orden_obj_destino = JSON_QUERY(
            CASE 
                /* === CLIENTE NUEVO: Estructura completa === */
                WHEN dfc.cliente_existe = 0 THEN (
                    SELECT
                        [Terceros] = JSON_QUERY((
                            SELECT * FROM @terceros t WHERE t.id_orden = o.id_orden 
                            FOR JSON PATH, INCLUDE_NULL_VALUES)),
                        [Clientes] = JSON_QUERY((
                            SELECT * FROM @clientes c WHERE c.id_orden = o.id_orden 
                            FOR JSON PATH, INCLUDE_NULL_VALUES)),
                        [ImpuestosYRetenciones] = JSON_QUERY((
                            SELECT * FROM @impuestos_y_retenciones ip WHERE ip.id_orden = o.id_orden 
                            FOR JSON PATH, INCLUDE_NULL_VALUES)),
                        [CriteriosClientes] = JSON_QUERY((
                            SELECT * FROM @criterios_clientes cc WHERE cc.id_orden = o.id_orden 
                            FOR JSON PATH, INCLUDE_NULL_VALUES)),
                        [EntidadDinamicaTercero] = JSON_QUERY((
                            SELECT * FROM @entidad_dinamica_tercero edt WHERE edt.id_orden = o.id_orden 
                            FOR JSON PATH, INCLUDE_NULL_VALUES)),
                        [EntidadDinamicaCliente] = JSON_QUERY((
                            SELECT * FROM @entidad_dinamica_cliente edc WHERE edc.id_orden = o.id_orden 
                            FOR JSON PATH, INCLUDE_NULL_VALUES))
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
                )
                /* === CLIENTE EXISTENTE: Solo Punto de Envío === */
                ELSE (
                    SELECT
                        [Punto de envio] = JSON_QUERY((
                            SELECT * FROM @puntos_de_envio pe WHERE pe.id_orden = o.id_orden 
                            FOR JSON PATH, INCLUDE_NULL_VALUES))
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )
            END
        )
    FROM @ordenes o
        INNER JOIN ordenes ord WITH (ROWLOCK) 
            ON 
                ord.id_orden = o.id_orden
        INNER JOIN @datos_formateados_cliente dfc 
            ON 
                dfc.id_orden = o.id_orden
    WHERE
        dfc.endpoint = @endpoint_terceros
        OR
        EXISTS (
            SELECT 1 
            FROM @puntos_de_envio pe 
            WHERE 
                pe.id_orden = o.id_orden
        );

    /* =============================================
       LOG DE PROCESAMIENTO (Opcional para auditoría)
       ============================================= */
    PRINT CONCAT('Batch procesado: ', @@ROWCOUNT, ' órdenes actualizadas.');
    
    /* Si desea logging detallado, descomente:
    INSERT INTO log_procesamiento_vtex (id_orden, tipo_cliente, endpoint_destino, fecha_proceso)
    SELECT o.id_orden, 
           CASE dfc.cliente_existe WHEN 0 THEN 'NUEVO' ELSE 'EXISTENTE' END,
           dfc.endpoint,
           GETDATE()
    FROM @ordenes o
    INNER JOIN @datos_formateados_cliente dfc ON dfc.id_orden = o.id_orden;
    */

END TRY
BEGIN CATCH
    /* =============================================
       MANEJO DE ERRORES CON TRAZABILIDAD
       ============================================= */
    DECLARE @errorMsg     NVARCHAR(4000) = ERROR_MESSAGE(),
            @errorSev     INT            = ERROR_SEVERITY(),
            @errorState   INT            = ERROR_STATE(),
            @errorLine    INT            = ERROR_LINE(),
            @errorProc    NVARCHAR(200)  = ISNULL(ERROR_PROCEDURE(), N'Script inline'),
            @msgFinal     NVARCHAR(4000);

    SET @msgFinal = CONCAT(
        N'[TERCERO_CLIENTE_VTEX] Error línea ', CAST(@errorLine AS NVARCHAR), N' | ',
        N'Proc: ', @errorProc, N' | ',
        N'Msg: ', @errorMsg, N' | ',
        N'Time: ', CONVERT(NVARCHAR, GETDATE(), 121)
    );

    /* Rollback implícito por SET XACT_ABORT ON */
    RAISERROR(@msgFinal, @errorSev, @errorState);

    /* Opcional: Logging de errores en tabla dedicada
    INSERT INTO log_errores_vtex (id_orden, mensaje_error, fecha_error, linea_error)
    SELECT o.id_orden, @msgFinal, GETDATE(), @errorLine
    FROM @ordenes o;
    */

END CATCH;