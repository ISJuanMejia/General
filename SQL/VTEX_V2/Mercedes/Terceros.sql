DECLARE @endpoint NVARCHAR(500) = 'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?idCompania=9056&idSistema=2&idDocumento=211153&nombreDocumento=Ecommerce_Terceros_Clientes'

UPDATE ordenes
SET 
    endpoint = @endpoint,
    intentos = 0,
    fecha_creacion = GETDATE(),
	id_estado = 2,
    orden_obj_destino = JSON_QUERY(
        '{
            "Inicial": [
                {
                    "F_CIA": "001"
                }
            ],
            "Terceros": [
                {
                    "F_CIA": "001",
                    "F200_ID": "' + JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') + '",
                    "F200_NIT": "' + JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') + '",
                    "F200_ID_TIPO_IDENT": "C",
                    "F200_IND_TIPO_TERCERO": "1",
                    "F200_RAZON_SOCIAL": "' + 
                        CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                        ) + '",
                   "F200_APELLIDO1": "' + 
					  CASE 
						WHEN CHARINDEX(' ', LTRIM(RTRIM(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')))) > 0 
						THEN LEFT(LTRIM(RTRIM(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))), CHARINDEX(' ', LTRIM(RTRIM(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')))) - 1)
						ELSE LTRIM(RTRIM(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))) 
					  END + '",

					"F200_APELLIDO2": "' + 
					  CASE 
						WHEN CHARINDEX(' ', LTRIM(RTRIM(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')))) > 0 
						THEN LTRIM(SUBSTRING(LTRIM(RTRIM(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))), CHARINDEX(' ', LTRIM(RTRIM(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')))) + 1, LEN(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))))
						ELSE ''
					  END + '",
                    "F200_NOMBRES": "' + JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName') + '",
                    "F200_IND_EMPLEADO": "0",
                    "F015_CONTACTO": "' + 
                        CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                        ) + '",
                    "F015_DIRECCION1": "' + LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), 40) + '",
                    "F015_DIRECCION2": "'+ CASE WHEN JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement') IS NULL THEN '' ELSE LEFT(ISNULL(JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement'), ''), 40) END +'",
                    "F015_DIRECCION3": "' + CASE WHEN JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood') IS NULL THEN '' ELSE LEFT((JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood')), 40) END + '",
                    "F015_ID_PAIS": "169",
                    "F015_ID_DEPTO": "' + LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2) + '",
                    "F015_ID_CIUDAD": "' + 
                        SUBSTRING(
                            JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 
                            3, 
                            LEN(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'))
                        ) + '",
                    "F015_TELEFONO": "' + REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), '+57', '') + '",
                    "F015_EMAIL": "' + LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), 50) + '",
                    "F200_FECHA_NACIMIENTO": "' + FORMAT(GETDATE(), 'yyyyMMdd') + '",
                    "F015_CELULAR": "' + REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), '+57', '') + '"
                }
            ],
            "Clientes": [
                {
                    "F_CIA": "001",
                    "F201_ID_TERCERO": "' + JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') + '",
                    "F201_ID_SUCURSAL": "001",
                    "F201_DESCRIPCION_SUCURSAL":  "' + 
                        CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                        ) + '",
                    "F015_CONTACTO": "' + 
                        CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', 
                            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')
                        ) + '",
                    "F015_DIRECCION1": "' + LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), 40) + '",
                    "F015_DIRECCION2": "'+ CASE WHEN JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement') IS NULL THEN '' ELSE LEFT(ISNULL(JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement'), ''), 40) END +'",
                    "F015_DIRECCION3": "' + CASE WHEN JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood') IS NULL THEN '' ELSE LEFT((JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood')), 40) END + '",
                    "F015_ID_PAIS": "169",
                    "F015_ID_DEPTO": "' + LEFT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 2) + '",
                    "F015_ID_CIUDAD": "' + 
                        SUBSTRING(
                            JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), 
                            3, 
                            LEN(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'))
                        ) + '",
                    "F015_TELEFONO": "' + REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), '+57', '') + '",
                    "F015_EMAIL": "' + LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), 50) + '",
                    "F201_FECHA_INGRESO": "' + FORMAT(GETDATE(), 'yyyyMMdd') + '",
                    "f015_celular": "' + REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), '+57', '') + '"
                }
            ],
            "ImptosYReten": [
                {
                    "F_CIA": "001",
                    "F_ID_TERCERO": "' + JSON_VALUE(orden_obj_origen, '$.clientProfileData.document') + '",
                    "F_ID_SUCURSAL": "001",
                    "F_ID_VALOR_TERCERO": "1"
                }
            ],
            "Final": [
                {
                    "F_CIA": "001"
                }
            ]
        }'
    )
WHERE 
    id_estado IN (1,2)
    AND (intentos <= 3 or intentos IS NULL)
    AND ISNULL(endpoint,'') != @endpoint