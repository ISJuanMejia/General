
if object_id('tempdb..##tmpPrecio') is not null drop table ##tmpPrecio;
declare @final table(id_variante varchar(50),sku_erp varchar(50),json varchar(max));
declare @conexion varchar(200),@bd varchar(100)
select top 1 @conexion=cadena_conexion,@bd=base_datos from conexiones
delete @final
exec(N'select a.*
       into ##tmpPrecio
       from OPENROWSET(''SQLNCLI'', '''+@conexion+''',
     ''select MAX(f126_fecha_activacion) as f126_fecha_activacion,f126_rowid_item,f126_id_lista_precio
       FROM t126_mc_items_precios
       WHERE f126_id_lista_precio=''''P01''''
       GROUP BY f126_rowid_item,f126_id_lista_precio'') as a')

insert into @final(id_variante,sku_erp,json)
exec(N'
SELECT Products.id_variante,Products.sku_erp,
    ''{"variant":{"id":"''+ CAST(Products.id_variante AS NVARCHAR(20))+''", "price": "''+FORMAT(t126_mc_items_precios.f126_precio,''####'') + ''"}}'' AS json
FROM variantes AS Products
INNER JOIN OPENROWSET(''SQLNCLI'', ''' + @conexion + ''', [' + @bd + '].dbo.v121) AS v121 
    ON v121_id_barras_principal = Products.sku_erp
INNER JOIN ##tmpPrecio precio 
    ON v121.v121_rowid_item = precio.f126_rowid_item
INNER JOIN OPENROWSET(''SQLNCLI'', ''' + @conexion + ''', [' + @bd + '].dbo.t126_mc_items_precios) AS t126_mc_items_precios 
    ON precio.f126_rowid_item = t126_mc_items_precios.f126_rowid_item 
    AND precio.f126_fecha_activacion = t126_mc_items_precios.f126_fecha_activacion 
    AND precio.f126_id_lista_precio = t126_mc_items_precios.f126_id_lista_precio
WHERE t126_mc_items_precios.f126_precio > 1');

merge into dbo.precios as target
using (
       select * from @final
      ) as source
on target.id_variante = source.id_variante
when matched and target.precio_obj <> source.json then
    update set
		   target.precio_obj = source.json,
		   target.sincronizado = 0,
		   target.fecha_sincronizacion = null
when not matched by target then
    insert (id_variante, sku_erp, precio_obj, sincronizado, fecha_sincronizacion)
    values (source.id_variante, source.sku_erp,source.json,0, null);

delete @final
if object_id('tempdb..##tmpPrecio') is not null drop table ##tmpPrecio;
