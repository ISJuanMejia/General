WITH ProductosFiltrados AS (
    SELECT 
        id_tienda,
        id_producto_ecommerce,
        referencia_producto_erp
    FROM 
        productos
    WHERE 
        id_tienda = 1
        --AND id_producto_ecommerce in ('11541','11514','11577','11579','11606','11607','11612')
        AND sincronizado = 1
)

INSERT INTO [dbo].[variantes] (
	id_tienda,
    id_producto_ecommerce, 
    id_variante_ecommerce, 
    sku_erp, 
	sincronizado, 
    fecha_sincronizacion,
    variante_obj
)

SELECT 
	pf.id_tienda,
    pf.id_producto_ecommerce,
    0 AS id_variante_ecommerce, 
    LTRIM(RTRIM(RawData.f120_id))	AS sku_erp,
    CAST(0 AS BIT) AS sincronizado, 
    GETDATE() AS fecha_sincronizacion,
    JSON_QUERY(( 
        SELECT 
            pf.id_producto_ecommerce AS ProductId,
            CAST('false' AS BIT) AS IsActive,
            CAST('true' AS BIT) AS ActivateIfPossible,
            UPPER(LTRIM(RTRIM(RawData.Descripcion_Ecommerce))) AS Name,
            LTRIM(RTRIM(RawData.f120_referencia)) AS RefId,
            LTRIM(RTRIM(RawData.f120_id)) AS Ean,
            10 AS PackagedHeight,
            10 AS PackagedLength,
            10 AS PackagedWidth,
            rawdata.f122_peso AS PackagedWeightKg,
            NULL AS Height,
            NULL AS Length,
            NULL AS Width,
            0 AS WeightKg,
            CAST(0 AS FLOAT) AS CubicWeight,
            CAST('false' AS BIT) AS IsKit,
            REPLACE(CONVERT(VARCHAR, GETDATE(), 102), '.', '-') AS CreationDate,
            NULL AS RewardValue,
            NULL AS EstimatedDateArrival,
            UPPER(LTRIM(RTRIM(RawData.f122_factor))) AS ManufacturerCode,
            1 AS CommercialConditionId,
            'un' AS MeasurementUnit,
            1 AS UnitMultiplier,
            NULL AS ModalType,
            CAST('false' AS BIT) AS KitItensSellApart,
            NULL AS Videos
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    )) AS variante_obj
FROM 
    ProductosFiltrados pf
