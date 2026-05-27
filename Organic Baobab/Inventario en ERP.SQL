SELECT 
    f120_referencia, f120_descripcion, f121_id_ext1_detalle, f121_id_ext2_detalle, f150_id, f400_cant_existencia_1, f400_cant_comprometida_1, f400_cant_pendiente_salir_1, f400_cant_pos_1, f400_cant_salida_sin_conf_1
FROM t120_mc_items
    INNER JOIN t121_mc_items_extensiones ON f120_rowid = f121_rowid_item
    INNER JOIN t400_cm_existencia ON f121_rowid = f400_rowid_item_ext
    INNER JOIN t150_mc_bodegas ON f150_rowid = f400_rowid_bodega
WHERE
    (
        f120_referencia = '6031266'
        AND
        f121_id_ext1_detalle = '06'
        AND
        f150_id = 'PUERB'
    )
    OR
    (
        f120_referencia = '6060321'
        AND
        f121_id_ext1_detalle = '02'
        AND
        f150_id = 'PUERB'
    )
    OR
    (
        f120_referencia = '5100901'
        AND
        f121_id_ext1_detalle = '02'
        AND
        f150_id = 'COSTA'
    )
    OR
    (
        f120_referencia = '6731294'
        AND
        f121_id_ext1_detalle = '03'
        AND
        f150_id = 'COSTA'
    )
    OR
    (
        f120_referencia = '6960163'
        AND
        f121_id_ext1_detalle = '01'
        AND
        f150_id = 'COSTA'
    )
    OR
    (
        f120_referencia = '5640259'
        AND
        f121_id_ext1_detalle = '03'
        AND
        f150_id = 'COSTA'
    )
    OR
    (
        f120_referencia = '4260233'
        -- AND
        -- f121_id_ext1_detalle = '04'
        AND
        f150_id = 'MELON'
    )
    OR
    (
        f120_referencia = '5100471'
        -- AND
        -- f121_id_ext1_detalle = '04'
        AND
        f150_id = 'MELON'
    )