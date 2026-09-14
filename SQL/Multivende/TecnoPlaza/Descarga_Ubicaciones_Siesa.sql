if object_id('tempdb..##tmp') is not null drop table ##tmp;
 
declare @conexion varchar(200), @bd varchar(100);
 
-- Obtener conexión y base de datos
select top 1 
    @conexion = cadena_conexion,
    @bd = base_datos 
from conexiones;
 
-- Ejecutar consulta remota usando OPENROWSET con MSOLEDBSQL
exec('
    select a.*
    into ##tmp
    from OPENROWSET(
        ''MSOLEDBSQL'',
        ''' + @conexion + ''',
        ''select 
            c.f013_id_pais,
            c.f013_id_depto,
            c.f013_id,
            p.f011_descripcion,
            d.f012_descripcion,
            c.f013_descripcion 
        from ' + @bd + '.dbo.t013_mm_ciudades c
        inner join ' + @bd + '.dbo.t012_mm_deptos d 
            on c.f013_id_depto = d.f012_id
        inner join ' + @bd + '.dbo.t011_mm_paises p 
            on c.f013_id_pais = p.f011_id 
            and d.f012_id_pais = p.f011_id''
    ) as a
');
 
-- Insertar datos en locaciones_erp
delete from locaciones_erp;
insert into locaciones_erp
select * from ##tmp;
 
-- Limpiar tabla temporal
if object_id('tempdb..##tmp') is not null drop table ##tmp;