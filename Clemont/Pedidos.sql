--VERSION FINAL CLEMONT PEDIDOS - PRUEBAS
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
	DECLARE	@idDocumento			INT			=	'228298',
			@descripcionConector	VARCHAR(50)	=	'Ecommerce_Pedidos_Estandar',
			@indicaParalelismo		BIT			=	0;
    
    /*
		*	Configuración de ejecución del script
	*/
	DECLARE @batch_size    INT = 25;  -- Órdenes por petición
    DECLARE @max_intentos  INT = 3;   -- Límite estricto de intentos (< no <=)

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
    DECLARE @id_cliente_ocasional   NVARCHAR(20)    =   '222222222';

    /*
        *   Número de días de entrega
    */
    DECLARE @num_dias_entrega   INT =   1;

    /*
        *   Vendedores
    */
    DECLARE @id_vendedor_defecto            NVARCHAR(20)    =   '901527979',
            @id_vendedor_lorenacano         NVARCHAR(20)    =   '1000398280',
            @id_vendedor_santiagomartinez   NVARCHAR(20)    =   '1010052735';

    /*
        *   Tags a validar
    */
    DECLARE @tag_lorenacano         NVARCHAR(20)    =   'lorenacano',
            @tag_santiagomartinez   NVARCHAR(20)    =   'santiagomartinez';

    /*
        *   Id Motivo
        *       '01'    ->  Producto
        *       '03'    ->  Obsequio
    */
    DECLARE @id_motivo_producto NVARCHAR(2) =   '01',
            @id_motivo_obsequio NVARCHAR(2) =   '03';

    /*
        *   Id  Centro de Costo
    */
    DECLARE @id_ccosto_producto NVARCHAR(5) =   '',
            @id_ccosto_obsequio NVARCHAR(5) =   '2002'

    /*
        *   Id Referencia
    */
    DECLARE @id_referencia_flete    NVARCHAR(15)    =   'FLE001';
    
    /*
        *   Tipo de proceso
        *       POS     ->  Agregar documentación
        *       ONLINE  ->  Agregar documentación
    */
    DECLARE @tipo_proceso  VARCHAR(20)   = 'POS';

    /*
		*	Definición de la tabla de pedidos del ERP
	*/
	DECLARE @t430_cm_pv_docto TABLE (
		f430_referencia             NVARCHAR(10),
		f430_num_docto_referencia   NVARCHAR(15)
	);

    /*
		*	Definición de la tabla de precios del ERP
	*/
    DECLARE  @precios_ERP TABLE (
        f126_precio                 MONEY,
        f120_referencia    NVARCHAR(50)
    )

    /*
        *   Obtener la cadena de conexión del ERP
    */
    DECLARE @conexion   NVARCHAR(MAX);
    DECLARE @base_datos NVARCHAR(MAX);

    SELECT TOP 1
        @conexion   =   cadena_conexion,
        @base_datos =   base_datos
    FROM [shopify-colombia-clemont].[dbo].[conexiones];

    /*
		*	Consulta a la tabla de pedidos del ERP
	*/
    INSERT INTO @t430_cm_pv_docto
	EXEC
    (
        '
        SELECT DISTINCT 
            f430_referencia,
            f430_num_docto_referencia
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT 
                    f430_referencia,
                    f430_num_docto_referencia
                FROM ' + @base_datos + '.[dbo].[t430_cm_pv_docto]
                    WHERE
                        F430_id_tipo_docto = ''''CPS''''
                        AND
                        f430_ind_estado != 9
                        AND 
                        f430_id_cia = 1
            ''
        )
        '
    );

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
                    INNER JOIN '+@base_datos +'.dbo.t126_mc_items_precios
                        ON
                            f126_rowid_item = f120_rowid
                WHERE
                    f126_id_lista_precio = ''''LP1''''
            ''
        )
        WHERE
            rn_1 = 1'
    );
	
