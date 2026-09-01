/* =============================================================
   1. PARAMETRIZACIÓN
   ============================================================= */

DECLARE @id_compania                    NVARCHAR(4)   = '4826',
        @id_sistema                     NVARCHAR(1)   = '2',
        @id_documento_transferencia      NVARCHAR(6)   = '252638',
        @nombre_documento_transferencia  NVARCHAR(255) = 'Vtex_Transferencias_Entre_Bodegas_Seriales',
        @validar_estructura              NVARCHAR(5)   = 'true';

DECLARE @estado_transferencias           INT = 3,
        @estado_pedido_por_integrar      INT = 4,
        @batch_size                      INT = 50;

DECLARE @endpoint_transferencias NVARCHAR(500);

SET @endpoint_transferencias =
        'http://localhost:8092/v3.1/ConectoresImportar?idCompania='
        + @id_compania
        + '&idSistema=' + @id_sistema
        + '&idDocumento=' + @id_documento_transferencia
        + '&nombreDocumento=' + @nombre_documento_transferencia
        + '&validarEstructura=' + @validar_estructura;


/* =============================================================
   2. TABLA DE ÓRDENES
   ============================================================= */


DECLARE @ordenes TABLE
(
    id_orden            NVARCHAR(50),
    orden_obj_origen    NVARCHAR(MAX)
);


INSERT INTO @ordenes
(
    id_orden,
    orden_obj_origen
)
SELECT TOP (@batch_size)
       id_orden,
       orden_obj_origen
FROM Ordenes WITH (ROWLOCK, READPAST)
WHERE 
id_estado = @estado_transferencias
 -- id_orden IN ('DDD-1656605315659-01')
  AND ISNULL(intentos, 0) <= 3
  AND orden_obj_origen IS NOT NULL
ORDER BY id_orden;



/* =============================================================
   3. MOVIMIENTOS SOLICITADOS POR VTEX

   Se normaliza la información del JSON.

   Una fila representa:

       Orden
       Item
       Bodega origen
       Cantidad solicitada
   ============================================================= */

DECLARE @movimientos_vtex TABLE
(
    id_orden            NVARCHAR(50),
    order_id            NVARCHAR(100),
    sequence            NVARCHAR(100),
    item_index           INT,
    referencia_item      NVARCHAR(100),
	ean                 NVARCHAR(100),
    cantidad_solicitada  DECIMAL(18,4),
    warehouse_id         NVARCHAR(50)
);

INSERT INTO @movimientos_vtex
(
    id_orden,
    order_id,
    sequence,
    item_index,
    referencia_item,
    ean,
    cantidad_solicitada,
    warehouse_id
)
SELECT
    o.id_orden,
    JSON_VALUE(o.orden_obj_origen, '$.orderId'),
    JSON_VALUE(o.orden_obj_origen, '$.sequence'),
    TRY_CONVERT(
        INT,
        JSON_VALUE(i.value, '$.index')
    ),
    JSON_VALUE(i.value, '$.refId'),
	JSON_VALUE(i.value, '$.ean') AS ean,
    TRY_CONVERT(
        DECIMAL(18,4),
        JSON_VALUE(di.value, '$.quantity')
    ),
    CONCAT('00',JSON_VALUE(di.value, '$.warehouseId'))
FROM @ordenes o
CROSS APPLY OPENJSON(o.orden_obj_origen, '$.items') i
CROSS APPLY OPENJSON(o.orden_obj_origen, '$.shippingData.logisticsInfo') li
CROSS APPLY OPENJSON(JSON_QUERY(li.value, '$.deliveryIds')) di
WHERE TRY_CONVERT(INT, JSON_VALUE(li.value, '$.itemId'))
    = TRY_CONVERT(INT, JSON_VALUE(i.value, '$.id'));



/* =============================================================
   4. REFERENCIAS + BODEGAS NECESARIAS

   Esta tabla permite limitar la consulta de existencias
   únicamente a las combinaciones necesarias.
   ============================================================= */

DECLARE @referencias_bodegas TABLE
(
    referencia_item NVARCHAR(100),
    id_bodega       NVARCHAR(50)
);

INSERT INTO @referencias_bodegas
(
    referencia_item,
    id_bodega
)
SELECT DISTINCT
    referencia_item,
    warehouse_id
FROM @movimientos_vtex;


/* =============================================================
   5. EXISTENCIAS

   Se mantienen las dos fuentes:

       t401 -> existencias por lote / artículos no serializados

       t400 + t417 -> existencias de artículos serializados

   126 se consulta también para poder determinar el lote de
   ingreso.
   ============================================================= */

