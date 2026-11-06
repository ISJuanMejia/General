DECLARE @fechaInicio NVARCHAR(50) = '{fecha_inicio}'
DECLARE @fechaFin NVARCHAR(50) = '{fecha_fin}'

-- Si la fecha de inicio o fecha fin no tiene el formato correcto (yyyy-MM-ddTHH:mm:ss), se asigna un valor por defecto
IF ISDATE(TRY_CAST(@fechaInicio AS DATETIME)) = 0
BEGIN
    SELECT 'La fecha de inicio no tiene el formato correcto' AS error_message
    RETURN
END

IF ISDATE(TRY_CAST(@fechaFin AS DATETIME)) = 0
BEGIN
    SELECT 'La fecha de fin no tiene el formato correcto' AS error_message 
    RETURN
END

-- Si la fecha de inicio es mayor a la fecha fin arrojar un error
IF @fechaInicio > @fechaFin
BEGIN
    SELECT 'La fecha de inicio no puede ser mayor a la fecha fin' AS error_message
    RETURN
END

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
FROM [Connekta].[dbo].[TransaccionesMediosDePago]
WHERE medioDePago = 'FansCorral'
AND estado = 'CerradoExitoso'
AND format(fecha, 'yyyy-MM-ddTHH:mm:ss') BETWEEN @fechaInicio AND @fechaFin
ORDER BY fecha DESC