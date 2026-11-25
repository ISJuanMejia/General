
IF OBJECT_ID('tempdb..#ProductosFiltrados') IS NOT NULL
    DROP TABLE #ProductosFiltrados;

IF OBJECT_ID('tempdb..#variantes') IS NOT NULL
    DROP TABLE #variantes;

SELECT 
    id_tienda,
    id_producto_ecommerce,
    referencia_producto_erp
INTO #ProductosFiltrados
FROM productos
WHERE id_tienda = 1 AND sincronizado = 1


SELECT DISTINCT
	v121_id_extension1,
	v121_id_ext1_detalle,
	v121_rowid_item,
	v121_id_barras_principal,
	v121_referencia,
	v121_id_ext2_detalle,
	pf.id_producto_ecommerce,
	pf.id_tienda
INTO #variantes
FROM  variantes
RIGHT JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].dbo.v121 ON variantes.sku_erp = v121_id_barras_principal COLLATE DATABASE_DEFAULT AND variantes.id_tienda = 1
RIGHT JOIN #ProductosFiltrados pf ON pf.referencia_producto_erp	= v121_referencia AND v121.v121_id_cia =	1
WHERE v121_id_cia = 1
AND v121_estado_item_ext = 1
AND	sku_erp	IS NULL
AND	v121_id_barras_principal IS NOT NULL

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
	id_tienda,
    id_producto_ecommerce,
    0										AS id_variante_ecommerce, 
    LTRIM(RTRIM(v121_id_barras_principal))	AS sku_erp,
    JSON_QUERY(( 
        SELECT 
            id_producto_ecommerce AS ProductId,
            CAST('false' AS BIT) AS IsActive,
            CAST('true' AS BIT) AS ActivateIfPossible,
            descripcion_color + '-' +	REPLACE( LTRIM(RTRIM(v121_id_ext2_detalle)),'00','Única') AS 'Name',
            LTRIM(RTRIM(v121_referencia)) + '-' +	REPLACE( LTRIM(RTRIM(v121_id_ext2_detalle)),'00','Única') AS RefId,
            LTRIM(RTRIM(v121_id_barras_principal)) AS Ean,
            REPLACE(alto_cm, ',', '.') AS PackagedHeight,
            largo_cm AS PackagedLength,
            ancho_cm AS PackagedWidth,
            REPLACE(peso_kg, ',', '.') AS PackagedWeightKg,
            REPLACE(alto_cm, ',', '.') AS Height,
            largo_cm AS Length,
            ancho_cm AS Width,
            REPLACE(peso_kg, ',', '.') AS WeightKg,
            0 AS CubicWeight,
            CAST('false' AS BIT) AS IsKit,
            REPLACE(CONVERT(VARCHAR, GETDATE(), 102), '.', '-') AS CreationDate,
            0 AS RewardValue,
            '' AS EstimatedDateArrival,
            '0' AS ManufacturerCode,
            1 AS CommercialConditionId,
            'un' AS MeasurementUnit,
            0 AS UnitMultiplier,
            '' AS ModalType,
            CAST('false' AS BIT) AS KitItensSellApart,
            JSON_QUERY('["https://www.youtube.com/"]') AS Videos
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )) AS variante_obj,
    CAST(0 AS BIT) AS sincronizado, 
    GETDATE() AS fecha_sincronizacion
-- select *
FROM  #variantes
LEFT JOIN	[Integracion-Nadar].[dbo].[VTEX-Colores] ON [Integracion-Nadar].[dbo].[VTEX-Colores].codigo_unificado	= v121_id_extension1 + v121_id_ext1_detalle	
INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t125_mc_items_criterios			t125_1 	ON	v121_rowid_item							=	t125_1.f125_rowid_item 
INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t106_mc_criterios_item_mayores	t106_1 	ON	t106_1.f106_id_cia						=	t125_1.f125_id_cia 
																							AND t106_1.f106_id_plan						=	t125_1.f125_id_plan 
																							AND t106_1.f106_id							=	t125_1.f125_id_criterio_mayor 
INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t105_mc_criterios_item_planes	t105_1	ON	t106_1.f106_id_cia						=	t105_1.f105_id_cia 
																							AND t106_1.f106_id_plan						=	t105_1.f105_id 
INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t125_mc_items_criterios			t125_2 	ON	v121_rowid_item							=	t125_2.f125_rowid_item 
INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t106_mc_criterios_item_mayores	t106_2 	ON	t106_2.f106_id_cia						=	t125_2.f125_id_cia 
																							AND t106_2.f106_id_plan						=	t125_2.f125_id_plan 
																							AND t106_2.f106_id							=	t125_2.f125_id_criterio_mayor 
INNER JOIN	[LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].t105_mc_criterios_item_planes	t105_2	ON	t106_2.f106_id_cia						=	t105_2.f105_id_cia 
																							AND t106_2.f106_id_plan						=	t105_2.f105_id 
INNER JOIN	[Integracion-Nadar].[dbo].[VTEX-Medidas] ON [Integracion-Nadar].[dbo].[VTEX-Medidas].TipoProducto LIKE '%' + t106_1.f106_id + '%' AND [Integracion-Nadar].[dbo].[VTEX-Medidas].edad LIKE '%' + t106_2.f106_id + '%' 
INNER JOIN	[Integracion-Nadar].[dbo].[VTEX-OrdenTallas] ON [Integracion-Nadar].[dbo].[VTEX-OrdenTallas].talla = v121_id_ext2_detalle
WHERE	Descripcion_Color				IS NOT NULL
AND			Descripcion_Color				<> ''
AND			peso_kg							<> ''
AND			alto_cm							<> ''
AND			ancho_cm						<> ''
AND			largo_cm						<> ''
AND			t105_1.f105_descripcion			= 'TIPO PRODUCTO'
AND			t105_2.f105_descripcion			= 'EDAD'
ORDER BY    id_producto_ecommerce, [Integracion-Nadar].[dbo].[VTEX-OrdenTallas].orden 