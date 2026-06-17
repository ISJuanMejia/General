BEGIN TRY
    SET XACT_ABORT ON;
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
	DECLARE	@idDocumento			INT			=	'240659',
			@descripcionConector	VARCHAR(50)	=	'Ecommerce_Pedidos_Estandar',
			@indicaParalelismo		BIT			=	0;

--->================================================================================================================<---

	/*
		*	Configuración de ejecución del script
	*/
	DECLARE @batch_size    INT = 25;  -- Órdenes por petición
    DECLARE @max_intentos  INT = 3;   -- Límite estricto de intentos (< no <=)
    DECLARE @tomar_fecha_actual BIT = 1;   -- 1 = Tomar fecha actual del sistema, 0 = Tomar fecha del JSON

	/*
		*	Origen de los datos del cliente/tercero
		*		1 = Desde la sección Customer
		*		2 = Desde la sección Billing Address
		*		3 = Desde la sección Customer y si no existe, desde Billing Address
		*		4 = Desde la sección Billing Address y si no existe, desde Customer
	*/
	DECLARE @client_origin_data	INT	=	4;

	DECLARE @path_customer	NVARCHAR(100)	=	'$.customer.default_address';
	DECLARE @path_billing	NVARCHAR(100)	=	'$.billing_address';

    /*
		*	Cliente ocasional cuando el cliente no tiene cédula
	*/
    DECLARE @id_cliente_ocasional   NVARCHAR(20)    =   '222222222222';

    /*
        *   Referencia flete
    */
    DECLARE @id_item_flete  NVARCHAR(50)    =   '13760';

    /*
        *   Número de días de entrega
    */
    DECLARE @num_dias_entrega   INT =   1;

--->================================================================================================================<---

    /*
		*	Definición de la tabla de pedidos del ERP
	*/
	DECLARE @t430_cm_pv_docto TABLE (
		f430_num_docto_referencia   NVARCHAR(15)
	);

--->================================================================================================================<---

    /*
        *   Obtener la cadena de conexión del ERP
    */
    DECLARE @conexion   NVARCHAR(MAX);
    DECLARE @base_datos NVARCHAR(MAX);

    SELECT TOP 1
        @conexion   =   cadena_conexion,
        @base_datos =   base_datos
    FROM [shopify-colombia-womder].dbo.conexiones;

    /*
		*	Consulta a la tabla de pedidos del ERP
	*/
    INSERT INTO @t430_cm_pv_docto
	EXEC
    (
        '
        SELECT DISTINCT
            f430_num_docto_referencia
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f430_num_docto_referencia
                FROM ' + @base_datos + '.dbo.t430_cm_pv_docto
                    WHERE 
                        f430_ind_estado != 9
                        AND 
                        f430_id_cia = 1
            ''
        )
        '
    );

--->================================================================================================================<---

	DECLARE @ordenes TABLE (
		id_orden	NVARCHAR(20),
		orden_obj	NVARCHAR(MAX)
	);

    UPDATE ord
    SET id_estado = 3
    FROM [shopify-colombia-womder].dbo.ordenes AS ord
        INNER JOIN @t430_cm_pv_docto
            ON
                f430_num_docto_referencia   =   id_orden
    WHERE
        id_estado = 2
    
    
    UPDATE ord
    SET id_estado = 2
    FROM [shopify-colombia-womder].dbo.ordenes AS ord
        LEFT JOIN @t430_cm_pv_docto
            ON
                f430_num_docto_referencia   =   id_orden
    WHERE
        id_estado = 3
        AND
        f430_num_docto_referencia   IS NULL

	/*
		*	Obtener órdenes pendientes de procesamiento que se encuentran en estado 2 y 
		*	tienen menos de 3 intentos de procesamiento
	*/
	INSERT INTO @ordenes (id_orden, orden_obj)
	SELECT TOP (@batch_size)
		id_orden, 
		orden_obj
	FROM [shopify-colombia-womder].dbo.ordenes
        LEFT JOIN @t430_cm_pv_docto
            ON
                f430_num_docto_referencia   =   id_orden
	WHERE 
		id_estado	=	2
		AND
		intentos	<=	@max_intentos
    ORDER BY ID DESC;

--->================================================================================================================<---

	/*
		*	Definición de la sección de Pedidos del conector
	*/
    DECLARE @Pedidos TABLE (
        f430_id_fecha               NVARCHAR(8),
        f430_id_tercero_fact        NVARCHAR(15),
        f430_id_tercero_rem         NVARCHAR(15),
        f430_fecha_entrega          NVARCHAR(8),
        f430_num_dias_entrega       NVARCHAR(3),
        f430_num_docto_referencia   NVARCHAR(15),
        f430_id_cond_pago           NVARCHAR(3),
        f430_notas                  NVARCHAR(2000)
    );

    /*
		*	Definición de la sección de Movto Pedidos comercial del conector
	*/
    DECLARE @Movto_Pedidos_comercial TABLE (
        id                      NVARCHAR(20),
        f431_nro_registro       NVARCHAR(10),
        f431_id_item    NVARCHAR(50),
        f431_id_ext1_detalle    NVARCHAR(20),
        f431_id_ext2_detalle    NVARCHAR(20),
        f431_fecha_entrega      NVARCHAR(8),
        f431_num_dias_entrega   NVARCHAR(3),
        f431_cant_pedida_base   NVARCHAR(20),
        f431_precio_unitario    NVARCHAR(20)
    );

    /*
		*	Definición de la sección de Descuentos del conector
	*/
	DECLARE @Descuentos	TABLE (
		f431_nro_registro	NVARCHAR(10),
        f432_vlr_uni        NVARCHAR(20)
	);
	
--->================================================================================================================<---

    DECLARE @line_items TABLE
    (
        id                      NVARCHAR(20),
        price                   NVARCHAR(20),
        quantity                NVARCHAR(20),
        sku                     NVARCHAR(200),
        id_item                 NVARCHAR(20),
        ext_1                   NVARCHAR(20),
        ext_2                   NVARCHAR(20),
        variant_title           NVARCHAR(20),
        discount_amount         NVARCHAR(MAX)
    );

--->================================================================================================================<---

	/*
		*	Definición de variables para el procesamiento de las órdenes
	*/
	DECLARE @order		NVARCHAR(30);
	DECLARE @json		NVARCHAR(MAX)	= 	'';
	DECLARE @total		INT	=	(SELECT COUNT(*) FROM @ordenes);	--	*	Total de órdenes a procesar
	DECLARE @counter	INT	=	1;
    
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
				LEFT(
                    REPLACE(
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
				    	END,
				    	'.',
				    	''
				    ),
                    15
                );
			
			SET @id_cliente = ISNULL(NULLIF(TRIM(@id_cliente), ''), @id_cliente_ocasional);

            DECLARE @id_cond_pago   NVARCHAR(3) = '001';
            
            SELECT  TOP 1
                @id_cond_pago   =
                    CASE 
                        WHEN JSON_VALUE(transaccion_obj, '$.gateway') = 'Wompi' 
                            THEN 'WO+'
                        WHEN JSON_VALUE(transaccion_obj, '$.gateway') = 'Bold' 
                            THEN 'BO+'
                        WHEN JSON_VALUE(transaccion_obj, '$.gateway') = 'Addi Payment' 
                            THEN 'ADDI'
                        ELSE '001'
                    END
            FROM transacciones_ordenes
            WHERE
                id_orden    =   JSON_VALUE(@json, '$.id')
                AND
                JSON_VALUE(transaccion_obj, '$.status') = 'success';
            
            
            DECLARE @id_fecha		NVARCHAR(8)	=	
                CASE 
                    WHEN    @tomar_fecha_actual = 1 
                        THEN
                            REPLACE(
                                CONVERT(
                                    VARCHAR(10), 
                                    GETDATE(), 
                                    120
                                ), 
                                '-', 
                                ''
                            )
                    ELSE REPLACE(
                            CONVERT(
                                VARCHAR(10), 
                                CAST(
                                    JSON_VALUE(@json, '$.updated_at') AS DATE
                                )
                            ), 
                            '-', 
                            ''
                        )
                END;
            
            DECLARE @id_fecha_entrega		NVARCHAR(8)	=	
                CASE 
                    WHEN @tomar_fecha_actual = 1 
                        THEN 
                            REPLACE(
                                CONVERT(
                                    VARCHAR(10), 
                                    DATEADD(
                                        DAY, 
                                        @num_dias_entrega, 
                                        GETDATE()
                                    ), 
                                    120
                                ), 
                                '-', 
                                ''
                            )
                    ELSE
                        REPLACE(
                            CONVERT(
                                VARCHAR(10), 
                                DATEADD(
                                    DAY, 
                                    @num_dias_entrega,
                                    CAST(
                                        JSON_VALUE(@json, '$.updated_at') AS DATE
                                    )
                                )
                            ), 
                            '-', 
                            ''
                        )
                END;

--->================================================================================================================<---

            /*
                *	Inserción sección de pedidos
            */
            INSERT INTO @Pedidos
            (
                f430_id_fecha,
                f430_id_tercero_fact,
                f430_id_tercero_rem,
                f430_fecha_entrega,
                f430_num_dias_entrega,
                f430_num_docto_referencia,
                f430_id_cond_pago,
                f430_notas
            )
            SELECT
                f430_id_fecha               =   @id_fecha,
                f430_id_tercero_fact        =   @id_cliente,
                f430_id_tercero_rem         =   @id_cliente,
                f430_fecha_entrega          =   @id_fecha_entrega,
                f430_num_dias_entrega       =   @num_dias_entrega,
                f430_num_docto_referencia   =   @order,
                f430_id_cond_pago           =   @id_cond_pago,
                f430_notas                  =   @order;

--->================================================================================================================<---

	        /*
	        	*	Consulta de los items del pedido y su descuento
	        */
            INSERT INTO @line_items
            SELECT
                id                  = JSON_VALUE(LI.value, '$.id'),
                price               = JSON_VALUE(LI.value, '$.price_set.presentment_money.amount'),
                quantity            = JSON_VALUE(LI.value, '$.quantity'),
                sku                 = JSON_VALUE(LI.value, '$.sku'),
                id_item             = MAX(CASE WHEN S.ordinal = 1 THEN S.value END),
                ext_1               = MAX(CASE WHEN S.ordinal = 2 THEN S.value END),
                ext_2               = MAX(CASE WHEN S.ordinal = 3 THEN S.value END),
                variant_title       = JSON_VALUE(LI.value, '$.variant_title'),
                discount_amount     = (
                                        SELECT
                                            SUM(CAST(JSON_VALUE(DA.value, '$.amount') AS DECIMAL(10,4)))
                                            / NULLIF(CAST(JSON_VALUE(LI.value, '$.quantity') AS INT), 0)
                                        FROM OPENJSON(LI.value, '$.discount_allocations') AS DA
                                    )
            FROM OPENJSON(@json, '$.line_items') AS LI
            CROSS APPLY STRING_SPLIT(JSON_VALUE(LI.value, '$.sku'), '-', 1) AS S
            WHERE
                CAST(JSON_VALUE(LI.value, '$.gift_card') AS BIT) = 0
            GROUP BY
                LI.value;  -- Agrupar por el nodo completo resuelve todo

	        /*
	        	*	Inserción sección de movimientos pedidos comercial
	        */
            INSERT INTO @Movto_Pedidos_comercial
            (
                id,
                f431_nro_registro,
                f431_id_item,
                f431_id_ext1_detalle,
                f431_id_ext2_detalle,
                f431_fecha_entrega,
                f431_num_dias_entrega,
                f431_cant_pedida_base,
                f431_precio_unitario
            )
            SELECT
                id                      =   id,
                f431_nro_registro       =   ROW_NUMBER() OVER (ORDER BY id),
                f431_id_item    =   id_item,
                f431_id_ext1_detalle    =   ext_1,
                f431_id_ext2_detalle    =   ext_2,
                f431_fecha_entrega      =   @id_fecha_entrega,
                f431_num_dias_entrega   =   @num_dias_entrega,
                f431_cant_pedida_base   =   quantity,
                f431_precio_unitario    =   price
            FROM @line_items;

            INSERT INTO @Movto_Pedidos_comercial
            (
                id,
                f431_nro_registro,
                f431_id_item,
                f431_id_ext1_detalle,
                f431_id_ext2_detalle,
                f431_fecha_entrega,
                f431_num_dias_entrega,
                f431_cant_pedida_base,
                f431_precio_unitario
            )
            SELECT
                id                      =   0,
                f431_nro_registro       =   0,
                f431_id_item            =   @id_item_flete,
                f431_id_ext1_detalle    =   '',
                f431_id_ext2_detalle    =   '',
                f431_fecha_entrega      =   @id_fecha_entrega,
                f431_num_dias_entrega   =   @num_dias_entrega,
                f431_cant_pedida_base   =   '1',
                f431_precio_unitario    =   JSON_VALUE(SL.value, '$.price_set.presentment_money.amount')
            FROM OPENJSON(@json, '$.shipping_lines') AS SL
            WHERE
                CAST(JSON_VALUE(SL.value, '$.price') AS DECIMAL(10,4)) > 0

--->================================================================================================================<---

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
                        LI.id   =   MPC.id
            WHERE
                LI.discount_amount  IS NOT NULL
                AND
                CAST(LI.discount_amount AS DECIMAL(10,4)) != 0;

            IF EXISTS (SELECT 1 FROM @Movto_Pedidos_comercial)
            BEGIN
                INSERT INTO @final
                (
                    idDocumento,
                    indicaParalelismo,
                    descripcion,
                    idOrden,
                    json
                )
                SELECT
                    @idDocumento,
                    @indicaParalelismo,
                    @descripcionConector,
                    @order,
                    CAST(
                        (
                            SELECT
                                Pedidos =
                                (
                                    SELECT * 
                                    FROM @Pedidos 
                                    FOR JSON PATH
                                ),
                                [Movto Pedidos comercial]   =
                                (
                                    SELECT * 
                                    FROM @Movto_Pedidos_comercial 
                                    FOR JSON PATH
                                ),
                                Descuentos  =   
                                (
                                    SELECT * 
                                    FROM @Descuentos 
                                    FOR JSON PATH
                                )
                            FOR JSON PATH, 
                            WITHOUT_ARRAY_WRAPPER
                        ) AS VARCHAR(MAX)
                    );
                END
                ELSE
                BEGIN
                    UPDATE [shopify-colombia-womder].dbo.ordenes
                    SET id_estado = 3
                    WHERE
                        id_orden = @order
                END
        END TRY
        BEGIN CATCH
            /*
            SELECT
                ErrorNumber         =   ERROR_NUMBER(),
                ErrorSeverity       =   ERROR_SEVERITY(),
                ErrorState          =   ERROR_STATE(),
                ErrorProcedure      =   ERROR_PROCEDURE(),
                ErrorLine           =   ERROR_LINE(),
                ErrorMessage        =   ERROR_MESSAGE();
            */

            UPDATE [shopify-colombia-womder].dbo.ordenes
            SET intentos = intentos + 1
            WHERE
                id_orden = @order
        END CATCH
        DELETE @Pedidos
        DELETE @Movto_Pedidos_comercial
        DELETE @Descuentos
        DELETE @line_items
        SET @counter += 1;
    END
END TRY
BEGIN CATCH
    SELECT
        0    AS idDocumento,
        0    AS indicaParalelismo,
        ERROR_MESSAGE() AS descripcion,
        '0'  AS idOrden,
        NULL AS json;
END CATCH;

SELECT * FROM @final;