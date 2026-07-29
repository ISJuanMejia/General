DECLARE @entidades_atributos_descripcion_web    TABLE
(
    grupo_entidad_id            NVARCHAR(100),
    entidad_etiqueta            NVARCHAR(100),
    entidad_atributo_id         NVARCHAR(100),
    entidad_atributo_etiqueta   NVARCHAR(100),
    entidad_atributo_dato       NVARCHAR(100),
    f753_rowid_movto_entidad    INT
)

INSERT INTO @entidades_atributos_descripcion_web
SELECT
	[grupo_entidad_id]          =   t744_mm_grupo_entidad.f744_id,
	[entidad_etiqueta]          =   f742_etiqueta,
	[entidad_atributo_id]       =   t743_mm_entidad_atributo.f743_id,
    [entidad_atributo_etiqueta] =   t743_mm_entidad_atributo.f743_etiqueta,
    [entidad_atributo_dato]     =
	    CASE
            WHEN    f743_ind_tipo_atributo  =   6
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  IN  (2, 3)
                THEN    CAST (f753_dato_fecha AS VARCHAR(20))
	    	WHEN    f743_ind_tipo_atributo  =   1
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  =   7
                THEN    ISNULL(f741_descripcion, ' ')
	    	WHEN    f743_ind_tipo_atributo  IN  (4, 5)
                THEN
                    CAST(
                        CAST(
                            f753_dato_numero AS DECIMAL(18, 2)
                        ) AS VARCHAR(20)
                    )
	        ELSE '' 
        END,
    f753_rowid_movto_entidad
FROM [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna]
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t750_mm_movto_entidad] 
        ON 
            f750_rowid = f753_rowid_movto_entidad
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] 
        ON 
            f743_rowid = f753_rowid_entidad_atributo
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t741_mm_maestro_detalle] 
        ON 
            f741_rowid = f753_rowid_maestro_detalle
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t739_mm_maestro_interno] 
        ON 
            f739_id = f743_id_maestro_interno
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t744_mm_grupo_entidad] 
        ON 
            t750_mm_movto_entidad.f750_rowid_grupo_entidad = t744_mm_grupo_entidad.f744_rowid
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t742_mm_entidad] 
        ON 
            t743_mm_entidad_atributo.f743_rowid_entidad = t742_mm_entidad.f742_rowid
WHERE
    t743_mm_entidad_atributo.f743_id    =   'texto_des_web'
    AND
    NULLIF(
        CASE
            WHEN    f743_ind_tipo_atributo  =   6
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  IN  (2, 3)
                THEN    CAST (f753_dato_fecha AS VARCHAR(20))
	    	WHEN    f743_ind_tipo_atributo  =   1
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  =   7
                THEN    ISNULL(f741_descripcion, ' ')
	    	WHEN    f743_ind_tipo_atributo  IN  (4, 5)
                THEN
                    CAST(
                        CAST(
                            f753_dato_numero AS DECIMAL(18, 2)
                        ) AS VARCHAR(20)
                    )
	        ELSE '' 
        END, 
        ''
    )   IS NOT NULL
ORDER BY f753_rowid_movto_entidad_fila

DECLARE @entidades_atributos_alto   TABLE
(
    grupo_entidad_id            NVARCHAR(100),
    entidad_etiqueta            NVARCHAR(100),
    entidad_atributo_id         NVARCHAR(100),
    entidad_atributo_etiqueta   NVARCHAR(100),
    entidad_atributo_dato       NVARCHAR(100),
    f753_rowid_movto_entidad    INT
)

INSERT INTO @entidades_atributos_alto
SELECT
	[grupo_entidad_id]          =   t744_mm_grupo_entidad.f744_id,
	[entidad_etiqueta]          =   f742_etiqueta,
	[entidad_atributo_id]       =   t743_mm_entidad_atributo.f743_id,
    [entidad_atributo_etiqueta] =   t743_mm_entidad_atributo.f743_etiqueta,
    [entidad_atributo_dato]     =
	    CASE
            WHEN    f743_ind_tipo_atributo  =   6
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  IN  (2, 3)
                THEN    CAST (f753_dato_fecha AS VARCHAR(20))
	    	WHEN    f743_ind_tipo_atributo  =   1
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  =   7
                THEN    ISNULL(f741_descripcion, ' ')
	    	WHEN    f743_ind_tipo_atributo  IN  (4, 5)
                THEN
                    CAST(
                        CAST(
                            f753_dato_numero AS DECIMAL(18, 2)
                        ) AS VARCHAR(20)
                    )
	        ELSE '' 
        END,
    f753_rowid_movto_entidad
