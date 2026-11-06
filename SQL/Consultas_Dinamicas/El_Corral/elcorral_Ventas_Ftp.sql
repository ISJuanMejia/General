DECLARE @id_cliente_pdv           VARCHAR(20)  = '-1';
DECLARE @fecha_ts_actualizacion   VARCHAR(14)  = '-1';  -- Formato ISO: AAAAMMDDHHMMSS. Comodín: -1
DECLARE @id_co                    VARCHAR(20)  = '-1';
--DECLARE @nrodocto INT  = '134386'

SET @id_cliente_pdv = RTRIM(@id_cliente_pdv);
SET @id_co          = RTRIM(@id_co);

DECLARE @fecha_ts_actualizacion_dt DATETIME;

IF @fecha_ts_actualizacion <> '-1'
BEGIN

    IF LEN(@fecha_ts_actualizacion) <> 14 OR @fecha_ts_actualizacion NOT LIKE REPLICATE('[0-9]', 14)
        RAISERROR('El parámetro @fecha_ts_actualizacion debe tener formato AAAAMMDDHHMMSS o el comodín -1.', 16, 1);

    DECLARE @anio  SMALLINT = CAST(SUBSTRING(@fecha_ts_actualizacion,  1, 4) AS SMALLINT);
    DECLARE @mes   TINYINT  = CAST(SUBSTRING(@fecha_ts_actualizacion,  5, 2) AS TINYINT);
    DECLARE @dia   TINYINT  = CAST(SUBSTRING(@fecha_ts_actualizacion,  7, 2) AS TINYINT);
    DECLARE @hora  TINYINT  = CAST(SUBSTRING(@fecha_ts_actualizacion,  9, 2) AS TINYINT);
    DECLARE @min   TINYINT  = CAST(SUBSTRING(@fecha_ts_actualizacion, 11, 2) AS TINYINT);
    DECLARE @seg   TINYINT  = CAST(SUBSTRING(@fecha_ts_actualizacion, 13, 2) AS TINYINT);

    IF @mes  NOT BETWEEN 1  AND 12 OR
       @dia  NOT BETWEEN 1  AND 31 OR
       @hora NOT BETWEEN 0  AND 23 OR
       @min  NOT BETWEEN 0  AND 59 OR
       @seg  NOT BETWEEN 0  AND 59
        RAISERROR('El parámetro @fecha_ts_actualizacion contiene componentes de fecha/hora fuera de rango.', 16, 1);

    SET @fecha_ts_actualizacion_dt = TRY_CONVERT(DATETIME,
            CAST(@anio AS VARCHAR) + '-' + RIGHT('0' + CAST(@mes AS VARCHAR), 2) + '-' +
            RIGHT('0' + CAST(@dia AS VARCHAR), 2) + ' ' +
            RIGHT('0' + CAST(@hora AS VARCHAR), 2) + ':' +
            RIGHT('0' + CAST(@min  AS VARCHAR), 2) + ':' +
            RIGHT('0' + CAST(@seg  AS VARCHAR), 2), 120);

    IF @fecha_ts_actualizacion_dt IS NULL
        RAISERROR('El parámetro @fecha_ts_actualizacion no representa una fecha/hora válida (ej. día 31 en un mes de 30 días).', 16, 1);
END;

DECLARE @fecha_desde DATETIME =
    CASE
        WHEN @fecha_ts_actualizacion_dt IS NULL
            THEN DATEADD(DAY, -3, GETDATE())
        ELSE @fecha_ts_actualizacion_dt
    END;

-- Límite inferior indexado sobre id_fecha_docto (con 1 día de holgura para cierres nocturnos)
DECLARE @fecha_docto_min DATETIME = DATEADD(DAY, DATEDIFF(DAY, 0, @fecha_desde) - 1, 0);

DROP TABLE IF EXISTS #candidatos_9920;
DROP TABLE IF EXISTS #documentos;
DROP TABLE IF EXISTS #documentos_claves;
DROP TABLE IF EXISTS #pagos_detalle;
DROP TABLE IF EXISTS #pagos;

