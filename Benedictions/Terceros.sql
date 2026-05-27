DECLARE @json					NVARCHAR(MAX) = '';
DECLARE @final					TABLE (
									idDocumento			INT
									,indicaParalelismo	BIT
									,descripcion		VARCHAR(50)
									,idOrden			VARCHAR(50)
									,json				VARCHAR(MAX)
								)
DECLARE @counter				INT = 1;
DECLARE @total					INT;
DECLARE @counterDuplicadas		INT = 1;
DECLARE @totalDuplicadas		INT;
DECLARE @order					VARCHAR(30)
DECLARE @paisSiesa				NVARCHAR(3)
		, @dptoSiesa			NVARCHAR(3)
		, @ciudadSiesa			NVARCHAR(3);
 
-- Cambiar datos a los reales del conector.
DECLARE @idDocumento			INT			=	200876
DECLARE @descripcionConector	VARCHAR(50)	=	'Terceros_Clientes_Imptos_Entidades'
DECLARE @indicaParalelismo		BIT			=	1
DECLARE @IdSucursal				NVARCHAR(3)	=	'WEB'
IF OBJECT_ID('tempdb..#company_ordenes') IS NOT NULL DROP TABLE #company_ordenes;
IF OBJECT_ID('tempdb..#company_terceros') IS NOT NULL DROP TABLE #company_terceros;
IF OBJECT_ID('tempdb..#company_cliente') IS NOT NULL DROP TABLE #company_cliente;
IF OBJECT_ID('tempdb..#company_impuestos') IS NOT NULL DROP TABLE #company_impuestos;
IF OBJECT_ID('tempdb..#company_ordenesDuplicadas') IS NOT NULL DROP TABLE #company_ordenesDuplicadas;
 
--Eliminamos ordenes duplicadas
SELECT id_orden, count(id_orden) number, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
  INTO #company_ordenesDuplicadas
  FROM ordenes
GROUP BY id_orden
HAVING count(id_orden) > 1
ORDER BY 1 DESC
 
