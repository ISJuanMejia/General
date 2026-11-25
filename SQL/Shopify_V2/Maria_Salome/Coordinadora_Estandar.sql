/*  MARÍA SALOMÉ    -   COORDINADORA
    ------------------------------------------------------------------------------
    DOCUMENTACIÓN DEL SCRIPT: Shopify_Coordinadora.sql
    ------------------------------------------------------------------------------
    Descripción:
        Este script SQL está diseñado para integrarse con el sistema de generación 
        de guías de Coordinadora desde una tienda Shopify. Permite obtener pedidos 
        listos para despacho, construir la información requerida y generar la 
        estructura XML necesaria para consumir el servicio web SOAP de Coordinadora.

    Secciones principales:
        1. Configuración de parámetros:
            - Define variables de conexión, parámetros de envío, remitente y destinatario.
            - Permite ajustar el tamaño de lote, fechas, valores declarados, tipos de cuenta, 
              producto, nivel de servicio, estado de la guía, usuario y clave de autenticación.

        2. Obtención de pedidos:
            - Consulta los pedidos facturados y listos para envío desde la base de datos 
              externa usando OPENROWSET.
            - Filtra los pedidos según estado, intentos y fecha de creación.

        3. Determinación de ciudad de destino:
            - Asocia cada pedido con el código de ciudad de destino requerido por Coordinadora, 
              utilizando funciones para normalizar y comparar nombres de ciudades y departamentos.

        4. Generación de XML para el servicio web:
            - Construye el XML SOAP requerido por el servicio de generación de guías de Coordinadora.
            - Incluye todos los datos del remitente, destinatario, detalles del envío y autenticación.
            - Utiliza CTEs y FOR XML PATH para estructurar correctamente el mensaje.

    Notas adicionales:
        - El script está preparado para producción, pero incluye comentarios para cambiar a sandbox.
        - Los parámetros y credenciales deben ser gestionados con seguridad.
        - Es importante validar los datos de entrada y salida para evitar errores en la integración.

    Autor: Juan Camilo Mejía
    Fecha de creación: 23/07/2025
    Última modificación: 28/08/2025
    ------------------------------------------------------------------------------
*/

/*  Configuración de parametros */

DECLARE @conexion VARCHAR(MAX);
DECLARE @base_datos VARCHAR(MAX);

SELECT
    @conexion = cadena_conexion
    ,@base_datos = base_datos
FROM conexiones

/*
    *   GENERAL
*/
DECLARE @batch_size         INT             =   25; --  *   ->  Cuantas guias se traen por petición
DECLARE @fecha              VARCHAR(10)     =   FORMAT(GETDATE(), 'yyyy-MM-dd')
DECLARE @valor_declarado    INT             =   100000;
DECLARE @fecha_inicio       DATETIME        =   DATEADD(DAY, -5, GETDATE());
DECLARE @usuario            VARCHAR(255)    =   'msalome.ws';
DECLARE @clave              VARCHAR(255)    =   'd036836b3c3a4165f8acf2b9f599fa051907950b99c2e1a2aebbf4ec8338e07c';
DECLARE @contenido          VARCHAR(255)    =   'COSMETICOS';
DECLARE @observaciones      VARCHAR(255)    =   '';

/*
    *   Declara una variable para especificar el tipo de código de cuenta para el envío:
    *       1   ->   Cuenta corriente
    *       2   ->   Acuerdo semanal
    *       3   ->   Flete pago
*/
DECLARE @codigo_cuenta  INT             =   1;
    
/*
    *   Declara una variable para especificar el tipo de código de producto para el envío:
    *       0   ->  Auto, se determina automaticamente a partir del detalle de la guia
    *       1   ->  Mercancia
    *       2   ->  Paquetes de 1-2 Kg
    *       3   ->  Documentos
    *       6   ->  Paquetes de 3-5 Kg
*/
DECLARE @codigo_producto    INT             =   2;

/*
    *   Declara una variable para especificar el tipo de nivel de servicio para el envío:
    *       1   ->  Estándar
    *       2   ->  Express
    *       3   ->  Programado
*/
DECLARE @nivel_servicio INT             =   1;

