INSERT INTO [dbo].[productos]
(
    id_tienda,
    referencia_producto_erp,
    id_producto_ecommerce,
    sincronizado,
    fecha_sincronizacion,
    producto_obj
)

SELECT DISTINCT
            '1' AS id_tienda,
			f120_id AS referencia_producto_erp,
			0 AS id_producto_ecommerce,
			0 AS sincronizado,
			GETDATE() AS fecha_sincronizacion,
            JSON_QUERY(
                CONCAT(
                    '{' ,
                        '"Name":"', STRING_ESCAPE(REPLACE(ISNULL(Descripcion_Ecommerce, ''), '/', '-'), 'json'), '",',
                        '"DepartmentId":', 1, ',',
                        '"CategoryId":', IdCriterioC24, ',',
                        '"BrandId":', DescripcionPlanC34, ',',
                        '"LinkId":"', STRING_ESCAPE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(
                                        REPLACE(
                                            REPLACE(
                                                REPLACE(
                                                    LOWER(ISNULL(Descripcion_Ecommerce, '')), 
														'/', '-'),
													' ', '-'),
												',', ''), 
											'.', ''), 
										'(', ''), 
									')', ''), 'json'), '",',
                        '"RefId":"', STRING_ESCAPE(ISNULL(f120_referencia, ''), 'json'), '",',
                        '"IsVisible":', 'true', ',',
                        '"Description":"",',
                        '"DescriptionShort":"",',
                        '"ReleaseDate":"', FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss'), '",',
                        '"KeyWords":"",',
                        '"Title":"",',
                        '"IsActive":', 'true', ',',
                        '"TaxCode":', 'null', ',',
                        '"MetaTagDescription":"",',  
                        '"ShowWithoutStock":', 'false', ',',
                        '"Score":', 1,
                    '}'
        )
    ) AS producto_obj
