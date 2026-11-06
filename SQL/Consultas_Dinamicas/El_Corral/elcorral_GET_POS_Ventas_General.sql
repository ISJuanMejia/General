DECLARE @id_cliente VARCHAR(20) = '{id_cliente}';
DECLARE @id_co VARCHAR(100) = '{id_co}';
DECLARE @fecha_inicio VARCHAR(25) = '{fecha_inicio}';
DECLARE @fecha_fin VARCHAR(25) = '{fecha_fin}';

-- =====================================================================
-- Validaciones
-- =====================================================================
DECLARE @fecha_inicio_dt DATETIME2 = TRY_CONVERT(DATETIME2, @fecha_inicio, 126);
DECLARE @fecha_fin_dt   DATETIME2 = TRY_CONVERT(DATETIME2, @fecha_fin,   126);

IF @fecha_inicio_dt IS NULL OR @fecha_fin_dt IS NULL
BEGIN
    SELECT 'Formato de fecha inválido. Use el formato yyyy-MM-ddTHH:mm:ss.' AS error_message
    FOR JSON PATH, ROOT('errores');
    RETURN;
END

IF @fecha_inicio_dt > @fecha_fin_dt
BEGIN
    SELECT 'La fecha de inicio no puede ser mayor a la fecha de fin.' AS error_message
    FOR JSON PATH, ROOT('errores');
    RETURN;
END

-- Si la diferencia de fechas es mayor a 5 minutos, mostramos advertencia y retornamos sin ejecutar la consulta principal. Esto es para evitar consultas muy pesadas que puedan afectar el rendimiento del sistema.

IF DATEDIFF(MINUTE, @fecha_inicio_dt, @fecha_fin_dt) > 5 AND DATEDIFF(DAY, @fecha_inicio_dt, @fecha_fin_dt) = 0
BEGIN

    SELECT 'El rango de fechas no puede ser mayor a 5 minutos.' AS error_message
    FOR JSON PATH, ROOT('errores');
    RETURN;
END

SET @id_cliente = RTRIM(@id_cliente);
SET @id_co      = RTRIM(@id_co);

-- =====================================================================
-- Clientes excluidos (IDs de prueba/demo)
-- =====================================================================
DECLARE @clientes_excluidos TABLE (id_cliente VARCHAR(20) PRIMARY KEY);
INSERT INTO @clientes_excluidos (id_cliente) VALUES
 ('22'),('222'),('2222'),('22222'),('222222'),('2222222')
,('22222222'),('222222222'),('2222222222'),('22222222222')
,('222222222222'),('2222222222222'),('22222222222222'),('222222222222222');

-- =====================================================================
-- Filtros de cliente y CO materializados
-- =====================================================================
DECLARE @tbl_clientes TABLE (id_cliente VARCHAR(20) PRIMARY KEY);
DECLARE @tbl_cos      TABLE (id_co      VARCHAR(20) PRIMARY KEY);

INSERT INTO @tbl_clientes SELECT DISTINCT RTRIM(value) FROM STRING_SPLIT(@id_cliente, ',') WHERE RTRIM(value) <> '-1';
INSERT INTO @tbl_cos      SELECT DISTINCT RTRIM(value) FROM STRING_SPLIT(@id_co,      ',') WHERE RTRIM(value) <> '-1';

-- =====================================================================
-- Limpieza defensiva
-- =====================================================================
IF OBJECT_ID('tempdb..#table_ventas_generales',  'U') IS NOT NULL DROP TABLE #table_ventas_generales;
IF OBJECT_ID('tempdb..#table_ventas_medios_pago','U') IS NOT NULL DROP TABLE #table_ventas_medios_pago;
IF OBJECT_ID('tempdb..#table_ventas_items',      'U') IS NOT NULL DROP TABLE #table_ventas_items;

