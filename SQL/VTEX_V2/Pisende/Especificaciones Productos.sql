INSERT INTO [dbo].[especificaciones_productos] (
    id_tienda, 
    id_producto, 
    id_producto_ecommerce, 
	sincronizado, 
    fecha_sincronizacion,
    especificacione_obj    
)

SELECT 
p.id_tienda,
p.id,
p.id_producto_ecommerce,
0,
GETDATE(),
JSON_QUERY(
	CONCAT(
		'[',
			'{"Value":["',Acabado,'"],"Name":"Acabado"},',
			'{"Value":["',Color,'"],"Name":"Color"},',
			'{"Value":["',REPLACE(Dimensiones, '"', '\"'),'"],"Name":"Dimensiones"},',
			'{"Value":["',Unidad_de_Negocio,'"],"Name":"Unidad de Negocio"},',
			'{"Value":["',Linea,'"],"Name":"LÃ­nea"},',
			'{"Value":["',CategorÃ­a,'"],"Name":"CategorÃ­a"},',
			'{"Value":["',Tipo,'"],"Name":"Tipo"},',
			'{"Value":["',REPLACE(Formatos, '"', '\"'),'"],"Name":"Formatos"},',
			'{"Value":["',Marca,'"],"Name":"Marca"},',
			'{"Value":["',Origen,'"],"Name":"Origen"},',
			'{"Value":["',Unidad_de_Empaque,'"],"Name":"Unidad de Empaque"},',
			'{"Value":["',REPLACE(Estilo, '"', '\"'),'"],"Name":"Estilo"},',
			'{"Value":["',Uso,'"],"Name":"Uso"},',
			'{"Value":["',TrÃ¡fico,'"],"Name":"TrÃ¡fico"},',
			'{"Value":["',Variacion_tono,'"],"Name":"VariaciÃ³n de tono"}',
		']'
		)
	)
FROM OPENROWSET(
    'SQLNCLI11', 
    'Server=siesa-m4-sqlsw-db6.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Pisende_Real;Uid=Pisende;Pwd=Pisende$12$%;',
    '
	SELECT 
	 	t120.f120_id,
	 	t120.f120_referencia,
	 	MAX(CASE WHEN t125B.f125_id_plan = ''C09'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Acabado,
	 	MAX(CASE WHEN t125B.f125_id_plan = ''C10'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Color,
	 	MAX(CASE WHEN t125B.f125_id_plan = ''C08'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Dimensiones,
		MAX(CASE WHEN t125B.f125_id_plan = ''C01'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Unidad_de_Negocio,
		MAX(CASE WHEN t125B.f125_id_plan = ''C04'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Linea,
		MAX(CASE WHEN t125B.f125_id_plan = ''C23'' THEN ISNULL(t106.f106_descripcion,'''') END) AS CategorÃ­a,
	 	MAX(CASE WHEN t125B.f125_id_plan = ''C06'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Tipo,
	 	MAX(CASE WHEN t125B.f125_id_plan = ''C13'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Formatos,
	 	MAX(CASE WHEN t125B.f125_id_plan = ''C17'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Marca,
	 	MAX(CASE WHEN t125B.f125_id_plan = ''C16'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Origen,	
		ISNULL(t101.f101_descripcion,'''') AS Unidad_de_Empaque,
	 	MAX(CASE WHEN t125B.f125_id_plan = ''C07'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Estilo,
	 	MAX(CASE WHEN t125B.f125_id_plan = ''C05'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Uso,
	 	MAX(CASE WHEN t125B.f125_id_plan = ''C12'' THEN ISNULL(t106.f106_descripcion,'''') END) AS TrÃ¡fico,
	 	MAX(CASE WHEN t125B.f125_id_plan = ''C11'' THEN ISNULL(t106.f106_descripcion,'''') END) AS Variacion_tono
	 FROM t120_mc_items t120
	 INNER JOIN t125_mc_items_criterios t125A		
		ON t125A.f125_rowid_item = t120.f120_rowid 
	 	AND t125A.f125_id_cia = 1
	 INNER JOIN t125_mc_items_criterios t125B		
		ON t125B.f125_rowid_item = t120.f120_rowid 
	 	AND t125B.f125_id_cia = 1
	 INNER JOIN t106_mc_criterios_item_mayores t106	
		ON t106.f106_id_cia = t125B.f125_id_cia 
	 	AND t106.f106_id_plan = t125B.f125_id_plan 
	 	AND t106.f106_id = t125B.f125_id_criterio_mayor
		AND f106_id_cia = 1
	 INNER JOIN t122_mc_items_unidades t122 
		ON t120.f120_rowid = t122.f122_rowid_item 
		AND f122_id_cia = 1
		AND t120.f120_id_unidad_orden = t122.f122_id_unidad
	 INNER JOIN t101_mc_unidades_medida t101 
		ON t101.f101_id = t122.f122_id_unidad
		AND f101_id_cia = 1
	 WHERE t125A.f125_id_plan = ''C29'' 
	 	AND t125A.f125_id_criterio_mayor = ''001''
	 	AND t125B.f125_id_plan in (''C09'',''C10'',''C08'',''C01'',''C04'',''C23'',''C06'',''C13'',''C17'',''C16'',''C07'',''C05'',''C12'',''C11'')
	 GROUP BY t120.f120_id,t120.f120_referencia,t120.f120_id_unidad_orden,t122.f122_factor,t101.f101_descripcion
	'
) AS EspecificacionesProductoERP
INNER JOIN productos P ON CAST(f120_id AS NVARCHAR) = p.referencia_producto_erp AND p.sincronizado = 1
WHERE NOT EXISTS (
    SELECT 1 
    FROM especificaciones_productos ep 
    WHERE ep.id_producto = p.id AND ep.id_producto_ecommerce = p.id_producto_ecommerce
	)
	
