/*
SELECT
    COUNT(*)
FROM t120_mc_items  AS  t120
    LEFT JOIN t101_mc_unidades_medida   AS  t101_inventario
        ON
            t120.f120_id_cia                =   t101_inventario.f101_id_cia
            AND
            t120.f120_id_unidad_inventario  =   t101_inventario.f101_id
    /*
    LEFT JOIN t101_mc_unidades_medida   AS  t101_adicional
        ON
            t120.f120_id_cia                =   t101_adicional.f101_id_cia
            AND
            t120.f120_id_unidad_adicional   =   t101_adicional.F101_id
    */
    LEFT JOIN t101_mc_unidades_medida   AS  t101_orden
        ON
            t120.f120_id_cia            =   t101_orden.f101_id_cia
            AND
            t120.f120_id_unidad_orden   =   t101_orden.F101_id
    LEFT JOIN t101_mc_unidades_medida   AS  t101_empaque
        ON
            t120.f120_id_cia            =   t101_empaque.f101_id_cia
            AND
            t120.f120_id_unidad_empaque =   t101_empaque.F101_id
    LEFT JOIN t101_mc_unidades_medida   AS  t101_precio
        ON
            t120.f120_id_cia            =   t101_precio.f101_id_cia
            AND
            t120.f120_id_unidad_precio  =   t101_precio.f101_id
    LEFT JOIN t103_mc_descripciones_tecnicas    AS  t103
        ON
            t120.f120_id_cia                    =   t103.f103_id_cia
            AND
            t120.f120_id_descripcion_tecnica    =   t103.f103_id
    INNER JOIN t121_mc_items_extensiones    AS  t121
        ON
            t120.f120_rowid =   t121.f121_rowid_item
WHERE 
    f120_id_cia   =   1
*/


-- SP_HELP t120_mc_items

/*
    *   t120_mc_items
    *       t101_mc_unidades_medida
    *           f120_id_cia                 ->  f101_id_cia, 
    *           f120_id_unidad_inventario   ->  f101_id
    *       t101_mc_unidades_medida
    *           f120_id_cia                 ->  f101_id_cia, 
    *           f120_id_unidad_adicional    ->  f101_id
    *       t101_mc_unidades_medida
    *           f120_id_cia                 ->  f101_id_cia, 
    *           f120_id_unidad_orden        ->  f101_id
    *       t101_mc_unidades_medida
    *           f120_id_cia                 ->  f101_id_cia, 
    *           f120_id_unidad_empaque      ->  f101_id
    *       t101_mc_unidades_medida
    *           f120_id_cia                 ->  f101_id_cia, 
    *           f120_id_unidad_precio       ->  f101_id
    *       t103_mc_descripciones_tecnicas
    *           f120_id_cia                 ->  f103_id_cia, 
    *           f120_id_descripcion_tecnica ->  f103_id
*/

