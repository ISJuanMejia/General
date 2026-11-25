-- ONEILL
DELETE FROM [productos] 
WHERE id_tienda = 2
AND sincronizado = 0;

WITH base_especificaciones AS (
    -- Fabricante
    SELECT  
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        'Fabricante y/o Importador' AS fieldName,
        'Creaciones Nadar S.A.' AS fieldValue
    FROM productos p
    WHERE p.id_tienda = 2
    AND p.fecha_sincronizacion >= DATEADD(HOUR, -12, GETDATE())

    UNION ALL

    -- Registro SIC
    SELECT  
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        'Registro SIC' AS fieldName,
        '800130985' AS fieldValue
    FROM productos p
    WHERE p.id_tienda = 2
    AND p.fecha_sincronizacion >= DATEADD(HOUR, -12, GETDATE())

    UNION ALL

    -- País de origen
    SELECT DISTINCT  
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        LTRIM(RTRIM(REPLACE(f105_descripcion, 'ORIGEN', 'País de origen'))) AS fieldName,
        LTRIM(RTRIM(f106_descripcion)) AS fieldValue
    FROM productos p
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t120_mc_items t120 
        ON SUBSTRING(f120_notas,0,CHARINDEX('|',f120_notas,1)) COLLATE DATABASE_DEFAULT = p.referencia_producto_erp
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t125_mc_items_criterios t125 
        ON f120_rowid = f125_rowid_item 
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t106_mc_criterios_item_mayores t106 
        ON f106_id_cia = f125_id_cia AND f106_id_plan = f125_id_plan AND f106_id = f125_id_criterio_mayor 
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t105_mc_criterios_item_planes t105 
        ON f106_id_cia = f105_id_cia AND f106_id_plan = f105_id 
    WHERE p.id_tienda = 2
    AND p.fecha_sincronizacion >= DATEADD(HOUR, -12, GETDATE())
    AND f125_id_plan = 023
    AND f106_descripcion IS NOT NULL
    AND f106_descripcion <> ''

    UNION ALL

    -- Composición
    SELECT DISTINCT  
        id_tienda,
        id_producto,
        id_producto_ecommerce,
        'Composición' AS fieldName,
        CONCAT(
            CASE WHEN [021] <> 'No aplica' THEN '<p>Principal: '+ [021] + '</p>' ELSE '' END,
            CASE WHEN [051] <> 'No aplica' THEN '<p>Interna: '+ [051] + '</p>' ELSE '' END,
            CASE WHEN [052] <> 'No aplica' THEN '<p>Otras: '+ [052] + '</p>' ELSE '' END
        ) AS fieldValue
    FROM (
        SELECT 
            p.id_tienda,
            p.id AS id_producto,
            p.id_producto_ecommerce,
            f125_id_plan AS f125_id,
            RTRIM(LTRIM(f106_descripcion)) AS f106_descripcion
        FROM productos p
        INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t120_mc_items t120 
            ON SUBSTRING(f120_notas,0,CHARINDEX('|',f120_notas,1)) COLLATE DATABASE_DEFAULT = p.referencia_producto_erp
        INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t125_mc_items_criterios t125 
            ON f120_rowid = f125_rowid_item 
        INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t106_mc_criterios_item_mayores t106 
            ON f106_id_cia = f125_id_cia AND f106_id_plan = f125_id_plan AND f106_id = f125_id_criterio_mayor 
        INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t105_mc_criterios_item_planes t105 
            ON f106_id_cia = f105_id_cia AND f106_id_plan = f105_id 
        WHERE p.id_tienda = 2
        AND p.fecha_sincronizacion >= DATEADD(HOUR, -12, GETDATE())
        AND f105_descripcion IN ('COMPOSICION','EC-COMP. INTERNA','EC-OTRAS COMPOSICIONES')
        AND f106_descripcion IS NOT NULL
        AND f106_descripcion <> ''
    ) Criterios
    PIVOT (MAX(f106_descripcion) FOR f125_id IN ([021],[051],[052])) AS PivotCriterios

    UNION ALL

    -- Cuidados del producto
    SELECT DISTINCT  
        id_tienda,
        id_producto,
        id_producto_ecommerce,
        'Cuidados del producto' AS fieldName,
        '<strong>Limpieza:</strong><ul>' +
        CONCAT(
            CASE WHEN [053] <> 'No Aplica' THEN '<li>Lavado: '+ [053] + '</li>' ELSE '' END,
            CASE WHEN [054] <> 'No Aplica' THEN '<li>Blanqueado: '+ [054] + '</li>' ELSE '' END,
            CASE WHEN [055] <> 'No Aplica' THEN '<li>Secado: '+ [055] + '</li>' ELSE '' END,
            CASE WHEN [056] <> 'No Aplica' THEN '<li>Planchado: '+ [056] + '</li>' ELSE '' END,
            CASE WHEN [057] <> 'No Aplica' THEN '<li>Lavado textil profesional: '+ [057] + '</li>' ELSE '' END
        ) + '</ul>' AS fieldValue
    FROM (
        SELECT 
            p.id_tienda,
            p.id AS id_producto,
            p.id_producto_ecommerce,
            f125_id_plan AS f125_id,
            RTRIM(LTRIM(f106_descripcion)) AS f106_descripcion
        FROM productos p
        INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t120_mc_items t120 
            ON SUBSTRING(f120_notas,0,CHARINDEX('|',f120_notas,1)) COLLATE DATABASE_DEFAULT = p.referencia_producto_erp
        INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t125_mc_items_criterios t125 
            ON f120_rowid = f125_rowid_item 
        INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t106_mc_criterios_item_mayores t106 
            ON f106_id_cia = f125_id_cia AND f106_id_plan = f125_id_plan AND f106_id = f125_id_criterio_mayor 
        INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t105_mc_criterios_item_planes t105 
            ON f106_id_cia = f105_id_cia AND f106_id_plan = f105_id 
        WHERE p.id_tienda = 2
        AND p.fecha_sincronizacion >= DATEADD(HOUR, -12, GETDATE())
        AND f105_descripcion IN ('EC-LAVADO','EC-BLANQUEADO', 'EC-SECADO','EC-PLANCHADO','EC-LAV. TEXTIL PROF')
        AND f106_descripcion IS NOT NULL
        AND f106_descripcion <> ''
    ) Criterios
    PIVOT (MAX(f106_descripcion) FOR f125_id IN ([053],[054],[055],[056],[057])) AS PivotCuidados
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
            FROM base_especificaciones b2
            WHERE b2.id_producto = b.id_producto
            FOR JSON PATH
        ) AS especificacione_obj
    FROM base_especificaciones b
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
    0,
    GETDATE()
FROM json_agregado j
LEFT JOIN especificaciones_productos e
    ON j.id_producto = e.id_producto AND j.especificacione_obj = e.especificacione_obj
WHERE e.id_producto IS NULL;
