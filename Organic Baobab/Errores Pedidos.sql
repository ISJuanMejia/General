SELECT ordenes_con_errores_de_items_no_existentes = id_orden, fecha_creacion FROM ordenes 
WHERE 
    execution_log like '%Movto Inventario: El item - extension no existe.%'

SELECT Ordenes_con_errores_de_falta_de_inventario = id_orden, fecha_creacion FROM ordenes 
WHERE 
    execution_log like '%Movto Inventario: Item sin cantidad disponible%'

SELECT Ordenes_con_errores_de_falta_nombre_contacto = id_orden, fecha_creacion FROM ordenes 
WHERE 
    execution_log like '%Falta el nombre del contacto%'

SELECT Ordenes_con_errores_de_valor_de_cartera_debe_ser_igual_al_valor_CxC  = id_orden, fecha_creacion FROM ordenes 
WHERE 
    execution_log like '%El valor de la cartera debe ser igual al valor de las CxC%'

SELECT Ordenes_con_errores_diferentes = id_orden, fecha_creacion, execution_log FROM ordenes 
WHERE 
    execution_log like '%Error%'
    AND
    execution_log NOT LIKE '%Movto Inventario: El item - extension no existe.%'
    AND
    execution_log NOT LIKE '%Movto Inventario: Item sin cantidad disponible%'
    AND
    execution_log NOT LIKE '%Falta el nombre del contacto%'
    AND
    execution_log NOT LIKE '%El valor de la cartera debe ser igual al valor de las CxC%'