/* =========================================================================================
   PROYECTO: VTEX ESTÁNDAR V2
   PROCESO: 01. CREACIÓN DE PRODUCTOS
   TABLA DESTINO: dbo.productos
   DESCRIPCIÓN: Extrae ítems maestros activos del ERP, genera el payload JSON estándar
                para la API de Catálogo de VTEX (/api/catalog/pvt/product) y los inserta
                con bandera de sincronización pendiente (sincronizado = 0).
   ========================================================================================= */

SET NOCOUNT ON;

DECLARE @id_tienda INT = 1;
DECLARE @id_cia    INT = 1;

-- 1. Identificar ítems maestros del ERP activos y categorizados
;WITH ItemsClasificados AS (
    SELECT
        i.f120_rowid,
        [referencia]       = TRIM(i.f120_referencia),
        [descripcion]      = TRIM(REPLACE(i.f120_descripcion, '  ', ' ')),
        [notas]            = TRIM(ISNULL(i.f120_notas, i.f120_descripcion)),
        [id_departamento]  = CAST(dept.f106_id AS INT),
        [id_categoria]     = CAST(cat.f106_id AS INT),
        [id_marca]         = CAST(marca.f106_id AS INT)
    FROM [UnoEE_ERP].[dbo].[t120_mc_items] i
    -- Departamento (Plan DPC)
    INNER JOIN [UnoEE_ERP].[dbo].[t125_mc_items_criterios] c_dept 
        ON c_dept.f125_rowid_item = i.f120_rowid 
       AND c_dept.f125_id_cia = @id_cia 
       AND c_dept.f125_id_plan = 'DPC'
    INNER JOIN [UnoEE_ERP].[dbo].[t106_mc_criterios_item_mayores] dept 
        ON dept.f106_id_cia = c_dept.f125_id_cia 
       AND dept.f106_id_plan = c_dept.f125_id_plan 
       AND dept.f106_id = c_dept.f125_id_criterio_mayor
    -- Categoría (Plan CC1)
    INNER JOIN [UnoEE_ERP].[dbo].[t125_mc_items_criterios] c_cat 
        ON c_cat.f125_rowid_item = i.f120_rowid 
       AND c_cat.f125_id_cia = @id_cia 
       AND c_cat.f125_id_plan = 'CC1'
    INNER JOIN [UnoEE_ERP].[dbo].[t106_mc_criterios_item_mayores] cat 
        ON cat.f106_id_cia = c_cat.f125_id_cia 
       AND cat.f106_id_plan = c_cat.f125_id_plan 
       AND cat.f106_id = c_cat.f125_id_criterio_mayor
    -- Marca (Plan 005)
    INNER JOIN [UnoEE_ERP].[dbo].[t125_mc_items_criterios] c_marca 
        ON c_marca.f125_rowid_item = i.f120_rowid 
       AND c_marca.f125_id_cia = @id_cia 
       AND c_marca.f125_id_plan = '005'
    INNER JOIN [UnoEE_ERP].[dbo].[t106_mc_criterios_item_mayores] marca 
        ON marca.f106_id_cia = c_marca.f125_id_cia 
       AND marca.f106_id_plan = c_marca.f125_id_plan 
       AND marca.f106_id = c_marca.f125_id_criterio_mayor
    WHERE i.f120_id_cia = @id_cia
      AND i.f120_ind_estado = 1 -- Ítems activos
)
-- 2. Inserción con formateo JSON y control de idempotencia
INSERT INTO [dbo].[productos]
(
    [id_tienda],
    [referencia_producto_erp],
    [id_producto_ecommerce],
    [producto_obj],
    [sincronizado],
    [fecha_sincronizacion]
)
SELECT DISTINCT
    [id_tienda]                 = @id_tienda,
    [referencia_producto_erp]   = item.referencia,
    [id_producto_ecommerce]     = 0,
    [producto_obj]              = (
        SELECT
            [Name]                      = item.descripcion,
            [DepartmentId]              = item.id_departamento,
            [CategoryId]                = item.id_categoria,
            [BrandId]                   = item.id_marca,
            [LinkId]                    = LOWER(REPLACE(REPLACE(REPLACE(REPLACE(item.descripcion, ' ', '-'), '/', '-'), '.', ''), ',', '')),
            [RefId]                     = item.referencia,
            [IsVisible]                 = CAST(1 AS BIT),
            [Description]               = item.notas,
            [DescriptionShort]          = item.descripcion,
            [ReleaseDate]               = FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss'),
            [KeyWords]                  = '',
            [Title]                     = item.descripcion,
            [IsActive]                  = CAST(1 AS BIT),
            [TaxCode]                   = '',
            [MetaTagDescription]        = '',
            [SupplierId]                = 1,
            [ShowWithoutStock]          = CAST(1 AS BIT),
            [Score]                     = 1
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ),
    [sincronizado]              = 0,
    [fecha_sincronizacion]      = GETDATE()
FROM ItemsClasificados item
LEFT JOIN [dbo].[productos] p 
    ON p.id_tienda = @id_tienda 
   AND p.referencia_producto_erp = item.referencia
WHERE p.referencia_producto_erp IS NULL;
