UPDATE ORDENES 
SET intentos = 0
WHERE
    fecha_creacion > DATEADD(DAY, -7, GETDATE()) 
    AND 
    intentos > 0