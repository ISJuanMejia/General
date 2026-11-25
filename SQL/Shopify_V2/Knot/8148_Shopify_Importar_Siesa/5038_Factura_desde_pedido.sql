
declare @idDocumento int=201184,@indicaParalelismo bit=0,@descripcion nvarchar(100)='FACT_DESDE_PEDIDO_CXC'
DECLARE @conexion NVARCHAR(MAX) = (SELECT TOP 1 cadena_conexion FROM Conexiones)
DECLARE @base_datos NVARCHAR(MAX) = (SELECT TOP 1 base_datos FROM Conexiones)
DECLARE @tabla NVARCHAR(MAX) = @base_datos + '.dbo.t430_cm_pv_docto 
											   where f430_ind_estado != 9 
											   and f430_ind_facturado=0 
											   and f430_id_cia = 1'
EXEC('select t.*
INTO ##tmpPedidosPendientes
from ordenes o
inner join OPENROWSET(''SQLNCLI'', ''' + @conexion + ''', ''
															SELECT f430_id_co,f430_id_tipo_docto,f430_consec_docto,f430_referencia
															FROM ' + @tabla + ''') as t on o.id_orden=t.f430_referencia 
															where id_estado=2 and intentos<3') 




select 
		@idDocumento as idDocumento ,
		@indicaParalelismo as indicaParalelismo,
		@descripcion as descripcion,
		f430_referencia as idOrden,
		(
			SELECT
				[Docto_ventas_comercial] = (
					SELECT GETDATE() as F350_FECHA,f430_consec_docto as F430_CONSEC_DOCTO_PEDIDO
					FOR JSON PATH
				),
				[Cuotas_CxC] = (
					SELECT GETDATE() as F353_FECHA_VCTO,GETDATE() as F353_FECHA_DSCTO_PP
					FOR JSON PATH
				)
			FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) as json from ##tmpPedidosPendientes;


			drop table ##tmpPedidosPendientes