/* =========================================================================================
   PROYECTO: VTEX ESTÁNDAR V2
   PROCESO: 03. ESPECIFICACIONES DE PRODUCTO
   TABLA DESTINO: dbo.especificaciones_productos
   DESCRIPCIÓN: Relaciona atributos y criterios del ERP con los FieldId de VTEX y genera
                el payload para /api/catalog_system/pvt/products/{productId}/specification.
   ========================================================================================= */

SET NOCOUNT ON;

DECLARE @id_tienda INT = 1;
DECLARE @id_cia    INT = 1;

-- 1. Tabla de mapeo: Atributo ERP -> FieldId en VTEX
DECLARE @MapeoEspecificaciones TABLE (
    tipo_origen      VARCHAR(30)  NOT NULL, 
    codigo_origen    VARCHAR(50)  NOT NULL, 
    nombre_campo     VARCHAR(100) NOT NULL,
    field_id_vtex    INT          NOT NULL,
    PRIMARY KEY (tipo_origen, codigo_origen)
);

INSERT INTO @MapeoEspecificaciones (tipo_origen, codigo_origen, nombre_campo, field_id_vtex)
VALUES
    ('ENTIDAD',   'texto_reg_invima', 'Registro INVIMA',          85),
    ('CRITERIO',  '023',              'País de Origen',           86),
    ('CRITERIO',  '014',              'Fabricante / Importador',   87),
    ('COMPONENTE','COMPOSICION',      'Composición Textil/Mat',   88);

-- 2. Consolidar especificaciones dinámicas desde múltiples orígenes ERP
;WITH EspecificacionesExtraidas AS (
    -- A. Origen: Atributos / Entidades de Ítems
    SELECT DISTINCT
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        m.field_id_vtex,
        [valor_texto] = LTRIM(RTRIM(c.f753_dato_texto))
    FROM [dbo].[productos] p
    INNER JOIN [UnoEE_ERP].[dbo].[t120_mc_items] i 
        ON TRIM(i.f120_referencia) = p.referencia_producto_erp AND i.f120_id_cia = @id_cia
    INNER JOIN [UnoEE_ERP].[dbo].[t753_mm_movto_entidad_columna] c 
        ON c.f753_rowid_movto_entidad = i.f120_rowid_movto_entidad
    INNER JOIN [UnoEE_ERP].[dbo].[t743_mm_entidad_atributo] a 
        ON a.f743_rowid = c.f753_rowid_entidad_atributo
    INNER JOIN @MapeoEspecificaciones m 
        ON m.tipo_origen = 'ENTIDAD' AND m.codigo_origen = a.f743_id
    WHERE p.id_tienda = @id_tienda
      AND p.sincronizado = 1
      AND NULLIF(TRIM(c.f753_dato_texto), '') IS NOT NULL

    UNION ALL

    -- B. Origen: Criterios Maestros del ERP
    SELECT DISTINCT
        p.id_tienda,
        p.id AS id_producto,
        p.id_producto_ecommerce,
        m.field_id_vtex,
        [valor_texto] = LTRIM(RTRIM(criterio.f106_descripcion))
    FROM [dbo].[productos] p
    INNER JOIN [UnoEE_ERP].[dbo].[t120_mc_items] i 
        ON TRIM(i.f120_referencia) = p.referencia_producto_erp AND i.f120_id_cia = @id_cia
    INNER JOIN [UnoEE_ERP].[dbo].[t125_mc_items_criterios] crit 
        ON crit.f125_rowid_item = i.f120_rowid AND crit.f125_id_cia = @id_cia
    INNER JOIN [UnoEE_ERP].[dbo].[t106_mc_criterios_item_mayores] criterio 
        ON criterio.f106_id_plan = crit.f125_id_plan 
       AND criterio.f106_id = crit.f125_id_criterio_mayor 
       AND criterio.f106_id_cia = crit.f125_id_cia
    INNER JOIN @MapeoEspecificaciones m 
        ON m.tipo_origen = 'CRITERIO' AND m.codigo_origen = crit.f125_id_plan
    WHERE p.id_tienda = @id_tienda
      AND p.sincronizado = 1
      AND criterio.f106_descripcion NOT IN ('No aplica', 'N/A', 'VACIO')
      AND NULLIF(TRIM(criterio.f106_descripcion), '') IS NOT NULL
)
-- 3. Inserción en tabla intermedia evitando duplicados
INSERT INTO [dbo].[especificaciones_productos]
(
    [id_tienda],
    [id_producto],
    [id_producto_ecommerce],
    [especificacione_obj],
    [sincronizado],
    [fecha_sincronizacion]
)
SELECT DISTINCT
    [id_tienda]             = e.id_tienda,
    [id_producto]           = e.id_producto,
    [id_producto_ecommerce] = e.id_producto_ecommerce,
    [especificacione_obj]   = (
        SELECT 
            [FieldId] = e.field_id_vtex,
            [Text]    = e.valor_texto
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ),
    [sincronizado]          = 0,
    [fecha_sincronizacion]  = GETDATE()
FROM EspecificacionesExtraidas e
WHERE NOT EXISTS (
    SELECT 1 
    FROM [dbo].[especificaciones_productos] ep 
    WHERE ep.id_producto = e.id_producto 
      AND JSON_VALUE(ep.especificacione_obj, '$.FieldId') = CAST(e.field_id_vtex AS VARCHAR(20))
      AND JSON_VALUE(ep.especificacione_obj, '$.Text') = e.valor_texto
);
