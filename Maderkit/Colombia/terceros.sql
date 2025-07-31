DECLARE @url                VARCHAR(50)     =   'http://localhost:84';
DECLARE @cia                VARCHAR(4)      =   '4879';
DECLARE @id_sistema         VARCHAR(2)      =   '2';
DECLARE @id_documento       VARCHAR(6)      =   '215538';
DECLARE @nombre_documento   VARCHAR(100)    =   'terceros_maderkit_vtex_col';
DECLARE @validar_estructura VARCHAR(10)     =   'false';

DECLARE @endpoint NVARCHAR(500) = @url + '/v3.1/ConectoresImportar?idCompania=' + @cia + '&idSistema=' + @id_sistema + '&idDocumento=' + @id_documento + '&nombreDocumento=' + @nombre_documento + '&validarEstructura=' + @validar_estructura

UPDATE ordenes
SET 
    endpoint = @endpoint,
    intentos = 0,
    fecha_creacion = GETDATE(),
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
						    WHEN CHARINDEX(' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')) > 0 
						    THEN LEFT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'), CHARINDEX(' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')) - 1)
						    ELSE JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName') 
						END + '",
                    "F200_APELLIDO2": "' +   
						LTRIM(
						    CASE 
						        WHEN CHARINDEX(' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')) > 0 
						        THEN SUBSTRING(
						            JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'), 
						            CHARINDEX(' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')) + 1, 
						            LEN(JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName'))
						        )
						        ELSE ''
						    END
						) + '",
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
    -- id_estado = 3
    -- AND intentos <= 3
    -- AND 
    ISNULL(endpoint,'') != @endpoint;

/*
{
  "Terceros": [
    {
      "F200_ID": "11111",
      "F200_NIT": "11111",
      "F200_ID_TIPO_IDENT": "C",    //C: Cédula, N: NIT
      "F200_IND_TIPO_TERCERO": "1", //1: Natural, 2: Juridica
      "F200_RAZON_SOCIAL": "Andrea Alvarez Arango",
      "F200_NOMBRE_EST": "Andrea Alvarez Arango",
      "F200_APELLIDO1": "Alvarez",
      "F200_APELLIDO2": "Arango",
      "F200_NOMBRES": "Andrea",
      "F015_CONTACTO": "Andrea Alvarez Arango",
      "F015_DIRECCION1": "Carrera 12",
      "F015_DIRECCION2": "Calle 34",
      "F015_DIRECCION3": "",
      "F015_ID_PAIS": "169",
      "F015_ID_DEPTO": "05",
      "F015_ID_CIUDAD": "001",
      "F015_TELEFONO": "3123456780",
      "F015_EMAIL": "andreaalvarezarango@correo.com",
      "F200_FECHA_NACIMIENTO": "19900101",
      "F200_ID_CIIU": "0081", // Personas naturales
      "F015_CELULAR": "3111111111"
    }
  ],
  "Clientes": [
    {
      "F201_ID_TERCERO": "11111",
      "F201_DESCRIPCION_SUCURSAL": "Andrea Alvarez Arango",
      "F201_NOTAS": "#0001",
      "F015_CONTACTO": "Andrea Alvarez Arango",
      "F015_DIRECCION1": "Carrera 12",
      "F015_DIRECCION2": "Calle 34",
      "F015_DIRECCION3": "",
      "F015_ID_PAIS": "169",
      "F015_ID_DEPTO": "05",
      "F015_ID_CIUDAD": "001",
      "F015_TELEFONO": "3111111111",
      "F015_EMAIL": "andreaalvarezarango@correo.com",
      "F201_FECHA_INGRESO": "20250715",
      "f015_celular": "3111111111"
    }
  ],
  "Imptos_y_Reten": [
    {
        "F_TIPO_REG": "46",         //46: Impuesto cliente
        "F_ID_TERCERO": "11111",
        "F_ID_CLASE": "1"           //IVA
    },
    {
       "F_TIPO_REG": "47",      //47: Retención cliente
       "F_ID_TERCERO": "11111",
       "F_ID_CLASE": "41"       //41: AUTORRETENCION RENTA | AUTORTA
    }
  ],
  "Criterios_Clientes": [
    {
      "F207_ID_TERCERO": "11111",
      "F207_ID_PLAN_CRITERIOS": "001",  // ==> TIPO DE CLIENTE
      "F207_ID_CRITERIO_MAYOR": "1"     // ==> NACIONAL
    },
    {
      "F207_ID_TERCERO": "11111",
      "F207_ID_PLAN_CRITERIOS": "002",  // ==> CANAL DE COMERCIALIZACION
      "F207_ID_CRITERIO_MAYOR": "13"    // ==> INTERNET
    },
    {
      "F207_ID_TERCERO": "11111",
      "F207_ID_PLAN_CRITERIOS": "003",  // ==> CLIENTE
      "F207_ID_CRITERIO_MAYOR": "1301"  // ==> PAGINA WEB PROPIA
    }
  ],
  "Ent_Dinamica_Tercero": [
    {
      "f200_id": "11111",
      "f753_id_entidad": "EUNOECO017",                  // ==> Códigos Tercero - FE 2.1
      "f753_id_atributo": "co017_codigo_regimen",       // ==> Código régimen
      "f753_id_maestro": "MUNOECO016",                  // ==> Regimen Fiscal - FE 2.1
      "f753_id_maestro_detalle": "48"                   // ==> Impuesto sobre las ventas - IVA
    },
    {
      "f200_id": "11111",
      "f753_id_entidad": "EUNOECO017",                  // ==> Códigos Tercero - FE 2.1
      "f753_id_atributo": "co017_cod_tipo_oblig",       // ==> Código obligación 1
      "f753_id_maestro": "MUNOECO019",                  // ==> Responsabilidades fiscales - FE 2.1
      "f753_id_maestro_detalle": "R-99-PN"              // ==> No responsable
    },
    {
      "f200_id": "11111",
      "f753_id_entidad": "EUNOECO031",                  // ==> Detalles tributarios - FE 2.1
      "f753_id_atributo": "co031_detalle_tributario1",  // ==> Detalle tributario 1
      "f753_id_maestro": "MUNOECO035",                  // ==> Detalles tributarios - FE 2.1
      "f753_id_maestro_detalle": "01"                   // ==> IVA
    },
    {
      "f200_id": "11111",
      "f753_id_entidad": "EUNOECO036",                  // ==> Info adicional tcro FE 21 DS
      "f753_id_atributo": "co036_id_procedencia_org",   // ==> Id. Procedencia organización
        "f753_id_maestro": "MUNOECO043",                // ==> Id. Procedencia ORG FE 2.1 DS
        "f753_id_maestro_detalle": "10"                 // ==> Residente
    }
  ]
}
*/