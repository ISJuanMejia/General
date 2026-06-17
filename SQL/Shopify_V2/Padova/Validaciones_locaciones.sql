-- SELECT DISTINCT TOP 100
--     JSON_VALUE(orden_obj, '$.billing_address.country'),
--     JSON_VALUE(orden_obj, '$.billing_address.province'),
--     JSON_VALUE(orden_obj, '$.billing_address.city'),
--     f011_descripcion,
--     f013_id_pais
-- FROM ordenes AS o
--     LEFT JOIN locaciones_erp AS l ON f011_descripcion = JSON_VALUE(orden_obj, '$.billing_address.country')
-- WHERE
--     JSON_VALUE(orden_obj,'$.presentment_currency') = 'USD'
-- -- ORDER BY o.ID DESC

-- SELECT * FROM locaciones_erp WHERE f011_descripcion LIKE '%estados%'

-- select * from ORDENES where id_orden = '#22321'


-- select * from ORDENES 
-- WHERE fecha_creacion > '2026-04-28'

-- update ordenes set intentos = 0


SELECT DISTINCT TOP 100
    JSON_VALUE(orden_obj, '$.billing_address.country'),
    -- JSON_VALUE(orden_obj, '$.billing_address.province'),
    -- JSON_VALUE(orden_obj, '$.billing_address.city'),
    f011_descripcion,
    f013_id_pais
FROM ordenes AS o
    LEFT JOIN locaciones_erp AS l ON f011_descripcion = JSON_VALUE(orden_obj, '$.billing_address.country')
-- WHERE
--     JSON_VALUE(orden_obj,'$.presentment_currency') = 'USD'

-- CASE 7 United States - Estados Unidos
-- CASE 8 Dominican Republic - República Dominicana
-- CASE 9 Singapore - Singapur
-- CASE 10 Germany - Alemania
-- CASE 11 Saudi Arabia - Arabia Saudita
-- CASE 12 Brazil - Brasil
-- CASE 13 Bulgary - BULGARIA
-- CASE 10 United Arab Emirates - EMIRATOS ARABES UNIDOS

SELECT DISTINCT f011_descripcion 
FROM locaciones_erp 
WHERE 
    f011_descripcion =  ''