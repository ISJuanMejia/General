/*
CAMBIO DE ESTADO INVOICED - VTEX / MERCEDES CAMPUZANO

SWITCH:
    @genera_guia = 1 -> espera guía registrada en guias_transportadoras y la informa a VTEX.
    @genera_guia = 0 -> no exige guía y envía Invoiced sin tracking.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* 1. CONFIGURACION */
DECLARE @genera_guia BIT = 1;
DECLARE @id_estado_lectura INT = 6; -- Estado Invoiced Por Integrar
DECLARE @id_estado_final INT = 7;    -- Proceso Finalizado

DECLARE @cadena_conexion NVARCHAR(255) =
    'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Rehemma_Real;UID=Rehemma;PWD=Rehemma$12$%';

/* 2. DATOS REMOTOS DE SIESA */
DECLARE @t430_cm_pv_docto TABLE
(
    f430_rowid INT,
    f430_num_docto_referencia NVARCHAR(100)
);

INSERT INTO @t430_cm_pv_docto
EXEC
(
    'SELECT
        f430_rowid,
        f430_num_docto_referencia
     FROM OPENROWSET
     (
        ''SQLNCLI'',
        ''' + @cadena_conexion + ''',
        ''SELECT
              f430_rowid,
              f430_num_docto_referencia
          FROM dbo.t430_cm_pv_docto
          WHERE NULLIF(TRIM(f430_num_docto_referencia), '''''''') IS NOT NULL''
     )'
);

DECLARE @t460_cm_docto_remision_venta TABLE
(
    f460_rowid_pv_docto INT,
    f460_rowid_docto_factura INT
);

INSERT INTO @t460_cm_docto_remision_venta
EXEC
(
    'SELECT
        f460_rowid_pv_docto,
        f460_rowid_docto_factura
     FROM OPENROWSET
     (
        ''SQLNCLI'',
        ''' + @cadena_conexion + ''',
        ''SELECT
              f460_rowid_pv_docto,
              f460_rowid_docto_factura
          FROM dbo.t460_cm_docto_remision_venta
          WHERE f460_rowid_pv_docto IS NOT NULL
            AND f460_rowid_docto_factura IS NOT NULL''
     )'
);

DECLARE @t461_cm_docto_factura_venta TABLE
(
    f461_rowid_docto INT
);

INSERT INTO @t461_cm_docto_factura_venta
EXEC
(
    'SELECT
        f461_rowid_docto
     FROM OPENROWSET
     (
        ''SQLNCLI'',
        ''' + @cadena_conexion + ''',
        ''SELECT f461_rowid_docto
          FROM dbo.t461_cm_docto_factura_venta''
     )'
);

DECLARE @t350_co_docto_contable TABLE
(
    f350_rowid INT,
    f350_id_co NVARCHAR(3),
    f350_id_tipo_docto NVARCHAR(3),
    f350_consec_docto INT,
    f350_fecha DATETIME
);

INSERT INTO @t350_co_docto_contable
EXEC
(
    'SELECT
        f350_rowid,
        f350_id_co,
        f350_id_tipo_docto,
        f350_consec_docto,
        f350_fecha
     FROM OPENROWSET
     (
        ''SQLNCLI'',
        ''' + @cadena_conexion + ''',
        ''SELECT
              f350_rowid,
              f350_id_co,
              f350_id_tipo_docto,
              f350_consec_docto,
              f350_fecha
          FROM dbo.t350_co_docto_contable''
     )'
);

/* 3. RECUPERACION DE ORDENES ESTANCADAS */
UPDATE O
SET
    O.intentos = 0,
    O.id_estado = @id_estado_lectura
FROM ordenes AS O
INNER JOIN @t430_cm_pv_docto AS t430
    ON t430.f430_num_docto_referencia =
       CASE
           WHEN LEN(REPLACE(JSON_VALUE(O.orden_obj_origen, '$.orderId'), '-', '')) <= 15
           THEN REPLACE(JSON_VALUE(O.orden_obj_origen, '$.orderId'), '-', '')
           ELSE JSON_VALUE(O.orden_obj_origen, '$.sequence')
       END
INNER JOIN @t460_cm_docto_remision_venta AS t460
    ON t430.f430_rowid = t460.f460_rowid_pv_docto
INNER JOIN @t461_cm_docto_factura_venta AS t461
    ON t461.f461_rowid_docto = t460.f460_rowid_docto_factura
INNER JOIN @t350_co_docto_contable AS t350
    ON t350.f350_rowid = t461.f461_rowid_docto