FROM [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna]
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t750_mm_movto_entidad] 
        ON 
            f750_rowid = f753_rowid_movto_entidad
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] 
        ON 
            f743_rowid = f753_rowid_entidad_atributo
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t741_mm_maestro_detalle] 
        ON 
            f741_rowid = f753_rowid_maestro_detalle
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t739_mm_maestro_interno] 
        ON 
            f739_id = f743_id_maestro_interno
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t744_mm_grupo_entidad] 
        ON 
            t750_mm_movto_entidad.f750_rowid_grupo_entidad = t744_mm_grupo_entidad.f744_rowid
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t742_mm_entidad] 
        ON 
            t743_mm_entidad_atributo.f743_rowid_entidad = t742_mm_entidad.f742_rowid
WHERE
    t743_mm_entidad_atributo.f743_id    =   'Num_Alto'
    AND
    NULLIF(
        CASE
            WHEN    f743_ind_tipo_atributo  =   6
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  IN  (2, 3)
                THEN    CAST (f753_dato_fecha AS VARCHAR(20))
	    	WHEN    f743_ind_tipo_atributo  =   1
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  =   7
                THEN    ISNULL(f741_descripcion, ' ')
	    	WHEN    f743_ind_tipo_atributo  IN  (4, 5)
                THEN
                    CAST(
                        CAST(
                            f753_dato_numero AS DECIMAL(18, 2)
                        ) AS VARCHAR(20)
                    )
	        ELSE '' 
        END, 
        ''
    )   IS NOT NULL
ORDER BY f753_rowid_movto_entidad_fila

DECLARE @entidades_atributos_ancho    TABLE
(
    grupo_entidad_id            NVARCHAR(100),
    entidad_etiqueta            NVARCHAR(100),
    entidad_atributo_id         NVARCHAR(100),
    entidad_atributo_etiqueta   NVARCHAR(100),
    entidad_atributo_dato       NVARCHAR(100),
    f753_rowid_movto_entidad    INT
)

INSERT INTO @entidades_atributos_ancho
SELECT
	[grupo_entidad_id]          =   t744_mm_grupo_entidad.f744_id,
	[entidad_etiqueta]          =   f742_etiqueta,
	[entidad_atributo_id]       =   t743_mm_entidad_atributo.f743_id,
    [entidad_atributo_etiqueta] =   t743_mm_entidad_atributo.f743_etiqueta,
    [entidad_atributo_dato]     =
	    CASE
            WHEN    f743_ind_tipo_atributo  =   6
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  IN  (2, 3)
                THEN    CAST (f753_dato_fecha AS VARCHAR(20))
	    	WHEN    f743_ind_tipo_atributo  =   1
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  =   7
                THEN    ISNULL(f741_descripcion, ' ')
	    	WHEN    f743_ind_tipo_atributo  IN  (4, 5)
                THEN
                    CAST(
                        CAST(
                            f753_dato_numero AS DECIMAL(18, 2)
                        ) AS VARCHAR(20)
                    )
	        ELSE '' 
        END,
    f753_rowid_movto_entidad
FROM [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna]
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t750_mm_movto_entidad] 
        ON 
            f750_rowid = f753_rowid_movto_entidad
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] 
        ON 
            f743_rowid = f753_rowid_entidad_atributo
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t741_mm_maestro_detalle] 
        ON 
            f741_rowid = f753_rowid_maestro_detalle
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t739_mm_maestro_interno] 
        ON 
            f739_id = f743_id_maestro_interno
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t744_mm_grupo_entidad] 
        ON 
            t750_mm_movto_entidad.f750_rowid_grupo_entidad = t744_mm_grupo_entidad.f744_rowid
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t742_mm_entidad] 
        ON 
            t743_mm_entidad_atributo.f743_rowid_entidad = t742_mm_entidad.f742_rowid
WHERE
    t743_mm_entidad_atributo.f743_id    =   'Num_Ancho'
    AND
    NULLIF(
        CASE
            WHEN    f743_ind_tipo_atributo  =   6
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  IN  (2, 3)
                THEN    CAST (f753_dato_fecha AS VARCHAR(20))
	    	WHEN    f743_ind_tipo_atributo  =   1
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  =   7
                THEN    ISNULL(f741_descripcion, ' ')
	    	WHEN    f743_ind_tipo_atributo  IN  (4, 5)
                THEN
                    CAST(
                        CAST(
                            f753_dato_numero AS DECIMAL(18, 2)
                        ) AS VARCHAR(20)
                    )
	        ELSE '' 
        END, 
        ''
    )   IS NOT NULL
ORDER BY f753_rowid_movto_entidad_fila

DECLARE @entidades_atributos_largo    TABLE
(
    grupo_entidad_id            NVARCHAR(100),
    entidad_etiqueta            NVARCHAR(100),
    entidad_atributo_id         NVARCHAR(100),
    entidad_atributo_etiqueta   NVARCHAR(100),
    entidad_atributo_dato       NVARCHAR(100),
    f753_rowid_movto_entidad    INT
)

