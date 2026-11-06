DECLARE @id_cliente_pdv           VARCHAR(20)  = '{id_cliente_pdv}';
DECLARE @fecha_ts_actualizacion   VARCHAR(14)  = '{fecha_ts_actualizacion}';  -- Formato ISO: AAAAMMDDHHMMSS. Comodín: -1
DECLARE @id_co                    VARCHAR(20)  = '{id_co}';

-- Validación estricta y conversión del parámetro ISO AAAAMMDDHHMMSS a DATETIME
DECLARE @fecha_ts_actualizacion_dt DATETIME;

IF @fecha_ts_actualizacion <> '-1'
BEGIN
    -- Longitud exacta y solo dígitos
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

    -- TRY_CONVERT captura días inválidos por mes (ej. 31 de febrero)
    SET @fecha_ts_actualizacion_dt = TRY_CONVERT(DATETIME,
            CAST(@anio AS VARCHAR) + '-' + RIGHT('0' + CAST(@mes AS VARCHAR), 2) + '-' +
            RIGHT('0' + CAST(@dia AS VARCHAR), 2) + ' ' +
            RIGHT('0' + CAST(@hora AS VARCHAR), 2) + ':' +
            RIGHT('0' + CAST(@min  AS VARCHAR), 2) + ':' +
            RIGHT('0' + CAST(@seg  AS VARCHAR), 2), 120);

    IF @fecha_ts_actualizacion_dt IS NULL
        RAISERROR('El parámetro @fecha_ts_actualizacion no representa una fecha/hora válida (ej. día 31 en un mes de 30 días).', 16, 1);
END;

SELECT
     RTRIM(t9740.f9740_id) AS id_cliente_pdv
    ,t9820.f9820_fecha_ts_actualizacion AS fecha_ultima_actualizacion
    ,t9820.f9820_id_fecha_docto AS fecha_docto    
    ,RTRIM(t010.f010_razon_social) AS razon_social_cia     
    ,RTRIM(t9820.f9820_id_co) AS id_co
    ,RTRIM(t9820.f9820_id_tipo_docto) AS id_tipo_docto
    ,t9820.f9820_consec_docto AS consecutivo_docto
    ,t9820.f9820_valor_bruto AS valor_bruto
    ,t9820.f9820_valor_imp AS valor_imp
    ,t9820.f9820_valor_dscto_global + t9820.f9820_valor_dscto_linea AS valor_dsctos
    ,t9820.f9820_valor_neto AS valor_neto
    ,CASE 
        WHEN SUBSTRING(t9750.f9750_id, 1, 1) IN ('C', 'D', 'H', 'P') THEN 'EL Corral'
        WHEN SUBSTRING(t9750.f9750_id, 1, 1) = 'G' THEN 'El Corral Gourmet'
        WHEN SUBSTRING(t9750.f9750_id, 1, 1) = 'E' THEN 'EVOK'
        WHEN SUBSTRING(t9750.f9750_id, 1, 1) = 'B' THEN 'Beer Station'
     ELSE 'Otros' END AS marca
    -- ,t9757.f9757_id AS id_tipo_entrega
    -- ,t9757.f9757_descripcion AS descripcion_tipo_entrega    
