/* =========================================================================================
   PROYECTO: VTEX ESTÁNDAR V2
   PROCESO: 07.1 IMPORTAR AL ERP - CONECTOR DE TERCEROS (SIESA / UNOEE)
   TABLA DESTINO: dbo.ordenes (endpoint, id_estado, orden_obj_destino)
   DESCRIPCIÓN: Prepara el payload JSON con la estructura requerida por el Conector de
                Importación de Terceros de Connekta Cloud / Siesa UnoEE (Nodos Terceros,
                Clientes, ImpuestosyRetenciones, EntDinamicaTercero, EntDinamicaCliente).
   ========================================================================================= */

SET NOCOUNT ON;

DECLARE @id_tienda INT = 1;
DECLARE @id_cia    INT = 1;
DECLARE @endpoint  NVARCHAR(500) = 'http://localhost:82/v3.1/conectoresimportar?idCompania=6230&idSistema=2&idDocumento=205743&nombreDocumento=TERCEROS_ECOMMERCE';

-- 1. VALIDACIÓN PREVIA: Si el tercero ya existe en Siesa, avanzar directamente a Estado 3 (Pedido)
UPDATE o
SET 
    o.id_estado = 3,
    o.intentos = 0,
    o.endpoint = NULL,
    o.orden_obj_destino = NULL
FROM [dbo].[ordenes] o
INNER JOIN [UnoEE_ERP].[dbo].[t200_mm_terceros] t 
    ON t.f200_id = ISNULL(NULLIF(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), ''), JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument'))
   AND t.f200_id_cia = @id_cia
WHERE o.id_tienda = @id_tienda 
  AND o.id_estado IN (1, 2);

