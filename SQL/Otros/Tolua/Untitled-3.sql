DECLARE	@idCo			VARCHAR(50)	=	'110' --114 {f_id_co}
DECLARE	@idtipoDocto	VARCHAR(50)	=	'N01' --CFE {f_id_tipo_docto}
DECLARE	@ConsecDocto	VARCHAR(50)	=	'661'  --12978 {f_consec_docto}

SELECT
	f461_id_fecha																				AS	'f_fecha'
	, t350_fact.f350_id_co																		AS	'f_co'
	--C.O. movto. = 114
	, f150_descripcion																			AS	'f_desc_co _movto'
	--, f470_costo_mp_en																			AS	'f_total_costo'
	--Margen prom. %
	, CAST(
		CASE 
			WHEN f461_id_moneda_docto = f010_id_moneda_local THEN (
				(
					f470_vlr_bruto - f470_vlr_dscto_linea - f470_vlr_dscto_global
				) * (
					CASE f470_ind_naturaleza 
						WHEN 1 THEN -1 
						ELSE 1 
					END
				)
			) 
			ELSE (
				(
					f470_vlr_bruto_alt - f470_vlr_dscto_linea_alt - f470_vlr_dscto_global_alt
				) * (
					CASE f470_ind_naturaleza 
						WHEN 1 THEN -1 
						ELSE 1 
					END
				)
			) 
		END AS DECIMAL(28,2)
	)																							AS	'f_valor_subtotal_local'
	, RTRIM(t350_fact.f350_id_tipo_docto) + '-' + dbo.Lpad(t350_fact.f350_consec_docto, 8, '0')	AS	'f_nro_documento'
	--Pedido documento CPM-00035356
	, t200_fact.f200_nit																		AS	'f_cliente_factura'
	, t200_fact.f200_razon_social																AS	'f_razon_social_cliente_factura'
	, f150_id																					AS	'f_bodega'
	, f150_descripcion																			AS	'f_desc_bodega'
	, t350_fact.f350_notas																		AS	'f_notas_item'
	, RTRIM(f120_referencia)																	AS	'f_referencia'
	, RTRIM(dbo.F_remover_enter_consulta(f120_descripcion))										AS	'f_desc_item'
	, (f470_cant_base * (
		CASE f470_ind_naturaleza
			WHEN 1 THEN -1
			ELSE 1 
		END)
	)																							AS	'f_cantidad_inv'
    , t200_vend.f200_razon_social																AS	'f_nombre_vendedor'
	, CASE 
        WHEN 1 = 0 THEN 0
        ELSE ISNULL(f132_costo_prom_uni, 0)
    END																							AS	'f_costo_promedio_uni_movto'
	--Costo promedio unidad inst
	--Margen promedio
	--Lista de precios
	, f470_precio_uni AS 'f_precio_unit_sin_dcto_antes_de_iva'
	--Precio unit con dcto/antes de iva
	, CAST(
		CASE 
			WHEN f461_id_moneda_docto = f010_id_moneda_local THEN (
				f470_vlr_bruto * (
					CASE f470_ind_naturaleza WHEN 1 THEN -1 ELSE 1 END
				)
			) 
			ELSE (
				f470_vlr_bruto_alt * (
					CASE f470_ind_naturaleza WHEN 1 THEN -1 ELSE 1 END
				)
			) 
		END AS DECIMAL(28,4)
    )																							AS	'f_valor_bruto_local'
	--Valor descuentos local
	--Descuento 1
	--Descuento 2
	, CAST(
		(
			f470_vlr_imp * (
				CASE f470_ind_naturaleza
					WHEN 1 THEN -1
					ELSE 1
				END
			)
		) AS DECIMAL(28, 4)
	)																							AS	'f_valor_impuestos_local'
	, CAST(
		( 
			f470_vlr_neto	* (
				CASE f470_ind_naturaleza
					WHEN 1 THEN -1 
					ELSE 1  
				END
			) 
		) AS DECIMAL(28, 4)
	)																							AS	'f_valor_neto_local'
	--FAMILIA = MADERAS
	--SUBFAMILIA = 0003 - MELAMINA
	--CATEGORIA = 0003 - RH
	--Desc ciudad = Bogotá, D.C.
	--Desc. depto = Bogotá
	--Direccion 1 = CLE 127 A 45 28
	--E-mail = qhpalomo@yahoo.com
	--Teléfono = 3182695817
	--Celular tercero factura
	--Reg docto 30
	--Reg mocto 30
	--Desc reg movto REGIONAL CENTRO
	--Desc reg docto REGIONAL CENTRO																					
	--Docto referencia (vacio)
	, ISNULL(
		(
			t350_rem.f350_id_tipo_docto + '-' + RIGHT(
				'00000000' + CAST(
					t350_rem.f350_consec_docto AS VARCHAR(8)
				), 8
			)
		), 
        ' '
    )																							AS	'f_docto_remision'
	, f470_rowid																				AS	'f_orden_interno'
	--,t150.*
    ,f305_xml_cfd
