/* =========================================================================================
   PROYECTO: VTEX V2 - ORTOPÉDICOS FUTURO
   ARCHIVO: Insertar_Especificaciones.sql
   DESCRIPCIÓN: Inserta especificaciones de productos y variantes en las tablas 
                `especificaciones_productos` y `especificaciones_variantes`.
                Incluye tablas de mapeo `@MapeoEspecificaciones` y `@MapeoEspecificacionesVariantes`
                para relacionar cualquier campo del ERP con su FieldId de VTEX.
   ========================================================================================= */

SET NOCOUNT ON;

-- =========================================================================================
-- PASO 0: TABLAS DE MAPEO ERP -> FIELD ID VTEX (EDITAR / AGREGAR CAMPOS AQUÍ)
-- =========================================================================================

-- A. MAPEO DE ESPECIFICACIONES DE PRODUCTO
DECLARE @MapeoEspecificaciones TABLE (
    tipo_origen       VARCHAR(30)  NOT NULL, 
    codigo_origen     VARCHAR(50)  NOT NULL, 
    nombre_campo_erp  VARCHAR(100) NOT NULL, 
    field_id_vtex     INT          NOT NULL, 
    PRIMARY KEY (tipo_origen, codigo_origen)
);

INSERT INTO @MapeoEspecificaciones (tipo_origen, codigo_origen, nombre_campo_erp, field_id_vtex)
VALUES
    -- 1. Registro INVIMA (FieldId 85 en VTEX)
    ('ENTIDAD',             'texto_reg_invima',    'Registro Invima',              85),

    -- 2. Dimensiones del Empaque (FieldId 79 en VTEX)
    ('DIMENSIONES_EMPAQUE', 'DIMENSIONES_EMPAQUE', 'Dimensiones Empaque Cm',       79)

    -- 3. Descripciones Técnicas (si se requieren):
    -- ('DESCRIPCION_TECNICA', 'REGISTRO SANITARIO',  'Registro Sanitario (Ficha)',   85),
    -- ('DESCRIPCION_TECNICA', 'PRINCIPIO ACTIVO',   'Principio Activo',            100),
    -- ('DESCRIPCION_TECNICA', 'COLOR',              'Color',                       101),

    -- 4. Criterios de Ítems (descomentar y asignar FieldId según se requiera):
    -- ('CRITERIO',            '001',                 'Línea',                        86),
    -- ('CRITERIO',            '002',                 'Grupo',                        87),
    -- ('CRITERIO',            '003',                 'Registro Sanitario (Criterio)',88),
    -- ('CRITERIO',            '004',                 'Modalidad de Producto',        89),
    -- ('CRITERIO',            '014',                 'País de Origen',               90),
    -- ('CRITERIO',            '011',                 'Requiere Fórmula Médica',      91),
    -- ('CRITERIO',            '012',                 'Regulados Farmacia',           92),
    -- ('CRITERIO',            'C01',                 'Categoría 1',                  93),
    -- ('CRITERIO',            'C02',                 'Categoría 2',                  94),
    -- ('CRITERIO',            'C03',                 'Categoría 3',                  95),
    -- ('CRITERIO',            'C04',                 'Categoría 4',                  96),
    -- ('CRITERIO',            'CC2',                 'Categoría Comercial 2',        97),
    -- ('CRITERIO',            'PM',                  'Unidad Medida PUM',            98),
    -- ('CRITERIO',            'PF',                  'Factor Medida PUM',            99)
;

-- B. MAPEO DE ESPECIFICACIONES DE VARIANTE / SKU
DECLARE @MapeoEspecificacionesVariantes TABLE (
    tipo_origen       VARCHAR(30)  NOT NULL, 
    codigo_origen     VARCHAR(50)  NOT NULL, 
    nombre_campo_erp  VARCHAR(100) NOT NULL, 
    field_id_vtex     INT          NOT NULL, 
    PRIMARY KEY (tipo_origen, codigo_origen)
);

INSERT INTO @MapeoEspecificacionesVariantes (tipo_origen, codigo_origen, nombre_campo_erp, field_id_vtex)
VALUES
    -- 1. Talla (FieldId 59 en VTEX)
    ('EXTENSION_2',         'TALLA',                  'Talla (Extensión 2)',          59),
    ('DESCRIPCION_TECNICA', 'TALLA',                  'Talla (Ficha Técnica)',        59)

    -- Otras especificaciones de SKU si se asignan en VTEX:
    -- ('EXTENSION_1',         'COLOR',                  'Color (Extensión 1)',          60),
    -- ('UNIDAD_MEDIDA',       'PRESENTACION_COMERCIAL', 'Presentación Comercial',       61),
    -- ('CRITERIO',            'PM',                     'Presentación PUM',             62)
;