/*
    *   Declara una variable para especificar el estado para la generación de la guía:
    *       PENDIENTE   ->  Se registra la guia, no se genera el codigo remision ni se genera el PDF.
    *       IMPRESO     ->  Se registra la guia, se genera el codigo remision y el PDF.
*/
DECLARE @estado     VARCHAR(10)     =   'IMPRESO';

/*
    *   REMITENTE
*/
DECLARE @id_cliente             INT             =   33029;
DECLARE @id_remitente           INT             =   0;
DECLARE @nit_remitente          VARCHAR(10)     =   '811012875';
DECLARE @nombre_remitente       VARCHAR(255)    =   'Laboratorio María Salomé S.A.S.';
DECLARE @direccion_remitente    VARCHAR(255)    =   'Calle 14 Sur # 51C 17';
DECLARE @telefono_remitente     VARCHAR(15)     =   '3178936894';
DECLARE @ciudad_remitente       VARCHAR(255)    =   '05001000'; -- * Medellín (Antioquia)

/*
    *   DESTINATARIO
*/
DECLARE @div_destinatario   VARCHAR(255)    =   '00';

/*
    *   DETALLE GUÍA
*/
DECLARE @ubl        INT =   1;
DECLARE @alto       INT =   2;
DECLARE @ancho      INT =   50;
DECLARE @largo      INT =   50;
DECLARE @peso       INT =   2;
DECLARE @unidades   INT =   1;

DECLARE @locaciones_coordinadora_estandar TABLE (
    id_pais             VARCHAR(255),
    nombre_pais         VARCHAR(255),
    id_departamento     VARCHAR(255),
    nombre_departamento VARCHAR(255),
    id_ciudad           VARCHAR(255),
    nombre_ciudad       VARCHAR(255)
);

INSERT INTO @locaciones_coordinadora_estandar
SELECT
    f013_id_pais,
    dbo.fn_RemoveAccentMarks(f011_descripcion),
    f013_id_depto,
    dbo.fn_RemoveAccentMarks(f012_descripcion),
    f013_id,
    dbo.fn_RemoveAccentMarks(
        LEFT(
                f013_descripcion, 
                CHARINDEX(',', f013_descripcion + ',') - 1
        )
    )
FROM locaciones_erp
WHERE
    f013_indicativo != 'COORDINADORA FULL'
    AND
    f013_id_pais    =   169;

DECLARE @ciudades_ordenes TABLE (
    id_orden                VARCHAR(10)
    ,orden_obj              VARCHAR(MAX)
    ,ciudad_destinatario    VARCHAR(8)
);