--->================================================================================================================<---

    DECLARE @ordenes TABLE (
		id_orden	NVARCHAR(20),
		orden_obj	NVARCHAR(MAX)
	);

    UPDATE ord
    SET id_estado = 3
    FROM [shopify-colombia-clemont].[dbo].[ordenes] AS ord
        INNER JOIN @t430_cm_pv_docto
            ON
                f430_num_docto_referencia   =   id_orden
                OR
                f430_referencia =   id_orden
    WHERE
        id_estado = 2;

    /*
		*	Obtener órdenes pendientes de procesamiento que se encuentran en estado 2 y 
		*	tienen menos de 3 intentos de procesamiento
	*/
	INSERT INTO @ordenes (id_orden, orden_obj)
	SELECT TOP (@batch_size)
		id_orden, 
		orden_obj
	FROM [shopify-colombia-clemont].[dbo].[ordenes]
        LEFT JOIN @t430_cm_pv_docto
            ON
                f430_num_docto_referencia   =   id_orden
                OR
                f430_referencia =   id_orden
	WHERE
		id_estado	=	2
		AND
		intentos	<=	@max_intentos
        AND 
        (
            (
                @tipo_proceso = 'POS'
                AND (
                    -- Caso vacío
                    LTRIM(
                        RTRIM(
                            ISNULL(
                                JSON_VALUE(orden_obj, '$.tags'), 
                                ''
                            )
                        )
                    )   =   ''
                    -- Caso PERSONALSHOPPER
                    OR 
                    CHARINDEX(
                        'personalshopper',
                        LOWER(
                            ISNULL(
                                JSON_VALUE(orden_obj, '$.tags'), 
                                ''
                            )
                        )
                    ) > 0
                    -- Caso ecommerce
                    OR 
                    CHARINDEX(
                        'ecommerce',
                        LOWER(
                            ISNULL(
                                JSON_VALUE(orden_obj, '$.tags'), 
                                ''
                            )
                        )
                    ) > 0
                )
            )
            OR 
            (
                @tipo_proceso = 'ONLINE'
                AND 
                (
                    -- ONLINE acepta vacíos o ecommerce
                    LTRIM(
                        RTRIM(
                            ISNULL(
                                JSON_VALUE(orden_obj, '$.tags'), 
                                ''
                            )
                        )
                    ) = ''
                    OR 
                    CHARINDEX(
                        'ecommerce',
                        LOWER(
                            ISNULL(
                                JSON_VALUE(orden_obj, '$.tags'), 
                                ''
                            )
                        )
                    ) > 0
                )
            )
        )
    ORDER BY ID DESC; 
	
--->================================================================================================================<---

    /*
		*	Definición de la sección de Pedidos del conector
	*/
    DECLARE @Pedidos TABLE (
        f430_consec_docto           NVARCHAR(8),
        f430_id_fecha               NVARCHAR(8),
        f430_id_tercero_fact        NVARCHAR(15),
        f430_id_tercero_rem         NVARCHAR(15),
        f430_id_tipo_cli_fact       NVARCHAR(4),
        f430_fecha_entrega          NVARCHAR(8),
        f430_referencia             NVARCHAR(10),
        f430_num_docto_referencia   NVARCHAR(15),
        f430_notas                  NVARCHAR(2000),
        f430_id_tercero_vendedor    NVARCHAR(15)
    );

    /*
		*	Definición de la sección de Movto Pedidos comercial del conector
	*/
    DECLARE @Movto_Pedidos_comercial TABLE (
        id                      NVARCHAR(20),
        f431_consec_docto       NVARCHAR(8),
        f431_nro_registro       NVARCHAR(10),
        f431_referencia_item    NVARCHAR(50),
        f431_id_motivo          NVARCHAR(2),
        f431_ind_obsequio       NVARCHAR(1),
        f431_id_ccosto_movto    NVARCHAR(15),
        f431_fecha_entrega      NVARCHAR(8),
        f431_num_dias_entrega   NVARCHAR(3),
        f431_cant_pedida_base   NVARCHAR(20),
        f431_precio_unitario    NVARCHAR(20),
        f431_ind_impto_asumido  NVARCHAR(1)
    );

    /*
		*	Definición de la sección de Descuentos del conector
	*/
	DECLARE @Descuentos	TABLE (
        f430_consec_docto   NVARCHAR(8),
		f431_nro_registro	NVARCHAR(10),
        f432_vlr_uni        NVARCHAR(20)
	);
	
