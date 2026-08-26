USE [Integracion-VeronaGroup-VTEX]
BEGIN

if object_id('tempdb..##ITEMSDESCRIPCION_verona') is not null
        DROP TABLE ##ITEMSDESCRIPCION_verona
if object_id('tempdb..##ITEMECOMMERCE_verona') is not null
        DROP TABLE ##ITEMECOMMERCE_verona
if object_id('tempdb..##DEPARTAMENTOCRITERIOS_verona') is not null
        DROP TABLE ##DEPARTAMENTOCRITERIOS_verona
if object_id('tempdb..##MARCACRITERIOS_verona') is not null
        DROP TABLE ##MARCACRITERIOS_verona
if object_id('tempdb..##CATEGORIACRITERIOS_verona') is not null
        DROP TABLE ##CATEGORIACRITERIOS_verona
if object_id('tempdb..##DEPARTAMENTO_verona') is not null
        DROP TABLE ##DEPARTAMENTO_verona
if object_id('tempdb..##MARCA_verona') is not null
        DROP TABLE ##MARCA_verona
if object_id('tempdb..##CATEGORIA_verona') is not null
        DROP TABLE ##CATEGORIA_verona
if object_id('tempdb..##ITEMS_verona') is not null
        DROP TABLE ##ITEMS_verona
if object_id('tempdb..##SINCRONIZARITEMS_verona') is not null
        DROP TABLE ##SINCRONIZARITEMS_verona
if object_id('tempdb..##SINCRONIZARFINAL_verona') is not null
        DROP TABLE ##SINCRONIZARFINAL_verona

SELECT 
    ITEMSDESCRIPCION.Referencia,
    ITEMSDESCRIPCION.ItemDescripcion
INTO ##ITEMSDESCRIPCION_verona
FROM OPENROWSET(
    'SQLNCLI',
    'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
    'SELECT
        t120.f120_referencia AS Referencia,
        t753.f753_dato_texto AS ItemDescripcion
    FROM t120_mc_items AS t120
		INNER JOIN t750_mm_movto_entidad AS t750 ON t120.f120_rowid_movto_entidad = t750.f750_rowid
		INNER JOIN t753_mm_movto_entidad_columna AS t753 ON t753.f753_rowid_movto_entidad = t750.f750_rowid AND t753.f753_id_cia = t750.f750_id_cia
		INNER JOIN t743_mm_entidad_atributo AS t743 ON t753.f753_rowid_entidad_atributo = t743.f743_rowid AND t753.f753_id_cia = t743.f743_id_cia
    WHERE t120.f120_id_cia = 2 AND t743.f743_etiqueta = ''VTEX''
    '
) AS ITEMSDESCRIPCION


SELECT 
    ITEMECOMMERCE.Referencia
INTO ##ITEMECOMMERCE_verona
FROM OPENROWSET(
    'SQLNCLI',
    'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
    'SELECT
        f120_referencia   AS Referencia
	FROM t105_mc_criterios_item_planes AS t105_mc_criterios_item_planes 
		INNER JOIN t106_mc_criterios_item_mayores AS t106_mc_criterios_item_mayores ON	f105_id_cia	= f106_id_cia AND f105_id = f106_id_plan 
		INNER JOIN t125_mc_items_criterios AS t125_mc_items_criterios ON f106_id_cia = f125_id_cia AND f106_id_plan	= f125_id_plan AND f106_id = f125_id_criterio_mayor
		INNER JOIN t120_mc_items AS t120_mc_items ON f125_rowid_item = f120_rowid 										
	WHERE f120_id_cia = 2 AND f106_descripcion = ''SI''
    '
) AS ITEMECOMMERCE


SELECT 
    DEPARTAMENTOCRITERIOS.IdPlanD,
	DEPARTAMENTOCRITERIOS.IdCriterioD,
	DEPARTAMENTOCRITERIOS.NotasD,
	DEPARTAMENTOCRITERIOS.DescripcionD