DECLARE @existencias TABLE
(
    id_cia                  NVARCHAR(20),
    id_co                   NVARCHAR(20),
    id_bodega               NVARCHAR(50),
    id_item                 BIGINT,
    referencia_item         NVARCHAR(100),
    id_ubicacion_aux        NVARCHAR(100),
    id_unidad_inventario    NVARCHAR(100),
    id_ext1_detalle         NVARCHAR(100),
    id_ext2_detalle         NVARCHAR(100),
    cant_comprometida_1     DECIMAL(18,4),
    cant_comprometida_2     DECIMAL(18,4),
    cant_existencia_1       DECIMAL(18,4),
    cant_existencia_2       DECIMAL(18,4),
    cantidad_disponible     DECIMAL(18,4),
    id_lote                 NVARCHAR(100),
    id_serial               NVARCHAR(100),
    fecha_creacion          DATE,
    ind_serial              NVARCHAR(20),
	ind_lote				NVARCHAR(20),
    fecha_garantia          NVARCHAR(20)
);


/* -------------------------------------------------------------
   5.1 LOTES
   ------------------------------------------------------------- */

INSERT INTO @existencias
(
    id_cia,
    id_co,
    id_bodega,
    id_item,
    referencia_item,
    id_ubicacion_aux,
    id_unidad_inventario,
    id_ext1_detalle,
    id_ext2_detalle,
    cant_comprometida_1,
    cant_comprometida_2,
    cant_existencia_1,
    cant_existencia_2,
    cantidad_disponible,
    id_lote,
    id_serial,
    fecha_creacion,
    ind_serial,
	ind_lote,
    fecha_garantia
)
SELECT DISTINCT
    t120.f120_id_cia,
    t150.f150_id_co,
    t150.f150_id,
    t120.f120_id,
    t120.f120_referencia,
    t401.f401_id_ubicacion_aux,
    t120.f120_id_unidad_inventario,
    t121.f121_id_ext1_detalle,
    t121.f121_id_ext2_detalle,
    t401.f401_cant_comprometida_1,
    t401.f401_cant_comprometida_2,
    t401.f401_cant_existencia_1,
    t401.f401_cant_existencia_2,

    ISNULL(t401.f401_cant_existencia_1, 0)
        - ISNULL(t401.f401_cant_comprometida_1, 0),

    t401.f401_id_lote,
    '',
    t403.f403_fecha_creacion,
    t120.f120_ind_serial,
	t120.f120_ind_lote,

    ''
FROM [UnoEE_PruebasProyectosCol].[dbo].t120_mc_items t120

INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].t121_mc_items_extensiones t121
    ON t120.f120_rowid = t121.f121_rowid_item

INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].t401_cm_existencia_lote t401
    ON t121.f121_rowid = t401.f401_rowid_item_ext

INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].t150_mc_bodegas t150
    ON t401.f401_rowid_bodega = t150.f150_rowid

LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].t403_cm_lotes t403
    ON t121.f121_rowid = t403.f403_rowid_item_ext
   AND t401.f401_id_cia = t403.f403_id_cia
   AND t401.f401_rowid_item_ext = t403.f403_rowid_item_ext
    AND t401.f401_id_lote = f403_id


INNER JOIN @referencias_bodegas rb
    ON rb.referencia_item = t120.f120_referencia
   AND rb.id_bodega = t150.f150_id

WHERE ISNULL(t120.f120_ind_serial, 0) = 0 AND 	t120.f120_ind_lote = 1 AND f401_cant_existencia_1 !=0;


/* -------------------------------------------------------------
   5.2 ARTÍCULOS SERIALIZADOS / NO LOTEADOS

   Para serializados existe una fila por serial activo.
   ------------------------------------------------------------- */

INSERT INTO @existencias
(
    id_cia,
    id_co,
    id_bodega,
    id_item,
    referencia_item,
    id_ubicacion_aux,
    id_unidad_inventario,
    id_ext1_detalle,
    id_ext2_detalle,
    cant_comprometida_1,
    cant_comprometida_2,
    cant_existencia_1,
    cant_existencia_2,
    cantidad_disponible,
    id_lote,
    id_serial,
    fecha_creacion,
    ind_serial,
	ind_lote,

    fecha_garantia
)
SELECT DISTINCT
    t120.f120_id_cia,
    t150.f150_id_co,
    t150.f150_id,
    t120.f120_id,
    t120.f120_referencia,
    t400.f400_id_ubicacion_aux,
    t120.f120_id_unidad_inventario,
    t121.f121_id_ext1_detalle,
    t121.f121_id_ext2_detalle,
    t400.f400_cant_comprometida_1,
    t400.f400_cant_comprometida_2,
    t400.f400_cant_existencia_1,
    t400.f400_cant_existencia_2,

    ISNULL(t400.f400_cant_existencia_1, 0)
        - ISNULL(t400.f400_cant_comprometida_1, 0),

    '',
    ISNULL(t417.f417_id, ''),
    t417.f417_fecha_creacion,
    t120.f120_ind_serial,
	t120.f120_ind_lote,

    ISNULL(
        CONVERT(NVARCHAR(20), t417.f417_fecha_salida, 112),
        ''
    )
