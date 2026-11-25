/* ============================================================================
 * SCRIPT  : Validar_Y_Devolver_Terceros.sql
 * CLIENTE : Ortopédicos Futuro
 * PROCESO : Integración VTEX - Siesa
 * OBJETIVO: Validar la existencia del tercero en Siesa (t200_mm_terceros)
 *           en cualquiera de los pasos activos del flujo (estados 3 a 7).
 *           Si el tercero no existe en Siesa, la orden se devuelve al
 *           Paso 1 (id_estado = 1) para que el conector de terceros
 *           (tercero por integrar v2.sql) proceda con su creación.
 * ============================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRY
    DECLARE @dias_atras INT = 15;

    -- Tabla para almacenar las órdenes a revertir
    DECLARE @ordenes_a_devolver TABLE (
        id_orden            NVARCHAR(50),
        id_estado_anterior  INT,
        documento_tercero   NVARCHAR(100),
        fecha_registro      DATETIME
    );

    INSERT INTO @ordenes_a_devolver (
        id_orden,
        id_estado_anterior,
        documento_tercero,
        fecha_registro
    )
    SELECT 
        o.id_orden,
        o.id_estado,
        REPLACE(REPLACE(
            CASE 
                WHEN UPPER(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.isCorporate')) IN ('TRUE', '1') 
                THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document')
            END, '.', ''), ' ', '') AS documento,
        o.fecha_creacion
    FROM dbo.ordenes o WITH (NOLOCK)
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t200_mm_terceros] t200 WITH (NOLOCK)
        ON t200.f200_id = REPLACE(REPLACE(
            CASE 
                WHEN UPPER(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.isCorporate')) IN ('TRUE', '1') 
                THEN JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.corporateDocument')
                ELSE JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document')
            END, '.', ''), ' ', '')
    WHERE o.id_estado IN (3, 4, 5, 6, 7)
      AND t200.f200_id IS NULL
      AND COALESCE(
            TRY_CAST(JSON_VALUE(o.orden_obj_origen, '$.lastChange') AS DATETIMEOFFSET),
            TRY_CAST(o.fecha_creacion AS DATETIMEOFFSET)
          ) >= DATEADD(DAY, -@dias_atras, SYSDATETIMEOFFSET());

    DECLARE @total_a_devolver INT = (SELECT COUNT(*) FROM @ordenes_a_devolver);

    IF @total_a_devolver = 0
    BEGIN
        PRINT 'Validación completa: Todos los terceros de las órdenes activas (estados 3-7) existen en Siesa ERP.';
        RETURN;
    END

    -- Devolver al Paso 1 (id_estado = 1) con reseteo de endpoint, destino e intentos
    UPDATE o
    SET 
        o.id_estado         = 1,
        o.endpoint          = NULL,
        o.orden_obj_destino = NULL,
        o.intentos          = 0,
        o.fecha_creacion    = GETDATE()
    FROM dbo.ordenes o
    INNER JOIN @ordenes_a_devolver dev
        ON o.id_orden = dev.id_orden;

    SELECT 
        id_orden            AS [Orden Devuelta a Paso 1],
        id_estado_anterior  AS [Estado Previo],
        documento_tercero   AS [Documento Tercero Faltante],
        'Devuelta a id_estado = 1 para creación de tercero' AS [Accion]
    FROM @ordenes_a_devolver;

    PRINT CONCAT('Se devolvieron ', @total_a_devolver, ' orden(es) al Paso 1 (id_estado = 1).');

END TRY
BEGIN CATCH
    DECLARE @errorMsg     NVARCHAR(4000) = ERROR_MESSAGE(),
            @errorSev     INT            = ERROR_SEVERITY(),
            @errorState   INT            = ERROR_STATE(),
            @errorLine    INT            = ERROR_LINE(),
            @errorProc    NVARCHAR(200)  = ISNULL(ERROR_PROCEDURE(), N'Script inline'),
            @msgFinal     NVARCHAR(4000);

    SET @msgFinal = CONCAT(
        N'[Validar_Y_Devolver_Terceros] Error línea ', CAST(@errorLine AS NVARCHAR), N' | ',
        N'Proc: ', @errorProc, N' | ',
        N'Msg: ', @errorMsg, N' | ',
        N'Time: ', CONVERT(NVARCHAR, GETDATE(), 121)
    );

    RAISERROR(@msgFinal, @errorSev, @errorState);
END CATCH;
