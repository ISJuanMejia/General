SELECT DISTINCT
    T430PP.f430_consec_docto,
    T430PP.f430_num_docto_referencia,
    f753_dato_texto_numero_guia =
        ISNULL(
            (
                SELECT  TOP 1
                    f753_dato_texto
                FROM t430_cm_pv_docto AS T430ENT
                    INNER JOIN t750_mm_movto_entidad    
                        ON
                            f750_rowid  =   T430ENT.f430_rowid_movto_entidad
                    INNER jOIN t753_mm_movto_entidad_columna
                        ON
                            f753_rowid_movto_entidad    =   f750_rowid
                    INNER JOIN t743_mm_entidad_atributo 
                        ON
                            f743_rowid  =   f753_rowid_entidad_atributo
                WHERE  
                    f743_etiqueta   =   'NO_GUIA'
                    AND 
                    T430PP.f430_rowid   =   T430ENT.f430_rowid
            ), 
            ' '
        ),
    f741_descripcion_transportadora =
        ISNULL(
            (
                SELECT DISTINCT TOP 1
                    f741_descripcion
                FROM t430_cm_pv_docto AS T430ENT
                    INNER JOIN t750_mm_movto_entidad
                        ON
                            T430ENT.f430_rowid_movto_entidad    =   f750_rowid
                    INNER JOIN t753_mm_movto_entidad_columna
                        ON
                            f753_rowid_movto_entidad    =   f750_rowid
                    INNER JOIN t743_mm_entidad_atributo
                        ON
                            f753_rowid_entidad_atributo =   f743_rowid
                    INNER JOIN t741_mm_maestro_detalle 
                        ON
                            f741_rowid  =   f753_rowid_maestro_detalle
                WHERE 
                    f743_etiqueta   =   'TRANSPORTADORA' 
                    AND 
                    T430PP.f430_rowid = T430ENT.f430_rowid
            ), 
            ' '
        ),
    f741_descripcion_guia_incidencia    =
        ISNULL(
            (
                SELECT DISTINCT TOP 1
                    f741_descripcion
                FROM t430_cm_pv_docto AS T430ENT
                    INNER JOIN  t750_mm_movto_entidad
                        ON
                            T430ENT.f430_rowid_movto_entidad    =   f750_rowid
                    INNER JOIN  t753_mm_movto_entidad_columna
                        ON
                            f753_rowid_movto_entidad    =   f750_rowid
                    INNER JOIN  t743_mm_entidad_atributo 
                        ON
                            f753_rowid_entidad_atributo =   f743_rowid
                    INNER JOIN  t741_mm_maestro_detalle 
                        ON
                            f741_rowid  =   f753_rowid_maestro_detalle
                WHERE 
                    f743_etiqueta   =   'GUIA_DE_INCIDENCIA' 
                    AND 
                    T430PP.f430_rowid   =   T430ENT.f430_rowid
            )
            , ''
        )
FROM t430_cm_pv_docto   AS  T430PP
    INNER JOIN  t431_cm_pv_movto 
        ON
            f431_rowid_pv_docto =   f430_rowid
WHERE
    T430PP.f430_id_tipo_docto IN ('PVI')
    AND
    T430PP.f430_num_docto_referencia IS NOT NULL
    AND
    (
        SELECT  TOP 1
            ISNULL(TRIM(f753_dato_texto), '')
        FROM t430_cm_pv_docto AS T430ENT
            INNER JOIN  t750_mm_movto_entidad
                ON
                    f750_rowid  =   T430ENT.f430_rowid_movto_entidad
            INNER jOIN  t753_mm_movto_entidad_columna
                ON
                    f753_rowid_movto_entidad    =   f750_rowid
            INNER JOIN  t743_mm_entidad_atributo
                ON
                    f743_rowid  =   f753_rowid_entidad_atributo
        WHERE  
            f743_etiqueta = 'NO_GUIA'
            AND 
            T430PP.f430_rowid = T430ENT.f430_rowid
            AND
            ISNULL(TRIM(f753_dato_texto), '') IS NOT NULL
            AND
            f753_dato_texto NOT IN ('CEDI', 'MADERKIT')
    ) IS NOT NULL
ORDER BY T430PP.f430_consec_docto DESC