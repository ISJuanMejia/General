SELECT
    RazonSocial,
    Usuarios =
    (
        SELECT
            Nombre,
            Apellido,
            Correo
        FROM Usuario AS u
        WHERE
            u.IdCompania = c.ID
        FOR JSON PATH
    ),
    Sistemas = (
        SELECT
            Nombre_Sistema = s.Descripcion,
            Propiedades_Sistema =
            (
                SELECT
                    Nombre,
                    Valor
                FROM Propiedades
                WHERE
                    IdSistema = s.Id
                FOR JSON PATH
            )
        FROM Sistema AS s
        WHERE
            s.IdCompania = c.Id
        FOR JSON PATH
    )
FROM Compania AS c
WHERE RazonSocial like '%alca%'
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER