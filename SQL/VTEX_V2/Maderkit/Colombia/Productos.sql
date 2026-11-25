WITH RawData AS
(
    SELECT
        *,
        STRING_ESCAPE(REPLACE(ISNULL(LEFT(Name, 150), ''), '/', '-'), 'json') AS Nombre_Comercial_Clean,
        TRY_CAST(TRIM(Departamento) AS INT) AS Department_Clean,
        TRY_CAST(TRIM(Categoria) AS INT) AS Category_Clean,
        CAST(Marca AS NUMERIC) AS Marca_Clean,
        FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss') AS Fecha_Release_Clean,
        STRING_ESCAPE(TRIM(ISNULL(f120_referencia, '')), 'json') AS Referencia_Clean,
        TRIM(
            CASE 
                WHEN CHARINDEX('-', f120_referencia) > 0 
                THEN LEFT(f120_referencia, CHARINDEX('-', f120_referencia) - 1)
                ELSE f120_referencia
            END
        ) AS Referencia_Padre_Maderkit
    --select * 
    FROM OPENROWSET
    (
    'SQLNCLI11',
    'Server=siesa-m3-sqlsw-db13.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_Maderkit_Real;UID=maderkit;PWD=Maderkit$12$%;',
    '
    SELECT DISTINCT
        f120_id,
        f120_referencia,
        f120_descripcion AS Name,
        MAX(CASE WHEN t125.f125_id_plan = ''002'' THEN t125.f125_id_criterio_mayor END) AS Departamento,
        MAX(CASE WHEN t125.f125_id_plan = ''003'' THEN t125.f125_id_criterio_mayor END) AS Categoria,
        ''1'' AS Marca
    FROM t120_mc_items i
    INNER JOIN t125_mc_items_criterios vtex  ON vtex.f125_rowid_item = f120_rowid AND vtex.f125_id_plan = ''015''  
    AND vtex.f125_id_criterio_mayor = ''1''
    AND vtex.f125_id_criterio_mayor IS NOT NULL
    LEFT JOIN t125_mc_items_criterios t125  ON t125.f125_rowid_item = f120_rowid 
    AND t125.f125_id_cia = i.f120_id_cia
    where i.f120_id_cia = ''1''
    and i.f120_referencia in (''M01842CL-FUWE'',''M01842CL-GSWE'')
    GROUP BY f120_id, f120_referencia, f120_descripcion
    '
    ) AS X
),
Base AS
(
    SELECT
        '1' AS id_tienda,
         Referencia_Padre_Maderkit AS referencia_producto_erp,   -- Usamos la referencia del padre como referencia del producto ERP
        0 AS id_producto_ecommerce,
        0 AS sincronizado,
        GETDATE() AS fecha_sincronizacion,
        Nombre_Comercial_Clean AS Name,
        1 AS DepartmentId,
        Category_Clean AS CategoryId,     
        1 AS BrandId,  
        '' AS LinkId, 
        Referencia_Padre_Maderkit AS RefId, --usamos la referencia del padre como RefId para VTEX
        CAST(0 AS BIT) AS IsVisible,
        '' AS Description, 
        '' AS DescriptionShort, 
        Fecha_Release_Clean AS ReleaseDate,
        '' AS KeyWords,
        '' AS Title,
        CAST(0 AS BIT) AS IsActive,
        '' AS TaxCode,
        '' AS MetaTagDescription,
        1 AS SupplierId,
        CAST(0 AS BIT) AS ShowWithoutStock,
        NULL AS AdWordsRemarketingCode,
        NULL AS LomadeeCampaignCode,
        1 AS Score,
        ROW_NUMBER() OVER
        (
            PARTITION BY Referencia_Padre_Maderkit
            ORDER BY 
            ISNULL(Category_Clean, 0), 
            ISNULL(Marca_Clean, 0),
            f120_id
        ) AS rn
    FROM RawData
    WHERE
        ISNULL(Name,'') <> ''
        AND ISNULL(Categoria, '') <> ''
        AND ISNULL(Marca, '') <> ''
        AND f120_referencia IS NOT NULL
        
        AND NOT EXISTS (
            SELECT 1
            FROM variantes v
            WHERE 
            REPLACE(UPPER(
            CASE 
                WHEN CHARINDEX('-', JSON_VALUE(v.variante_obj, '$.RefId')) > 0 
                THEN LEFT(JSON_VALUE(v.variante_obj, '$.RefId'), CHARINDEX('-', JSON_VALUE(v.variante_obj, '$.RefId')) - 1)
                ELSE JSON_VALUE(v.variante_obj, '$.RefId')
            END
        ), ' ', '') = REPLACE(UPPER(RawData.Referencia_Padre_Maderkit), '', '')
    )

        AND NOT EXISTS (
            SELECT 1
            FROM productos p
            WHERE REPLACE(UPPER(p.referencia_producto_erp), ' ', '') 
            = REPLACE(UPPER(RawData.Referencia_Padre_Maderkit), ' ', '')
            AND p.id_tienda = 1
    )
)

INSERT INTO [dbo].[productos]
(
    id_tienda,
    referencia_producto_erp,
    id_producto_ecommerce,
    sincronizado,
    fecha_sincronizacion,
    producto_obj
)
 
SELECT
    id_tienda,
    referencia_producto_erp,
    id_producto_ecommerce,
    sincronizado,
    fecha_sincronizacion,
    JSON_QUERY(
        (
            SELECT
                Name,
                DepartmentId,
                CategoryId,
                BrandId,
                LinkId,
                RefId,
                IsVisible,
                Description,
                DescriptionShort,
                ReleaseDate,
                KeyWords,
                Title,
                IsActive,
                TaxCode,
                MetaTagDescription,
                SupplierId,
                ShowWithoutStock,
                AdWordsRemarketingCode,
                LomadeeCampaignCode,
                Score
            FOR JSON PATH,
            WITHOUT_ARRAY_WRAPPER,
            INCLUDE_NULL_VALUES
        )
    ) AS producto_obj
FROM Base
WHERE rn = 1; 