-- =====================================================================
-- Tablas temporales como HEAP + índice NONCLUSTERED en guid_docto
--
-- Sin PRIMARY KEY CLUSTERED sobre guid_docto ni guid_movto_venta:
-- ambas son columnas GUID (nvarchar aleatorio). Insertar en un B-tree
-- con claves aleatorias genera page splits en cada fila → degrada
-- el INSERT proporcionalmente al volumen.
-- El HEAP permite INSERT secuencial sin fragmentación.
-- El índice NONCLUSTERED en guid_docto cubre los seeks del SELECT final.
-- =====================================================================
CREATE TABLE #table_ventas_generales
(
    guid_docto          nvarchar(255) NOT NULL,
    documento           nvarchar(255),
    tipo_concepto       VARCHAR(20),
    id_cliente          VARCHAR(20),
    subtotal            decimal(18,2),
    impuestos           decimal(18,2),
    descuentos          decimal(18,2),
    total               decimal(18,2),
    fecha_docto         date,
    fecha_venta         datetime,
    fecha_actualizacion datetime
);
CREATE NONCLUSTERED INDEX IX_tvg_guid_docto ON #table_ventas_generales (guid_docto);

CREATE TABLE #table_ventas_medios_pago
(
    guid_docto             nvarchar(255) NOT NULL,
    id_medio_pago          VARCHAR(5),
    descripcion_medio_pago VARCHAR(255),
    valor_neto             decimal(18,2)
);
CREATE NONCLUSTERED INDEX IX_mp_guid_docto ON #table_ventas_medios_pago (guid_docto);

CREATE TABLE #table_ventas_items
(
    guid_docto        nvarchar(255) NOT NULL,
    guid_movto_venta  nvarchar(255) NOT NULL,
    id_item           VARCHAR(20),
    descripcion_item  VARCHAR(255),
    id_ext1_detalle   VARCHAR(255),
    id_ext2_detalle   VARCHAR(255),
    id_lista_precio   VARCHAR(20),
    id_concepto       VARCHAR(20),
    id_motivo         VARCHAR(20),
    tipo_item         VARCHAR(20),
    cantidad          decimal(18,2),
    precio_unitario   decimal(18,2),
    valor_bruto       decimal(18,2),
    valor_dscto       decimal(18,2),
    valor_impuesto    decimal(18,2),
    valor_neto        decimal(18,2)
);
CREATE NONCLUSTERED INDEX IX_items_guid_docto ON #table_ventas_items (guid_docto);

-- =====================================================================
-- Datos generales de venta — IF/ELSE + OPTION (RECOMPILE) por INSERT
-- =====================================================================
IF @id_cliente = '-1' AND @id_co = '-1'
BEGIN
    -- Ruta 1: sin filtro de cliente ni CO
    INSERT INTO #table_ventas_generales
        (guid_docto, documento, tipo_concepto, id_cliente, subtotal, impuestos, descuentos, total, fecha_docto, fecha_venta, fecha_actualizacion)
    SELECT f9820_guid
          ,CONCAT(f9820_id_co,'-',f9820_id_tipo_docto,'-',f9820_consec_docto)
          ,CASE f9820_id_concepto WHEN 1201 THEN 'Venta' WHEN 1202 THEN 'Devolución' ELSE 'Otro' END
          ,f9820_id_cliente_pdv, f9820_valor_bruto, f9820_valor_imp
          ,f9820_valor_dscto_global + f9820_valor_dscto_linea, f9820_valor_neto
          ,f9820_id_fecha_docto, f9820_fecha_ts_creacion, f9820_fecha_ts_actualizacion
    FROM t9820_pdv_d_doctos
    WHERE f9820_id_cia      = 1
      AND f9820_id_concepto IN (1201, 1202)
      AND f9820_ind_estado  = 1
      AND f9820_fecha_ts_actualizacion BETWEEN @fecha_inicio_dt AND @fecha_fin_dt
      AND NOT EXISTS (SELECT 1 FROM @clientes_excluidos WHERE id_cliente = f9820_id_cliente_pdv)
    OPTION (RECOMPILE);

    INSERT INTO #table_ventas_generales
        (guid_docto, documento, tipo_concepto, id_cliente, subtotal, impuestos, descuentos, total, fecha_docto, fecha_venta, fecha_actualizacion)
    SELECT f9920_guid
          ,CONCAT(f9920_id_co,'-',f9920_id_tipo_docto,'-',f9920_consec_docto)
          ,CASE f9920_id_concepto WHEN 1201 THEN 'Venta' WHEN 1202 THEN 'Devolución' ELSE 'Otro' END
          ,f9920_id_cliente_pdv, f9920_valor_bruto, f9920_valor_imp
          ,f9920_valor_dscto_global + f9920_valor_dscto_linea, f9920_valor_neto
          ,f9920_id_fecha_docto, f9920_fecha_ts_creacion, f9920_fecha_ts_actualizacion
    FROM t9920_pdv_a_doctos
    WHERE f9920_id_cia      = 1
      AND f9920_id_concepto IN (1201, 1202)
      AND f9920_ind_estado  = 1
      AND f9920_fecha_ts_actualizacion BETWEEN @fecha_inicio_dt AND @fecha_fin_dt
      AND NOT EXISTS (SELECT 1 FROM @clientes_excluidos WHERE id_cliente = f9920_id_cliente_pdv)
    OPTION (RECOMPILE);
