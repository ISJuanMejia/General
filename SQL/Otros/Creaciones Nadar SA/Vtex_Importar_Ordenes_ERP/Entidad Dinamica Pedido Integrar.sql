DECLARE @endpoint NVARCHAR(500) = 'http://localhost:82/v3.1/conectoresimportar?idCompania=6230&idSistema=2&idDocumento=205745&nombreDocumento=ENTIDADES_PEDIDO_INTEGRACION';

-- Limpiar si existe
IF OBJECT_ID('tempdb..#Entidades') IS NOT NULL
    DROP TABLE #Entidades;

CREATE TABLE #Entidades (
    id INT,
    f350_id_co VARCHAR(10),
    f350_id_tipo_docto VARCHAR(10),
    f350_consec_docto INT,
    f753_id_atributo VARCHAR(50),
    f753_dato_texto NVARCHAR(MAX)
);

-- Insertar los valores con UNION ALL
INSERT INTO #Entidades
SELECT 
    o.id,
    t.f430_id_co AS f350_id_co,
    t.f430_id_tipo_docto AS f350_id_tipo_docto,
    t.f430_consec_docto AS f350_consec_docto,
    'Market_Place' AS f753_id_atributo, 
    JSON_VALUE(o.orden_obj_origen, '$.origin') AS f753_dato_texto
FROM ordenes o
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t430_cm_pv_docto t
    ON t.f430_num_docto_referencia = '0' + CAST(o.id_tienda AS NVARCHAR) + ' ' + JSON_VALUE(o.orden_obj_origen, '$.sequence')
LEFT JOIN guias_transportadoras tr ON o.id = tr.id_orden
WHERE o.id_tienda = 1 AND o.id_estado = 7 AND o.orden_obj_destino IS NULL

UNION ALL

SELECT 
    o.id,
    t.f430_id_co AS f350_id_co,
    t.f430_id_tipo_docto AS f350_id_tipo_docto,
    t.f430_consec_docto AS f350_consec_docto,
    'Transportadora' AS f753_id_atributo, 
    'Coordinadora' AS f753_dato_texto
FROM ordenes o
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t430_cm_pv_docto t
    ON t.f430_num_docto_referencia = '0' + CAST(o.id_tienda AS NVARCHAR) + ' ' + JSON_VALUE(o.orden_obj_origen, '$.sequence')
LEFT JOIN guias_transportadoras tr ON o.id = tr.id_orden
WHERE o.id_tienda = 1 AND o.id_estado = 7 AND o.orden_obj_destino IS NULL

UNION ALL

SELECT 
    o.id,
    t.f430_id_co AS f350_id_co,
    t.f430_id_tipo_docto AS f350_id_tipo_docto,
    t.f430_consec_docto AS f350_consec_docto,
    'Nro_Guia' AS f753_id_atributo, 
    ISNULL(tr.remision, '') AS f753_dato_texto
FROM ordenes o
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t430_cm_pv_docto t
    ON t.f430_num_docto_referencia = '0' + CAST(o.id_tienda AS NVARCHAR) + ' ' + JSON_VALUE(o.orden_obj_origen, '$.sequence')
LEFT JOIN guias_transportadoras tr ON o.id = tr.id_orden
WHERE o.id_tienda = 1 AND o.id_estado = 7 AND o.orden_obj_destino IS NULL

UNION ALL

SELECT 
    o.id,
    t.f430_id_co AS f350_id_co ,
    t.f430_id_tipo_docto AS f350_id_tipo_docto,
    t.f430_consec_docto AS f350_consec_docto,
    'Pasarela' AS f753_id_atributo, 
    ISNULL(JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].id'),'') AS f753_dato_texto
FROM ordenes o
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t430_cm_pv_docto t
    ON t.f430_num_docto_referencia = '0' + CAST(o.id_tienda AS NVARCHAR) + ' ' + JSON_VALUE(o.orden_obj_origen, '$.sequence')
LEFT JOIN guias_transportadoras tr ON o.id = tr.id_orden
WHERE o.id_tienda = 1 AND o.id_estado = 7 AND o.orden_obj_destino IS NULL;

UPDATE o
SET o.orden_obj_destino = 
    '{
        "EntidadesDinamicas": ' + ISNULL((
            SELECT 
                f350_id_co, 
                f350_id_tipo_docto, 
                f350_consec_docto, 
                f753_id_atributo, 
                f753_dato_texto
            FROM #Entidades e
            WHERE e.id = o.id
            FOR JSON PATH, INCLUDE_NULL_VALUES
        ), '[]') + '
    }',
endpoint = @endpoint
FROM ordenes o
WHERE o.id_tienda = 1 
    AND o.id_estado = 7
    AND o.orden_obj_destino IS NULL
    AND ISNULL(@endpoint, '') != '';