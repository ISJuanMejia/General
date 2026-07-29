/*
SELECT * 
FROM UnoEE_PruebasProyectosCol.dbo.t105_mc_criterios_item_planes
WHERE
    f105_id IN  ('DPC')

SELECT * 
FROM UnoEE_PruebasProyectosCol.dbo.t106_mc_criterios_item_mayores
WHERE
    f106_id_plan    IN  ('DPC')

SELECT *
FROM UnoEE_PruebasProyectosCol.dbo.t125_mc_items_criterios
WHERE
    f125_id_cia =   1
    AND
    f125_id_plan    =   'DPC'

SELECT *
FROM UnoEE_PruebasProyectosCol.dbo.t742_mm_entidad

SP_HELP t742_mm_entidad

SP_HELP t745_mm_grupo_entidad_relacion

SP_HELP t744_mm_grupo_entidad
*/

/*
SELECT  DISTINCT
    f120_rowid,
    f120_rowid_movto_entidad,
    f120_rowid_tercero_cli,
    f120_rowid_tercero_prov,
    f120_id,
    f120_id_cfg_serial,
    f120_id_descripcion_tecnica,
    f120_id_extension1,
    f120_id_extension2,
    f120_id_grupo_dscto,
    f120_id_grupo_impositivo,
    f120_id_sucursal_cli,
    f120_id_sucursal_prov,
    f120_id_tipo_inv_serv,
    f120_id_unidad_empaque,
    f120_id_unidad_inventario,
    f120_id_unidad_orden,
    f121_rowid,
    f121_rowid_item,
    f121_rowid_movto_entidad,
    f121_id_barras_principal,
    f121_id_ext1_detalle,
    f121_id_ext2_detalle,
    f121_id_extension1,
    f121_id_extension2,
    f121_id_plan_kit,
    f121_id_unidad_validacion_kit
FROM t120_mc_items

    INNER JOIN t121_mc_items_extensiones    ON  f120_rowid  = f121_rowid_item

SP_HELP t120_mc_items


SELECT
    COUNT(*)
FROM t120_mc_items
-- 12589

SELECT
    COUNT(*)
FROM t120_mc_items
    INNER JOIN t121_mc_items_extensiones    ON  f120_rowid  = f121_rowid_item
-- 14213

SELECT
    COUNT(*)
FROM t120_mc_items
    LEFT JOIN   t101_mc_unidades_medida
        ON
            f120_id_cia =   f101_id_cia
            AND
            f120_id_unidad_inventario   =   f101_id
    LEFT JOIN   t121_mc_items_extensiones    
        ON
            f120_rowid  =   f121_rowid_item
-- 14213


SELECT * FROM t222_grupo_entidad

SELECT
    f742_id,
    f742_etiqueta,
    f742_notas,
    f743_id,
    f743_etiqueta
FROM t742_mm_entidad
    INNER JOIN t743_mm_entidad_atributo
        ON
            f743_rowid_entidad  =   f742_rowid
WHERE
    f742_id =   'ITEM'
    AND
    f743_id = 'texto_des_web'

SELECT
    f743_rowid_entidad
FROM t743_mm_entidad_atributo

SP_HELP t743_mm_entidad_atributo

SELECT *
FROM t739_mm_maestro_interno

SELECT *
FROM t740_mm_maestro

SELECT *
FROM t741_mm_maestro_detalle

SELECT *
FROM 
*/


SELECT  DISTINCT
    tp.name AS tabla_padre,
    cp.name AS columna_padre,
    tr.name AS tabla_referenciada,
    cr.name AS columna_referenciada
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc
    ON fk.object_id = fkc.constraint_object_id
INNER JOIN sys.tables tp
    ON fkc.parent_object_id = tp.object_id
INNER JOIN sys.columns cp
    ON cp.object_id = tp.object_id
    AND cp.column_id = fkc.parent_column_id
INNER JOIN sys.tables tr
    ON fkc.referenced_object_id = tr.object_id
INNER JOIN sys.columns cr
    ON cr.object_id = tr.object_id
    AND cr.column_id = fkc.referenced_column_id
WHERE
    (
        tp.name IN (
            't120_mc_items'
        )
        OR 
        tr.name IN (
            't120_mc_items'
        )
    )
    AND
    (
    cp.name = 'f120_rowid_movto_entidad'
    OR
    cr.name = 'f120_rowid_movto_entidad'
    )
ORDER BY tp.name;