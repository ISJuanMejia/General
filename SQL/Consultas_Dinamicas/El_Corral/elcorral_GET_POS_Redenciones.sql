DECLARE @fechaInicio NVARCHAR(50) = '{fecha_inicio}';
DECLARE @fechaFin    NVARCHAR(50) = '{fecha_fin}';

DECLARE @fechaInicio_dt DATETIME2(0) = COALESCE(
    TRY_CONVERT(DATETIME2(0), RTRIM(@fechaInicio), 126),
    TRY_CAST(RTRIM(@fechaInicio) AS DATETIME2(0))
);
DECLARE @fechaFin_dt DATETIME2(0) = COALESCE(
    TRY_CONVERT(DATETIME2(0), RTRIM(@fechaFin), 126),
    TRY_CAST(RTRIM(@fechaFin) AS DATETIME2(0))
);

-- Validación de formato de fecha de inicio y fin (yyyy-MM-ddTHH:mm:ss)
IF @fechaInicio_dt IS NULL
BEGIN
    SELECT 'La fecha de inicio no tiene el formato correcto' AS error_message;
    RETURN;
END

IF @fechaFin_dt IS NULL
BEGIN
    SELECT 'La fecha de fin no tiene el formato correcto' AS error_message;
    RETURN;
END

-- Si la fecha de inicio es mayor a la fecha fin arrojar un error
IF @fechaInicio_dt > @fechaFin_dt
BEGIN
    SELECT 'La fecha de inicio no puede ser mayor a la fecha fin' AS error_message;
    RETURN;
END

DECLARE @fechaFin_exclusiva DATETIME2(0) = DATEADD(SECOND, 1, @fechaFin_dt);

SELECT 
     ISNULL(JSON_VALUE(documento, '$.documento.cabecera.InfoAdicional[0].f_guid'), 'sin_guid') AS guid_docto
    ,fecha AS fechaTransaccion
    ,valorTransaccion AS valorTransaccion      
    ,idTransaccionComercio AS idTransaccionComercio
    ,ISNULL(JSON_VALUE(resultadoTransaccionComercio, '$.data.redemption_id'), 'sin_redemption_id') AS redemption_id
    ,ISNULL(JSON_VALUE(resultadoTransaccionComercio, '$.data.cliente'), 'sin_cliente') AS cliente
    ,ISNULL(JSON_VALUE(resultadoTransaccionComercio, '$.data.identificacion'), 'sin_identificacion') AS identificacion
    ,ISNULL(JSON_VALUE(resultadoTransaccionComercio, '$.data.premio'), 'sin_premio') AS premio
    ,ISNULL(JSON_VALUE(resultadoTransaccionComercio, '$.data.prize_code'), 'sin_prize_code') AS prize_code
    ,ISNULL(JSON_VALUE(resultadoTransaccionComercio, '$.data.fecha'), 'sin_fecha') AS fecha_rs
FROM [Connekta].[dbo].[TransaccionesMediosDePago] WITH (NOLOCK)
WHERE medioDePago = 'FansCorral'
  AND estado = 'CerradoExitoso'
  AND fecha >= @fechaInicio_dt
  AND fecha <  @fechaFin_exclusiva
ORDER BY fecha DESC
OPTION (RECOMPILE);

OPTION (RECOMPILE);