-- 2. GENERAR PAYLOAD DEL CONECTOR DE TERCEROS PARA ÓRDENES PENDIENTES
UPDATE o
SET 
    o.endpoint          = @endpoint,
    o.id_estado         = 2, -- En proceso conector de terceros
    o.intentos          = 0,
    o.fecha_creacion    = GETDATE(),
    o.orden_obj_destino = JSON_QUERY((
        SELECT
            -- -----------------------------------------------------------------------------
            -- NODO 1: TERCEROS (Maestro Principal f200)
            -- -----------------------------------------------------------------------------
            JSON_QUERY((
                SELECT *
                FROM (
                    SELECT 
                        [F200_ID] = CASE 
                                        WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), '') = '' 
                                        THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                                        ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') 
                                    END,
                        [F200_NIT] = CASE 
                                         WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), '') = '' 
                                         THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                                         ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') 
                                     END,
                        [F200_ID_TIPO_IDENT] = CASE
                                                   WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument'), '') <> '' THEN 'N'
                                                   WHEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.documentType') IN ('cedulaCOL', 'CC') THEN 'C'
                                                   WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.documentType'), '') = '' THEN 'C'
                                                   WHEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.documentType') IN ('cedula-de-extranjeria', 'CE') THEN 'E'
                                                   WHEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.documentType') = 'pasaporte' THEN 'P'
                                                   ELSE 'C'
                                               END,
                        [F200_IND_TIPO_TERCERO] = CASE 
                                                      WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' THEN '1' 
                                                      ELSE '2' 
                                                  END,
                        [F200_RAZON_SOCIAL] = CASE 
                                                  WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' THEN '' 
                                                  ELSE UPPER(CONCAT(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'), ' ', JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'))) 
                                              END,
                        [F200_APELLIDO1] = LTRIM(RTRIM(SUBSTRING(
                                               CASE 
                                                   WHEN CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'))))) > 0
                                                   THEN LEFT(LTRIM(RTRIM(UPPER(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName')))), CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'))))) - 1)
                                                   ELSE LTRIM(RTRIM(UPPER(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'))))
                                               END, 1, 15))),
                        [F200_APELLIDO2] = LTRIM(RTRIM(SUBSTRING(
                                               CASE 
                                                   WHEN CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'))))) > 0
                                                   THEN SUBSTRING(
                                                       LTRIM(RTRIM(UPPER(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName')))),
                                                       CHARINDEX(' ', LTRIM(RTRIM(UPPER(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'))))) + 1,
                                                       LEN(LTRIM(RTRIM(UPPER(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName')))))
                                                   )
                                                   ELSE ''
                                               END, 1, 15))),
                        [F200_NOMBRES] = SUBSTRING(UPPER(TRIM(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'))), 1, 20),
                        [F015_CONTACTO] = SUBSTRING(UPPER(CONCAT(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'), ' ', JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'))), 1, 50),
                        [F015_DIRECCION1] = SUBSTRING(UPPER(REPLACE(CONCAT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.street'), ' ', ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.number'), '')), '''', '')), 1, 40),
                        [F015_DIRECCION2] = SUBSTRING(UPPER(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.complement'), '')), 1, 40),
                        [F015_DIRECCION3] = SUBSTRING(UPPER(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.neighborhood'), '')), 1, 40),
                        [F015_ID_DEPTO]   = SUBSTRING(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.postalCode'), 1, 2),
                        [F015_ID_CIUDAD]  = SUBSTRING(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.postalCode'), 3, 3),
                        [F015_TELEFONO]   = SUBSTRING(REPLACE(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.phone'), '0'), '+57', ''), 1, 15),
                        [F015_EMAIL]      = SUBSTRING(LOWER(TRIM(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.email'), 'facturacion@ecommerce.com'))), 1, 50),
                        [F200_FECHA_NACIMIENTO] = CONVERT(CHAR(8), GETDATE(), 112),
                        [F200_ID_CIIU]    = '0081',
                        [F015_CELULAR]    = SUBSTRING(REPLACE(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.phone'), '0'), '+57', ''), 1, 15)
                ) AS terceros
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Terceros,

            -- -----------------------------------------------------------------------------
            -- NODO 2: CLIENTES (Sucursal Cliente f201)
            -- -----------------------------------------------------------------------------
            JSON_QUERY((
                SELECT 
                    [F201_ID_TERCERO] = CASE 
                                            WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), '') = '' 
                                            THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                                            ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') 
                                        END,
                    [F201_ID_SUCURSAL] = '001',
                    [F201_DESCRIPCION_SUCURSAL] = SUBSTRING(UPPER(CONCAT(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'), ' ', JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'))), 1, 40),
                    [F015_CONTACTO]   = SUBSTRING(UPPER(CONCAT(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'), ' ', JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'))), 1, 50),
                    [F015_DIRECCION1] = SUBSTRING(UPPER(REPLACE(CONCAT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.street'), ' ', ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.number'), '')), '''', '')), 1, 40),
                    [F015_DIRECCION2] = SUBSTRING(UPPER(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.complement'), '')), 1, 40),
                    [F015_DIRECCION3] = SUBSTRING(UPPER(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.neighborhood'), '')), 1, 40),
                    [F015_ID_DEPTO]   = SUBSTRING(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.postalCode'), 1, 2),
                    [F015_ID_CIUDAD]  = SUBSTRING(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.postalCode'), 3, 3),
                    [F015_TELEFONO]   = SUBSTRING(REPLACE(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.phone'), '0'), '+57', ''), 1, 15),
                    [F015_EMAIL]      = SUBSTRING(LOWER(TRIM(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.email'), 'facturacion@ecommerce.com'))), 1, 50),
                    [F201_FECHA_INGRESO] = CONVERT(CHAR(8), GETDATE(), 112),
                    [F015_CELULAR]    = SUBSTRING(REPLACE(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.phone'), '0'), '+57', ''), 1, 15)
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS Clientes,

            -- -----------------------------------------------------------------------------
            -- NODO 3: IMPUESTOS Y RETENCIONES (Configuración tributaria online)
            -- -----------------------------------------------------------------------------
            JSON_QUERY((
                SELECT * FROM (
                    SELECT 
                        [F_TIPO_REG] = '46',
                        [F_ID_TERCERO] = CASE 
                                             WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), '') = '' 
                                             THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                                             ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') 
                                         END,
                        [F_ID_SUCURSAL] = '001',
                        [F_ID_CLASE] = '1',
                        [F_ID_VALOR_TERCERO] = '1'
                    UNION ALL
                    SELECT 
                        '47', 
                        CASE 
                            WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), '') = '' 
                            THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                            ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') 
                        END, 
                        '001', '1', '1'
                ) AS ImpuestosyRetenciones
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS ImpuestosyRetenciones,

            -- -----------------------------------------------------------------------------
            -- NODO 4: ENTIDADES DINÁMICAS TERCERO (DIAN Facturación Electrónica)
            -- -----------------------------------------------------------------------------
            JSON_QUERY((
                SELECT * FROM (
                    SELECT 
                        [f200_id] = CASE 
                                        WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), '') = '' 
                                        THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                                        ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') 
                                    END,
                        [f753_id_grupo_entidad]   = 'FE_CODIGO/TIPO OBLIGACION 2.1',
                        [f753_id_entidad]         = 'EUNOECO017',
                        [f753_id_atributo]        = 'co017_codigo_regimen',
                        [f753_id_maestro]         = 'MUNOECO016',
                        [f753_id_maestro_detalle] = '49' -- Régimen No Responsable de IVA
                    UNION ALL
                    SELECT 
                        CASE 
                            WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), '') = '' 
                            THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                            ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') 
                        END, 
                        'FE_CODIGO/TIPO OBLIGACION 2.1', 'EUNOECO017', 'co017_cod_tipo_oblig', 'MUNOECO019', 'R-99-PN'
                    UNION ALL
                    SELECT 
                        CASE 
                            WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document'), '') = '' 
                            THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                            ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') 
                        END, 
                        'FE_CODIGO/TIPO OBLIGACION 2.1', 'EUNOECO031', 'co031_detalle_tributario1', 'MUNOECO035', 'ZY'
                ) AS EntDinamicaTercero
                FOR JSON PATH, INCLUDE_NULL_VALUES
            )) AS EntDinamicaTercero

        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    ))
FROM [dbo].[ordenes] o
WHERE o.id_tienda = @id_tienda
  AND o.id_estado = 1
  AND ISNULL(o.intentos, 0) <= 3
  AND ISNULL(o.endpoint, '') <> @endpoint;