FROM	t350_co_docto_contable			t350_fact
INNER	JOIN	t461_cm_docto_factura_venta			ON	f461_rowid_docto				=	f350_rowid
INNER	JOIN	t470_cm_movto_invent				ON	f470_rowid_docto_fact			=	f461_rowid_docto
INNER	JOIN	t150_mc_bodegas						ON	f150_rowid						=	f470_rowid_bodega
INNER	JOIN	t121_mc_items_extensiones			ON	f121_rowid						=	f470_rowid_item_ext
INNER	JOIN	t120_mc_items						ON	f120_rowid						=	f121_rowid_item
LEFT	JOIN	t010_mm_companias					ON	f010_id							=	f461_id_cia
INNER	JOIN	t200_mm_terceros		t200_fact	ON	t200_fact.f200_rowid			=	f461_rowid_tercero_fact
INNER	JOIN	t201_mm_clientes		t201_fact	ON	t201_fact.f201_rowid_tercero	=	f461_rowid_tercero_fact	AND	t201_fact.f201_id_sucursal	=	f461_id_sucursal_fact
INNER	JOIN	t200_mm_terceros		t200_vend	ON	t200_vend.f200_rowid			=	f461_rowid_tercero_vendedor
INNER	JOIN	v470_ventas_devol					ON	v470_devol_rowid_movto			=	f470_rowid
INNER	JOIN	t100_pp_comerciales					ON	f100_id_cia						=	f470_id_cia
LEFT	JOIN	t122_mc_items_unidades	t122_e		ON	f120_rowid						=	t122_e.f122_rowid_item	AND	f120_id_unidad_empaque		=	t122_e.f122_id_unidad	AND	t122_e.f122_id_cia	=	f120_id_cia
LEFT	JOIN	t158_mc_causal_devol				ON	f158_id_cia						=	f470_id_cia				AND	f158_id_concepto			=	f470_id_concepto		AND	f158_id				=	f470_id_causal_devol
LEFT	JOIN	v125 t01_03							ON	t01_03.v125_rowid_item			=	f121_rowid_item			AND	t01_03.v125_id_plan			=	'03'
LEFT	JOIN	v125 t01_04							ON	t01_04.v125_rowid_item			=	f121_rowid_item			AND	t01_04.v125_id_plan			=	'04'
LEFT	JOIN	v125 t01_05							ON	t01_05.v125_rowid_item			=	f121_rowid_item			AND	t01_05.v125_id_plan			=	'05'
LEFT	JOIN	t350_co_docto_contable	t350_rem	ON	t350_rem.f350_rowid				=	f470_rowid_docto
LEFT	JOIN	t132_mc_items_instalacion			ON	f470_id_cia						=	f132_id_cia				AND	f470_rowid_item_ext			=	f132_rowid_item_ext		AND	f470_id_instalacion	=	f132_id_instalacion
LEFT OUTER JOIN t305_co_cfd                         ON  f350_rowid                      =   f305_rowid_docto
WHERE  
t350_fact.f350_id_co			= @idCo			AND 
t350_fact.f350_id_tipo_docto	= @idtipoDocto	AND 
t350_fact.f350_consec_docto		= @ConsecDocto