FROM OPENROWSET(
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
			RTRIM(LTRIM(i.f120_descripcion)) AS f120_descripcion,
			i.f120_descripcion_corta,
			i.f120_id_tipo_inv_serv,
			i.f120_id_unidad_inventario,
			i.f120_id_unidad_orden,
			MAX(CASE WHEN ic.f125_id_plan = ''C24'' AND cm.f106_descripcion IS NOT NULL 
					 THEN cm.f106_descripcion END) AS DescripcionPlanC24,
			MAX(CASE WHEN ic.f125_id_plan = ''C24'' AND cm.f106_id IS NOT NULL 
					 THEN cm.f106_id END) AS IdCriterioC24,
			MAX(CASE WHEN ic.f125_id_plan = ''C29'' AND cm.f106_descripcion IS NOT NULL 
					 THEN cm.f106_descripcion END) AS DescripcionPlanC29,
			MAX(CASE WHEN ic.f125_id_plan = ''C29'' AND cm.f106_id IS NOT NULL 
					 THEN cm.f106_id END) AS IdCriterioC29,
			MAX(CASE WHEN ic.f125_id_plan = ''C29'' AND ic.f125_id_plan IS NOT NULL 
					 THEN ic.f125_id_plan END) AS f125_id,
			MAX(CASE WHEN ic.f125_id_plan = ''C29'' AND cm.f106_id IS NOT NULL 
					 THEN cm.f106_id END) AS f106_id,
			MAX(CASE WHEN ic.f125_id_plan = ''C29'' AND cm.f106_descripcion IS NOT NULL 
					 THEN cm.f106_descripcion END) AS f106_descripcion,
			MAX(CASE WHEN ic.f125_id_plan = ''C34'' AND cm.f106_descripcion IS NOT NULL 
					 THEN SUBSTRING(cm.f106_descripcion,1,7) END) AS DescripcionPlanC34,
			MAX(CASE WHEN ic.f125_id_plan = ''C34'' AND cm.f106_id IS NOT NULL 
					 THEN cm.f106_id END) AS IdCriterioC34
		FROM t120_mc_items i
		INNER JOIN t125_mc_items_criterios ic ON ic.f125_rowid_item = i.f120_rowid 
			AND ic.f125_id_cia = 1
			AND ic.f125_id_plan IN (''C24'', ''C29'',''C34'')  -- Filtro temprano
		INNER JOIN t106_mc_criterios_item_mayores cm ON cm.f106_id_cia = ic.f125_id_cia 
			AND cm.f106_id_plan = ic.f125_id_plan
			AND cm.f106_id = ic.f125_id_criterio_mayor
		INNER JOIN t105_mc_criterios_item_planes cp ON cp.f105_id_cia = cm.f106_id_cia 
			AND cp.f105_id = cm.f106_id_plan
			AND cp.f105_id IN (''C24'', ''C29'',''C34'')  -- Filtro temprano
		WHERE i.f120_id_cia = 1
		GROUP BY
			i.f120_id,
			i.f120_rowid,
			i.f120_rowid_movto_entidad,
			i.f120_id_grupo_impositivo,
			i.f120_referencia,
			i.f120_descripcion,
			i.f120_descripcion_corta,
			i.f120_id_tipo_inv_serv,
			i.f120_id_unidad_inventario,
			i.f120_id_unidad_orden
	),
	-- CTE para centralizar las subconsultas de atributos e-commerce
	EcommerceData AS (
		SELECT DISTINCT
			me.f750_rowid,
			MAX(CASE WHEN ea.f743_etiqueta = ''Descripcion Ecommerce'' 
					 THEN mec.f753_dato_texto END) AS Descripcion_Ecommerce,
			MAX(CASE WHEN ea.f743_etiqueta = ''Detalle Ecommerce'' 
					 THEN mec.f753_dato_texto END) AS Detalle_Ecommerce,
			MAX(CASE WHEN ea.f743_etiqueta = ''KeyWords''
					 THEN mec.f753_dato_texto END) AS KeyWords,
			MAX(CASE WHEN ea.f743_etiqueta = ''Titulo SEO''
					 THEN mec.f753_dato_texto END) AS Titulo_SEO,
			MAX(CASE WHEN ea.f743_etiqueta = ''Metadescripcion''
					 THEN mec.f753_dato_texto END) AS Metadescripcion
		FROM t750_mm_movto_entidad me
		INNER JOIN t753_mm_movto_entidad_columna mec ON me.f750_rowid = mec.f753_rowid_movto_entidad
		INNER JOIN t743_mm_entidad_atributo ea ON mec.f753_rowid_entidad_atributo = ea.f743_rowid
		WHERE ea.f743_etiqueta IN (''Descripcion Ecommerce'', ''Detalle Ecommerce'', ''KeyWords'', ''Titulo SEO'',''Metadescripcion'')
		GROUP BY me.f750_rowid
	)
	-- Consulta principal
	SELECT DISTINCT
		icd.f120_id,
		icd.f120_rowid,
		icd.f120_id_grupo_impositivo,
		icd.f120_referencia,
		icd.f120_descripcion,
		icd.f106_descripcion,
		icd.f125_id,
		icd.f106_id,
		icd.f120_descripcion_corta,
		ed.Descripcion_Ecommerce,
		ed.Detalle_Ecommerce,
		ed.KeyWords,
		ed.Titulo_SEO,
		ed.Metadescripcion,
		icd.DescripcionPlanC24,
		icd.IdCriterioC24,
		icd.DescripcionPlanC29,
		icd.IdCriterioC29,
		icd.f120_id_tipo_inv_serv AS TipoInventario,
		icd.f120_id_unidad_inventario AS IdUnidadInventario,
		icd.f120_id_unidad_orden AS IdUnidadOrden,
		icd.DescripcionPlanC34,
		icd.IdCriterioC34
	FROM ItemsConDescripciones icd
	LEFT JOIN EcommerceData ed ON ed.f750_rowid = icd.f120_rowid_movto_entidad
	WHERE icd.DescripcionPlanC29 = ''APLICA''
		AND icd.IdCriterioC24 IN (''1'', ''2'', ''3'', ''4'', ''5'', ''6'', ''7'', ''8'')
		AND icd.f106_descripcion IS NOT NULL
		AND icd.f106_descripcion <> ''''
		AND icd.f106_descripcion <> ''NO APLICA''
		AND DescripcionPlanC34 IS NOT NULL
		AND (ISNUMERIC(icd.DescripcionPlanC34) = 1 AND LEN(icd.DescripcionPlanC34)=7)
		--AND f120_id IN (''5901602'',''5901606'',''5901612'')
    '
) AS RawData
WHERE NOT EXISTS
(
    SELECT 1
    FROM productos p
    WHERE p.id_tienda = 1
      AND
      (
          p.referencia_producto_erp = CAST(RawData.f120_id AS NVARCHAR)
         OR
          LTRIM(RTRIM(
              JSON_VALUE(
                  p.producto_obj,'$.RefId'))) =LTRIM(RTRIM(RawData.f120_referencia ))
      )
)
AND ISNULL(
        RawData.Descripcion_Ecommerce,'') <> '';
