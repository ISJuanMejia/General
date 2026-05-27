INSERT INTO [dbo].[productos] (
    id_tienda,
    referencia_producto_erp,
    id_producto_ecommerce,
    producto_obj,
    sincronizado,
    fecha_sincronizacion
)
SELECT DISTINCT 
    id_tienda   =   '1',
    referencia_producto_erp =   f120_referencia,
    id_producto_ecommerce   =   0,
    producto_obj    =
        JSON_QUERY(
            CONCAT(
                '{',
                '"Name":"'
                , STRING_ESCAPE(
                    UPPER(
                        LEFT(
                            cmitems_descripcion
                            ,1
                        )
                    ) + LOWER(
                        SUBSTRING(
                            cmitems_descripcion, 
                            2, 
                            LEN(cmitems_descripcion)
                        )
                    ) + ' Para ' + UPPER(
                        LEFT(
                            REPLACE(
                                REPLACE(
                                    cmitems_GENERO, 
                                    'MASCULINO', 
                                    'Hombre'
                                ), 
                                'FEMENINO', 
                                'Mujer'
                            )
                            , 1
                        )
                    ) + LOWER(
                        SUBSTRING(
                            REPLACE(
                                REPLACE(
                                    cmitems_GENERO, 
                                    'MASCULINO', 
                                    'Hombre'
                                ),
                                'FEMENINO', 
                                'Mujer'
                            ), 
                            2, 
                            LEN(cmitems_GENERO)
                        )
                    ) + ' ' + UPPER(
                        LEFT(
                            cmitems_MARCA, 
                            1
                        )
                    ) + LOWER(
                        SUBSTRING(
                            cmitems_MARCA, 
                            2, 
                            LEN(cmitems_MARCA)
                        )
                    ), 
                    'json'
                ), 
                '",', 
                '"DepartmentId":', 
                Departamentos.Chopper, 
                ',', 
                '"CategoryId":', 
                Categorias.Chopper, 
                ',', 
                '"BrandId":', 
                Marcas.Chopper, 
                ',', 
                '"LinkId":"', 
                STRING_ESCAPE(
                    LOWER(cmitems_descripcion) + ' para ' + LOWER(
                        REPLACE(
                            REPLACE(
                                cmitems_GENERO, 
                                'MASCULINO', 
                                'HOMBRE'
                            ), 
                            'FEMENINO', 
                            'MUJER'
                        )
                    ) + ' ' + LOWER(cmitems_MARCA) + ' ' + LOWER(f120_referencia COLLATE DATABASE_DEFAULT), 
                    'json'
                ), 
                '",', 
                '"RefId":"', 
                STRING_ESCAPE(f120_referencia, 'json'), 
                '",', 
                '"IsVisible":true,', 
                '"Description":"', 
                STRING_ESCAPE(
                    LOWER(cmitems_descripcion) + ' para ' + LOWER(
                        REPLACE(
                            REPLACE(
                                cmitems_GENERO, 
                                'MASCULINO', 
                                'HOMBRE'
                            ), 
                            'FEMENINO', 
                            'MUJER'
                        )
                    ) + ' ' + LOWER(cmitems_MARCA) + ', La Prenda Ideal Para Combinar Con Tus Looks. Compra Ahora En Pilatos.Com',
                    'json'
                ), 
                '",', 
                '"DescriptionShort":"', 
                STRING_ESCAPE(
                    LEFT(
                        LOWER(cmitems_descripcion), 
                        50
                    ),
                    'json'
                ), 
                '",',
                '"ReleaseDate":"', 
                FORMAT(
                    GETDATE(), 
                    'yyyy-MM-ddTHH:mm:ss'
                ), 
                '",',
                '"KeyWords":"', 
                STRING_ESCAPE(
                    LOWER(cmitems_descripcion) + ',' + LOWER(cmitems_GENERO) + ',' + LOWER(cmitems_MARCA),
                    'json'
                ), 
                '",',
                '"Title":"', 
                STRING_ESCAPE(
                    UPPER(cmitems_descripcion), 
                    'json'
                ), 
                '",',
                '"IsActive":true,',
                '"TaxCode":"', 
                STRING_ESCAPE(
                    ISNULL(
                        f120_id_grupo_impositivo, 
                        ''
                    ), 
                    'json'
                ), 
                '",',
                '"MetaTagDescription":"', 
                STRING_ESCAPE(
                    LOWER(cmitems_descripcion) + ', La Prenda Ideal Para Combinar Con Tus Looks. Compra Ahora En Pilatos.Com',
                    'json'
                ), 
                '",',
                '"SupplierId":1,',
                '"ShowWithoutStock":false,',
                '"AdWordsRemarketingCode":null,',
                '"LomadeeCampaignCode":null,',
                '"Score":1',
                '}'
            )
        ),
    sincronizado    =   0,
    fecha_sincronizacion    =   GETDATE() 