FROM [UnoEE_PruebasProyectosCol].[dbo].t120_mc_items t120

INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].t121_mc_items_extensiones t121
    ON t120.f120_rowid = t121.f121_rowid_item

INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].t400_cm_existencia t400
    ON t121.f121_rowid = t400.f400_rowid_item_ext

INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].t150_mc_bodegas t150
    ON t400.f400_rowid_bodega = t150.f150_rowid

LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].t417_cm_seriales t417
    ON t121.f121_rowid = t417.f417_rowid_item_ext
   AND t150.f150_rowid = t417.f417_rowid_bodega
   AND t417.f417_ind_estado = 1

INNER JOIN @referencias_bodegas rb
    ON rb.referencia_item = t120.f120_referencia
   AND rb.id_bodega = t150.f150_id
WHERE t120.f120_ind_lote = 0


/* =============================================================
   6. TABLA DE ERRORES
   ============================================================= */

DECLARE @ordenes_error TABLE
(
    id_orden       NVARCHAR(50),
    mensaje_error  NVARCHAR(MAX)
);


/* =============================================================
   7. VALIDACIÓN DE EXISTENCIAS

   Para cada item:

       Disponible en bodega 126
       +
       Disponible en bodega origen
       >=
       Cantidad solicitada

   Para serializados, adicionalmente se valida la cantidad
   de seriales activos.
   ============================================================= */

;WITH Solicitudes AS
(
    SELECT
        id_orden,
        referencia_item,
        warehouse_id,
        SUM(cantidad_solicitada) AS cantidad_solicitada
    FROM @movimientos_vtex
    GROUP BY
        id_orden,
        referencia_item,
        warehouse_id
),
Disponibilidad AS
(
    SELECT
        s.id_orden,
        s.referencia_item,
        s.warehouse_id,
        s.cantidad_solicitada,

        ISNULL(
            SUM(
                CASE
                    WHEN e.id_bodega = s.warehouse_id
                     AND ISNULL(e.ind_serial, 0) = 0
                    THEN e.cantidad_disponible
                    ELSE 0
                END
            ), 0
        ) AS disponible_origen,

        ISNULL(
            SUM(
                CASE
                    WHEN e.id_bodega = '00126'
                     AND ISNULL(e.ind_serial, 0) = 0
                    THEN e.cantidad_disponible
                    ELSE 0
                END
            ), 0
        ) AS disponible_destino,

        MAX(
            CASE
                WHEN ISNULL(e.ind_serial, 0) = 1
                THEN 1
                ELSE 0
            END
        ) AS es_serial
    FROM Solicitudes s
    LEFT JOIN @existencias e
        ON e.referencia_item = s.referencia_item
       AND
       (
            e.id_bodega = s.warehouse_id
            OR e.id_bodega = '00126'
       )
    GROUP BY
        s.id_orden,
        s.referencia_item,
        s.warehouse_id,
        s.cantidad_solicitada
)
INSERT INTO @ordenes_error
(
    id_orden,
    mensaje_error
)
SELECT DISTINCT
    d.id_orden,
    CONCAT(
        'Existencia insuficiente para el item ',
        d.referencia_item,
        '. Cantidad solicitada: ',
        d.cantidad_solicitada,
        '. Disponible origen: ',
        d.disponible_origen,
        '. Disponible bodega 126: ',
        d.disponible_destino
    )
FROM Disponibilidad d
WHERE
    (
        d.es_serial = 0
        AND
        d.disponible_origen + d.disponible_destino
            < d.cantidad_solicitada
    )
    OR
    (
        d.es_serial = 1
        AND
        d.disponible_origen
            < d.cantidad_solicitada
    );


/* =============================================================
   8. MOVIMIENTOS BASE

   Aquí se determina cuánto debe salir realmente de cada bodega.

   Primero se utiliza la cantidad que ya existe en 126.

   Solo la diferencia se transfiere desde la bodega origen.

   Para lotes se consume FIFO por fecha_creacion.

   Para seriales se consume FIFO por fecha_creacion, pero los
   seriales se conservan para construir posteriormente la sección
   "Movimiento de Seriales".
   ============================================================= */

