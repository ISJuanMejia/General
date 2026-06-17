

DECLARE @order	INT = '122095';
DECLARE @batch_size	INT = 25;

SELECT DISTINCT TOP (@batch_size) 
	consumo	=
	(
		SELECT
			[@f9740_ts]					=	GETDATE(),
			[@f9740_id]					=	company,
			[@f9740_nit]				=	company,
			[@f9740_id_tipo_ident]		=	'C',
			[@f9740_ind_tipo_tercero]	=	'0',
			[@f9740_razon_social]		=	UPPER(CONCAT(first_name, ' ', last_name)),
			[@f9740_apellido_1]			=	UPPER(LEFT(last_name, CHARINDEX(' ', last_name + ' ') - 1)),
			[@f9740_apellido_2]			=	UPPER(LTRIM(SUBSTRING(last_name,CHARINDEX(' ', last_name + ' '),LEN(last_name)))),
			[@f9740_nombre]				=	UPPER(first_name),
			[@f9740_fecha_ingreso]		=	GETDATE(),
			[@f9740_contacto]			=	UPPER(CONCAT(first_name, ' ', last_name)),
			[@f9740_telefono]			=	REPLACE(phone, '+57', ''),
			[@f9740_ind_sexo]			=	'0',
			[@f9740_ind_habeas_data]	=	'2',
			[@f9740_id_pais]			=	country_code_billing,
			[@f9740_id_depto]			=	province_code_billing,
			[@f9740_id_ciudad]			=	city_code_billing,
			[@f9740_id_barrio]			=	'',
			[f_id_co]					=	zip
		FOR XML PATH('t9740_pdv_clientes')
	),
	url			=	ValorOrigen7,
	Cia			=	
		CASE
			WHEN CHARINDEX('P',CampoOrigen6) = 0 
				THEN ltrim(rtrim(CampoOrigen6))
			ELSE substring(CampoOrigen6,1,CHARINDEX('P',CampoOrigen6)-1) 
		END
FROM [GTIntegration]..equivalencias
	INNER JOIN Customers
		ON	equivalencias.ValorOrigen1	=	Customers.zip
	INNER JOIN Order_head 
		ON	Customers.order_id	=	Order_head.order_id
	INNER JOIN [Order_detail]
		ON	Order_detail.order_id	=	Order_head.order_id