/*
    *   t121_mc_items_extensiones
    *       t101_mc_unidades_medida
    *           f121_id_cia                     ->  f101_id_cia, 
    *           f121_id_unidad_validacion_kit   ->  f101_id
    *       t105_mc_criterios_item_planes
    *           f121_id_cia                     ->  f105_id_cia, 
    *           f121_id_plan_kit                ->  f105_id
    *       t116_mc_extensiones1
    *           f121_id_cia                     ->  f116_id_cia, 
    *           f121_id_extension1              ->  f116_id
    *       t117_mc_extensiones1_detalle
    *           f121_id_cia                     ->  f117_id_cia, 
    *           f121_id_extension1              ->  f117_id_extension1, 
    *           f121_id_ext1_detalle            ->  f117_id
    *       t118_mc_extensiones2
    *           f121_id_cia                     ->  f118_id_cia, 
    *           f121_id_extension2              ->  f118_id
    *       t119_mc_extensiones2_detalle
    *           f121_id_cia                     ->  f119_id_cia, 
    *           f121_id_extension2              ->  f119_id_extension2, 
    *           f121_id_ext2_detalle            ->  f119_id
    *       t121_mc_items_extensiones
    *           f121_rowid_item_ext_gen         ->  f121_rowid
    *       t131_mc_items_barras
    *           f121_id_cia                     ->  f131_id_cia, 
    *           f121_id_barras_principal        ->  f131_id
*/
/*
SELECT  TOP 100
    (
        SELECT
            f120_ts,
            f120_id_cia,
            f120_id,
            f120_rowid,
            f120_referencia,
            f120_descripcion,
            f120_descripcion_corta,
            f120_id_grupo_impositivo,
            f120_id_tipo_inv_serv,
            f120_id_grupo_dscto,
            f120_ind_tipo_item,
            f120_ind_compra,
            f120_ind_venta,
            f120_ind_manufactura,
            f120_ind_lista_precios_ext,
            f120_ind_lote,
            f120_ind_lote_asignacion,
            f120_ind_sobrecostos,
            f120_vida_util,
            f120_rowid_tercero_prov,
            f120_id_sucursal_prov,
            f120_rowid_tercero_cli,
            f120_id_sucursal_cli,
            f120_id_unidad_inventario   =
            (
                SELECT
                    f101_ts,
                    f101_id_cia,
                    f101_descripcion,
                    f101_decimales,
                    f101_um_gc_ic,
                    f101_ind_estado,
                    f101_ind_gum_unificado
                FROM t101_mc_unidades_medida   AS  t101_inventario
                WHERE
                    t120.f120_id_cia                =   t101_inventario.f101_id_cia
                    AND
                    t120.f120_id_unidad_inventario  =   t101_inventario.f101_id
                FOR JSON PATH
            ),
            f120_id_unidad_orden   =
            (
                SELECT
                    f101_ts,
                    f101_id_cia,
                    f101_descripcion,
                    f101_decimales,
                    f101_um_gc_ic,
                    f101_ind_estado,
                    f101_ind_gum_unificado
                FROM t101_mc_unidades_medida   AS  t101_orden
                WHERE
                    t120.f120_id_cia                =   t101_orden.f101_id_cia
                    AND
                    t120.f120_id_unidad_orden  =   t101_orden.f101_id
                FOR JSON PATH
            ),
            f120_id_unidad_empaque   =
            (
                SELECT
                    f101_ts,
                    f101_id_cia,
                    f101_descripcion,
                    f101_decimales,
                    f101_um_gc_ic,
                    f101_ind_estado,
                    f101_ind_gum_unificado
                FROM t101_mc_unidades_medida   AS  t101_empaque
                WHERE
                    t120.f120_id_cia                =   t101_empaque.f101_id_cia
                    AND
                    t120.f120_id_unidad_empaque  =   t101_empaque.f101_id
                FOR JSON PATH
            ),
            f120_id_descripcion_tecnica =
            (
                SELECT
                    f103_ts,
                    f103_id_cia,
                    f103_id,
                    f103_ind_tipo,
                    f103_descripcion,
                    f103_notas
                FROM    t103_mc_descripciones_tecnicas    AS  t103
                WHERE
                    t120.f120_id_cia                    =   t103.f103_id_cia
                    AND
                    t120.f120_id_descripcion_tecnica    =   t103.f103_id
                FOR JSON PATH
            ),
            f120_id_extension1,
            f120_id_extension2,
            f120_notas,
            f120_id_segmento_costo,
            f120_usuario_creacion,
            f120_usuario_actualizacion,
            f120_fecha_creacion,
            f120_fecha_actualizacion,
            f120_ind_serial,
            f120_id_cfg_serial,
            f120_ind_paquete,
            f120_rowid_movto_entidad,
            f120_ind_exento,
            f120_ind_venta_interno,
            f120_ind_generico,
            f120_ind_gum_unificado,
            f120_ind_controlado,
            t121_mc_items_extensiones   =
            (
                SELECT
                    f121_ts,
                    f121_id_cia,
                    f121_rowid,
                    f121_rowid_item,
                    f121_id_ext1_detalle,
                    f121_id_ext2_detalle,
                    f121_ind_estado,
                    f121_fecha_inactivacion,
                    f121_fecha_creacion,
                    f121_notas,
                    f121_usuario_inactivacion,
                    f121_usuario_creacion,
                    f121_usuario_actualizacion,
                    f121_fecha_actualizacion,
                    f121_id_extension1,
                    f121_id_extension2,
                    f121_rowid_movto_entidad,
                    f121_porc_max_exceso_kit,
                    f121_porc_min_exceso_kit,
                    f121_id_unidad_validacion_kit,
                    f121_id_barras_principal,
                    f121_id_plan_kit,
                    f121_ind_gum_unificado
                FROM    t121_mc_items_extensiones    AS  t121
                WHERE
                    t120.f120_rowid =   t121.f121_rowid_item
                FOR JSON PATH,
                INCLUDE_NULL_VALUES
            )
        FOR JSON PATH,
        INCLUDE_NULL_VALUES
    )   AS  t120
FROM t120_mc_items  AS  t120
WHERE 
    f120_id_cia   =   1
ORDER BY F120_ROWID DESC
*/

