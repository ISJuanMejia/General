
SET XACT_ABORT ON;
BEGIN TRY
	/*
		*	Definición de tabla de resultados
	*/
	DECLARE @final	TABLE (
		idDocumento			INT,
		indicaParalelismo	BIT,
		descripcion			VARCHAR(50),
		idOrden				VARCHAR(50),
		json				VARCHAR(MAX)
	);

	/*
		*	Definición de información del conector: ID del documento, descripción y si indica paralelismo:
		*		ID del documento: Consultar en Connekta el Id del Conector.
		*		Descripción: Nombre del conector
		*		Indica paralelismo: 1 = Sí, 0 = No, dependiendo si el conector soporta múltiples hilos de ejecución.
	*/
	DECLARE	@idDocumento			INT			=	'000000',
			@descripcionConector	VARCHAR(50)	=	'Ecommerce_Pedidos_Estandar',
			@indicaParalelismo		BIT			=	0;

--->================================================================================================================<---

	/*
		*	Configuración de ejecución del script
	*/
	DECLARE @batch_size	INT	=   25;	--	*	Cuantas órdenes se traen por petición

	/*
		*	Origen de los datos del cliente/tercero
		*		1 = Desde la sección Customer
		*		2 = Desde la sección Billing Address
		*		3 = Desde la sección Customer y si no existe, desde Billing Address
		*		4 = Desde la sección Billing Address y si no existe, desde Customer
		*	
		*	Nota: Debe dejarse igual que lo que se coloque en la consulta de terceros.
	*/
	DECLARE @client_origin_data	INT	=	4;
	
	DECLARE @path_customer	NVARCHAR(100)	=	'$.customer.default_address';
	DECLARE @path_billing	NVARCHAR(100)	=	'$.billing_address';

	DECLARE @id_cliente_ocasional	NVARCHAR(100)	=	'';

	/*
		*	Campo para validar la exitencia de un pedido en el ERP:
		*		0	->	Validar con el campo f430_referencia
		*		1	->	Validar con el campo f430_num_docto_referencia
		*		2	->	Validar con los campos f430_referencia y f430_num_docto_referencia
	*/
	DECLARE @order_validation_data	INT	=	2;

	/*
		*	Id tipo de cliente:
		*		1	->	id_tipo_cliente 1
		*		2	->	id_tipo_cliente 2
		*		3	->	id_tipo_cliente 3
		*		4	->	id_tipo_cliente 4
	*/
	DECLARE @id_tipo_cliente_1	NVARCHAR(4) =   '1',
            @id_tipo_cliente_2	NVARCHAR(4) =   '2',
            @id_tipo_cliente_3	NVARCHAR(4) =   '3',
            @id_tipo_cliente_4	NVARCHAR(4) =   '4';

	DECLARE @id_tipo_docto_erp			NVARCHAR(3)	=	'PV';

	DECLARE @id_lista_precio_cerrada	NVARCHAR(3)	=	'001';

	DECLARE @num_dias_entrega	INT	=	1;

--->================================================================================================================<---
	/*
		*	Tablas con datos del ERP
	*/
	DECLARE @t430_cm_pv_docto	TABLE
	(
		f430_referencia				NVARCHAR(10),
		f430_num_docto_referencia	NVARCHAR(15)
	);

	/*
		*	Definición de la tabla de precios del ERP
	*/
    DECLARE	@precios_ERP	TABLE (
        f126_precio		MONEY,
        f120_referencia	NVARCHAR(50)
    );

    /*
		*	Definición de la tabla de terceros del ERP
	*/
    DECLARE	@terceros_clientes_ERP	TABLE (
        f200_id			NVARCHAR(50),
        f015_id_pais    NVARCHAR(3)
    );

	/*
		*	Definición de la tabla de unidades de medida
	*/
	DECLARE @unidades_de_medida_por_extensiones TABLE (
		f121_id_barras_principal	NVARCHAR(20),
		f122_id_unidad				NVARCHAR(4)
	);

