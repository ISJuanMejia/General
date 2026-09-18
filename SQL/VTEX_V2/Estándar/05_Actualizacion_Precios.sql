/* =========================================================================================
   PROYECTO: VTEX ESTÁNDAR V2
   PROCESO: 05. ACTUALIZACIÓN DE PRECIOS
   TABLA DESTINO: dbo.precios
   DESCRIPCIÓN: MERGE incremental que detecta cambios de precio en el ERP, genera el payload
                JSON para Pricing VTEX (/api/pricing/prices/{skuId}) y reactiva sincronizado = 0.
   ========================================================================================= */

SET NOCOUNT ON;

DECLARE @id_tienda       INT = 1;
DECLARE @id_cia          INT = 1;
DECLARE @id_lista_precio VARCHAR(10) = '100'; -- Código de lista de precio ecommerce ERP

-- 1. Obtener el precio vigente más reciente por ítem mediante ROW_NUMBER (Optimizado sin subconsulta correlacionada)
;WITH PreciosVigentes AS (
    SELECT
        pr.f126_rowid_item,
        pr.f126_precio,
        ROW_NUMBER() OVER (
            PARTITION BY pr.f126_rowid_item 
            ORDER BY pr.f126_fecha_activacion DESC
        ) AS rn
    FROM [UnoEE_ERP].[dbo].[t126_mc_items_precios] pr
    WHERE pr.f126_id_cia = @id_cia
      AND pr.f126_id_lista_precio = @id_lista_precio
      AND pr.f126_fecha_activacion <= GETDATE()
      AND pr.f126_precio > 0
),
-- 2. Cruzar con variantes sincronizadas y generar payload JSON de VTEX Pricing
PreciosCalculados AS (
    SELECT DISTINCT
        [id_tienda]             = @id_tienda,
        [id_variante]           = v.id,
        [id_variante_ecommerce] = v.id_variante_ecommerce,
        [sku_erp]               = v.sku_erp,
        [precio_obj]            = (
            SELECT
                [markup]      = 0,
                [basePrice]   = CAST(ROUND(pv.f126_precio, 0) AS INT),
                [listPrice]   = CAST(ROUND(pv.f126_precio, 0) AS INT),
                [fixedPrices] = (
                    SELECT
                        [tradePolicyId] = '1',
                        [value]         = CAST(ROUND(pv.f126_precio, 0) AS INT),
                        [listPrice]     = CAST(ROUND(pv.f126_precio, 0) AS INT),
                        [minQuantity]   = 1
                    FOR JSON PATH
                )
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        [sincronizado]          = 0,
        [fecha_sincronizacion]  = GETDATE()
    FROM [dbo].[variantes] v
    INNER JOIN [UnoEE_ERP].[dbo].[t131_mc_items_barras] b 
        ON TRIM(b.f131_id) = v.sku_erp AND b.f131_id_cia = @id_cia
    INNER JOIN [UnoEE_ERP].[dbo].[t121_mc_items_extensiones] ext 
        ON ext.f121_rowid = b.f131_rowid_item_ext AND ext.f121_id_cia = @id_cia
    INNER JOIN PreciosVigentes pv 
        ON pv.f126_rowid_item = ext.f121_rowid_item AND pv.rn = 1
    WHERE v.id_tienda = @id_tienda
      AND v.sincronizado = 1
)
-- 3. MERGE en tabla intermedia: Solo actualiza y reactiva sincronizado = 0 si hubo cambio en el JSON
MERGE INTO [dbo].[precios] AS target
USING PreciosCalculados AS source
ON (target.id_tienda = source.id_tienda 
    AND target.id_variante_ecommerce = source.id_variante_ecommerce)

WHEN MATCHED AND target.precio_obj <> source.precio_obj THEN
    UPDATE SET
        target.precio_obj           = source.precio_obj,
        target.sincronizado         = 0,
        target.fecha_sincronizacion = source.fecha_sincronizacion

WHEN NOT MATCHED THEN
    INSERT ([id_tienda], [id_variante], [id_variante_ecommerce], [sku_erp], [precio_obj], [sincronizado], [fecha_sincronizacion])
    VALUES (source.id_tienda, source.id_variante, source.id_variante_ecommerce, source.sku_erp, source.precio_obj, source.sincronizado, source.fecha_sincronizacion);