-- Pre-filtrado 100% cubierto en IX_t9920_4 (f9920_id_cliente_pdv, f9920_id_fecha_docto -> f9920_guid)
-- Evita millones de Key Lookups sobre los 121.7M de registros de t9920_pdv_a_doctos
SELECT
    t9920.f9920_guid AS guid_docto
INTO #candidatos_9920
FROM t9741_pdv_criterios_clientes criterio WITH (NOLOCK)
INNER JOIN t9920_pdv_a_doctos t9920 WITH (NOLOCK, INDEX(IX_t9920_4))
    ON t9920.f9920_id_cliente_pdv = criterio.f9741_id_cliente_pdv
   AND t9920.f9920_id_fecha_docto >= @fecha_docto_min
WHERE criterio.f9741_id_cia = 1
  AND criterio.f9741_id_criterio_mayor = '0004'
  AND criterio.f9741_id_plan_criterios = 'PDV'
  AND (
         @id_cliente_pdv = '-1'
      OR criterio.f9741_id_cliente_pdv = @id_cliente_pdv
  )
OPTION (RECOMPILE);

CREATE UNIQUE CLUSTERED INDEX IX_cand_9920 ON #candidatos_9920 (guid_docto);

SELECT
     CAST('D' AS CHAR(1)) AS origen
    ,t9820.f9820_guid AS guid_docto
    ,t9820.f9820_id_cia AS id_cia

    ,RTRIM(t9740.f9740_id) AS id_cliente_pdv
    ,t9820.f9820_fecha_ts_actualizacion AS fecha_ultima_actualizacion
    ,t9820.f9820_id_fecha_docto AS fecha_docto
    ,RTRIM(t010.f010_razon_social) AS razon_social_cia
    ,RTRIM(t9820.f9820_id_co) AS id_co
    ,RTRIM(t9820.f9820_id_tipo_docto) AS id_tipo_docto
    ,t9820.f9820_consec_docto AS consecutivo_docto
    ,t9820.f9820_valor_bruto AS valor_bruto
    ,t9820.f9820_valor_imp AS valor_imp

    ,t9820.f9820_valor_dscto_global
        + t9820.f9820_valor_dscto_linea AS valor_dsctos

    ,t9820.f9820_valor_neto AS valor_neto

    ,CASE
        WHEN LEFT(t9750.f9750_id, 1) IN ('C', 'D', 'H', 'P')
            THEN 'EL Corral'

        WHEN LEFT(t9750.f9750_id, 1) = 'G'
            THEN 'El Corral Gourmet'

        WHEN LEFT(t9750.f9750_id, 1) = 'E'
            THEN 'EVOK'

        WHEN LEFT(t9750.f9750_id, 1) = 'B'
            THEN 'Beer Station'

        ELSE 'Otros'
     END AS marca

    ,t9757.f9757_id AS Tipo_Entrega

INTO #documentos

FROM t9740_pdv_clientes t9740 WITH (NOLOCK)

INNER JOIN t010_mm_companias t010 WITH (NOLOCK)
    ON t010.f010_id = t9740.f9740_id_cia

INNER JOIN t9820_pdv_d_doctos t9820 WITH (NOLOCK)
    ON t9820.f9820_id_cia = t9740.f9740_id_cia
   AND t9820.f9820_id_cliente_pdv = t9740.f9740_id

INNER JOIN t9750_pdv_tpv t9750 WITH (NOLOCK)
    ON t9750.f9750_rowid = t9820.f9820_rowid_tpv
    --AND t9820.f9820_consec_docto = @nrodocto

LEFT JOIN t9757_pdv_tipos_entrega t9757 WITH (NOLOCK)
    ON t9757.f9757_rowid = t9820.f9820_rowid_tipo_entrega

