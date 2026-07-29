/*
====================================================================================================================
PARCHITA - DOC_CONTABLE_BONOS
====================================================================================================================
Nombre del Script  : Documento_contable.sql  
Descripción        : Este script genera documentos contables para las órdenes pagadas con bonos regalo ("gift_card").
                     También actualiza el estado de las órdenes sin transacciones exitosas con este medio de pago.
====================================================================================================================
*/

SET XACT_ABORT ON;

BEGIN TRY
	DECLARE 
		@idDocumento		INT				=	201455,
		@indicaParalelismo	BIT				=	0,
		@descripcion		VARCHAR(100)	=	'DOC_CONTABLE_BONOS';

--->================================================================================================================<---

	/*
		*	Configuración de ejecución del script
	*/
	DECLARE @batch_size		INT			=	25;                           -- Órdenes por petición (lote de 25)
    DECLARE @max_intentos	INT			=	3;                            -- Límite estricto de intentos (< no <=)
	DECLARE @fecha_inicio	DATETIME	=	DATEADD(DAY, -30, GETDATE()); -- Filtro de ordenes no más viejas a 30 días
    DECLARE @fecha_actual   VARCHAR(8)  =   FORMAT(GETDATE(), 'yyyyMMdd');

	DECLARE @client_origin_data	INT	=	4;

	DECLARE @path_customer	NVARCHAR(100)	=	'$.customer.default_address';
	DECLARE @path_billing	NVARCHAR(100)	=	'$.billing_address';
	DECLARE @path_shipping	NVARCHAR(100)	=	'$.shipping_address';

    DECLARE @id_cliente_ocasional   NVARCHAR(20)    =   '99999999';

--->================================================================================================================<---

    DECLARE @conexion   NVARCHAR(MAX);
    DECLARE @base_datos NVARCHAR(MAX);

    SELECT TOP 1
        @conexion   =   cadena_conexion,
        @base_datos =   base_datos
    FROM [shopify-colombia-parchita].dbo.conexiones;

    /*
    ================================================================================================================
    Paso 1 - Identificación de órdenes con transacciones exitosas de tipo gift_card
    ================================================================================================================
    */
    DECLARE @orders_with_successful_transaction TABLE   (
        id_orden    VARCHAR(900) PRIMARY KEY,
        orden_obj   VARCHAR(MAX),
        id_tercero  VARCHAR(100),
        amount      DECIMAL(18,2)
    );

    INSERT INTO @orders_with_successful_transaction (id_orden, orden_obj, id_tercero, amount)
    SELECT TOP (@batch_size)
        id_orden        =   orden.id_orden,
        orden_obj       =   orden.orden_obj,
        id_tercero      =   
            LEFT(
                REPLACE(
					REPLACE(
						CASE @client_origin_data
							WHEN 1 THEN NULLIF(TRIM(JSON_VALUE(orden_obj, @path_customer + '.company')), '')
							WHEN 2 THEN NULLIF(TRIM(JSON_VALUE(orden_obj, @path_billing  + '.company')), '')
							WHEN 3 THEN COALESCE(NULLIF(TRIM(JSON_VALUE(orden_obj, @path_customer + '.company')), ''), NULLIF(TRIM(JSON_VALUE(orden_obj, @path_billing  + '.company')), ''))
							WHEN 4 THEN COALESCE(NULLIF(TRIM(JSON_VALUE(orden_obj, @path_billing  + '.company')), ''), NULLIF(TRIM(JSON_VALUE(orden_obj, @path_customer + '.company')), ''))
						END,
						'.',
						''
					),
					'-',
					''
			    ),
                15
            ),
        amount          =   
            (
                SELECT SUM(CAST(JSON_VALUE(t.transaccion_obj, '$.amount') AS DECIMAL(18,2)))
                FROM transacciones_ordenes t
                WHERE t.id_orden = JSON_VALUE(orden.orden_obj, '$.id')
                  AND JSON_VALUE(t.transaccion_obj, '$.status') = 'success'
                  AND JSON_VALUE(t.transaccion_obj, '$.gateway') = 'gift_card'
            )
    FROM ordenes AS orden
    WHERE
        id_estado       =   5
        AND
        intentos        <=  @max_intentos
        AND
        fecha_creacion  >=  @fecha_inicio
    ORDER BY orden.id DESC;

    /*
    ================================================================================================================
    Paso 2 - Actualización de estado de órdenes sin transacciones gift_card exitosas o que superan intentos
    ================================================================================================================
    */
    UPDATE o
    SET o.id_estado = 6
    FROM ordenes o
    INNER JOIN @orders_with_successful_transaction owst
        ON o.id_orden = owst.id_orden
    WHERE owst.amount IS NULL;

    /*
    ================================================================================================================
    Paso 3 - Construcción del JSON de integración contable
    ================================================================================================================
    */
    SELECT
        idDocumento         =   @idDocumento,
        indicaParalelismo   =   @indicaParalelismo,
        descripcion         =   @descripcion,
        idOrden             =   id_orden,
        JSON    =   (
            SELECT
                [Documentocontable] = (
                    SELECT
                        F350_FECHA          =   @fecha_actual,
                        F350_ID_TERCERO     =   
                            CASE
                                WHEN dbo.fn_KeepNumbersHyphen(id_tercero) = '' THEN @id_cliente_ocasional
                                ELSE dbo.fn_KeepNumbersHyphen(id_tercero)
                            END,
                        F350_NOTAS          =   id_orden
                    FOR JSON PATH
                ),
                [Movimientocontable] = (
                    SELECT
                        F351_VALOR_DB       =   amount,
                        F351_VALOR_CR      =   '0',
                        F351_NOTAS         =   id_orden
                    FOR JSON PATH
                ),
                [Caja] = (
                    SELECT 
                        F351_VALOR_DB       =   '0',
                        F351_VALOR_CR      =   amount,
                        F351_NOTAS         =   id_orden,
                        F358_NOTAS         =   id_orden
                    FOR JSON PATH
                )
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    FROM @orders_with_successful_transaction
    WHERE amount IS NOT NULL
    GROUP BY	
        id_orden,
        orden_obj,
        id_tercero,
        amount;
END TRY
BEGIN CATCH
    SELECT
		indicaError			=	CAST(1 AS BIT),
        descripcionError	=	ERROR_MESSAGE();
END CATCH;