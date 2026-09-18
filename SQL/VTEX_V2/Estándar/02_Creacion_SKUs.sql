/* =========================================================================================
   PROYECTO: VTEX ESTÁNDAR V2
   PROCESO: 02. CREACIÓN DE SKUs / VARIANTES
   TABLA DESTINO: dbo.variantes
   DESCRIPCIÓN: Extrae códigos de barras y extensiones del ERP vinculados al producto padre,
                genera el payload JSON estándar para la API de SKUs (/api/catalog/pvt/stockkeepingunit)
                y los inserta en estado pendiente de sincronización.
   ========================================================================================= */

SET NOCOUNT ON;

DECLARE @id_tienda INT = 1;
DECLARE @id_cia    INT = 1;

-- 1. Extraer dimensiones y pesos del maestro de entidades
;WITH AtributosDimensiones AS (
    SELECT
        col.f753_rowid_movto_entidad,
        [alto]  = MAX(CASE WHEN atr.f743_id IN ('Num_Alto', 'ALTO') THEN col.f753_dato_numero END),
        [ancho] = MAX(CASE WHEN atr.f743_id IN ('Num_Ancho', 'ANCHO') THEN col.f753_dato_numero END),
        [largo] = MAX(CASE WHEN atr.f743_id IN ('Num_Largo', 'LARGO') THEN col.f753_dato_numero END),
        [peso]  = MAX(CASE WHEN atr.f743_id IN ('Num_Peso', 'PESO') THEN col.f753_dato_numero END)
    FROM [UnoEE_ERP].[dbo].[t753_mm_movto_entidad_columna] col
    INNER JOIN [UnoEE_ERP].[dbo].[t743_mm_entidad_atributo] atr 
        ON atr.f743_rowid = col.f753_rowid_entidad_atributo
    WHERE atr.f743_id IN ('Num_Alto', 'Num_Ancho', 'Num_Largo', 'Num_Peso', 'ALTO', 'ANCHO', 'LARGO', 'PESO')
    GROUP BY col.f753_rowid_movto_entidad
)
-- 2. Inserción de variantes asociadas al producto padre
INSERT INTO [dbo].[variantes]
(
    [id_tienda],
    [id_producto_ecommerce],
    [id_variante_ecommerce],
    [sku_erp],
    [variante_obj],
    [sincronizado],
    [fecha_sincronizacion]
)
SELECT DISTINCT
    [id_tienda]             = @id_tienda,
    [id_producto_ecommerce] = p.id_producto_ecommerce,
    [id_variante_ecommerce] = 0,
    [sku_erp]               = TRIM(b.f131_id),
    [variante_obj]          = (
        SELECT
            [Name]                  = TRIM(i.f120_descripcion),
            [RefId]                 = TRIM(i.f120_referencia),
            [IsActive]              = CAST(1 AS BIT),
            [ActivateIfPossible]    = CAST(1 AS BIT),
            [PackagedHeight]        = CAST(ISNULL(dim.alto, 1.0) AS DECIMAL(18,2)),
            [PackagedWidth]         = CAST(ISNULL(dim.ancho, 1.0) AS DECIMAL(18,2)),
            [PackagedLength]        = CAST(ISNULL(dim.largo, 1.0) AS DECIMAL(18,2)),
            [PackagedWeightKg]      = CAST(ISNULL(dim.peso, 0.5) AS DECIMAL(18,2)),
            [Height]                = 0,
            [Length]                = 0,
            [Width]                 = 0,
            [WeightKg]              = 0,
            [CubicWeight]           = 1,
            [IsKit]                 = CAST(0 AS BIT),
            [CreationDate]          = FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss'),
            [RewardValue]           = NULL,
            [EstimatedDateArrival]  = NULL,
            [ManufacturerCode]      = '',
            [CommercialConditionId] = 1,
            [MeasurementUnit]       = 'un',
            [UnitMultiplier]        = 1,
            [ModalType]             = NULL,
            [KitItensSellApart]     = CAST(0 AS BIT)
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ),
    [sincronizado]          = 0,
    [fecha_sincronizacion]  = GETDATE()
FROM [UnoEE_ERP].[dbo].[t120_mc_items] i
INNER JOIN [UnoEE_ERP].[dbo].[t121_mc_items_extensiones] ext 
    ON ext.f121_rowid_item = i.f120_rowid AND ext.f121_id_cia = @id_cia
INNER JOIN [UnoEE_ERP].[dbo].[t131_mc_items_barras] b 
    ON b.f131_rowid_item_ext = ext.f121_rowid AND b.f131_id_cia = @id_cia
INNER JOIN [dbo].[productos] p 
    ON p.id_tienda = @id_tienda 
   AND p.referencia_producto_erp = TRIM(i.f120_referencia)
LEFT JOIN AtributosDimensiones dim 
    ON dim.f753_rowid_movto_entidad = i.f120_rowid_movto_entidad
WHERE i.f120_id_cia = @id_cia
  AND i.f120_ind_estado = 1
  AND NOT EXISTS (
      SELECT 1 
      FROM [dbo].[variantes] v 
      WHERE v.id_tienda = @id_tienda 
        AND v.sku_erp = TRIM(b.f131_id)
  );