INSERT INTO @entidades_atributos_largo
SELECT
	[grupo_entidad_id]          =   t744_mm_grupo_entidad.f744_id,
	[entidad_etiqueta]          =   f742_etiqueta,
	[entidad_atributo_id]       =   t743_mm_entidad_atributo.f743_id,
    [entidad_atributo_etiqueta] =   t743_mm_entidad_atributo.f743_etiqueta,
    [entidad_atributo_dato]     =
	    CASE
            WHEN    f743_ind_tipo_atributo  =   6
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  IN  (2, 3)
                THEN    CAST (f753_dato_fecha AS VARCHAR(20))
	    	WHEN    f743_ind_tipo_atributo  =   1
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  =   7
                THEN    ISNULL(f741_descripcion, ' ')
	    	WHEN    f743_ind_tipo_atributo  IN  (4, 5)
                THEN
                    CAST(
                        CAST(
                            f753_dato_numero AS DECIMAL(18, 2)
                        ) AS VARCHAR(20)
                    )
	        ELSE '' 
        END,
    f753_rowid_movto_entidad
FROM [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna]
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t750_mm_movto_entidad] 
        ON 
            f750_rowid = f753_rowid_movto_entidad
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] 
        ON 
            f743_rowid = f753_rowid_entidad_atributo
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t741_mm_maestro_detalle] 
        ON 
            f741_rowid = f753_rowid_maestro_detalle
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t739_mm_maestro_interno] 
        ON 
            f739_id = f743_id_maestro_interno
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t744_mm_grupo_entidad] 
        ON 
            t750_mm_movto_entidad.f750_rowid_grupo_entidad = t744_mm_grupo_entidad.f744_rowid
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t742_mm_entidad] 
        ON 
            t743_mm_entidad_atributo.f743_rowid_entidad = t742_mm_entidad.f742_rowid
WHERE
    t743_mm_entidad_atributo.f743_id    =   'Num_Largo'
    AND
    NULLIF(
        CASE
            WHEN    f743_ind_tipo_atributo  =   6
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  IN  (2, 3)
                THEN    CAST (f753_dato_fecha AS VARCHAR(20))
	    	WHEN    f743_ind_tipo_atributo  =   1
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  =   7
                THEN    ISNULL(f741_descripcion, ' ')
	    	WHEN    f743_ind_tipo_atributo  IN  (4, 5)
                THEN
                    CAST(
                        CAST(
                            f753_dato_numero AS DECIMAL(18, 2)
                        ) AS VARCHAR(20)
                    )
	        ELSE '' 
        END, 
        ''
    )   IS NOT NULL
ORDER BY f753_rowid_movto_entidad_fila

DECLARE @entidades_atributos_peso    TABLE
(
    grupo_entidad_id            NVARCHAR(100),
    entidad_etiqueta            NVARCHAR(100),
    entidad_atributo_id         NVARCHAR(100),
    entidad_atributo_etiqueta   NVARCHAR(100),
    entidad_atributo_dato       NVARCHAR(100),
    f753_rowid_movto_entidad    INT
)

INSERT INTO @entidades_atributos_peso
SELECT
	[grupo_entidad_id]          =   t744_mm_grupo_entidad.f744_id,
	[entidad_etiqueta]          =   f742_etiqueta,
	[entidad_atributo_id]       =   t743_mm_entidad_atributo.f743_id,
    [entidad_atributo_etiqueta] =   t743_mm_entidad_atributo.f743_etiqueta,
    [entidad_atributo_dato]     =
	    CASE
            WHEN    f743_ind_tipo_atributo  =   6
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  IN  (2, 3)
                THEN    CAST (f753_dato_fecha AS VARCHAR(20))
	    	WHEN    f743_ind_tipo_atributo  =   1
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  =   7
                THEN    ISNULL(f741_descripcion, ' ')
	    	WHEN    f743_ind_tipo_atributo  IN  (4, 5)
                THEN
                    CAST(
                        CAST(
                            f753_dato_numero AS DECIMAL(18, 2)
                        ) AS VARCHAR(20)
                    )
	        ELSE '' 
        END,
    f753_rowid_movto_entidad
FROM [UnoEE_PruebasProyectosCol].[dbo].[t753_mm_movto_entidad_columna]
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t750_mm_movto_entidad] 
        ON 
            f750_rowid = f753_rowid_movto_entidad
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t743_mm_entidad_atributo] 
        ON 
            f743_rowid = f753_rowid_entidad_atributo
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t741_mm_maestro_detalle] 
        ON 
            f741_rowid = f753_rowid_maestro_detalle
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t739_mm_maestro_interno] 
        ON 
            f739_id = f743_id_maestro_interno
    LEFT JOIN [UnoEE_PruebasProyectosCol].[dbo].[t744_mm_grupo_entidad] 
        ON 
            t750_mm_movto_entidad.f750_rowid_grupo_entidad = t744_mm_grupo_entidad.f744_rowid
    INNER JOIN [UnoEE_PruebasProyectosCol].[dbo].[t742_mm_entidad] 
        ON 
            t743_mm_entidad_atributo.f743_rowid_entidad = t742_mm_entidad.f742_rowid