END
ELSE IF @id_cliente = '-1' AND @id_co <> '-1'
BEGIN
    -- Ruta 2: filtro solo por centro de operación
    INSERT INTO #table_ventas_generales
        (guid_docto, documento, tipo_concepto, id_cliente, subtotal, impuestos, descuentos, total, fecha_docto, fecha_venta, fecha_actualizacion)
    SELECT f9820_guid
          ,CONCAT(f9820_id_co,'-',f9820_id_tipo_docto,'-',f9820_consec_docto)
          ,CASE f9820_id_concepto WHEN 1201 THEN 'Venta' WHEN 1202 THEN 'Devolución' ELSE 'Otro' END
          ,f9820_id_cliente_pdv, f9820_valor_bruto, f9820_valor_imp
          ,f9820_valor_dscto_global + f9820_valor_dscto_linea, f9820_valor_neto
          ,f9820_id_fecha_docto, f9820_fecha_ts_creacion, f9820_fecha_ts_actualizacion
    FROM t9820_pdv_d_doctos
    WHERE f9820_id_cia      = 1
      AND f9820_id_concepto IN (1201, 1202)
      AND f9820_ind_estado  = 1
      AND f9820_fecha_ts_actualizacion BETWEEN @fecha_inicio_dt AND @fecha_fin_dt
      AND f9820_id_co IN (SELECT id_co FROM @tbl_cos)
      AND NOT EXISTS (SELECT 1 FROM @clientes_excluidos WHERE id_cliente = f9820_id_cliente_pdv)
    OPTION (RECOMPILE);

    INSERT INTO #table_ventas_generales
        (guid_docto, documento, tipo_concepto, id_cliente, subtotal, impuestos, descuentos, total, fecha_docto, fecha_venta, fecha_actualizacion)
    SELECT f9920_guid
          ,CONCAT(f9920_id_co,'-',f9920_id_tipo_docto,'-',f9920_consec_docto)
          ,CASE f9920_id_concepto WHEN 1201 THEN 'Venta' WHEN 1202 THEN 'Devolución' ELSE 'Otro' END
          ,f9920_id_cliente_pdv, f9920_valor_bruto, f9920_valor_imp
          ,f9920_valor_dscto_global + f9920_valor_dscto_linea, f9920_valor_neto
          ,f9920_id_fecha_docto, f9920_fecha_ts_creacion, f9920_fecha_ts_actualizacion
    FROM t9920_pdv_a_doctos
    WHERE f9920_id_cia      = 1
      AND f9920_id_concepto IN (1201, 1202)
      AND f9920_ind_estado  = 1
      AND f9920_fecha_ts_actualizacion BETWEEN @fecha_inicio_dt AND @fecha_fin_dt
      AND f9920_id_co IN (SELECT id_co FROM @tbl_cos)
      AND NOT EXISTS (SELECT 1 FROM @clientes_excluidos WHERE id_cliente = f9920_id_cliente_pdv)
    OPTION (RECOMPILE);
