/* =========================================================================================
   PROYECTO: VTEX ESTÁNDAR V2
   PROCESO: 04. ESPECIFICACIONES DE SKUs / VARIANTES
   TABLA DESTINO: dbo.especificaciones_variantes
   DESCRIPCIÓN: Relaciona extensiones de variantes (Tallas, Colores) con los FieldId
                de VTEX y genera el payload para /api/catalog_system/pvt/sku/{skuId}/specification.
   ========================================================================================= */

SET NOCOUNT ON;

DECLARE @id_tienda INT = 1;
DECLARE @id_cia    INT = 1;

-- 1. Tabla de mapeo: Extensión ERP -> FieldId de Variante en VTEX
DECLARE @MapeoEspecificacionesVariantes TABLE (
    tipo_origen   VARCHAR(30)  NOT NULL, 
    codigo_origen VARCHAR(50)  NOT NULL, 
    nombre_campo  VARCHAR(100) NOT NULL,
    field_id_vtex INT          NOT NULL,
    PRIMARY KEY (tipo_origen, codigo_origen)
);

INSERT INTO @MapeoEspecificacionesVariantes (tipo_origen, codigo_origen, nombre_campo, field_id_vtex)
VALUES
    ('EXTENSION_2', 'TALLA', 'Talla', 59),
    ('EXTENSION_1', 'COLOR', 'Color', 60);

-- 2. Extracción de valores por variante
;WITH EspecificacionesVariantesExtraidas AS (
    -- Tallas (Extensión 2)
    SELECT DISTINCT
        v.id_tienda,
        v.id AS id_variante,
        v.id_variante_ecommerce,
        m.field_id_vtex,
        [valor_texto] = LTRIM(RTRIM(e2.f119_descripcion))
    FROM [dbo].[variantes] v
    INNER JOIN [UnoEE_ERP].[dbo].[t131_mc_items_barras] b 
        ON TRIM(b.f131_id) = v.sku_erp AND b.f131_id_cia = @id_cia
    INNER JOIN [UnoEE_ERP].[dbo].[t121_mc_items_extensiones] ext 
        ON ext.f121_rowid = b.f131_rowid_item_ext AND ext.f121_id_cia = @id_cia
    INNER JOIN [UnoEE_ERP].[dbo].[t119_mc_extensiones2_detalle] e2 
        ON e2.f119_id_extension2 = ext.f121_id_extension2 
       AND e2.f119_id = ext.f121_id_ext2_detalle 
       AND e2.f119_id_cia = ext.f121_id_cia
    INNER JOIN @MapeoEspecificacionesVariantes m 
        ON m.tipo_origen = 'EXTENSION_2' AND m.codigo_origen = 'TALLA'
    WHERE v.id_tienda = @id_tienda
      AND v.sincronizado = 1
      AND NULLIF(TRIM(e2.f119_descripcion), '') IS NOT NULL

    UNION ALL

    -- Colores (Extensión 1)
    SELECT DISTINCT
        v.id_tienda,
        v.id AS id_variante,
        v.id_variante_ecommerce,
        m.field_id_vtex,
        [valor_texto] = LTRIM(RTRIM(e1.f117_descripcion))
    FROM [dbo].[variantes] v
    INNER JOIN [UnoEE_ERP].[dbo].[t131_mc_items_barras] b 
        ON TRIM(b.f131_id) = v.sku_erp AND b.f131_id_cia = @id_cia
    INNER JOIN [UnoEE_ERP].[dbo].[t121_mc_items_extensiones] ext 
        ON ext.f121_rowid = b.f131_rowid_item_ext AND ext.f121_id_cia = @id_cia
    INNER JOIN [UnoEE_ERP].[dbo].[t117_mc_extensiones1_detalle] e1 
        ON e1.f117_id_extension1 = ext.f121_id_extension1 
       AND e1.f117_id = ext.f121_id_ext1_detalle 
       AND e1.f117_id_cia = ext.f121_id_cia
    INNER JOIN @MapeoEspecificacionesVariantes m 
        ON m.tipo_origen = 'EXTENSION_1' AND m.codigo_origen = 'COLOR'
    WHERE v.id_tienda = @id_tienda
      AND v.sincronizado = 1
      AND NULLIF(TRIM(e1.f117_descripcion), '') IS NOT NULL
)
-- 3. Inserción evitando duplicados
INSERT INTO [dbo].[especificaciones_variantes]
(
    [id_tienda],
    [id_variante],
    [id_variante_ecommerce],
    [especificacione_obj],
    [sincronizado],
    [fecha_sincronizacion]
)
SELECT DISTINCT
    [id_tienda]             = e.id_tienda,
    [id_variante]           = e.id_variante,
    [id_variante_ecommerce] = e.id_variante_ecommerce,
    [especificacione_obj]   = (
        SELECT 
            [FieldId] = e.field_id_vtex,
            [Text]    = e.valor_texto
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ),
    [sincronizado]          = 0,
    [fecha_sincronizacion]  = GETDATE()
FROM EspecificacionesVariantesExtraidas e
WHERE NOT EXISTS (
    SELECT 1 
    FROM [dbo].[especificaciones_variantes] ev 
    WHERE ev.id_variante = e.id_variante 
      AND JSON_VALUE(ev.especificacione_obj, '$.FieldId') = CAST(e.field_id_vtex AS VARCHAR(20))
      AND JSON_VALUE(ev.especificacione_obj, '$.Text') = e.valor_texto
);
