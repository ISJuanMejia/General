-- Paso 1: Eliminar duplicados por prioridad
WITH Priorizados AS (
    SELECT 
        id_orden,
        JSON_VALUE(orden_obj, '$.name') AS nombre_json,
        id_estado,
        CASE 
            WHEN id_estado IN (2, 3) THEN 1
            WHEN id_estado = 1       THEN 2
            ELSE                          3  -- NULL
        END AS prioridad
    FROM ORDENES
    WHERE JSON_VALUE(orden_obj, '$.name') IS NOT NULL
),
Duplicados AS (
    SELECT 
        o1.id_orden
    FROM Priorizados o1
    WHERE EXISTS (
        SELECT 1
        FROM Priorizados o2
        WHERE 
            o2.nombre_json = o1.nombre_json
            AND o2.id_orden != o1.id_orden
            AND (
                -- o2 tiene mejor prioridad
                o2.prioridad < o1.prioridad
                OR
                -- misma prioridad, conservar el de menor id_orden
                (o2.prioridad = o1.prioridad AND o2.id_orden < o1.id_orden)
            )
    )
)
DELETE FROM ORDENES
WHERE id_orden IN (SELECT id_orden FROM Duplicados);

-- Paso 2: Actualizar ID_ORDEN desde el JSON
UPDATE ORDENES
SET ID_ORDEN = JSON_VALUE(orden_obj, '$.name')
WHERE ID_ORDEN != JSON_VALUE(orden_obj, '$.name');