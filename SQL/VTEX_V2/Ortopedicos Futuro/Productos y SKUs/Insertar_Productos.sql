/* =========================================================================================
   PROYECTO: VTEX V2 - ORTOPÉDICOS FUTURO
   ARCHIVO: Insertar_Productos.sql (MODO PRUEBA / SELECT)
   DESCRIPCIÓN: Consulta de productos para VTEX obteniendo información de SIESA ERP
                cumpliendo la Historia de Usuario (Filtro por f120_ind_estado = 1).
   ========================================================================================= */

DECLARE @entidades_atributos_descripcion_web TABLE (
    f753_rowid_movto_entidad INT,
    entidad_atributo_dato    NVARCHAR(255)
);

-- Cargar Atributo: Descripción Web
INSERT INTO @entidades_atributos_descripcion_web (f753_rowid_movto_entidad, entidad_atributo_dato)
SELECT f753_rowid_movto_entidad, f753_dato_texto
FROM [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna]
INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] ON f743_rowid = f753_rowid_entidad_atributo
WHERE f743_id = 'texto_des_web' AND NULLIF(TRIM(f753_dato_texto), '') IS NOT NULL;

-- -----------------------------------------------------------------------------------------
-- CONSULTA DE PRODUCTOS QUE SE INSERTARÍAN (SELECT SIN INSERT)
-- -----------------------------------------------------------------------------------------
SELECT DISTINCT
    [id_tienda]                 = 1,
    [referencia_producto_erp]   = TRIM(i.f120_referencia),
    [id_producto_ecommerce]     = 0,
    [sincronizado]              = 0,
    [fecha_sincronizacion]      = GETDATE(),
    [producto_obj]              =
        (
            SELECT
                [Name]                      = TRIM(eadw.entidad_atributo_dato),
                [DepartmentId]              = CAST(departament.f106_id AS INT),
                [CategoryId]                = CAST(category.f106_id AS INT),
                [BrandId]                   = CAST(brand.f106_id AS INT),
                [LinkId]                    = 
                    STRING_ESCAPE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(
                                        REPLACE(
                                            REPLACE(
                                                LOWER(ISNULL(TRIM(eadw.entidad_atributo_dato), '')), 
                                                '/', '-'
                                            ), ' ', '-'
                                        ), ',', ''
                                    ), '.', ''
                                ), '(', ''
                            ), ')', ''
                        ), 
                        'json'
                    ),
                [RefId]                     = TRIM(i.f120_referencia),
                [IsVisible]                 = CAST(1 AS BIT), -- Habilitado visible según HU
                [Description]               = TRIM(eadw.entidad_atributo_dato),
                [DescriptionShort]          = TRIM(eadw.entidad_atributo_dato),
                [ReleaseDate]               = FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss'),
                [Keywords]                  = '',
                [Title]                     = TRIM(eadw.entidad_atributo_dato),
                [IsActive]                  = CASE WHEN i.f120_ind_estado = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
                [TaxCode]                   = '',
                [MetaTagDescription]        = '',
                [SupplierId]                = NULL,
                [ShowWithoutStock]          = CAST(1 AS BIT),
                [AdWordsRemarketingCode]    = NULL,
                [LomadeeCampaignCode]       = NULL,
                [Score]                     = 0
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
FROM [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items] i
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t121_mc_items_extensiones] ext ON i.f120_rowid = ext.f121_rowid_item
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras] barras ON barras.f131_rowid_item_ext = ext.f121_rowid
    INNER JOIN @entidades_atributos_descripcion_web eadw ON eadw.f753_rowid_movto_entidad = i.f120_rowid_movto_entidad
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_departament ON i.f120_rowid = criterios_departament.f125_rowid_item
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores] departament ON departament.f106_id_plan = criterios_departament.f125_id_plan AND departament.f106_id = criterios_departament.f125_id_criterio_mayor
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_category ON i.f120_rowid = criterios_category.f125_rowid_item
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores] category ON category.f106_id_plan = criterios_category.f125_id_plan AND category.f106_id = criterios_category.f125_id_criterio_mayor
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_brand ON i.f120_rowid = criterios_brand.f125_rowid_item
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores] brand ON brand.f106_id_plan = criterios_brand.f125_id_plan AND brand.f106_id = criterios_brand.f125_id_criterio_mayor
    LEFT JOIN [dbo].[productos] p ON p.referencia_producto_erp = TRIM(i.f120_referencia)
WHERE
    i.f120_ind_estado = 1 -- Regla HU: Solo ítems activos en SIESA
    AND criterios_departament.f125_id_plan = 'DPC'
    AND criterios_category.f125_id_plan    = 'CC1'
    AND criterios_brand.f125_id_plan       = '005'
    AND p.referencia_producto_erp IS NULL;