WHERE
    t743_mm_entidad_atributo.f743_id    =   'Num_Peso'
    AND
    NULLIF(
        CASE
            WHEN    f743_ind_tipo_atributo  =   6
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  IN  (2, 3)
                THEN    CAST (f753_dato_fecha AS VARCHAR(20))
	    	WHEN    f743_ind_tipo_atributo  =   1
                THEN    f753_dato_texto
	    	WHEN    f743_ind_tipo_atributo  =   7
                THEN    ISNULL(f741_descripcion, ' ')
	    	WHEN    f743_ind_tipo_atributo  IN  (4, 5)
                THEN
                    CAST(
                        CAST(
                            f753_dato_numero AS DECIMAL(18, 2)
                        ) AS VARCHAR(20)
                    )
	        ELSE '' 
        END, 
        ''
    )   IS NOT NULL
ORDER BY f753_rowid_movto_entidad_fila

/*
*   5.  ActivateSkuIfPossible
*       a.  Item sin extensión
*           -   Item    ->  Parametros  ->  Generales   ->  Estado
*       b.  Item con extensión
*           -   Item    ->  Otros   ->  Extensiones ->  Parametros  ->  Generales   ->  Estado
*/

/*
*   6.  SkuIsActive
*       a.  Item sin extensión
*           -   Item    ->  Parametros  ->  Generales   ->  Estado
*       b.  Item con extensión
*           -   Item    ->  Otros   ->  Extensiones ->  Parametros  ->  Generales   ->  Estado
*/

/*
*   8.  Height
*       a.  Item    ->  Entidades   ->  Grupo entidad: ITEM ->  ITEM    ->  Alto cm (Empaque) 
*/
/*
SELECT
    f120_id,
    f120_referencia,
    f120_descripcion,
    f742_etiqueta,
    f743_id,
    f743_etiqueta,
    f753_dato_texto,
    f753_dato_fecha,
    f753_dato_numero
FROM t120_mc_items  t120
    INNER JOIN t753_mm_movto_entidad_columna    t753
        ON 
            f120_rowid_movto_entidad    =   f753_rowid_movto_entidad
    INNER JOIN t742_mm_entidad  t742
        ON
            f753_rowid_entidad  =   f742_rowid
    INNER JOIN t743_mm_entidad_atributo t743
        ON
            f742_rowid  =   f743_rowid_entidad
WHERE
    f742_id =   'ITEM'
    AND
    f743_id =   'Num_Alto'
*/

/*
*   10.  Width
*       a.  Item    ->  Entidades   ->  Grupo entidad: ITEM ->  ITEM    ->  Ancho cm (Empaque)
*/

/*
*   12.  Length
*       a.  Item    ->  Entidades   ->  Grupo entidad: ITEM ->  ITEM    ->  Largo cm (Empaque)
*/

/*
*   12.  Weight
*       a.  Item    ->  Entidades   ->  Grupo entidad: ITEM ->  ITEM    ->  Peso gr (Empaque)
*/

/*
*   25.  ProductIsActive
*       a.  Item sin extensión
*           -   Item    ->  Parametros  ->  Generales   ->  Estado
*       b.  Item con extensión
*           -   Item    ->  Otros   ->  Extensiones ->  Parametros  ->  Generales   ->  Estado
*/

/*
*   26.  ProductReferenceCodeId
*       a.  Item que maneja ref padre (Ref 6 digitos)
*           -   Item    ->  Descripcion técnica ->  Descripción tecnica: 001 - MEDIAS DE COMPRESIÓN ->  Estado
*       b.  Refencia completa (SKU)
*           -   Item    ->  Referencia
*/

/*
*   25.  ShowOnSite
*       a.  Item sin extensión
*           -   Item    ->  Parametros  ->  Generales   ->  Estado
*       b.  Item con extensión
*           -   Item    ->  Otros   ->  Extensiones ->  Parametros  ->  Generales   ->  Estado
*/

/*
*   33.  MetaTagDescription
*       a.  Item    ->  Entidades   ->  Grupo entidad: ITEM ->  DATOS MARKETING ->  [Meta Tag Description 1, Meta Tag Description 2]
*/