END
ELSE IF @id_cliente <> '-1' AND @id_co = '-1'
BEGIN
    -- Ruta 3: filtro solo por cliente
    INSERT INTO #table_ventas_generales
        (guid_docto, documento, tipo_concepto, id_cliente, subtotal, impuestos, descuentos, total, fecha_docto, fecha_venta, fecha_actualizacion)
    SELECT f9820_guid
          ,CONCAT(f9820_id_co,'-',f9820_id_tipo_docto,'-',f9820_consec_docto)
          ,CASE f9820_id_concepto WHEN 1201 THEN 'Venta' WHEN 1202 THEN 'Devolución' ELSE 'Otro' END
          ,f9820_id_cliente_pdv, f9820_valor_bruto, f9820_valor_imp
          ,f9820_valor_dscto_global + f9820_valor_dscto_linea, f9820_valor_neto
          ,f9820_id_fecha_docto, f9820_fecha_ts_creacion, f9820_fecha_ts_actualizacion
    FROM t9820_pdv_d_doctos
    WHERE f9820_id_cia      = 1
      AND f9820_id_concepto IN (1201, 1202)
      AND f9820_ind_estado  = 1
      AND f9820_fecha_ts_actualizacion BETWEEN @fecha_inicio_dt AND @fecha_fin_dt
      AND f9820_id_cliente_pdv IN (SELECT id_cliente FROM @tbl_clientes)
      AND NOT EXISTS (SELECT 1 FROM @clientes_excluidos WHERE id_cliente = f9820_id_cliente_pdv)
    OPTION (RECOMPILE);

    INSERT INTO #table_ventas_generales
        (guid_docto, documento, tipo_concepto, id_cliente, subtotal, impuestos, descuentos, total, fecha_docto, fecha_venta, fecha_actualizacion)
    SELECT f9920_guid
          ,CONCAT(f9920_id_co,'-',f9920_id_tipo_docto,'-',f9920_consec_docto)
          ,CASE f9920_id_concepto WHEN 1201 THEN 'Venta' WHEN 1202 THEN 'Devolución' ELSE 'Otro' END
          ,f9920_id_cliente_pdv, f9920_valor_bruto, f9920_valor_imp
          ,f9920_valor_dscto_global + f9920_valor_dscto_linea, f9920_valor_neto
          ,f9920_id_fecha_docto, f9920_fecha_ts_creacion, f9920_fecha_ts_actualizacion
    FROM t9920_pdv_a_doctos
    WHERE f9920_id_cia      = 1
      AND f9920_id_concepto IN (1201, 1202)
      AND f9920_ind_estado  = 1
      AND f9920_fecha_ts_actualizacion BETWEEN @fecha_inicio_dt AND @fecha_fin_dt
      AND f9920_id_cliente_pdv IN (SELECT id_cliente FROM @tbl_clientes)
      AND NOT EXISTS (SELECT 1 FROM @clientes_excluidos WHERE id_cliente = f9920_id_cliente_pdv)
    OPTION (RECOMPILE);