DECLARE @movimientos_base TABLE
(
    id_orden              NVARCHAR(50),
    order_id              NVARCHAR(100),
    sequence              NVARCHAR(100),
    warehouse_id          NVARCHAR(50),
    referencia_item       NVARCHAR(100),
    cantidad_solicitada   DECIMAL(18,4),
    cantidad_destino      DECIMAL(18,4),
    cantidad_movimiento   DECIMAL(18,4),
    id_lote               NVARCHAR(100),
    id_lote_ent           NVARCHAR(100),
    id_serial             NVARCHAR(100),
    fecha_garantia        NVARCHAR(20),
    fecha_creacion        DATE,
    id_co_movto           NVARCHAR(20),
    id_unidad_medida      NVARCHAR(100),
    id_ext1_detalle       NVARCHAR(100),
    id_ext2_detalle       NVARCHAR(100),
    ind_serial             NVARCHAR(20)
);


/* =============================================================
   8.1 CANTIDAD YA EXISTENTE EN BODEGA 126
   ============================================================= */

DECLARE @disponibilidad_destino TABLE
(
    id_orden             NVARCHAR(50),
    referencia_item      NVARCHAR(100),
    cantidad_destino     DECIMAL(18,4)
);

INSERT INTO @disponibilidad_destino
(
    id_orden,
    referencia_item,
    cantidad_destino
)
SELECT
    m.id_orden,
    m.referencia_item,
    SUM(
        CASE
            WHEN e.id_bodega = '00126'
             AND ISNULL(e.ind_serial, 0) = 0
            THEN e.cantidad_disponible
            ELSE 0
        END
    )
FROM @movimientos_vtex m
LEFT JOIN @existencias e
    ON e.referencia_item = m.referencia_item
   AND e.id_bodega = '00126'
GROUP BY
    m.id_orden,
    m.referencia_item;


/* =============================================================
   8.2 SOLICITUDES QUE REALMENTE DEBEN TRANSFERIRSE
   ============================================================= */

DECLARE @necesidades TABLE
(
    id_orden             NVARCHAR(50),
    order_id             NVARCHAR(100),
    sequence             NVARCHAR(100),
    referencia_item      NVARCHAR(100),
    warehouse_id         NVARCHAR(50),
    cantidad_solicitada  DECIMAL(18,4),
    cantidad_destino     DECIMAL(18,4),
    cantidad_transferir  DECIMAL(18,4)
);

INSERT INTO @necesidades
(
    id_orden,
    order_id,
    sequence,
    referencia_item,
    warehouse_id,
    cantidad_solicitada,
    cantidad_destino,
    cantidad_transferir
)
SELECT
    m.id_orden,
    MAX(m.order_id),
    MAX(m.sequence),
    m.referencia_item,
    m.warehouse_id,
    SUM(m.cantidad_solicitada),
    ISNULL(MAX(d.cantidad_destino), 0),

    CASE
        WHEN
            SUM(m.cantidad_solicitada)
            - ISNULL(MAX(d.cantidad_destino), 0) > 0
        THEN
            SUM(m.cantidad_solicitada)
            - ISNULL(MAX(d.cantidad_destino), 0)
        ELSE 0
    END
FROM @movimientos_vtex m
LEFT JOIN @disponibilidad_destino d
    ON d.id_orden = m.id_orden
   AND d.referencia_item = m.referencia_item
WHERE NOT EXISTS
(
    SELECT 1
    FROM @ordenes_error oe
    WHERE oe.id_orden = m.id_orden
)
GROUP BY
    m.id_orden,
    m.referencia_item,
    m.warehouse_id;


/* =============================================================
   8.3 DISTRIBUCIÓN FIFO DE EXISTENCIAS DE ORIGEN

   IMPORTANTE:

   Para serializados:
       cantidad_disponible = 1 por serial.

   Para lotes:
       cantidad_disponible = existencia - comprometida.

   La ventana calcula cuánto del registro actual debe utilizarse.
   ============================================================= */

