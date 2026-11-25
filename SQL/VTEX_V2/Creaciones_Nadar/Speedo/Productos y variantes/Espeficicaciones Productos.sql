WITH especificaciones_por_producto AS (
    SELECT DISTINCT  
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        LTRIM(RTRIM(
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                t105.f105_descripcion,
                'EC-CATEGORIA N1', 'Categoría'),
                'EC-EDAD', 'Edad'),
                'EC-LINEA', 'Línea'),
                'EC-USO', 'Uso'),
                'EC-TECNOLOGÍA', 'Tecnología'),
                'EC-TIPO DE PRENDA', 'Tipo Prenda'),
                'ESPALDAS', 'Espalda'),
                'EC-SOPORTE BRASIER', 'Soporte Brasier'),
                'EC-ALTURA PIERNA', 'Altura Pierna'),
                'EC-TELA', 'Tela'),
                'EC-MATERIAL', 'Material'),
                'EC-MARCO', 'Marco'),
                'LENTES', 'Color Lente'),
				'COLECCIÓN', 'Colección'),
                'EC-SALE', 'Sale'),
                'SEXO', 'Género')
        )) AS fieldName,
        LTRIM(RTRIM(t106.f106_descripcion)) AS fieldValue
    FROM productos p
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t120_mc_items t120 
        ON SUBSTRING(f120_notas, 0, CHARINDEX('|', f120_notas, 1)) COLLATE DATABASE_DEFAULT = p.referencia_producto_erp
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t125_mc_items_criterios t125 
        ON f120_rowid = f125_rowid_item 
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t106_mc_criterios_item_mayores t106 
        ON f106_id_cia = f125_id_cia AND f106_id_plan = f125_id_plan AND f106_id = f125_id_criterio_mayor 
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t105_mc_criterios_item_planes t105 
        ON f106_id_cia = f105_id_cia AND f106_id_plan = f105_id 
    WHERE 
        p.id_tienda = 1
        AND f105_id IN ('040','029','030','031','033','034','017','035','036','037','038','039','022','032','007','012')
        AND f106_descripcion NOT IN ('No','No Aplica')
        AND p.id_producto_ecommerce >= 1319
		AND p.fecha_sincronizacion >= DATEADD(HOUR, -48, GETDATE())
)
, json_agregado AS (
    SELECT
        id_tienda,
        id_producto,
        id_producto_ecommerce,
        (
            SELECT 
                JSON_QUERY('["' + fieldValue + '"]') AS [Value],
                fieldName AS [Name]
            FROM especificaciones_por_producto ep2
            WHERE ep2.id_producto = ep.id_producto
            FOR JSON PATH
        ) AS especificacione_obj
    FROM especificaciones_por_producto ep
    GROUP BY id_tienda, id_producto, id_producto_ecommerce
)
INSERT INTO especificaciones_productos (
    id_tienda, id_producto, id_producto_ecommerce, especificacione_obj, sincronizado, fecha_sincronizacion
)
SELECT 
    j.id_tienda,
    j.id_producto,
    j.id_producto_ecommerce,
    j.especificacione_obj,
    0 as sincronizado,
    GETDATE() as fecha_sincronizacion
FROM json_agregado j
LEFT JOIN especificaciones_productos e
    ON j.id_producto = e.id_producto AND j.especificacione_obj = e.especificacione_obj
WHERE e.id_producto IS NULL;
