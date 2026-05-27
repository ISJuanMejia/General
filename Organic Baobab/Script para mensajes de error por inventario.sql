SELECT
    id_orden, 
    (
        SELECT 
            REPLACE(JSON_VALUE(value, '$.f_valor'), 'Bodega:', ' - Bodega: ') AS Descripcion_error, 
            JSON_VALUE(value, '$.f_detalle') AS Error
        FROM OPENJSON(
            REPLACE(
                REPLACE(
                    REPLACE(execution_log, 'Error importando FACTURA_DIRECTA_INTEGRACION en orden ', ''), id_orden, ''
                )
                , ': {'
                , '{'
            )
            , '$.detalle'
        )
        -- WHERE JSON_VALUE(value, '$.f_detalle') LIKE '%Item sin cantidad disponible%'
        FOR JSON PATH, 
        WITHOUT_ARRAY_WRAPPER
    )
FROM ordenes 
where 
    id_estado = 2 
    and 
    intentos > 0 
    and 
    fecha_creacion > '2026-04-01'
    AND
    EXISTS
    (
        SELECT 
            1
        FROM OPENJSON(
            REPLACE(
                REPLACE(
                    REPLACE(execution_log, 'Error importando FACTURA_DIRECTA_INTEGRACION en orden ', ''), id_orden, ''
                )
                , ': {'
                , '{'
            )
            , '$.detalle'
        )
        -- WHERE JSON_VALUE(value, '$.f_detalle') LIKE '%Item sin cantidad disponible%'
    );