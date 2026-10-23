DECLARE @endpoint NVARCHAR(500) = 'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?idCompania=6618&idSistema=2&idDocumento=214849&nombreDocumento=Ecommerce_Terceros_Clientes'
UPDATE ordenes
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
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' 
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END AS F200_ID,
                        CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END AS F200_NIT,
                        CASE
						  WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') <> '' THEN 'N'
						  WHEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') IN ('cedulaCOL', 'CC') THEN 'C'
						  WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType'), '') = '' THEN 'C'
						  ELSE ''
						END AS F200_ID_TIPO_IDENT,
						CASE 
						  WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' THEN '1' 
						  ELSE '2' 
						END AS F200_IND_TIPO_TERCERO,
						CASE 
							WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.tradeName'), '') <> '' 
							THEN dbo.fn_Replace_Accents(JSON_VALUE(orden_obj_origen, '$.clientProfileData.tradeName'))
							ELSE
								CASE 
								  WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' 
								  THEN '' 
								  ELSE UPPER(dbo.fn_Replace_Accents(CONCAT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'), ' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName')))) 
								END 
						END AS F200_RAZON_SOCIAL,
						CASE 
							WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.tradeName'), '') <> '' 
							THEN ''
							ELSE
							LTRIM(RTRIM(SUBSTRING(
								CASE 
								        WHEN CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) > 0
								        THEN LEFT(
								            LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')))),
								            CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))) - 1
								        )
								        ELSE LTRIM(RTRIM(UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))
								    END, 1,15))) 
							END AS F200_APELLIDO1,		
						CASE 
							WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.tradeName'), '') <> '' 
							THEN ''
							ELSE
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
							    END, 1,15))) 
							END AS F200_APELLIDO2,
						CASE 
							WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.tradeName'), '') <> '' 
							THEN LEFT(dbo.fn_Replace_Accents(JSON_VALUE(orden_obj_origen, '$.clientProfileData.tradeName')),40)
							ELSE
								UPPER(dbo.fn_Replace_Accents(JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'))) 
							END AS F200_NOMBRES,
                        UPPER(CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                        )) AS F015_CONTACTO,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), 40) AS F015_DIRECCION1,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood'), 40) AS F015_DIRECCION2,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2) AS F015_ID_DEPTO,
                        SUBSTRING(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 3, 5) AS F015_ID_CIUDAD,
                         REPLACE(ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'),''), '+57', '') AS F015_TELEFONO,
                        CASE 
                            WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), '') = '' 
                            THEN ''
                            ELSE LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), 40)
                        END AS F015_EMAIL,
                        CONVERT(CHAR(8),GETDATE(),112) AS F200_FECHA_NACIMIENTO,
                        REPLACE(ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'),''), '+57', '') AS F015_CELULAR
                ) AS terceros
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Terceros,

            -- Nodo Clientes
            JSON_QUERY((
                SELECT 
                    CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
					END AS F201_ID_TERCERO,
					CASE 
						WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.tradeName'), '') <> '' 
						THEN LEFT(dbo.fn_Replace_Accents(JSON_VALUE(orden_obj_origen, '$.clientProfileData.tradeName')),40)
						ELSE
                            dbo.fn_Replace_Accents(
							CONCAT(
							    JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
							    JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
							))
						END AS F201_DESCRIPCION_SUCURSAL,
                    CONCAT(
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                    ) AS F015_CONTACTO,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), 40) AS F015_DIRECCION1,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood'), 40) AS F015_DIRECCION2,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2) AS F015_ID_DEPTO,
                    SUBSTRING(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 3, 5) AS F015_ID_CIUDAD,
                    REPLACE(ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'),''), '+57', '') AS F015_TELEFONO,
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
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END AS F_ID_TERCERO,
                        '1' AS F_ID_CLASE,
                        '1' AS F_ID_VALOR_TERCERO
					UNION ALL
					SELECT 
                        '46' AS F_TIPO_REG,
                        CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END, '2', '0'	
                    UNION ALL
                    SELECT 
						'47',
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END, '1', IIF((CASE
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') <> '' THEN 'N'
						   WHEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') IN ('cedulaCOL', 'CC') THEN 'C'
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType'), '') = '' THEN 'C'
						   ELSE ''
						   END)='C','0','1')
                    UNION ALL
                    SELECT '47',
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END, '2', '0'
					UNION ALL
                    SELECT '47',
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END, '3', '1'
					UNION ALL
                    SELECT '47',
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END, '80', '1'
                ) AS ImpuestosyRetenciones
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS ImpuestosyRetenciones,

			-- Nodo CriteriosClientes
			JSON_QUERY((
                SELECT * FROM (
                    SELECT CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						   THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						   ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						   END AS F207_ID_TERCERO,
                           '002' AS F207_ID_PLAN_CRITERIOS,
                           '00' AS F207_ID_CRITERIO_MAYOR
                    UNION ALL
                    SELECT CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						   THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						   ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						   END AS F207_ID_TERCERO,
                           '003' AS F207_ID_PLAN_CRITERIOS,
                           '11' AS F207_ID_CRITERIO_MAYOR
                    UNION ALL
                    SELECT CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						   THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						   ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						   END AS F207_ID_TERCERO,
                           '004' AS F207_ID_PLAN_CRITERIOS,
                           IIF((CASE
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') <> '' THEN 'N'
						   WHEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') IN ('cedulaCOL', 'CC') THEN 'C'
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType'), '') = '' THEN 'C'
						   ELSE ''
						   END)='C','S','E') AS F207_ID_CRITERIO_MAYOR
                ) AS CriteriosClientes
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS CriteriosClientes,

            -- Nodo EntDinamicaTercero
            JSON_QUERY((
                SELECT * FROM (
                    SELECT CASE 
						      WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						     THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						     ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						   END AS f200_id,
                           'EUNOECO017' AS f753_id_entidad,
                           'co017_codigo_regimen' AS f753_id_atributo,
						   IIF((CASE
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') <> '' THEN 'N'
						   WHEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') IN ('cedulaCOL', 'CC') THEN 'C'
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType'), '') = '' THEN 'C'
						   ELSE ''
						   END)='C','49','48') AS f753_dato_numerico,
                           'MUNOECO016' AS f753_id_maestro,
                           IIF((CASE
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') <> '' THEN 'N'
						   WHEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') IN ('cedulaCOL', 'CC') THEN 'C'
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType'), '') = '' THEN 'C'
						   ELSE ''
						   END)='C','49','48') AS f753_id_maestro_detalle
                    UNION ALL
                    SELECT CASE 
						      WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						     THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						     ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						   END AS f200_id, 'EUNOECO017', 'co017_cod_tipo_oblig', '0', 'MUNOECO019', 'O-13'
						   WHERE CASE 
									WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') <> '' THEN 'N'
									WHEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') IN ('cedulaCOL', 'CC') THEN 'C'
									WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType'), '') = '' THEN 'C'
									ELSE ''
									END = 'N'
					UNION ALL
                    SELECT CASE 
						      WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						     THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						     ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						   END AS f200_id, 'EUNOECO017', 'co017_cod_tipo_oblig2', '0', 'MUNOECO019', 'O-15'
						   WHERE CASE 
									WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') <> '' THEN 'N'
									WHEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') IN ('cedulaCOL', 'CC') THEN 'C'
									WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType'), '') = '' THEN 'C'
									ELSE ''
									END = 'N'
					UNION ALL
                    SELECT CASE 
						      WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						     THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						     ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						   END AS f200_id, 'EUNOECO031', 'co031_detalle_tributario1', '31', 'MUNOECO035', '01'
                ) AS EntDinamicaTercero
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS EntDinamicaTercero,

            -- Nodo EntDinamicaCliente
            JSON_QUERY((
				SELECT * FROM (
					SELECT 
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END AS f201_id_tercero,
						'HABEAS DATA' AS f753_id_atributo,
						'' AS f753_dato_texto,
						'' AS f753_dato_fecha_hora,
						'AUTORIZATD' AS f753_id_maestro,
						'01' AS f753_id_maestro_detalle
					UNION ALL
					SELECT 
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END AS f201_id_tercero, 'FECHA HABEAS DATA', '', CONVERT(CHAR(8),GETDATE(),112), '', ''
						UNION ALL
					SELECT 
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END AS f201_id_tercero, 'OTP VALIDACION HABEAS DATA', 'ECOMMERCE', '', '', ''
				) AS EntDinamicaTercero
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS EntDinamicaCliente

        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    ))
WHERE 
    id_estado = 1
    AND id_tienda = 1
    AND JSON_VALUE(orden_obj_origen, '$.hostname') = 'pisende'
    AND ISNULL(intentos, 0) <= 3
    AND ISNULL(endpoint, '') != @endpoint;