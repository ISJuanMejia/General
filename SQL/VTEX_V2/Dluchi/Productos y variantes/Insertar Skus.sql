WITH ProductosFiltrados AS (
    SELECT 
        id_tienda,
        id_producto_ecommerce,
        referencia_producto_erp
    FROM 
        productos
    WHERE 
        id_tienda = 1
        AND sincronizado = 1
)

INSERT INTO [dbo].[variantes] (
	id_tienda,
    id_producto_ecommerce, 
    id_variante_ecommerce, 
    sku_erp, 
    variante_obj, 
    sincronizado, 
    fecha_sincronizacion
)
SELECT 
	pf.id_tienda,
    pf.id_producto_ecommerce,
    0										AS id_variante_ecommerce, 
    LTRIM(RTRIM(f121_id_barras_principal))	AS sku_erp,
    JSON_QUERY(( 
        SELECT 
            pf.id_producto_ecommerce AS ProductId,
            CAST('false' AS BIT) AS IsActive,
            CAST('true' AS BIT) AS ActivateIfPossible,
            UPPER(erp.nombre_extension) AS Name,
            LTRIM(RTRIM(erp.f120_referencia)) AS RefId,
            LTRIM(RTRIM(erp.f121_id_barras_principal)) AS Ean,
            10 AS PackagedHeight,
            10 AS PackagedLength,
            10 AS PackagedWidth,
            10 AS PackagedWeightKg,
            NULL AS Height,
            NULL AS Length,
            NULL AS Width,
            NULL AS WeightKg,
            CAST(0 AS FLOAT) AS CubicWeight,
            CAST('false' AS BIT) AS IsKit,
            REPLACE(CONVERT(VARCHAR, GETDATE(), 102), '.', '-') AS CreationDate,
            NULL AS RewardValue,
            NULL AS EstimatedDateArrival,
            '123' AS ManufacturerCode,
            1 AS CommercialConditionId,
            'un' AS MeasurementUnit,
            1 AS UnitMultiplier,
            NULL AS ModalType,
            CAST('false' AS BIT) AS KitItensSellApart,
            NULL AS Videos
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )) AS variante_obj,
    CAST(0 AS BIT) AS sincronizado, 
    GETDATE() AS fecha_sincronizacion
FROM ProductosFiltrados pf 
INNER JOIN OPENROWSET(
        'SQLNCLI11', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Comercbd_Real;Uid=Comercbd;Pwd=Comercbd$12$%;',
        'SELECT	i.f120_id_cia,
				c14.f125_id_criterio_mayor AS criterio_padre,
				c14d.f106_descripcion AS descripcion_criterio_padre,
				i.f120_referencia,
				e.f121_id_barras_principal,
				UPPER(CONCAT(
					MAX(CASE WHEN ea.f743_etiqueta = ''Nombre Comercial'' THEN mec.f753_dato_texto END),
					'' '', f117.f117_descripcion, '' '', f119.f119_descripcion
				)) AS nombre_extension,  
				MAX(CASE WHEN ea.f743_etiqueta = ''Categoria'' THEN md.f741_id END) AS Categoria,
				MAX(CASE WHEN ea.f743_etiqueta = ''Marca'' THEN md.f741_id END) AS Marca
			FROM t120_mc_items i
			INNER JOIN t121_mc_items_extensiones e ON i.f120_rowid = e.f121_rowid_item AND e.f121_id_cia = 1
			INNER JOIN t125_mc_items_criterios c13 ON c13.f125_rowid_item = i.f120_rowid AND c13.f125_id_plan = ''013'' AND c13.f125_id_criterio_mayor = ''0001'' AND c13.f125_id_cia = 1
			INNER JOIN t125_mc_items_criterios c14 ON c14.f125_rowid_item = i.f120_rowid AND c14.f125_id_plan = ''014'' AND c14.f125_id_cia = 1
			INNER JOIN t106_mc_criterios_item_mayores c14d ON c14d.f106_id_plan = ''014'' AND c14d.f106_id = c14.f125_id_criterio_mayor AND c14d.f106_id_cia = 1
			LEFT JOIN t750_mm_movto_entidad me ON me.f750_rowid = i.f120_rowid_movto_entidad AND me.f750_id_cia = 1
			LEFT JOIN t753_mm_movto_entidad_columna mec ON mec.f753_rowid_movto_entidad = me.f750_rowid AND mec.f753_id_cia = 1
			LEFT JOIN t743_mm_entidad_atributo ea ON ea.f743_rowid = mec.f753_rowid_entidad_atributo AND ea.f743_id_cia = 1 AND ea.f743_etiqueta IN (''Categoria'', ''Marca'', ''Nombre Comercial'')
			LEFT JOIN t741_mm_maestro_detalle md ON md.f741_rowid = mec.f753_rowid_maestro_detalle AND md.f741_id_cia = 1
			LEFT JOIN t117_mc_extensiones1_detalle f117 ON e.f121_id_extension1 = f117.f117_id_extension1 AND e.f121_id_ext1_detalle = f117.f117_id
			LEFT JOIN t119_mc_extensiones2_detalle f119 ON e.f121_id_extension2 = f119.f119_id_extension2 AND e.f121_id_ext2_detalle = f119.f119_id
			WHERE i.f120_id_cia = 1
			AND EXISTS (
				SELECT 1 FROM t745_mm_grupo_entidad_relacion ger
				INNER JOIN t744_mm_grupo_entidad ge ON ge.f744_rowid = ger.f745_rowid_grupo_entidad AND ge.f744_id = ''Ecommerce''
				WHERE ger.f745_rowid_entidad = ea.f743_rowid_entidad AND ger.f745_id_cia = 1
			)
			AND EXISTS (
				SELECT 1 FROM t753_mm_movto_entidad_columna vtex
				INNER JOIN t743_mm_entidad_atributo a ON a.f743_rowid = vtex.f753_rowid_entidad_atributo AND a.f743_etiqueta = ''Tienda Vtex''
				WHERE vtex.f753_rowid_movto_entidad = me.f750_rowid AND vtex.f753_dato_texto = ''Si'' AND vtex.f753_id_cia = 1
			)
			GROUP BY i.f120_id_cia,i.f120_referencia, e.f121_id_barras_principal, f117.f117_descripcion, f119.f119_descripcion, c14.f125_id_criterio_mayor, c14d.f106_descripcion
		'
) erp on erp.criterio_padre = pf.referencia_producto_erp
where not exists (
	select 1 from variantes v where v.sku_erp = erp.f121_id_barras_principal
)
and erp.f120_id_cia = 1
AND erp.f121_id_barras_principal IS NOT NULL