/*
*   4.  SkuName
*       -   Items   ->  Entidades   ->  Grupo Entidad: ITEM ->  Descripcion WEB
*   --------------------------------------------------------------------------------------------------------------------
*   7.  SkuEan
*       a.  Item con extensión
*           -   Item    ->  Otros   ->  Extensiones ->  Extensión   ->  Codigo de barras
*   --------------------------------------------------------------------------------------------------------------------
*   18.  SKUReference
*       a.  Item    ->  Referencia
*   --------------------------------------------------------------------------------------------------------------------
*   32.  SiteTitle
*       a.  Item    ->  Entidades   ->  Grupo entidad: ITEM ->  ITEM    ->  Descripcion WEB
*   --------------------------------------------------------------------------------------------------------------------
*   37.  DepartamentId
*       a.  Item    ->  Criterios   ->  Plan    DPC ->  Tomar Criterio
*   --------------------------------------------------------------------------------------------------------------------
*   38.  DepartamentName
*       a.  Item    ->  Criterios   ->  Plan    DPC ->  Tomar Descripcion Criterio
*   --------------------------------------------------------------------------------------------------------------------
*   39.  CategoryId
*       a.  Item    ->  Criterios   ->  Plan    CC1 ->  Tomar Criterio
*   --------------------------------------------------------------------------------------------------------------------
*   40.  CategoryName
*       a.  Item    ->  Criterios   ->  Plan    CC1 ->  Tomar Descripcion Criterio
*   --------------------------------------------------------------------------------------------------------------------
*   42.  BrandId
*       a.  Item    ->  Criterios   ->  Plan    005 ->  Tomar Criterio
*   --------------------------------------------------------------------------------------------------------------------
*   42.  Brand
*       a.  Item    ->  Criterios   ->  Plan    005 ->  Tomar Descripcion Criterio
*/

/*
SELECT
    [SkuId]                     =   '',                                     --> 3
    [SkuName]                   =   TRIM(eadw.entidad_atributo_dato),       --> 4
    [ActivateSkuIfPossible]     =   '',                                     --- TODO    5   YES|NO
    [SkuIsActive]               =   '',                                     --- TODO    6   YES|NO
    [SkuEan]                    =   TRIM(f131_id),                          --> 7
    [Height]                    =   TRIM(ea_alto.entidad_atributo_dato),    --> 8
    [ActualHeight]              =   '',                                     --> 9
    [Width]                     =   TRIM(ea_ancho.entidad_atributo_dato),   --> 10
    [ActualWidth]               =   '',                                     --> 11
    [Length]                    =   TRIM(ea_largo.entidad_atributo_dato),   --> 12
    [ActualLenght]              =   '',                                     --> 13
    [Weight]                    =   TRIM(ea_peso.entidad_atributo_dato),    --> 14
    [ActualWeight]              =   '',                                     --> 15
    [MeasurementUnit]           =   'UN',                                   --> 16
    [UnitMultiplier]            =   '1,000000',                             --> 17
    [SKUReference]              =   TRIM(f120_referencia),                  --> 18
    [RewardValue]               =   '',                                     --> 19
    [EstimatedArrivalDate]      =   '',                                     --> 20
    [ManufacturerCode]          =   '',                                     --> 21
    [ProductId]                 =   '',                                     --> 22
    [ProductName]               =   TRIM(eadw.entidad_atributo_dato),       --> 23
    [ProductShortDescription]   =   '',                                     --> 24
    [ProductIsActive]           =   '',                                     --- TODO    25  YES|NO
    [ProductReferenceCodeId]    =   '',
    [ShowOnSite]                =   '',
    [CaptionLink]               =   '',
    [ProductDescription]        =   '',
    [ProductLaunchDate]         =   '',
    [Keywords]                  =   '',
    [SiteTitle]                 =   TRIM(eadw.entidad_atributo_dato),
    [MetaTagDescription]        =   '',
    [SupplierId]                =   '',
    [ShowOutOfStock]            =   'YES',
    [Kit]                       =   'NO',
    [DepartamentId]             =   departament.f106_id,
    [DepartamentName]           =   TRIM(departament.f106_descripcion),
    [CategoryId]                =   category.f106_id,
    [CategoryName]              =   TRIM(category.f106_descripcion),
    [BrandId]                   =   brand.f106_id,
    [Brand]                     =   TRIM(brand.f106_descripcion),
    [CubicWeight]               =   1,
    [CommercialCondition]       =   'Padrão',
    [Stores]                    =   1,
    [Accessories]               =   '',
    [Similar]                   =   '',
    [Suggestions]               =   '',
    [ShowTogether]              =   '',
    [Attachment]                =   ''
FROM [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items]
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t121_mc_items_extensiones]
        ON
            f120_rowid  =   f121_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras]
        ON
            f131_rowid_item_ext =   f121_rowid
    INNER JOIN  @entidades_atributos_descripcion_web    eadw
        ON
            eadw.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_alto   ea_alto
        ON
            ea_alto.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_ancho  ea_ancho
        ON
            ea_ancho.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_largo  ea_largo
        ON
            ea_largo.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_peso   ea_peso
        ON
            ea_peso.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_departament
        ON
            f120_rowid  =   criterios_departament.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  departament
        ON
            departament.f106_id_plan    =   criterios_departament.f125_id_plan
            AND
            departament.f106_id         =   criterios_departament.f125_id_criterio_mayor
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_category
        ON
            f120_rowid  =   criterios_category.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  category
        ON
            category.f106_id_plan    =   criterios_category.f125_id_plan
            AND
            category.f106_id         =   criterios_category.f125_id_criterio_mayor
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_brand
        ON
            f120_rowid  =   criterios_brand.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  brand
        ON
            Brand.f106_id_plan    =   criterios_brand.f125_id_plan
            AND
            Brand.f106_id         =   criterios_brand.f125_id_criterio_mayor
WHERE
    criterios_departament.f125_id_plan  =   'DPC'
    AND
    criterios_category.f125_id_plan     =   'CC1'
    AND
    criterios_brand.f125_id_plan        =   '005';
*/

/*
SELECT
    f120_id_cia,
    f120_id,
    f120_referencia,
    f120_descripcion,
    f103_descripcion,
    f104_id,
    f123_dato
FROM t120_mc_items
    INNER JOIN t123_mc_items_desc_tecnicas
        ON
            f123_rowid_item =   f120_rowid
    INNER JOIN t104_mc_desc_tecnicas_campos
        ON
            f123_rowid_campo    =   f104_rowid
    INNER JOIN t103_mc_descripciones_tecnicas
        ON
            f104_id_cia =   f103_id_cia
            AND
            f104_id_descripcion_tecnica =   f103_id
WHERE
    f104_id =   'REF 6 DIGITOS'
*/

/*
SELECT
    [Name]                      =   TRIM(eadw.entidad_atributo_dato),
    [DepartmentId]              =   CAST(departament.f106_id AS INT),
    [CategoryId]                =   CAST(category.f106_id AS INT),
    [BrandId]                   =   CAST(brand.f106_id AS INT),
    [LinkId]                    =   '',
    [RefId]                     =   TRIM(f120_referencia),
    [IsVisible]                 =   CAST(0 AS BIT),
    [Description]               =   TRIM(eadw.entidad_atributo_dato),
    [DescriptionShort]          =   TRIM(eadw.entidad_atributo_dato),
    [ReleaseDate]               =   GETDATE(),
    [Keywords]                  =   '',
    [Title]                     =   TRIM(eadw.entidad_atributo_dato),
    [IsActive]                  =   CAST(1 AS BIT),
    [TaxCode]                   =   '',
    [MetaTagDescription]        =   '',
    [SupplierId]                =   NULL,
    [ShowWithoutStock]          =   CAST(1 AS BIT),
    [AdWordsRemarketingCode]    =   NULL,
    [LomadeeCampaignCode]       =   NULL,
    [Score]                     =   0
FROM [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items]
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t121_mc_items_extensiones]
        ON
            f120_rowid  =   f121_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras]
        ON
            f131_rowid_item_ext =   f121_rowid
    INNER JOIN  @entidades_atributos_descripcion_web    eadw
        ON
            eadw.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_alto   ea_alto
        ON
            ea_alto.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_ancho  ea_ancho
        ON
            ea_ancho.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_largo  ea_largo
        ON
            ea_largo.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_peso   ea_peso
        ON
            ea_peso.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_departament
        ON
            f120_rowid  =   criterios_departament.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  departament
        ON
            departament.f106_id_plan    =   criterios_departament.f125_id_plan
            AND
            departament.f106_id         =   criterios_departament.f125_id_criterio_mayor
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_category
        ON
            f120_rowid  =   criterios_category.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  category
        ON
            category.f106_id_plan    =   criterios_category.f125_id_plan
            AND
            category.f106_id         =   criterios_category.f125_id_criterio_mayor
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_brand
        ON
            f120_rowid  =   criterios_brand.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  brand
        ON
            Brand.f106_id_plan    =   criterios_brand.f125_id_plan
            AND
            Brand.f106_id         =   criterios_brand.f125_id_criterio_mayor
    LEFT JOIN   productos
        ON
            referencia_producto_erp =   f120_referencia
WHERE
    referencia_producto_erp IS NULL
    AND
    criterios_departament.f125_id_plan  =   'DPC'
    AND
    criterios_category.f125_id_plan     =   'CC1'
    AND
    criterios_brand.f125_id_plan        =   '005';
*/

