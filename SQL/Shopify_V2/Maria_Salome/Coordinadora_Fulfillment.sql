/*
--------------------------------------------------------------------------------
Script Name: Pedido Integracion.sql (Optimizado)
Project: MARIA SALOME - CREACIÓN DE PEDIDOS
Purpose:
    Procesar e integrar pedidos de Shopify en Siesa ERP.
    Esta versión optimiza legibilidad, elimina código duplicado y mejora rendimiento.
--------------------------------------------------------------------------------
*/

BEGIN TRY
    /*
    *   PARÁMETROS
    */
    DECLARE @batch_size             INT             =   25;
    DECLARE @es_pago_contra_entrega VARCHAR(15)     =   'N';
    DECLARE @fecha_inicio           DATETIME        =   DATEADD(DAY, -5, GETDATE());
    DECLARE @cliente_predeterminado NVARCHAR(30)	=	'99999999';
    DECLARE @nombre_empaque         NVARCHAR(30)	=	'Caja';
    
    DECLARE @nit_remitente          VARCHAR(15) =   '811012875';
    DECLARE @nombre_remitente       VARCHAR(15) =   'Maria Salome';
    DECLARE @telefono_remitente     VARCHAR(15) =   '3178936894';
    DECLARE @codigo_tienda          VARCHAR(15) =   '0';
    DECLARE @codigo_vendedor        VARCHAR(15) =   '0';

    DECLARE
        @conexion   VARCHAR(200),
        @bd        VARCHAR(100)

    SELECT TOP 1 
        @conexion   =   cadena_conexion
        ,@bd        =   base_datos 
    FROM conexiones;

    DECLARE @locaciones_coordinadora_fulfillment TABLE (
        id_pais             VARCHAR(255),
        nombre_pais         VARCHAR(255),
        id_departamento     VARCHAR(255),
        nombre_departamento VARCHAR(255),
        id_ciudad           VARCHAR(255),
        nombre_ciudad       VARCHAR(255)
    );

    INSERT INTO @locaciones_coordinadora_fulfillment
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
        f013_indicativo = 'COORDINADORA FULL';

    DECLARE @productos_erp TABLE (
        f120_referencia             VARCHAR(50),
        f121_id_barras_principal    VARCHAR(20),
        f131_id                     VARCHAR(20)
    );

    INSERT INTO @productos_erp
    EXEC('
        SELECT
            f120_referencia,
            f121_id_barras_principal,
            f131_id
        FROM OPENROWSET(
            ''SQLNCLI'', 
            '''+@conexion+''',
            ''
                SELECT
                    f120_referencia             =   TRIM(f120_referencia),
                    f121_id_barras_principal    =   TRIM(MAX(f121_id_barras_principal)),
                    f131_id                     =   TRIM(MAX(f131_id))
                FROM ' + @bd + '.dbo.t120_mc_items
                    INNER JOIN ' + @bd + '.dbo.t121_mc_items_extensiones 
                        ON 
                            f121_rowid_item = f120_rowid
                    INNER JOIN ' + @bd + '.dbo.t131_mc_items_barras
                        ON 
                            f131_rowid_item_ext = f121_rowid
                            GROUP BY f120_referencia
            ''
        )
    ');

    /*
    *   CTE: ORDENES FILTRADAS
    *       Solo órdenes válidas y recientes
    */
    WITH OrdenesFiltradas AS (
        SELECT 
            o.id_orden,
            o.orden_obj,
            o.fecha_creacion,
            id_tercero_comprador            =
                CASE
                    WHEN
                        EXISTS
                        (
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
                                    NA.Nombre   =   'documento'
                            )
                        )
                        THEN
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
                                    NA.Nombre   =   'documento'
                            )
                    WHEN
                        NULLIF(
                            TRIM(
                                JSON_VALUE(
                                    o.orden_obj
                                    , '$.billing_address.company'
                                )
                            ), 
                            ''
                        ) IS NOT NULL
                        AND
                        REPLACE(
                            dbo.fn_KeepNumbersHyphen(
                                JSON_VALUE(
                                    o.orden_obj
                                    , '$.billing_address.company'
                                )
                            )
                            , '-'
                            , ''
                        ) IS NOT NULL 
                        THEN
                            dbo.fn_KeepNumbersHyphen(
                                JSON_VALUE(o.orden_obj, '$.billing_address.company')
                            )
                    WHEN
                        NULLIF(
                            TRIM(
                                JSON_VALUE(
                                    o.orden_obj
                                    , '$.customer.default_address.company'
                                )
                            ), 
                            ''
                        ) IS NOT NULL
                        AND
                        REPLACE(
                            dbo.fn_KeepNumbersHyphen(
                                JSON_VALUE(
                                    o.orden_obj
                                    , '$.customer.default_address.company'
                                )
                            )
                            , '-'
                            , ''
                        ) IS NOT NULL 
                        THEN
                            dbo.fn_KeepNumbersHyphen(
                                JSON_VALUE(o.orden_obj, '$.customer.default_address.company')
                            )
                    ELSE @cliente_predeterminado
                END,
            id_tercero_destinatario         =   JSON_VALUE(o.orden_obj, '$.shipping_address.company'),
            nombre_tercero_formulario       =
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
            nombre_tercero_comprador        =
                UPPER(
					dbo.fn_RemoveAccentMarks(
                        CASE
                            WHEN
                                EXISTS
                                (
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
                                )
                                THEN
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
                                    )
                            ELSE
                                ISNULL(
                                    NULLIF(
                                        JSON_VALUE(o.orden_obj, '$.billing_address.first_name')
                                        , ''
                                    )
                                    ,NULLIF(
                                        JSON_VALUE(o.orden_obj, '$.customer.default_address.first_name')
                                        , ''
                                    )
                                )
                        END
					)
				),
            nombre_tercero_destinatario     =   UPPER(JSON_VALUE(o.orden_obj, '$.shipping_address.first_name')),
            apellido_tercero_comprador      =
                UPPER(
					dbo.fn_RemoveAccentMarks(
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
                                        NA.Nombre   =   'apellidos'
                                )
                                THEN
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
                            ELSE
                                ISNULL(
                                    NULLIF(
                                        JSON_VALUE(o.orden_obj, '$.billing_address.last_name')
                                        , ''
                                    )
                                    ,NULLIF(
                                        JSON_VALUE(o.orden_obj, '$.customer.default_address.last_name')
                                        , ''
                                    )
                                )
                        END
					)
				),
            apellido_tercero_destinatario   =   UPPER(JSON_VALUE(o.orden_obj, '$.shipping_address.last_name')),
            direccion_tercero_formulario    =
                UPPER(
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
                ),
            direccion_tercero_comprador     = 
                UPPER(
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
                                    NA.Nombre   =   'direccion_residencia'
                            )
                            OR
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
                                    NA.Nombre   =   'direccion_residencia_2'
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
                        ELSE
                            ISNULL(
                                NULLIF(
                                    CONCAT(
                                        JSON_VALUE(o.orden_obj, '$.billing_address.address1'), ' ',
                                        JSON_VALUE(o.orden_obj, '$.billing_address.address2'), ' ',
                                        JSON_VALUE(o.orden_obj, '$.billing_address.address3')
                                    ),
                                    ''
                                ),
                                CONCAT(
                                    JSON_VALUE(o.orden_obj, '$.customer.default_address.address1'), ' ',
                                    JSON_VALUE(o.orden_obj, '$.customer.default_address.address2'), ' ',
                                    JSON_VALUE(o.orden_obj, '$.customer.default_address.address3')
                                )
                            )
                    END
                ),
            direccion_tercero_destinatario  =
                UPPER(
                    CONCAT(
                        JSON_VALUE(o.orden_obj, '$.shipping_address.address1'), ' ',
                        JSON_VALUE(o.orden_obj, '$.shipping_address.address2'), ' ',
                        JSON_VALUE(o.orden_obj, '$.shipping_address.address3')
                    )
                ),
            telefono_tercero_formulario     =
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
                ),
            telefono_tercero_comprador      =
                REPLACE(
                    CASE
                        WHEN
                            EXISTS(
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
                            )
                            THEN
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
                                )
                        ELSE
                            ISNULL(
                                NULLIF(
                                    JSON_VALUE(o.orden_obj, '$.billing_address.phone')
                                    , ''
                                ),
                                JSON_VALUE(o.orden_obj, '$.customer.default_address.phone')
                            )
                    END
				    ,'+57'
				    ,''
			    ),
            telefono_tercero_destinatario   =   REPLACE(JSON_VALUE(o.orden_obj, '$.shipping_address.phone'), '+57', ''),
            ciudad_formulario               =
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
                        NA.Nombre   =   'ciudad'
                ),
            ciudad_comprador                =
                ISNULL(
                    NULLIF(
                        JSON_VALUE(o.orden_obj, '$.billing_address.city'), 
                        ''
                    ),
                    JSON_VALUE(o.orden_obj, '$.customer.default_address.city')
                ),
            ciudad_destinatario             =   JSON_VALUE(o.orden_obj, '$.shipping_address.city'),
            departament_comprador           =
                ISNULL(
                    NULLIF(
                        JSON_VALUE(o.orden_obj, '$.billing_address.province'), 
                        ''
                    ),
                    JSON_VALUE(o.orden_obj, '$.customer.default_address.province')
                ),
            departament_destinatario        =   JSON_VALUE(o.orden_obj, '$.shipping_address.province'),
            pais_comprador                  =
                ISNULL(
                    NULLIF(
                        JSON_VALUE(o.orden_obj, '$.billing_address.country'), 
                        ''
                    ),
                    JSON_VALUE(o.orden_obj, '$.customer.default_address.country')
                ),
            pais_destinatario               =   JSON_VALUE(o.orden_obj, '$.shipping_address.country'),
            total_con_iva                   =   CAST(JSON_VALUE(o.orden_obj, '$.total_price') AS DECIMAL(18,2)),
            total_iva                       =   CAST(JSON_VALUE(o.orden_obj, '$.total_tax') AS DECIMAL(18,2))    
        FROM ordenes o
            INNER JOIN @locaciones_coordinadora_fulfillment ON
                LEFT(
                    dbo.fn_RemoveAccentMarks(JSON_VALUE(o.orden_obj, '$.shipping_address.city')), 
                    CHARINDEX(',', dbo.fn_RemoveAccentMarks(JSON_VALUE(o.orden_obj, '$.shipping_address.city')) + ',') - 1
                ) LIKE '%' + nombre_ciudad + '%'
        WHERE
            o.id_estado =   3
            AND
            o.intentos  <=  3
            AND
            o.fecha_creacion    >   @fecha_inicio
    ),

    /*
    *   CTC: CIUDAD TERCERO COMPRADOR
    *       Calcula nombre y código de ciudad (sin duplicar lógica)
    */
    CiudadTerceroComprador AS (
        SELECT 
            o.id_orden,
            codigo_ciudad_tercero   =   
                CASE 
                    WHEN ciudad_formulario IS NOT NULL 
                        THEN ciudad_formulario 
                    ELSE CONCAT(lcf.id_departamento,lcf.id_ciudad,'000') 
                END
        FROM OrdenesFiltradas o
            LEFT JOIN @locaciones_coordinadora_fulfillment lcf
                ON
                    lcf.nombre_pais   =   dbo.fn_RemoveAccentMarks(LOWER(o.pais_comprador))
        WHERE
            lcf.nombre_pais = dbo.fn_RemoveAccentMarks(LOWER(o.pais_comprador))
            AND
            (
                ciudad_formulario   IS NOT NULL
                OR
                (
                    --> Caso 1: Bogotá D.C. (ciudad y departamento son Bogotá)
                    (
                        (
                            '%' + dbo.fn_RemoveAccentMarks(LOWER(o.departament_comprador)) + '%' LIKE '%cundinamarca%' 
                            OR
                            '%' + dbo.fn_RemoveAccentMarks(LOWER(o.departament_comprador)) + '%' LIKE '%bogota%' 
                        )
                        AND 
                        dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_comprador)) LIKE    '%bogota%'
                        AND
                        nombre_ciudad   LIKE    '%bogota%'
                        AND
                        nombre_ciudad   LIKE    '%bogota%'
                    )
                    OR 
                    --> Caso 2: Provincia es Bogotá pero ciudad NO es Bogotá
                    (
                        (
                            '%' + dbo.fn_RemoveAccentMarks(LOWER(o.departament_comprador)) + '%' LIKE '%cundinamarca%' 
                            OR
                            '%' + dbo.fn_RemoveAccentMarks(LOWER(o.departament_comprador)) + '%' LIKE '%bogota%' 
                        )
                        AND 
                        dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_comprador)) NOT LIKE 'bogota'
                        AND
                        lcf.nombre_departamento LIKE    '%cundinamarca%'
                        AND
                        lcf.nombre_ciudad   =   dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_comprador))
                    )
                    OR
                    --> Caso 3: Caso general (otros departamentos)
                    (
                        lcf.nombre_departamento =   dbo.fn_RemoveAccentMarks(LOWER(o.departament_comprador))
                        AND 
                        (
                            dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_comprador)) =   lcf.nombre_ciudad
                            OR 
                            (
                                NOT EXISTS (
                                    SELECT 1 FROM @locaciones_coordinadora_fulfillment lcf2
                                    WHERE 
                                        lcf2.nombre_pais    =   dbo.fn_RemoveAccentMarks(LOWER(o.pais_comprador))
                                        AND
                                        lcf2.nombre_departamento    =   dbo.fn_RemoveAccentMarks(LOWER(o.departament_comprador))
                                        AND
                                        dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_comprador))    =   lcf2.nombre_ciudad
                                )
                                AND
                                dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_comprador))    LIKE    '%' + lcf.nombre_ciudad + '%'
                            )
                        )
                    )
                )
            )
    ),

    /*
    *   CTD: CIUDAD TERCERO DESTINATARIO
    *       Calcula nombre y código de ciudad (sin duplicar lógica)
    */
    CiudadTerceroDestinatario AS (
        SELECT 
            o.id_orden,
            loc.f013_descripcion                    AS  nombre_ciudad_tercero,
            loc.f013_id_depto + loc.f013_id + '000' AS  codigo_ciudad_tercero
        FROM OrdenesFiltradas o
        JOIN locaciones_erp loc
            ON dbo.fn_RemoveAccentMarks(LOWER(loc.f011_descripcion)) 
               = dbo.fn_RemoveAccentMarks(LOWER(o.pais_destinatario))
        WHERE
            dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(o.pais_destinatario))
            AND
            (
                --> Caso 1: Bogotá D.C. (ciudad y departamento son Bogotá)
                (
                    (
                        '%' + dbo.fn_RemoveAccentMarks(LOWER(o.departament_destinatario)) + '%' LIKE '%cundinamarca%' 
                        OR
                        '%' + dbo.fn_RemoveAccentMarks(LOWER(o.departament_destinatario)) + '%' LIKE '%bogota%' 
                    )
                    AND 
                    dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_destinatario)) LIKE    '%bogota%'
                    AND
                    dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion))   LIKE    '%bogota%'
                    AND
                    dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion))   LIKE    '%bogota%'
                )
                OR 
                --> Caso 2: Provincia es Bogotá pero ciudad NO es Bogotá
                (
                    (
                        '%' + dbo.fn_RemoveAccentMarks(LOWER(o.departament_destinatario)) + '%' LIKE '%cundinamarca%' 
                        OR
                        '%' + dbo.fn_RemoveAccentMarks(LOWER(o.departament_destinatario)) + '%' LIKE '%bogota%' 
                    )
                    AND 
                    dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_destinatario)) NOT LIKE 'bogota'
                    AND
                    dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) LIKE    '%cundinamarca%'
                    AND
                    dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_destinatario))
                )
                OR
                --> Caso 3: Caso general (otros departamentos)
                (
                    dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(o.departament_destinatario))
                    AND 
                    (
                        dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_destinatario)) = dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion))
                        OR 
                        (
                            NOT EXISTS (
                                SELECT 1 FROM locaciones_erp l2
                                WHERE 
                                    dbo.fn_RemoveAccentMarks(LOWER(l2.f011_descripcion))    =   dbo.fn_RemoveAccentMarks(LOWER(o.pais_destinatario))
                                    AND
                                    dbo.fn_RemoveAccentMarks(LOWER(l2.f012_descripcion))    =   dbo.fn_RemoveAccentMarks(LOWER(o.departament_destinatario))
                                    AND
                                    dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_destinatario))    =   dbo.fn_RemoveAccentMarks(LOWER(l2.f013_descripcion))
                            )
                            AND
                            dbo.fn_RemoveAccentMarks(LOWER(o.ciudad_destinatario))    LIKE    '%' + dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) + '%'
                        )
                    )
                )
            )
    ),

    /*
    *   CTE: PRODUCTOS ORDEN
    *       Extrae productos en formato JSON
    */
    ProductosOrden AS (
        SELECT 
            o.id_orden,
            (
                SELECT 
                    id_producto         =   JSON_VALUE(li.value, '$.product_id'),
                    cantidad_producto   =   JSON_VALUE(li.value, '$.quantity'),
                    id_variante         =   JSON_VALUE(li.value, '$.variant_id')
                FROM OPENJSON(o.orden_obj, '$.line_items') li
                FOR JSON PATH
            ) AS productos_orden
        FROM OrdenesFiltradas o
    )

    /*
    *   SELECT FINAL
    */
    SELECT TOP (@batch_size)
        nit_remitente                   =   @nit_remitente,
        nombre_remitente                =   @nombre_remitente,
        telefono_remitente              =   @telefono_remitente,
        codigo_tienda                   =   @codigo_tienda,
        es_pago_contra_entrega          =   @es_pago_contra_entrega,
        identificacion_cliente          =   id_tercero_comprador,
        nombres_cliente                 =   nombre_tercero_comprador,
        apellidos_cliente               =   apellido_tercero_comprador,
        direccion_cliente               =   direccion_tercero_comprador,
        codigo_ciudad_cliente           =   c.codigo_ciudad_tercero,
        telefono_fijo_cliente           =   telefono_tercero_comprador,
        identificacion_destinatario     =   id_tercero_destinatario,
        nombres_destinatario            =   nombre_tercero_destinatario,
        apellidos_destinatario          =   apellido_tercero_destinatario,
        direccion_destinatario          =   direccion_tercero_destinatario,
        telefono_celular_destinatario   =   telefono_tercero_destinatario,
        telefono_fijo_destinatario      =   telefono_tercero_destinatario,
        nombre_ciudad_destinatario      =   d.nombre_ciudad_tercero,
        codigo_ciudad_destinatario      =   d.codigo_ciudad_tercero,
        codigo_pedido                   =   o.id_orden,
        numero_pedido                   =   o.id_orden,
        fechahora_pedido                =   REPLACE(o.fecha_creacion, '/', '-'),
        codigo_vendedor                 =   @codigo_vendedor,
        total_coniva                    =
            (
                SELECT
                    SUM(
                        pe.Precio
                    )
                FROM OPENJSON(p.productos_orden) AS po
                    LEFT JOIN ProductosCoordinadoraFulfillment AS pe 
                        ON 
                            pe.ProductID = JSON_VALUE(po.value, '$.id_producto')
            ),
        total_iva                       =   0,
        valor_declarado                 =
            (
                SELECT
                    SUM(
                        pe.ValorAsegurado
                    )
                FROM OPENJSON(p.productos_orden) AS po
                    LEFT JOIN ProductosCoordinadoraFulfillment AS pe 
                        ON 
                            pe.ProductID = JSON_VALUE(po.value, '$.id_producto')
            ),
        detalle                         =
            (
                SELECT 
                    ancho           =   ISNULL(pe.Ancho, 0),
                    alto            =   ISNULL(pe.Alto, 0),
                    largo           =   ISNULL(pe.Largo, 0),
                    peso            =   ISNULL(pe.Peso, 0),
                    unidades        =   JSON_VALUE(po.value, '$.cantidad_producto'),
                    nombre_empaque  =   @nombre_empaque,
                    referencia      =   ISNULL(f120_referencia, '')
                FROM OPENJSON(p.productos_orden) AS po
                    LEFT JOIN ProductosCoordinadoraFulfillment AS pe 
                        ON 
                            pe.ProductID = JSON_VALUE(po.value, '$.id_producto')
                    INNER JOIN variantes
                        ON
                            id_variante =   JSON_VALUE(po.value, '$.id_variante')
                    LEFT JOIN @productos_erp AS pr
                        ON 
                            pr.f121_id_barras_principal = sku_erp
                            OR
                            pr.f131_id = sku_erp
                FOR JSON PATH
            )   
    FROM OrdenesFiltradas   AS  o
        LEFT JOIN CiudadTerceroComprador    AS  c 
            ON o.id_orden = c.id_orden
        LEFT JOIN CiudadTerceroDestinatario AS  d 
            ON o.id_orden = d.id_orden
        JOIN ProductosOrden                 AS  p
            ON o.id_orden = p.id_orden;
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(4000);
    SELECT @ErrorMessage = ERROR_MESSAGE();
    RAISERROR(@ErrorMessage, 16, 1);
END CATCH;
