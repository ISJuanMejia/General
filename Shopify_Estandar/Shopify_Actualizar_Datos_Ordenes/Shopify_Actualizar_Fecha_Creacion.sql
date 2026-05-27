UPDATE ORDENES
SET fecha_creacion = JSON_VALUE(orden_obj, '$.updated_at')
WHERE 
fecha_creacion != JSON_VALUE(orden_obj, '$.updated_at')