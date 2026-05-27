

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