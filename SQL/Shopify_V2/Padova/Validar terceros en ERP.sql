SELECT f200_id, f015_id_pais, f015_id_depto, f015_id_ciudad
FROM t200_mm_terceros AS t200
    INNER JOIN t201_mm_clientes AS t201 ON f201_rowid_tercero = f200_rowid
    INNER JOIN t015_mm_contactos AS t015 ON f015_rowid = f201_rowid_contacto
WHERE
    f200_id = '8706146762851'