--->================================================================================================================<---
	/*
		*	Consultar datos en el ERP
	*/
	DECLARE @conexion	NVARCHAR(MAX);
    DECLARE @base_datos	NVARCHAR(MAX);

	SELECT
		@conexion	=	cadena_conexion,
		@base_datos	=	base_datos
	FROM Conexiones;

	/*
		*	Consultar pedidos existentes
	*/
	INSERT INTO @t430_cm_pv_docto
    EXEC('
        SELECT DISTINCT
			f430_referencia,
			f430_num_docto_referencia
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
				SELECT
					f430_referencia				=	TRIM(f430_referencia),
					f430_num_docto_referencia	=	TRIM(f430_num_docto_referencia)
				FROM ' + @base_datos + '.dbo.t430_cm_pv_docto
				WHERE 
					f430_ind_estado != 9
           			AND 
					f430_id_cia = 1
					AND
					(
						f430_referencia IS NOT NULL
						OR
						f430_num_docto_referencia IS NOT NULL
					)
					AND
					f430_id_tipo_docto	=	'''''+ @id_tipo_docto_erp +'''''
			''
        )
    ');

	/*
        *   Valida si el precio del ecommerce es diferente al del erp y si lo es lo toma como un descuento
    */
    INSERT INTO @precios_ERP
    EXEC('
        SELECT DISTINCT
            f126_precio,
            f120_referencia
        FROM OPENROWSET(
            ''SQLNCLI''
            ,''' + @conexion + '''
            ,''
                SELECT
                    f126_precio,
                    f120_referencia,
                    f126_fecha_activacion,
                    ROW_NUMBER() OVER (PARTITION BY f126_rowid_item ORDER BY f126_fecha_activacion DESC) AS rn_1
                FROM '+@base_datos + '.dbo.t120_mc_items
					INNER JOIN '+@base_datos +'.dbo.t121_mc_items_extensiones
						ON
							f120_rowid	=	f121_rowid_item
                    INNER JOIN '+@base_datos +'.dbo.t126_mc_items_precios
                        ON
                            f126_rowid_item	=	f120_rowid
                WHERE
                    f126_id_lista_precio = ''''LP1''''
            ''
        )
        WHERE
            rn_1 = 1'
    );

	/*
        *   Valida si el tercero del pedido existe, y si tiene el id del pais
    */
    INSERT INTO @terceros_clientes_ERP
    EXEC('
        SELECT DISTINCT
            f200_id,
            f015_id_pais
        FROM OPENROWSET(
            ''SQLNCLI''
            ,''' + @conexion + '''
            ,''
                SELECT
                    f200_id,
                    f015_id_pais
                FROM '+@base_datos + '.dbo.t200_mm_terceros
                    INNER JOIN '+@base_datos + '.dbo.t201_mm_clientes
                        ON
                            f200_rowid  =   f201_rowid_tercero
                    INNER JOIN '+@base_datos + '.dbo.t015_mm_contactos
                        ON
                            f015_rowid  =   f201_rowid_contacto
            ''
        )
    ');

--->================================================================================================================<---

	/*
		*	Definición de la sección de pedidos del conector
	*/
	DECLARE @pedidos	TABLE (
        f430_consec_docto           NVARCHAR(8),
		f430_fecha_entrega          NVARCHAR(8),
		f430_id_cli_contado			NVARCHAR(15),
        f430_id_co                  NVARCHAR(3),
        f430_id_co_fact             NVARCHAR(3),
        f430_id_cond_pago           NVARCHAR(3),
		f430_id_fecha               NVARCHAR(8),
		f430_id_moneda_conv			NVARCHAR(3),
		f430_id_moneda_docto		NVARCHAR(3),
		f430_id_moneda_local		NVARCHAR(3),
		f430_id_punto_envio			NVARCHAR(3),
        f430_id_sucursal_fact       NVARCHAR(3),
        f430_id_sucursal_rem        NVARCHAR(3),
		f430_id_tercero_fact        NVARCHAR(15),
		f430_id_tercero_rem         NVARCHAR(15),
        f430_id_tercero_vendedor    NVARCHAR(15),
        f430_id_tipo_cli_fact       NVARCHAR(4),
        f430_id_tipo_docto          NVARCHAR(3),
        f430_ind_estado             NVARCHAR(1),
        f430_ind_backorder          NVARCHAR(1),
		f419_ind_descuento			NVARCHAR(1),
		f430_notas                  NVARCHAR(2000),
		f430_num_dias_entrega		NVARCHAR(3),
        f430_num_docto_referencia   NVARCHAR(15),
		f430_referencia             NVARCHAR(10)
	);

	/*
		*	Definición de la sección de movimientos pedidos comercial del conector
	*/
	DECLARE @movto_pedidos_comercial	TABLE (
		line_item_id			BIGINT,
		f431_cant_pedida_base   NVARCHAR(20),
		f431_codigo_barras      NVARCHAR(20),
		f431_consec_docto       NVARCHAR(8),
		f431_detalle			NVARCHAR(2000),
		f431_fecha_entrega      NVARCHAR(8),
		f431_id_bodega          NVARCHAR(5),
		f431_id_ccosto_movto    NVARCHAR(15),
		f431_id_co              NVARCHAR(3),
		f431_id_co_movto        NVARCHAR(3),
		f431_id_ext1_detalle    NVARCHAR(20),
		f431_id_ext2_detalle    NVARCHAR(20),
		f431_id_item            NVARCHAR(7),
		f431_id_lista_precio    NVARCHAR(3),
		f431_id_motivo          NVARCHAR(2),
		f431_id_un_movto        NVARCHAR(20),
		f431_id_tipo_docto      NVARCHAR(3),
		f431_id_unidad_medida   NVARCHAR(4),
		f431_ind_backorder      NVARCHAR(1),
		f431_ind_impto_asumido  NVARCHAR(1),
		f431_ind_obsequio		NVARCHAR(1),
		f431_ind_precio         NVARCHAR(1),
		f431_notas              NVARCHAR(255),
		f431_nro_registro       NVARCHAR(10),
		f431_num_dias_entrega   NVARCHAR(3),
		f431_precio_unitario    NVARCHAR(20),
		f431_referencia_item    NVARCHAR(50)
	);

	/*
		*	Definición de la sección de descuentos del conector
	*/
	DECLARE @descuentos	TABLE (
		f430_consec_docto   NVARCHAR(8),
		f430_id_co          NVARCHAR(3),
		f430_id_tipo_docto	NVARCHAR(3),
		f431_nro_registro	NVARCHAR(10),
		f432_tasa			NVARCHAR(8),
		f432_vlr_uni		NVARCHAR(20)
	);

--->================================================================================================================<---

    DECLARE @line_items TABLE
    (
        id                      NVARCHAR(20),
        price                   NVARCHAR(20),
        quantity                NVARCHAR(20),
        sku                     NVARCHAR(20),
        barcode                 NVARCHAR(20),
        variant_title           NVARCHAR(20),
        discount_amount         NVARCHAR(MAX)
    );
	
--->================================================================================================================<---
	
	/*
        *   Actualizar a estado 2 pedidos que estén en estado superior a 3
    */
    UPDATE ord
    SET id_estado = 2
    FROM [dbo].[ordenes] AS ord
    WHERE
        id_estado = 4;

    /*
        *   Actualizar a estado 3 pedidos ya existentes
    */
    UPDATE ord
    SET id_estado = 3
    FROM [ordenes] AS ord
        INNER JOIN @t430_cm_pv_docto
            ON
                f430_num_docto_referencia   =   id_orden
                OR
                f430_referencia =   id_orden
    WHERE
        id_estado = 2;
    
    /*
        *   Actualizar a estado 2 pedidos aún no existentes pero que aparece como que ya existieran
    */
    UPDATE ord
    SET id_estado = 2
    FROM [ordenes] AS ord
        LEFT JOIN @t430_cm_pv_docto
            ON
                f430_num_docto_referencia   =   id_orden
                OR
                f430_referencia =   id_orden
    WHERE
        id_estado   <=  3
        AND
        (
            f430_num_docto_referencia   IS NULL
            AND
            f430_referencia   IS NULL
        );

	DECLARE @ordenes TABLE (
		id_orden	NVARCHAR(20),
		orden_obj	NVARCHAR(MAX)
	);

	/*
		*	Obtener órdenes pendientes de procesamiento que se encuentran en estado 2 y 
		*	tienen menos de 3 intentos de procesamiento
	*/
	INSERT INTO @ordenes (id_orden, orden_obj)
	SELECT TOP (@batch_size)
		id_orden, 
		orden_obj
	FROM ordenes
		LEFT JOIN @t430_cm_pv_docto
			ON
				f430_num_docto_referencia	=	id_orden
				OR
				f430_referencia	=	id_orden
	WHERE 
		id_estado	=	2
		AND
		intentos	<=	3
		AND
		f430_num_docto_referencia	IS NULL
		AND
		f430_referencia	IS NULL;

--->================================================================================================================<---

	/*
		*	Definición de variables para el procesamiento de las órdenes
	*/
	DECLARE @order		NVARCHAR(30);
	DECLARE @json		NVARCHAR(MAX)	= 	'';
	DECLARE @total		INT	=	(SELECT COUNT(*) FROM @ordenes);	--	*	Total de órdenes a procesar
	DECLARE @counter	INT	=	1;									--	*	Contador de órdenes procesadas

	WHILE @counter <= @total
	BEGIN
		BEGIN TRY
			/*
				*	Obtener el JSON de la orden actual
			*/
			SET @json	=	(
				SELECT
					orden_obj
				FROM (
					SELECT 
						orden_obj, 
						ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
					FROM @ordenes
				) AS temp
				WHERE
					rn = @counter
			);

			SET @order	=	JSON_VALUE(@json, '$.name');	--	*	Obtener el número de la orden

			DECLARE @id_cliente NVARCHAR(100) =
				CASE @client_origin_data
					WHEN 1 
						THEN 
							NULLIF(
								TRIM(
									JSON_VALUE(@json, @path_customer + '.company')
								)
								, ''
							)
					WHEN 2 
						THEN 
							NULLIF(
								TRIM(
									JSON_VALUE(@json, @path_billing  + '.company')
								)
								, ''
							)
					WHEN 3 
						THEN 
							COALESCE(
								NULLIF(
									TRIM(
										JSON_VALUE(@json, @path_customer + '.company')
									)
									, ''
								),
								NULLIF(
									TRIM(
										JSON_VALUE(@json, @path_billing  + '.company')
									)
									, ''
								)
							)
					WHEN 4 
						THEN 
							COALESCE(
								NULLIF(
									TRIM(
										JSON_VALUE(@json, @path_billing  + '.company')
									)
									, ''
								),
								NULLIF(
									TRIM(
										JSON_VALUE(@json, @path_customer + '.company')
									)
									, ''
								)
							)
				END;
			
			SET @id_cliente	=	
				ISNULL(
					NULLIF(
						TRIM(
							@id_cliente
						),
						''
					), 
					@id_cliente_ocasional
				);
			
			DECLARE @consec_docto   VARCHAR(50) =   JSON_VALUE(@json,'$.order_number');
			DECLARE @id_fecha       VARCHAR(8)  =   
						FORMAT(
							CAST(
								JSON_VALUE(@json, '$.updated_at') AS DATE
							),
							'yyyyMMdd'
						),
                    @fecha_entrega  VARCHAR(10) =   
						FORMAT(
							DATEADD(
								DAY,
								1,
								CAST(
									JSON_VALUE(@json, '$.updated_at') AS DATE
								)
							),
							'yyyyMMdd'
						);

			INSERT INTO @pedidos
			(
    		    f430_consec_docto,
				f430_fecha_entrega,
				f430_id_cli_contado,
    		    f430_id_co,
    		    f430_id_co_fact,
    		    f430_id_cond_pago,
				f430_id_fecha,
				f430_id_moneda_conv	,
				f430_id_moneda_docto,
				f430_id_moneda_local,
				f430_id_punto_envio,
    		    f430_id_sucursal_fact,
    		    f430_id_sucursal_rem,
				f430_id_tercero_fact,
				f430_id_tercero_rem,
    		    f430_id_tercero_vendedor,
    		    f430_id_tipo_cli_fact,
    		    f430_id_tipo_docto,
    		    f430_ind_estado,
    		    f430_ind_backorder,
				f419_ind_descuento,
				f430_notas,
				f430_num_dias_entrega,
    		    f430_num_docto_referencia,
				f430_referencia             
			)
			SELECT
				f430_consec_docto			=	@consec_docto,
				f430_fecha_entrega			=	'',
				f430_id_cli_contado			=	'',
    		    f430_id_co					=	'',
    		    f430_id_co_fact				=	'',
    		    f430_id_cond_pago           =	'',
				f430_id_fecha               =	'',
				f430_id_moneda_conv			=	'',
				f430_id_moneda_docto		=	'',
				f430_id_moneda_local		=	'',
				f430_id_punto_envio			=	'',
    		    f430_id_sucursal_fact       =	'',
    		    f430_id_sucursal_rem        =	'',
				f430_id_tercero_fact        =	'',
				f430_id_tercero_rem         =	'',
    		    f430_id_tercero_vendedor    =	'',
    		    f430_id_tipo_cli_fact       =	'',
    		    f430_id_tipo_docto          =	'',
    		    f430_ind_estado             =	'',
    		    f430_ind_backorder          =	'',
				f419_ind_descuento			=	'',
				f430_notas                  =	'',
				f430_num_dias_entrega		=	'',
    		    f430_num_docto_referencia   =	'',
				f430_referencia             =	'';

			INSERT INTO @line_items
            (
                id,
                price,
                quantity,
                sku,
                variant_title,
                discount_amount
            )
            SELECT
                id                      =   JSON_VALUE(LI.value, '$.id'),
                price                   =   JSON_VALUE(LI.value, '$.price_set.presentment_money.amount'),
                quantity                =   JSON_VALUE(LI.value, '$.quantity'),
                sku                     =   JSON_VALUE(LI.value, '$.sku'),
                variant_title           =   JSON_VALUE(LI.value, '$.variant_title'),
                discount_amount         =
                    (
                        SELECT
                            amount          =   
                                SUM(
                                    CAST(
                                        JSON_VALUE(DA.value, '$.amount') AS DECIMAL(10,4)
                                    )
                                ) / CAST(
                                    JSON_VALUE(LI.value, '$.quantity') AS INT
                                )
                        FROM OPENJSON(LI.VALUE, '$.discount_allocations') AS DA
                    )
            FROM OPENJSON(@json,'$.line_items') AS LI;

--->================================================================================================================<---

	        /*
	        	*	Inserción sección de descuentos
	        */
            INSERT INTO @Descuentos
            (
                f430_consec_docto,
                f431_nro_registro,
                f432_vlr_uni
            )
            SELECT
                f430_consec_docto   =   @consec_docto,
                f431_nro_registro   =   MPC.f431_nro_registro,
                f432_vlr_uni        =   CAST(LI.discount_amount AS DECIMAL(10,4))
            FROM @Movto_Pedidos_comercial AS MPC
                INNER JOIN @line_items AS LI
                    ON
                        LI.id   =   MPC.id
            WHERE
                LI.discount_amount  IS NOT NULL
                AND 
                CAST(LI.discount_amount AS DECIMAL) >   0
                AND
                CAST(LI.discount_amount AS DECIMAL) !=  CAST(LI.price AS DECIMAL);

			INSERT INTO @final(
				idDocumento,
				descripcion,
				indicaParalelismo,
				idOrden,
				json
			)
			SELECT 
				@idDocumento,
				@descripcionConector,
				@indicaParalelismo,
				@order as idOrden,
				(
					SELECT
						[Pedidos] = (
							SELECT *
							FROM @pedidos
							FOR JSON PATH,
							INCLUDE_NULL_VALUES
						),
						[movto pedidos comercial] = (
							SELECT *
							FROM @movto_pedidos_comercial
							FOR JSON PATH,
							INCLUDE_NULL_VALUES
						),
						[descuentos] = (
							SELECT *
							FROM @descuentos
							FOR JSON PATH,
							INCLUDE_NULL_VALUES
						)
					FOR JSON PATH,
					WITHOUT_ARRAY_WRAPPER,
					INCLUDE_NULL_VALUES
				);

			SET @counter = @counter + 1;
		END TRY
		BEGIN CATCH
			--	*	Registrar el error en la orden y continuar con la siguiente
			UPDATE ordenes
			SET 
				intentos	=	intentos + 1
			WHERE 
				id_orden	=	@order;
		END CATCH;

		SET @counter = @counter + 1;
	END

    SELECT * 
    FROM    @final AS final_json;
END TRY
BEGIN CATCH
    SELECT 
        ERROR_NUMBER()		AS	ErrorNumber,
        ERROR_SEVERITY()	AS	ErrorSeverity,
        ERROR_STATE()		AS	ErrorState,
        ERROR_PROCEDURE()	AS	ErrorProcedure,
        ERROR_LINE()		AS	ErrorLine,
        ERROR_MESSAGE()		AS	ErrorMessage;
END CATCH;