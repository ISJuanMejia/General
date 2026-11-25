UPDATE o
SET orden_obj_destino = 
'{
    "type": "Output",
    "invoiceNumber": "' + f350_id_co + '-' + f350_id_tipo_docto + '-' + RTRIM(LTRIM(CONVERT(CHAR, f350_consec_docto))) + '",
    "invoiceValue": ' + JSON_VALUE(o.orden_obj_origen, '$.value') + ',
    "issuanceDate": "' + CONVERT(VARCHAR, f350_fecha, 23) + '",
    "trackingNumber": "' + ISNULL(g.remision, '') + '",
    "trackingUrl": "' + CASE WHEN g.remision IS NULL THEN '' ELSE 'https://www.coordinadora.com/portafolio-de-servicios/servicios-en-linea/rastrear-guias/' END + '",
    "courier": "' + ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany'), '') + '",
    "items": [' + ISNULL(json_items.items_json, '') + ']
}'
FROM ordenes o
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.[t430_cm_pv_docto] 
    ON f430_num_docto_referencia = '0' + CAST(id_tienda AS NVARCHAR) + ' ' + JSON_VALUE(orden_obj_origen, '$.sequence')
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.[t460_cm_docto_remision_venta] 
    ON f430_rowid = f460_rowid_pv_docto
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.[t461_cm_docto_factura_venta] 
    ON f461_rowid_docto = f460_rowid_docto_factura
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.[t350_co_docto_contable] 
    ON f350_rowid = f461_rowid_docto
LEFT JOIN guias_transportadoras g 
    ON o.id = g.id_orden
OUTER APPLY (
    SELECT 
        STUFF((
            SELECT 
                ',{"id":"' + JSON_VALUE(item.value, '$.id') + '",' +
                '"price":' + 
                CASE 
                    WHEN ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) = 1 THEN 
                        CAST(
                            CAST(JSON_VALUE(item.value, '$.sellingPrice') AS INT) + 
                            ISNULL(CAST(JSON_VALUE(o.orden_obj_origen, '$.totals[2].value') AS INT), 0)
                        AS NVARCHAR)
                    ELSE 
                        CAST(CAST(JSON_VALUE(item.value, '$.sellingPrice') AS INT) AS NVARCHAR)
                END + ',' +
                '"quantity":' + JSON_VALUE(item.value, '$.quantity') + '}'
            FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
            ORDER BY (SELECT NULL) -- importante para garantizar ROW_NUMBER consistente
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS items_json
) AS json_items
WHERE 
    o.id_estado = 6
    AND o.id_tienda = 2
    AND o.intentos <= 3
    AND ISNULL(o.orden_obj_destino, '') = '';