OUTER APPLY
(
    SELECT TOP (1)
        LTRIM(RTRIM(gt.remision)) AS trackingNumber,
        gt.url AS trackingUrl
    FROM guias_transportadoras AS gt
    WHERE gt.id_orden = O.id
      AND gt.id_transportadora = 1
      AND NULLIF(LTRIM(RTRIM(gt.remision)), '') IS NOT NULL
    ORDER BY gt.fecha_creacion DESC, gt.id DESC
) AS guia
WHERE O.fecha_creacion > DATEADD(DAY, -7, GETDATE())
  AND O.id_estado = @id_estado_lectura
  AND O.intentos >= 3
  AND (
        @genera_guia = 0
        OR guia.trackingNumber IS NOT NULL
      );

/* 4. CONSTRUCCION DEL JSON DE INVOICED */
UPDATE O
SET
    O.orden_obj_destino =
    (
        SELECT
            [type] = 'Output',
            [invoiceNumber] = CONCAT(
                t350.f350_id_co,
                '-',
                t350.f350_id_tipo_docto,
                '-',
                RTRIM(LTRIM(CONVERT(CHAR, t350.f350_consec_docto)))
            ),
            [invoiceValue] = JSON_VALUE(O.orden_obj_origen, '$.value'),
            [issuanceDate] = CONVERT(VARCHAR, t350.f350_fecha, 23),
            [trackingNumber] = CASE
                WHEN @genera_guia = 1
                THEN ISNULL(guia.trackingNumber, '')
                ELSE ''
            END,
            [trackingUrl] = CASE
                WHEN @genera_guia = 1
                THEN ISNULL(
                    guia.trackingUrl,
                    CASE
                        WHEN guia.trackingNumber IS NOT NULL
                        THEN CONCAT(
                            'https://www.coordinadora.com/portafolio-de-servicios/servicios-en-linea/rastreo-de-guias/?guia=',
                            guia.trackingNumber
                        )
                        ELSE ''
                    END
                )
                ELSE ''
            END,
            [courier] = CASE
                WHEN @genera_guia = 1
                     AND guia.trackingNumber IS NOT NULL
                THEN 'Coordinadora'
                ELSE ''
            END,
            [items] =
            (
                SELECT
                    [id] = JSON_VALUE(item.value, '$.id'),
                    [price] = CASE
                        WHEN ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) = 1
                        THEN CAST(
                            CAST(JSON_VALUE(item.value, '$.sellingPrice') AS INT) +
                            CAST(JSON_VALUE(O.orden_obj_origen, '$.totals[2].value') AS INT)
                            AS NVARCHAR
                        )
                        ELSE CAST(
                            CAST(JSON_VALUE(item.value, '$.sellingPrice') AS INT)
                            AS NVARCHAR
                        )
                    END,
                    [quantity] = JSON_VALUE(item.value, '$.quantity')
                FROM OPENJSON(O.orden_obj_origen, '$.items') AS item
                FOR JSON PATH
            )
        FOR JSON PATH,
        WITHOUT_ARRAY_WRAPPER
    )
FROM ordenes AS O
INNER JOIN @t430_cm_pv_docto AS t430
    ON t430.f430_num_docto_referencia =
       CASE
           WHEN LEN(REPLACE(JSON_VALUE(O.orden_obj_origen, '$.orderId'), '-', '')) <= 15
           THEN REPLACE(JSON_VALUE(O.orden_obj_origen, '$.orderId'), '-', '')
           ELSE JSON_VALUE(O.orden_obj_origen, '$.sequence')
       END
INNER JOIN @t460_cm_docto_remision_venta AS t460
    ON t430.f430_rowid = t460.f460_rowid_pv_docto
INNER JOIN @t461_cm_docto_factura_venta AS t461
    ON t461.f461_rowid_docto = t460.f460_rowid_docto_factura
INNER JOIN @t350_co_docto_contable AS t350
    ON t350.f350_rowid = t461.f461_rowid_docto
OUTER APPLY
(
    SELECT TOP (1)
        LTRIM(RTRIM(gt.remision)) AS trackingNumber,
        gt.url AS trackingUrl
    FROM guias_transportadoras AS gt
    WHERE gt.id_orden = O.id
      AND gt.id_transportadora = 1
      AND NULLIF(LTRIM(RTRIM(gt.remision)), '') IS NOT NULL
    ORDER BY gt.fecha_creacion DESC, gt.id DESC
) AS guia
WHERE O.id_estado = @id_estado_lectura
  AND O.id_tienda = 1
  AND O.intentos <= 3
  AND ISNULL(O.orden_obj_destino, '') <> ''
  AND (
        @genera_guia = 0
        OR guia.trackingNumber IS NOT NULL
      );

SELECT
    'INVOICED_PREPARADO' AS resultado,
    @genera_guia AS genera_guia,
    @id_estado_lectura AS estado_lectura,
    @id_estado_final AS estado_siguiente_motor;
