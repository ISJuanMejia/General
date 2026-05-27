
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
	DECLARE	@idDocumento			INT			=	'227666',
			@descripcionConector	VARCHAR(50)	=	'Pedidos De Venta',
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

	DECLARE @id_referencia_flete	NVARCHAR(50)	=	'0001547';

	DECLARE @id_tipo_docto_erp		NVARCHAR(3)		=	'PDV';

	DECLARE @num_dias_entrega	INT	=	1;

--->================================================================================================================<---
	/*
		*	Tablas con datos del ERP
	*/
	DECLARE @t430_cm_pv_docto	TABLE
	(
		f430_num_docto_referencia	NVARCHAR(15)
	);

    /*
		*	Definición de la tabla de terceros del ERP
	*/
    DECLARE	@terceros_clientes_ERP	TABLE (
        f200_id			NVARCHAR(50),
        f015_id_pais    NVARCHAR(3)
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
			f430_num_docto_referencia
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
				SELECT
					f430_num_docto_referencia	=	TRIM(f430_num_docto_referencia)
				FROM ' + @base_datos + '.dbo.t430_cm_pv_docto
				WHERE 
					f430_ind_estado != 9
           			AND 
					f430_id_cia = 3
					AND
					f430_num_docto_referencia IS NOT NULL
					AND
					f430_id_tipo_docto	=	'''''+ @id_tipo_docto_erp +'''''
			''
        )
    ');

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
		f430_fecha_entrega          NVARCHAR(8),
		f430_id_fecha               NVARCHAR(8),
		f430_id_tercero_fact        NVARCHAR(15),
		f430_id_tercero_rem         NVARCHAR(15),
		f430_notas                  NVARCHAR(2000),
        f430_num_docto_referencia   NVARCHAR(15),
        f430_fecha_entrega_min      NVARCHAR(8),
        f430_fecha_entrega_max      NVARCHAR(8)
	);

	/*
		*	Definición de la sección de movimientos pedidos comercial del conector
	*/
	DECLARE @movto_pedidos_comercial	TABLE (
		line_item_id			BIGINT,
		f431_cant_pedida_base   NVARCHAR(20),
		f431_codigo_barras      NVARCHAR(20),
		f431_referencia_item	NVARCHAR(50),
		f431_fecha_entrega      NVARCHAR(8),
		f431_notas              NVARCHAR(255),
		f431_nro_registro       NVARCHAR(10),
		f431_precio_unitario    NVARCHAR(20)
	);

	/*
		*	Definición de la sección de descuentos del conector
	*/
	DECLARE @descuentos	TABLE (
		f431_nro_registro	NVARCHAR(10),
		f432_vlr_uni		NVARCHAR(20)
	);

--->================================================================================================================<---

    DECLARE @line_items TABLE
    (
        id                      NVARCHAR(20),
        price                   NVARCHAR(20),
        quantity                NVARCHAR(20),
        barcode                 NVARCHAR(20),
        discount_amount         NVARCHAR(MAX)
    );
	
--->================================================================================================================<---

    /*
        *   Actualizar a estado 3 pedidos ya existentes
    */
    UPDATE ord
    SET id_estado = 3
    FROM [ordenes] AS ord
        INNER JOIN @t430_cm_pv_docto
            ON
                f430_num_docto_referencia   =   id_orden
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
    WHERE
        id_estado   IN	(3, 4)
        AND
        f430_num_docto_referencia   IS NULL;

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
	WHERE 
		id_estado	=	2
		AND
		intentos	<=	3
		AND
		f430_num_docto_referencia	IS NULL
	ORDER BY ID DESC;

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
								@num_dias_entrega,
								CAST(
									JSON_VALUE(@json, '$.updated_at') AS DATE
								)
							),
							'yyyyMMdd'
						);
			
			DECLARE @notas	NVARCHAR(2000)	=	NULL;
			
			--validar metodos de pago
			SELECT TOP 1
				@notas	=	JSON_VALUE(transaccion_obj, '$.gateway')
			FROM transacciones_ordenes
			WHERE
				id_orden	=	JSON_VALUE(@json, '$.id')
				AND
				JSON_VALUE(transaccion_obj, '$.status')	=	'success';

