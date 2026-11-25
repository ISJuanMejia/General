DECLARE @endpoint NVARCHAR(500) = 'http://localhost:82/v3.1/conectoresimportar?idCompania=6230&idSistema=2&idDocumento=205745&nombreDocumento=ENTIDADES_PEDIDO_INTEGRACION';

-- =========================================================================
-- PASO 1: Filtrar localmente las órdenes candidatas y extraer campos JSON
-- =========================================================================
IF OBJECT_ID('tempdb..#OrdenBaseSpeedo') IS NOT NULL DROP TABLE #OrdenBaseSpeedo;

CREATE TABLE #OrdenBaseSpeedo (
    id INT PRIMARY KEY CLUSTERED, -- Índice ultra rápido
    CodigoReferencia NVARCHAR(200),
    Origin NVARCHAR(100),
    PasarelaId NVARCHAR(200)
);

INSERT INTO #OrdenBaseSpeedo (id, CodigoReferencia, Origin, PasarelaId)
SELECT 
    o.id,
    '0' + CAST(o.id_tienda AS NVARCHAR(10)) + ' ' + JSON_VALUE(o.orden_obj_origen, '$.sequence'),
    JSON_VALUE(o.orden_obj_origen, '$.origin'),
    ISNULL(JSON_VALUE(o.orden_obj_origen, '$.paymentData.transactions[0].payments[0].id'), '')
FROM ordenes o
WHERE O.fecha_creacion >= DATEADD(day, -30, GETDATE())
	AND o.id_tienda = 1 
  AND o.id_estado = 7 
  AND o.orden_obj_destino IS NULL;

-- Crear índice secundario para acelerar el cruce con el Linked Server
CREATE NONCLUSTERED INDEX IX_#OrdenBaseSpeedo_Ref ON #OrdenBaseSpeedo(CodigoReferencia);


-- =========================================================================
-- PASO 2: Obtener solo las guías necesarias y poblar #EntidadesSpeedo
-- =========================================================================
IF OBJECT_ID('tempdb..#GuiasFiltradasSpeedo') IS NOT NULL DROP TABLE #GuiasFiltradasSpeedo;

-- Filtramos las guías asociadas ÚNICAMENTE a nuestros IDs para evitar el escaneo masivo
SELECT id_orden, remision
INTO #GuiasFiltradasSpeedo
FROM guias_transportadoras
WHERE fecha_creacion >= DATEADD(day, -30, GETDATE())
AND id_orden IN (SELECT id FROM #OrdenBaseSpeedo);

-- Crear índice rápido
CREATE CLUSTERED INDEX IX_#GuiasFiltradasSpeedo_id ON #GuiasFiltradasSpeedo(id_orden);


IF OBJECT_ID('tempdb..#EntidadesSpeedo') IS NOT NULL DROP TABLE #EntidadesSpeedo;

CREATE TABLE #EntidadesSpeedo (
    id INT,
    f350_id_co VARCHAR(10),
    f350_id_tipo_docto VARCHAR(10),
    f350_consec_docto INT,
    f753_id_atributo VARCHAR(50),
    f753_dato_texto NVARCHAR(MAX),
    PRIMARY KEY CLUSTERED (id, f753_id_atributo) 
);

INSERT INTO #EntidadesSpeedo (id, f350_id_co, f350_id_tipo_docto, f350_consec_docto, f753_id_atributo, f753_dato_texto)
SELECT 
    du.id,
    du.f350_id_co,
    du.f350_id_tipo_docto,
    du.f350_consec_docto,
    unpvt.f753_id_atributo,
    unpvt.f753_dato_texto
FROM (
    SELECT 
        ob.id,
        t.f430_id_co AS f350_id_co,
        t.f430_id_tipo_docto AS f350_id_tipo_docto,
        t.f430_consec_docto AS f350_consec_docto,
        ob.Origin,
        ob.PasarelaId,
        ISNULL(tr.remision, '') AS Remision
    FROM #OrdenBaseSpeedo ob
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t430_cm_pv_docto t
        ON t.f430_id_fecha >= DATEADD(day, -30, GETDATE()) AND t.f430_num_docto_referencia = ob.CodigoReferencia
    LEFT JOIN #GuiasFiltradasSpeedo tr -- 👈 Ahora cruzamos contra la temporal pequeña
        ON ob.id = tr.id_orden
) du
CROSS APPLY (
    VALUES 
        ('Market_Place',  du.Origin),
        ('Transportadora', 'Coordinadora'),
        ('Nro_Guia',       du.Remision),
        ('Pasarela',       du.PasarelaId)
) AS unpvt(f753_id_atributo, f753_dato_texto);


-- =========================================================================
-- PASO 3: UPDATE Quirúrgico utilizando el formato JSON construido
-- =========================================================================

UPDATE o
SET o.orden_obj_destino = 
    '{ "EntidadesDinamicas": ' + 
        ISNULL((
            SELECT 
                e.f350_id_co, 
                e.f350_id_tipo_docto, 
                e.f350_consec_docto, 
                e.f753_id_atributo, 
                e.f753_dato_texto
            FROM #EntidadesSpeedo e
            WHERE e.id = o.id
            FOR JSON PATH, INCLUDE_NULL_VALUES
        ), '[]') + 
    '}',
    o.endpoint = @endpoint
FROM ordenes o
WHERE o.fecha_creacion >= DATEADD(day, -30, GETDATE())
	AND o.id_tienda = 1 
  AND o.id_estado = 7
  AND o.orden_obj_destino IS NULL
  AND ISNULL(@endpoint, '') != '';


-- Limpieza
DROP TABLE #OrdenBaseSpeedo;
DROP TABLE #EntidadesSpeedo;