/*
{
  "Id": 1,
  "Name": "Media de compresión deportiva unisex 15-20 mmHg NV-X® Sport",
  "DepartmentId": 8,
  "CategoryId": 165,
  "BrandId": 2,
  "LinkId": "Media-deportiva-unisex-15-20-mmhg-nv-x-sport-101047",
  "RefId": "101047",
  "IsVisible": true,
  "Description": "Las medias deportivas NV-X® Sport de mediana compresión 15-20 mmHg ofrece compresión progresiva para minimizar el movimiento muscular durante el ejercicio; recomendadas para usar antes, durante y después de cualquier actividad física. Ayuda a la recuperación después de la actividad física, mejora la metabolización del ácido láctico y optimizan el uso del oxígeno, también son ideales para mejorar la circulación y aliviar síntomas en las piernas como: pesadez, dolor, inflamación y calambres. Su tejido circular con fibras de doble recubrimiento garantiza la compresión progresiva, elasticidad y durabilidad.",
  "DescriptionShort": "Media de compresión no-varix® mujer 15-20 mmhg   colors diseño diamante pequeño",
  "ReleaseDate": "2023-02-14T00:00:00",
  "KeyWords": "medias de compresion deportivas,medias de compresión running,pantorrilleras deportivas,medias de compresion running,medias compresion deportivas,medias de compresion de running,medias de compresion,medias de compresión,media de compresion,equipos médicos,medias antiembolicas,medias para varices,medias compresivas,medias compresion,medias de compresión precio,equipos biomedicos,medias para las varices,media compresion,medias compresión,medias antiembólicas,medias antiembolia,medias para la varices,antiembolicas medias,medias antiembolica,equipomedico,medias para el varis,tienda medico,medias de compresión precios",
  "Title": "Media De Compresión Deportiva Unisex 15-20",
  "IsActive": true,
  "TaxCode": "",
  "MetaTagDescription": "Medias deportivas que ofrecen compresión progresiva para minimizar el movimiento muscular; recomendadas para usar antes, durante y después de cualquier actividad física",
  "SupplierId": null,
  "ShowWithoutStock": true,
  "AdWordsRemarketingCode": null,
  "LomadeeCampaignCode": null,
  "Score": 0
}
*/

/*
SELECT
    [Id]                        =   '',
    [ProductId]                 =   '',
    [IsActive]                  =   CAST(1 AS BIT),
    [ActivateIfPossible]        =   CAST(1 AS BIT),
    [Name]                      =   TRIM(eadw.entidad_atributo_dato),
    [RefId]                     =   TRIM(f120_referencia),
    [PackagedHeight]            =   TRIM(ea_alto.entidad_atributo_dato),
    [PackagedLength]            =   TRIM(ea_largo.entidad_atributo_dato),
    [PackagedWidth]             =   TRIM(ea_ancho.entidad_atributo_dato),
    [PackagedWeightKg]          =   TRIM(ea_peso.entidad_atributo_dato),
    [Height]                    =   TRIM(ea_alto.entidad_atributo_dato),
    [Length]                    =   TRIM(ea_largo.entidad_atributo_dato),
    [Width]                     =   TRIM(ea_ancho.entidad_atributo_dato),
    [WeightKg]                  =   TRIM(ea_peso.entidad_atributo_dato),
    [CubicWeight]               =   1,
    [IsKit]                     =   CAST(0 AS BIT),
    [CreationDate]              =   GETDATE(),
    [RewardValue]               =   NULL,
    [EstimatedDateArrival]      =   NULL,
    [ManufacturerCode]          =   '',
    [CommercialConditionId]     =   1,
    [MeasurementUnit]           =   'un',
    [UnitMultiplier]            =   1,
    [ModalType]                 =   NULL,
    [KitItensSellApart]         =   CAST(0 AS BIT)
FROM [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items]
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t121_mc_items_extensiones]
        ON
            f120_rowid  =   f121_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras]
        ON
            f131_rowid_item_ext =   f121_rowid
    INNER JOIN  @entidades_atributos_descripcion_web    eadw
        ON
            eadw.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_alto   ea_alto
        ON
            ea_alto.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_ancho  ea_ancho
        ON
            ea_ancho.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_largo  ea_largo
        ON
            ea_largo.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_peso   ea_peso
        ON
            ea_peso.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_departament
        ON
            f120_rowid  =   criterios_departament.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  departament
        ON
            departament.f106_id_plan    =   criterios_departament.f125_id_plan
            AND
            departament.f106_id         =   criterios_departament.f125_id_criterio_mayor
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_category
        ON
            f120_rowid  =   criterios_category.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  category
        ON
            category.f106_id_plan    =   criterios_category.f125_id_plan
            AND
            category.f106_id         =   criterios_category.f125_id_criterio_mayor
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_brand
        ON
            f120_rowid  =   criterios_brand.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  brand
        ON
            Brand.f106_id_plan    =   criterios_brand.f125_id_plan
            AND
            Brand.f106_id         =   criterios_brand.f125_id_criterio_mayor
WHERE
    criterios_departament.f125_id_plan  =   'DPC'
    AND
    criterios_category.f125_id_plan     =   'CC1'
    AND
    criterios_brand.f125_id_plan        =   '005';
*/

/*
    {
        "Id": 1,
        "ProductId": 1,
        "IsActive": true,
        "ActivateIfPossible": true,
        "Name": "Media de compresión deportiva unisex 15-20 mmHg NV-X® Sport black/fucsia L",
        "RefId": "10103875",
        "PackagedHeight": 17.5,
        "PackagedLength": 3.5,
        "PackagedWidth": 10.5,
        "PackagedWeightKg": 90,
        "Height": 0,
        "Length": 0,
        "Width": 0,
        "WeightKg": 0,
        "CubicWeight": 1,
        "IsKit": false,
        "CreationDate": "2025-10-15T12:59:00",
        "RewardValue": null,
        "EstimatedDateArrival": null,
        "ManufacturerCode": "",
        "CommercialConditionId": 1,
        "MeasurementUnit": "un",
        "UnitMultiplier": 1,
        "ModalType": null,
        "KitItensSellApart": false,
        "Videos": []
    }
*/

