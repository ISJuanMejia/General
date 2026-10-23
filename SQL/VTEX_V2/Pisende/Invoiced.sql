UPDATE o
SET orden_obj_destino =
    '{
        "type": "Output",
        "invoiceNumber": "' + remote_ERP.f350_id_co + '-' + remote_ERP.f350_id_tipo_docto + '-' + RTRIM(LTRIM(CONVERT(CHAR, remote_ERP.f350_consec_docto))) + '",
        "invoiceValue": ' + JSON_VALUE(o.orden_obj_origen, '$.value') + ',
        "issuanceDate": "' + CONVERT(VARCHAR, remote_ERP.f350_fecha, 23) + '",
        "trackingNumber": "''",
        "trackingUrl": "''",
        "courier": "''",
        "items": [' + (
            SELECT 
                STUFF((
                    SELECT 
                        ',{"id":"' + JSON_VALUE(item.value, '$.id') + '",' +
                        '"price":' + 
                        CASE 
                            WHEN ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) = 1 THEN 
                                CAST(CAST(JSON_VALUE(item.value, '$.sellingPrice') AS INT) + 
                                     CAST(JSON_VALUE(o.orden_obj_origen, '$.totals[2].value') AS INT) AS NVARCHAR)
                            ELSE 
                                CAST(CAST(JSON_VALUE(item.value, '$.sellingPrice') AS INT) AS NVARCHAR)
                        END + ',' +
                        '"quantity":' + JSON_VALUE(item.value, '$.quantity') + '}'
                    FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 1, '')
        ) + ']
    }'
FROM ordenes o
INNER JOIN (
    SELECT 
        f430_rowid,
        f430_num_docto_referencia,
        f350_id_co,
        f350_id_tipo_docto,
        f350_consec_docto,
        f350_fecha
    FROM OPENROWSET(
        'SQLNCLI',
        'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=Pisende;Pwd=Pisende$12$%;',
        '
         SELECT 
             t430.f430_rowid AS f430_rowid,
             t430.f430_num_docto_referencia AS f430_num_docto_referencia,
             t350.f350_id_co AS f350_id_co,
             t350.f350_id_tipo_docto AS f350_id_tipo_docto,
             t350.f350_consec_docto AS f350_consec_docto,
             t350.f350_fecha AS f350_fecha
         FROM dbo.t430_cm_pv_docto t430
         INNER JOIN dbo.t460_cm_docto_remision_venta t460 ON t430.f430_rowid = t460.f460_rowid_pv_docto
         INNER JOIN dbo.t461_cm_docto_factura_venta t461 ON t461.f461_rowid_docto = t460.f460_rowid_docto_factura
         INNER JOIN dbo.t350_co_docto_contable t350 ON t350.f350_rowid = t461.f461_rowid_docto
		 WHERE t350.f350_id_co = ''010'' AND t350.f350_id_tipo_docto = ''FEV''
        '
    ) AS remote_data
) AS remote_ERP 
    ON (
        CASE 
            WHEN LEN(REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-', '')) <= 15 
            THEN REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-', '') 
            ELSE JSON_VALUE(o.orden_obj_origen, '$.sequence') 
        END
    ) = remote_ERP.f430_num_docto_referencia
WHERE 
    o.id_estado = 7
	AND o.id_tienda = 1
    AND o.intentos <= 3
    AND ISNULL(o.orden_obj_destino, '') = '';