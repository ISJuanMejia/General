-- =============================================
-- PASO 1: Corregir registros con fecha_sincronizacion != NULL
--         que tengan sincronizado = 0 (nunca deben coexistir)
-- =============================================
UPDATE precios
SET sincronizado = 1
WHERE 
    sincronizado = 0
    AND 
    fecha_sincronizacion IS NOT NULL;

-- =============================================
-- PASO 2: Si hay más de 1 registro con sincronizado = 0,
--         conservar solo 1 (el de menor id) y revertir el resto
-- =============================================
UPDATE precios
SET sincronizado = 1
WHERE
    sincronizado = 0
    AND id NOT IN (
        SELECT MIN(id)
        FROM precios
        WHERE sincronizado = 0
    );

-- =============================================
-- PASO 3: Lógica original — tomar 1 candidato
--         (sincronizado = 1, sin fecha) y marcarlo como pendiente
-- =============================================
UPDATE p
SET sincronizado = 0
FROM precios p
INNER JOIN (
    SELECT TOP 1 id
    FROM precios
    WHERE 
        sincronizado = 1
        AND fecha_sincronizacion IS NULL
    ORDER BY id ASC  -- criterio explícito de prioridad
) AS candidato ON candidato.id = p.id
WHERE NOT EXISTS (
    -- Solo ejecutar si actualmente no hay ningún pendiente
    SELECT 1 FROM precios WHERE sincronizado = 0
);