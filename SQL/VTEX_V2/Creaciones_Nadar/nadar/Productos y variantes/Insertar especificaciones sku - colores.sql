-- 1. Crear una tabla temporal con los datos actuales de especificaciones_variantes
IF OBJECT_ID('tempdb..#Temp_Especificaciones') IS NOT NULL
    DROP TABLE #Temp_Especificaciones;

SELECT * 
INTO #Temp_Especificaciones
FROM dbo.especificaciones_variantes;

-- Crear índice en la tabla temporal para mejorar el rendimiento
CREATE CLUSTERED INDEX IDX_Temp_Especificaciones 
    ON #Temp_Especificaciones(id_variante_ecommerce);

-- 2. Generar los datos en CTE para comparación (JSON uno a uno, sin espacios ni saltos)
WITH CTE_Especificaciones AS (
    SELECT 
        v.id_tienda,
        v.id AS id_variante,
        v.id_variante_ecommerce,

        -- Generar JSON limpio para cada variante
        (
            SELECT 
                'Color' AS FieldName,
                'Especificaciones' AS GroupName,
                JSON_QUERY(CONCAT('["', descripcion_color, '"]')) AS FieldValues
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS especificacion_obj,

        0 AS sincronizado,
        GETDATE() AS fecha_sincronizacion
    FROM variantes v
    INNER JOIN [LinkedtoRDS].[UnoEE_Cnadar_Real].[dbo].v121 
        ON v121_id_barras_principal = v.sku_erp COLLATE DATABASE_DEFAULT 
       AND v121_id_cia = 1
    INNER JOIN [Integracion-Nadar].[dbo].[VTEX-Colores] c
        ON c.codigo_unificado = v121_id_extension1 + v121_id_ext1_detalle
    WHERE v.id_tienda = 2
	AND v.fecha_sincronizacion >= DATEADD(HOUR, -48, GETDATE())
)
-- 3. Insertar solo registros nuevos o modificados
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

-- 4. Eliminar la tabla temporal
DROP TABLE #Temp_Especificaciones;
