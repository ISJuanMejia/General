/* =========================================================================================
   PROYECTO: VTEX ESTÁNDAR V2
   PROCESO: 08. CAMBIO DE ESTADO INVOICED
   TABLA DESTINO: dbo.ordenes (columna orden_obj_destino)
   DESCRIPCIÓN: Detecta órdenes facturadas en el ERP, cruza remisiones y guías de transporte,
                y genera el payload JSON estándar para el API de Facturación de VTEX
                (/api/oms/pvt/orders/{orderId}/invoice).
   ========================================================================================= */

SET NOCOUNT ON;

DECLARE @id_tienda INT = 1;
DECLARE @id_cia    INT = 1;

UPDATE o
SET 
    o.orden_obj_destino = (
        SELECT
            [type]           = 'Output',
            [invoiceNumber]  = CONCAT(f350.f350_id_co, '-', f350.f350_id_tipo_docto, '-', RTRIM(LTRIM(CONVERT(CHAR, f350.f350_consec_docto)))),
            [invoiceValue]   = CAST(JSON_VALUE(o.orden_obj_origen, '$.value') AS INT),
            [issuanceDate]   = CONVERT(VARCHAR, f350.f350_fecha, 23),
            [trackingNumber] = ISNULL(g.remision, ''),
            [trackingUrl]    = CASE 
                                   WHEN g.remision IS NOT NULL THEN 'https://www.coordinadora.com/portafolio-de-servicios/servicios-en-linea/rastrear-guias/' 
                                   ELSE '' 
                               END,
            [courier]        = ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany'), 'Coordinadora'),
            [items]          = (
                SELECT
                    [id]       = JSON_VALUE(item.value, '$.id'),
                    [price]    = CAST(JSON_VALUE(item.value, '$.sellingPrice') AS INT),
                    [quantity] = CAST(JSON_VALUE(item.value, '$.quantity') AS INT)
                FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
                FOR JSON PATH
            )
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ),
    o.sincronizado = 0
FROM [dbo].[ordenes] o
INNER JOIN [UnoEE_ERP].[dbo].[t430_cm_pv_docto] f430 
    ON f430.f430_num_docto_referencia = CONCAT('0', CAST(o.id_tienda AS VARCHAR), ' ', JSON_VALUE(o.orden_obj_origen, '$.sequence'))
   AND f430.f430_id_cia = @id_cia
INNER JOIN [UnoEE_ERP].[dbo].[t460_cm_docto_remision_venta] f460 
    ON f460.f460_rowid_pv_docto = f430.f430_rowid
INNER JOIN [UnoEE_ERP].[dbo].[t461_cm_docto_factura_venta] f461 
    ON f461.f461_rowid_docto = f460.f460_rowid_docto_factura
INNER JOIN [UnoEE_ERP].[dbo].[t350_co_docto_contable] f350 
    ON f350.f350_rowid = f461.f461_rowid_docto
LEFT JOIN [dbo].[guias_transportadoras] g 
    ON g.id_orden = o.id
WHERE o.id_tienda = @id_tienda
  AND o.id_estado = 6 -- Estado facturación pendiente
  AND o.intentos <= 3
  AND (o.orden_obj_destino IS NULL OR o.orden_obj_destino = '');