INSERT INTO @ciudades_ordenes
SELECT TOP (@batch_size)
    id_orden,
    orden_obj,
    ciudad_destinatario = (
        CASE
            WHEN EXISTS (
                    SELECT 1
                    FROM
                    (
                        SELECT
                            Nombre = JSON_VALUE(value, '$.name'),
                            Valor  = JSON_VALUE(value, '$.value')
                        FROM OPENJSON(o.orden_obj, '$.note_attributes')
                    ) AS NA
                    WHERE
                        NA.Nombre   =   'ciudad'
                )
                THEN (SELECT valor
                    FROM
                    (
                        SELECT
                            Nombre = JSON_VALUE(value, '$.name'),
                            Valor  = JSON_VALUE(value, '$.value')
                        FROM OPENJSON(o.orden_obj, '$.note_attributes')
                    ) AS NA
                    WHERE
                        NA.Nombre   =   'ciudad')
            ELSE
                (
                    SELECT TOP 1 
                        id_departamento + id_ciudad + '000'
                    FROM @locaciones_coordinadora_estandar
                    WHERE
                        nombre_pais = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.country')))
                        AND 
                        (
                            -- Caso 1: Bogotá D.C. (ciudad y departamento son Bogotá)
                            (
                                (
                                    REPLACE(
                                        '%' + dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.province'))) + '%',
                                        ', d.c.', 
                                        ''
                                    ) LIKE '%cundinamarca%' 
                                    OR
                                    REPLACE(
                                        '%' + dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.province'))) + '%', 
                                        ', d.c.', 
                                        ''
                                    ) LIKE '%bogota%' 
                                )
                                AND 
                                REPLACE(
                                    dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.city'))),
                                    ', d.c.', 
                                    ''
                                )   LIKE    '%bogota%'
                                AND
                                nombre_departamento LIKE    '%bogota%'
                                AND
                                nombre_ciudad       LIKE    '%bogota%'
                            )
                            OR 
                            -- Caso 2: Provincia es Bogotá pero ciudad NO es Bogotá
                            (
                                (
                                    '%' + dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.province'))) + '%' LIKE '%cundinamarca%' 
                                    OR
                                    '%' + dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.province'))) + '%' LIKE '%bogota%' 
                                )
                                AND 
                                dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.city'))) NOT LIKE 'bogota'
                                AND
                                nombre_departamento LIKE    '%cundinamarca%'
                                AND
                                nombre_ciudad = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.city')))
                            )
                            OR 
                            -- Caso 3: Bolívar y Cartagena (caso especial)
                            (
                                dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.province')))  LIKE    '%bolivar%'
                                AND
                                (
                                    nombre_ciudad   LIKE    '%cartagena%'
                                    AND
                                    dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.city'))) LIKE '%cartagena%'
                                )
                            )
                            OR
                            -- Caso 4: Caso general (otros departamentos)
                            (
                                nombre_departamento = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.province')))
                                AND 
                                (
                                    dbo.fn_RemoveAccentMarks( LOWER( LTRIM(RTRIM( LEFT(JSON_VALUE(o.orden_obj, '$.shipping_address.city'),
                                    CHARINDEX('(', JSON_VALUE(o.orden_obj, '$.shipping_address.city') + '(') - 1))) )) = nombre_ciudad
                                    OR 
                                    (
                                        NOT EXISTS (
                                            SELECT 1 FROM @locaciones_coordinadora_estandar lce2
                                            WHERE 
                                                lce2.nombre_pais    =   dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.country')))
                                                AND
                                                lce2.nombre_departamento    =   dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.province')))
                                                AND
                                                dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.city')))    =   lce2.nombre_ciudad
                                        )
                                        AND
                                        --dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.city')))    LIKE    '%' + nombre_ciudad + '%'
                                        nombre_ciudad LIKE '%' +dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(o.orden_obj, '$.shipping_address.city')))+ '%'
                                    )
                                )
                            )
                        )
                )
        END
    )
FROM ordenes AS o
WHERE 
    o.id_estado =   3
    AND
    o.intentos  <   3
    AND
    o.fecha_creacion > @fecha_inicio;