INSERT INTO [dbo].[productos]
(
    id_tienda,
    referencia_producto_erp,
    id_producto_ecommerce,
    sincronizado,
    fecha_sincronizacion,
    producto_obj
)
SELECT DISTINCT
    [id_tienda] =   1,
    [referencia_producto_erp]   =   TRIM(f120_referencia),
    [id_producto_ecommerce]     =   0,
    [sincronizado]              =   0,
    [fecha_sincronizacion]      =   GETDATE(),
    [producto_obj]              =
        (
            SELECT
                [Name]                      =   TRIM(eadw.entidad_atributo_dato),
                [DepartmentId]              =   CAST(departament.f106_id AS INT),
                [CategoryId]                =   CAST(category.f106_id AS INT),
                [BrandId]                   =   CAST(brand.f106_id AS INT),
                [LinkId]                    =   
                    STRING_ESCAPE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(
                                        REPLACE(
                                            REPLACE(
                                                LOWER(
                                                    ISNULL(
                                                        TRIM(eadw.entidad_atributo_dato), 
                                                        ''
                                                    )
                                                ), 
												'/', 
                                                '-'
                                            ),
                                            ' ', 
                                            '-'
                                        ),
                                        ',', 
                                        ''
                                    ),
                                    '.', 
                                    ''
                                ), 
								'(', 
                                ''
                            ), 
							')', 
                            ''
                        ), 
                        'json'
                    ),
                [RefId]                     =   TRIM(f120_referencia),
                [IsVisible]                 =   CAST(0 AS BIT),
                [Description]               =   TRIM(eadw.entidad_atributo_dato),
                [DescriptionShort]          =   TRIM(eadw.entidad_atributo_dato),
                [ReleaseDate]               =   FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss'),
                [Keywords]                  =   '',
                [Title]                     =   TRIM(eadw.entidad_atributo_dato),
                [IsActive]                  =   CAST(1 AS BIT),
                [TaxCode]                   =   '',
                [MetaTagDescription]        =   '',
                [SupplierId]                =   NULL,
                [ShowWithoutStock]          =   CAST(0 AS BIT),
                [AdWordsRemarketingCode]    =   NULL,
                [LomadeeCampaignCode]       =   NULL,
                [Score]                     =   0
            FOR JSON PATH,
            WITHOUT_ARRAY_WRAPPER
        )
FROM [UnoEE_PruebasProyectosCol].[dbo].[t120_mc_items]
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t121_mc_items_extensiones]
        ON
            f120_rowid  =   f121_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t131_mc_items_barras]
        ON
            f131_rowid_item_ext =   f121_rowid
    INNER JOIN  @entidades_atributos_descripcion_web    eadw
        ON
            eadw.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_alto   ea_alto
        ON
            ea_alto.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_ancho  ea_ancho
        ON
            ea_ancho.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_largo  ea_largo
        ON
            ea_largo.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  @entidades_atributos_peso   ea_peso
        ON
            ea_peso.f753_rowid_movto_entidad    =   f120_rowid_movto_entidad
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_departament
        ON
            f120_rowid  =   criterios_departament.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  departament
        ON
            departament.f106_id_plan    =   criterios_departament.f125_id_plan
            AND
            departament.f106_id         =   criterios_departament.f125_id_criterio_mayor
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_category
        ON
            f120_rowid  =   criterios_category.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  category
        ON
            category.f106_id_plan    =   criterios_category.f125_id_plan
            AND
            category.f106_id         =   criterios_category.f125_id_criterio_mayor
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t125_mc_items_criterios] criterios_brand
        ON
            f120_rowid  =   criterios_brand.f125_rowid_item
    INNER JOIN  [UnoEE_PruebasProyectosCol].[dbo].[t106_mc_criterios_item_mayores]  brand
        ON
            Brand.f106_id_plan    =   criterios_brand.f125_id_plan
            AND
            Brand.f106_id         =   criterios_brand.f125_id_criterio_mayor
    LEFT JOIN   productos
        ON
            referencia_producto_erp =   f120_referencia
WHERE
    referencia_producto_erp IS NULL
    AND
    criterios_departament.f125_id_plan  =   'DPC'
    AND
    criterios_category.f125_id_plan     =   'CC1'
    AND
    criterios_brand.f125_id_plan        =   '005'
    AND
    NOT EXISTS (
		SELECT 1
		FROM productos p
		WHERE
            p.referencia_producto_erp   =   CAST(f120_referencia AS NVARCHAR)
	)