INTO ##DEPARTAMENTOCRITERIOS_verona
FROM OPENROWSET(
    'SQLNCLI',
    'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
    'SELECT
        f105_id                 AS IdPlanD,
		f106_id                 AS IdCriterioD, 
		f106_notas              AS NotasD,
		f106_descripcion        AS DescripcionD
	FROM t105_mc_criterios_item_planes AS t105_mc_criterios_item_planes 
		INNER JOIN	t106_mc_criterios_item_mayores AS t106_mc_criterios_item_mayores ON  f105_id_cia = f106_id_cia AND f105_id = f106_id_plan
	WHERE f105_id = 001 AND f105_id_cia = 2
    '
) AS DEPARTAMENTOCRITERIOS


SELECT 
    MARCACRITERIOS.IdPlanM,
	MARCACRITERIOS.IdCriterioM,
	MARCACRITERIOS.NotasM,
	MARCACRITERIOS.DescripcionM
INTO ##MARCACRITERIOS_verona
FROM OPENROWSET(
    'SQLNCLI',
    'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
    'SELECT
		f105_id            AS IdPlanM,
		f106_id            AS IdCriterioM, 
		f106_notas         AS NotasM,
		f106_descripcion   AS DescripcionM
	FROM t105_mc_criterios_item_planes AS t105_mc_criterios_item_planes 
		INNER JOIN	t106_mc_criterios_item_mayores AS t106_mc_criterios_item_mayores ON  f105_id_cia = f106_id_cia AND f105_id = f106_id_plan
	WHERE f105_id = 002 AND f105_id_cia = 2
    '
) AS MARCACRITERIOS


SELECT 
    CATEGORIACRITERIOS.IdPlanC,
	CATEGORIACRITERIOS.IdCriterioC,
	CATEGORIACRITERIOS.NotasC,
	CATEGORIACRITERIOS.DescripcionC
INTO ##CATEGORIACRITERIOS_verona
FROM OPENROWSET(
    'SQLNCLI',
    'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
    'SELECT
		f105_id           AS IdPlanC,
		f106_id           AS IdCriterioC, 
		f106_notas        AS NotasC,
		f106_descripcion  AS DescripcionC
	FROM t105_mc_criterios_item_planes AS t105_mc_criterios_item_planes 
		INNER JOIN	t106_mc_criterios_item_mayores AS t106_mc_criterios_item_mayores ON  f105_id_cia = f106_id_cia AND f105_id = f106_id_plan
	WHERE f105_id = 003 AND f105_id_cia = 2
    '
) AS CATEGORIACRITERIOS


SELECT 
    DEPARTAMENTO.IdPlanL,
    DEPARTAMENTO.IdCriterioL,
    DEPARTAMENTO.ReferenciaL,
    DEPARTAMENTO.Descripcion,
    DEPARTAMENTO.Notas
INTO ##DEPARTAMENTO_verona
FROM (
    SELECT
         f105_id          AS IdPlanL,
         f106_id          AS IdCriterioL,
         f120_referencia  AS ReferenciaL,
         f120_descripcion AS Descripcion,
         f120_notas       AS Notas
    FROM OPENROWSET(
        'SQLNCLI',
        'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
        '
         SELECT
             f105_id,
             f106_id,
             f120_referencia,
             f120_descripcion,
             f120_notas,
             f105_descripcion,
             f120_id_cia
         FROM t105_mc_criterios_item_planes
         INNER JOIN t106_mc_criterios_item_mayores 
             ON f105_id_cia = f106_id_cia AND f105_id = f106_id_plan 
         INNER JOIN t125_mc_items_criterios 
             ON f106_id_cia = f125_id_cia AND f106_id_plan = f125_id_plan AND f106_id = f125_id_criterio_mayor
         INNER JOIN t120_mc_items 
             ON f125_rowid_item = f120_rowid
        '
    ) AS RawData
    WHERE f120_id_cia = 2 AND f105_descripcion = 'DEPARTAMENTO'
) AS DEPARTAMENTO
INNER JOIN ##ITEMECOMMERCE_verona IE ON DEPARTAMENTO.ReferenciaL = IE.Referencia

