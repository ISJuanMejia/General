DECLARE @endpoint NVARCHAR(500) = 'http://localhost:82/v3.1/conectoresimportar?idCompania=6230&idSistema=2&idDocumento=205743&nombreDocumento=SPEEDO_TERCEROS_CLI_IVA_INT'

UPDATE o
SET id_estado = 3
FROM ordenes o
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t200_mm_terceros t 
        ON 
            t.f200_id   =   ISNULL(
                JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), 
                JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
            )
WHERE
    o.id_tienda = 1 
    AND 
    (
        f200_ind_proveedor = 1
        OR 
        f200_ind_accionista = 1
        OR 
        f200_ind_empleado = 1
    )
    AND
    o.id_estado in (1, 2) 

UPDATE ordenes
SET 
    endpoint            =   @endpoint,
    id_estado           =   2,
    intentos            =   0,
    fecha_creacion      =   GETDATE(),
    orden_obj_destino   =   
        JSON_QUERY(
            (
                SELECT
                    -- Nodo Terceros
                    JSON_QUERY(
                        (
                            SELECT
                                F200_ID                 =   id_cliente,
                                F200_NIT                =   id_cliente,
                                F200_ID_TIPO_IDENT      =   id_tipo_identificacion,
                                F200_IND_TIPO_TERCERO   =   ind_tipo_tercero,
                                F200_RAZON_SOCIAL       =   razon_social
                            FROM (
                                SELECT 
                                    id_cliente = 
                                        CASE 
                                            WHEN 
                                                ISNULL(
                                                    JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
                                                    , ''
                                                ) = ''  
                                                THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
                                            ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						                END,
                                    id_tipo_identificacion =
                                        CASE
                                            WHEN 
                                                ISNULL(
                                                    JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
                                                    , ''
                                                ) <> ''
                                                THEN 'N'
                                            WHEN 
                                                JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') IN ('cedulaCOL', 'CC')
                                                THEN 'C'
                                            WHEN 
                                                ISNULL(
                                                    JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType')
                                                    , ''
                                                ) = ''
                                                THEN 'C'
                                            WHEN 
                                                JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') IN ('cedula-de-extranjeria', 'CE') 
                                                THEN 'E'
                                            WHEN 
                                                JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') = 'pasaporte' 
                                                THEN 'P'
                                            ELSE 'O'
						                END,
                                    ind_tipo_tercero =
                                        CASE 
                                            WHEN 
                                                ISNULL(
                                                    JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
                                                    , ''
                                                ) = '' 
                                                THEN '1' 
                                            ELSE '2' 
						                END,
                                    razon_social =
                                        CASE
                                            WHEN 
                                                ISNULL(
                                                    JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
                                                    , ''
                                                ) = '' 
                                                THEN '' 
						                    ELSE 
                                                UPPER(
                                                    CONCAT(
                                                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                                                        , ' '
                                                        , JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName')
                                                    )
                                                ) 
						                END,
                        LTRIM(RTRIM(SUBSTRING(
							CASE 
							        WHEN CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) > 0
							        THEN LEFT(
							            LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')))),
							            CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) - 1
							        )
							        ELSE LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))
							    END, 1,15))) AS F200_APELLIDO1,		
						LTRIM(RTRIM(SUBSTRING(
						    CASE 
						        WHEN CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) > 0
						        THEN SUBSTRING(
						            LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')))),
						            CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) + 1,
						            LEN(LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) - 
						            CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) + 1
						        )
						        ELSE ''
						    END, 1,15))) AS F200_APELLIDO2,
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName') AS F200_NOMBRES,
                        CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                        ) AS F015_CONTACTO,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), 40) AS F015_DIRECCION1,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement'), 40) AS F015_DIRECCION2,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood'), 40) AS F015_DIRECCION3,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2) AS F015_ID_DEPTO,
                        SUBSTRING(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 3, 5) AS F015_ID_CIUDAD,
                         REPLACE(ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'),''), '+57', '') AS F015_TELEFONO,
                        CASE 
                            WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), '') = '' 
                            THEN 'SINCORREO@NADAR.COM'
                            ELSE LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), 40)
                        END AS F015_EMAIL,
                        CONVERT(CHAR(8),GETDATE(),112) AS F200_FECHA_NACIMIENTO,
                        CASE 
						  WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.corporateDocument'), '') <> '' THEN '9999' 
						  ELSE '0081' 
						END AS F200_ID_CIIU,
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
                    LEFT(
						    CONCAT(
						        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ',
						        JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
						    ), 
						    40
						) AS F201_DESCRIPCION_SUCURSAL,
                    CONCAT(
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                    ) AS F015_CONTACTO,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), 40) AS F015_DIRECCION1,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement'), 40) AS F015_DIRECCION2,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood'), 40) AS F015_DIRECCION3,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2) AS F015_ID_DEPTO,
                    SUBSTRING(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 3, 5) AS F015_ID_CIUDAD,
                     REPLACE(ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'),''), '+57', '') AS F015_TELEFONO,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), 40) AS F015_EMAIL,
                    '20250408' AS F201_FECHA_INGRESO,
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
					WHERE NOT EXISTS (
			            SELECT 1 
			            FROM OPENJSON(orden_obj_origen, '$.ratesAndBenefitsData.rateAndBenefitsIdentifiers') 
			            WHERE JSON_VALUE(value, '$.name') = 'Impuesto en San Andres' )
                    UNION ALL
                    SELECT 
						'47',
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END, '001', '1', '1'
                    UNION ALL
                    SELECT '47',
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END, '001', '5', '1'
                ) AS ImpuestosyRetenciones
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS ImpuestosyRetenciones,

            -- Nodo EntDinamicaTercero
            JSON_QUERY((
                SELECT * FROM (
                    SELECT CASE 
						      WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
						     THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						     ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						   END AS f200_id,
                           'FE_CODIGO/TIPO OBLIGACION 2.1' AS f753_id_grupo_entidad,
                           'EUNOECO017' AS f753_id_entidad,
                           'co017_codigo_regimen' AS f753_id_atributo,
                           'MUNOECO016' AS f753_id_maestro,
                           '49' AS f753_id_maestro_detalle
                    UNION ALL
                    SELECT CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END, 'FE_CODIGO/TIPO OBLIGACION 2.1', 'EUNOECO017', 'co017_cod_tipo_oblig', 'MUNOECO019', 'R-99-PN'
                    UNION ALL
                    SELECT CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END, 'FE_CODIGO/TIPO OBLIGACION 2.1', 'EUNOECO031', 'co031_detalle_tributario1', 'MUNOECO035', 'ZY'
                ) AS EntDinamicaTercero
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS EntDinamicaTercero,

            -- Nodo EntDinamicaCliente
            JSON_QUERY((
                SELECT 
                    CASE 
					   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
					  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
					  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
					END AS f201_id_tercero,
                    '001' AS f201_id_sucursal,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), 40) AS f753_dato_texto
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS EntDinamicaCliente

        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    ))
WHERE 
    id_estado = 1
    AND id_tienda = 1
    AND ISNULL(intentos, 0) <= 3
    AND ISNULL(endpoint, '') != @endpoint;