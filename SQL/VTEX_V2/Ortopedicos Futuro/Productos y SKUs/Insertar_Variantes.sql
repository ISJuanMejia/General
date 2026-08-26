/* =========================================================================================
   PROYECTO: VTEX V2 - ORTOPÉDICOS FUTURO
   ARCHIVO: Insertar_Variantes.sql
   DESCRIPCIÓN: Inserta SKUs/Variantes en la tabla `variantes` obteniendo datos de SIESA ERP.
   ========================================================================================= */

DECLARE @entidades_atributos_descripcion_web TABLE (
    f753_rowid_movto_entidad INT,
    entidad_atributo_dato    NVARCHAR(255)
);

DECLARE @entidades_atributos_alto TABLE (
    f753_rowid_movto_entidad INT,
    entidad_atributo_dato    NVARCHAR(100)
);

DECLARE @entidades_atributos_ancho TABLE (
    f753_rowid_movto_entidad INT,
    entidad_atributo_dato    NVARCHAR(100)
);

DECLARE @entidades_atributos_largo TABLE (
    f753_rowid_movto_entidad INT,
    entidad_atributo_dato    NVARCHAR(100)
);

DECLARE @entidades_atributos_peso TABLE (
    f753_rowid_movto_entidad INT,
    entidad_atributo_dato    NVARCHAR(100)
);

-- Cargar Atributo: Descripción Web
INSERT INTO @entidades_atributos_descripcion_web (f753_rowid_movto_entidad, entidad_atributo_dato)
SELECT f753_rowid_movto_entidad, f753_dato_texto
FROM [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna]
INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] ON f743_rowid = f753_rowid_entidad_atributo
WHERE f743_id = 'texto_des_web' AND NULLIF(TRIM(f753_dato_texto), '') IS NOT NULL;

-- Cargar Atributo: Alto (Cm Empaque)
INSERT INTO @entidades_atributos_alto (f753_rowid_movto_entidad, entidad_atributo_dato)
SELECT f753_rowid_movto_entidad, CAST(CAST(f753_dato_numero AS DECIMAL(18,2)) AS VARCHAR(20))
FROM [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna]
INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] ON f743_rowid = f753_rowid_entidad_atributo
WHERE f743_id = 'Num_Alto';

-- Cargar Atributo: Ancho (Cm Empaque)
INSERT INTO @entidades_atributos_ancho (f753_rowid_movto_entidad, entidad_atributo_dato)
SELECT f753_rowid_movto_entidad, CAST(CAST(f753_dato_numero AS DECIMAL(18,2)) AS VARCHAR(20))
FROM [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna]
INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] ON f743_rowid = f753_rowid_entidad_atributo
WHERE f743_id = 'Num_Ancho';

-- Cargar Atributo: Largo (Cm Empaque)
INSERT INTO @entidades_atributos_largo (f753_rowid_movto_entidad, entidad_atributo_dato)
SELECT f753_rowid_movto_entidad, CAST(CAST(f753_dato_numero AS DECIMAL(18,2)) AS VARCHAR(20))
FROM [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna]
INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] ON f743_rowid = f753_rowid_entidad_atributo
WHERE f743_id = 'Num_Largo';

-- Cargar Atributo: Peso (Gr Empaque)
INSERT INTO @entidades_atributos_peso (f753_rowid_movto_entidad, entidad_atributo_dato)
SELECT f753_rowid_movto_entidad, CAST(CAST(f753_dato_numero AS DECIMAL(18,2)) AS VARCHAR(20))
FROM [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna]
INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] ON f743_rowid = f753_rowid_entidad_atributo
WHERE f743_id = 'Num_Peso';

-- Inserción masiva en tabla variantes
INSERT INTO [dbo].[variantes]
(
    id_tienda,
    id_producto_ecommerce,
    id_variante_ecommerce,
    sku_erp,
    variante_obj,
    sincronizado,
    fecha_sincronizacion
)
SELECT DISTINCT
    [id_tienda]             = 1,
    [id_producto_ecommerce] = 0,
    [id_variante_ecommerce] = 0,
    [sku_erp]               = TRIM(barras.f131_id),
    [variante_obj]          = 
        (
            SELECT
                [Name]                  = TRIM(i.f120_descripcion),
                [RefId]                 = TRIM(i.f120_referencia),
                [IsActive]              = CASE WHEN i.f120_ind_estado = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
                [ActivateIfPossible]    = CASE WHEN i.f120_ind_estado = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
                [PackagedHeight]        = CAST(ISNULL(ea_alto.entidad_atributo_dato, '0') AS DECIMAL(18,2)),
                [PackagedWidth]         = CAST(ISNULL(ea_ancho.entidad_atributo_dato, '0') AS DECIMAL(18,2)),
                [PackagedLength]        = CAST(ISNULL(ea_largo.entidad_atributo_dato, '0') AS DECIMAL(18,2)),
                [PackagedWeightKg]      = CAST(ISNULL(ea_peso.entidad_atributo_dato, '0') AS DECIMAL(18,2)),
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
FROM [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items] i
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t121_mc_items_extensiones] ext
        ON i.f120_rowid = ext.f121_rowid_item
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras] barras
        ON barras.f131_rowid_item_ext = ext.f121_rowid
    LEFT JOIN @entidades_atributos_descripcion_web eadw ON eadw.f753_rowid_movto_entidad = i.f120_rowid_movto_entidad
    LEFT JOIN @entidades_atributos_alto ea_alto ON ea_alto.f753_rowid_movto_entidad = i.f120_rowid_movto_entidad
    LEFT JOIN @entidades_atributos_ancho ea_ancho ON ea_ancho.f753_rowid_movto_entidad = i.f120_rowid_movto_entidad
    LEFT JOIN @entidades_atributos_largo ea_largo ON ea_largo.f753_rowid_movto_entidad = i.f120_rowid_movto_entidad
    LEFT JOIN @entidades_atributos_peso ea_peso ON ea_peso.f753_rowid_movto_entidad = i.f120_rowid_movto_entidad
    INNER JOIN [dbo].[productos] p ON p.referencia_producto_erp = TRIM(i.f120_referencia)
WHERE
    i.f120_ind_estado = 1
    AND NOT EXISTS (
        SELECT 1 
        FROM [dbo].[variantes] v 
        WHERE v.sku_erp = TRIM(barras.f131_id)
    );