WHERE t9740.f9740_id_cia = 1
AND EXISTS
(
    SELECT 1
    FROM t9741_pdv_criterios_clientes criterio WITH (NOLOCK)
    WHERE criterio.f9741_id_cia = t9740.f9740_id_cia
      AND criterio.f9741_id_cliente_pdv = t9740.f9740_id
      AND criterio.f9741_id_criterio_mayor = '0004'
      AND criterio.f9741_id_plan_criterios = 'PDV'
)
AND
(
       @id_cliente_pdv = '-1'
    OR t9740.f9740_id = @id_cliente_pdv
)
AND t9820.f9820_id_fecha_docto >= @fecha_docto_min
AND t9820.f9820_fecha_ts_actualizacion >= @fecha_desde
AND
(
       @id_co = '-1'
    OR t9820.f9820_id_co = @id_co
)


UNION ALL


SELECT
     CAST('A' AS CHAR(1)) AS origen
    ,t9920.f9920_guid AS guid_docto
    ,t9920.f9920_id_cia AS id_cia

    ,RTRIM(t9740.f9740_id) AS id_cliente_pdv
    ,t9920.f9920_fecha_ts_actualizacion AS fecha_ultima_actualizacion
    ,t9920.f9920_id_fecha_docto AS fecha_docto
    ,RTRIM(t010.f010_razon_social) AS razon_social_cia
    ,RTRIM(t9920.f9920_id_co) AS id_co
    ,RTRIM(t9920.f9920_id_tipo_docto) AS id_tipo_docto
    ,t9920.f9920_consec_docto AS consecutivo_docto
    ,t9920.f9920_valor_bruto AS valor_bruto
    ,t9920.f9920_valor_imp AS valor_imp

    ,t9920.f9920_valor_dscto_global
        + t9920.f9920_valor_dscto_linea AS valor_dsctos

    ,t9920.f9920_valor_neto AS valor_neto

    ,CASE
        WHEN LEFT(t9750.f9750_id, 1) IN ('C', 'D', 'H', 'P')
            THEN 'EL Corral'

        WHEN LEFT(t9750.f9750_id, 1) = 'G'
            THEN 'El Corral Gourmet'

        WHEN LEFT(t9750.f9750_id, 1) = 'E'
            THEN 'EVOK'

        WHEN LEFT(t9750.f9750_id, 1) = 'B'
            THEN 'Beer Station'

        ELSE 'Otros'
     END AS marca

    ,t9757.f9757_id AS Tipo_Entrega

FROM #candidatos_9920 cand

INNER JOIN t9920_pdv_a_doctos t9920 WITH (NOLOCK)
    ON t9920.f9920_guid = cand.guid_docto

INNER JOIN t9740_pdv_clientes t9740 WITH (NOLOCK)
    ON t9740.f9740_id_cia = t9920.f9920_id_cia
   AND t9740.f9740_id = t9920.f9920_id_cliente_pdv

INNER JOIN t010_mm_companias t010 WITH (NOLOCK)
    ON t010.f010_id = t9920.f9920_id_cia

INNER JOIN t9750_pdv_tpv t9750 WITH (NOLOCK)
    ON t9750.f9750_rowid = t9920.f9920_rowid_tpv
    --AND t9920.f9920_consec_docto = @nrodocto

LEFT JOIN t9757_pdv_tipos_entrega t9757 WITH (NOLOCK)
    ON t9757.f9757_rowid = t9920.f9920_rowid_tipo_entrega

WHERE t9920.f9920_id_cia = 1
  AND t9920.f9920_fecha_ts_actualizacion >= @fecha_desde
  AND (
         @id_co = '-1'
      OR t9920.f9920_id_co = @id_co
  )

OPTION (RECOMPILE);

DROP TABLE IF EXISTS #candidatos_9920;

CREATE NONCLUSTERED INDEX IX_documentos_origen_guid
ON #documentos
(
    origen,
    guid_docto
)
INCLUDE
(
    id_cia
);

SELECT DISTINCT
     origen
    ,guid_docto
    ,id_cia

INTO #documentos_claves

FROM #documentos;


CREATE UNIQUE CLUSTERED INDEX IX_documentos_claves
ON #documentos_claves
(
    origen,
    guid_docto
);

