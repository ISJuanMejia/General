
IF OBJECT_ID('tempdb..##ppal') IS NOT NULL DROP TABLE ##ppal;
IF OBJECT_ID('tempdb..##variants') IS NOT NULL DROP TABLE ##variants;
IF OBJECT_ID('tempdb..#productoEcomerce') IS NOT NULL DROP TABLE #productoEcomerce;

DECLARE	@conexion VARCHAR(200),
		@bd       VARCHAR(100);
SELECT TOP 1 
		@conexion = cadena_conexion,
		@bd       = base_datos
FROM conexiones



EXEC ('
SELECT	 
	DISTINCT ltrim(rtrim(v121_descripcion)) as v121_descripcion,
	f150_id,
    v121_id_ext1_detalle,
	v121_id_ext2_detalle,
	v121_id_cia,
	v121_rowid_item,
	v121_id_barras_principal,
	cantidad
INTO ##ppal
FROM OPENROWSET(
    ''sqlncli'',
    '''+@conexion+''',
    ''SELECT 
			top 2 ltrim(rtrim(v121_descripcion)) as v121_descripcion,
			f150_id,
			v121_id_ext1_detalle,
			v121_id_ext2_detalle,
			v121_id_cia,
			v121_rowid_item,
			v121_id_barras_principal,
			ISNULL(f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1),0) AS cantidad
	
		FROM v121
		INNER JOIN t400_cm_existencia ON v121.v121_rowid_item_ext = t400_cm_existencia.f400_rowid_item_ext
		INNER JOIN t150_mc_bodegas    ON f400_rowid_bodega = f150_rowid 
		AND f400_id_cia      = f150_id_cia
		WHERE v121_id_barras_principal IS NOT NULL
	''
) AS v121
inner join variantes v on ltrim(rtrim(v121.v121_id_barras_principal))<>v.sku_erp
where v.sku_erp is not null 
')
--and isnumeric(v.sku_erp)=1
SELECT * FROM ##ppal

exec( N'
SELECT DISTINCT 
    MIN(f117_descripcion) AS option1,
    MIN(f119_descripcion) AS option2,
    T126.f126_precio AS price,
    v121_id_barras_principal AS sku,
    v121_id_barras_principal AS barcode,
    ''true'' AS tracked,
    v121_rowid_item,
    cantidad
into ##variants
FROM ##ppal
LEFT JOIN OPENROWSET(
    ''sqlncli'', 
    '''+@conexion+''',
    ''SELECT f117_id, f117_id_cia, f117_descripcion 
      FROM ['+@bd+'].[dbo].t117_mc_extensiones1_detalle''
) AS T117 ON v121_id_ext1_detalle = T117.f117_id AND v121_id_cia = T117.f117_id_cia
LEFT JOIN OPENROWSET(
    ''sqlncli'', 
    '''+@conexion+''',
    ''SELECT f119_id, f119_id_cia, f119_descripcion 
      FROM ['+@bd+'].[dbo].t119_mc_extensiones2_detalle''
) AS T119 ON v121_id_ext2_detalle = T119.f119_id AND v121_id_cia = T119.f119_id_cia 
           AND T119.f119_descripcion != ''[NO APLICA]''
LEFT JOIN (
    SELECT f126_rowid_item, MAX(f126_fecha_ts_actualizacion) AS f126_fecha_ts_actualizacion
    FROM OPENROWSET(
        ''sqlncli'',
        '''+@conexion+''',
        ''SELECT f126_rowid_item, f126_fecha_ts_actualizacion, f126_id_lista_precio 
          FROM t126_mc_items_precios 
          WHERE f126_id_lista_precio = ''''P01''''
          GROUP BY f126_rowid_item, f126_fecha_ts_actualizacion,f126_id_lista_precio''
    ) AS tempPrice
    GROUP BY f126_rowid_item
) AS TempPrice ON TempPrice.f126_rowid_item = v121_rowid_item
LEFT JOIN OPENROWSET(
    ''sqlncli'', 
    '''+@conexion+''',
    ''SELECT f126_precio, f126_fecha_ts_actualizacion 
      FROM ['+@bd+'].[dbo].t126_mc_items_precios''
) AS T126 ON T126.f126_fecha_ts_actualizacion = TempPrice.f126_fecha_ts_actualizacion
GROUP BY v121_id_barras_principal, T126.f126_precio, v121_rowid_item, cantidad;
');
 

SELECT ISNULL( ( 
SELECT p.v121_descripcion AS 'product.title',
    p.v121_descripcion AS 'product.body_html',
    'somos filipa' AS 'product.vendor',
    'draft' AS 'product.status',
    (
        SELECT 
            v.option1 AS [option1],
            v.option2 AS [option2],
            isnull(v.price,0) AS [price],
            v.sku AS [sku],
			'true' as taxable,
			'shopify' as inventory_management,
			v.cantidad as inventory_quantity,
            v.barcode AS [barcode],
            v.tracked AS [tracked]
        FROM ##variants v
        WHERE v.v121_rowid_item = p.v121_rowid_item
        FOR JSON PATH
    ) AS 'product.variants',
    (
        SELECT 
            [name],
            JSON_QUERY('[' + STRING_AGG('"' + [value] + '"', ',') + ']') AS [values]
        FROM (
            SELECT DISTINCT 'Color' AS [name], v.option1 AS [value]
            FROM ##variants v
            WHERE v.v121_rowid_item = p.v121_rowid_item and (v.option1 is not null or v.option1 <> '')
            UNION ALL
            SELECT DISTINCT 'Talla' AS [name], v.option2 AS [value]
            FROM ##variants v
            WHERE v.v121_rowid_item = p.v121_rowid_item and (v.option2 is not null or v.option2 <> '')
        ) AS options_union
        GROUP BY [name]
        FOR JSON PATH
    ) AS 'product.options'
FROM ##ppal p --where v121_rowid_item=1
FOR JSON PATH
--, ROOT('products')
    ), '[]') AS JsonResult;
 
if object_id('tempdb..##ppal') is not null drop table ##ppal;
if object_id('tempdb..##variants') is not null drop table ##variants;
if object_id('tempdb..#productoEcomerce') is not null drop table #productoEcomerce;
