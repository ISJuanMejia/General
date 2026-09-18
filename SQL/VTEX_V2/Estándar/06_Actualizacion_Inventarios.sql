/* =========================================================================================
   PROYECTO: VTEX ESTÁNDAR V2
   PROCESO: 06. ACTUALIZACIÓN DE INVENTARIOS
   TABLA DESTINO: dbo.inventarios
   DESCRIPCIÓN: MERGE delta que calcula el saldo disponible neto por bodega en el ERP
                (Existencia - Comprometido - POS) y actualiza VTEX Logistics API
                (/api/logistics/pvt/inventory/skus/{skuId}/warehouses/{warehouseId}).
   ========================================================================================= */

SET NOCOUNT ON;

DECLARE @id_tienda          INT = 1;
DECLARE @id_cia             INT = 1;
DECLARE @id_bodega_vtex     VARCHAR(50) = '1'; -- Identificador de Bodega configurado en VTEX

-- 1. Pre-calcular saldos disponibles agregados por código de barras
;WITH SaldosPorSKU AS (
    SELECT
        [sku_erp]     = TRIM(b.f131_id),
        [saldo_neto]  = SUM(CAST(ex.f400_cant_existencia_1 - (ex.f400_cant_comprometida_1 + ex.f400_cant_pos_1) AS INT))
    FROM [UnoEE_ERP].[dbo].[t400_cm_existencia] ex
    INNER JOIN [UnoEE_ERP].[dbo].[t150_mc_bodegas] bod 
        ON bod.f150_rowid = ex.f400_rowid_bodega 
       AND bod.f150_id_cia = @id_cia
    INNER JOIN [UnoEE_ERP].[dbo].[t121_mc_items_extensiones] ext 
        ON ext.f121_rowid = ex.f400_rowid_item_ext 
       AND ext.f121_id_cia = @id_cia
    INNER JOIN [UnoEE_ERP].[dbo].[t131_mc_items_barras] b 
        ON b.f131_rowid_item_ext = ext.f121_rowid 
       AND b.f131_id_cia = @id_cia
    WHERE ex.f400_id_cia = @id_cia
      AND bod.f150_id IN ('BV300', '00126') -- Bodegas origen despachos web
    GROUP BY b.f131_id
),
-- 2. Consolidar con variantes activas y estructurar payload JSON
InventarioConsolidado AS (
    SELECT
        [id_tienda]             = @id_tienda,
        [id_variante]           = v.id,
        [id_variante_ecommerce] = v.id_variante_ecommerce,
        [id_bodega_ecommerce]   = @id_bodega_vtex,
        [sku_erp]               = v.sku_erp,
        [cantidad]              = CASE 
                                      WHEN ISNULL(s.saldo_neto, 0) < 0 THEN 0 
                                      ELSE ISNULL(s.saldo_neto, 0) 
                                  END,
        [inventario_obj]        = (
            SELECT
                [unlimitedQuantity]      = CAST(0 AS BIT),
                [quantity]               = CASE 
                                               WHEN ISNULL(s.saldo_neto, 0) < 0 THEN 0 
                                               ELSE ISNULL(s.saldo_neto, 0) 
                                           END,
                [dateUtcOnBalanceSystem] = ''
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        [sincronizado]          = 0,
        [fecha_sincronizacion]  = GETDATE()
    FROM [dbo].[variantes] v
    LEFT JOIN SaldosPorSKU s 
        ON s.sku_erp = v.sku_erp
    WHERE v.id_tienda = @id_tienda
      AND v.sincronizado = 1
)
-- 3. MERGE en tabla intermedia: Solo actualiza si hay variación en la cantidad disponible
MERGE INTO [dbo].[inventarios] AS target
USING InventarioConsolidado AS source
ON (target.id_tienda = source.id_tienda 
    AND target.id_variante_ecommerce = source.id_variante_ecommerce 
    AND target.id_bodega_ecommerce = source.id_bodega_ecommerce)

WHEN MATCHED AND (target.cantidad <> source.cantidad) THEN
    UPDATE SET
        target.cantidad             = source.cantidad,
        target.inventario_obj       = source.inventario_obj,
        target.sincronizado         = 0,
        target.fecha_sincronizacion = source.fecha_sincronizacion

WHEN NOT MATCHED THEN
    INSERT ([id_tienda], [id_variante], [id_variante_ecommerce], [id_bodega_ecommerce], [sku_erp], [cantidad], [inventario_obj], [sincronizado], [fecha_sincronizacion])
    VALUES (source.id_tienda, source.id_variante, source.id_variante_ecommerce, source.id_bodega_ecommerce, source.sku_erp, source.cantidad, source.inventario_obj, source.sincronizado, source.fecha_sincronizacion);
