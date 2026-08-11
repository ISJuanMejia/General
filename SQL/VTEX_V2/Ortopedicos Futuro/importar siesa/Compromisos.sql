SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRY
    /* =============================================
       PARÁMETROS DE CONFIGURACIÓN GENERAL
       ============================================= */
    DECLARE @id_compania        NVARCHAR(4)     =   '4826',
            @id_sistema         NVARCHAR(1)     =   '2',
            @id_documento       NVARCHAR(6)     =   '250159',
            @nombre_documento   NVARCHAR(255)   =   'Compromiso_Pedido_VTEX',
            @validar_estructura NVARCHAR(5)     =   'true';
        
    DECLARE @endpoint   NVARCHAR(500)   =   'http://localhost:8092/v3.1/ConectoresImportar?idCompania='
                                            +   @id_compania 
                                            +   '&idSistema='
                                            +   @id_sistema
                                            +   '&idDocumento='
                                            +   @id_documento
                                            +   '&nombreDocumento='
                                            +   @nombre_documento                                            
                                            +   '&validarEstructura='
                                            +   @validar_estructura;

    DECLARE @num_max_intentos   INT =   3,
            @batch_size         INT =   25; 

    DECLARE @id_tipo_docto_pedido   NVARCHAR(10)    =   'PVW';

    /* =============================================
       DEDUPLICACIÓN DE PEDIDOS DEL ERP
       ============================================= */
    DECLARE @t430_cm_pv_docto TABLE (
        f430_num_docto_referencia   NVARCHAR(50) PRIMARY KEY,
        f430_consec_docto           NVARCHAR(20),
        f430_rowid                  NVARCHAR(50)
    );

    INSERT INTO @t430_cm_pv_docto (f430_num_docto_referencia, f430_consec_docto, f430_rowid)
    SELECT
        t430.f430_num_docto_referencia,
        MAX(t430.f430_consec_docto) AS f430_consec_docto,
        MAX(t430.f430_rowid) AS f430_rowid
    FROM [UnoEE_PruebasProyectosCol].[dbo].[t430_cm_pv_docto] t430 WITH (NOLOCK)
    WHERE
        NULLIF(TRIM(t430.f430_num_docto_referencia), '') IS NOT NULL
        AND f430_id_tipo_docto = @id_tipo_docto_pedido
    GROUP BY
        t430.f430_num_docto_referencia;

    /* =============================================
       ÓRDENES PROCESABLES (CON LÍMITE DE BATCH)
       ============================================= */
    DECLARE @ordenes_procesables TABLE (
        id_orden            NVARCHAR(50) PRIMARY KEY,
        referencia_orden    NVARCHAR(50)
    );

    INSERT INTO @ordenes_procesables (id_orden, referencia_orden)
    SELECT TOP (@batch_size)
        id_orden         = o.id_orden,
        referencia_orden = LEFT(
                                CONCAT(
                                    JSON_VALUE(o.orden_obj_origen, '$.orderId'),
                                    N' (', JSON_VALUE(o.orden_obj_origen, '$.sequence'), N')'
                                ),
                                50
                           ) + ' - 1'
    FROM dbo.ordenes o WITH (NOLOCK)
    WHERE
        o.id_estado = 7
        AND (o.intentos <= @num_max_intentos OR o.intentos IS NULL)
        AND ISNULL(o.endpoint, '') <> @endpoint
    ORDER BY o.id_orden DESC;

    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'No hay órdenes pendientes para procesar en este batch.';
        RETURN;
    END

    /* =============================================
       ACTUALIZACIÓN FINAL Y CONSTRUCCIÓN DE JSON
       ============================================= */
    UPDATE o
    SET
        o.endpoint          =   @endpoint,
        o.intentos          =   0,
        o.fecha_creacion    =   GETDATE(),
        o.orden_obj_destino = 
        (
            SELECT
                [Compromisos] = (
                    SELECT DISTINCT
                        f430_consec_docto     = t430.f430_consec_docto,
                        f431_referencia_item  = '',
                        /*
                        f431_referencia_item  = ISNULL(CAST(v.v121_id_item AS VARCHAR(50)), ''),
                        */
                        f431_codigo_barras    = ISNULL(TRIM(v.v121_id_barras_principal), ''),
                        f431_id_lote            =   '', -- TODO PENDIENTE
                        f431_id_unidad_medida = ISNULL(TRIM(m.f431_id_unidad_medida), 'UN'),
                        f431_cant_base        = CAST(CAST(m.f431_cant1_pedida AS INT) AS VARCHAR(20)),
                        f431_nro_registro     = CAST(m.f431_rowid AS VARCHAR(50))
                    FROM [UnoEE_PruebasProyectosCol].[dbo].[t431_cm_pv_movto] m WITH (NOLOCK)
                        LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[v121] v WITH (NOLOCK)
                            ON v.v121_rowid_item_ext = m.f431_rowid_item_ext
                    WHERE m.f431_rowid_pv_docto = t430.f430_rowid
                    FOR JSON PATH
                )
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    FROM dbo.ordenes o WITH (ROWLOCK)
        INNER JOIN @ordenes_procesables op
            ON o.id_orden = op.id_orden
        INNER JOIN @t430_cm_pv_docto t430
            ON t430.f430_num_docto_referencia = op.referencia_orden;

    PRINT CONCAT('Batch procesado: ', @@ROWCOUNT, ' órdenes de compromiso actualizadas.');

END TRY
BEGIN CATCH
    DECLARE @errorMsg     NVARCHAR(4000) = ERROR_MESSAGE(),
            @errorSev     INT            = ERROR_SEVERITY(),
            @errorState   INT            = ERROR_STATE(),
            @errorLine    INT            = ERROR_LINE(),
            @errorProc    NVARCHAR(200)  = ISNULL(ERROR_PROCEDURE(), N'Script inline'),
            @msgFinal     NVARCHAR(4000);

    SET @msgFinal = CONCAT(
        N'[COMPROMISO_PEDIDO_VTEX] Error línea ', CAST(@errorLine AS NVARCHAR), N' | ',
        N'Proc: ', @errorProc, N' | ',
        N'Msg: ', @errorMsg, N' | ',
        N'Time: ', CONVERT(NVARCHAR, GETDATE(), 121)
    );

    RAISERROR(@msgFinal, @errorSev, @errorState);
END CATCH;
