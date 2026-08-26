/* =========================================================================================
   PROYECTO:     VTEX V2 - ORTOPÉDICOS FUTURO
   ARCHIVO:      Inventarios.sql
   DESCRIPCIÓN:  Actualización de inventarios desde ERP SIESA (UnoEE_PruebasProyectosCol)
                 hacia la tabla [dbo].[inventarios] de la BD de integración VTEX.
   
   BASE DE DATOS INTEGRACIÓN: Integracion-VTEX-Estandar-Ortopedicos
   BASE DE DATOS ERP:         UnoEE_PruebasProyectosCol (acceso cross-database directo)
   COMPAÑÍA ERP (id_cia):     1
   TIENDA INTEGRACIÓN:        1 (ortopedicos)

   TABLAS ERP UTILIZADAS:
     - t131_mc_items_barras     → Códigos de barras (EAN) de los ítems
     - t400_cm_existencia       → Existencias consolidadas por item_ext + bodega
     - t150_mc_bodegas          → Maestro de bodegas
   
   TABLAS INTEGRACIÓN:
     - variantes                → SKUs sincronizados (sku_erp = código de barras EAN)
     - productos                → Productos con id_tienda
     - inventarios              → Tabla destino de inventario por variante/bodega

   RELACIÓN SKU/VARIANTE ↔ ERP:
     variantes.sku_erp  ←→  t131_mc_items_barras.f131_id (código de barras EAN)
     t131.f131_rowid_item_ext  ←→  t400.f400_rowid_item_ext (extensión del ítem)

   CÁLCULO DE INVENTARIO DISPONIBLE:
     Disponible = f400_cant_existencia_1 
                  - f400_cant_comprometida_1 
                  - f400_cant_salida_sin_conf_1
                  - f400_cant_pos_1
   
   NOTAS:
     - Se usa t400_cm_existencia (existencia consolidada, NO por lote).
     - Se usa DECLARE @TABLE en lugar de tablas temporales #temp.
     - No se aplica conversión de unidades ni filtro por criterios.
     - Se incluyen productos con existencia 0 (cantidad = 0).
     - Bodega ERP confirmada: 00126 (MERCADO LIBRE).
     - PENDIENTE: id_bodega_ecommerce de VTEX (reemplazar 'PENDIENTE').

   ========================================================================================= */

SET NOCOUNT ON;

-- =============================================================================
-- PASO 0: MAPEO DE BODEGAS ERP → ECOMMERCE (VTEX)
-- =============================================================================
-- BODEGA CONFIRMADA:
--   00126 - MERCADO LIBRE (9,327 uds disponibles, 1,301 SKUs con stock)
--
-- PENDIENTE: Confirmar el id_bodega_ecommerce de VTEX para esta bodega.
--            Reemplazar 'PENDIENTE' por el valor real antes de ejecutar.

DECLARE @MapeoBodegas TABLE (
    id_bodega_erp       VARCHAR(10)     NOT NULL,
    id_bodega_ecommerce VARCHAR(50)     NOT NULL,
    PRIMARY KEY (id_bodega_erp)
);

-- >>> PENDIENTE: reemplazar 'PENDIENTE' por el id_bodega_ecommerce real de VTEX <<<
INSERT INTO @MapeoBodegas (id_bodega_erp, id_bodega_ecommerce)
VALUES
    ('00101', '101'),
    ('00102', '102'),
    ('00109', '109'),
    ('00118', '118'),
    ('00119', '119'),
    ('00120', '120'),
    ('00124', '124'),
    ('00127', '127'),
    ('00126', '126'), -- MERCADO LIBRE → id_bodega_ecommerce de VTEX
    ('00130', '130');

-- =============================================================================
-- PASO 1: VARIANTES SINCRONIZADAS DE LA TIENDA
-- =============================================================================
-- Obtiene todas las variantes que ya están sincronizadas con VTEX.
-- El sku_erp contiene el código de barras EAN del producto en el ERP.

DECLARE @Variantes TABLE (
    id_tienda               INT             NOT NULL,
    id_variante             INT             NOT NULL,
    sku_erp                 NVARCHAR(20)    NOT NULL,
    id_variante_ecommerce   INT             NOT NULL,
    INDEX IX_Variantes_SkuErp       NONCLUSTERED (sku_erp),
    INDEX IX_Variantes_Ecommerce    NONCLUSTERED (id_variante_ecommerce)
);

INSERT INTO @Variantes (
    id_tienda,
    id_variante,
    sku_erp,
    id_variante_ecommerce
)
SELECT
    p.id_tienda,
    v.id                        AS id_variante,
    v.sku_erp,
    v.id_variante_ecommerce
FROM dbo.variantes v
INNER JOIN dbo.productos p
    ON p.id_producto_ecommerce = v.id_producto_ecommerce
WHERE
    p.id_tienda     = 1
    AND v.sincronizado  = 1;

-- =============================================================================
-- PASO 2: INVENTARIO CALCULADO DESDE EL ERP
-- =============================================================================
-- Consulta la existencia consolidada (t400_cm_existencia) del ERP,
-- relacionando por código de barras (t131_mc_items_barras).
--
-- Fórmula: Disponible = Existencia - Comprometida - Salida sin confirmar - POS
-- Se agrupan las cantidades por variante + bodega ecommerce.

