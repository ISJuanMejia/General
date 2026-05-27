SELECT
    id_grupo_entidad = f744_id,
    id_entidad = f742_id,
    etiqueta_entidad = f742_etiqueta,
    id_atributo = f743_id,
    etiqueta_atributo = f743_etiqueta,
    id_maestro = f740_id, 
    descripcion_maestro = f740_descripcion,
    id_maestro_detalle = f741_id,
    descripcion_maestro_detalle = f741_descripcion
FROM t744_mm_grupo_entidad
    INNER JOIN t745_mm_grupo_entidad_relacion 
        ON 
            f745_rowid_grupo_entidad = f744_rowid
    INNER JOIN t742_mm_entidad 
        ON 
            f742_rowid = f745_rowid_entidad
    INNER JOIN t743_mm_entidad_atributo 
        ON 
            f743_rowid_entidad = f742_rowid
    LEFT JOIN t740_mm_maestro AS t740 
        ON 
            f743_rowid_maestro = f740_rowid
    LEFT JOIN t741_mm_maestro_detalle AS t741 
        ON 
            f741_rowid_maestro = f740_rowid
WHERE 
    f744_rowid = 3 
    AND 
    f744_id_cia = 1
    AND
    f742_id IN ('EUNOECO031', 'EUNOECO036')