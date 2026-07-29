/*  PARCHITA    -   FACT_VENTA_DESE_PEDIDO_V1
    -----------------------------------------------------------------------------------------
    Nombre del Script: FACT_VENTA_DESE_PEDIDO_V1.sql
    Descripción:
        Este script realiza la construcción de un JSON con información de ventas y transacciones
        asociadas a pedidos para la generación de facturas desde pedidos en el ERP.
    -----------------------------------------------------------------------------------------
*/

DECLARE 
	@idDocumento		INT				=	201458,
	@indicaParalelismo	BIT				=	0,
	@descripcion		VARCHAR(100)	=	'FACT_VENTA_DESE_PEDIDO_V1';

--->================================================================================================================<---

/*
	*	Configuración de ejecución del script
*/
DECLARE @batch_size		INT	        =	25;                           -- Órdenes por petición (lote de 25)
DECLARE @max_intentos	INT	        =	3;                            -- Límite estricto de intentos (< no <=)
DECLARE @fecha_inicio	DATETIME	=	DATEADD(DAY, -30, GETDATE()); -- Filtro de ordenes no más viejas a 30 días
DECLARE @fecha_actual   NVARCHAR(8) =   FORMAT(GETDATE(), 'yyyyMMdd');

DECLARE @id_cond_pago_item      NVARCHAR(3) =   '30D',
        @id_cond_pago_giftcard  NVARCHAR(3) =   'EFE';