FROM        t9740_pdv_clientes t9740 WITH (NOLOCK)
INNER JOIN  t010_mm_companias t010 ON t010.f010_id = t9740.f9740_id_cia
INNER JOIN  t9820_pdv_d_doctos t9820 WITH (NOLOCK) ON t9820.f9820_id_cia = t9740.f9740_id_cia
INNER JOIN  t9750_pdv_tpv t9750 WITH (NOLOCK) ON t9750.f9750_rowid = t9820.f9820_rowid_tpv
-- LEFT JOIN   t9757_pdv_tipos_entrega t9757 WITH (NOLOCK)  ON t9757.f9757_rowid = t9820.f9820_rowid_tipo_entrega
AND t9820.f9820_id_cliente_pdv = RTRIM(t9740.f9740_id)
WHERE EXISTS (
    SELECT 1 FROM t9741_pdv_criterios_clientes
    WHERE f9741_id_cliente_pdv    = t9740.f9740_id
    AND   f9741_id_criterio_mayor = '0004'
    AND   f9741_id_plan_criterios = 'PDV'
)
AND   (@id_cliente_pdv = '-1' OR RTRIM(t9740.f9740_id) = @id_cliente_pdv)
AND   t9820.f9820_fecha_ts_actualizacion >= CASE WHEN @fecha_ts_actualizacion_dt IS NULL THEN DATEADD(DAY, -7, GETDATE()) ELSE @fecha_ts_actualizacion_dt END
AND   (@id_co = '-1' OR RTRIM(t9820.f9820_id_co) = @id_co)

UNION ALL

SELECT
     RTRIM(t9740.f9740_id) AS id_cliente_pdv
    ,t9920.f9920_fecha_ts_actualizacion AS fecha_ultima_actualizacion
    ,t9920.f9920_id_fecha_docto AS fecha_docto    
    ,RTRIM(t010.f010_razon_social) AS razon_social_cia     
    ,RTRIM(t9920.f9920_id_co) AS id_co
    ,RTRIM(t9920.f9920_id_tipo_docto) AS id_tipo_docto
    ,t9920.f9920_consec_docto AS consecutivo_docto
    ,t9920.f9920_valor_bruto AS valor_bruto
    ,t9920.f9920_valor_imp AS valor_imp
    ,t9920.f9920_valor_dscto_global + t9920.f9920_valor_dscto_linea AS valor_dsctos
    ,t9920.f9920_valor_neto AS valor_neto
    ,CASE 
        WHEN SUBSTRING(t9750.f9750_id, 1, 1) IN ('C', 'D', 'H', 'P') THEN 'EL Corral'
        WHEN SUBSTRING(t9750.f9750_id, 1, 1) = 'G' THEN 'El Corral Gourmet'
        WHEN SUBSTRING(t9750.f9750_id, 1, 1) = 'E' THEN 'EVOK'
        WHEN SUBSTRING(t9750.f9750_id, 1, 1) = 'B' THEN 'Beer Station'
     ELSE 'Otros' END AS marca
    -- ,t9757.f9757_id AS id_tipo_entrega
    -- ,t9757.f9757_descripcion AS descripcion_tipo_entrega
FROM        t9740_pdv_clientes t9740 WITH (NOLOCK)
INNER JOIN  t010_mm_companias t010 ON t010.f010_id = t9740.f9740_id_cia
INNER JOIN  t9920_pdv_a_doctos t9920 WITH (NOLOCK) ON t9920.f9920_id_cia = t9740.f9740_id_cia
INNER JOIN  t9750_pdv_tpv t9750 WITH (NOLOCK) ON t9750.f9750_rowid = t9920.f9920_rowid_tpv
-- LEFT JOIN   t9757_pdv_tipos_entrega t9757 WITH (NOLOCK)  ON t9757.f9757_rowid = t9920.f9920_rowid_tipo_entrega
AND t9920.f9920_id_cliente_pdv = RTRIM(t9740.f9740_id)
WHERE EXISTS (
    SELECT 1 FROM t9741_pdv_criterios_clientes
    WHERE f9741_id_cliente_pdv    = t9740.f9740_id
    AND   f9741_id_criterio_mayor = '0004'
    AND   f9741_id_plan_criterios = 'PDV'
)
AND   (@id_cliente_pdv = '-1' OR RTRIM(t9740.f9740_id) = @id_cliente_pdv)
AND   t9920.f9920_fecha_ts_actualizacion >= CASE WHEN @fecha_ts_actualizacion_dt IS NULL THEN DATEADD(DAY, -7, GETDATE()) ELSE @fecha_ts_actualizacion_dt END
AND   (@id_co = '-1' OR RTRIM(t9920.f9920_id_co) = @id_co);