WITH XMLNAMESPACES (
    'http://schemas.xmlsoap.org/soap/envelope/'                     AS  soapenv,
    'http://schemas.xmlsoap.org/soap/encoding/'                     AS  soapenc,
/*
    'https://sandbox.coordinadora.com/agw/ws/guias/1.6/server.php'  AS  ser,    --> URL de sandbox 
*/
    'https://guias.coordinadora.com/ws/guias/1.6/server.php'        AS  ser,    --> URL de producción
    'http://www.w3.org/2001/XMLSchema-instance'                     AS  xsi,
    'http://www.w3.org/2001/XMLSchema'                              AS  xsd
)
SELECT TOP (@batch_size)
    o.id_orden,
    (
        SELECT 
            '' AS [soapenv:Header],
            (
                SELECT
			    (
                    SELECT 
                        [@xsi:type]                 =   'ser:Agw_typeGenerarGuiaIn'
                        ,[codigo_remision]          =   ''
                        ,[fecha]                    =   @fecha
                        ,[id_cliente]               =   @id_cliente
                        ,[id_remitente]             =   0
                        ,[nit_remitente]            =   @nit_remitente
                        ,[nombre_remitente]         =   @nombre_remitente
                        ,[direccion_remitente]      =   @direccion_remitente
                        ,[telefono_remitente]       =   @telefono_remitente
                        ,[ciudad_remitente]         =   @ciudad_remitente
                        ,[nit_destinatario]         =   
                            CASE
                                WHEN EXISTS (
                                    SELECT 1
                                    FROM
                                    (
                                        SELECT
                                            Nombre = JSON_VALUE(value, '$.name'),
                                            Valor  = JSON_VALUE(value, '$.value')
                                        FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                    ) AS NA
                                    WHERE
                                        NA.Nombre   =   'documento'
                                )
                                THEN (
                                    SELECT valor
                                    FROM
                                    (
                                        SELECT
                                            Nombre = JSON_VALUE(value, '$.name'),
                                            Valor  = JSON_VALUE(value, '$.value')
                                        FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                    ) AS NA
                                    WHERE
                                        NA.Nombre   =   'documento'
                                )
                                ELSE    JSON_VALUE(o.orden_obj, '$.shipping_address.company')
                            END
                        ,[div_destinatario]         =   @div_destinatario
                        ,[nombre_destinatario]      =   
                            CASE
                                WHEN    
                                    EXISTS
                                    (
                                        SELECT 1
                                        FROM
                                        (
                                            SELECT
                                                Nombre = JSON_VALUE(value, '$.name'),
                                                Valor  = JSON_VALUE(value, '$.value')
                                            FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                        ) AS NA
                                        WHERE
                                            NA.Nombre   =   'nombres'
                                    )
                                    AND
                                    EXISTS(
                                        SELECT 1
                                        FROM
                                        (
                                            SELECT
                                                Nombre = JSON_VALUE(value, '$.name'),
                                                Valor  = JSON_VALUE(value, '$.value')
                                            FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                        ) AS NA
                                        WHERE
                                            NA.Nombre   =   'apellidos'
                                    )
                                    THEN    
                                        CONCAT(
                                            (
                                                SELECT valor
                                                FROM
                                                (
                                                    SELECT
                                                        Nombre = JSON_VALUE(value, '$.name'),
                                                        Valor  = JSON_VALUE(value, '$.value')
                                                    FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                                ) AS NA
                                                WHERE
                                                    NA.Nombre   =   'nombres'
                                            ), 
                                            ' ',
                                            (
                                                SELECT valor
                                                FROM
                                                (
                                                    SELECT
                                                        Nombre = JSON_VALUE(value, '$.name'),
                                                        Valor  = JSON_VALUE(value, '$.value')
                                                    FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                                ) AS NA
                                                WHERE
                                                    NA.Nombre   =   'apellidos'
                                            )
                                        )
                                ELSE    JSON_VALUE(o.orden_obj, '$.shipping_address.name')
                            END
                        ,[direccion_destinatario]   =
                            CASE
                                WHEN
                                    EXISTS(
                                        SELECT 1
                                        FROM
                                        (
                                            SELECT
                                                Nombre = JSON_VALUE(value, '$.name'),
                                                Valor  = JSON_VALUE(value, '$.value')
                                            FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                        ) AS NA
                                        WHERE
                                            NA.Nombre   =   'direccion_residencia'
                                    )
                                    OR
                                    EXISTS(
                                        SELECT 1
                                        FROM
                                        (
                                            SELECT
                                                Nombre = JSON_VALUE(value, '$.name'),
                                                Valor  = JSON_VALUE(value, '$.value')
                                            FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                        ) AS NA
                                        WHERE
                                            NA.Nombre   =   'direccion_residencia_2'
                                    )
                                    THEN
                                        TRIM(
                                            CONCAT(
                                                (
                                                    SELECT valor
                                                    FROM
                                                    (
                                                        SELECT
                                                            Nombre = JSON_VALUE(value, '$.name'),
                                                            Valor  = JSON_VALUE(value, '$.value')
                                                        FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                                    ) AS NA
                                                    WHERE
                                                        NA.Nombre   =   'direccion_residencia'
                                                ),
                                                ' ',
                                                (
                                                    SELECT valor
                                                    FROM
                                                    (
                                                        SELECT
                                                            Nombre = JSON_VALUE(value, '$.name'),
                                                            Valor  = JSON_VALUE(value, '$.value')
                                                        FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                                    ) AS NA
                                                    WHERE
                                                        NA.Nombre   =   'direccion_residencia_2'
                                                )
                                            )
                                        )
                                ELSE
                                    CONCAT(
                                        JSON_VALUE(o.orden_obj, '$.shipping_address.address1')
                                        ,' '
                                        ,JSON_VALUE(o.orden_obj, '$.shipping_address.address2')
                                    )
                            END
                        ,[ciudad_destinatario]      =   ISNULL(o.ciudad_destinatario, '00000000')
                        ,[telefono_destinatario]    =   
                            CASE
                                WHEN
                                    EXISTS
                                        (
                                            SELECT 1
                                            FROM
                                            (
                                                SELECT
                                                    Nombre = JSON_VALUE(value, '$.name'),
                                                    Valor  = JSON_VALUE(value, '$.value')
                                                FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                            ) AS NA
                                            WHERE
                                                NA.Nombre   =   'telefono'
                                        )
                                    THEN
                                        REPLACE(
                                            (
                                                SELECT valor
                                                FROM
                                                (
                                                    SELECT
                                                        Nombre = JSON_VALUE(value, '$.name'),
                                                        Valor  = JSON_VALUE(value, '$.value')
                                                    FROM OPENJSON(o.orden_obj, '$.note_attributes')
                                                ) AS NA
                                                WHERE
                                                    NA.Nombre   =   'telefono'
                                            ),
                                            '+57',
                                            ''
                                        )
                                ELSE
                                    REPLACE(
                                        JSON_VALUE(o.orden_obj, '$.shipping_address.phone')
                                        ,'+57'
                                        ,''
                                    )
                            END
                        ,[valor_declarado]          =   @valor_declarado
                        ,[codigo_cuenta]            =   @codigo_cuenta
                        ,[codigo_producto]          =   @codigo_producto
                        ,[nivel_servicio]           =   @nivel_servicio
                        ,[linea]                    =   ''
                        ,[contenido]                =   @contenido
                        ,[referencia]               =   CONCAT('Pedido ', JSON_VALUE(o.orden_obj, '$.name'))
                        ,[observaciones]            =   @observaciones 
                        ,[estado]                   =   @estado
                        ,[detalle]                  =   
                            (
                                SELECT 
                                    (
                                        SELECT 
                                            [ubl]       =   @ubl
                                            ,[alto]     =   @alto
                                            ,[ancho]    =   @ancho
                                            ,[largo]    =   @largo
                                            ,[peso]     =   @peso
                                            ,[unidades] =   @unidades
                                        FOR XML PATH('item')
                                        , TYPE
                                    )
                            )
                        ,[cuenta_contable]          =   ''
                        ,[centro_costos]            =   ''
                        ,
                            (
                                SELECT
                                    [@xsi:type]             =   'soapenc:Array'
                                    ,[@soapenc:arrayType]   =   'ser:Agw_typeGuiaDetalleRecaudo[]'
                                FOR XML PATH('recaudos')
                                ,TYPE
                            )
                        ,[margen_izquierdo]         =   ''
                        ,[margen_superior]          =   ''
                        ,[id_rotulo]                =   ''
                        ,[usuario_vmi]              =   ''
                        ,[formato_impresion]        =   ''
                        ,[atributo1_nombre]         =   ''
                        ,atributo1_valor            =   ''
                        ,
                            (
                                SELECT
                                    [@xsi:type] =   'ns1:ArrayOfAgw_typeNotificaciones'
                                FOR XML PATH('notificaciones')
                                ,TYPE
                            )
                        ,
                            (
                                SELECT
                                    [@xsi:type] =   'ns1:Agw_typeAtributosRetorno'
                                FOR XML PATH('atributos_retorno')
                                ,TYPE
                            )
                        ,[nro_doc_radicados]        =   ''
                        ,[nro_sobre]                =   ''
                        ,[usuario]                  =   @usuario
                        ,[clave]                    =   @clave
                    FOR XML PATH('p')
                    ,TYPE
                )
            FOR XML PATH('ser:Guias_generarGuia')
            ,TYPE
        ) AS [soapenv:Body]
    FOR XML PATH('soapenv:Envelope')
    ,TYPE
) AS xml
FROM @ciudades_ordenes   AS  o
WHERE
    o.ciudad_destinatario IS NOT NULL