FROM (
    SELECT 
        f120_id,
        f120_rowid AS f120_rowid_item,
        f120_id_grupo_impositivo,
        RTRIM(LTRIM(f120_referencia)) AS f120_referencia,
        RTRIM(LTRIM(f120_descripcion)) AS f120_descripcion,
        RTRIM(LTRIM(f106_id)) AS f106_id,
        f125_id_plan AS f125_id
    FROM EDMERPDB.unoee.dbo.t105_mc_criterios_item_planes
        INNER JOIN EDMERPDB.unoee.dbo.t106_mc_criterios_item_mayores
            ON
                f105_id_cia = f106_id_cia
                AND
                f105_id = f106_id_plan
        INNER JOIN EDMERPDB.unoee.dbo.t125_mc_items_criterios
            ON
                f106_id_cia = f125_id_cia
                AND
                f106_id_plan = f125_id_plan
                AND
                f106_id = f125_id_criterio_mayor
        INNER JOIN EDMERPDB.unoee.dbo.t120_mc_items
            ON
                f125_rowid_item = f120_rowid
        LEFT JOIN productos
            ON
                productos.referencia_producto_erp = t120_mc_items.f120_referencia COLLATE DATABASE_DEFAULT
                AND
                productos.id_tienda = 1
    WHERE
        f120_id_cia = 1  
        AND
        f105_descripcion IN ('ES ECOMMERCE?', 'CATEGORIA', 'MARCA', 'GENERO')
        AND
        productos.referencia_producto_erp IS NULL
) Criterios
PIVOT (MAX(f106_id) FOR f125_id IN ([014],[009],[003],[010])) AS FormatoPivotCriterios
    INNER JOIN [data_reporting].[comercial].[cmitems_120] 
        ON
            cmitems_referencia_k2 = f120_referencia COLLATE DATABASE_DEFAULT
    INNER JOIN [Integracion-VTEX-Portal].[dbo].[Departamentos] AS Departamentos
        ON 
            Departamentos.CodigoERP = [010]
    INNER JOIN [Integracion-VTEX-Portal].[dbo].[Categorias] AS Categorias
        ON
            Categorias.CodigoGeneroERP = [010]
            AND
            Categorias.CodigoCategoriaERP = [009]
    INNER JOIN [Integracion-VTEX-Portal].[dbo].[Marcas] AS Marcas
        ON
            Marcas.CodigoERP = [003]
WHERE
    [014] LIKE '%SI%'
    AND 
    [009] IS NOT NULL
    AND
    [003] IS NOT NULL
    AND
    [010] IS NOT NULL
    AND 
    (
        cmitems_MARCA LIKE '%PILATOS%'
        OR
        cmitems_MARCA LIKE '%DIESEL%'
        OR
        cmitems_MARCA LIKE '%GIRBAUD%'
        OR
        cmitems_MARCA LIKE '%SUPERDRY%'
        OR
        cmitems_MARCA LIKE '%KIPLING%'
        OR
        cmitems_MARCA LIKE '%NEW BALANCE%'
        OR
        cmitems_MARCA LIKE '%REPLAY%'
    )
    AND
    Departamentos.Chopper <> ''
    AND
    Categorias.Chopper <> ''
    AND 
    Marcas.Chopper <> '';