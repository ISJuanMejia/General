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
    TRIM(criterio_14) AS referencia_producto_erp,
    0 AS id_producto_ecommerce,
    0 AS sincronizado,
    GETDATE() AS fecha_sincronizacion,
	JSON_QUERY(( 
        SELECT 
            Nombre_Comercial_Clean AS Name,
			1 AS DepartmentId,
			Categoria_Clean AS CategoryId,
			Marca_Clean AS BrandId,
			'' AS LinkId,
			Referencia_Clean AS RefId,
			CAST(0 AS BIT) AS IsVisible,
			'' AS Description,
			'' AS DescriptionShort,
			Fecha_Release_Clean AS ReleaseDate,
			'' AS KeyWords,
			'' AS Title,
			CAST(0 AS BIT) AS IsActive,
			'' AS TaxCode,
			'' AS MetaTagDescription,
			1 AS SupplierId,
			CAST(0 AS BIT) AS ShowWithoutStock,
			null AS AdWordsRemarketingCode,
			null AS LomadeeCampaignCode,
			1 AS Score
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    )) AS producto_obj
FROM (
    SELECT *,
        -- Limpieza de campos
        STRING_ESCAPE(REPLACE(ISNULL(descripcion_criterio_14, ''), '/', '-'), 'json') AS Nombre_Comercial_Clean,
        CAST(Categoria AS NUMERIC) AS Categoria_Clean,
        CAST(Marca AS NUMERIC) AS Marca_Clean,
        STRING_ESCAPE(TRIM(ISNULL(criterio_14, '')), 'json') AS Referencia_Clean,
        FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss') AS Fecha_Release_Clean
    FROM OPENROWSET(
        'SQLNCLI11', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Comercbd_Real;Uid=Comercbd;Pwd=Comercbd$12$%;',
        '
			SELECT DISTINCT
				f120_referencia,
				f121_id_barras_principal,
				-- Criterio 14
				c14.f125_id_criterio_mayor AS criterio_14,
				c14d.f106_descripcion      AS descripcion_criterio_14,
				-- Categoria y Marca
				MAX(CASE WHEN ea.f743_etiqueta = ''Categoria''
						 THEN md.f741_id END) AS Categoria,
				MAX(CASE WHEN ea.f743_etiqueta = ''Marca''
						 THEN md.f741_id END) AS Marca
			FROM t120_mc_items i
			INNER JOIN t121_mc_items_extensiones ON i.f120_rowid = f121_rowid_item
			-- Criterio integración (Plan 013)
			INNER JOIN t125_mc_items_criterios c13
				ON c13.f125_rowid_item = i.f120_rowid
			   AND c13.f125_id_plan = ''013''
			   AND c13.f125_id_criterio_mayor = ''0001''
			   AND c13.f125_id_cia = i.f120_id_cia
			-- Criterio 14
			INNER JOIN t125_mc_items_criterios c14
				ON c14.f125_rowid_item = i.f120_rowid
			   AND c14.f125_id_plan = ''014''
			   AND c14.f125_id_cia = i.f120_id_cia
			INNER JOIN t106_mc_criterios_item_mayores c14d
				ON c14d.f106_id_plan = c14.f125_id_plan
			   AND c14d.f106_id = c14.f125_id_criterio_mayor
			   AND c14d.f106_id_cia = c14.f125_id_cia
			-- Atributos solo para Categoria y Marca
			LEFT JOIN t750_mm_movto_entidad me
				ON me.f750_rowid = i.f120_rowid_movto_entidad
			   AND me.f750_id_cia = i.f120_id_cia
			LEFT JOIN t753_mm_movto_entidad_columna mec
				ON mec.f753_rowid_movto_entidad = me.f750_rowid
			   AND mec.f753_id_cia = me.f750_id_cia
			LEFT JOIN t743_mm_entidad_atributo ea
				ON ea.f743_rowid = mec.f753_rowid_entidad_atributo
			   AND ea.f743_id_cia = mec.f753_id_cia
			LEFT JOIN t741_mm_maestro_detalle md
				ON md.f741_rowid = mec.f753_rowid_maestro_detalle
			   AND md.f741_id_cia = mec.f753_id_cia
			   AND ea.f743_etiqueta IN (''Categoria'', ''Marca'')
			WHERE i.f120_id_cia = 1
			-- Ecommerce
			AND EXISTS (
				SELECT 1
				FROM t745_mm_grupo_entidad_relacion ger
				INNER JOIN t744_mm_grupo_entidad ge
					ON ge.f744_rowid = ger.f745_rowid_grupo_entidad
				   AND ge.f744_id = ''Ecommerce''
				WHERE ger.f745_rowid_entidad = ea.f743_rowid_entidad
				  AND ger.f745_id_cia = i.f120_id_cia
			)
			-- Tienda Vtex = Si
			AND EXISTS (
				SELECT 1
				FROM t753_mm_movto_entidad_columna vtex
				INNER JOIN t743_mm_entidad_atributo a
					ON a.f743_rowid = vtex.f753_rowid_entidad_atributo
				   AND a.f743_etiqueta = ''Tienda Vtex''
				WHERE vtex.f753_rowid_movto_entidad = me.f750_rowid
				  AND vtex.f753_dato_texto = ''Si''
				  AND vtex.f753_id_cia = i.f120_id_cia
			)
			GROUP BY
				c14.f125_id_criterio_mayor,
				c14d.f106_descripcion,
				f121_id_barras_principal,
				f120_referencia
        '
    ) AS Raw
) AS RawData
WHERE NOT EXISTS (      
        SELECT 1 FROM variantes v WHERE v.sku_erp = f121_id_barras_principal 
								OR REPLACE(UPPER(JSON_VALUE(variante_obj,'$.RefId')),' ','') LIKE '%' + REPLACE(UPPER(f120_referencia),' ','') + '%'
)
AND ISNULL(descripcion_criterio_14, '') <> ''
AND ISNULL(Categoria, '') <> ''
AND ISNULL(Marca, '') <> ''