END
ELSE
BEGIN
    -- Ruta 4: filtro por cliente Y centro de operación
    INSERT INTO #table_ventas_generales
        (guid_docto, documento, tipo_concepto, id_cliente, subtotal, impuestos, descuentos, total, fecha_docto, fecha_venta, fecha_actualizacion)
    SELECT f9820_guid
          ,CONCAT(f9820_id_co,'-',f9820_id_tipo_docto,'-',f9820_consec_docto)
          ,CASE f9820_id_concepto WHEN 1201 THEN 'Venta' WHEN 1202 THEN 'Devolución' ELSE 'Otro' END
          ,f9820_id_cliente_pdv, f9820_valor_bruto, f9820_valor_imp
          ,f9820_valor_dscto_global + f9820_valor_dscto_linea, f9820_valor_neto
          ,f9820_id_fecha_docto, f9820_fecha_ts_creacion, f9820_fecha_ts_actualizacion
    FROM t9820_pdv_d_doctos
    WHERE f9820_id_cia      = 1
      AND f9820_id_concepto IN (1201, 1202)
      AND f9820_ind_estado  = 1
      AND f9820_fecha_ts_actualizacion BETWEEN @fecha_inicio_dt AND @fecha_fin_dt
      AND f9820_id_cliente_pdv IN (SELECT id_cliente FROM @tbl_clientes)
      AND f9820_id_co          IN (SELECT id_co      FROM @tbl_cos)
      AND NOT EXISTS (SELECT 1 FROM @clientes_excluidos WHERE id_cliente = f9820_id_cliente_pdv)
    OPTION (RECOMPILE);

    INSERT INTO #table_ventas_generales
        (guid_docto, documento, tipo_concepto, id_cliente, subtotal, impuestos, descuentos, total, fecha_docto, fecha_venta, fecha_actualizacion)
    SELECT f9920_guid
          ,CONCAT(f9920_id_co,'-',f9920_id_tipo_docto,'-',f9920_consec_docto)
          ,CASE f9920_id_concepto WHEN 1201 THEN 'Venta' WHEN 1202 THEN 'Devolución' ELSE 'Otro' END
          ,f9920_id_cliente_pdv, f9920_valor_bruto, f9920_valor_imp
          ,f9920_valor_dscto_global + f9920_valor_dscto_linea, f9920_valor_neto
          ,f9920_id_fecha_docto, f9920_fecha_ts_creacion, f9920_fecha_ts_actualizacion
    FROM t9920_pdv_a_doctos
    WHERE f9920_id_cia      = 1
      AND f9920_id_concepto IN (1201, 1202)
      AND f9920_ind_estado  = 1
      AND f9920_fecha_ts_actualizacion BETWEEN @fecha_inicio_dt AND @fecha_fin_dt
      AND f9920_id_cliente_pdv IN (SELECT id_cliente FROM @tbl_clientes)
      AND f9920_id_co          IN (SELECT id_co      FROM @tbl_cos)
      AND NOT EXISTS (SELECT 1 FROM @clientes_excluidos WHERE id_cliente = f9920_id_cliente_pdv)
    OPTION (RECOMPILE);
END

-- =====================================================================
-- Medios de pago
-- =====================================================================
INSERT INTO #table_ventas_medios_pago (guid_docto, id_medio_pago, descripcion_medio_pago, valor_neto)
SELECT
     t9821.f9821_guid_docto
    ,t9821.f9821_id_medio_pago
    ,mp.f025_descripcion
    ,t9821.f9821_valor_ingreso - t9821.f9821_valor_egreso
FROM t9821_pdv_d_movto_mp t9821
INNER JOIN t025_mm_medios_pago mp
    ON mp.f025_id = t9821.f9821_id_medio_pago AND mp.f025_id_cia = 1
INNER JOIN #table_ventas_generales tvg
    ON tvg.guid_docto = t9821.f9821_guid_docto
WHERE t9821.f9821_ind_naturaleza = 1

UNION ALL

SELECT
     t9921.f9921_guid_docto
    ,t9921.f9921_id_medio_pago
    ,mp.f025_descripcion
    ,t9921.f9921_valor_ingreso - t9921.f9921_valor_egreso
FROM t9921_pdv_a_movto_mp t9921
INNER JOIN t025_mm_medios_pago mp
    ON mp.f025_id = t9921.f9921_id_medio_pago AND mp.f025_id_cia = 1
INNER JOIN #table_ventas_generales tvg
    ON tvg.guid_docto = t9921.f9921_guid_docto
WHERE t9921.f9921_ind_naturaleza = 1;

-- =====================================================================
-- Ítems de venta
-- =====================================================================
INSERT INTO #table_ventas_items
    (guid_docto, guid_movto_venta, id_item, descripcion_item, id_ext1_detalle, id_ext2_detalle,
     id_lista_precio, id_concepto, id_motivo, tipo_item, cantidad, precio_unitario,
     valor_bruto, valor_dscto, valor_impuesto, valor_neto)