;WITH ExistenciasOrigen AS
(
    SELECT
        n.id_orden,
        n.order_id,
        n.sequence,
        n.referencia_item,
        n.warehouse_id,
        n.cantidad_transferir,

        e.id_lote,
        e.id_serial,
        e.fecha_creacion,
        e.fecha_garantia,
        e.id_co,
        e.id_unidad_inventario,
        e.cantidad_disponible,
        e.ind_serial,
		e.id_ext1_detalle,
		e.id_ext2_detalle,

        SUM(
            e.cantidad_disponible
        ) OVER
        (
            PARTITION BY
                n.id_orden,
                n.referencia_item,
                n.warehouse_id
            ORDER BY
                e.fecha_creacion ASC,
                e.id_lote,
                e.id_serial
            ROWS UNBOUNDED PRECEDING
        ) AS acumulado
    FROM @necesidades n
    INNER JOIN @existencias e
        ON e.referencia_item = n.referencia_item
       AND e.id_bodega = n.warehouse_id
    WHERE n.cantidad_transferir > 0
      AND NOT EXISTS
      (
          SELECT 1
          FROM @ordenes_error oe
          WHERE oe.id_orden = n.id_orden
      )
),
Distribucion AS
(
    SELECT
        *,
        CASE
            WHEN acumulado <= cantidad_transferir
                THEN cantidad_disponible

            WHEN acumulado - cantidad_disponible
                 < cantidad_transferir
                THEN cantidad_transferir
                     - (acumulado - cantidad_disponible)

            ELSE 0
        END AS cantidad_asignada
    FROM ExistenciasOrigen
)
INSERT INTO @movimientos_base
(
    id_orden,
    order_id,
    sequence,
    warehouse_id,
    referencia_item,
    cantidad_solicitada,
    cantidad_destino,
    cantidad_movimiento,
    id_lote,
    id_lote_ent,
    id_serial,
    fecha_garantia,
    fecha_creacion,
    id_co_movto,
    id_unidad_medida,
	id_ext1_detalle,
	id_ext2_detalle,
    ind_serial
)
SELECT
    d.id_orden,
    d.order_id,
    d.sequence,
    d.warehouse_id,
    d.referencia_item,

    n.cantidad_solicitada,
    n.cantidad_destino,

    d.cantidad_asignada,

    ISNULL(d.id_lote, ''),
    ISNULL(d.id_lote, ''),

    --ISNULL(
    --    (
    --        SELECT TOP 1
    --            e126.id_lote
    --        FROM @existencias e126
    --        WHERE e126.referencia_item = d.referencia_item
    --          AND e126.id_bodega = '00126'
    --          AND ISNULL(e126.id_lote, '') <> ''
    --        ORDER BY
    --            e126.fecha_creacion ASC
    --    ),
    --    ''
    --),

    ISNULL(d.id_serial, ''),

    ISNULL(d.fecha_garantia, ''),

    d.fecha_creacion,

    d.id_co,

    d.id_unidad_inventario,
	ISNULL(d.id_ext1_detalle, ''),
	ISNULL(d.id_ext2_detalle, ''),
    ISNULL(d.ind_serial, 0)
FROM Distribucion d
INNER JOIN @necesidades n
    ON n.id_orden = d.id_orden
   AND n.referencia_item = d.referencia_item
   AND n.warehouse_id = d.warehouse_id
WHERE d.cantidad_asignada > 0;


/* =============================================================
   9. VALIDACIÓN FINAL DE LA DISTRIBUCIÓN

   Esto protege contra el caso en que la suma realmente asignada
   no alcance la cantidad que debe salir de origen.
   ============================================================= */

;WITH Validacion AS
(
    SELECT
        n.id_orden,
        n.referencia_item,
        n.warehouse_id,
        n.cantidad_transferir,
        ISNULL(
            SUM(mb.cantidad_movimiento),
            0
        ) AS cantidad_asignada
    FROM @necesidades n
    LEFT JOIN @movimientos_base mb
        ON mb.id_orden = n.id_orden
       AND mb.referencia_item = n.referencia_item
       AND mb.warehouse_id = n.warehouse_id
    WHERE n.cantidad_transferir > 0
    GROUP BY
        n.id_orden,
        n.referencia_item,
        n.warehouse_id,
        n.cantidad_transferir
)
INSERT INTO @ordenes_error
(
    id_orden,
    mensaje_error
)
SELECT
    id_orden,
    CONCAT(
        'No fue posible distribuir completamente el item ',
        referencia_item,
        '. Requerido desde origen: ',
        cantidad_transferir,
        '. Asignado: ',
        cantidad_asignada
    )
FROM Validacion
WHERE cantidad_asignada < cantidad_transferir;


/* =============================================================
   10. TRANSFERENCIAS

   Una transferencia = una bodega origen.

   Por eso una orden puede tener:

       Bodega 101 -> Documento 1
       Bodega 102 -> Documento 2
       Bodega 103 -> Documento 3
   ============================================================= */

DECLARE @transferencias TABLE
(
    id_orden            NVARCHAR(50),
    order_id            NVARCHAR(100),
    sequence            NVARCHAR(100),
    warehouse_id        NVARCHAR(50),
    consec_docto        INT
);

