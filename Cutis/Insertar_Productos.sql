-- SET ANSI_NULLS ON
-- GO
-- SET QUOTED_IDENTIFIER ON
-- GO
-- ALTER PROCEDURE [dbo].[Sp_VTEX_InsertarProductosSincronizar]
-- AS
-- BEGIN
	DECLARE	@nombre_conexion	VARCHAR(250), 
			@conexion			VARCHAR(2500);

	EXEC [Sp_VTEX_ConfiguracionesInterface]
		@nombre_conexion	OUTPUT, 
		@conexion			OUTPUT;

    DECLARE @productos_sincronizado TABLE (
        RefId   VARCHAR(10)
    );

    INSERT INTO @productos_sincronizado
	SELECT 
		RefId
	FROM [VTEX-ProductosSincronizados]
	WHERE
		RefId <> ''

    DECLARE @productos_erp  TABLE(
        f120_id             VARCHAR(20),
		f120_descripcion    VARCHAR(2000),
		f106_15_notas		VARCHAR(2000),
		f106_10_notas       VARCHAR(2000),
		f106_60_notas		VARCHAR(2000),
		f753_des_dato_texto	VARCHAR(2000),
		f753_dec_dato_texto	VARCHAR(2000),
		f753_key_dato_texto	VARCHAR(2000)
    );

    INSERT INTO @productos_erp
	EXEC('
		SELECT DISTINCT
			f120_id,
			f120_descripcion,
			f106_15_notas		=	t106_15.f106_notas,
			f106_10_notas       =	t106_10.f106_notas,
			f106_60_notas		=	t106_60.f106_notas,
			f753_des_dato_texto	=	t753_DES.f753_dato_texto,
			f753_dec_dato_texto	=	t753_DEC.f753_dato_texto,
			f753_key_dato_texto	=	t753_KEY.f753_dato_texto
		FROM OPENROWSET(
			''SQLNCLI'', 
			'+@conexion+',
			['+@nombre_conexion+'].dbo.t120_mc_items
		)
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t121_mc_items_extensiones
			)
				ON
					f120_rowid	=	f121_rowid_item
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t125_mc_items_criterios
			)	t125_10
				ON
					f120_id_cia	=	t125_10.f125_id_cia
					AND	
					f120_rowid	=	t125_10.f125_rowid_item
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t105_mc_criterios_item_planes
			)	t105_10	
				ON
					t105_10.f105_id_cia	=	t125_10.f125_id_cia
					AND	
					t105_10.f105_id		=	t125_10.f125_id_plan
					AND	
					t105_10.f105_id		=	''10''
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t106_mc_criterios_item_mayores
			)	t106_10	
				ON
					t106_10.f106_id_cia		=	t125_10.f125_id_cia	
					AND	
					t106_10.f106_id			=	t125_10.f125_id_criterio_mayor	
					AND	
					t106_10.f106_id_plan	=	t125_10.f125_id_plan
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t125_mc_items_criterios
			)	t125_15	
				ON	
                    f120_id_cia	    =	t125_15.f125_id_cia
					AND	
                    f120_rowid		=	t125_15.f125_rowid_item
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t105_mc_criterios_item_planes
			)	t105_15	
				ON
					t105_15.f105_id_cia	=	t125_15.f125_id_cia
					AND	
					t105_15.f105_id		=	t125_15.f125_id_plan
					AND	
					t105_15.f105_id		=	''15''
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t106_mc_criterios_item_mayores
			)	t106_15		
                ON	
                    t106_15.f106_id_cia		=	t125_15.f125_id_cia
					AND	
                    t106_15.f106_id			=	t125_15.f125_id_criterio_mayor
					AND	
                    t106_15.f106_id_plan	=	t125_15.f125_id_plan

			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t125_mc_items_criterios
            )	t125_60	
                    ON
                        f120_id_cia	=	t125_60.f125_id_cia
						AND	
                        f120_rowid	=	t125_60.f125_rowid_item
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t105_mc_criterios_item_planes
            )	t105_60		
                    ON	
                        t105_60.f105_id_cia	=	t125_60.f125_id_cia
                        AND	
                        t105_60.f105_id		=	t125_60.f125_id_plan
                        AND	
                        t105_60.f105_id		=	''60''
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t106_mc_criterios_item_mayores
            )	t106_60		
                    ON	
                        t106_60.f106_id_cia		=	t125_60.f125_id_cia
						AND	
                        t106_60.f106_id			=	t125_60.f125_id_criterio_mayor
						AND	
                        t106_60.f106_id_plan	=	t125_60.f125_id_plan

		    INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t125_mc_items_criterios
            )	t125_VTX	
                    ON	
                        f120_id_cia =   t125_VTX.f125_id_cia
                        AND	
                        f120_rowid	=   t125_VTX.f125_rowid_item
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t105_mc_criterios_item_planes
            )	t105_VTX	
                    ON	
                        t105_VTX.f105_id_cia    =	t125_VTX.f125_id_cia
                        AND	
                        t105_VTX.f105_id		=	t125_VTX.f125_id_plan
                        AND	
                        t105_VTX.f105_id		=	''VTX''
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t106_mc_criterios_item_mayores
            )	t106_VTX	
                    ON	
                        t106_VTX.f106_id_cia	=	t125_VTX.f125_id_cia
					    AND	
                        t106_VTX.f106_id		=	t125_VTX.f125_id_criterio_mayor
					    AND	
                        t106_VTX.f106_id_plan	=	t125_VTX.f125_id_plan

			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t750_mm_movto_entidad
            )	t750_DES	
                    ON	
                        t750_DES.f750_rowid	=	f120_rowid_movto_entidad
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t752_mm_movto_entidad_fila
            )	t752_DES
                ON
                    t750_DES.f750_rowid	=	t752_DES.f752_rowid_movto_entidad
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t753_mm_movto_entidad_columna
			)	t753_DES
                ON	
                    t752_DES.f752_rowid	=	t753_DES.f753_rowid_movto_entidad_fila
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t743_mm_entidad_atributo
			)	t743_DES
                ON
                    t743_DES.f743_rowid	=	t753_DES.f753_rowid_entidad_atributo
                    AND	
                    t743_DES.f743_id	=	''RappiDescrip''
            INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t750_mm_movto_entidad
            )	t750_DEC
                ON
                    t750_DEC.f750_rowid	=	f120_rowid_movto_entidad
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t752_mm_movto_entidad_fila
            )	t752_DEC	
                ON
                    t750_DEC.f750_rowid	=	t752_DEC.f752_rowid_movto_entidad
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t753_mm_movto_entidad_columna
            )	t753_DEC
                ON
                    t752_DEC.f752_rowid	=	t753_DEC.f753_rowid_movto_entidad_fila
            INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t743_mm_entidad_atributo
            )	t743_DEC	
                ON	
                    t743_DEC.f743_rowid	=	t753_DEC.f753_rowid_entidad_atributo
					AND
                    t743_DEC.f743_id	=	''RappiDescripCorta''
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t750_mm_movto_entidad
            )	t750_KEY
                ON	
                    t750_KEY.f750_rowid	=	f120_rowid_movto_entidad
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t752_mm_movto_entidad_fila
            )	t752_KEY	
                ON	
                    t750_KEY.f750_rowid	=	t752_KEY.f752_rowid_movto_entidad
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t753_mm_movto_entidad_columna
            )   t753_KEY	
                ON
                    t752_KEY.f752_rowid	=	t753_KEY.f753_rowid_movto_entidad_fila
			INNER JOIN	OPENROWSET(
				''SQLNCLI'', 
				'+@conexion+',
				['+@nombre_conexion+'].dbo.t743_mm_entidad_atributo
            )	t743_KEY	
                ON
                    t743_KEY.f743_rowid	=	t753_KEY.f753_rowid_entidad_atributo
				    AND	
                    t743_KEY.f743_id	=	''VtexPalabrasClave''
			WHERE
			    f120_id_cia = 1
			    AND (
                    SELECT TOP 1 
                        id 
                    FROM category 
                    WHERE 
                        dbo.fn_remove_special_characters(name) = dbo.fn_remove_special_characters(t106_15.f106_descripcion)
                ) IS NOT NULL
			ORDER BY f120_id
	')

	SELECT
		f120_id,
        IdTienda            =   1,
        name                =   TRIM(f120_descripcion),
		DepartmentId	    =	CAST(f106_15_notas AS INT),
		CategoryId		    =	CAST(f106_10_notas AS INT),
		BrandId			    =	CAST(f106_60_notas AS INT),
        LinkId			    =	
            LOWER(
                REPLACE(
                    TRIM(f120_descripcion), 
                    ' ', 
                    '-'
                )
            ),
		RefId				=
            RIGHT(
                '0000000' + LTRIM(
                    RTRIM(f120_id)
                ),
                7
            ),
		isVisible			=	CAST(0 AS BIT),
		Description			=	ISNULL(f753_des_dato_texto, ''),
		DescriptionShort	=
            RTRIM(
                LTRIM(
                    ISNULL(f753_dec_dato_texto, '')
                )
            ),
		ReleaseDate			=	'',
		KeyWords			=
            ISNULL(
                REPLACE(
                    f753_key_dato_texto, 
                    '-', 
                    ''
                ), 
                ''
            ),
		Title				=	TRIM(f120_descripcion),
		isActive			=	CAST(0 AS BIT),
		TaxCode				=	'',
		MetaTagDescription	=	'',
		SupplierId			=	'',
		ShowWithoutStock	=	CAST(0 AS BIT),
		Score				=	1,
		TradePolicyId		=	'1',
		json	=	(
			SELECT
				Name				=	CONVERT(VARCHAR(MAX),TRIM(f120_descripcion)),
				DepartmentId		=	NULLIF(CONVERT(INT,f106_15_notas), ''),
				CategoryId			=	NULLIF(CONVERT(INT,f106_10_notas), ''),
				BrandId				=	NULLIF(CONVERT(INT,f106_60_notas), ''),
				LinkId				=	
                    CONVERT(
                        VARCHAR(MAX),
                        LOWER(
                            REPLACE(
                                TRIM(f120_descripcion), 
                                ' ', 
                                '-'
                            )
                        )
                    ),
				RefId				=
                    CONVERT(
                        VARCHAR(MAX),
                        RIGHT(
                            '0000000' + LTRIM(
                                RTRIM(f120_id)
                            ),
                            7
                        )
                    ),
				IsVisible			=	CAST(0 AS BIT),
				Description			=	
					CONVERT(
						VARCHAR(MAX),
						REPLACE(
							REPLACE(
								CAST(
									ISNULL(f753_des_dato_texto, '') AS VARCHAR(MAX)
								), 
								CHAR(13), 
								''
							), 
							CHAR(10), 
							''
						)
					),
				DescriptionShort	=	
					CONVERT(
						VARCHAR(MAX),
						REPLACE(
							REPLACE(
								CAST(
									RTRIM(LTRIM(ISNULL(f753_dec_dato_texto, ''))) AS VARCHAR(MAX)
								), 
								CHAR(13), 
								''
							), 
							CHAR(10), 
							''
						)
					),
				ReleaseDate			=	'',
				KeyWords			=
					CONVERT(
						VARCHAR(MAX),
						REPLACE(
							REPLACE(
								CAST(
									ISNULL(REPLACE(f753_key_dato_texto, '-', ''), '') AS VARCHAR(MAX)
								), 
								CHAR(13), 
								''
							), 
							CHAR(10), 
							''
						)
					),
				Title				=
					CONVERT(
						VARCHAR(MAX),
						REPLACE(
							REPLACE(
								CAST(
									TRIM(f120_descripcion) AS VARCHAR(MAX)
								), 
								CHAR(13), 
								''
							), 
							CHAR(10), 
							''
						) 
					),
				IsActive			=	CAST(0 AS BIT),
				TaxCode				=	'',
				MetaTagDescription	=	'',
				SupplierId			=	'',
				ShowWithoutStock	=	CAST(0 AS BIT),
				Score				=	1
			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		)
	FROM @productos_erp
	WHERE
		RIGHT('0000000'+Ltrim(Rtrim(f120_id)),7) NOT IN (SELECT RefId FROM @productos_sincronizado)
-- END
-- GO
