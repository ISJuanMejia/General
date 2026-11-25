if object_id('tempdb..##tmp') is not null drop table ##tmp;
declare @conexion varchar(200),@bd varchar(100)
select top 1 @conexion=cadena_conexion,@bd=base_datos from conexiones
exec(N'select a.*
       into ##tmp
       from OPENROWSET(''SQLNCLI'', '''+@conexion+''',
     ''select c.f013_id_pais
		,c.f013_id_depto
		,c.f013_id
		,p.f011_descripcion
		,d.f012_descripcion
		,c.f013_descripcion 
		from t013_mm_ciudades c
		inner join t012_mm_deptos d on c.f013_id_depto=d.f012_id
		inner join t011_mm_paises p on c.f013_id_pais=p.f011_id and d.f012_id_pais=p.f011_id
		'') as a')
delete locaciones_erp
insert into locaciones_erp
select * from ##tmp

if object_id('tempdb..##tmp') is not null drop table ##tmp;