INSERT INTO @transferencias
(
    id_orden,
    order_id,
    sequence,
    warehouse_id,
    consec_docto
)
SELECT
    mb.id_orden,
    MAX(mb.order_id),
    MAX(mb.sequence),
    mb.warehouse_id,

    ROW_NUMBER() OVER
    (
        PARTITION BY mb.id_orden
        ORDER BY mb.warehouse_id
    )
FROM @movimientos_base mb
WHERE NOT EXISTS
(
    SELECT 1
    FROM @ordenes_error oe
    WHERE oe.id_orden = mb.id_orden
)
GROUP BY
    mb.id_orden,
    mb.warehouse_id;


/* =============================================================
   11. DOCUMENTOS
   ============================================================= */

DECLARE @documentos TABLE
(
    id_orden                    NVARCHAR(50),
    f350_consec_docto           NVARCHAR(20),
    f350_fecha                  NVARCHAR(20),
    f350_id_tercero             NVARCHAR(100),
    f350_notas                  NVARCHAR(500),
    f450_id_bodega_salida       NVARCHAR(50),
    f450_docto_alterno          NVARCHAR(100)
);

INSERT INTO @documentos
(
    id_orden,
    f350_consec_docto,
    f350_fecha,
    f350_id_tercero,
    f350_notas,
    f450_id_bodega_salida,
    f450_docto_alterno
)
SELECT
    t.id_orden,
    CAST(t.consec_docto AS NVARCHAR(20)),
    CONVERT(NVARCHAR(8), GETDATE(), 112),
    '',
    CONCAT(
        t.order_id,
        ' (',
        t.sequence,
        ')'
    ),
    t.warehouse_id,
    t.sequence
FROM @transferencias t;


/* =============================================================
   12. MOVIMIENTOS

   IMPORTANTE:

   Para serializados:

       Un único movimiento
       cantidad = N

   NO se genera un movimiento por cada serial.
   ============================================================= */

DECLARE @movimientos TABLE
(
    id_orden                    NVARCHAR(50),
    f470_consec_docto           NVARCHAR(20),
    f470_nro_registro           NVARCHAR(20),
    f470_id_bodega              NVARCHAR(50),
    f470_id_lote                NVARCHAR(100),
    f470_id_co_movto            NVARCHAR(20),
    f470_id_unidad_medida       NVARCHAR(100),
    f470_cant_base              NVARCHAR(50),
    f470_id_lote_ent            NVARCHAR(100),
    f470_referencia_item        NVARCHAR(100),
	f470_id_ext1_detalle        NVARCHAR(100),
    f470_id_ext2_detalle        NVARCHAR(100),
    f470_id_un_movto            NVARCHAR(20),
    ind_serial                  NVARCHAR(20)
);

;WITH MovimientosAgrupados AS
(
    SELECT
        mb.id_orden,
        t.consec_docto,
        mb.warehouse_id,

        /*
          Para seriales, todos los seriales pertenecientes al
          mismo item deben convertirse en un solo movimiento.
        */
        mb.referencia_item,
        mb.id_lote,
        mb.id_lote_ent,
        mb.id_co_movto,
        mb.id_unidad_medida,
        mb.ind_serial,
		mb.id_ext1_detalle,
		mb.id_ext2_detalle,

        SUM(mb.cantidad_movimiento) AS cantidad_movimiento,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                mb.id_orden,
                t.consec_docto
            ORDER BY
                mb.referencia_item,
                mb.id_lote,
                mb.id_serial
        ) AS nro_registro
    FROM @movimientos_base mb
    INNER JOIN @transferencias t
        ON t.id_orden = mb.id_orden
       AND t.warehouse_id = mb.warehouse_id
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM @ordenes_error oe
        WHERE oe.id_orden = mb.id_orden
    )
    GROUP BY
        mb.id_orden,
        t.consec_docto,
        mb.warehouse_id,
        mb.referencia_item,
        mb.id_lote,
        mb.id_lote_ent,
        mb.id_co_movto,
        mb.id_unidad_medida,
        mb.ind_serial,
		mb.id_ext1_detalle,
		mb.id_ext2_detalle,
        mb.id_serial

)
INSERT INTO @movimientos
(
    id_orden,
    f470_consec_docto,
    f470_nro_registro,
    f470_id_bodega,
    f470_id_lote,
    f470_id_co_movto,
    f470_id_unidad_medida,
    f470_cant_base,
    f470_id_lote_ent,
    f470_referencia_item,
    f470_id_un_movto,
	f470_id_ext1_detalle,
	f470_id_ext2_detalle,
    ind_serial
)
SELECT
    ma.id_orden,
    CAST(ma.consec_docto AS NVARCHAR(20)),
    CAST(ma.nro_registro AS NVARCHAR(20)),
    ma.warehouse_id,
    ISNULL(ma.id_lote, ''),
    ma.id_co_movto,
    ma.id_unidad_medida,
    CAST(ma.cantidad_movimiento AS NVARCHAR(50)),
    ISNULL(ma.id_lote_ent, ''),
    ma.referencia_item,
    '01',
    ISNULL(ma.id_ext1_detalle, ''),
    ISNULL(ma.id_ext2_detalle, ''),
    ma.ind_serial
