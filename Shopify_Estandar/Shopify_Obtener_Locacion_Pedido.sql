CREATE FUNCTION dbo.fn_GetLocationIds
(
    @pais_shopify NVARCHAR(100),
    @dpto_shopify NVARCHAR(100),
    @ciudad_shopify NVARCHAR(100),
    @id_pais_defecto NVARCHAR(3),
    @id_dpto_defecto NVARCHAR(2),
    @id_ciudad_defecto NVARCHAR(3)
)
RETURNS @result TABLE
(
    id_pais_erp NVARCHAR(3),
    id_dptos_erp NVARCHAR(2),
    id_ciudad_erp NVARCHAR(3)
)
AS
BEGIN
    INSERT INTO @result
    SELECT TOP 1
        ISNULL(f013_id_pais, @id_pais_defecto),
        ISNULL(f013_id_depto, @id_dpto_defecto),
        ISNULL(f013_id, @id_ciudad_defecto)
    FROM locaciones_erp
    WHERE
        dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(@pais_shopify))
        AND
        (
            -- Caso 1: Bogotá D.C.
            (
                (
                    '%' + @dpto_shopify + '%' LIKE '%cundinamarca%'
                    OR
                    '%' + @dpto_shopify + '%' LIKE '%bogota%'
                )
                AND @ciudad_shopify LIKE '%bogota%'
                AND dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) LIKE '%bogota%'
                AND dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) LIKE '%bogota%'
            )
            OR
            -- Caso 2
            (
                (
                    '%' + @dpto_shopify + '%' LIKE '%cundinamarca%'
                    OR
                    '%' + @dpto_shopify + '%' LIKE '%bogota%'
                )
                AND @ciudad_shopify NOT LIKE 'bogota'
                AND dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) LIKE '%cundinamarca%'
                AND dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = @ciudad_shopify
            )
            OR
            -- Caso 3: Bolívar – Cartagena
            (
                @dpto_shopify LIKE '%bolivar%'
                AND dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) LIKE '%cartagena%'
                AND @ciudad_shopify LIKE '%cartagena%'
            )
            OR
            -- Caso 4: México – CDMX
            (
                dbo.fn_RemoveAccentMarks(LOWER(@pais_shopify)) = 'mexico'
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(@dpto_shopify)) = 'ciudad de mexico'
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(@ciudad_shopify)) IN ('cdmx', 'ciudad de mexico')
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = 'mexico'
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = 'ciudad de mexico'
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = 'ciudad de mexico'
            )
            OR
            -- Caso 5: Nicaragua – Managua
            (
                dbo.fn_RemoveAccentMarks(LOWER(@pais_shopify)) = 'nicaragua'
                AND 
                (
                    dbo.fn_RemoveAccentMarks(LOWER(@dpto_shopify)) = 'managua'
                    OR
                    @dpto_shopify IS NULL
                )
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(@ciudad_shopify)) = 'managua'
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = 'nicaragua'
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = 'managua'
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = 'managua'
            )
            OR
            -- Caso 6: Panamá – Panamá
            (
                dbo.fn_RemoveAccentMarks(LOWER(@pais_shopify)) = 'panama'
                AND 
                (
                    dbo.fn_RemoveAccentMarks(LOWER(@dpto_shopify)) LIKE '%panama%'
                    OR
                    @dpto_shopify IS NULL
                )
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(@ciudad_shopify)) LIKE '%panama%'
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = 'panama'
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = 'ciudad de panama'
                AND 
                dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = 'ciudad de panama'
            )
            OR
            -- Caso 7: Estados Unidos
            -- (
            --     dbo.fn_RemoveAccentMarks(LOWER(@pais_shopify)) = 'united states'
            --     -- Caso 7.1: Florida
            --     AND 
            --     (
            --         dbo.fn_RemoveAccentMarks(LOWER(@dpto_shopify)) LIKE '%panama%'
            --         OR
            --         @dpto_shopify IS NULL
            --     )
            --     AND 
            --     dbo.fn_RemoveAccentMarks(LOWER(@ciudad_shopify)) LIKE '%panama%'
            --     AND 
            --     dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = 'panama'
            --     AND 
            --     dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = 'ciudad de panama'
            --     AND 
            --     dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = 'ciudad de panama'
            -- )
            -- OR
            -- Caso 6: Caso general
            (
                dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = @dpto_shopify
                AND
                (
                    @ciudad_shopify = dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion))
                    OR
                    dbo.fn_RemoveAccentMarks(
                        REPLACE(
                            LOWER(@ciudad_shopify), 
                            ' ', 
                            ''
                        )
                    )   =   dbo.fn_RemoveAccentMarks(
                        REPLACE(
                            LOWER(f013_descripcion), 
                            ' ', 
                            ''
                        )
                    )
                    OR
                    (
                        NOT EXISTS (
                            SELECT 1
                            FROM locaciones_erp l2
                            WHERE
                                dbo.fn_RemoveAccentMarks(LOWER(l2.f011_descripcion)) = @pais_shopify
                                AND dbo.fn_RemoveAccentMarks(LOWER(l2.f012_descripcion)) = @dpto_shopify
                                AND @ciudad_shopify = dbo.fn_RemoveAccentMarks(LOWER(l2.f013_descripcion))
                        )
                        AND @ciudad_shopify LIKE '%' + dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) + '%'
                    )
                )
            )
        );
    
    IF NOT EXISTS (SELECT 1 FROM @result)
    BEGIN
        INSERT INTO @result
        SELECT
            id_pais_erp     =   @id_pais_defecto,
            id_dptos_erp    =   @id_dpto_defecto,
            id_ciudad_erp   =   @id_ciudad_defecto

        RETURN;
    END

    RETURN;
END
GO