--->================================================================================================================<---
/*
    *	Definición de la tabla de pedidos del ERP
*/
DECLARE @t430_cm_pv_docto TABLE (
    f430_consec_docto   INT,
    f430_ind_facturado  BIT,
    f430_ind_estado     INT,
    f430_referencia     VARCHAR(50)
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
FROM [shopify-colombia-parchita].dbo.conexiones;

/*  Paso 1: Obtener pedidos del ERP */
INSERT INTO @t430_cm_pv_docto (f430_consec_docto, f430_ind_facturado, f430_ind_estado, f430_referencia)
EXEC
(
    '
    SELECT DISTINCT 
        f430_consec_docto,
        f430_ind_facturado,
        f430_ind_estado,
        f430_referencia
    FROM OPENROWSET(
        ''SQLNCLI'',
        ''' + @conexion + ''',
        ''
            SELECT 
                f430_consec_docto,
                f430_ind_facturado,
                f430_ind_estado,
                f430_referencia
            FROM ' + @base_datos + '.dbo.t430_cm_pv_docto
            WHERE f430_id_cia = 1
              AND f430_referencia IS NOT NULL
              AND TRIM(f430_referencia) != ''''''''
        ''
    )
    '
);

--->================================================================================================================<---
/*
    *   Actualizar a estado 5 pedidos ya facturados en ERP
*/
UPDATE ord
    SET id_estado	=	5
FROM [shopify-colombia-parchita].dbo.ordenes AS ord
    INNER JOIN @t430_cm_pv_docto
        ON f430_referencia     =   id_orden
       AND f430_ind_estado     =   4
       AND f430_ind_facturado  =   1
WHERE id_estado = 4;

DECLARE @ordenes TABLE 
(
	id_orden            NVARCHAR(20),
	orden_obj           NVARCHAR(MAX),
    f430_consec_docto   INT,
    f430_referencia     VARCHAR(50)
);

/*
    *   Obtener hasta 25 órdenes en estado 4 no mayores a 30 días,
    *   excluyendo POS y ordenadas por ID DESC.
*/
INSERT INTO @ordenes (id_orden, orden_obj, f430_consec_docto, f430_referencia)
SELECT TOP (@batch_size)
    id_orden,
    orden_obj,
    f430_consec_docto,
    f430_referencia
FROM [shopify-colombia-parchita].dbo.ordenes
    INNER JOIN @t430_cm_pv_docto
        ON f430_referencia     =   id_orden
       AND f430_ind_estado     =   3
       AND f430_ind_facturado  =   0
WHERE
    id_estado   =   4
    AND
    intentos    <=  @max_intentos
    AND
    fecha_creacion >= @fecha_inicio
GROUP BY 
    id_orden,
    orden_obj,
    f430_consec_docto,
    f430_referencia
ORDER BY MAX(ordenes.id) DESC;

DECLARE @transacciones_ordenes  TABLE (
    id_transaction  VARCHAR(20),
    id_orden        VARCHAR(20),
    gateway         VARCHAR(50),
    amount          VARCHAR(50)
);

/*  Paso 2: Agregar información de medios de pago   */
INSERT INTO @transacciones_ordenes
SELECT DISTINCT
    id_transaction  =   tor.id_transaction,
    id_orden        =   orden.id_orden,
    gateway         =   tor.gateway,
    amount          =   tor.amount
FROM @ordenes AS orden
    CROSS APPLY (
        SELECT DISTINCT
            id_transaction  =   JSON_VALUE(t.transaccion_obj, '$.id'),
            gateway         =   JSON_VALUE(t.transaccion_obj, '$.gateway'),
            amount          =   JSON_VALUE(t.transaccion_obj, '$.amount'),
            [status]        =   JSON_VALUE(t.transaccion_obj, '$.status')
        FROM transacciones_ordenes  AS  t
        WHERE t.id_orden = JSON_VALUE(orden.orden_obj, '$.id')
          AND JSON_VALUE(t.transaccion_obj, '$.status') = 'success'
    ) AS tor;
    
/*  Paso 3: Construir JSON con lógica condicional   */
SELECT
    idDocumento         =   @idDocumento,
    indicaParalelismo   =   @indicaParalelismo,
    descripcion         =   @descripcion,
    idOrden             =   p.f430_referencia,
    JSON                =   (
        SELECT
            [Docto_ventas_comercial] = (
                SELECT
                    F350_FECHA                  =   @fecha_actual,
                    F430_CONSEC_DOCTO_PEDIDO    =   p.f430_consec_docto,
                    f462_notas                  =   LTRIM(RTRIM(p.f430_referencia)),
                    f460_id_cond_pago           =
                        CASE 
                            WHEN EXISTS (
                                SELECT 1 
                                FROM @transacciones_ordenes AS ord 
                                WHERE LTRIM(RTRIM(ord.id_orden)) = LTRIM(RTRIM(p.f430_referencia)) 
                                  AND ord.gateway = 'gift_card'
                            ) 
                            AND NOT EXISTS (
                                SELECT 1 
                                FROM @transacciones_ordenes AS ord 
                                WHERE LTRIM(RTRIM(ord.id_orden)) = LTRIM(RTRIM(p.f430_referencia))
                                  AND ord.gateway != 'gift_card'
                            ) 
                                THEN @id_cond_pago_giftcard 
                            ELSE @id_cond_pago_item 
                        END,
                    f461_notas                  =   LTRIM(RTRIM(p.f430_referencia))
                FOR JSON PATH
            ),
            [Cuotas_CxC] = (
                SELECT 
					F353_VLR_CRUCE      =
                        CASE 
                            WHEN EXISTS (
                                SELECT 1 FROM @transacciones_ordenes AS ord 
                                WHERE LTRIM(RTRIM(ord.id_orden)) = LTRIM(RTRIM(p.f430_referencia)) AND ord.gateway = 'gift_card'
                            ) AND EXISTS (
                                SELECT 1 FROM @transacciones_ordenes AS ord 
                                WHERE LTRIM(RTRIM(ord.id_orden)) = LTRIM(RTRIM(p.f430_referencia)) AND ord.gateway != 'gift_card'
                            ) 
                                THEN ord.amount
                            ELSE '0' 
                        END,
                    F_PORCENTAJE_CUOTA  =
                        CASE 
                            WHEN EXISTS (
                                SELECT 1 FROM @transacciones_ordenes AS ord 
                                WHERE LTRIM(RTRIM(ord.id_orden)) = LTRIM(RTRIM(p.f430_referencia)) AND ord.gateway = 'gift_card'
                            ) AND EXISTS (
                                SELECT 1 FROM @transacciones_ordenes AS ord 
                                WHERE LTRIM(RTRIM(ord.id_orden)) = LTRIM(RTRIM(p.f430_referencia)) AND ord.gateway != 'gift_card'
                            ) 
                                THEN '000.00' 
                            ELSE '100.00' 
                        END,
                    F353_FECHA_VCTO     =   @fecha_actual,
                    F353_FECHA_DSCTO_PP =   @fecha_actual
                FROM @transacciones_ordenes AS ord
                WHERE LTRIM(RTRIM(ord.id_orden)) = LTRIM(RTRIM(p.f430_referencia))
                  AND ord.gateway != 'gift_card'
                FOR JSON PATH
            ),
            [Caja] = (
                SELECT 
                    F_VLR_MEDIO_PAGO    =   ord.amount,
                    F358_NOTAS          =   LTRIM(RTRIM(p.f430_referencia))
                FROM @transacciones_ordenes AS ord
                WHERE LTRIM(RTRIM(ord.id_orden)) = LTRIM(RTRIM(p.f430_referencia))
                  AND ord.gateway = 'gift_card'
                FOR JSON PATH
            )
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )
FROM @ordenes AS p
    INNER JOIN @transacciones_ordenes AS ord
        ON LTRIM(RTRIM(ord.id_orden)) = LTRIM(RTRIM(p.f430_referencia))
GROUP BY 
    p.f430_referencia, 
    p.f430_consec_docto;