SET @totalDuplicadas = (SELECT COUNT(*) FROM #company_ordenesDuplicadas);
WHILE @counterDuplicadas <= @totalDuplicadas
BEGIN
 
DECLARE	@ordenD		NVARCHAR(20)  =  (SELECT id_orden FROM #company_ordenesDuplicadas WHERE rn = @counterDuplicadas); 
DECLARE @idD		NVARCHAR(20)  =  (SELECT TOP 1 (id) FROM ordenes WHERE id_orden = @ordenD ORDER BY 1);
UPDATE ordenes SET id_estado = 3, id_orden = CONCAT(@ordenD,'-1') WHERE id_orden = @ordenD AND id <> @idD;
 
SET @counterDuplicadas = @counterDuplicadas + 1;
END
 
--Obtenemos las ordenes
SELECT TOP 10
	id_orden
	, orden_obj
INTO #company_ordenes
FROM ordenes 
WHERE id_estado =1 and intentos<=3 
AND id_orden <> '#9999'
--AND id_orden IN ('#2546','#2490','#2543');
 
SET @total = (SELECT COUNT(*) FROM #company_ordenes);
WHILE @counter <= @total
BEGIN
    --Obtenemos el json de la orden
    SET @json = (
        SELECT orden_obj
        FROM (
            SELECT orden_obj, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
            FROM #company_ordenes
        ) AS temp
        WHERE rn = @counter
    );
	--Obtenemos Pais, Ciudad y Municipio
	select top 1 @paisSiesa=isnull(f013_id_pais,'169') ,@dptoSiesa=isnull(f013_id_depto,'05') ,@ciudadSiesa=isnull(f013_id,'001') 
	from locaciones_erp 
	where 
		dbo.fn_RemoveAccentMarks(lower(f011_descripcion)) = dbo.fn_RemoveAccentMarks(lower(JSON_VALUE(@json, '$.customer.default_address.country')))
		and (
			dbo.fn_RemoveAccentMarks(lower(f012_descripcion)) = dbo.fn_RemoveAccentMarks(lower(JSON_VALUE(@json, '$.customer.default_address.province')))
			and dbo.fn_RemoveAccentMarks(lower(f013_descripcion))=dbo.fn_RemoveAccentMarks(lower(JSON_VALUE(@json, '$.customer.default_address.city'))) 
			or (dbo.fn_RemoveAccentMarks(lower(JSON_VALUE(@json, '$.customer.default_address.province'))) LIKE '%bogota%' and dbo.fn_RemoveAccentMarks(lower(f012_descripcion)) LIKE '%bogota%')
			or (dbo.fn_RemoveAccentMarks(lower(JSON_VALUE(@json, '$.customer.default_address.province'))) LIKE '%bolivar%' and dbo.fn_RemoveAccentMarks(lower(f013_descripcion)) LIKE '%cartagena%')
		);
 
	SELECT 
		@paisSiesa		=	ISNULL(@paisSiesa, '169')
		,@dptoSiesa		=	ISNULL(@dptoSiesa,'05')
		,@ciudadSiesa	=	ISNULL(@ciudadSiesa,'001')
 
	SET @order=JSON_VALUE(@json, '$.name')
 
	--Obtener documento del cliente
	DECLARE @F200_ID NVARCHAR(40) = 
	CASE
		WHEN TRY_CAST(dbo.OnlyNumbers(JSON_VALUE(@json, '$.billing_address.company')) AS DECIMAL(30,0)) IS NOT NULL 
			THEN JSON_VALUE(@json, '$.billing_address.company')
		WHEN TRY_CAST(dbo.OnlyNumbers(JSON_VALUE(@json, '$.customer.default_address.company')) AS DECIMAL(30,0)) IS NOT NULL 
			THEN JSON_VALUE(@json, '$.customer.default_address.company')
		ELSE '222222222222'
	END;
	DECLARE 
		@TipoIdentificacion					CHAR(1)
		,@IndTipoTercero					CHAR(1);
	SET @TipoIdentificacion					=	
		CASE
			WHEN	dbo.fn_KeepNumbersHyphen(@F200_ID)	LIKE		'%-%'		THEN	'N'	--Si contiene guion es NIT
			ELSE	'C'												--Cualquier otro caso es Cédula
		END;
	SET @IndTipoTercero						=
		CASE
			WHEN	dbo.fn_KeepNumbersHyphen(@F200_ID)	LIKE		'%-%'		THEN	'2'	--Si contiene guion
			WHEN	dbo.fn_KeepNumbersHyphen(@F200_ID)	=			''			THEN	'1'	-- Si está vacío
			WHEN	dbo.fn_KeepNumbersHyphen(@F200_ID)	NOT LIKE	'%[^0-9]%'	THEN	'1'	-- Si solo contiene números
			ELSE	'1'												-- Cualquier otro caso (contiene caracteres no numéricos)
		END;
	SET @F200_ID = 
		CASE
			WHEN dbo.fn_KeepNumbersHyphen(@F200_ID) = '' THEN '222222222222'
			ELSE dbo.fn_KeepNumbersHyphen(@F200_ID)
		END;
	DECLARE	@F200_RAZON_SOCIAL	NVARCHAR(100)	=
		UPPER(
			dbo.fn_RemoveAccentMarks(
				ISNULL(
					JSON_VALUE(@json, '$.billing_address.name')
					,JSON_VALUE(@json, '$.customer.default_address.name')
				)
			)
		)
	DECLARE	@F015_DIRECCION1	NVARCHAR(40)	=
		ISNULL(
			UPPER(
				dbo.fn_RemoveAccentMarks(
					JSON_VALUE(@json, '$.customer.default_address.address1')
				)
			)
			, ''
		)
	DECLARE	@F015_DIRECCION2	NVARCHAR(40)	=	
		ISNULL(
			UPPER(
				dbo.fn_RemoveAccentMarks(
					JSON_VALUE(@json, '$.customer.default_address.address2')
				)
			)
			, ''
		)
	--DECLARE	@F015_DIRECCION3	NVARCHAR(40)	=	
	--	ISNULL(
	--		UPPER(
	--			dbo.fn_RemoveAccentMarks(
	--				JSON_VALUE(@json, '$.customer.default_address.address3')
	--			)
	--		)
	--		, ''
	--	)
	DECLARE	@F015_TELEFONO		NVARCHAR(20)	=	
		REPLACE(
			JSON_VALUE(@json, '$.customer.default_address.phone')
			,'+57'
			,''
		)
	DECLARE	@F015_EMAIL			NVARCHAR(255)	=	
		dbo.fn_RemoveAccentMarks(
			JSON_VALUE(@json, '$.customer.email')
		)
	DECLARE	@FECHA				NVARCHAR(40)	=	
		REPLACE(
			CONVERT(
				varchar(10)
				,CAST(
					JSON_VALUE(@json, '$.customer.created_at')	AS	DATE
				)
			)
			, '-'
			, ''
		)
 
	--tercero
	SELECT
		F200_ID					=	LEFT(@F200_ID, 15)
		,F200_NIT				=	LEFT(@F200_ID, 25)
		,F200_ID_TIPO_IDENT		=	@TipoIdentificacion
		,F200_IND_TIPO_TERCERO	=	@IndTipoTercero
		,F200_RAZON_SOCIAL		=	@F200_RAZON_SOCIAL
		,F200_APELLIDO1			=	
			UPPER(
				dbo.fn_RemoveAccentMarks(
					LEFT(
						LTRIM(
							RTRIM(
								LEFT(
									ISNULL(
										JSON_VALUE(@json, '$.billing_address.last_name'),
										JSON_VALUE(@json, '$.customer.default_address.last_name')
									),
									CHARINDEX(
										' ',
										LTRIM(
											RTRIM(
												ISNULL(
													JSON_VALUE(@json, '$.billing_address.last_name'),
													JSON_VALUE(@json, '$.customer.default_address.last_name')
												)
											)
										) + ' '
									)
								)
							)
						), 29
					)
				)
			)
		,F200_APELLIDO2			= 
			UPPER(
				dbo.fn_RemoveAccentMarks(
					LEFT(
						LTRIM(
							SUBSTRING(
								LTRIM(
									RTRIM(
										ISNULL(
											JSON_VALUE(@json, '$.billing_address.last_name'),
											JSON_VALUE(@json, '$.customer.default_address.last_name')
										)
									)
								),
								CHARINDEX(
									' ',
									LTRIM(
										RTRIM(
											ISNULL(
												JSON_VALUE(@json, '$.billing_address.last_name'),
												JSON_VALUE(@json, '$.customer.default_address.last_name')
											)
										)
									) + ' '
								),
								LEN(
									ISNULL(
										JSON_VALUE(@json, '$.billing_address.last_name'),
										JSON_VALUE(@json, '$.customer.default_address.last_name')
									)
								) - CHARINDEX(
									' ',
									LTRIM(
										RTRIM(
											ISNULL(
												JSON_VALUE(@json, '$.billing_address.last_name'),
												JSON_VALUE(@json, '$.customer.default_address.last_name')
											)
										)
									)
								) + 1
							)
						), 29
					)
				)
			)
		,F200_NOMBRES			=
			UPPER(
				dbo.fn_RemoveAccentMarks(
					LEFT(
						ISNULL(
							JSON_VALUE(@json, '$.billing_address.first_name'),
							JSON_VALUE(@json, '$.customer.default_address.first_name')
						), 40
					)
				)
			)
		,F015_CONTACTO			=
			UPPER(
				dbo.fn_RemoveAccentMarks(
					LEFT(
						ISNULL(
							JSON_VALUE(@json, '$.billing_address.name'),
							JSON_VALUE(@json, '$.customer.default_address.name')
						), 50
					)
				)
			)
		,F015_DIRECCION1		=	@F015_DIRECCION1
		,F015_DIRECCION2		=	@F015_DIRECCION2
		--,F015_DIRECCION3		=	@F015_DIRECCION3
		,F015_ID_PAIS			=	@paisSiesa
		,F015_ID_DEPTO			=	@dptoSiesa
		,F015_ID_CIUDAD			=	@ciudadSiesa
		,F015_TELEFONO			=	@F015_TELEFONO
		,F015_EMAIL				=	@F015_EMAIL
		,F200_FECHA_NACIMIENTO	=	@FECHA
		,F015_CELULAR			=	@F015_TELEFONO
	INTO #company_terceros
	--cliente
	SELECT
		F201_ID_TERCERO				=	@F200_ID
		,F201_ID_SUCURSAL			=	@IdSucursal
		,F201_DESCRIPCION_SUCURSAL	=	LEFT(@F200_RAZON_SOCIAL, 40)
		,F201_ID_LISTA_PRECIO		=	'001'
		,F015_CONTACTO				=	@F200_RAZON_SOCIAL
		,F015_DIRECCION1			=	@F015_DIRECCION1
		,F015_DIRECCION2			=	@F015_DIRECCION2
		--,F015_DIRECCION3			=	@F015_DIRECCION3
		,F015_ID_PAIS				=	@paisSiesa
		,F015_ID_DEPTO				=	@dptoSiesa
		,F015_ID_CIUDAD				=	@ciudadSiesa
		,F015_TELEFONO				=	@F015_TELEFONO
		,F015_EMAIL					=	@F015_EMAIL
		,F201_FECHA_INGRESO			=	@FECHA
		,f015_celular				=	@F015_TELEFONO  
	INTO #company_cliente
	--impuestos
	CREATE TABLE #company_impuestos (
		F_TIPO_REG			VARCHAR(10)
		,F_ID_TERCERO		VARCHAR(50)
		,F_ID_SUCURSAL		VARCHAR(10)
		,F_ID_CLASE			VARCHAR(10)
		,F_ID_VALOR_TERCERO	VARCHAR(10)
	);
	INSERT INTO #company_impuestos (
		F_TIPO_REG
		,F_ID_TERCERO
		,F_ID_SUCURSAL
		,F_ID_CLASE
		,F_ID_VALOR_TERCERO
	)
	SELECT
		'46'		AS	F_TIPO_REG
		,@F200_ID	AS	F_ID_TERCERO
		,@IdSucursal		AS	F_ID_SUCURSAL
		,'1'		AS	F_ID_CLASE
		,'1'		AS	F_ID_VALOR_TERCERO
	/*UNION ALL
	SELECT
		'46'		AS	F_TIPO_REG
		,@F200_ID	AS	F_ID_TERCERO
		,'001'		AS	F_ID_SUCURSAL
		,'21'		AS	F_ID_CLASE
		,'1'		AS	F_ID_VALOR_TERCERO*/
	--entidad dinamica
	IF OBJECT_ID('tempdb..#company_entidad') IS NOT NULL DROP TABLE #company_entidad;
	CREATE TABLE #company_entidad (
		f200_id						VARCHAR(255)
		,f753_id_grupo_entidad		VARCHAR(255)
		,f753_id_entidad			VARCHAR(255)
		,f753_id_atributo			VARCHAR(255)
		,f753_id_maestro			VARCHAR(255)
		,f753_id_maestro_detalle	VARCHAR(255)
	);
	-- Insertar los valores en la tabla temporal #company_entidad
	INSERT INTO #company_entidad (
		f200_id
		,f753_id_grupo_entidad
		,f753_id_entidad
		,f753_id_atributo
		,f753_id_maestro
		,f753_id_maestro_detalle
	)
	SELECT
		@F200_ID						AS	f200_id
		,'FE TERCERO'				    AS	f753_id_grupo_entidad
		,'EUNOECO017'					AS	f753_id_entidad
		,'co017_codigo_regimen'	        AS	f753_id_atributo
		,'MUNOECO016'					AS	f753_id_maestro
		,'49'							AS	f753_id_maestro_detalle
	UNION ALL
	SELECT
		@F200_ID						AS	f200_id
		,'FE TERCERO'				    AS	f753_id_grupo_entidad
		,'EUNOECO017'					AS	f753_id_entidad
		,'co017_cod_tipo_oblig'	        AS	f753_id_atributo
		,'MUNOECO019'					AS	f753_id_maestro
		,'R-99-PN'						AS	f753_id_maestro_detalle
	UNION ALL
	SELECT
		@F200_ID						AS	f200_id
		,'FE TERCERO'				    AS	f753_id_grupo_entidad
		,'EUNOECO017'					AS	f753_id_entidad
		,'co017_cod_tipo_oblig2'	    AS	f753_id_atributo
		,'MUNOECO019'					AS	f753_id_maestro
		,'R-99-PN'						AS	f753_id_maestro_detalle
	UNION ALL
	SELECT
		@F200_ID						AS	f200_id
		,'FE TERCERO'				    AS	f753_id_grupo_entidad
		,'EUNOECO017'					AS	f753_id_entidad
		,'co017_cod_tipo_oblig3'	    AS	f753_id_atributo
		,'MUNOECO019'					AS	f753_id_maestro
		,'R-99-PN'                      AS	f753_id_maestro_detalle
	UNION ALL
	SELECT
		@F200_ID						AS	f200_id
		,'FE TERCERO'				    AS	f753_id_grupo_entidad
		,'EUNOECO031'					AS	f753_id_entidad
		,'co031_detalle_tributario1'	AS	f753_id_atributo
		,'MUNOECO035'					AS	f753_id_maestro
		,'ZZ'                           AS	f753_id_maestro_detalle
	UNION ALL
	SELECT
		@F200_ID						AS	f200_id
		,'FE TERCERO'				    AS	f753_id_grupo_entidad
		,'EUNOECO031'					AS	f753_id_entidad
		,'co031_detalle_tributario2'	AS	f753_id_atributo
		,'MUNOECO035'					AS	f753_id_maestro
		,'ZZ'                           AS	f753_id_maestro_detalle
	UNION ALL
	SELECT
		@F200_ID						AS	f200_id
		,'FE TERCERO'				    AS	f753_id_grupo_entidad
		,'EUNOECO031'					AS	f753_id_entidad
		,'co031_detalle_tributario3'	AS	f753_id_atributo
		,'MUNOECO035'					AS	f753_id_maestro
		,'ZZ'                           AS	f753_id_maestro_detalle
	UNION ALL
	SELECT
		@F200_ID						AS	f200_id
		,'FE TERCERO'				    AS	f753_id_grupo_entidad
		,'EUNOECO036'					AS	f753_id_entidad
		,'co036_id_procedencia_org'	    AS	f753_id_atributo
		,'MUNOECO043'					AS	f753_id_maestro
		,'01'                           AS	f753_id_maestro_detalle
    
    IF (@F200_ID != '222222222222')
    BEGIN
        INSERT INTO @final(
            idDocumento
            ,descripcion
            ,indicaParalelismo
            ,idOrden
            ,json
        )
        SELECT
            @idDocumento
            ,@descripcionConector
            ,@indicaParalelismo
            ,@order					AS	idOrden
            ,(
                SELECT
                    [Terceros]				=	(
                        SELECT * 
                        FROM #company_terceros
                        FOR JSON PATH
                        ,INCLUDE_NULL_VALUES
                    ),[Clientes]			=	(
                        SELECT *
                        FROM #company_cliente
                        FOR JSON PATH
                        ,INCLUDE_NULL_VALUES
                    ),[ImptosyReten]		=	(
                        SELECT *
                        FROM #company_impuestos
                        FOR JSON PATH
                        ,INCLUDE_NULL_VALUES
                    ),[EntDinamicaTercero]	=	(
                        SELECT *
                        FROM #company_entidad
                        FOR JSON PATH
                        ,INCLUDE_NULL_VALUES
                    )FOR JSON PATH
                    ,WITHOUT_ARRAY_WRAPPER
                    ,INCLUDE_NULL_VALUES
            );
    END
    ELSE
    BEGIN
        UPDATE ORDENES
        SET intentos = 99
        WHERE
            id_orden = @order
    END
	IF OBJECT_ID('tempdb..#company_terceros') IS NOT NULL DROP TABLE #company_terceros;
	IF OBJECT_ID('tempdb..#company_cliente') IS NOT NULL DROP TABLE #company_cliente;
	IF OBJECT_ID('tempdb..#company_impuestos') IS NOT NULL DROP TABLE #company_impuestos;
	IF OBJECT_ID('tempdb..#company_entidad') IS NOT NULL DROP TABLE #company_entidad;
	SET @counter = @counter + 1;
END
SELECT * from @final AS final_json;