-- =========================================================================================
-- 1. ESPECIFICACIONES DE PRODUCTO (`especificaciones_productos`)
-- =========================================================================================

WITH especificaciones_extraidas AS (
    -- 1.1 Origen: Atributos / Entidades del ERP (a nivel de SKU/Variante y a nivel de Ítem Padre)
    SELECT DISTINCT
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        m.field_id_vtex,
        LTRIM(RTRIM(c.f753_dato_texto)) AS valor_texto
    FROM [dbo].[productos] p
    INNER JOIN [dbo].[variantes] v
        ON v.id_producto_ecommerce = p.id_producto_ecommerce
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras] b 
        ON TRIM(b.f131_id) = v.sku_erp COLLATE DATABASE_DEFAULT
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t121_mc_items_extensiones] ext 
        ON ext.f121_rowid = b.f131_rowid_item_ext
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items] t120 
        ON t120.f120_rowid = ext.f121_rowid_item
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna] c
        ON c.f753_rowid_movto_entidad = t120.f120_rowid_movto_entidad
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] a
        ON a.f743_rowid = c.f753_rowid_entidad_atributo
    INNER JOIN @MapeoEspecificaciones m
        ON  m.tipo_origen   = 'ENTIDAD'
        AND m.codigo_origen = a.f743_id
    WHERE 
        p.id_tienda = 1
        AND p.sincronizado = 1
        AND NULLIF(TRIM(c.f753_dato_texto), '') IS NOT NULL

    UNION

    SELECT DISTINCT
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        m.field_id_vtex,
        LTRIM(RTRIM(c.f753_dato_texto)) AS valor_texto
    FROM [dbo].[productos] p
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items] t120 
        ON TRIM(t120.f120_referencia) = p.referencia_producto_erp COLLATE DATABASE_DEFAULT
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna] c
        ON c.f753_rowid_movto_entidad = t120.f120_rowid_movto_entidad
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] a
        ON a.f743_rowid = c.f753_rowid_entidad_atributo
    INNER JOIN @MapeoEspecificaciones m
        ON  m.tipo_origen   = 'ENTIDAD'
        AND m.codigo_origen = a.f743_id
    WHERE 
        p.id_tienda = 1
        AND p.sincronizado = 1
        AND NULLIF(TRIM(c.f753_dato_texto), '') IS NOT NULL

    UNION ALL

    -- 1.2 Origen: Dimensiones del Empaque (Num_Largo, Num_Ancho, Num_Alto)
    SELECT DISTINCT
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        m.field_id_vtex,
        CONCAT(
            'Largo ',
            CAST(CAST(MAX(CASE WHEN a.f743_id = 'Num_Largo' THEN c.f753_dato_numero END) AS DECIMAL(18,2)) AS VARCHAR), ' cm x Ancho ',
            CAST(CAST(MAX(CASE WHEN a.f743_id = 'Num_Ancho' THEN c.f753_dato_numero END) AS DECIMAL(18,2)) AS VARCHAR), ' cm x Alto ',
            CAST(CAST(MAX(CASE WHEN a.f743_id = 'Num_Alto'  THEN c.f753_dato_numero END) AS DECIMAL(18,2)) AS VARCHAR), ' cm'
        ) AS valor_texto
    FROM [dbo].[productos] p
    INNER JOIN [dbo].[variantes] v
        ON v.id_producto_ecommerce = p.id_producto_ecommerce
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras] b 
        ON TRIM(b.f131_id) = v.sku_erp COLLATE DATABASE_DEFAULT
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t121_mc_items_extensiones] ext 
        ON ext.f121_rowid = b.f131_rowid_item_ext
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items] t120 
        ON t120.f120_rowid = ext.f121_rowid_item
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna] c
        ON c.f753_rowid_movto_entidad = t120.f120_rowid_movto_entidad
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] a
        ON a.f743_rowid = c.f753_rowid_entidad_atributo
    INNER JOIN @MapeoEspecificaciones m
        ON  m.tipo_origen   = 'DIMENSIONES_EMPAQUE'
    WHERE 
        p.id_tienda = 1
        AND p.sincronizado = 1
        AND a.f743_id IN ('Num_Largo', 'Num_Ancho', 'Num_Alto')
        AND c.f753_dato_numero > 0
    GROUP BY 
        p.id_tienda,
        p.id,
        p.id_producto_ecommerce,
        m.field_id_vtex
    HAVING 
        MAX(CASE WHEN a.f743_id = 'Num_Largo' THEN c.f753_dato_numero END) > 0
        AND MAX(CASE WHEN a.f743_id = 'Num_Ancho' THEN c.f753_dato_numero END) > 0
        AND MAX(CASE WHEN a.f743_id = 'Num_Alto'  THEN c.f753_dato_numero END) > 0

    UNION

    SELECT DISTINCT
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        m.field_id_vtex,
        CONCAT(
            'Largo ',
            CAST(
                CAST(
                    MAX(
                        CASE WHEN a.f743_id = 'Num_Largo' THEN c.f753_dato_numero END
                    ) AS DECIMAL(18,2)
                ) AS VARCHAR
            ), 
            ' cm x Ancho ',
            CAST(CAST(MAX(CASE WHEN a.f743_id = 'Num_Ancho' THEN c.f753_dato_numero END) AS DECIMAL(18,2)) AS VARCHAR), ' cm x Alto ',
            CAST(CAST(MAX(CASE WHEN a.f743_id = 'Num_Alto'  THEN c.f753_dato_numero END) AS DECIMAL(18,2)) AS VARCHAR), ' cm'
        ) AS valor_texto
    FROM [dbo].[productos] p
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items] t120 
        ON TRIM(t120.f120_referencia) = p.referencia_producto_erp COLLATE DATABASE_DEFAULT
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna] c
        ON c.f753_rowid_movto_entidad = t120.f120_rowid_movto_entidad
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] a
        ON a.f743_rowid = c.f753_rowid_entidad_atributo
    INNER JOIN @MapeoEspecificaciones m
        ON  m.tipo_origen   = 'DIMENSIONES_EMPAQUE'
    WHERE 
        p.id_tienda = 1
        AND p.sincronizado = 1
        AND a.f743_id IN ('Num_Largo', 'Num_Ancho', 'Num_Alto')
        AND c.f753_dato_numero > 0
    GROUP BY 
        p.id_tienda,
        p.id,
        p.id_producto_ecommerce,
        m.field_id_vtex
    HAVING 
        MAX(CASE WHEN a.f743_id = 'Num_Largo' THEN c.f753_dato_numero END) > 0
        AND MAX(CASE WHEN a.f743_id = 'Num_Ancho' THEN c.f753_dato_numero END) > 0
        AND MAX(CASE WHEN a.f743_id = 'Num_Alto'  THEN c.f753_dato_numero END) > 0

    UNION ALL

    -- 1.3 Origen: Fichas / Descripciones Técnicas del ERP (REGISTRO SANITARIO, COLOR, etc.)
    SELECT DISTINCT
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        m.field_id_vtex,
        LTRIM(RTRIM(dt.f123_dato)) AS valor_texto
    FROM [dbo].[productos] p
    INNER JOIN [dbo].[variantes] v
        ON v.id_producto_ecommerce = p.id_producto_ecommerce
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras] b 
        ON TRIM(b.f131_id) = v.sku_erp COLLATE DATABASE_DEFAULT
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t121_mc_items_extensiones] ext 
        ON ext.f121_rowid = b.f131_rowid_item_ext
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items] t120 
        ON t120.f120_rowid = ext.f121_rowid_item
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t123_mc_items_desc_tecnicas] dt 
        ON dt.f123_rowid_item = t120.f120_rowid
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t104_mc_desc_tecnicas_campos] c 
        ON c.f104_rowid = dt.f123_rowid_campo
        AND c.f104_id_cia = 1
    INNER JOIN @MapeoEspecificaciones m
        ON  m.tipo_origen   = 'DESCRIPCION_TECNICA'
        AND m.codigo_origen = c.f104_id
    WHERE 
        p.id_tienda = 1
        AND p.sincronizado = 1
        AND NULLIF(TRIM(dt.f123_dato), '') IS NOT NULL

    UNION ALL

    -- 1.4 Origen: Criterios del ERP
    SELECT DISTINCT
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        m.field_id_vtex,
        LTRIM(RTRIM(t106.f106_descripcion)) AS valor_texto
    FROM [dbo].[productos] p
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items] t120 
        ON TRIM(t120.f120_referencia) = p.referencia_producto_erp COLLATE DATABASE_DEFAULT
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] t125 
        ON t125.f125_rowid_item = t120.f120_rowid
        AND t125.f125_id_cia    = 1
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores] t106 
        ON  t106.f106_id_cia   = t125.f125_id_cia 
        AND t106.f106_id_plan  = t125.f125_id_plan 
        AND t106.f106_id       = t125.f125_id_criterio_mayor 
    INNER JOIN @MapeoEspecificaciones m
        ON  m.tipo_origen   = 'CRITERIO'
        AND m.codigo_origen = t125.f125_id_plan
    WHERE 
        p.id_tienda = 1
        AND p.sincronizado = 1
        AND t106.f106_descripcion NOT IN ('No', 'No Aplica', 'N/A', 'VACIO ACTUALIZAR')
        AND NULLIF(TRIM(t106.f106_descripcion), '') IS NOT NULL
)
/*
INSERT INTO [dbo].[especificaciones_productos] (
    id_tienda, 
    id_producto, 
    id_producto_ecommerce, 
    especificacione_obj, 
    sincronizado, 
    fecha_sincronizacion
)
*/
SELECT DISTINCT
    [id_tienda]             = e.id_tienda,
    [id_producto]           = e.id_producto,
    [id_producto_ecommerce] = e.id_producto_ecommerce,
    [especificacione_obj]   = 
        (
            SELECT 
                [FieldId] = e.field_id_vtex,
                [Text]    = e.valor_texto
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
    [sincronizado]          = 0,
    [fecha_sincronizacion]  = GETDATE()
FROM especificaciones_extraidas e
WHERE NOT EXISTS (
    SELECT 1 
    FROM [dbo].[especificaciones_productos] ep 
    WHERE ep.id_producto = e.id_producto 
      AND JSON_VALUE(ep.especificacione_obj, '$.FieldId') = CAST(e.field_id_vtex AS VARCHAR(20))
      AND JSON_VALUE(ep.especificacione_obj, '$.Text') = e.valor_texto
);

-- =========================================================================================
-- 2. ESPECIFICACIONES DE VARIANTE / SKU (`especificaciones_variantes`)
-- =========================================================================================

WITH especificaciones_variantes_extraidas AS (
    -- 2.1 Origen: Extensión 2 del Ítem (Talla)
    SELECT DISTINCT
        v.id_tienda,
        v.id AS id_variante,
        v.id_variante_ecommerce,
        m.field_id_vtex,
        LTRIM(RTRIM(ext.f121_id_ext2_detalle)) AS valor_texto
    FROM [dbo].[variantes] v
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras] b 
        ON TRIM(b.f131_id) = v.sku_erp COLLATE DATABASE_DEFAULT
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t121_mc_items_extensiones] ext 
        ON ext.f121_rowid = b.f131_rowid_item_ext
    INNER JOIN @MapeoEspecificacionesVariantes m
        ON  m.tipo_origen   = 'EXTENSION_2'
        AND m.codigo_origen = 'TALLA'
    WHERE 
        v.id_tienda = 1
        AND v.sincronizado = 1
        AND NULLIF(TRIM(ext.f121_id_ext2_detalle), '') IS NOT NULL

    UNION

    -- 2.2 Origen: Ficha / Descripción Técnica del Ítem (Talla)
    SELECT DISTINCT
        v.id_tienda,
        v.id AS id_variante,
        v.id_variante_ecommerce,
        m.field_id_vtex,
        LTRIM(RTRIM(dt.f123_dato)) AS valor_texto
    FROM [dbo].[variantes] v
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras] b 
        ON TRIM(b.f131_id) = v.sku_erp COLLATE DATABASE_DEFAULT
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t121_mc_items_extensiones] ext 
        ON ext.f121_rowid = b.f131_rowid_item_ext
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items] t120 
        ON t120.f120_rowid = ext.f121_rowid_item
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t123_mc_items_desc_tecnicas] dt 
        ON dt.f123_rowid_item = t120.f120_rowid
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t104_mc_desc_tecnicas_campos] c 
        ON c.f104_rowid = dt.f123_rowid_campo
        AND c.f104_id_cia = 1
    INNER JOIN @MapeoEspecificacionesVariantes m
        ON  m.tipo_origen   = 'DESCRIPCION_TECNICA'
        AND m.codigo_origen = c.f104_id
    WHERE 
        v.id_tienda = 1
        AND v.sincronizado = 1
        AND NULLIF(TRIM(dt.f123_dato), '') IS NOT NULL
)
/*
INSERT INTO [dbo].[especificaciones_variantes] (
    id_tienda, 
    id_variante, 
    id_variante_ecommerce, 
    especificacion_obj, 
    sincronizado, 
    fecha_sincronizacion
)*/
SELECT DISTINCT
    [id_tienda]             = e.id_tienda,
    [id_variante]           = e.id_variante,
    [id_variante_ecommerce] = e.id_variante_ecommerce,
    [especificacion_obj]    = 
        (
            SELECT 
                [FieldId] = e.field_id_vtex,
                [Text]    = e.valor_texto
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
    [sincronizado]          = 0,
    [fecha_sincronizacion]  = GETDATE()
FROM especificaciones_variantes_extraidas e
WHERE NOT EXISTS (
    SELECT 1 
    FROM [dbo].[especificaciones_variantes] ev 
    WHERE ev.id_variante = e.id_variante 
      AND JSON_VALUE(ev.especificacion_obj, '$.FieldId') = CAST(e.field_id_vtex AS VARCHAR(20))
      AND JSON_VALUE(ev.especificacion_obj, '$.Text') = e.valor_texto
);