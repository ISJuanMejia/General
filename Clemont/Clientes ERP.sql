SELECT
    f200_id
FROM t200_mm_terceros
    INNER JOIN t201_mm_clientes ON f200_rowid = f201_rowid_tercero
    INNER JOIN t015_mm_contactos    ON f015_rowid = f201_rowid_contacto
WHERE 
    f015_id_pais    IS NULL