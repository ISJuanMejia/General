/*
    *   Información Conector
*/
DECLARE @idDocumento            INT         = 228556;
DECLARE @descripcionConector    VARCHAR(50) = 'TERCERO_CLIENTES _INTEGRACION _NUEVO';
DECLARE @indicaParalelismo      BIT         = 1;

/*
    *   Variables
*/
DECLARE @id_tipo_ident      VARCHAR(2)  =   'C'
DECLARE @ind_tipo_tercero   VARCHAR(2)  =   '1'
DECLARE @id_sucursal        VARCHAR(3)  =   '001';

DECLARE @ordenes    TABLE   (
    order_name          VARCHAR(200),
    customer_email      VARCHAR(200),
    customer_created    VARCHAR(200),
    company             VARCHAR(200),
    full_name           VARCHAR(200),
    address1_raw        VARCHAR(200),
    address2_raw        VARCHAR(200),
    phone               VARCHAR(200),
    country             VARCHAR(200),
    province            VARCHAR(200),
    city                VARCHAR(200),
    last_name           VARCHAR(200),
    first_name          VARCHAR(200)
)

INSERT INTO @ordenes
SELECT TOP 20
    order_name          =   JSON_VALUE(o.orden_obj, '$.name'),
    customer_email      =   JSON_VALUE(o.orden_obj, '$.customer.email'),
    customer_created    =   JSON_VALUE(o.orden_obj, '$.customer.created_at'),
    company             =   
        ISNULL(
            JSON_VALUE(o.orden_obj, '$.billing_address.company'),
            JSON_VALUE(o.orden_obj, '$.customer.default_address.company')
        ),
    full_name           =
        UPPER(
            ISNULL(
                JSON_VALUE(o.orden_obj, '$.billing_address.name'), 
                JSON_VALUE(o.orden_obj, '$.customer.default_address.name')
            )
        ),
    address1_raw        =
        UPPER(
            JSON_VALUE(o.orden_obj, '$.customer.default_address.address1')
        ),
    address2_raw        =
        UPPER(
            JSON_VALUE(o.orden_obj, '$.customer.default_address.address2')
        ),
    phone               =
        REPLACE(
            JSON_VALUE(o.orden_obj, '$.customer.default_address.phone'), 
            '+57', 
            ''
        ),
    country             =   JSON_VALUE(o.orden_obj, '$.customer.default_address.country'),
    province            =   JSON_VALUE(o.orden_obj, '$.customer.default_address.province'),
    city                =   JSON_VALUE(o.orden_obj, '$.customer.default_address.city'),
    last_name           =   UPPER(JSON_VALUE(o.orden_obj, '$.customer.default_address.last_name')),
    first_name          =   UPPER(JSON_VALUE(o.orden_obj, '$.customer.default_address.first_name'))
FROM ordenes    AS  o
WHERE
    id_estado   =   1
    AND
    intentos    <=  3;

UPDATE o
SET 
    o.id_estado =   2,
    o.intentos  =   0
FROM ordenes    AS  o
    INNER JOIN @ordenes ord
        ON
            ord.order_name = o.id_orden
WHERE
    ord.company IS NULL;