SELECT 
    MARCA.IdPlanM,
    MARCA.IdCriterioM,
    MARCA.ReferenciaM
INTO ##MARCA_verona
FROM (
    SELECT
         f105_id         AS IdPlanM,
         f106_id         AS IdCriterioM,
         f120_referencia AS ReferenciaM
    FROM OPENROWSET(
        'SQLNCLI',
        'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
        '
         SELECT
             f105_id,
             f106_id,
             f120_referencia,
             f105_descripcion,
             f120_id_cia
         FROM t105_mc_criterios_item_planes
         INNER JOIN t106_mc_criterios_item_mayores 
             ON f105_id_cia = f106_id_cia AND f105_id = f106_id_plan 
         INNER JOIN t125_mc_items_criterios 
             ON f106_id_cia = f125_id_cia AND f106_id_plan = f125_id_plan AND f106_id = f125_id_criterio_mayor
         INNER JOIN t120_mc_items 
             ON f125_rowid_item = f120_rowid
        '
    ) AS RawData
    WHERE f120_id_cia = 2 AND f105_descripcion = 'MARCA'
) AS MARCA
INNER JOIN ##ITEMECOMMERCE_verona IE ON MARCA.ReferenciaM = IE.Referencia


SELECT 
    CATEGORIA.IdPlanC,
    CATEGORIA.IdCriterioC,
    CATEGORIA.ReferenciaC
INTO ##CATEGORIA_verona
FROM (
    SELECT
         f105_id                 AS IdPlanC,
         f106_id                 AS IdCriterioC,
         f120_referencia         AS ReferenciaC
     FROM OPENROWSET(
        'SQLNCLI',
        'Server=siesa-m3-sqlsw-db03.cihpfbkcx35e.us-east-1.rds.amazonaws.com;Database=UnoEE_VeronaGroup_Real;UID=Verona;PWD=Verona$12$%',
        '
         SELECT
             f105_id,
             f106_id,
             f120_referencia,
             f105_descripcion,
             f120_id_cia
         FROM t105_mc_criterios_item_planes
         INNER JOIN t106_mc_criterios_item_mayores 
             ON f105_id_cia = f106_id_cia AND f105_id = f106_id_plan 
         INNER JOIN t125_mc_items_criterios 
             ON f106_id_cia = f125_id_cia AND f106_id_plan = f125_id_plan AND f106_id = f125_id_criterio_mayor
         INNER JOIN t120_mc_items 
             ON f125_rowid_item = f120_rowid
        '
    ) AS RawData
    WHERE f120_id_cia = 2 AND f105_descripcion = 'CATEGORIAS'
) AS CATEGORIA
INNER JOIN ##ITEMECOMMERCE_verona IE ON CATEGORIA.ReferenciaC = IE.Referencia


SELECT * INTO ##ITEMS_verona FROM ##DEPARTAMENTO_verona L
INNER JOIN ##MARCA_verona M ON L.ReferenciaL = M.ReferenciaM
INNER JOIN ##CATEGORIA_verona C ON L.ReferenciaL = C.ReferenciaC


SELECT 
 ReferenciaL
,Descripcion
,Notas
,NotasD
,NotasM
,NotasC
INTO ##SINCRONIZARITEMS_verona
FROM ##ITEMS_verona I
INNER JOIN ##DEPARTAMENTOCRITERIOS_verona D ON I.IdPlanL = D.IdPlanD
                      AND I.IdCriterioL = D.IdCriterioD
INNER JOIN ##MARCACRITERIOS_verona M ON I.IdPlanM = M.IdPlanM
                     AND I.IdCriterioM = M.IdCriterioM
