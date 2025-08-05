SELECT TOP (1000) 
    [MedioDePago]
    ,[IdTransaccionPOS]
    ,[Tipo]
    ,[Peticion]
    ,[CodigoRepuesta]
    ,[Respuesta]
    ,[Ts]
FROM [Connekta].[dbo].[TransaccionesMediosDePagoPOS]
WHERE
    IdCompania = 4749
    AND
    MedioDePago = 'Ogloba'
    AND
    Ts > '2025-08-04'
    AND
    Ts < '2025-08-05'
    -- AND
    -- Peticion LIKE '%G706%'
ORDER BY ID DESC