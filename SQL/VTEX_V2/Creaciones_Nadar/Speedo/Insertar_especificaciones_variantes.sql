-- ==========================================================================================
-- Proceso: Sincronización e Inserción de Especificaciones de Color para Variantes (Speedo)
-- Base de Datos: [Connekta-Ecommerce-Vtex]
-- ==========================================================================================

-- 1. Sincronizar catálogo de colores desde UnoEE hacia VTEX-Colores
EXEC [Integracion-Nadar].[dbo].[Sp_PORTAL_MergeColores];

-- 2. Cargar únicamente especificaciones de color existentes para la tienda en una tabla temporal liviana
IF OBJECT_ID('tempdb..#Temp_Especificaciones') IS NOT NULL
    DROP TABLE #Temp_Especificaciones;

SELECT 
    id_variante_ecommerce,
    especificacion_obj
INTO #Temp_Especificaciones
FROM dbo.especificaciones_variantes
WHERE id_tienda = 1
  AND especificacion_obj LIKE '{"FieldName":"Color"%';

-- Índice clustered para acelerar la comprobación en el NOT EXISTS
CREATE CLUSTERED INDEX IDX_Temp_Especificaciones 
    ON #Temp_Especificaciones(id_variante_ecommerce);

-- 3. Generar especificaciones con JSON limpio, control de colación y filtro de valores válidos
WITH CTE_Especificaciones AS (
    SELECT DISTINCT
        v.id_tienda,
        v.id AS id_variante,
        v.id_variante_ecommerce,

        -- Generar JSON individual por variante
        (
            SELECT 
                'Color' AS FieldName,
                'Filtros' AS GroupName,
                JSON_QUERY(CONCAT('["', LTRIM(RTRIM(c.TEXT_Color)), '"]')) AS FieldValues
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS especificacion_obj,

        0 AS sincronizado,
        GETDATE() AS fecha_sincronizacion
    FROM dbo.variantes v
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].v121 
        ON v121_id_barras_principal = v.sku_erp COLLATE DATABASE_DEFAULT 
       AND v121_id_cia = 1
    INNER JOIN [Integracion-Nadar].[dbo].[VTEX-Colores] c
        ON c.codigo_unificado = (v121_id_extension1 + v121_id_ext1_detalle) COLLATE DATABASE_DEFAULT
    WHERE v.id_tienda = 1
      AND v.id_variante_ecommerce >= 5058
      AND v.fecha_sincronizacion >= DATEADD(HOUR, -48, GETDATE())
      AND c.TEXT_Color IS NOT NULL
      AND LTRIM(RTRIM(c.TEXT_Color)) <> ''
)
-- 4. Insertar registros que no existen con el mismo JSON de color
INSERT INTO dbo.especificaciones_variantes (
    id_tienda,
    id_variante,
    id_variante_ecommerce,
    especificacion_obj,
    sincronizado,
    fecha_sincronizacion
)
SELECT 
    cte.id_tienda,
    cte.id_variante,
    cte.id_variante_ecommerce,
    cte.especificacion_obj,
    cte.sincronizado,
    cte.fecha_sincronizacion
FROM CTE_Especificaciones cte
WHERE NOT EXISTS (
    SELECT 1 
    FROM #Temp_Especificaciones te
    WHERE cte.id_variante_ecommerce = te.id_variante_ecommerce
      AND LTRIM(RTRIM(cte.especificacion_obj)) COLLATE DATABASE_DEFAULT = 
          LTRIM(RTRIM(te.especificacion_obj)) COLLATE DATABASE_DEFAULT
);

-- 5. Limpieza de la tabla temporal
DROP TABLE #Temp_Especificaciones;

-- 6. Sincronizar [dbo].[colores] con toda la información de [Integracion-Nadar].[dbo].[VTEX-Colores]
MERGE [dbo].[colores] AS Destino
USING [Integracion-Nadar].[dbo].[VTEX-Colores] AS Origen
   ON (Destino.codigo_unificado = Origen.Codigo_Unificado COLLATE DATABASE_DEFAULT)
WHEN MATCHED THEN
    UPDATE SET 
        Destino.codigo            = Origen.Codigo COLLATE DATABASE_DEFAULT,
        Destino.descripcion       = Origen.Descripcion COLLATE DATABASE_DEFAULT,
        Destino.descripcion_corta = Origen.Descripcion_Corta COLLATE DATABASE_DEFAULT,
        Destino.descripcion_color = Origen.Descripcion_Color COLLATE DATABASE_DEFAULT,
        Destino.filtro_color      = Origen.Filtro_Color COLLATE DATABASE_DEFAULT,
        Destino.text_color        = Origen.TEXT_Color COLLATE DATABASE_DEFAULT
WHEN NOT MATCHED BY TARGET THEN
    INSERT (
        codigo,
        codigo_unificado,
        descripcion,
        descripcion_corta,
        descripcion_color,
        filtro_color,
        text_color
    )
    VALUES (
        Origen.Codigo,
        Origen.Codigo_Unificado,
        Origen.Descripcion,
        Origen.Descripcion_Corta,
        Origen.Descripcion_Color,
        Origen.Filtro_Color,
        Origen.TEXT_Color
    );