SELECT
     CAST('D' AS CHAR(1)) AS origen
    ,t9821.f9821_guid_docto AS guid_docto

    ,RTRIM(CONVERT(
        VARCHAR(20),
        t9821.f9821_id_medio_pago
     )) AS id_medio_pago

    ,RTRIM(CONVERT(
        VARCHAR(255),
        mp.f025_descripcion
     )) AS descripcion_medio_pago

    ,SUM(
        t9821.f9821_valor_ingreso
        - t9821.f9821_valor_egreso
     ) AS valor_neto_medio_pago

INTO #pagos_detalle

FROM t9821_pdv_d_movto_mp t9821 WITH (NOLOCK)

INNER JOIN #documentos_claves documento
    ON documento.origen = 'D'
   AND documento.guid_docto = t9821.f9821_guid_docto

INNER JOIN t025_mm_medios_pago mp WITH (NOLOCK)
    ON mp.f025_id = t9821.f9821_id_medio_pago
   AND mp.f025_id_cia = documento.id_cia

WHERE t9821.f9821_ind_naturaleza = 1

GROUP BY
     t9821.f9821_guid_docto
    ,t9821.f9821_id_medio_pago
    ,mp.f025_descripcion


UNION ALL


SELECT
     CAST('A' AS CHAR(1)) AS origen
    ,t9921.f9921_guid_docto AS guid_docto

    ,RTRIM(CONVERT(
        VARCHAR(20),
        t9921.f9921_id_medio_pago
     )) AS id_medio_pago

    ,RTRIM(CONVERT(
        VARCHAR(255),
        mp.f025_descripcion
     )) AS descripcion_medio_pago

    ,SUM(
        t9921.f9921_valor_ingreso
        - t9921.f9921_valor_egreso
     ) AS valor_neto_medio_pago

FROM t9921_pdv_a_movto_mp t9921 WITH (NOLOCK)

INNER JOIN #documentos_claves documento
    ON documento.origen = 'A'
   AND documento.guid_docto = t9921.f9921_guid_docto

INNER JOIN t025_mm_medios_pago mp WITH (NOLOCK)
    ON mp.f025_id = t9921.f9921_id_medio_pago
   AND mp.f025_id_cia = documento.id_cia

WHERE t9921.f9921_ind_naturaleza = 1

GROUP BY
     t9921.f9921_guid_docto
    ,t9921.f9921_id_medio_pago
    ,mp.f025_descripcion;

CREATE NONCLUSTERED INDEX IX_pagos_detalle_documento
ON #pagos_detalle
(
    origen,
    guid_docto
);

SELECT
     origen
    ,guid_docto

    ,STRING_AGG(
        CONVERT(VARCHAR(MAX), id_medio_pago),
        ','
     ) AS id_medio_pago

    ,STRING_AGG(
        CONVERT(VARCHAR(MAX), descripcion_medio_pago),
        ', '
     ) AS descripcion_medio_pago

    ,SUM(valor_neto_medio_pago) AS valor_neto_medio_pago

INTO #pagos

FROM #pagos_detalle

GROUP BY
     origen
    ,guid_docto;

CREATE UNIQUE CLUSTERED INDEX IX_pagos_documento
ON #pagos
(
    origen,
    guid_docto
);

SELECT
     documento.id_cliente_pdv
    ,documento.fecha_ultima_actualizacion
    ,documento.fecha_docto
    ,documento.razon_social_cia
    ,documento.id_co
    ,documento.id_tipo_docto
    ,documento.consecutivo_docto
    ,documento.valor_bruto
    ,documento.valor_imp
    ,documento.valor_dsctos
    ,documento.valor_neto
    ,documento.marca
    ,pago.id_medio_pago
    ,pago.descripcion_medio_pago
    ,documento.Tipo_Entrega

FROM #documentos documento

LEFT JOIN #pagos pago
    ON pago.origen = documento.origen
   AND pago.guid_docto = documento.guid_docto;

DROP TABLE IF EXISTS #pagos;
DROP TABLE IF EXISTS #pagos_detalle;
DROP TABLE IF EXISTS #documentos_claves;
DROP TABLE IF EXISTS #documentos;
