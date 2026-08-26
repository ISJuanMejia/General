DECLARE @endpoint NVARCHAR(500) = 'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?idCompania=7243&idSistema=2&idDocumento=214359&nombreDocumento=TERCEROS_CLIENTES_INT'

DECLARE @ordenes_seleccionadas TABLE
(
    id_orden            NVARCHAR(100),
    id_tercero          NVARCHAR(100),
    id_empresa          NVARCHAR(100),
    tipo_documento      NVARCHAR(100),
    nombre_cliente      NVARCHAR(100),
    apellido_cliente    NVARCHAR(100), 
    calle               NVARCHAR(100),
    complemento         NVARCHAR(100),
    codigo_postal       NVARCHAR(100),
    telefono            NVARCHAR(100),
    email               NVARCHAR(100),
    medio_de_pago       NVARCHAR(100)   
)

INSERT INTO @ordenes_seleccionadas
SELECT
    id_orden,
    id_tercero          =   JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'),
    id_empresa          =   JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'),
    tipo_documento      =   JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType'),
    nombre_cliente      =   JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'),
    apellido_cliente    =   JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'), 
    calle               =   JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'),
    complemento         =   JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement'),
    codigo_postal       =   JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'),
    telefono            =   REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), '+57', ''),
    email               =   JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'),
    medio_de_pago       =   json_value(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName')
FROM ordenes
-- WHERE
--     id_estado = 1
--     AND 
--     (
--         intentos <= 3 
--         OR 
--         intentos IS NULL
--     )
--     AND 
--     ISNULL(endpoint,'') != @endpoint

SELECT
    endpoint        =   @endpoint,
    id_estado       =   2,
    intentos        =   0,
    fecha_creacion  =   GETDATE(),
    orden_obj_destino   =
    (
        SELECT
            Terceros =
            (
                SELECT
                    F200_ID =   
                    CASE 
							WHEN id_tercero =   '' 
								THEN id_empresa
							ELSE id_tercero
						END,
                    F200_NIT    =
                        CASE 
							WHEN id_tercero =   '' 
								THEN id_empresa
							ELSE id_tercero
						END,
                    F200_ID_TIPO_IDENT  =
                        CASE
							WHEN ISNULL(id_empresa, '') <> '' 
								THEN 'N'
							WHEN tipo_documento IN ('cedulaCOL', 'CC') 
								THEN 'C'
							WHEN ISNULL(tipo_documento, '') = '' 
								THEN 'C'
							ELSE ''
						END,
                    F200_IND_TIPO_TERCERO   =
						CASE 
							WHEN ISNULL(id_empresa, '') = '' 
								THEN '1' 
							ELSE '2' 
						END,
                    F200_RAZON_SOCIAL   =
						CASE 
							WHEN ISNULL(id_empresa, '') = '' 
								THEN '' 
							ELSE UPPER(CONCAT(apellido_cliente, ' ', nombre_cliente)) 
						END,
                    F200_APELLIDO1  =
						LTRIM(RTRIM(SUBSTRING(
						CASE 
							WHEN CHARINDEX(' ', LTRIM(RTRIM(UPPER(apellido_cliente)))) > 0
								THEN LEFT(
									LTRIM(RTRIM(UPPER(apellido_cliente))),
									CHARINDEX(' ', LTRIM(RTRIM(UPPER(apellido_cliente)))) - 1)
							ELSE LTRIM(RTRIM(UPPER(apellido_cliente)))
						END, 1,15))),
                    F200_APELLIDO2  =
						LTRIM(RTRIM(SUBSTRING(
						CASE 
						    WHEN CHARINDEX(' ', LTRIM(RTRIM(UPPER(apellido_cliente)))) > 0
								THEN SUBSTRING(
									LTRIM(RTRIM(UPPER(apellido_cliente))),
									CHARINDEX(' ', LTRIM(RTRIM(UPPER(apellido_cliente)))) + 1,
									LEN(LTRIM(RTRIM(UPPER(apellido_cliente)))) - 
									CHARINDEX(' ', LTRIM(RTRIM(UPPER(apellido_cliente)))) + 1)
						    ELSE ''
						END, 1,15))),
                    F200_NOMBRES    =
                        nombre_cliente,
                    F200_NOMBRE_EST =
						 CONCAT(
                            nombre_cliente, ' ', 
                            apellido_cliente
                        ),
                    F015_CONTACTO   =
                        CONCAT(
                            nombre_cliente, ' ', 
                            apellido_cliente
                        ),
                        LEFT(calle, 40) AS F015_DIRECCION1,
                        LEFT(complemento, 40) AS F015_DIRECCION2,
						'169' AS F015_ID_PAIS,
                        LEFT(codigo_postal, 2) AS F015_ID_DEPTO,
                        SUBSTRING(codigo_postal, 3, 5) AS F015_ID_CIUDAD,
						'' AS F015_ID_BARRIO,
                        telefono AS F015_TELEFONO,
                        CASE 
                            WHEN ISNULL(email, '') = '' 
                            THEN ''
                            ELSE LEFT(email, 40)
                        END AS F015_EMAIL,
                        CONVERT(CHAR(8),GETDATE(),112) AS F200_FECHA_NACIMIENTO,
						'0010' AS F200_ID_CIIU,
                        telefono AS F015_CELULAR
            )
        FOR JSON PATH,
        WITHOUT_ARRAY_WRAPPER
    )
FROM @ordenes_seleccionadas
/*UPDATE ordenes
SET 
    endpoint = @endpoint,
    id_estado = 2,
    intentos = 0,
    fecha_creacion = GETDATE(),
    orden_obj_destino = JSON_QUERY((
        SELECT
            -- Nodo Terceros
            JSON_QUERY((
                SELECT *
                FROM (
                    SELECT 
                        CASE 
							WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = '' 
								THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
							ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END AS F200_ID,
                        CASE 
							WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = '' 
								THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
							ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END AS F200_NIT,
                        CASE
							WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') <> '' 
								THEN 'N'
							WHEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') IN ('cedulaCOL', 'CC') 
								THEN 'C'
							WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType'), '') = '' 
								THEN 'C'
							ELSE ''
						END AS F200_ID_TIPO_IDENT,
						CASE 
							WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' 
								THEN '1' 
							ELSE '2' 
						END AS F200_IND_TIPO_TERCERO,
						CASE 
							WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' 
								THEN '' 
							ELSE UPPER(CONCAT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'), ' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'))) 
						END AS F200_RAZON_SOCIAL,
						LTRIM(RTRIM(SUBSTRING(
						CASE 
							WHEN CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) > 0
								THEN LEFT(
									LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')))),
									CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) - 1)
							ELSE LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))
						END, 1,15))) AS F200_APELLIDO1,
						LTRIM(RTRIM(SUBSTRING(
						CASE 
						    WHEN CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) > 0
								THEN SUBSTRING(
									LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')))),
									CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) + 1,
									LEN(LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) - 
									CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) + 1)
						    ELSE ''
						END, 1,15))) AS F200_APELLIDO2,
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName') AS F200_NOMBRES,
						 CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                        ) AS F200_NOMBRE_EST,
                        CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                        ) AS F015_CONTACTO,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), 40) AS F015_DIRECCION1,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement'), 40) AS F015_DIRECCION2,
						'169' AS F015_ID_PAIS,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2) AS F015_ID_DEPTO,
                        SUBSTRING(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 3, 5) AS F015_ID_CIUDAD,
						'' AS F015_ID_BARRIO,
                        REPLACE(ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'),''), '+57', '') AS F015_TELEFONO,
                        CASE 
                            WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), '') = '' 
                            THEN ''
                            ELSE LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), 40)
                        END AS F015_EMAIL,
                        CONVERT(CHAR(8),GETDATE(),112) AS F200_FECHA_NACIMIENTO,
						'0010' AS F200_ID_CIIU,
                        REPLACE(ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'),''), '+57', '') AS F015_CELULAR
                ) AS terceros
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Terceros,

            -- Nodo Clientes
            JSON_QUERY((
                SELECT 
                    CASE 
						WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
							THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
					END AS F201_ID_TERCERO,
                    '001' AS F201_ID_SUCURSAL,
                    CONCAT(
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                    ) AS F201_DESCRIPCION_SUCURSAL,
                    CONCAT(
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                    ) AS F015_CONTACTO,
					CASE 
						WHEN json_value(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%Addi%'			THEN 'C005'
						WHEN json_value(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%Mastercard%'	THEN 'C007'
						WHEN json_value(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%Visa%'			THEN 'C007'
						WHEN json_value(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%PSE%'			THEN 'C007'
						WHEN json_value(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%SisteCredito%'  THEN 'C006'
						WHEN json_value(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%WompiCo%'		THEN 'C007'
						WHEN json_value(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%Nequi%'			THEN 'C007'
						WHEN json_value(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') LIKE '%Assumed value by affiliate Agaval(GVL)%'			THEN 'C008'
						ELSE 'C007'
					END AS F201_ID_TIPO_CLI,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), 40) AS F015_DIRECCION1,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2) AS F015_ID_DEPTO,
                    SUBSTRING(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 3, 5) AS F015_ID_CIUDAD,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), 40) AS F015_EMAIL,
                    CONVERT(CHAR(8),GETDATE(),112) AS F201_FECHA_INGRESO,
                    REPLACE(ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'),''), '+57', '') AS F015_CELULAR
					

                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Clientes,

            -- Nodo Impuestos y Retenciones
            JSON_QUERY((
                SELECT * FROM (
                    SELECT 
                        '46' AS F_TIPO_REG,
                        CASE 
							WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
								THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
							ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END AS F_ID_TERCERO,
                        '001' AS F_ID_SUCURSAL,
                        '1' AS F_ID_CLASE,
                        '1' AS F_ID_VALOR_TERCERO
                ) AS imptos_y_reten
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Imptos_y_Reten,

            -- Nodo EntDinamicaTercero
            JSON_QUERY((
                SELECT * FROM (
					SELECT 
						CASE 
						    WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
								THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						    ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END AS f200_id,
                           'EUNOECO017' AS f753_id_entidad,
                           'co017_codigo_regimen' AS f753_id_atributo,
                           'MUNOECO016' AS f753_id_maestro,
                           '49' AS f753_id_maestro_detalle
                UNION ALL
					SELECT 
						CASE 
						    WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
								THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						    ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END AS f200_id,
                           'EUNOECO017' AS f753_id_entidad,
                           'co017_cod_tipo_oblig' AS f753_id_atributo,
                           'MUNOECO019' AS f753_id_maestro,
                           'R-99-PN' AS f753_id_maestro_detalle
                UNION ALL
					SELECT 
						CASE 
						    WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
								THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						    ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END AS f200_id,
                           'EUNOECO031' AS f753_id_entidad,
                           'co031_detalle_tributario1' AS f753_id_atributo,
                           'MUNOECO035' AS f753_id_maestro,
                           'ZZ' AS f753_id_maestro_detalle
                ) AS ent_dinamica_tercero
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Ent_Dinamica_Tercero

        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    ))
WHERE 
    id_estado = 1
    AND id_estado = 1
    AND (intentos <= 3 or intentos IS NULL)
    AND ISNULL(endpoint,'') != @endpoint
*/