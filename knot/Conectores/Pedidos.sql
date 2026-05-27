BEGIN TRY
    SET XACT_ABORT ON;

    /*
    *   DEFINICIÓN DE LA INFORMACIÓN DEL CONECTOR
    *       @idDocumento        ->  Id del conector en Connekta
    *       @indicaParalelismo  ->  Si es igual a 1 se ejecuta paralelamente múltiples peticiones a Connekta, si es 
    *                               igual a 2 se hace de manera secuencial, para pedidos se recomienda dejarlo en 0 
    *                               para evitar duplicidad de pedidos
    *       @descripcion        ->  Nombre del conector en Connekta
    */
    DECLARE @idDocumento        INT             =   228557,
            @indicaParalelismo  BIT             =   0,
            @descripcion        VARCHAR(100)    =   'PEDIDOS_INTEGRACION';

    /*
    *   PARAMETROS GENERALES DEL QUERY
    */
    DECLARE @fecha_actual       NVARCHAR(8)     =   FORMAT(GETDATE(), 'yyyyMMdd');
    DECLARE @fecha_entrega      NVARCHAR(8)     =   FORMAT(DATEADD(DAY, 1, GETDATE()), 'yyyyMMdd');
    DECLARE @id_tercero_defecto VARCHAR(255)    =   '22222222';

    /*
    *   PARAMETROS MOVTO PEDIDOS COMERCIAL
    */
    DECLARE @unidad_medida_item     NVARCHAR(4)     =   'PAR';
    DECLARE @unidad_medida_flete    NVARCHAR(4)     =   'UND';
    DECLARE @referencia_flete       NVARCHAR(50)    =   'FLETES NACIONAL WEB';
    
    /*
    *   DEFINICIÓN DE LAS TABLAS DE LAS SECCIONES DEL CONECTOR
    *       PEDIDOS
    *       MOVTO_PEDIDOS_COMERCIAL
    *       DESCUENTOS
    */
    DECLARE @pedidos    TABLE
    (
        f430_id_fecha               NVARCHAR(8),
        f430_id_tercero_fact        VARCHAR(255),
        f430_id_tercero_rem         VARCHAR(255),
        f430_fecha_entrega          VARCHAR(8),
        f430_num_docto_referencia   VARCHAR(15),
        f430_referencia             VARCHAR(10)
    );

    DECLARE @movto_pedidos_comercial    TABLE
    (
        id_movimiento			VARCHAR(50),
        f431_nro_registro       INT,
        f431_referencia_item    NVARCHAR(50),
        f431_codigo_barras      NVARCHAR(20),
        f431_fecha_entrega      NVARCHAR(8),
        f431_id_unidad_medida   NVARCHAR(4),
        f431_cant_pedida_base   DECIMAL,
        f431_precio_unitario    DECIMAL,
        f431_notas              NVARCHAR(255)
    );

    DECLARE @descuentos TABLE
    (
        f431_nro_registro   INT,
        f432_vlr_uni        DECIMAL
    );

    /*
    *   FLETE
    */
    DECLARE @shipping_lines TABLE
    (
        amount  DECIMAL
    );

    /*
    *   DESCUENTOS DE SHOPIFY
    */
    DECLARE @discount_applications  TABLE
    (
        discount_applications   NVARCHAR(255),
        [value]                 NVARCHAR(255),
        [name]                  NVARCHAR(255),
        target_type             NVARCHAR(255),
        value_type              NVARCHAR(255)
    );

    DECLARE	@line_item_discounts	TABLE
    (
		f431_nro_registro	VARCHAR(50),
        f432_vlr_uni		FLOAT,
        item_discount_price FLOAT
	);

    /*
    *   TABLA QUE RETORNA LOS RESULTADOS DEL QUERY
    */
    DECLARE @final TABLE (
        idDocumento         INT,
        indicaParalelismo   BIT,
        descripcion         VARCHAR(100),
        idOrden             VARCHAR(50),
        json                VARCHAR(MAX)
    );

    /*
    *   VARIABLES GENERALES DEL QUERY
    */
    DECLARE @json           VARCHAR(MAX)    =   '',
            @order          VARCHAR(30),
            @counter        INT             =   1,
            @total          INT,
            @metodo_pago    NVARCHAR(MAX);

    /*
    *   OBTENER LA CADENA DE CONEXIÓN A LA BASE DE DATOS DEL ERP
    */
    DECLARE @conexion   NVARCHAR(MAX),
            @base_datos NVARCHAR(MAX);
   
    SELECT TOP 1
        @conexion   =   cadena_conexion,
        @base_datos =   base_datos
    FROM Conexiones;

    /*
    *   CONSULTAR LA TABLA DE PEDIDOS PARA VALIDAR QUE PEDIDOS YA EXISTEN
    */
    DECLARE @t430_cm_pv_docto   TABLE
    (
        f430_referencia             NVARCHAR(255),
        f430_num_docto_referencia   NVARCHAR(255)
    );

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
                    f430_referencia,
                    f430_num_docto_referencia
                FROM ' + @base_datos + '.dbo.t430_cm_pv_docto
            ''
        )
    ');

    DECLARE @ordenes    TABLE
    (
        id_orden    NVARCHAR(255),
        orden_obj   NVARCHAR(MAX)
    );

    INSERT INTO @ordenes
    SELECT TOP 25
        id_orden,
        orden_obj
    FROM ordenes
        LEFT JOIN @t430_cm_pv_docto  oc
            ON
                oc.f430_referencia  =   REPLACE(id_orden, '"', '')
                OR
                oc.f430_num_docto_referencia    =   REPLACE(id_orden, '"', '')
    WHERE
        id_estado   =   2
        AND
        intentos    <=  3
        AND
        (
            f430_num_docto_referencia   IS NULL
            AND
            f430_referencia IS NULL
        )
    ORDER BY id_orden;
 
    SET @total = (SELECT COUNT(*) FROM @ordenes);
 
    WHILE @counter <= @total
    BEGIN
        SET @json = (
            SELECT orden_obj
            FROM (
                SELECT orden_obj, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                FROM @ordenes
            ) AS temp
            WHERE rn = @counter
        );
 
        SET @order = JSON_VALUE(@json, '$.name');
 
        -- Pago
        SELECT TOP 1
            @metodo_pago = [value]
        FROM OPENJSON(@json, '$.payment_gateway_names') AS payment
        WHERE
            [value] != 'gift_card'
        ORDER BY [key] DESC;

        DECLARE @id_tercero NVARCHAR(255)    =
            ISNULL(
                NULLIF(
                    TRIM(
                        ISNULL(
                            JSON_VALUE(@json, '$.billing_address.company'),
                            JSON_VALUE(@json, '$.customer.default_address.company')
                        )
                    ),
                    ''
                ),
                @id_tercero_defecto
            );
 
        -- Encabezado solo con campos requeridos
        INSERT INTO @pedidos
        (
            f430_id_fecha,
            f430_id_tercero_fact,
            f430_id_tercero_rem,
            f430_fecha_entrega,
            f430_num_docto_referencia,
            f430_referencia
        )
        SELECT
            f430_id_fecha               =   @fecha_actual,
            f430_id_tercero_fact        =   @id_tercero,
            f430_id_tercero_rem         =   @id_tercero,
            f430_fecha_entrega          =   @fecha_entrega,
            f430_num_docto_referencia   =   @order,
            f430_referencia             =   @order
 
        -- Movimientos solo con campos requeridos
        INSERT INTO @movto_pedidos_comercial
        (
            id_movimiento,
            f431_nro_registro,
            f431_referencia_item,
            f431_codigo_barras,
            f431_fecha_entrega,
            f431_id_unidad_medida,
            f431_cant_pedida_base,
            f431_precio_unitario,
            f431_notas
        )
        SELECT
            id_movimiento           =	JSON_VALUE(LineItems.value, '$.id'),
            f431_nro_registro       =   ROW_NUMBER() OVER (ORDER BY (JSON_VALUE(LineItems.value, '$.id'))),
            f431_referencia_item    =   CAST('' AS VARCHAR(50)),
            f431_codigo_barras      =   JSON_VALUE(LineItems.value, '$.sku'),
            f431_fecha_entrega      =   @fecha_entrega,
            f431_id_unidad_medida   =   @unidad_medida_item,
            f431_cant_pedida_base   =   JSON_VALUE(LineItems.value, '$.quantity'),
            f431_precio_unitario    =   JSON_VALUE(LineItems.value, '$.price'),
            f431_notas              =   @metodo_pago
        FROM OPENJSON(@json, '$.line_items') AS LineItems
        ORDER BY JSON_VALUE(LineItems.value, '$.id');
 
        /*
        *   Envío: solo si hay shipping con precio > 0 y no removido, y si no hay descuentos de shipping_lines
        */
        INSERT INTO @shipping_lines
        SELECT
            amount  =   JSON_VALUE(ShippingLines.value, '$.discount_allocations[0].amount')
        FROM OPENJSON(@json, '$.shipping_lines') AS ShippingLines;
 
        IF NOT EXISTS (SELECT amount FROM @shipping_lines WHERE amount IS NOT NULL)
        BEGIN
            INSERT INTO @movto_pedidos_comercial (
                id_movimiento,
                f431_nro_registro,
                f431_referencia_item,
                f431_codigo_barras,
                f431_fecha_entrega,
                f431_id_unidad_medida,
                f431_cant_pedida_base,
                f431_precio_unitario,
                f431_notas
            )
            SELECT
                id_movimiento           =   '0',
                f431_nro_registro       =   0,
                f431_referencia_item    =   @referencia_flete,
                f431_codigo_barras      =   '',
                f431_fecha_entrega      =   @fecha_entrega,
                f431_id_unidad_medida   =   @unidad_medida_flete,
                f431_cant_pedida_base   =   '1',
                f431_precio_unitario    =   JSON_VALUE(sl.value, '$.price'),
                f431_notas              =   @referencia_flete
            FROM OPENJSON(@json, '$.shipping_lines')    AS sl
            WHERE 
                JSON_VALUE(sl.value, '$.price') NOT IN ('0.00', '0')
                AND 
                JSON_VALUE(sl.value, '$.is_removed') = 'false';
        END
 
        -- Descuentos (solo target_type = line_item)
        IF EXISTS (SELECT value FROM OPENJSON(@json, '$.discount_applications'))
        BEGIN
            INSERT INTO @discount_applications
            SELECT
                discount_applications,
                [value],
                [name],
                [target_type],
                [value_type]
            FROM OPENJSON(@json) WITH (
                discount_applications NVARCHAR(MAX) '$.discount_applications[0].type',
                [value] NVARCHAR(20)                '$.discount_applications[0].value',
                [name] VARCHAR(50)                  '$.name',
                [target_type] VARCHAR(50)           '$.discount_applications[0].target_type',
                [value_type] VARCHAR(50)            '$.discount_applications[0].value_type'
            ) AS c1;
 
            IF EXISTS
            (
                SELECT TOP 1 
                    target_type 
                FROM @discount_applications 
                WHERE
                    target_type = 'line_item'
            )
            BEGIN
				INSERT INTO @line_item_discounts
				SELECT
					f431_nro_registro		=	m.f431_nro_registro,
                    f432_vlr_uni			=
                        CONVERT(
                            MONEY,
                            JSON_VALUE(Discount.value, '$.amount')
                        ) / CONVERT(
                            MONEY,
                            JSON_VALUE(LineItems.value, '$.quantity')
                        ),
                    item_discount_price	=	
                        (
                            CONVERT(
                                MONEY,
                                JSON_VALUE(LineItems.value, '$.price')
                            ) * CONVERT(
                                MONEY,
                                JSON_VALUE(LineItems.value, '$.quantity')
                            )
                        ) - CONVERT(
                            MONEY,
                            JSON_VALUE(Discount.value, '$.amount')
                        )
				FROM @movto_pedidos_comercial AS m
				    LEFT JOIN OPENJSON(@json, '$.line_items') AS LineItems 
                        ON
                            JSON_VALUE(LineItems.value, '$.id') = m.id_movimiento
				    CROSS APPLY OPENJSON(LineItems.value, '$.discount_allocations') AS Discount;
				
				INSERT INTO @descuentos
				SELECT
					f431_nro_registro,
					f432_vlr_uni
				FROM @line_item_discounts
				WHERE 
					item_discount_price > 0	
					AND
					f432_vlr_uni > 0;
            END
        END
 
        -- Insertar en @final con SOLO los campos permitidos y nombres requeridos
        INSERT INTO @final (idDocumento, indicaParalelismo, descripcion, idOrden, json)
        SELECT
            @idDocumento,
            @indicaParalelismo,
            @descripcion,
            @order AS idOrden,
            (
                SELECT
                    [Pedidos] = (
                        SELECT *
                        FROM @pedidos
                        FOR JSON PATH
                    ),
                    [Movto_Pedidos_comercial] = (
                        SELECT *
                        FROM @movto_pedidos_comercial
                        FOR JSON PATH
                    ),
                    [Descuentos] = (
                        SELECT *
                        FROM @descuentos
                        FOR JSON PATH
                    )
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

        DELETE FROM @pedidos
        DELETE FROM @movto_pedidos_comercial
        DELETE FROM @descuentos
        DELETE FROM @shipping_lines
        DELETE FROM @line_item_discounts;
        DELETE FROM @discount_applications;
 
        SET @counter = @counter + 1;
    END
END TRY
BEGIN CATCH
    SELECT 
        idDocumento         =   0,
        indicaParalelismo   =   0, 
        descripcion         =   ERROR_MESSAGE(),
        idOrden             =   0;
END CATCH
 
SELECT * FROM @final AS final_json;