--->================================================================================================================<---

			INSERT INTO @pedidos
			(
				f430_fecha_entrega,
				f430_id_fecha,
				f430_id_tercero_fact,
				f430_id_tercero_rem,
				f430_notas,
    		    f430_num_docto_referencia,
				f430_fecha_entrega_min,
				f430_fecha_entrega_max
			)
			SELECT
				f430_fecha_entrega			=	@fecha_entrega,
				f430_id_fecha               =	@id_fecha,
				f430_id_tercero_fact        =	@id_cliente,
				f430_id_tercero_rem         =	@id_cliente,
				f430_notas                  =	@notas,
    		    f430_num_docto_referencia   =	@order,
				f430_fecha_entrega_min		=	@id_fecha,
				f430_fecha_entrega_max		=	@fecha_entrega;
				
--->================================================================================================================<---

			INSERT INTO @line_items
            (
                id,
                price,
                quantity,
                barcode,
                discount_amount
            )
            SELECT
                id                      =   JSON_VALUE(LI.value, '$.id'),
                price                   =   JSON_VALUE(LI.value, '$.price_set.presentment_money.amount'),
                quantity                =   JSON_VALUE(LI.value, '$.quantity'),
                barcode                 =   JSON_VALUE(variante_obj, '$.barcode'),
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
            FROM OPENJSON(@json,'$.line_items') AS LI
				LEFT JOIN	variantes	
					ON	
						JSON_VALUE(LI.value, '$.variant_id')	=	id_variante;

--->================================================================================================================<---
			/*
	        	*	Inserción sección de movimientos pedidos comercial
	        */
            INSERT INTO @Movto_Pedidos_comercial
            (
				line_item_id,
				f431_cant_pedida_base,
				f431_codigo_barras,
				f431_referencia_item,
				f431_fecha_entrega,
				f431_notas,
				f431_nro_registro,
				f431_precio_unitario
            )
            SELECT
                line_item_id			=   id,
                f431_cant_pedida_base   =   quantity,
				f431_codigo_barras		=	barcode,
				f431_referencia_item	=	'',
                f431_fecha_entrega      =   @fecha_entrega,
				f431_notas				=	@notas,
                f431_nro_registro       =   ROW_NUMBER() OVER (ORDER BY id),
                f431_precio_unitario    =   price
            FROM @line_items;

			INSERT INTO @Movto_Pedidos_comercial
            (
                line_item_id,
				f431_cant_pedida_base,
				f431_codigo_barras,
				f431_referencia_item,
				f431_fecha_entrega,
				f431_notas,
				f431_nro_registro,
				f431_precio_unitario
            )
            SELECT
                line_item_id			=   0,
                f431_cant_pedida_base	=   1,
                f431_codigo_barras		=   '',
                f431_referencia_item    =   @id_referencia_flete,
                f431_fecha_entrega      =   @fecha_entrega,
				f431_notas				=	'',
				f431_nro_registro		=	0,
                f431_precio_unitario    =   JSON_VALUE(SL.value, '$.price')
            FROM OPENJSON(@json, '$.shipping_lines') AS SL
            WHERE
                CAST(JSON_VALUE(SL.value, '$.price') AS DECIMAL(10,4)) > 0

	        /*
	        	*	Inserción sección de descuentos
	        */
            INSERT INTO @Descuentos
            (
                f431_nro_registro,
                f432_vlr_uni
            )
            SELECT
                f431_nro_registro   =   MPC.f431_nro_registro,
                f432_vlr_uni        =   CAST(LI.discount_amount AS DECIMAL(10,4))
            FROM @Movto_Pedidos_comercial AS MPC
                INNER JOIN @line_items AS LI
                    ON
                        LI.id   =   MPC.line_item_id
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
						[Movimiento] = (
							SELECT *
							FROM @movto_pedidos_comercial
							FOR JSON PATH,
							INCLUDE_NULL_VALUES
						),
						[Descuentos] = (
							SELECT *
							FROM @descuentos
							FOR JSON PATH,
							INCLUDE_NULL_VALUES
						)
					FOR JSON PATH,
					WITHOUT_ARRAY_WRAPPER
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

		DELETE @pedidos;
		DELETE @line_items;
		DELETE @movto_pedidos_comercial;
		DELETE @descuentos;

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