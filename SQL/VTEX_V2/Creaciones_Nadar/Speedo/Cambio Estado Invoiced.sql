SET NOCOUNT ON;

-- ==========================================
-- 0. LIMPIEZA PREVIA DE TABLAS TEMPORALES
-- ==========================================
IF OBJECT_ID('tempdb..#OrdenesCandidatasSpeedo') IS NOT NULL DROP TABLE #OrdenesCandidatasSpeedo;
IF OBJECT_ID('tempdb..#DatosSiesaSpeedo') IS NOT NULL DROP TABLE #DatosSiesaSpeedo;
IF OBJECT_ID('tempdb..#ResultadosJSONSpeedo') IS NOT NULL DROP TABLE #ResultadosJSONSpeedo;

-- ==========================================
-- 1. AISLAR EL UNIVERSO DE TRABAJO (Últimos 30 días)
-- ==========================================
CREATE TABLE #OrdenesCandidatasSpeedo (
    id INT PRIMARY KEY CLUSTERED, 
    CodigoReferencia NVARCHAR(150) NOT NULL,
    orden_obj_origen NVARCHAR(MAX),
    INDEX IX_OrdenesCandidatasSpeedo_Ref (CodigoReferencia) 
);

INSERT INTO #OrdenesCandidatasSpeedo (id, CodigoReferencia, orden_obj_origen)
SELECT 
    id,
    '0' + CAST(id_tienda AS NVARCHAR(10)) + ' ' + JSON_VALUE(orden_obj_origen, '$.sequence'),
    orden_obj_origen
FROM ordenes
WHERE id_estado = 6
  AND id_tienda = 1
  AND intentos <= 3
  AND (orden_obj_destino IS NULL OR orden_obj_destino = '')
  AND fecha_creacion >= DATEADD(day, -30, GETDATE());


-- ==========================================
-- 2. TRAER LOS DATOS DEL LINKED SERVER A TABLA LOCAL
-- ==========================================
CREATE TABLE #DatosSiesaSpeedo (
    CodigoReferencia NVARCHAR(150) PRIMARY KEY CLUSTERED,
    f350_id_co NVARCHAR(20),
    f350_id_tipo_docto NVARCHAR(20),
    f350_consec_docto INT,
    f350_fecha DATETIME
);

INSERT INTO #DatosSiesaSpeedo (CodigoReferencia, f350_id_co, f350_id_tipo_docto, f350_consec_docto, f350_fecha)
SELECT 
    oc.CodigoReferencia,
    t350.f350_id_co,
    t350.f350_id_tipo_docto,
    t350.f350_consec_docto,
    t350.f350_fecha
FROM #OrdenesCandidatasSpeedo oc
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.[t430_cm_pv_docto] t430 
    ON t430.f430_id_fecha >= DATEADD(YEAR, -1, GETDATE())  
   AND t430.f430_num_docto_referencia = oc.CodigoReferencia
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.[t460_cm_docto_remision_venta] t460 
    ON t460.f460_id_fecha >= DATEADD(YEAR, -1, GETDATE())
   AND t430.f430_rowid = t460.f460_rowid_pv_docto
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.[t461_cm_docto_factura_venta] t461 
    ON t461.f461_id_fecha >= DATEADD(YEAR, -1, GETDATE())
   AND t461.f461_rowid_docto = t460.f460_rowid_docto_factura
INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.[t350_co_docto_contable] t350 
    ON t350.f350_fecha >= DATEADD(YEAR, -1, GETDATE())
   AND t350.f350_rowid = t461.f461_rowid_docto;


-- ==========================================
-- 3. CONSTRUIR LOS JSON FINALES
-- ==========================================
CREATE TABLE #ResultadosJSONSpeedo (
    id INT PRIMARY KEY CLUSTERED,
    NuevoJsonDestino NVARCHAR(MAX)
);

WITH ItemsParseados AS (
    SELECT 
        oc.id,
        item.ItemId,
        item.SellingPrice,
        item.Quantity,
        ISNULL(CAST(JSON_VALUE(oc.orden_obj_origen, '$.totals[2].value') AS INT), 0) AS ShippingValue,
        ROW_NUMBER() OVER (PARTITION BY oc.id ORDER BY (SELECT NULL)) AS RowNum
    FROM #OrdenesCandidatasSpeedo oc
    CROSS APPLY OPENJSON(oc.orden_obj_origen, '$.items') 
    WITH (
        ItemId NVARCHAR(150) '$.id',
        SellingPrice INT '$.sellingPrice',
        Quantity INT '$.quantity'
    ) AS item
),
ItemsAgrupados AS (
    SELECT 
        id,
        STRING_AGG(
            '{"id":"' + ItemId + '",' +
            '"price":' + CAST(CASE WHEN RowNum = 1 THEN SellingPrice + ShippingValue ELSE SellingPrice END AS NVARCHAR(20)) + ',' +
            '"quantity":' + CAST(Quantity AS NVARCHAR(10)) + '}',
            ','
        ) AS items_json
    FROM ItemsParseados
    GROUP BY id
)
INSERT INTO #ResultadosJSONSpeedo (id, NuevoJsonDestino)
SELECT 
    oc.id,
    '{' +
    '"type": "Output",' +
    '"invoiceNumber": "' + s.f350_id_co + '-' + s.f350_id_tipo_docto + '-' + RTRIM(LTRIM(CONVERT(CHAR, s.f350_consec_docto))) + '",' +
    '"invoiceValue": ' + JSON_VALUE(oc.orden_obj_origen, '$.value') + ',' +
    '"issuanceDate": "' + CONVERT(VARCHAR, s.f350_fecha, 23) + '",' +
    '"trackingNumber": "' + ISNULL(g.remision, '') + '",' +
    '"trackingUrl": "' + CASE WHEN g.remision IS NULL THEN '' ELSE 'https://www.coordinadora.com/portafolio-de-servicios/servicios-en-linea/rastrear-guias/' END + '",' +
    '"courier": "' + ISNULL(JSON_VALUE(oc.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany'), '') + '",' +
    '"items": [' + ISNULL(ia.items_json, '') + ']' +
    '}'
FROM #OrdenesCandidatasSpeedo oc
INNER JOIN #DatosSiesaSpeedo s ON oc.CodigoReferencia = s.CodigoReferencia
LEFT JOIN guias_transportadoras g ON oc.id = g.id_orden
LEFT JOIN ItemsAgrupados ia ON oc.id = ia.id;


-- ==========================================
-- 4. ACTUALIZACIÓN DEFINITIVA
-- ==========================================
UPDATE o
SET o.orden_obj_destino = r.NuevoJsonDestino
FROM ordenes o
INNER JOIN #ResultadosJSONSpeedo r ON o.id = r.id
WHERE o.fecha_creacion >= DATEADD(day, -30, GETDATE());


-- ==========================================
-- 5. LIMPIEZA FINAL
-- ==========================================
IF OBJECT_ID('tempdb..#OrdenesCandidatasSpeedo') IS NOT NULL DROP TABLE #OrdenesCandidatasSpeedo;
IF OBJECT_ID('tempdb..#DatosSiesaSpeedo') IS NOT NULL DROP TABLE #DatosSiesaSpeedo;
IF OBJECT_ID('tempdb..#ResultadosJSONSpeedo') IS NOT NULL DROP TABLE #ResultadosJSONSpeedo;