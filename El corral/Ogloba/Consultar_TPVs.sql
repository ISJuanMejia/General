SELECT * 
FROM MediosDePagoTPV
WHERE
    Aliado = 'IRCC'
    AND
    MedioDePago = 'Ogloba'
    AND
    CodigoTPV LIKE '%G706%'

/*
INSERT INTO MediosDePagoTPV (IdCompania, IdCia, IdCo, CodigoTPV, DescripcionTPV, DescripcionCO, Aliado, LocationCode, FechaCreacion, MedioDePago)
VALUES
(4749, 1, '', '', '', '', 'IRCC', '', GETDATE(), 'Ogloba')
*/