FROM MovimientosAgrupados ma;


/* =============================================================
   13. MOVIMIENTO DE SERIALES

   Un registro por serial.

   f479_consec_docto = documento de transferencia

   f479_nro_registro = consecutivo INDEPENDIENTE de los
                       movimientos.

   Por tanto NO utilizamos f470_nro_registro.
   ============================================================= */

DECLARE @movimientos_seriales TABLE
(
    id_orden                NVARCHAR(50),
    f479_consec_docto       NVARCHAR(20),
    f479_nro_registro       NVARCHAR(20),
    f479_id_serial          NVARCHAR(100),
    f479_fecha_garantia     NVARCHAR(20),
    f479_notas              NVARCHAR(500)
);

;WITH SerialesNumerados AS
(
    SELECT
        mb.id_orden,
        t.consec_docto,
        mb.id_serial,
        mb.fecha_garantia,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                mb.id_orden,
                t.consec_docto
            ORDER BY
                mb.fecha_creacion ASC,
                mb.id_serial ASC
        ) AS nro_serial
    FROM @movimientos_base mb
    INNER JOIN @transferencias t
        ON t.id_orden = mb.id_orden
       AND t.warehouse_id = mb.warehouse_id
    WHERE ISNULL(mb.ind_serial, 0) = 1
      AND ISNULL(mb.id_serial, '') <> ''
      AND NOT EXISTS
      (
          SELECT 1
          FROM @ordenes_error oe
          WHERE oe.id_orden = mb.id_orden
      )
)
INSERT INTO @movimientos_seriales
(
    id_orden,
    f479_consec_docto,
    f479_nro_registro,
    f479_id_serial,
    f479_fecha_garantia,
    f479_notas
)
SELECT
    sn.id_orden,
    CAST(sn.consec_docto AS NVARCHAR(20)),
    CAST(sn.nro_serial AS NVARCHAR(20)),
    sn.id_serial,
    ISNULL(sn.fecha_garantia, ''),
    ''
FROM SerialesNumerados sn;


/*
Bloque de revision de errores
*/

--SELECT 'ORDENES' AS etapa, *
--FROM @ordenes;

--SELECT 'MOVIMIENTOS_VTEX' AS etapa, *
--FROM @movimientos_vtex;

--SELECT 'REFERENCIAS_BODEGAS' AS etapa, *
--FROM @referencias_bodegas;

--SELECT 'EXISTENCIAS' AS etapa, *
--FROM @existencias
--ORDER BY
--    referencia_item,
--    id_bodega,
--    fecha_creacion;

--SELECT 'ORDENES_ERROR' AS etapa, *
--FROM @ordenes_error;

--SELECT 'NECESIDADES' AS etapa, *
--FROM @necesidades;

--SELECT 'MOVIMIENTOS_BASE' AS etapa, *
--FROM @movimientos_base;

--SELECT 'TRANSFERENCIAS' AS etapa, *
--FROM @transferencias;

--SELECT 'DOCUMENTOS' AS etapa, *
--FROM @documentos;

--SELECT 'MOVIMIENTOS' AS etapa, *
--FROM @movimientos;

--SELECT 'MOVIMIENTOS_SERIALES' AS etapa, *
--FROM @movimientos_seriales;

/* =============================================================
   14. CONSTRUCCIÓN DE LOS JSON POR ORDEN

   Se genera un payload independiente por cada orden.

   Estructura base:

       {
           "Documentos": [...],
           "Movimientos": [...]
       }

   Cuando existen seriales se agrega:

       "Movimiento_de_Seriales": [...]

   Si la orden no tiene seriales, la propiedad NO se incluye.
   ============================================================= */

DECLARE @OrdenesDestino TABLE
(
    id_orden            NVARCHAR(50),
    endpoint            NVARCHAR(500),
    intentos            INT,
    fecha_creacion      DATETIME,
    orden_obj_destino   NVARCHAR(MAX)
);


