WITH ProductosFiltrados AS (
    SELECT 
        id_tienda,
        id_producto_ecommerce,
        referencia_producto_erp
    FROM 
        productos
    WHERE 
        id_tienda = 1
        AND sincronizado = 1
)
-- INSERT INTO [dbo].[variantes] (
-- 	id_tienda,
--     id_producto_ecommerce, 
--     id_variante_ecommerce, 
--     sku_erp, 
--     variante_obj, 
--     sincronizado, 
--     fecha_sincronizacion
-- )
SELECT 
	[id_tienda]             =   pf.id_tienda,
    [id_producto_ecommerce] =   pf.id_producto_ecommerce,
    [id_variante_ecommerce] =   0, 
    [sku_erp]               =   LTRIM(RTRIM(v121_id_barras_principal)),
    variante_obj            =
    (
        SELECT 
            [ProductId]             =   pf.id_producto_ecommerce,
            [IsActive]              =   CAST(0 AS BIT),
            [ActivateIfPossible]    =   CAST(1 AS BIT),
            [Name]                  =   
                UPPER(
                    CONCAT(
                        LTRIM(
                            RTRIM(f117_descripcion)
                        ),
                        ' ',
                        LTRIM(
                            RTRIM(
                                CONCAT(
                                    LEFT(v121_id_ext2_detalle, 1),
                                    SUBSTRING(
                                        v121_id_ext2_detalle, 
                                        2, 
                                        LEN(v121_id_ext2_detalle)
                                    )
                                )
                            )
                        )
                    )
                ),
            [RefId]                 =   LTRIM(RTRIM(v121_id_barras_principal)),
            [Ean]                   =   LTRIM(RTRIM(v121_id_barras_principal)),
            [PackagedHeight]        =   10,
            [PackagedLength]        =   10,
            [PackagedWidth]         =   10,
            [PackagedWeightKg]      =   10,
            [Height]                =   NULL,
            [Length]                =   NULL,
            [Width]                 =   NULL,
            [WeightKg]              =   NULL,
            [CubicWeight]           =   CAST(0 AS FLOAT),
            [IsKit]                 =   CAST(0 AS BIT),
            [CreationDate]          =   REPLACE(CONVERT(VARCHAR, GETDATE(), 102), '.', '-'),
            [RewardValue]           =   NULL,
            [EstimatedDateArrival]  =   NULL,
            [ManufacturerCode]      =   '123',
            [CommercialConditionId] =   1,
            [MeasurementUnit]       =   'un',
            [UnitMultiplier]        =   1,
            [ModalType]             =   NULL,
            [KitItensSellApart]     =   CAST(0 AS BIT),
            [Videos]                =   JSON_QUERY('["https://www.youtube.com/"]')
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ),
    sincronizado            =   CAST(0 AS BIT), 
    fecha_sincronizacion    =   GETDATE()
FROM 
    ProductosFiltrados pf
    INNER JOIN  [UnoEE_PruebasProyectosCol].dbo.v121
        ON
            pf.referencia_producto_erp  =	v121_referencia
            AND 
            v121.v121_id_cia			=	1
    INNER JOIN  [UnoEE_PruebasProyectosCol].dbo.t117_mc_extensiones1_detalle	
        ON
            f117_id_extension1	=	v121_id_extension1
            AND 
            f117_id				=	v121_id_ext1_detalle
            AND 
            f117_id_cia			=	1
    LEFT JOIN   variantes 
        ON
            variantes.sku_erp   =   v121_id_barras_principal COLLATE DATABASE_DEFAULT
WHERE 
    v121_id_cia                 =   1
    AND 
    variantes.sku_erp           IS NULL
    AND
    v121_id_barras_principal    IS NOT NULL
/*
ORDER BY
    pf.id_tienda, 
    pf.id_producto_ecommerce,
    v121_id_ext1_detalle, 
    CASE 
        WHEN v121_id_ext2_detalle = 'U' THEN '00'
        WHEN v121_id_ext2_detalle = 'XXS' THEN '01'
        WHEN v121_id_ext2_detalle = 'XS' THEN '02'
        WHEN v121_id_ext2_detalle = 'S' THEN '03'
        WHEN v121_id_ext2_detalle IN ('S/M', 'S-M') THEN '04'
        WHEN v121_id_ext2_detalle = 'M' THEN '05'
        WHEN v121_id_ext2_detalle IN ('M/L', 'M-L') THEN '06'
        WHEN v121_id_ext2_detalle = 'L' THEN '07'
        WHEN v121_id_ext2_detalle = 'L/XL' THEN '08'
        WHEN v121_id_ext2_detalle = 'XL' THEN '09'
        WHEN v121_id_ext2_detalle = 'XXL' THEN '10'
        WHEN v121_id_ext2_detalle = 'XXXL' THEN '11'
        WHEN ISNUMERIC(v121_id_ext2_detalle) = 1 THEN
            CASE
                WHEN CHARINDEX(',', v121_id_ext2_detalle) > 0 THEN
                    CAST(SUBSTRING(v121_id_ext2_detalle, 1, CHARINDEX(',', v121_id_ext2_detalle) - 1) AS INT) * 10 +
                    CAST(SUBSTRING(v121_id_ext2_detalle, CHARINDEX(',', v121_id_ext2_detalle) + 1, LEN(v121_id_ext2_detalle)) AS INT)
                ELSE
                    CAST(v121_id_ext2_detalle AS INT) * 10
            END
        ELSE 1000
    END;
*/