SELECT TOP 100
    [id_tienda]                 =   '1',
    [referencia_producto_erp]   =   TRIM(f120_referencia),
    [id_producto_ecommerce]     =   0,
    [producto_obj]              =   
    (
        SELECT
            [Name]                      =   TRIM(REPLACE(f120_descripcion, '  ', ' ')),
            [DepartmentId]              =   TRIM(t125_criterios_department_id.f125_id_criterio_mayor),
            [CategoryId]                =   '',
            [BrandId]                   =   '',
            [LinkId]                    =   CONCAT(TRIM(f120_descripcion), '-', TRIM(f120_referencia)),
            [RefId]                     =   TRIM(f120_referencia),
            [IsVisible]                 =   CAST(1 AS BIT),
            [Description]               =   '',
            [DescriptionShort]          =   '',
            [ReleaseDate]               =   '',
            [KeyWords]                  =   '',
            [Title]                     =   '',
            [IsActive]                  =   CAST(1 AS BIT),
            [TaxCode]                   =   '',
            [MetaTagDescription]        =   '',
            [SupplierId]                =   1,
            [ShowWithoutStock]          =   CAST(1 AS BIT),
            [AdWordsRemarketingCode]    =   NULL,
            [LomadeeCampaignCode]       =   NULL,
            [Score]                     =   1
        FROM    [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items]   AS  t120_pobj
        WHERE
            t120_pobj.f120_rowid    =   t120.f120_rowid
        FOR JSON PATH, 
        INCLUDE_NULL_VALUES, 
        WITHOUT_ARRAY_WRAPPER
    ),
    sincronizado                =   0,
    fecha_sincronizacion        =   GETDATE()
FROM    [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items]   AS  t120
    LEFT JOIN  productos
        ON
            referencia_producto_erp =   TRIM(f120_referencia)
    INNER JOIN  UnoEE_PruebasProyectosCol.dbo.t125_mc_items_criterios   t125_criterios_department_id
        ON
            t125_criterios_department_id.f125_id_cia    =   t120.f120_id_cia
            AND
            t125_criterios_department_id.f125_id_plan    =   'DPC'
WHERE
    t120.f120_id_cia    =   1
    AND
    referencia_producto_erp IS NULL

-- SELECT DISTINCT NULLIF(TRIM(referencia_producto_erp), '') FROM productos 

-- SELECT *
-- FROM    [UnoEE_PruebasProyectosCol].[dbo].t105_mc_criterios_item_planes
-- WHERE
--     f105_id_cia =   1

