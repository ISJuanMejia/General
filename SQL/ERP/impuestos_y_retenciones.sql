SELECT 
    F_ID_CLASE  =   f035_id, 
    f035_descripcion, 
    f035_sigla,
    f044_id,
    f044_descripcion,
    F_ID_LLAVE  =   f037_id,
    f037_descripcion
FROM t035_mm_clases_impuesto
    LEFT JOIN t044_mm_clase_impuesto_valores ON f044_id_clase_impuesto = f035_id
    LEFT JOIN t037_mm_llaves_impuesto ON f035_id = f037_id_clase_impuesto
WHERE
    f037_id_cia = 7
    and
    f035_sigla IN ('IVA', 'INC')
ORDER BY f035_id

-- SELECT * FROM t037_mm_llaves_impuesto

SELECT 
    F_ID_CLASE  =   f038_id, 
    f038_descripcion, 
    f038_sigla,
    F_ID_LLAVE  =   f040_id,
    f040_descripcion
FROM t038_mm_clases_retencion
    INNER JOIN t040_mm_llaves_retencion ON f038_id = f040_id_clase_retencion


SELECT * FROM t044_mm_clase_impuesto_valores

select * from t036_mm_clases_impuesto_accion

-- SP_HELP t044_mm_clase_impuesto_valores

SELECT * FROM t037_mm_llaves_impuesto 
INNER JOIN t035_mm_clases_impuesto ON f037_id_clase_impuesto = f035_id