INSERT INTO @OrdenesDestino
(
    id_orden,
    endpoint,
    intentos,
    fecha_creacion,
    orden_obj_destino
)
SELECT
    o.id_orden,
    @endpoint_transferencias,
    0,
    GETDATE(),
    JSON_MODIFY(
        (
            SELECT
                JSON_QUERY
                (
                    (
                        SELECT
                            d.f350_consec_docto,
                            d.f350_fecha,
                            d.f350_id_tercero,
                            d.f350_notas,
                            d.f450_id_bodega_salida,
                            d.f450_docto_alterno
                        FROM @documentos d
                        WHERE d.id_orden = o.id_orden
                        ORDER BY
                            TRY_CONVERT(INT, d.f350_consec_docto)
                        FOR JSON PATH
                    )
                ) AS [Documentos],

                JSON_QUERY
                (
                    (
                        SELECT
                            m.f470_consec_docto,
                            m.f470_nro_registro,
                            m.f470_id_bodega,
                            m.f470_id_lote,
                            m.f470_id_co_movto,
                            m.f470_id_unidad_medida,
                            m.f470_cant_base,
                            m.f470_id_lote_ent,
                            m.f470_referencia_item,
                            m.f470_id_ext1_detalle,
                            m.f470_id_ext2_detalle,
                            m.f470_id_un_movto
                        FROM @movimientos m
                        WHERE m.id_orden = o.id_orden
                        ORDER BY
                            TRY_CONVERT(INT, m.f470_consec_docto),
                            TRY_CONVERT(INT, m.f470_nro_registro)
                        FOR JSON PATH
                    )
                ) AS [Movimientos]

            FOR JSON PATH,
                WITHOUT_ARRAY_WRAPPER
        ),

        '$.Movimiento_de_Seriales',

        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM @movimientos_seriales ms
                WHERE ms.id_orden = o.id_orden
            )
            THEN
                JSON_QUERY
                (
                    (
                        SELECT
                            ms.f479_consec_docto,
                            ms.f479_nro_registro,
                            ms.f479_id_serial,
                            ms.f479_fecha_garantia,
                            ms.f479_notas
                        FROM @movimientos_seriales ms
                        WHERE ms.id_orden = o.id_orden
                        ORDER BY
                            TRY_CONVERT(INT, ms.f479_consec_docto),
                            TRY_CONVERT(INT, ms.f479_nro_registro)
                        FOR JSON PATH
                    )
                )
            ELSE NULL
        END
    )
FROM
(
    SELECT DISTINCT
        ord.id_orden
    FROM @ordenes AS ord
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM @ordenes_error AS oe
        WHERE oe.id_orden = ord.id_orden
    )
) AS o;


/* =============================================================
   15. RESULTADO DE PRUEBA

   Permite revisar un payload por orden antes de ejecutar el
   proceso de actualización.
   ============================================================= */

SELECT
    d.id_orden,
    d.endpoint,
    d.orden_obj_destino
FROM @OrdenesDestino AS d
ORDER BY
    d.id_orden;


/* =============================================================
   16. UPDATE DE ÓRDENES

   Se actualiza únicamente la orden para la cual se generó
   correctamente el payload.

   La estructura sigue el patrón utilizado en Pedido por
   Integrar:

       endpoint
       intentos
       fecha_creacion
       orden_obj_destino

   IMPORTANTE:
   Este bloque NO cambia id_estado.

   La transición de estado 3 -> 4 debe realizarse según el
   mecanismo de control de estados de la integración, después
   de que el consumo del endpoint confirme la creación exitosa
   de las transferencias.

   Si este query se ejecuta directamente como etapa previa al
   POST, este UPDATE debe ejecutarse después de recibir la
   respuesta exitosa del endpoint.
   ============================================================= */

UPDATE o
SET
    o.endpoint          = d.endpoint,
	o.id_estado			= @estado_pedido_por_integrar,
    o.intentos          = 0,
    o.fecha_creacion    = d.fecha_creacion,
    o.orden_obj_destino = d.orden_obj_destino
 FROM dbo.ordenes AS o
INNER JOIN @OrdenesDestino AS d
    ON o.id_orden = d.id_orden;


/* =============================================================
   17. ERRORES

   Las órdenes que no tengan existencia suficiente o no hayan
   podido distribuir completamente sus cantidades no entran en
   @OrdenesDestino y por tanto no son actualizadas.
   ============================================================= */

SELECT
    id_orden,
    mensaje_error
FROM @ordenes_error;


/* =============================================================
   18. RESUMEN DE EJECUCIÓN
   ============================================================= */

SELECT
    (SELECT COUNT(*) FROM @ordenes) AS ordenes_seleccionadas,
    (SELECT COUNT(*) FROM @OrdenesDestino) AS ordenes_con_payload,
    (SELECT COUNT(DISTINCT id_orden) FROM @ordenes_error) AS ordenes_con_error;
