;WITH Duplicados AS
(
    SELECT *,
           ROW_NUMBER() OVER(PARTITION BY id_orden ORDER BY Id) AS rn
    FROM [vtex-estandar-dluchi].[dbo].[ordenes]
)
DELETE
FROM Duplicados
WHERE rn > 1;

-- ============================================
-- SECCIÓN 1: DECLARACIÓN DE VARIABLES
-- ============================================
-- Define el endpoint API donde se enviarán los datos procesados
DECLARE @endpoint NVARCHAR(500) = 'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?idCompania=9082&idSistema=2&idDocumento=225676&nombreDocumento=Terceros_Clientes_Dluchi'

-- ============================================
-- SECCIÓN 2: ACTUALIZACIÓN DE ÓRDENES - MARCAS DE EXCLUSIÓN
-- ============================================
-- Marca todas las órdenes NO originarias de 'dluchi' como estado 8 (excluidas)
-- Condiciones: hostname diferente de 'dluchi' y estado actual no sea 8
UPDATE [vtex-estandar-dluchi].[dbo].[ordenes] SET id_estado = 8
WHERE JSON_VALUE(orden_obj_origen,'$.hostname') <> 'dluchi'
AND id_estado <> 8


-- ============================================
-- SECCIÓN 3: ACTUALIZACIÓN DE ÓRDENES - MARCAS A EMPLEADOS ERP
-- ============================================
-- Marca órdenes de empleados (estado 1) como estado 3 (procesar)
-- Obtiene lista de empleados desde base ERP y hace JOIN con órdenes por NIT
-- Consulta empleados activos (f200_ind_empleado = 1) de la compañía 1 en BD ERP
UPDATE o SET o.id_estado = 3 
FROM OPENROWSET(
        'SQLNCLI11', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Comercbd_Real;Uid=Comercbd;Pwd=Comercbd$12$%;',
		'
		SELECT f200_nit FROM t200_mm_terceros WHERE f200_ind_empleado = 1 AND f200_id_cia = 1
		'
		) AS empleadosERP
INNER JOIN [vtex-estandar-dluchi].[dbo].[ordenes] o ON empleadosERP.f200_nit = CASE 
												   WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), '') = ''  
												   THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
												   ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') 
												END
WHERE id_estado = 1


-- ============================================
-- SECCIÓN 4: ACTUALIZACIÓN PRINCIPAL - PREPARACIÓN DE DATOS PARA ENVÍO
-- ============================================
UPDATE [vtex-estandar-dluchi].[dbo].[ordenes]
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
						  WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') <> '' THEN 'N'
						  WHEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType') IN ('cedulaCOL', 'CC','2') THEN 'C'
						  WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.documentType'), '') = '' THEN 'C'
						  ELSE ''
						END AS F200_ID_TIPO_IDENT,
						CASE 
						  WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' THEN '1' 
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
                        UPPER(JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName')) AS F200_NOMBRES,
                        UPPER(CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                        )) AS F015_CONTACTO,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), 40) AS F015_DIRECCION1,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood'), 40) AS F015_DIRECCION2,
                        LEFT(ISNULL(JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement'), ''), 40) AS F015_DIRECCION3,
                        LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2) AS F015_ID_DEPTO,
                        SUBSTRING(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 3, 5) AS F015_ID_CIUDAD,
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
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
					END AS F201_ID_TERCERO,
                    LEFT(UPPER(CONCAT(
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                    )),40) AS F201_DESCRIPCION_SUCURSAL,
                    UPPER(CONCAT(
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                        JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                    )) AS F015_CONTACTO,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), 40) AS F015_DIRECCION1,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood'), 40) AS F015_DIRECCION2,
                    LEFT(ISNULL(JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement'), ''), 40) AS F015_DIRECCION3,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2) AS F015_ID_DEPTO,
                    SUBSTRING(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 3, 5) AS F015_ID_CIUDAD,
                    LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), 40) AS F015_EMAIL,
                    CONVERT(CHAR(8),GETDATE(),112) AS F201_FECHA_INGRESO,
                    REPLACE(ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'),''), '+57', '') AS f015_celular
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
                        '1' AS F_ID_CLASE,
                        '1' AS F_ID_VALOR_TERCERO

					UNION ALL
	
                    SELECT 
						'47',
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END, '1', '0'

                    UNION ALL

                    SELECT '47',
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END, '41', '1'
					
                ) AS ImpuestosRetenciones
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS ImpuestosRetenciones,

            -- Nodo EntDinamicaCliente
            JSON_QUERY((
				SELECT * FROM (
					SELECT 
						CASE 
						   WHEN ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') = ''  
						  THEN JSON_VALUE(orden_obj_origen, '$.clientProfileData.corporateDocument')
						  ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') 
						END AS f201_id_tercero,
						 LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), 40) AS f753_dato_texto
				) AS EntidadDinamicaCliente
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS EntidadDinamicaCliente

        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    ))
WHERE 
    id_estado = 1
    AND id_tienda = 1
    AND ISNULL(intentos, 0) <= 3