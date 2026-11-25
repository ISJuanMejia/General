-- ONEILL

DELETE FROM [productos] 
WHERE id_tienda = 2
AND sincronizado = 0

INSERT INTO [dbo].[productos] (
    id_tienda,
    referencia_producto_erp,
    id_producto_ecommerce,
    producto_obj,
    sincronizado,
    fecha_sincronizacion
)
SELECT DISTINCT 
    '2' AS id_tienda,
    SUBSTRING(f120_notas,0,CHARINDEX('|',f120_notas,1)) AS referencia_producto_erp,
    0 AS id_producto_ecommerce,
    JSON_QUERY(CONCAT(
        '{',
        '"Name":"', STRING_ESCAPE(REPLACE(REPLACE(SUBSTRING(f120_notas,(CHARINDEX('|',f120_notas)) + 1, (CHARINDEX('|', f120_notas, CHARINDEX('|', f120_notas) + 1)
					-  (CHARINDEX('|',f120_notas) +1))),'+',''),'"',''), 'json'), '",',
        '"DepartmentId":', '0', ',',
        '"CategoryId":', CONVERT(INT,f106_id), ',',
        '"BrandId":', 2000000, ',',
		'"LinkId":"',STRING_ESCAPE(REPLACE(RIGHT(f120_notas, CHARINDEX('|', REVERSE(f120_notas)) - 1),' ', '-'),'json'),'",',
        '"RefId":"', STRING_ESCAPE(SUBSTRING(f120_notas,0,CHARINDEX('|',f120_notas,1)), 'json'), '",',
        '"IsVisible":true,',
        '"Description":null,',
        '"DescriptionShort":null,',
        '"ReleaseDate":"', FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss'), '",',
        '"KeyWords":null,',
        '"Title":"', STRING_ESCAPE(REPLACE(REPLACE(REPLACE(
					 SUBSTRING(f120_notas, CHARINDEX('|', f120_notas, CHARINDEX('|', f120_notas) + 1) + 1,
					 		  CHARINDEX('|', f120_notas, CHARINDEX('|', f120_notas, CHARINDEX('|', f120_notas) + 1) + 1) - 
					 		  (CHARINDEX('|', f120_notas, CHARINDEX('|', f120_notas) + 1) + 1)
					 ) + ' ' + 
					 SUBSTRING(f120_notas, 0, CHARINDEX('|', f120_notas, 1)),
					 CHAR(10), ''), CHAR(13), ''), '  ', ' '), 'json'), '",',
        '"IsActive":false,',
        '"TaxCode":null,',
        '"MetaTagDescription":"', STRING_ESCAPE(REPLACE(REPLACE(REPLACE(
								  SUBSTRING(f120_notas, CHARINDEX('|', f120_notas, CHARINDEX('|', f120_notas) + 1) + 1,
								  		  CHARINDEX('|', f120_notas, CHARINDEX('|', f120_notas, CHARINDEX('|', f120_notas) + 1) + 1) - 
								  		  (CHARINDEX('|', f120_notas, CHARINDEX('|', f120_notas) + 1) + 1)
								  ) + ' ' + 
								  SUBSTRING(f120_notas, 0, CHARINDEX('|', f120_notas, 1)),
								  CHAR(10), ''), CHAR(13), ''), '  ', ' '), 'json'), '",',
        '"SupplierId":null,',
        '"ShowWithoutStock":false,',
        '"AdWordsRemarketingCode":null,',
        '"LomadeeCampaignCode":null,',
        '"Score":null',
        '}'
    ))                AS producto_obj,
    0                  AS sincronizado,
    GETDATE()          AS fecha_sincronizacion
FROM (
    SELECT 
				 f120_id						
				,f120_rowid	
				,f120_id_grupo_impositivo				
				,RTRIM(LTRIM(f120_referencia))	AS f120_referencia
				,f120_notas
				,RTRIM(LTRIM(f120_descripcion)) AS f120_descripcion
				,RTRIM(LTRIM(f106_descripcion))	AS f106_descripcion					
				,f125_id_plan					AS f125_id				
	FROM		[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t105_mc_criterios_item_planes
	INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t106_mc_criterios_item_mayores	ON	f105_id_cia								=	f106_id_cia 
																						AND f105_id									=	f106_id_plan 
	INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t125_mc_items_criterios			ON	f106_id_cia								=	f125_id_cia 
																						AND f106_id_plan							=	f125_id_plan 
																						AND f106_id									=	f125_id_criterio_mayor
	INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t120_mc_items					ON	f125_rowid_item							=	f120_rowid
    --and f120_referencia = '1N00309-0016'
	LEFT JOIN productos ON productos.referencia_producto_erp = SUBSTRING(f120_notas,0,CHARINDEX('|',f120_notas,1)) COLLATE DATABASE_DEFAULT AND productos.id_tienda = 2
    WHERE f120_id_cia = 1  
    AND	  f105_descripcion IN ('ECOMMERCE','MARCA')
    AND productos.referencia_producto_erp IS NULL
	AND	  f120_notas <> ''
) Criterios
	  PIVOT (MAX(f106_descripcion) FOR f125_id IN ([028],[011])) AS FormatoPivotCriterios
INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t125_mc_items_criterios	   			ON	f120_rowid		=	f125_rowid_item 
INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t106_mc_criterios_item_mayores		ON	f106_id_cia		=	f125_id_cia 
																						AND f106_id_plan	=	f125_id_plan 
																						AND f106_id			=	f125_id_criterio_mayor 
INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t105_mc_criterios_item_planes		ON	f106_id_cia		=	f105_id_cia 
																						AND f106_id_plan	=	f105_id 
WHERE f125_id_plan	=	064
AND	  [028]			=	'SI'	
AND	  [011]			=	'ONEILL'