--->================================================================================================================<---

    DECLARE @line_items TABLE
    (
        id                      NVARCHAR(20),
        price                   NVARCHAR(20),
        quantity                NVARCHAR(20),
        sku                     NVARCHAR(20),
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
	
--->================================================================================================================<---
 
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

            DECLARE @id_vendedor    NVARCHAR(20)    =   @id_vendedor_defecto;

            DECLARE @id_tipo_cli_fact   NVARCHAR(10)    =   '';

            DECLARE @tags NVARCHAR(MAX) =   
                LOWER(
                    ISNULL(
                        JSON_VALUE(@json,'$.tags'), 
                        ''
                    )
                );
                
            IF @tags IS NOT NULL
            BEGIN
                SET @id_vendedor    =
                    CASE
                        WHEN    CHARINDEX(@tag_lorenacano, @tags)  >   0
                            THEN    @id_vendedor_lorenacano
                        WHEN    CHARINDEX(@tag_santiagomartinez, @tags) > 0
                            THEN    @id_vendedor_santiagomartinez
                        ELSE    @id_vendedor_defecto
                    END;

                SET @id_tipo_cli_fact   =
                    CASE
                        WHEN    CHARINDEX('sistecredito', @tags) > 0
                            THEN    'C005'
                        WHEN    CHARINDEX('addi', @tags) > 0
                            THEN    'C004'
                        WHEN    CHARINDEX('wompi', @tags) > 0 
                            THEN    'C009'
                        WHEN    CHARINDEX('bold', @tags) > 0 
                            THEN    'C013'
                        WHEN    CHARINDEX('mercado', @tags) > 0 
                            THEN    'C008'
                        WHEN    CHARINDEX('gift', @tags) > 0 
                            THEN    'C006'
                    END
            END;

            IF NULLIF(TRIM(@id_tipo_cli_fact), '') IS NULL
            BEGIN
                SELECT DISTINCT TOP 1
                    @id_tipo_cli_fact   =
                        CASE
                            WHEN    JSON_VALUE(transaccion_obj, '$.gateway') LIKE '%Sistecredito%'
                                THEN    'C005'
                            WHEN    JSON_VALUE(transaccion_obj, '$.gateway') LIKE '%Addi%'
                                THEN    'C004'
                            WHEN    JSON_VALUE(transaccion_obj, '$.gateway') LIKE '%Wompi%'
                                THEN    'C009'
                            WHEN    JSON_VALUE(transaccion_obj, '$.gateway') LIKE '%Bold%'
                                THEN    'C013'
                            WHEN
                                JSON_VALUE(transaccion_obj, '$.gateway') LIKE '%Mercado Pago%'
                                OR
                                JSON_VALUE(transaccion_obj, '$.gateway') LIKE '%MercadoPago%'
                                THEN    'C008'
                            WHEN    JSON_VALUE(transaccion_obj, '$.gateway') LIKE '%gift%'
                                THEN    'C006'
                        END
                FROM transacciones_ordenes
                WHERE
                    id_orden    =   JSON_VALUE(@json, '$.id')
                    AND
                    JSON_VALUE(transaccion_obj, '$.status') = 'success';
            END;
 
            SET @id_tipo_cli_fact   =   ISNULL(@id_tipo_cli_fact, '');
 
            DECLARE @consec_docto   VARCHAR(50) =   JSON_VALUE(@json,'$.order_number');
            DECLARE @id_fecha       VARCHAR(8)  =   FORMAT(CAST(JSON_VALUE(@json, '$.updated_at') AS DATE),'yyyyMMdd'),
                    @fecha_entrega  VARCHAR(10) =   FORMAT(DATEADD(DAY,1,CAST(JSON_VALUE(@json, '$.updated_at') AS DATE)),'yyyyMMdd');
 
            /* ========= PEDIDOS ========= */
            INSERT INTO @Pedidos
            (
                f430_consec_docto,
                f430_id_fecha,
                f430_id_tercero_fact,
                f430_id_tercero_rem,
                f430_id_tipo_cli_fact,
                f430_fecha_entrega,
                f430_referencia,
                f430_num_docto_referencia,
                f430_notas,
                f430_id_tercero_vendedor
            )
            SELECT
                f430_consec_docto         = @consec_docto,
                f430_id_fecha             = @id_fecha,
                f430_id_tercero_fact      = @id_cliente,
                f430_id_tercero_rem       = @id_cliente,
                f430_id_tipo_cli_fact     = @id_tipo_cli_fact,
                f430_fecha_entrega        = @fecha_entrega,
                f430_referencia           = @order,
                f430_num_docto_referencia = @order,
                f430_notas                = @order,
                f430_id_tercero_vendedor  = ISNULL(@id_vendedor, '');
                
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
            /* ========= MOVIMIENTOS ========= */
            INSERT INTO @Movto_Pedidos_comercial
            (
                id,
                f431_consec_docto,
                f431_nro_registro,
                f431_referencia_item,
                f431_id_motivo,
                f431_ind_obsequio,
                f431_id_ccosto_movto,
                f431_fecha_entrega,
                f431_num_dias_entrega,
                f431_cant_pedida_base,
                f431_precio_unitario,
                f431_ind_impto_asumido
            )
            SELECT
                id                      =   id,
                f431_consec_docto       =   @consec_docto,
                f431_nro_registro       =   ROW_NUMBER() OVER (ORDER BY id),
                f431_referencia_item    =   sku,
                f431_id_motivo          = 
                    CASE 
                        WHEN    TRY_CAST(price AS DECIMAL(18,2)) - TRY_CAST(discount_amount AS DECIMAL(18,2)) = 0 
                            THEN    @id_motivo_obsequio
                        ELSE    @id_motivo_producto
                    END,
                f431_ind_obsequio       = 
                    CASE 
                        WHEN    TRY_CAST(price AS DECIMAL(18,2)) - TRY_CAST(discount_amount AS DECIMAL(18,2)) = 0 
                            THEN 1 
                        ELSE 0 
                    END,
                f431_id_ccosto_movto    = 
                    CASE 
                        WHEN    TRY_CAST(price AS DECIMAL(18,2)) - TRY_CAST(discount_amount AS DECIMAL(18,2)) = 0 
                            THEN    @id_ccosto_obsequio 
                        ELSE    @id_ccosto_producto 
                    END,
                f431_fecha_entrega      =   @fecha_entrega,
                f431_num_dias_entrega   =   @num_dias_entrega,
                f431_cant_pedida_base   =   quantity,
                f431_precio_unitario    =
                    CASE
                        WHEN CAST(price AS DECIMAL) = 0
                            THEN p.f126_precio
                        ELSE CAST(price AS DECIMAL)
                    END,
                f431_ind_impto_asumido  = 
                    CASE 
                        WHEN    TRY_CAST(price AS DECIMAL(18,2)) - TRY_CAST(discount_amount AS DECIMAL(18,2)) = 0 
                            THEN 1 
                        ELSE 0 
                    END
            FROM @line_items
                LEFT JOIN @precios_ERP p
                    ON p.f120_referencia = SKU;

            /* ========= SHIPPING ========= */
            INSERT INTO @Movto_Pedidos_comercial
            (
                id,
                f431_consec_docto,
                f431_nro_registro,
                f431_referencia_item,
                f431_id_motivo,
                f431_ind_obsequio,
                f431_id_ccosto_movto,
                f431_fecha_entrega,
                f431_num_dias_entrega,
                f431_cant_pedida_base,
                f431_precio_unitario,
                f431_ind_impto_asumido
            )
                SELECT
                    id                      =   0,
                    f431_consec_docto       =   @consec_docto,
                    f431_nro_registro       =   0,
                    f431_referencia_item    =   @id_referencia_flete,
                    f431_id_motivo          =   @id_motivo_producto,
                    f431_ind_obsequio       =   0,
                    f431_id_ccosto_movto    =   @id_ccosto_producto,
                    f431_fecha_entrega      =   @fecha_entrega,
                    f431_num_dias_entrega   =   @num_dias_entrega,
                    f431_cant_pedida_base   =   1,
                    f431_precio_unitario    =   JSON_VALUE(sl.value,'$.price'),
                    f431_ind_impto_asumido  =   0
            FROM OPENJSON(@json, '$.shipping_lines') AS SL
            WHERE
                CAST(JSON_VALUE(SL.value, '$.price') AS DECIMAL(10,4)) > 0

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
                CAST(LI.discount_amount AS DECIMAL) >   0;
 
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
        END TRY
        BEGIN CATCH
            -- SELECT
            --     ErrorNumber         =   ERROR_NUMBER(),
            --     ErrorSeverity       =   ERROR_SEVERITY(),
            --     ErrorState          =   ERROR_STATE(),
            --     ErrorProcedure      =   ERROR_PROCEDURE(),
            --     ErrorLine           =   ERROR_LINE(),
            --     ErrorMessage        =   ERROR_MESSAGE();

            UPDATE [shopify-colombia-clemont].dbo.ordenes
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