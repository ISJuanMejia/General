SET XACT_ABORT ON;

BEGIN TRY
	DECLARE @final	TABLE (
		idDocumento			INT,
		indicaParalelismo	BIT,
		descripcion			VARCHAR(100),
		idOrden				VARCHAR(50),
		json				VARCHAR(max)
	);

	DECLARE
		@idDocumento		INT				=	200548,
		@indicaParalelismo	BIT				=	0,
		@descripcion		VARCHAR(100)	=	'Pedido_Eccomerce';

	DECLARE @counter	INT	=	1;
	DECLARE @total		INT;

	DECLARE @json				VARCHAR(MAX)	=	'';
	DECLARE @order				VARCHAR(30);
	DECLARE @paymentType		NVARCHAR(MAX);
	DECLARE @paymentValue		NVARCHAR(MAX);
	DECLARE @TomarCodigoBarras	INT				=	1;			--1: Si, 2: No
    DECLARE @lista_precios_libre_en_movtos_pedido_comercial BIT =   0;  -- 1: Si, 0: No
	DECLARE @fecha_inicio		DATETIME	=	'2026-03-06'

	/*	SUCURSAL	*/
	DECLARE @sucursal_defecto		NVARCHAR(3)	=	'010'
	DECLARE @sucursal_sistecredito	NVARCHAR(3)	=	'011'
	DECLARE @sucursal_addi			NVARCHAR(3)	=	'012'
	DECLARE @sucursal_contraentrega	NVARCHAR(3)	=	'013'

	/*	BODEGA	*/
	DECLARE @bodegas TABLE
    (
        id_location BIGINT,
        bodega_erp VARCHAR(6)
    )

    INSERT INTO @bodegas
    SELECT
        location_id,
        bodega_erp
    FROM bodegas
    WHERE
        bodega_erp IS NOT NULL;

    IF NOT EXISTS(
        SELECT
            id_location
        FROM @bodegas
    )
    BEGIN
        SELECT 'No hay bodegas configuradas.'
        RETURN
    END

	/*	
        LISTA DE PRECIOS	

        *   Lista de precios libre = 'LPL'
        *   Lista de precios cerrada = '18'
    */
	DECLARE @IdListaPreciosProducto	NVARCHAR(3)	=   
        CASE 
            WHEN @lista_precios_libre_en_movtos_pedido_comercial = 1 
                THEN 'LPL' 
            ELSE '18' 
        END;
	DECLARE @IdListaPreciosFlete	NVARCHAR(3)	=	'LPL'

	/*	
        MOTIVOS	
    
        *    Venta producto =   'V3'
        *    Obsequio       =   'V4'
        *    Flete          =   '10'
    */
	DECLARE @IdMotivoProducto	NVARCHAR(3)	=	'V3';
	DECLARE @IdMotivoObsequio	NVARCHAR(3)	=	'V4';
	DECLARE @IdMotivoFlete		NVARCHAR(3)	=	'10';

	/*	UNIDADES DE MEDIDA	*/
	DECLARE @UnidadMedidaProducto	NVARCHAR(3)	=	'UND';
	DECLARE @UnidadMedidaFlete		NVARCHAR(3)	=	'UND';

	/*	
        INDICADORES DE PRECIOS	

        *    Lista de precios libre = 2
        *    Lista de precios cerrada = 1
    */
	DECLARE @IndPrecioProducto	INT	=	
        CASE 
            WHEN @lista_precios_libre_en_movtos_pedido_comercial = 1 
                THEN 2 
            ELSE 1 
        END;
	DECLARE @IndPrecioFlete		INT	=	2;

	/*	CODIGO	FLETE	*/
	DECLARE @ReferenciaItemFlete	NVARCHAR(MAX)	=	'S42505003';	--'0008658'

	/*	CONEXIÓN BASE DE DATOS	*/
	DECLARE @conexion	NVARCHAR(MAX)	=	(SELECT TOP 1 cadena_conexion FROM Conexiones)
	DECLARE @base_datos	NVARCHAR(MAX)	=	(SELECT TOP 1 base_datos FROM Conexiones)

	/*
		*	Tablas del ERP
		*		t121_mc_items_extensiones
		*		t122_mc_items_unidades
		*		t430_cm_pv_docto
	*/
	DECLARE	@t121_mc_items_extensiones	TABLE	(
		f121_rowid_item				INT,
		f121_id_barras_principal	VARCHAR(20)
	);

	DECLARE	@t122_mc_items_unidades	TABLE	(
		f122_rowid_item	INT,
		f122_id_unidad	VARCHAR(4)
	);

	DECLARE @t430_cm_pv_docto	TABLE	(
		f430_referencia	NVARCHAR(10)
	);

	INSERT INTO @t121_mc_items_extensiones
	EXEC('
		SELECT
			f121_rowid_item, 
			f121_id_barras_principal 
		FROM OPENROWSET(
			''SQLNCLI'',
			''' + @conexion + ''',
			''
				SELECT
					f121_rowid_item,
					f121_id_barras_principal
				FROM ' + @base_datos	 + '.dbo.t121_mc_items_extensiones
			''
		)
	');

	INSERT INTO @t122_mc_items_unidades
	EXEC('
		SELECT
			f122_rowid_item, 
			f122_id_unidad 
		FROM OPENROWSET(
			''SQLNCLI'',
			''' + @conexion + ''',
			''
				SELECT
					f122_rowid_item,
					f122_id_unidad
				FROM ' + @base_datos	 + '.dbo.t122_mc_items_unidades
			''
		)
	');

	INSERT INTO @t430_cm_pv_docto
	EXEC('
		SELECT DISTINCT 
			f430_referencia
		FROM OPENROWSET(
			''SQLNCLI'', 
			''' + @conexion + ''', 
			''
				SELECT
					f430_referencia 
				FROM ' + @base_datos + '.dbo.t430_cm_pv_docto
				WHERE
					f430_ind_estado != 9 
					AND 
					f430_id_cia = 1
			''
		)'
	);

	/*
        *   Valida si el precio del ecommerce es diferente al del erp y si lo es lo toma como un descuento
	*/
    DECLARE  @precios_ERP TABLE (
		f126_precio					MONEY,
		f121_id_barras_principal	NVARCHAR(50)
	)
	INSERT INTO @precios_ERP
	EXEC('
		SELECT DISTINCT
			f126_precio,
            f121_id_barras_principal
		FROM OPENROWSET(
			''SQLNCLI''
			,''' + @conexion + '''
			,''
				SELECT
					f126_precio,
                    f121_id_barras_principal,
                    f126_fecha_activacion,
                    ROW_NUMBER() OVER (PARTITION BY f126_rowid_item_ext ORDER BY f126_fecha_activacion DESC) AS rn_1
				FROM '+@base_datos + '.dbo.t126_mc_items_precios
					INNER JOIN '+@base_datos +'.dbo.t121_mc_items_extensiones
						ON
							f121_rowid = f126_rowid_item_ext
				WHERE
					f126_id_lista_precio = ''''18''''
					AND
					f126_fecha_activacion < GETDATE()
			''
		)
        WHERE
            rn_1 = 1'
	);
	
	--> Crear tabla global temporal
	DECLARE	@unidades_por_items	TABLE	(
		f121_id_barras_principal	VARCHAR(255),
		f122_id_unidad				VARCHAR(255)
	);

	INSERT INTO	@unidades_por_items
	SELECT
		f121_id_barras_principal,
		f122_id_unidad
	FROM @t121_mc_items_extensiones
		LEFT JOIN @t122_mc_items_unidades
			ON
				f121_rowid_item	=	f122_rowid_item;

	/*
		*	Tablas de las secciones del conector
		*		Pedidos
		*		Movimiento
		*		Descuentos
	*/
	DECLARE @pedidos	TABLE	(
		f430_id_fecha				NVARCHAR(8),
		f430_fecha_entrega			NVARCHAR(8),
		f430_num_dias_entrega		NVARCHAR(10),
		f430_referencia				NVARCHAR(10),
		f430_num_docto_referencia	NVARCHAR(15),
		f430_notas					NVARCHAR(MAX),
		f430_id_tercero_fact		NVARCHAR(200),
		f430_id_tercero_rem			NVARCHAR(200),
		f430_id_sucursal_fact		NVARCHAR(3),
		f430_id_sucursal_rem		NVARCHAR(3),
		f430_tasa_dscto_global_cap	NVARCHAR(20),
		f430_id_tipo_cli_fact		NVARCHAR(4)
	)

	DECLARE @Movto_Pedidos_Comercial	TABLE	(
		f431_nro_registro		INT,
		f431_referencia_item	NVARCHAR(50),
		f431_codigo_barras		NVARCHAR(20),
		f431_id_ext1_detalle	NVARCHAR(20),
		f431_id_ext2_detalle	NVARCHAR(20),
		f431_id_bodega			NVARCHAR(5),
		f431_id_motivo			NVARCHAR(2),
		f431_ind_obsequio		INT,
		f431_fecha_entrega		NVARCHAR(8),
		f431_num_dias_entrega	INT,
		f431_id_lista_precio	NVARCHAR(3),
		f431_id_unidad_medida	NVARCHAR(4),
		f431_cant_pedida_base	NVARCHAR(20),
		f431_precio_unitario	NVARCHAR(20),
		f431_ind_impto_asumido	INT,
		f431_ind_precio			INT
	)

	DECLARE @descuentos	TABLE (
		f431_nro_registro	INT,
		f432_vlr_uni		NVARCHAR(20)
	);

	/*	TABLAS DATOS SHOPIFY	*/
	DECLARE	@shipping_lines	TABLE	(
		amount	NVARCHAR(20)
	)

	DECLARE	@descuentos_shopify	TABLE (
		discount_applications	NVARCHAR(max),
		[value]					NVARCHAR(50),
		[name]					VARCHAR(50),
		[target_type]			VARCHAR(50),
		[value_type]			VARCHAR(50),
		[json]					NVARCHAR(MAX)
	)

	DECLARE @ordenes	TABLE	(
		id_orden	NVARCHAR(900),
		orden_obj	NVARCHAR(MAX)
	)

	INSERT INTO @ordenes
	SELECT TOP 25
		id_orden, 
		orden_obj
	FROM ordenes
		LEFT JOIN	@t430_cm_pv_docto	AS	oc 
			ON 
				oc.f430_referencia = REPLACE(id_orden, '"', '')
		INNER JOIN (
			SELECT DISTINCT 
				order_id_shopify
			FROM shopify_fulfillment_orders
		) AS sfo 
			ON sfo.order_id_shopify = JSON_VALUE(orden_obj, '$.id')
	WHERE
		id_estado = 3
		AND 
		intentos<=3 
		AND
		oc.f430_referencia IS NULL
		AND
		fecha_creacion	>	@fecha_inicio
	ORDER BY ID DESC;

	UPDATE ordenes
	SET id_estado = 4
	WHERE
		id_estado = 3
		AND 
		intentos <= 3
		AND 
		id_orden IN (
			SELECT
				REPLACE(id_orden, '"', '')
			FROM	@t430_cm_pv_docto	AS	oc
			WHERE
				oc.f430_referencia = REPLACE(id_orden, '"', '')
		);

	SET @total = (SELECT COUNT(*) FROM @ordenes);

	WHILE @counter <= @total
	BEGIN
		BEGIN TRY
			SET @json = (
				SELECT orden_obj
				FROM (
					SELECT orden_obj ,row_number() over (order by (select null)) as rn
					FROM @ordenes
				) AS temp
			WHERE rn = @counter);

			SET @order = JSON_VALUE(@json, '$.name');

			DECLARE @id_tercero	NVARCHAR(40)	=
				ISNULL(
					(
						SELECT TOP 1
							attrs.value
						FROM OPENJSON(@json, '$.note_attributes')
							WITH (
								name NVARCHAR(100),
								value NVARCHAR(100)
							) AS attrs
						WHERE
							attrs.name = 'Número_documento'
							AND
							TRY_CAST(
								REPLACE(attrs.value, '-', '') AS DECIMAL(30,0)
							) IS NOT NULL
					), 
					'1053774023'
				);

			DECLARE @id_tipo_cliente	NVARCHAR(4)	= 'TCNL';

			DECLARE @Sucursal	NVARCHAR(3);

			;WITH transacciones_ok AS (
				SELECT 
					JSON_VALUE(transaccion_obj, '$.gateway') AS gateway
				FROM transacciones_ordenes 
				WHERE 
					id_orden = JSON_VALUE(@json, '$.id')
					AND JSON_VALUE(transaccion_obj, '$.status') = 'success'
			)
			SELECT TOP 1
				@id_tipo_cliente = 
					CASE gateway
						WHEN 'Sistecredito' THEN 'TCSC'
						WHEN 'Addi Payment' THEN 'TCNA'
						WHEN 'manual'		THEN 'TCNC'
						ELSE 'TCNL'
					END,
				@sucursal = 
					CASE gateway
						WHEN 'Sistecredito' 
							THEN @sucursal_sistecredito
						WHEN 'manual' 
							THEN @sucursal_contraentrega
						WHEN 'Addi Payment'	
							THEN @sucursal_addi
						ELSE @sucursal_defecto
					END
			FROM transacciones_ok;

			SET @sucursal = ISNULL(@sucursal, @sucursal_defecto);

			DECLARE @IdBodega			NVARCHAR(5)	=	(
				SELECT TOP 1
					bodega_erp
				FROM @bodegas
				WHERE
					id_location = JSON_VALUE(@json, '$.location_id')
			);

			SET @IdBodega	=
				ISNULL(
					@IdBodega, 
					(
						SELECT TOP 1
						bodega_erp
						FROM @bodegas
					)
				);

			-->	encabezado
			INSERT INTO @pedidos
			SELECT
				f430_id_fecha				=	FORMAT(GETDATE(), 'yyyyMMdd'),
				f430_fecha_entrega			=	FORMAT(GETDATE(), 'yyyyMMdd'),
				f430_num_dias_entrega		=	'1',
				f430_referencia				=	JSON_VALUE(@json, '$.name'),
				f430_num_docto_referencia	=	JSON_VALUE(@json, '$.name'),
				f430_notas					=	
					(
						SELECT TOP 1
							CASE 
								WHEN value = 'Cash on Delivery (COD)'
									THEN 'Contraentrega'
								ELSE value
							END
						FROM OPENJSON(@json, '$.payment_gateway_names')
						ORDER BY [key] DESC
					),
				f430_id_tercero_fact		=	@id_tercero,
				f430_id_tercero_rem			=	@id_tercero,
				f430_id_sucursal_fact		=	@Sucursal,
				f430_id_sucursal_rem		=	@Sucursal,
				f430_tasa_dscto_global_cap	=	'',
				f430_id_tipo_cli_fact		=	@id_tipo_cliente;
			
			INSERT INTO @Movto_Pedidos_Comercial (
				f431_nro_registro,
				f431_precio_unitario,
				f431_ind_precio,
				f431_referencia_item,
				f431_codigo_barras,
				f431_fecha_entrega,
				f431_num_dias_entrega,
				f431_cant_pedida_base,
				f431_id_lista_precio,
				f431_id_bodega,
				f431_id_ext1_detalle,
				f431_id_ext2_detalle,
				f431_id_motivo,
				f431_id_unidad_medida,
				f431_ind_impto_asumido,
				f431_ind_obsequio
			)
			SELECT
				f431_nro_registro		=	ROW_NUMBER() OVER (ORDER BY (JSON_VALUE(LineItems.value, '$.id'))),
				f431_precio_unitario	=	
                    CASE
                        WHEN @lista_precios_libre_en_movtos_pedido_comercial = 1 
                            THEN 
                                CAST(
                                    ROUND(
                                        CAST(
                                            REPLACE(
                                                JSON_VALUE(LineItems.value, '$.price')
                                                , ','
                                                , '.'
                                            ) AS DECIMAL(18,2)
                                        ), 2
                                    ) AS DECIMAL(18,2)
                                )
                        ELSE 
                            CAST('0' AS VARCHAR(50))
                    END,
				f431_ind_precio			=	@IndPrecioProducto,
				f431_referencia_item	=
					CASE
						WHEN @TomarCodigoBarras = 1 
							THEN CAST('' AS VARCHAR(20))
						WHEN @TomarCodigoBarras = 2	
							THEN LEFT(v.sku_erp, CHARINDEX('-', v.sku_erp) - 1)
					END,
				f431_codigo_barras		=
					CASE
						WHEN @TomarCodigoBarras = 1 
							THEN v.sku_erp
						WHEN @TomarCodigoBarras = 2	
							THEN CAST('' AS VARCHAR(20))
					END,
				f431_fecha_entrega		=	FORMAT(GETDATE(), 'yyyyMMdd'),
				f431_num_dias_entrega	=	1,
				f431_cant_pedida_base	=	JSON_VALUE(LineItems.value, '$.quantity'),
				f431_id_lista_precio	=	@IdListaPreciosProducto,
				f431_id_bodega			=	bodega_erp,
				f431_id_ext1_detalle	=
					CASE
						WHEN @TomarCodigoBarras = 1
							THEN CAST('' AS VARCHAR(20))
						WHEN @TomarCodigoBarras = 2
							THEN RIGHT(v.sku_erp, CHARINDEX('-', REVERSE(v.sku_erp)) - 1)
					END,
				f431_id_ext2_detalle	=
					CASE
						WHEN @TomarCodigoBarras = 1 THEN CAST('' AS VARCHAR(20))
						WHEN @TomarCodigoBarras = 2	THEN SUBSTRING(
							v.sku_erp,
							CHARINDEX('-', v.sku_erp) + 1,
							LEN(v.sku_erp) - CHARINDEX('-', v.sku_erp) - CHARINDEX(
								'-', REVERSE(v.sku_erp)
							)
						)
					END,
				f431_id_motivo			=
					CASE
						WHEN NOT EXISTS (SELECT 1 FROM OPENJSON(LineItems.value, '$.discount_allocations'))
							THEN @IdMotivoProducto
						WHEN EXISTS (SELECT 1 FROM OPENJSON(LineItems.value, '$.discount_allocations'))
							THEN (
								SELECT
									CASE
										WHEN (
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(LineItems.value, '$.price')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											) * JSON_VALUE(LineItems.value, '$.quantity')
										) - SUM(
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(da.value, '$.amount')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											)
										) = 0 THEN @IdMotivoObsequio
										WHEN (
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(LineItems.value, '$.price')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											) * JSON_VALUE(LineItems.value, '$.quantity')
										) - SUM(
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(da.value, '$.amount')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											)
										) != 0 THEN @IdMotivoProducto
									END
								FROM OPENJSON(LineItems.value, '$.discount_allocations') as da
							)
					END,
				f431_id_unidad_medida	=	TRIM(f122_id_unidad),
				f431_ind_impto_asumido	=
					CASE
						WHEN NOT EXISTS (SELECT 1 FROM OPENJSON(LineItems.value, '$.discount_allocations'))
							THEN 0
						WHEN EXISTS (SELECT 1 FROM OPENJSON(LineItems.value, '$.discount_allocations'))
							THEN (
								SELECT
									CASE
										WHEN (
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(LineItems.value, '$.price')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											) * JSON_VALUE(LineItems.value, '$.quantity')
										) - SUM(
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(da.value, '$.amount')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											)
										) = 0 THEN 1
										WHEN (
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(LineItems.value, '$.price')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											) * JSON_VALUE(LineItems.value, '$.quantity')
										) - SUM(
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(da.value, '$.amount')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											)
										)!= 0 THEN 0
									END
								FROM OPENJSON(LineItems.value, '$.discount_allocations') as da
							)
					END,
				f431_ind_obsequio		=
					CASE
						WHEN NOT EXISTS (SELECT 1 FROM OPENJSON(LineItems.value, '$.discount_allocations'))
							THEN 0
						WHEN EXISTS (SELECT 1 FROM OPENJSON(LineItems.value, '$.discount_allocations'))
							THEN (
								SELECT
									CASE
										WHEN (
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(LineItems.value, '$.price')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											) * JSON_VALUE(LineItems.value, '$.quantity')
										) - SUM(
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(da.value, '$.amount')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											)
										) = 0 THEN 1
										WHEN (
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(LineItems.value, '$.price')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											) * JSON_VALUE(LineItems.value, '$.quantity')
										) - SUM(
											CAST(
												ROUND(
													CAST(
														REPLACE(
															JSON_VALUE(da.value, '$.amount')
															, ','
															, '.'
														) AS DECIMAL(18,2)
													), 2
												) AS DECIMAL(18,2)
											)
										) != 0 THEN 0
									END
								FROM OPENJSON(LineItems.value, '$.discount_allocations') as da
							)
					END
			FROM OPENJSON(@json, '$.line_items') AS LineItems
				LEFT JOIN (
					SELECT DISTINCT id_variante, sku_erp
					FROM variantes
				) v ON v.id_variante = JSON_VALUE(LineItems.value, '$.variant_id')
				LEFT JOIN	@unidades_por_items	AS	unidades
					ON
						unidades.f121_id_barras_principal = v.sku_erp
				LEFT JOIN shopify_fulfillment_order_items
					ON	JSON_VALUE(LineItems.value, '$.id')	=	line_item_id
				LEFT JOIN shopify_fulfillment_orders
					ON
						fulfillment_order_id = id_fulfillment_order
				INNER JOIN bodegas
					ON
						assigned_location_id	=	location_id
			WHERE
				v.sku_erp	NOT IN ('7704198942299')
			ORDER BY JSON_VALUE(LineItems.value, '$.id')

			UPDATE
				Inv
			SET Inv.sincronizado	=	0
			FROM	Inventarios	AS	Inv 
				INNER JOIN	variantes	AS	v 
					ON 
						Inv.sku_erp = v.sku_erp
				INNER JOIN	OPENJSON(@json, '$.line_items')	AS	LineItems
					ON 
						v.id_variante = JSON_VALUE(LineItems.value, '$.variant_id');

			/*
                *   Valida si tiene envio
            */
			INSERT INTO @shipping_lines
			SELECT 
				amount	=	JSON_VALUE(sl.value, '$.discount_allocations[0].amount')
			FROM OPENJSON(@json,'$.shipping_lines')	AS	sl
			
			IF NOT EXISTS (SELECT amount FROM @shipping_lines WHERE amount IS NOT NULL)
			BEGIN
				INSERT INTO @Movto_Pedidos_Comercial (
					f431_nro_registro,
					f431_precio_unitario,
					f431_ind_precio,
					f431_referencia_item,
					f431_codigo_barras,
					f431_fecha_entrega,
					f431_num_dias_entrega,
					f431_cant_pedida_base,
					f431_id_lista_precio,
					f431_id_bodega,
					f431_id_ext1_detalle,
					f431_id_ext2_detalle,
					f431_id_motivo,
					f431_id_unidad_medida,
					f431_ind_impto_asumido,
					f431_ind_obsequio
				)
				SELECT
					f431_nro_registro		=	0,
					f431_precio_unitario	=
						CAST(
							ROUND(
								CAST(
									REPLACE(
										JSON_VALUE(sl.value, '$.price')
										, ','
										, '.'
									) AS DECIMAL(18,2)
								) / 1.19, 2
							) AS DECIMAL(18,2)
						),
					f431_ind_precio			=	@IndPrecioFlete,
					f431_referencia_item	=	@ReferenciaItemFlete,
					f431_codigo_barras		=	CAST('' AS VARCHAR(20)),
					f431_fecha_entrega		=	FORMAT(GETDATE(), 'yyyyMMdd'),
					f431_num_dias_entrega	=	1,
					f431_cant_pedida_base	=	1,
					f431_id_lista_precio	=	@IdListaPreciosFlete,
					f431_id_bodega			=	@IdBodega,
					f431_id_ext1_detalle	=	'',
					f431_id_ext2_detalle	=	'',
					f431_id_motivo			=	@IdMotivoFlete,
					f431_id_unidad_medida	=	@UnidadMedidaFlete,
					f431_ind_impto_asumido	=	0,
					f431_ind_obsequio		=	0
				FROM OPENJSON(@json, '$.shipping_lines') as sl
				WHERE
					JSON_VALUE(sl.value, '$.price')	!=	'0.00' 
					AND
					JSON_VALUE(sl.value, '$.price') != '0'  
					AND 
					JSON_VALUE(sl.value, '$.is_removed') = 'false'
			END

			/*
                *   Valida el descuento con lista de precios libre
            */
			IF (
                @lista_precios_libre_en_movtos_pedido_comercial = 1 
                AND 
                EXISTS (SELECT value FROM OPENJSON(@json,'$.discount_applications'))
            )
			BEGIN
				INSERT INTO @descuentos_shopify
				SELECT
					JSON_VALUE(@json, '$.discount_applications[0].type'),
					JSON_VALUE(@json, '$.discount_applications[0].value'),
					JSON_VALUE(@json, '$.name'),
					JSON_VALUE(@json, '$.discount_applications[0].target_type'),
					JSON_VALUE(@json, '$.discount_applications[0].value_type'),
					@json
				FROM OPENJSON(@json);

				--valida descuento por linea
				IF EXISTS (
					SELECT TOP 1 
					target_type 
					FROM @descuentos_shopify 
					WHERE 
						target_type	=	'line_item'
				)
				BEGIN
					INSERT INTO @descuentos
					SELECT
						f431_nro_registro	=	m.f431_nro_registro,
						f432_vlr_uni		=
							CONVERT(
								MONEY,
								JSON_VALUE(Discount.value, '$.amount')
							)/CONVERT(
								MONEY,
								JSON_VALUE(LineItems.value, '$.quantity')
							)
					FROM OPENJSON(@json, '$.line_items') AS LineItems
						INNER JOIN variantes	AS	v
							ON
								v.id_variante = JSON_VALUE(LineItems.value, '$.variant_id')
						INNER JOIN @Movto_Pedidos_Comercial	AS	m
							ON
								m.f431_codigo_barras = v.sku_erp
						CROSS APPLY OPENJSON(LineItems.value, '$.discount_allocations') AS Discount
					WHERE 
						m.f431_id_motivo = @IdMotivoProducto
				END
			END;

            IF (@lista_precios_libre_en_movtos_pedido_comercial = 0)
			BEGIN
				INSERT INTO @descuentos
				SELECT
					f431_nro_registro	=	m.f431_nro_registro,
					f432_vlr_uni		=	
                        pe.f126_precio - 
                        (
                            JSON_VALUE(li.value, '$.price') - 
                            (
                                CASE 
                                    WHEN EXISTS (SELECT 1 FROM OPENJSON(li.value, '$.discount_allocations'))
                                        THEN (
                                            SELECT 
                                                SUM(
                                                    CAST(
                                                        ROUND(
                                                            CAST(
                                                                REPLACE(
                                                                    JSON_VALUE(da.value, '$.amount')
                                                                    , ','
                                                                    , '.'
                                                                ) AS DECIMAL(18,2)
                                                            ), 2
                                                        ) AS DECIMAL(18,2)
                                                    )
                                                ) / JSON_VALUE(li.value, '$.quantity')
                                            FROM OPENJSON(li.value, '$.discount_allocations') as da
                                        )
                                    ELSE 0
                                END
                            )
                        )
				FROM @Movto_Pedidos_Comercial	AS	m
					LEFT JOIN @precios_ERP AS pe 
						ON 
							pe.f121_id_barras_principal = m.f431_codigo_barras
					INNER JOIN variantes v 
                        ON 
                            v.sku_erp = m.f431_codigo_barras
					INNER JOIN OPENJSON(@json, '$.line_items') AS li 
						ON 
							v.id_variante = JSON_VALUE(li.value, '$.variant_id')
				WHERE 
					f431_id_motivo = @IdMotivoProducto 
					AND 
					(
                        pe.f126_precio - 
                        (
                            JSON_VALUE(li.value, '$.price') - 
                            (
                                CASE 
                                    WHEN EXISTS (SELECT 1 FROM OPENJSON(li.value, '$.discount_allocations'))
                                        THEN (
                                            SELECT 
                                                SUM(
                                                    CAST(
                                                        ROUND(
                                                            CAST(
                                                                REPLACE(
                                                                    JSON_VALUE(da.value, '$.amount')
                                                                    , ','
                                                                    , '.'
                                                                ) AS DECIMAL(18,2)
                                                            ), 2
                                                        ) AS DECIMAL(18,2)
                                                    )
                                                )
                                            FROM OPENJSON(li.value, '$.discount_allocations') as da
                                        )
                                    ELSE 0
                                END
                            )
                        )   
                    )   >   0
                ORDER BY m.f431_nro_registro;
			END

			IF EXISTS (SELECT 1 FROM @Movto_Pedidos_Comercial)
			BEGIN
				INSERT into @final(
					idDocumento,
					indicaParalelismo,
					descripcion,
					idOrden,
					json
				)
				SELECT
					@idDocumento,
					@indicaParalelismo,
					@descripcion,
					@order as idOrden,
					(
						SELECT
							[Pedidos] = (
								SELECT *
								FROM @pedidos
								FOR JSON PATH
							),
							[Movto_Pedidos_Comercial] = (
								SELECT *
								FROM @Movto_Pedidos_Comercial
								FOR JSON PATH
							),
							[Descuentos] = (
								SELECT *
								FROM @descuentos
								FOR JSON PATH
							)
						FOR JSON PATH,WITHOUT_ARRAY_WRAPPER
					);
			END

			/*	ELIMINAR TABLAS DE SECCIONES DEL CONECTOR	*/
			DELETE @pedidos;
			DELETE @Movto_Pedidos_Comercial;
			DELETE @descuentos

			/*	ELIMINAR TABLAS DE DATOS DE SHOPIFY	*/
			DELETE @descuentos_shopify;
			DELETE @shipping_lines;
			
		END TRY
		BEGIN CATCH
			/*	ELIMINAR TABLAS DE SECCIONES DEL CONECTOR	*/
			DELETE @pedidos;
			DELETE @Movto_Pedidos_Comercial;
			DELETE @descuentos

			/*	ELIMINAR TABLAS DE DATOS DE SHOPIFY	*/
			DELETE @descuentos_shopify;
			DELETE @shipping_lines;
		END CATCH

		SET @counter = @counter + 1;
	END
END TRY
BEGIN CATCH
	SELECT
		CAST(1 AS BIT) AS indicaError, 
		CONCAT('Error: ', ERROR_MESSAGE()) as descripcionError;
END CATCH

SELECT DISTINCT * from @final AS final_json;