WHERE 
	Equivalencia	=	'TPVs' 
	AND
	CampoOrigen7	=	'POS'
	AND	
	CASE 
		WHEN CHARINDEX('P', Order_head.CodigoCia) <> 0 
			THEN SUBSTRING(Order_head.CodigoCia, 1, 3) 
		ELSE Order_head.CodigoCia 
	END IN (
		SELECT DISTINCT CampoOrigen6
			FROM [GTIntegration]..equivalencias
		WHERE 
			Equivalencia='TPVs' 
			AND
			CampoOrigen7='POS'
	)
	--AND
	--status IN	(4,5) 
	--AND
	--Order_head.RowId	=	@order;

	/*SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
	
	--      [Sp_Devuelvexml] 65062

	ALTER procedure [dbo].[SP_DevuelveXML]
	@orden int
	as
	BEGIN
	select
			 ValorOrigen3 as sucursal
			,ValorOrigen4 as tpv
			,CampoOrigen6 as Cia2
			,ValorOrigen7 as url
			,case when CHARINDEX('P',CampoOrigen6)=0 then ltrim(rtrim(CampoOrigen6))
			else substring(CampoOrigen6,1,CHARINDEX('P',CampoOrigen6)-1) end as Cia
		into #equivalencias
		from [GTIntegration]..equivalencias
		where Equivalencia='TPVs' and CampoOrigen7='POS'

		declare @country varchar(3),@province varchar(3),@city varchar(3)
		select @country=country_code_shipping ,@province=province_code_shipping,@city=city_code_shipping 
		from [order_head] doc
			inner join [customers]     as  cus  on cus.order_id = doc.order_id
			inner join [order_detail]  as  mov  on mov.order_id = doc.order_id
		where doc.RowId=@orden

		-- descuentos
		select Order_detail.RowId
		  ,sku																			as producto
		  ,(discount_amount)*100/(price*quantity)                                       as tasa
		  ,(price*quantity)*(discount_amount)*100/(price*quantity)/100                  as valorDcto
		  ,(price*quantity)-(price*quantity)*(discount_amount)*100/(price*quantity)/100 as valorNeto
		  ,(price*quantity)                                                             as valorBruto
		 into #TmpDcto
		 from Order_head
			inner join Order_detail  on Order_head.order_id=Order_detail.order_id
		 where Order_head.RowId=@orden
	
		-- impuestos
		select  distinct 
				f120_id_cia as IdCompania,
				f120_referencia AS Referencia,
				ISNULL((SELECT f037_tasa 
						FROM [GRUPOBIOSUNOEE].dbo.t037_mm_llaves_impuesto 
						WHERE  f037_id = (SELECT f114_id_llave_impuesto 
										  FROM [GRUPOBIOSUNOEE].dbo.t114_mc_grupos_impo_impuestos 
										  WHERE f114_grupo_impositivo = it.f120_id_grupo_impositivo 
										  and f114_id_cia = it.f120_id_cia
										  and f114_ind_tipo_indicador in (1) 
										  and f114_id_clase_impuesto in (1))
										  and f037_id_cia = it.f120_id_cia), 0) AS TasaImpuesto,
        
				ISNULL((SELECT f037_tasa 
						FROM [GRUPOBIOSUNOEE].dbo.t037_mm_llaves_impuesto 
						WHERE  f037_id = (SELECT f114_id_llave_impuesto 
										  FROM [GRUPOBIOSUNOEE].dbo.t114_mc_grupos_impo_impuestos 
										  WHERE f114_grupo_impositivo = it.f120_id_grupo_impositivo 
										  and f114_id_cia = it.f120_id_cia
										  and f114_ind_tipo_indicador in (3) 
										  and f114_id_clase_impuesto in (7))
										  and f037_id_cia = it.f120_id_cia), 0) AS TasaImpuesto2
		into  #tmpLlaveimp        
		FROM [GRUPOBIOSUNOEE].dbo.t120_mc_items it
			INNER JOIN [GRUPOBIOSUNOEE].dbo.t121_mc_items_extensiones  ON f121_rowid_item = f120_rowid AND f121_ind_estado = 1 and f121_id_cia = f120_id_cia -- Solo activos
			LEFT JOIN [GRUPOBIOSUNOEE].dbo.t192_mc_equiv_contab_invent ON f120_id_tipo_inv_serv = f192_id_tipo_inv_serv and f192_id_cia = f120_id_cia
			INNER JOIN [GRUPOBIOSUNOEE].dbo.t113_mc_grupos_impositivos ON f113_id = f120_id_grupo_impositivo and f113_id_cia = f120_id_cia
			INNER JOIN [GRUPOBIOSUNOEE].dbo.t010_mm_companias ON f010_id = f120_id_cia
			INNER JOIN Order_detail ON f120_referencia = sku
			INNER JOIN Order_head ON Order_detail.order_id = Order_head.order_id
		WHERE f120_id_cia = (SELECT DISTINCT Cia FROM #equivalencias WHERE Cia = (SELECT DISTINCT CASE WHEN CHARINDEX('P', CodigoCia) = 0 THEN LTRIM(RTRIM(CodigoCia))
			ELSE SUBSTRING(CodigoCia, 1, CHARINDEX('P', CodigoCia) - 1) END AS CodigoCia FROM Order_head WHERE RowId = @orden)) 
			AND Order_head.RowId = @orden;

			--Insertar los impuestos
		CREATE TABLE #tmp_t9832_pdv_d_movto_venta_impto
	(
		xmlString VARCHAR(max),
		llave VARCHAR(max),
		porcentaje_base VARCHAR(max),
		tasa VARCHAR(max),
		sku VARCHAR(max)
	)
 
	-- Datos de La Orden
	SELECT ROW_NUMBER() OVER (ORDER by detail.order_id ASC) AS Orden
		,detail.order_id
		,detail.sku
		,detail.quantity
		,detail.price
		,detail.price_taxes
		,detail.discount_amount
		,t120.f120_id_grupo_impositivo
		,t120.f120_id_cia
	INTO		#tmp_ItemsOrder
	FROM [Integracion-Shopify].[dbo].[order_head] head		
	INNER JOIN  [Integracion-Shopify].[dbo].[Order_detail]	detail ON detail.order_id = head.order_id
	INNER JOIN	[GRUPOBIOSUNOEE].[dbo].[t120_mc_items]	t120 ON t120.f120_referencia = detail.sku
													AND t120.f120_id_cia = 232
	WHERE head.RowId = @orden


	-- Validar si maneja llaves.
	DECLARE @cantidadItems INT = (SELECT COUNT(*) FROM #tmp_ItemsOrder)
	DECLARE @i INT
	SET @i = 1;
	-- Se recorren los items para validar sus grupos impositivios y llaves.
	WHILE @i <= @cantidadItems
	BEGIN
		-- IdCia
		DECLARE @id_cia smallint = (select f120_id_cia from #tmp_ItemsOrder WHERE Orden = @i)
		--SKU: Se obtiene la información del SKU para poder asignar al que aplica, el impuesto, porcentaje y tasa.
		DECLARE @sku VARCHAR(MAX) = (select sku from #tmp_ItemsOrder WHERE Orden = @i)
		--Grupo Impositivo: Se obtiene el grupo impositivos asociado al item para la consulta.
		DECLARE @id_grupo_impositivo VARCHAR(MAX) = (select f120_id_grupo_impositivo from #tmp_ItemsOrder WHERE Orden = @i)
		--Obtenemos la cantidad de llaves del grupo impositivo.
		DECLARE @cantidadLlaves INT = 
		(
			SELECT COUNT (*) from [GRUPOBIOSUNOEE].[dbo].[t114_mc_grupos_impo_impuestos] 
			WHERE 
				f114_id_cia = @id_cia 
			AND f114_grupo_impositivo = @id_grupo_impositivo
		)
		-- Si la cantidad de llaves es diferente de 0.
		IF(@cantidadLlaves != 0)
		BEGIN
			  -- Se obtiene la información de las llaves asociadas al grupo impositivo.
			  SELECT
			   ROW_NUMBER() OVER (ORDER by f114_id_llave_impuesto ASC) AS Orden
			  ,f114_id_cia
			  ,f114_grupo_impositivo
			  ,f114_id_llave_impuesto
			  , @sku as sku
			  INTO #tmp_LlavesPorGrupoImpositivo
			  FROM GRUPOBIOSUNOEE.dbo.t114_mc_grupos_impo_impuestos
			  WHERE 
					f114_id_cia = @id_cia 
			  AND	f114_grupo_impositivo = @id_grupo_impositivo
			  AND	f114_ind_tipo_indicador = 3  -- Venta.
             
			  -- Grupos de impuestos por llaves.
			  DECLARE @countLlaves INT = (select COUNT(*) from #tmp_LlavesPorGrupoImpositivo)
			  DECLARE @j int;
			  SET @j = 1;
 
			  -- Recorrido para obtener tasa y porcentaje.
			  WHILE @j <= @countLlaves
			  BEGIN
				 -- Seleccionamos la llave por grupo de la cual se va a extraer su configuración de impuesto (Tas, Porcentaje base).
				 DECLARE @llave varchar(5) = (select f114_id_llave_impuesto from #tmp_LlavesPorGrupoImpositivo WHERE Orden = @j)
				 -- Valor asignado para tasa.
				 DECLARE @tasa smallmoney;
 
				 -- Valor asignado para %.
				 DECLARE @porcentaje_base smallmoney;
 
				 -- Se extraen del maestro.
				 SELECT
					 f037_porcentaje_base
					,f037_tasa
				 INTO #tmp_PorcentajeTasaPorLlave
				 FROM GRUPOBIOSUNOEE.dbo.t037_mm_llaves_impuesto
				 WHERE 
					f037_id = @llave
				 AND f037_id_cia = @id_cia
 
				 -- Se asignan para el XML previo.
				 SELECT
					 @porcentaje_base = f037_porcentaje_base, -- Asigna el valor del porcentaje base.
					 @tasa = f037_tasa  -- Asigna el valor de la tasa.
				 FROM #tmp_PorcentajeTasaPorLlave
                  
				--PRINT (CONCAT('Para el SKU: ',@sku,' el grupo de impuestos es ',@id_grupo_impositivo,' y para la llave ', @llave,' El porcentaje base es ',@porcentaje_base, ' y la tasa es: ', @tasa))
 
				INSERT INTO #tmp_t9832_pdv_d_movto_venta_impto
				SELECT concat('<t9832_pdv_d_movto_venta_impto f9832_id_llave_impuesto=''',@llave,''' f9832_porcentaje_base=''',@porcentaje_base,''' f9832_tasa=''',@tasa,''' f9832_vlr_uni=''0'' f9832_vlr_tot=''0'' f9832_ind_accion=''1'' ''f9832_ind_calculo=''1''/>') AS t9832,
				       @llave AS llave, @porcentaje_base AS porcentaje_base, @tasa AS tasa, @sku AS sku
				 SET @j = @j + 1;
				 DROP TABLE #tmp_PorcentajeTasaPorLlave
			  END
 
			  DROP TABLE #tmp_LlavesPorGrupoImpositivo
		END
		SET @i = @i + 1;
	END
	-- Tabla final de datos por item
	SELECT sku, llave, tasa
	INTO #tmp_t9832_impto
	FROM #tmp_t9832_pdv_d_movto_venta_impto
			
		-- nuevo proceso para calcular unidades adicionales
		    select distinct  t120_mc_items.f120_id_cia, t120_mc_items.f120_referencia, t120_mc_items.f120_descripcion
				, t122_mc_items_unidades.f122_factor
				, t122_mc_items_unidades.f122_peso
				, t122_mc_items_unidades.f122_volumen, 
				t122_mc_items_unidades.f122_id_unidad
				,isnull(f120_id_unidad_adicional,f122_id_unidad) as f120_id_unidad_adicional
				,iif(count(f120_referencia) over(partition by f120_referencia,mov.rowid)>1,f120_id_unidad_empaque,f122_id_unidad) as n
		    into #tmpUndAdicional_1
		    from [GRUPOBIOSUNOEE]..t120_mc_items 
			   left join [GRUPOBIOSUNOEE]..t122_mc_items_unidades on t120_mc_items.f120_rowid = t122_mc_items_unidades.f122_rowid_item and t120_mc_items.f120_id_cia = t122_mc_items_unidades.f122_id_cia
			   left join [order_detail] as mov on f120_referencia=mov.sku
			   left join [order_head]   as doc on mov.order_id=doc.order_id
		    where (t120_mc_items.f120_id_cia  =(select distinct Cia from  #equivalencias where Cia=(select distinct case when CHARINDEX('P',CodigoCia)=0 then ltrim(rtrim(CodigoCia))
			else substring(CodigoCia,1,CHARINDEX('P',CodigoCia)-1) end as  CodigoCia from Order_head where RowId=@orden)))
			 and (f122_id_unidad=isnull(f120_id_unidad_adicional,f122_id_unidad))
			 and (doc.RowId=@orden)

			 select * 
			 into #tmpUndAdicional
			 from #tmpUndAdicional_1
			 where f122_id_unidad=n
			 
		--consultar tpv
		select ValorOrigen3 as sucursal, ValorOrigen4 as tpv,Order_head.RowId
		into #tmpTpv
		from [GTIntegration]..equivalencias
			inner join Customers on equivalencias.ValorOrigen1=Customers.zip
			inner join Order_head on Customers.order_id=Order_head.order_id
		where Equivalencia='TPVs'
			and (Order_head.RowId=@orden)
		declare @texto varchar(max)


		--Crear xml
		set @texto=( select  isnull(tpv.tpv,'')											as [@f_id_tpv]
				,'999998'																as [@f_id_tercero_vendedor]
				,'222222222222'															as [@f_id_tercero_perfil]
				,'222222222222'															as [@f_id_tercero_cajero]
			   ,doc.audit_date															as [@f9820_id_fecha_docto]
			   ,doc.order_name															as [@f9820_notas]
			   ,tpv.sucursal															as [@f9820_id_sucursal_cli_perfil]
			   --,iif(ltrim(rtrim(dbo.RemoveChars(cc_registro))) in(select ValorOrigen1 from [GTIntegration]..equivalencias where equivalencia = 'Tercero'), Cus.customer_id,  ltrim(rtrim(dbo.RemoveChars(cc_registro)))) as [@f9820_id_cliente_pdv]
			   ---,isnull(iif(ltrim(rtrim(dbo.RemoveChars(cc_registro))) in(select ValorOrigen1 from [GTIntegration]..equivalencias where equivalencia = 'Tercero'), Cus.customer_id,  ltrim(rtrim(dbo.RemoveChars(cc_registro)))),ltrim(rtrim(dbo.RemoveChars(company))))  as [@f9820_id_cliente_pdv]
			   ,'222222222222'															as [@f9820_id_cliente_pdv]
			   ,'4'																		as [@f_id_tipo_entrega]
			   ,'5'																		as [@f9823_id_indicativo_domic]
			   ,dbo.removeChars(replace(cus.phone,'+57',''))							as [@f9823_id_telefono_domic]
			   ,concat(cus.first_name,' ',cus.last_name)								as [@f9823_nombre_contacto_domic]
			   ,@country																as [@f9823_id_pais_domic]
			   ,@province																as [@f9823_id_depto_domic]
			   ,@city																	as [@f9823_id_ciudad_domic]
			   ,dbo.fn_RemoveAccentMarks(concat(cus.shipping_address1,' ',cus.shipping_address2))  as [@f9823_direccion_domic]
			   --seccion Movimientos
			  ,(select mov.sku                                           as [@f_referencia_item]
					  ,mov.sku                                           as [@f_id_item]
					  ,'999998'                                          as [@f_id_vendedor]
					  ,'1201'                                            as [@f9830_id_concepto]
					  ,'01'                                              as [@f9830_id_motivo]
					  ,f120_id_unidad_adicional                          as [@f9830_id_unidad_medida]
					  ,convert(decimal(18,4),mov.quantity)               as [@f9830_cant_base]
					  ,convert(decimal(18,4),mov.quantity*isnull(tmp.f122_factor,1)) as [@f9830_cant_1]
					  ,convert(decimal(18,4),mov.quantity)               as [@f9830_cant_2]
					  ,replace(price,',','.')                            as [@f9830_precio_uni]
					  ,replace(dcto.valorBruto,',','.')                  as [@f9830_vlr_bruto]
					  ,replace(dcto.valorNeto,',','.')                   as [@f9830_vlr_neto]
					  ,''                                                as [@f_id_familia]
					  ,concat('sku:',mov.sku,' und:',mov.quantity)       as [@f9834_notas]
					  ,''                                                as [@f9834_tipo_reg_preparacion]
					  ,''                                                as [@f9834_tipo_familia_item]

					  -- seccion dctos
					 ,(select distinct							         
					  '1'                                                as [@f9831_orden]
					  ,tmpd.tasa                                         as [@f9831_tasa]
					  ,'0'                                               as [@f9831_vlr_uni]
					  ,tmpd.valorDcto                                    as [@f9831_vlr_tot]
					  ,'0'                                               as [@f9831_cant1_obsequio]
					  ,'0'                                               as [@f9831_cant2_obsequio]
					  ,'1'                                               as [@f9831_ind_tipo_dscto]
					  from #TmpDcto tmpd
					      -- inner join #tmp_t9832_impto as t9832 ON t9832.sku=tmpd.producto
					  where mov.sku=tmpd.producto
					  and tmpd.RowId=mov.RowId
					  and valorDcto <> 0 
					  for xml path('t9831_pdv_d_movto_venta_dscto'),type)  

					  --seccion impuestos
					  ,(select
					  t9832.llave                                        as [@f9832_id_llave_impuesto]
					  ,'100.0000'                                        as [@f9832_porcentaje_base]
					  ,t9832.tasa                                        as [@f9832_tasa]
					  ,'0.0000'                                          as [@f9832_vlr_uni]
					  ,'0.0000'                                          as [@f9832_vlr_tot]
					  ,'1'                                               as [@f9832_ind_accion]
					  ,'1'                                               as [@f9832_ind_calculo]
					  from   #tmp_t9832_impto t9832
					  where  mov.sku=t9832.sku --and doc.RowId=imp.RowId and RowIdt=mov.RowId
					  for xml path('t9832_pdv_d_movto_venta_impto'),type)

				 from [order_head] doc
				 inner join [customers]     as cus	on cus.order_id = doc.order_id
				 inner join [order_detail]  as mov  on mov.order_id = doc.order_id
				 inner join #TmpDcto        as dcto on dcto.RowId=mov.RowId
				 left  join #tmpUndAdicional as tmp  on mov.sku=tmp.f120_referencia
				
				 where doc.RowId=@orden
				 for xml path('t9830_pdv_d_movto_venta'),type) 
		from [order_head] doc
		inner join [customers] cus	on cus.order_id = doc.order_id
		left join #tmpTpv tpv on doc.RowId=tpv.RowId
		where doc.RowId=@orden 
		for xml path('t9820_pdv_d_doctos'))
	   
		select 
		@texto as consumo
		,url
		,Cia
		from #equivalencias  as equ
			inner join #tmpTpv as tp on tp.tpv=equ.tpv
		drop table #TmpDcto,#tmpLlaveimp,#tmp_ItemsOrder,#tmpUndAdicional_1,#tmpUndAdicional,#tmpTpv,#equivalencias,
		           #tmp_t9832_pdv_d_movto_venta_impto,#tmp_t9832_impto

END
GO
*/