;WITH OrderData AS (
    SELECT TOP 20
        o.id_orden,
        o.orden_obj,
        order_name          =   JSON_VALUE(o.orden_obj, '$.name'),
        customer_email      =   JSON_VALUE(o.orden_obj, '$.customer.email'),
        customer_created    =   JSON_VALUE(o.orden_obj, '$.customer.created_at'),
        company             =   
            ISNULL(
                JSON_VALUE(o.orden_obj, '$.billing_address.company'),
                JSON_VALUE(o.orden_obj, '$.customer.default_address.company')
            ),
        full_name           =
            UPPER(
                ISNULL(
                    JSON_VALUE(o.orden_obj, '$.billing_address.name'), 
                    JSON_VALUE(o.orden_obj, '$.customer.default_address.name')
                )
            ),
        address1_raw        =
            UPPER(
                JSON_VALUE(o.orden_obj, '$.customer.default_address.address1')
            ),
        address2_raw        =
            UPPER(
                JSON_VALUE(o.orden_obj, '$.customer.default_address.address2')
            ),
        phone               =
            REPLACE(
                JSON_VALUE(o.orden_obj, '$.customer.default_address.phone'), 
                '+57', 
                ''
            ),
        country             =   JSON_VALUE(o.orden_obj, '$.customer.default_address.country'),
        province            =   JSON_VALUE(o.orden_obj, '$.customer.default_address.province'),
        city                =   JSON_VALUE(o.orden_obj, '$.customer.default_address.city'),
        last_name           =   UPPER(JSON_VALUE(o.orden_obj, '$.customer.default_address.last_name')),
        first_name          =   UPPER(JSON_VALUE(o.orden_obj, '$.customer.default_address.first_name'))
    FROM ordenes o
    WHERE
        o.id_estado = 1
),
AddressSplit AS (
    SELECT 
        od.*,
        direccion1 =
            CAST(
                LEFT(
                    ISNULL(od.address1_raw, ''), 
                    39
                ) AS VARCHAR(39)
            ),
        direccion2 = 
            CAST(
                CASE 
                    WHEN LEN(ISNULL(od.address1_raw, '')) > 39 
                        THEN LEFT(SUBSTRING(od.address1_raw, 40, 39), 39)
                    ELSE LEFT(ISNULL(od.address2_raw, ''), 39)
                END
                AS VARCHAR(39)
            )
    FROM OrderData od
),
LocationMapping AS (
    SELECT 
        a.*,
        pais_siesa      =   ISNULL(le.f013_id_pais,     '169'),
        dpto_siesa      =   ISNULL(le.f013_id_depto,    '05'),
        ciudad_siesa    =   ISNULL(le.f013_id,          '001')
    FROM AddressSplit a
    OUTER APPLY (
        SELECT TOP 1 
            f013_id_pais,
            f013_id_depto,
            f013_id
        FROM locaciones_erp le
        WHERE
            dbo.fn_RemoveAccentMarks(LOWER(le.f011_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(a.country))
            AND 
            dbo.fn_RemoveAccentMarks(LOWER(le.f012_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(a.province))
            AND 
            dbo.fn_RemoveAccentMarks(LOWER(le.f013_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(a.city))
    ) le
),
JSONOutput AS (
    SELECT
        idDocumento         =   @idDocumento,
        descripcion         =   @descripcionConector,
        indicaParalelismo   =   @indicaParalelismo,
        idOrden             =   lm.order_name,
        [json]              =
        (
            SELECT
                [Terceros] = JSON_QUERY((
                    SELECT
                        F200_ID                 =   lm.company,
                        F200_NIT                =   lm.company,
                        F200_ID_TIPO_IDENT      =   @id_tipo_ident,
                        F200_IND_TIPO_TERCERO   =   @ind_tipo_tercero,
                        F200_RAZON_SOCIAL       =   lm.full_name,
                        F200_APELLIDO1          =   LEFT(lm.last_name, CHARINDEX(' ', lm.last_name + ' ') - 1),
                        F200_APELLIDO2          =   LTRIM(SUBSTRING(lm.last_name, 
                                                      CHARINDEX(' ', lm.last_name + ' '), 
                                                      LEN(lm.last_name))),
                        F200_NOMBRES            =   lm.first_name,
                        F015_CONTACTO           =   lm.full_name,
                        F015_DIRECCION1         =   lm.direccion1,
                        F015_DIRECCION2         =   COALESCE(lm.direccion2, ''),
                        F015_ID_PAIS            =   lm.pais_siesa,
                        F015_ID_DEPTO           =   lm.dpto_siesa,
                        F015_ID_CIUDAD          =   lm.ciudad_siesa,
                        F015_TELEFONO           =   lm.phone,
                        F015_EMAIL              =   lm.customer_email,
                        F200_FECHA_NACIMIENTO   =   REPLACE(CONVERT(VARCHAR(10), CAST(lm.customer_created AS DATE)), '-', ''),
                        F015_CELULAR            =   lm.phone
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )),
                [Clientes] = JSON_QUERY((
                    SELECT
                        F201_ID_TERCERO             =   lm.company,
                        F201_ID_SUCURSAL            =   @id_sucursal,
                        F201_DESCRIPCION_SUCURSAL   =   lm.full_name,
                        F201_ID_MONEDA              =   'COP',
                        F201_ID_VENDEDOR            =   '01',
                        F201_IND_CALIFICACION       =   'A',
                        F201_ID_COND_PAGO           =   'CON',
                        F201_ID_TIPO_CLI            =   '0001',
                        F201_ID_LISTA_PRECIO        =   '001',
                        F015_CONTACTO               =   lm.full_name,
                        F015_DIRECCION1             =   lm.direccion1,
                        F015_DIRECCION2             =   COALESCE(lm.direccion2, ''),
                        F015_ID_PAIS                =   lm.pais_siesa,
                        F015_ID_DEPTO               =   lm.dpto_siesa,
                        F015_ID_CIUDAD              =   lm.ciudad_siesa,
                        F015_TELEFONO               =   lm.phone,
                        F015_EMAIL                  =   lm.customer_email,
                        F201_FECHA_INGRESO          =   REPLACE(CONVERT(VARCHAR(10), CAST(lm.customer_created AS DATE)), '-', ''),
                        f015_celular                =   lm.phone
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )),
                [ImptosyReten] = JSON_QUERY((
                    SELECT
                        F_TIPO_REG          =   '46',
                        F_ID_TERCERO        =   lm.company,
                        F_ID_SUCURSAL       =   @id_sucursal,
                        F_ID_CLASE          =   '1',
                        F_ID_VALOR_TERCERO  =   '1'
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                ))
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        )
    FROM LocationMapping lm
)
SELECT 
    idDocumento,
    indicaParalelismo,
    descripcion,
    idOrden,
    json
FROM JSONOutput
ORDER BY idOrden;