INNER JOIN ##CATEGORIACRITERIOS_verona C ON I.IdPlanC = C.IdPlanC
                     AND I.IdCriterioC = C.IdCriterioC


SELECT	
DISTINCT
	'1'																	                            AS 'IdTienda'	
	,REPLACE(SI.Descripcion,'"','')													                AS 'Name'
	,rtrim(ltrim(SI.NotasD))                                                                	    AS 'DepartmentId'
	,rtrim(ltrim(SI.NotasC))                                                                        AS 'CategoryId'
	,rtrim(ltrim(SI.NotasM))                                                                        AS 'BrandId'
	,RTRIM(LTRIM(REPLACE(REPLACE(CONCAT(SI.Descripcion,'-',SI.ReferenciaL),' ',''),'"','')))	    AS 'LinkId'
	,SI.ReferenciaL										            	                            AS 'RefId'
	,'true'															                                AS 'IsVisible'
	,REPLACE(CASE WHEN ID.ItemDescripcion IS NULL THEN SI.Descripcion				                
			WHEN ID.ItemDescripcion IS NOT NULL THEN ID.ItemDescripcion END,'"','')                 AS 'Description'
	,REPLACE(SI.Descripcion,'"','')													                AS 'DescriptionShort'
	,REPLACE(CONVERT(VARCHAR, GETDATE(),102),'.','-')					                            AS 'ReleaseDate'
	,'null'															                                AS 'KeyWords'
	,REPLACE(SI.Descripcion,'"','')                                                                 AS 'Title'
	,'true'															                                AS 'IsActive'
	,'null'																	                        AS 'TaxCode'
	,'null'                      											                        AS 'MetaTagDescription'
	,'null'																	                        AS 'SupplierId'
	,'true'														    	                            AS 'ShowWithoutStock'
	,'null'																	                        AS 'AdWordsRemarketingCode'
	,'null'																	                        AS 'LomadeeCampaignCode'
	,'null'																	                        AS 'Score'
	,'1'									                        	                            AS 'TradePolicyId'
	,''												                                                AS 'CriterioAval'
INTO ##SINCRONIZARFINAL_verona	
FROM  ##SINCRONIZARITEMS_verona SI
LEFT JOIN ##ITEMSDESCRIPCION_verona ID ON SI.ReferenciaL = ID.Referencia


INSERT INTO [dbo].[productos] (
    id_tienda,
    referencia_producto_erp,
    id_producto_ecommerce,
    producto_obj,
    sincronizado,
    fecha_sincronizacion
)
SELECT DISTINCT 
    '1' AS id_tienda,
    s.RefId AS referencia_producto_erp,
    0 AS id_producto_ecommerce,
    (
        SELECT 
            s.Name,
            s.DepartmentId,
            s.CategoryId,
            s.BrandId,
            s.LinkId,
            s.RefId,
            CAST(1 AS BIT) AS IsVisible,
            s.Description,
            s.DescriptionShort,
            s.ReleaseDate AS ReleaseDate,
            s.KeyWords,
            s.Title,
            CAST(1 AS BIT) AS IsActive,
            s.TaxCode,
            s.MetaTagDescription,
            1 AS SupplierId,
            CAST(0 AS BIT) AS ShowWithoutStock,
            NULL AS AdWordsRemarketingCode,
            NULL AS LomadeeCampaignCode,
            1 AS Score
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS producto_obj,
    0 AS sincronizado,
    GETDATE() AS fecha_sincronizacion
FROM ##SINCRONIZARFINAL_verona s
WHERE 
	ISNULL(LTRIM(RTRIM(s.BrandId)), '') <> ''
	AND ISNULL(LTRIM(RTRIM(s.CategoryId)), '') <> ''
	AND ISNULL(LTRIM(RTRIM(s.DepartmentId)), '') <> ''
	AND NOT EXISTS (
        SELECT 1 
        FROM productos p 
        WHERE p.referencia_producto_erp = s.RefId 
          AND id_tienda = 1
    )

END