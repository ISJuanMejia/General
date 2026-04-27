
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

	DECLARE @id_tipo_docto_erp	NVARCHAR(3)	=	'PV';

--->================================================================================================================<---
	/*
		*	Tablas con datos del ERP
	*/
	DECLARE @t430_cm_pv_docto	TABLE
	(
		f430_referencia				NVARCHAR(10),
		f430_num_docto_referencia	NVARCHAR(15)
	)

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
				f430_consec_docto           ,
				f430_fecha_entrega          ,
				f430_id_cli_contado			,
    		    f430_id_co                  ,
    		    f430_id_co_fact             ,
    		    f430_id_cond_pago           ,
				f430_id_fecha               ,
				f430_id_moneda_conv			,
				f430_id_moneda_docto		,
				f430_id_moneda_local		,
				f430_id_punto_envio			,
    		    f430_id_sucursal_fact       ,
    		    f430_id_sucursal_rem        ,
				f430_id_tercero_fact        ,
				f430_id_tercero_rem         ,
    		    f430_id_tercero_vendedor    ,
    		    f430_id_tipo_cli_fact       ,
    		    f430_id_tipo_docto          ,
    		    f430_ind_estado             ,
    		    f430_ind_backorder          ,
				f419_ind_descuento			,
				f430_notas                  ,
				f430_num_dias_entrega		,
    		    f430_num_docto_referencia   ,
				f430_referencia             ;

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