SELECT
     tvg.guid_docto
    ,t9830.f9830_guid
    ,t120.f120_id
    ,t120.f120_descripcion
    ,t121.f121_id_ext1_detalle
    ,t121.f121_id_ext2_detalle
    ,t9830.f9830_id_lista_precio
    ,t9830.f9830_id_concepto
    ,t9830.f9830_id_motivo
    ,CASE t9830.f9830_ind_tipo_item
        WHEN 1 THEN 'Inventario' WHEN 2 THEN 'Servicio'
        WHEN 3 THEN 'Kit'        WHEN 4 THEN 'Fantasma' ELSE 'Otro'
     END
    ,t9830.f9830_cant_base, t9830.f9830_precio_uni, t9830.f9830_vlr_bruto
    ,t9830.f9830_vlr_dscto_linea + t9830.f9830_vlr_dscto_global
    ,t9830.f9830_vlr_imp, t9830.f9830_vlr_neto
FROM t9830_pdv_d_movto_venta t9830
INNER JOIN #table_ventas_generales tvg ON tvg.guid_docto = t9830.f9830_guid_docto
INNER JOIN t121_mc_items_extensiones t121 ON t121.f121_rowid = t9830.f9830_rowid_item_ext
INNER JOIN t120_mc_items t120 ON t120.f120_rowid = t121.f121_rowid_item

UNION ALL

SELECT
     tvg.guid_docto
    ,t9930.f9930_guid
    ,t120.f120_id
    ,t120.f120_descripcion
    ,t121.f121_id_ext1_detalle
    ,t121.f121_id_ext2_detalle
    ,t9930.f9930_id_lista_precio
    ,t9930.f9930_id_concepto
    ,t9930.f9930_id_motivo
    ,CASE t9930.f9930_ind_tipo_item
        WHEN 1 THEN 'Inventario' WHEN 2 THEN 'Servicio'
        WHEN 3 THEN 'Kit'        WHEN 4 THEN 'Fantasma' ELSE 'Otro'
     END
    ,t9930.f9930_cant_base, t9930.f9930_precio_uni, t9930.f9930_vlr_bruto
    ,t9930.f9930_vlr_dscto_linea + t9930.f9930_vlr_dscto_global
    ,t9930.f9930_vlr_imp, t9930.f9930_vlr_neto
FROM t9930_pdv_a_movto_venta t9930
INNER JOIN #table_ventas_generales tvg ON tvg.guid_docto = t9930.f9930_guid_docto
INNER JOIN t121_mc_items_extensiones t121 ON t121.f121_rowid = t9930.f9930_rowid_item_ext
INNER JOIN t120_mc_items t120 ON t120.f120_rowid = t121.f121_rowid_item;

-- =====================================================================
-- Resultado final en JSON
-- =====================================================================
SELECT
     vg.guid_docto, vg.documento, vg.tipo_concepto, vg.id_cliente
    ,vg.subtotal, vg.impuestos, vg.descuentos, vg.total
    ,vg.fecha_docto, vg.fecha_venta, vg.fecha_actualizacion
    ,(
        SELECT mp.id_medio_pago, mp.descripcion_medio_pago, mp.valor_neto
        FROM #table_ventas_medios_pago mp
        WHERE mp.guid_docto = vg.guid_docto
        FOR JSON PATH
    ) AS medios_pago
    ,(
        SELECT vi.guid_movto_venta, vi.id_item, vi.descripcion_item
              ,vi.id_ext1_detalle, vi.id_ext2_detalle, vi.id_lista_precio
              ,vi.id_concepto, vi.id_motivo, vi.tipo_item, vi.cantidad
              ,vi.precio_unitario, vi.valor_bruto, vi.valor_dscto
              ,vi.valor_impuesto, vi.valor_neto
        FROM #table_ventas_items vi
        WHERE vi.guid_docto = vg.guid_docto
        FOR JSON PATH
    ) AS movimientos
FROM #table_ventas_generales vg
ORDER BY vg.fecha_venta
FOR JSON PATH, ROOT('documentos');

-- =====================================================================
-- Limpieza
-- =====================================================================
DROP TABLE IF EXISTS #table_ventas_generales;
DROP TABLE IF EXISTS #table_ventas_medios_pago;
DROP TABLE IF EXISTS #table_ventas_items;