INNER JOIN 
    OPENROWSET(
    'SQLNCLI11', 
    'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=Pisende;Pwd=Pisende$12$%;',
    '
        WITH ItemsConDescripciones AS (
            SELECT DISTINCT
                i.f120_id,
                i.f120_rowid,
                i.f120_rowid_movto_entidad,
                i.f120_id_grupo_impositivo,
                RTRIM(LTRIM(i.f120_referencia)) AS f120_referencia,
                i.f120_notas,
                RTRIM(LTRIM(i.f120_descripcion)) AS f120_descripcion,
                i.f120_descripcion_corta,
                i.f120_id_tipo_inv_serv,
                i.f120_id_unidad_inventario,
                i.f120_id_unidad_orden,
                MAX(CASE WHEN ic.f125_id_plan = ''C24'' THEN cm.f106_descripcion END) AS DescripcionPlanC24,
                MAX(CASE WHEN ic.f125_id_plan = ''C24'' THEN cm.f106_id END) AS IdCriterioC24,
                MAX(CASE WHEN ic.f125_id_plan = ''C29'' THEN cm.f106_descripcion END) AS DescripcionPlanC29,
                MAX(CASE WHEN ic.f125_id_plan = ''C29'' THEN cm.f106_id END) AS IdCriterioC29,
                MAX(CASE WHEN ic.f125_id_plan = ''C29'' THEN ic.f125_id_plan END) AS f125_id,
                MAX(CASE WHEN ic.f125_id_plan = ''C29'' THEN cm.f106_id END) AS f106_id,
                MAX(CASE WHEN ic.f125_id_plan = ''C29'' THEN cm.f106_descripcion END) AS f106_descripcion,
				u.f122_factor,
				u.f122_peso  * 1000 AS f122_peso
            FROM t120_mc_items i
            INNER JOIN t125_mc_items_criterios ic ON ic.f125_rowid_item = i.f120_rowid AND ic.f125_id_cia = 1
            INNER JOIN t106_mc_criterios_item_mayores cm ON cm.f106_id_cia = ic.f125_id_cia 
                                                    AND cm.f106_id_plan = ic.f125_id_plan
                                                    AND cm.f106_id = ic.f125_id_criterio_mayor
            INNER JOIN t105_mc_criterios_item_planes cp ON cp.f105_id_cia = cm.f106_id_cia 
                                                    AND cp.f105_id = cm.f106_id_plan
			inner join t122_mc_items_unidades u on i.f120_rowid = u.f122_rowid_item and i.f120_id_unidad_orden = u.f122_id_unidad
            WHERE i.f120_id_cia = 1
            AND cp.f105_id IN (''C24'', ''C29'')
            GROUP BY
                i.f120_id,
                i.f120_rowid,
                i.f120_rowid_movto_entidad,
                i.f120_id_grupo_impositivo,
                i.f120_referencia,
                i.f120_notas,
                i.f120_descripcion,
                i.f120_descripcion_corta,
                i.f120_id_tipo_inv_serv,
                i.f120_id_unidad_inventario,
                i.f120_id_unidad_orden,
				u.f122_factor,
				u.f122_peso
        )
        SELECT DISTINCT
            icd.f120_id,
            icd.f120_rowid,
            icd.f120_id_grupo_impositivo,
            icd.f120_referencia,
            icd.f120_notas,
            icd.f120_descripcion,
            icd.f106_descripcion,
            icd.f125_id,
            icd.f106_id,
            icd.f120_descripcion_corta,
            -- Subconsulta para Descripcion Ecommerce
            (SELECT TOP 1 f753_dato_texto
            FROM t750_mm_movto_entidad me
            INNER JOIN t753_mm_movto_entidad_columna mec ON me.f750_rowid = mec.f753_rowid_movto_entidad
            INNER JOIN t743_mm_entidad_atributo ea ON mec.f753_rowid_entidad_atributo = ea.f743_rowid
            WHERE me.f750_rowid = icd.f120_rowid_movto_entidad
            AND ea.f743_etiqueta = ''Descripcion Ecommerce'') AS Descripcion_Ecommerce,
            -- Subconsulta para KeyWords
            (SELECT TOP 1 f753_dato_texto
            FROM t750_mm_movto_entidad me
            INNER JOIN t753_mm_movto_entidad_columna mec ON me.f750_rowid = mec.f753_rowid_movto_entidad
            INNER JOIN t743_mm_entidad_atributo ea ON mec.f753_rowid_entidad_atributo = ea.f743_rowid
            WHERE me.f750_rowid = icd.f120_rowid_movto_entidad
            AND ea.f743_etiqueta = ''KeyWords'') AS KeyWords,
            -- Campos adicionales de C24 y C29
            icd.DescripcionPlanC24,
            icd.IdCriterioC24,
            icd.DescripcionPlanC29,
            icd.IdCriterioC29,
            icd.f120_id_tipo_inv_serv AS TipoInventario,
            icd.f120_id_unidad_inventario AS IdUnidadInventario,
            icd.f120_id_unidad_orden AS IdUnidadOrden,
			f122_factor,
			f122_peso
        FROM ItemsConDescripciones icd
        WHERE icd.DescripcionPlanC29 = ''APLICA''
        AND icd.IdCriterioC24 IN (''1'', ''2'', ''3'', ''4'', ''5'', ''6'', ''7'', ''8'')
        AND icd.f106_descripcion <> ''''
        AND icd.f106_descripcion IS NOT NULL
        AND icd.f106_descripcion <> ''NO APLICA''
        AND icd.f106_id = ''001'';
    '
	) AS RawData ON pf.referencia_producto_erp = CAST(RawData.f120_id AS NVARCHAR)
WHERE NOT EXISTS (
    SELECT * 
    FROM variantes v 
    WHERE v.id_producto_ecommerce = pf.id_producto_ecommerce
		and v.sku_erp = pf.referencia_producto_erp
	)