-- ================================================================================================================== --
/*
INSERT INTO [dbo].[productos] (
    id_tienda,
    referencia_producto_erp,
    id_producto_ecommerce,
    producto_obj,
    sincronizado,
    fecha_sincronizacion
)
SELECT DISTINCT 
    '1'                    AS id_tienda,
    f120_referencia        AS referencia_producto_erp,
    0                      AS id_producto_ecommerce,
    JSON_QUERY(CONCAT(
        '{',
        '"Name":"', 
            STRING_ESCAPE(
                UPPER(
                    LEFT(cmitems_descripcion, 1)
                ) + LOWER(
                    SUBSTRING(cmitems_descripcion, 2, LEN(cmitems_descripcion))
                ) + 
                ' Para ' + 
                UPPER(
                    LEFT(
                        REPLACE(
                            REPLACE(cmitems_GENERO, 'MASCULINO', 'Hombre'), 
                            'FEMENINO', 'Mujer'
                        ), 
                        1
                    )
                ) + 
                LOWER(
                    SUBSTRING(
                        REPLACE(
                            REPLACE(cmitems_GENERO, 'MASCULINO', 'Hombre'), 
                            'FEMENINO', 
                            'Mujer'
                        ), 
                        2, 
                        LEN(cmitems_GENERO))
                ) + 
                ' ' + 
                UPPER(
                    LEFT(cmitems_MARCA, 1)
                ) + 
                LOWER(
                    SUBSTRING(cmitems_MARCA, 2, LEN(cmitems_MARCA))
                ),
            'json'
        ), '",',
        '"DepartmentId":', Departamentos.Chopper, ',',
        '"CategoryId":', Categorias.Chopper, ',',
        '"BrandId":', Marcas.Chopper, ',',
        '"LinkId":"', STRING_ESCAPE(
            LOWER(cmitems_descripcion) + ' para ' + LOWER(REPLACE(REPLACE(cmitems_GENERO, 'MASCULINO', 'HOMBRE'), 'FEMENINO', 'MUJER')) + ' ' + 
            LOWER(cmitems_MARCA) + ' ' + LOWER(f120_referencia COLLATE DATABASE_DEFAULT), 
        'json'), '",',
        '"RefId":"', STRING_ESCAPE(f120_referencia, 'json'), '",',
        '"IsVisible":true,',
        '"Description":"', STRING_ESCAPE(
            LOWER(cmitems_descripcion) + ' para ' + LOWER(REPLACE(REPLACE(cmitems_GENERO, 'MASCULINO', 'HOMBRE'), 'FEMENINO', 'MUJER')) + ' ' + 
            LOWER(cmitems_MARCA) + ', La Prenda Ideal Para Combinar Con Tus Looks. Compra Ahora En Pilatos.Com',
        'json'), '",',
        '"DescriptionShort":"', STRING_ESCAPE(
            LEFT(LOWER(cmitems_descripcion), 50),
        'json'), '",',
        '"ReleaseDate":"', FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss'), '",',
        '"KeyWords":"', STRING_ESCAPE(
            LOWER(cmitems_descripcion) + ',' + LOWER(cmitems_GENERO) + ',' + LOWER(cmitems_MARCA),
        'json'), '",',
        '"Title":"', STRING_ESCAPE(UPPER(cmitems_descripcion), 'json'), '",',
        '"IsActive":true,',
        '"TaxCode":"', STRING_ESCAPE(ISNULL(f120_id_grupo_impositivo, ''), 'json'), '",',
        '"MetaTagDescription":"', STRING_ESCAPE(
            LOWER(cmitems_descripcion) + ', La Prenda Ideal Para Combinar Con Tus Looks. Compra Ahora En Pilatos.Com',
        'json'), '",',
        '"SupplierId":1,',
        '"ShowWithoutStock":false,',
        '"AdWordsRemarketingCode":null,',
        '"LomadeeCampaignCode":null,',
        '"Score":1',
        '}'
    ))                AS producto_obj,
    0                  AS sincronizado,
    GETDATE()          AS fecha_sincronizacion
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
    INNER JOIN EDMERPDB.unoee.dbo.t106_mc_criterios_item_mayores ON f105_id_cia = f106_id_cia AND f105_id = f106_id_plan
    INNER JOIN EDMERPDB.unoee.dbo.t125_mc_items_criterios ON f106_id_cia = f125_id_cia AND f106_id_plan = f125_id_plan AND f106_id = f125_id_criterio_mayor
    INNER JOIN EDMERPDB.unoee.dbo.t120_mc_items ON f125_rowid_item = f120_rowid
    LEFT JOIN productos ON productos.referencia_producto_erp = t120_mc_items.f120_referencia COLLATE DATABASE_DEFAULT AND productos.id_tienda = 1
    WHERE f120_id_cia = 1  
    AND f105_descripcion IN ('ES ECOMMERCE?', 'CATEGORIA', 'MARCA', 'GENERO')
    AND productos.referencia_producto_erp IS NULL
) Criterios
PIVOT (MAX(f106_id) FOR f125_id IN ([014],[009],[003],[010])) AS FormatoPivotCriterios
INNER JOIN [data_reporting].[comercial].[cmitems_120] ON cmitems_referencia_k2 = f120_referencia COLLATE DATABASE_DEFAULT
INNER JOIN [Integracion-VTEX-Portal].[dbo].[Departamentos] AS Departamentos ON Departamentos.CodigoERP = [010]
INNER JOIN [Integracion-VTEX-Portal].[dbo].[Categorias] AS Categorias ON Categorias.CodigoGeneroERP = [010] AND Categorias.CodigoCategoriaERP = [009]
INNER JOIN [Integracion-VTEX-Portal].[dbo].[Marcas] AS Marcas ON Marcas.CodigoERP = [003]
WHERE [014] LIKE '%SI%'
AND [009] IS NOT NULL
AND [003] IS NOT NULL
AND [010] IS NOT NULL
AND (cmitems_MARCA LIKE '%PILATOS%' OR cmitems_MARCA LIKE '%DIESEL%' OR cmitems_MARCA LIKE '%GIRBAUD%' OR 
    cmitems_MARCA LIKE '%SUPERDRY%' OR cmitems_MARCA LIKE '%KIPLING%' OR cmitems_MARCA LIKE '%NEW BALANCE%' OR cmitems_MARCA LIKE '%REPLAY%')
AND Departamentos.Chopper <> ''
AND Categorias.Chopper <> ''
AND Marcas.Chopper <> '';
*/