DECLARE @InventarioERP TABLE (
    id_tienda               INT             NOT NULL,
    id_variante_ecommerce   INT             NOT NULL,
    id_bodega_ecommerce     VARCHAR(50)     NOT NULL,
    cantidad                INT             NOT NULL,
    INDEX IX_InventarioERP NONCLUSTERED (id_variante_ecommerce, id_bodega_ecommerce)
);

INSERT INTO @InventarioERP (
    id_tienda,
    id_variante_ecommerce,
    id_bodega_ecommerce,
    cantidad
)
SELECT
    v.id_tienda,
    v.id_variante_ecommerce,
    mb.id_bodega_ecommerce,
    CONVERT(
        INT,
        SUM(
            e.f400_cant_existencia_1
            - e.f400_cant_comprometida_1
            - e.f400_cant_salida_sin_conf_1
            - e.f400_cant_pos_1
        )
    )                                       AS cantidad
FROM @Variantes v
INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras] b
    ON TRIM(b.f131_id) = v.sku_erp COLLATE DATABASE_DEFAULT
INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t400_cm_existencia] e
    ON  e.f400_rowid_item_ext = b.f131_rowid_item_ext
    AND e.f400_id_cia         = 1
INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t150_mc_bodegas] bod
    ON  bod.f150_rowid  = e.f400_rowid_bodega
    AND bod.f150_id_cia = 1
INNER JOIN @MapeoBodegas mb
    ON mb.id_bodega_erp = TRIM(bod.f150_id)
GROUP BY
    v.id_tienda,
    v.id_variante_ecommerce,
    mb.id_bodega_ecommerce;

-- =============================================================================
-- PASO 3: RESULTADO FINAL - GENERAR COMBINACIONES VARIANTE × BODEGA
-- =============================================================================
-- Genera la matriz completa: cada variante con cada bodega ecommerce.
-- Si no existe stock en el ERP para esa combinación, la cantidad queda en 0.

DECLARE @ResultadoFinal TABLE (
    id_tienda               INT             NOT NULL,
    id_variante             INT             NOT NULL,
    id_variante_ecommerce   INT             NOT NULL,
    id_bodega_ecommerce     VARCHAR(50)     NOT NULL,
    sku_erp                 NVARCHAR(20)    NOT NULL,
    cantidad                INT             NOT NULL,
    inventario_obj          NVARCHAR(MAX)       NULL,
    sincronizado            BIT             NOT NULL,
    fecha_sincronizacion    DATETIME        NOT NULL
);

INSERT INTO @ResultadoFinal (
    id_tienda,
    id_variante,
    id_variante_ecommerce,
    id_bodega_ecommerce,
    sku_erp,
    cantidad,
    inventario_obj,
    sincronizado,
    fecha_sincronizacion
)
SELECT
    v.id_tienda,
    v.id_variante,
    v.id_variante_ecommerce,
    b.id_bodega_ecommerce,
    v.sku_erp,
    ISNULL(i.cantidad, 0)                       AS cantidad,
    JSON_QUERY(
        '{"unlimitedQuantity": false, "quantity": '
        + CAST(ISNULL(i.cantidad, 0) AS VARCHAR(20))
        + ', "dateUtcOnBalanceSystem": "", "timeToRefill (deprecated)": ""}'
    )                                           AS inventario_obj,
    0                                           AS sincronizado,
    GETDATE()                                   AS fecha_sincronizacion
FROM @Variantes v
CROSS JOIN (SELECT DISTINCT id_bodega_ecommerce FROM @MapeoBodegas) b
LEFT JOIN @InventarioERP i
    ON  v.id_variante_ecommerce = i.id_variante_ecommerce
    AND b.id_bodega_ecommerce   = i.id_bodega_ecommerce;

-- =============================================================================
-- PASO 4: UPDATE - ACTUALIZAR REGISTROS EXISTENTES CON CAMBIO DE CANTIDAD
-- =============================================================================

UPDATE target
SET
    target.cantidad              = source.cantidad,
    target.inventario_obj        = source.inventario_obj,
    target.sincronizado          = 0,
    target.fecha_sincronizacion  = source.fecha_sincronizacion
FROM dbo.inventarios target
INNER JOIN @ResultadoFinal source
    ON  target.id_tienda             = source.id_tienda
    AND target.id_variante_ecommerce = source.id_variante_ecommerce
    AND target.id_bodega_ecommerce   = source.id_bodega_ecommerce
WHERE
    ISNULL(target.cantidad, 0) <> ISNULL(source.cantidad, 0);

-- =============================================================================
-- PASO 5: INSERT - REGISTROS NUEVOS QUE NO EXISTEN AÚN
-- =============================================================================

INSERT INTO dbo.inventarios (
    id_tienda,
    id_variante,
    id_variante_ecommerce,
    id_bodega_ecommerce,
    sku_erp,
    cantidad,
    inventario_obj,
    sincronizado,
    fecha_sincronizacion
)
SELECT
    source.id_tienda,
    source.id_variante,
    source.id_variante_ecommerce,
    source.id_bodega_ecommerce,
    source.sku_erp,
    source.cantidad,
    source.inventario_obj,
    source.sincronizado,
    source.fecha_sincronizacion
FROM @ResultadoFinal source
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.inventarios target
    WHERE
        target.id_tienda             = source.id_tienda
        AND target.id_variante_ecommerce = source.id_variante_ecommerce
        AND target.id_bodega_ecommerce   = source.id_bodega_ecommerce
);
