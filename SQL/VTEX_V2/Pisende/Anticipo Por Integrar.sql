DECLARE @endpointAnticipo NVARCHAR(500) = 'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?idCompania=6618&idSistema=2&idDocumento=215337&nombreDocumento=Ecommerce_Recibo_Caja_Anticipo';
DECLARE @endpointServicio NVARCHAR(500) = 'https://servicios.siesacloud.com/api/siesa/v3.1/conectoresimportar?idCompania=6618&idSistema=2&idDocumento=215939&nombreDocumento=Ecommerce_Venta_Servicios';

IF OBJECT_ID('tempdb..#AnticiposERP') IS NOT NULL DROP TABLE #AnticiposERP;

CREATE TABLE #AnticiposERP (
    referencia NVARCHAR(100)
);

INSERT INTO #AnticiposERP
SELECT DISTINCT referencia
FROM OPENROWSET(
    'SQLNCLI',
    'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=Pisende;Pwd=Pisende$12$%;',
    '
    -- 1. Recaudos de anticipo (RCA) por f357_referencia (orderId)
    SELECT DISTINCT TRIM(r.f357_referencia) AS referencia
    FROM t357_co_recaudos r
    INNER JOIN t350_co_docto_contable c ON c.f350_rowid = r.f357_rowid_docto
    WHERE c.f350_id_cia = 1 
      AND c.f350_id_co = ''010''
      AND c.f350_id_tipo_docto = ''RCA''
      AND r.f357_referencia IS NOT NULL
    UNION
    -- 2. Documentos de servicios/creditos por f350_notas (orderId)
    SELECT DISTINCT TRIM(REPLACE(f350_notas, ''Pedido: '', '''')) AS referencia
    FROM t350_co_docto_contable
    WHERE f350_id_cia = 1 
      AND f350_id_co = ''010''
      AND f350_notas LIKE ''Pedido: %''
    '
) AS t;

-- Si el anticipo ya fue creado en Siesa, avanzar directamente a Estado 4 (Pedido Por Integrar)
UPDATE o
SET 
    id_estado           = 4,
    intentos            = 0,
    endpoint            = NULL,
    orden_obj_destino   = NULL
FROM ordenes o
INNER JOIN #AnticiposERP a 
    ON a.referencia = JSON_VALUE(o.orden_obj_origen, '$.orderId')
WHERE o.id_tienda = 1 
  AND o.id_estado = 3;

IF OBJECT_ID('tempdb..#tempOrdenes') IS NOT NULL DROP TABLE #tempOrdenes;

SELECT o.* 
INTO #tempOrdenes
FROM ordenes o
LEFT JOIN #AnticiposERP a 
    ON a.referencia = JSON_VALUE(o.orden_obj_origen, '$.orderId')
WHERE o.id_tienda = 1
  AND o.id_estado = 3
  AND ISNULL(o.intentos, 0) < 3
  AND a.referencia IS NULL;

IF OBJECT_ID('tempdb..#AnticiposERP') IS NOT NULL DROP TABLE #AnticiposERP;

-- vendedores ERP
	IF OBJECT_ID('tempdb..#VendedoresERP') IS NOT NULL 
		DROP TABLE #VendedoresERP;

    SELECT 
		 f210_id
		,f200_id 
	INTO #VendedoresERP
    FROM OPENROWSET(
        'SQLNCLI',
        'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=Pisende;Pwd=Pisende$12$%;',
        '
        SELECT 
			 f210_id
			,f200_id 
		FROM t210_mm_vendedores
		INNER JOIN t200_mm_terceros t 
			ON f210_rowid_tercero = f200_rowid 
			AND f200_id_cia = 1
        '
    );

-- Actualización final con lógica para ambos tipos de documentos
UPDATE o
SET 
    o.endpoint = CASE 
        WHEN JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') IN ('Addi','AddiMarketplace','Assumed value by affiliate Addi(DDD)', 'Servicredito','SisteCredito') 
             THEN @endpointServicio
        ELSE @endpointAnticipo
    END,
    o.fecha_creacion = GETDATE(),
    o.orden_obj_destino = 
    CASE 
        WHEN JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') IN ('Addi', 'AddiMarketplace','Assumed value by affiliate Addi(DDD)', 'Servicredito','SisteCredito') THEN
            JSON_QUERY('{
              "Documento": [{
                "F350_CONSEC_DOCTO": "1",
                "F350_FECHA": "' + CONVERT(VARCHAR(8), GETDATE(), 112) + '",
                "F350_ID_TERCERO": "' + 
                    CASE 
                        WHEN JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') IN ('Addi','AddiMarketplace','Assumed value by affiliate Addi(DDD)')  THEN '901216768'
                        WHEN JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = 'Servicredito' THEN '901997478'
                        WHEN JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') = 'SisteCredito' THEN '811007713'  
                    END + '",
                "F350_NOTAS": "Pedido: ' + JSON_VALUE(o.orden_obj_origen, '$.orderId') + '",
                "F311_ID_TERCERO_VENDEDOR": "' + ISNULL((
								SELECT TOP 1 f200_id 
								FROM #VendedoresERP 
								WHERE f210_id = ISNULL(JSON_VALUE(o.orden_obj_origen, '$.marketingData.utmiCampaign'),'9999')
							),'9999') +'"
              }],
              "Movimiento": [{
                "F350_CONSEC_DOCTO": "1",
                "F320_ROWID": "1",
                "F320_ID_CCOSTO_MOVTO": "",
                "F320_ID_TERCERO_MOVTO": "' + JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') + '",
                "F320_CANTIDAD": "1",
                "F320_VLR_BRUTO": "' + CASE 
                        WHEN LEN(JSON_VALUE(o.orden_obj_origen, '$.value')) > 2 
                        THEN LEFT(JSON_VALUE(o.orden_obj_origen, '$.value'), LEN(JSON_VALUE(o.orden_obj_origen, '$.value')) - 2)
                        ELSE '0'
                    END + '",
                "F320_NOTAS": "Pedido: ' + JSON_VALUE(o.orden_obj_origen, '$.orderId') + '"
              }],
              "CXC": [{
                "F350_CONSEC_DOCTO": "1",
                "F353_ID_TIPO_DOCTO_CRUCE": "",
                "F353_CONSEC_DOCTO_CRUCE": "0",
                "F353_NRO_CUOTA_CRUCE": "0",
                "F353_VLR_CRUCE": "' + CASE 
                        WHEN LEN(JSON_VALUE(o.orden_obj_origen, '$.value')) > 2 
                        THEN LEFT(JSON_VALUE(o.orden_obj_origen, '$.value'), LEN(JSON_VALUE(o.orden_obj_origen, '$.value')) - 2)
                        ELSE '0'
                    END + '",
                "F_PORCENTAJE_CUOTA": "0",
                "F353_FECHA_VCTO": "' + CONVERT(VARCHAR(8), EOMONTH(GETDATE()), 112) + '",
                "F353_VLR__DSCTO_PP": "0",
                "F_PORCENTAJE_PP": "0",
                "F353_FECHA_DSCTO_PP": "' + CONVERT(VARCHAR(8), EOMONTH(GETDATE()), 112) + '"
              }]
            }')
        ELSE
            JSON_QUERY('{
                "Inicial": [{"F_CIA": "001"}],
                "OtrosIngresos": [{
                    "F_CIA": "001",
                    "F350_ID_CO": "010",
                    "F350_ID_TIPO_DOCTO": "RCA",
                    "F350_CONSEC_DOCTO": "1",
                    "F350_FECHA": "' + CONVERT(VARCHAR(8), GETDATE(), 112) + '",
                    "F357_ID_CAJA": "001",
                    "F357_FECHA_RECAUDO": "' + CONVERT(VARCHAR(8), GETDATE(), 112) + '",
                    "F350_ID_TERCERO": "' + CASE 
						   WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' 
						  THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END + '",
                    "F357_ID_MONEDA_INGRESO": "COP",
                    "F357_VALOR_INGRESO": "' + CASE 
                        WHEN LEN(JSON_VALUE(o.orden_obj_origen, '$.value')) > 2 
                        THEN LEFT(JSON_VALUE(o.orden_obj_origen, '$.value'), LEN(JSON_VALUE(o.orden_obj_origen, '$.value')) - 2)
                        ELSE '0'
                    END + '",
                    "F357_ID_COBRADOR": "' + ISNULL((
								SELECT TOP 1 f210_id 
								FROM #VendedoresERP 
								WHERE f210_id = ISNULL(JSON_VALUE(o.orden_obj_origen, '$.marketingData.utmiCampaign'),'9999')
							),'9999') +'",
                    "F357_ID_UN": "99",
                    "F357_ID_FE": "1102",
                    "F350_NOTAS": "Secuencia Pedido: ' + JSON_VALUE(o.orden_obj_origen, '$.sequence') + '",
                    "F351_ID_AUXILIAR_OTRO_ING": "280505",
                    "F351_ID_TERCERO_OTRO_ING": "' + CASE 
						   WHEN ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument'), '') = '' 
						  THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document')
						  ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument') 
						END + '",
                    "F351_ID_SUCURSAL_OTRO_ING": "001",
                    "F351_ID_CO_OTRO_ING": "010",
                    "F351_ID_UN_OTRO_ING": "99",
                    "F357_REFERENCIA": "' + JSON_VALUE(o.orden_obj_origen, '$.orderId') + '"
                }],
                "Caja": [{
                    "F_CIA": "001",
                    "F350_ID_CO": "010",
                    "F350_ID_TIPO_DOCTO": "RCA",
                    "F350_CONSEC_DOCTO": "1",
                    "F358_ID_MEDIOS_PAGO": "WEB",
                    "F358_VALOR": "' + CASE 
                        WHEN LEN(JSON_VALUE(o.orden_obj_origen, '$.value')) > 2 
                        THEN LEFT(JSON_VALUE(o.orden_obj_origen, '$.value'), LEN(JSON_VALUE(o.orden_obj_origen, '$.value')) - 2)
                        ELSE '0'
                    END + '",
                    "F358_REFERENCIA_OTROS": "VTX",
                    "F358_FECHA_CONSIGNACION": "' + CONVERT(VARCHAR(8), GETDATE(), 112) + '",
                    "f358_nro_alt_docto_banco": "",
                    "f358_docto_banco_cg": "CG"
                }],
                "Final": [{"F_CIA": "001"}]
            }')
    END
FROM ordenes o
INNER JOIN #tempOrdenes tmp ON o.id = tmp.id
WHERE o.id_tienda = 1
--  AND ISNULL(o.endpoint, '') NOT IN (@endpointAnticipo, @endpointServicio)