/*=====================================================
1. ELIMINAR DUPLICADOS EXISTENTES
=====================================================*/
-- MODIFICACION 1: limpieza previa de duplicados
WITH Duplicados_verona AS (
    SELECT 
        id,
        ROW_NUMBER() OVER (
            PARTITION BY id_tienda, id_producto_ecommerce, sku_erp
            ORDER BY id
        ) AS rn
    FROM variantes
)
DELETE FROM Duplicados_verona
WHERE rn > 1;


/*=====================================================
2. TABLA TEMPORAL DESCRIPCIONES TECNICAS
=====================================================*/
IF OBJECT_ID('tempdb..##ITEMSDESCTECNICAS_VERONA') IS NOT NULL
    DROP TABLE ##ITEMSDESCTECNICAS_VERONA

SELECT 
    *
INTO ##ITEMSDESCTECNICAS_VERONA
FROM OPENROWSET(
    'SQLNCLI',
    'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
	'SELECT * FROM
	(
		SELECT 
			f120_id            AS IdItem,
			f120_referencia    AS Referencia,
			f120_descripcion	AS Descripcion,
			f104_id,
			f123_dato
		FROM t123_mc_items_desc_tecnicas
			INNER JOIN t104_mc_desc_tecnicas_campos 
				ON f104_rowid = f123_rowid_campo 
				AND f123_id_cia = f104_id_cia 
			INNER JOIN t103_mc_descripciones_tecnicas 
				ON f103_id = f104_id_descripcion_tecnica 
				AND f104_id_cia = f103_id_cia 
			INNER JOIN t120_mc_items 
				ON f123_id_cia = f120_id_cia 
				AND f123_rowid_item = f120_rowid                  
		WHERE f120_id_cia = 2
	)DESCRIPCIONESTECNICAS
	PIVOT 
	(
		MAX(f123_dato) 
		FOR f104_id IN 
		([PackagedHeight],[PackagedLength],[PackagedWidth],[PackagedWeightKg],[Height],[Length],[Width],[WeightKg])
	) AS FormatoPivotCriterios'
) AS ITEMSDESCTECNICAS;


/*=====================================================
3. PRODUCTOS FILTRADOS
=====================================================*/
WITH ProductosFiltrados AS (
    SELECT 
        id_tienda,
        id_producto_ecommerce,
        referencia_producto_erp
    FROM productos
    WHERE id_tienda = 1
    AND sincronizado = 1
),

/*=====================================================
4. EVITAR DUPLICADOS DESDE EL ORIGEN
=====================================================*/
-- MODIFICACION 2: ROW_NUMBER para evitar duplicados del OPENROWSET
VariantesOrigen AS (
SELECT 
	pf.id_tienda,
    pf.id_producto_ecommerce,
    LTRIM(RTRIM(v121_id_barras_principal)) AS sku_erp,
    ID.*,
    ROW_NUMBER() OVER(
        PARTITION BY pf.id_producto_ecommerce, LTRIM(RTRIM(v121_id_barras_principal))
        ORDER BY pf.id_producto_ecommerce
    ) AS rn
FROM ProductosFiltrados pf

INNER JOIN OPENROWSET(
    'SQLNCLI',
    'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
	'SELECT 
		v121_referencia,
		v121_id_ext1_detalle,
		v121_id_ext2_detalle,
		v121_id_barras_principal,
		f117_id,
		f117_descripcion
	 FROM v121
	 INNER JOIN t117_mc_extensiones1_detalle 
		 ON f117_id = v121_id_ext1_detalle 
		 AND f117_id_cia = v121_id_cia
	 WHERE v121_id_cia = 2 
	 AND v121_id_barras_principal IS NOT NULL'
) AS UN 
ON pf.referencia_producto_erp = UN.v121_referencia

INNER JOIN ##ITEMSDESCTECNICAS_VERONA ID 
ON ID.Referencia = UN.v121_referencia
)


/*=====================================================
5. INSERT DE VARIANTES
=====================================================*/
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
	vo.id_tienda,
    vo.id_producto_ecommerce,
    0 AS id_variante_ecommerce,
    vo.sku_erp,

    JSON_QUERY(( 
        SELECT 
            vo.id_producto_ecommerce AS ProductId,
            CAST('false' AS BIT) AS IsActive,
            CAST('true' AS BIT) AS ActivateIfPossible,
            vo.sku_erp AS Name,
            vo.sku_erp AS RefId,
            vo.sku_erp AS Ean,

			TRY_CONVERT(NUMERIC(18,1), vo.PackagedHeight) AS PackagedHeight,
			TRY_CONVERT(NUMERIC(18,1), vo.PackagedLength) AS PackagedLength,
			TRY_CONVERT(NUMERIC(18,1), vo.PackagedWidth)  AS PackagedWidth,
			TRY_CONVERT(NUMERIC(18,1), REPLACE(LTRIM(RTRIM(vo.PackagedWeightKg)), ',', '.')) AS PackagedWeightKg,

			TRY_CONVERT(NUMERIC(18,1), vo.Height) AS Height,
			TRY_CONVERT(NUMERIC(18,1), vo.Length) AS Length,
			TRY_CONVERT(NUMERIC(18,1), vo.Width) AS Width,

            vo.WeightKg AS WeightKg,
            CONVERT(NUMERIC(18,1),0) AS CubicWeight,
            CAST('false' AS BIT) AS IsKit,
            FORMAT(GETDATE(),'yyyy-MM-ddTHH:mm:00') AS CreationDate,
            NULL AS RewardValue,
            NULL AS EstimatedDateArrival,
            '0' AS ManufacturerCode,
            1 AS CommercialConditionId,
            'un' AS MeasurementUnit,
            CONVERT(NUMERIC(18,1),1) AS UnitMultiplier,
            NULL AS ModalType,
            CAST('false' AS BIT) AS KitItensSellApart,
            JSON_QUERY('["https://www.youtube.com/"]') AS Videos
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )) AS variante_obj,

    CAST(0 AS BIT),
    GETDATE()

FROM VariantesOrigen vo

-- MODIFICACION 3: solo insertar el primer duplicado
WHERE vo.rn = 1

-- MODIFICACION 4: evitar insertar si ya existe
AND NOT EXISTS (
	SELECT 1 
	FROM variantes v 
	WHERE v.id_producto_ecommerce = vo.id_producto_ecommerce
	AND v.sku_erp = vo.sku_erp
)

AND ISNULL(vo.sku_erp,'') <> '';