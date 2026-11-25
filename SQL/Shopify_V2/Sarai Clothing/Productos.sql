IF OBJECT_ID('tempdb..#ProductosJSON') IS NOT NULL
    DROP TABLE #ProductosJSON;
IF OBJECT_ID('tempdb..#ProductosRefs') IS NOT NULL
    DROP TABLE #ProductosRefs;

DECLARE @product_vendor         NVARCHAR(10)    =   'Sarai'
DECLARE @product_default_status NVARCHAR(10)    =   'draft'
DECLARE @InventoryManagement    NVARCHAR(10)    =   'shopify'
DECLARE @TipoExtension1         VARCHAR(5)      =   'Talla'
DECLARE @TipoExtension2         VARCHAR(5)      =   'Color'

SELECT Distinct
    SUBSTRING(JSON_VALUE(producto_obj, '$.variants[0].sku'),1,CHARINDEX('-',JSON_VALUE(producto_obj, '$.variants[0].sku'))-1) AS sku
INTO #ProductosRefs
FROM productos
where JSON_VALUE(producto_obj, '$.variants[0].sku') like '%-%';

;WITH UltimosPrecios AS (
    SELECT 
        f126_rowid_item,
        f126_rowid_item_ext,
        f126_precio,
        ROW_NUMBER() OVER (
            PARTITION BY f126_rowid_item, f126_rowid_item_ext 
            ORDER BY f126_fecha_ts_actualizacion DESC
        ) AS rn
    FROM REALSARAI.dbo.t126_mc_items_precios
	where f126_id_lista_precio = '003'
)
SELECT TOP 50
    JSON_QUERY(
        (
            SELECT
                [product.title]     =   f120_descripcion,
                [product.body_html] =   f120_descripcion,
                [product.vendor]    =   @product_vendor,
                [product.status]    =   @product_default_status,
                [product.variants] =
                (
                    SELECT 
                        
                        [option1] = CASE WHEN TRIM(f117_descripcion) != 'NO APLICA' THEN TRIM(f117_descripcion) ELSE '' END,
						[option2] = CASE WHEN TRIM(f119_id) != 'NO APLICA' THEN dbo.fn_QuitarCeroInicial(TRIM(f119_id))  ELSE '' END,
                        [price]   = p.f126_precio,
                        [sku]     = TRIM(t120.f120_referencia) + '-' 
                                    + dbo.fn_QuitarCeroInicial(TRIM(t121_variantes.f121_id_ext2_detalle)) + '/' 
                                    + TRIM(f117_descripcion),
                        [inventory_management] = @InventoryManagement
                    FROM REALSARAI.dbo.t121_mc_items_extensiones t121_variantes
                    INNER JOIN REALSARAI.dbo.t117_mc_extensiones1_detalle t117 ON t117.f117_id = t121_variantes.f121_id_ext1_detalle AND t117.f117_id_cia = t121_variantes.f121_id_cia
                    INNER JOIN REALSARAI.dbo.t119_mc_extensiones2_detalle t119 ON t119.f119_id = t121_variantes.f121_id_ext2_detalle AND t119.f119_id_cia = t121_variantes.f121_id_cia
                    INNER JOIN REALSARAI.dbo.t400_cm_existencia t400 ON t400.f400_rowid_item_ext = t121_variantes.f121_rowid
                    INNER JOIN REALSARAI.dbo.t150_mc_bodegas t150 ON t150.f150_rowid = t400.f400_rowid_bodega
                    LEFT JOIN UltimosPrecios p ON (p.f126_rowid_item = f120_rowid OR p.f126_rowid_item_ext = t121_variantes.f121_rowid) AND p.rn = 1
                    WHERE f121_rowid_item = f120_rowid
                      AND t150.f150_id = 'BOWB'
					--  AND f400_cant_existencia_1 > 0
                    FOR JSON PATH
                ),
               [product.options] =
				(
					SELECT
						v.[name],
						[position],
						[values] = JSON_QUERY(
							'[' + STRING_AGG('"' + v.[value] + '"', ',') WITHIN GROUP (
								ORDER BY CAST(
									CASE 
										WHEN ISNUMERIC(v.[value]) = 1 THEN v.[value] 
										ELSE '999' -- Para valores no numéricos
									END AS INT
								)
							) + ']'
						)
					FROM (
						SELECT DISTINCT
							@TipoExtension1 AS [name],
							2 AS [position] ,
							dbo.fn_QuitarCeroInicial(LTRIM(RTRIM(f119_id))) AS [value]
						FROM REALSARAI.dbo.t121_mc_items_extensiones t121_ext1
						INNER JOIN REALSARAI.dbo.t117_mc_extensiones1_detalle ON f117_id = f121_id_ext1_detalle  AND f117_id_cia = f121_id_cia
						INNER JOIN REALSARAI.dbo.t119_mc_extensiones2_detalle ON f119_id = f121_id_ext2_detalle AND f119_id_cia = f121_id_cia
						INNER JOIN REALSARAI.dbo.t400_cm_existencia t400 ON t400.f400_rowid_item_ext = t121_ext1.f121_rowid
						INNER JOIN REALSARAI.dbo.t150_mc_bodegas t150 ON t150.f150_rowid = t400.f400_rowid_bodega
						WHERE f121_rowid_item = f120_rowid
						  AND TRIM(f119_descripcion) NOT IN ('', 'NO APLICA')
						  AND t150.f150_id = 'BOWB'
						--  AND f400_cant_existencia_1 > 0

						UNION ALL

						SELECT DISTINCT
							@TipoExtension2 AS [name],
							1 AS [position],
							f117_descripcion AS [value]
						FROM REALSARAI.dbo.t121_mc_items_extensiones t121_ext2
						INNER JOIN REALSARAI.dbo.t117_mc_extensiones1_detalle  ON f117_id = f121_id_ext1_detalle AND f117_id_cia = f121_id_cia
						INNER JOIN REALSARAI.dbo.t400_cm_existencia t400 ON t400.f400_rowid_item_ext = t121_ext2.f121_rowid
						INNER JOIN REALSARAI.dbo.t150_mc_bodegas t150 ON t150.f150_rowid = t400.f400_rowid_bodega
						WHERE f121_rowid_item = f120_rowid
						  AND TRIM(f117_descripcion) NOT IN ('', 'NO APLICA')
						  AND t150.f150_id = 'BOWB'
						--  AND f400_cant_existencia_1 > 0
					) v
					GROUP BY v.[name],[position]
					FOR JSON PATH
				)
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    ) AS ProductJSON
FROM REALSARAI.dbo.t120_mc_items AS t120
INNER JOIN REALSARAI.dbo.t121_mc_items_extensiones ON f120_rowid = f121_rowid_item
INNER JOIN REALSARAI.dbo.t400_cm_existencia ON f121_rowid = f400_rowid_item_ext	
INNER JOIN REALSARAI.dbo.t150_mc_bodegas ON f150_rowid = f400_rowid_bodega
WHERE f150_id = 'BOWB'
  AND f120_id_tipo_inv_serv = 'INVPT'
 -- and f120_referencia like '%ASP00251%' --  ASP00300 
--  AND f400_cant_existencia_1 > 0
  AND 
  NOT  EXISTS (
    SELECT 1
    FROM #ProductosRefs r
    WHERE r.sku = TRIM(t120.f120_referencia)
  )
GROUP BY f120_rowid, f120_descripcion, f120_referencia;


