BEGIN TRY
	--->	AJUSTAR CON LOS PARAMETROS DE TU CONECTOR.
	DECLARE @id_documento			INT			    =	222302,
			@descripcion_conector	VARCHAR(100)	=	'TecnoPlaza_Terceros',
			@indica_paralelismo		BIT			    =	1;

	--->	DEFINIR LA TABLA PARA RETORNAR DATOS
	DECLARE	@final	TABLE 
	(
		idDocumento			INT,
		indicaParalelismo	BIT,
		descripcion			VARCHAR(100),
		idOrden				VARCHAR(100),
		json				VARCHAR(MAX)
	);

	--->	ACTUALIZAR ESTADO A 5 ORDENES EN ESTADO 2 QUE TENGAN UNA FECHA ANTERIOR A 2025-11-26
	UPDATE Orders
	SET
		idEstado	=	5
	WHERE 
		SWITCHOFFSET(
			TRY_CONVERT(
				datetimeoffset, 
				JSON_VALUE(Order_jsonApi, '$.createdAt')
			),
			DATENAME(
				TzOffset, 
				SYSDATETIMEOFFSET()
			)
		)	<	'2025-11-26T15:00:00'
		AND 
		idEstado	=	2
		AND 
		intentos	=	0;
	
	DECLARE	@ordenes	TABLE
	(
		IdOrder				NVARCHAR(100),
		Order_jsonApi		NVARCHAR(MAX),
		Orden				INT,
		documentoTer		NVARCHAR(100),
		tipoDocTer			NVARCHAR(100),
		tipoTercero			NVARCHAR(100),
		nombreCompletoTer	NVARCHAR(200),
		nombreTer			NVARCHAR(200),
		apellidoTer			NVARCHAR(100),
		emailTer			NVARCHAR(100),
		direccionUno		NVARCHAR(200),
		direccionDos		NVARCHAR(300),
		celularTer			NVARCHAR(100),
		paisTer				NVARCHAR(100),
		stateTer			NVARCHAR(100),
		ciudadTer			NVARCHAR(100),
		origen				NVARCHAR(100)
	);

	INSERT INTO @ordenes
	SELECT	TOP 25
		[IdOrder]			=	IdOrder,
		[Order_jsonApi]		=	Order_jsonApi,
		[Orden]				=	ROW_NUMBER() OVER (ORDER BY (SELECT IdOrder)),
		--Datos Tercero
		[documentoTer]		=	dbo.OnlyNumbers(JSON_VALUE(Order_jsonApi, '$.Client.taxId')),
		[tipoDocTer]		=	JSON_VALUE(Order_jsonApi, '$.Client.type'),
		[tipoTercero]		=
			CASE
				WHEN
					JSON_VALUE(Order_jsonApi, '$.Client.taxId')	LIKE	'[789]%'
					AND
					LEN(
						JSON_VALUE(Order_jsonApi, '$.Client.taxId')
					)	>=	10
					THEN	2
				ELSE	1
			END,
		[nombreCompletoTer]	=	REPLACE(JSON_VALUE(Order_jsonApi, '$.Client.fullName'),'&',''),
		[nombreTer]			=	REPLACE(JSON_VALUE(Order_jsonApi, '$.Client.name'),'&',''),
		[apellidoTer]		=	REPLACE(JSON_VALUE(Order_jsonApi, '$.Client.lastName'),'&',''),
		[emailTer]			=	JSON_VALUE(Order_jsonApi, '$.Client.email'),
		[direccionUno]		=	JSON_VALUE(Order_jsonApi, '$.Client.BillingAddresses[0].address_1'),
		[direccionDos]		=	JSON_VALUE(Order_jsonApi, '$.Client.BillingAddresses[0].address_2'),
		[celularTer]		=	JSON_VALUE(Order_jsonApi, '$.Client.phoneNumber'),
		[paisTer]			=	JSON_VALUE(Order_jsonApi, '$.Client.BillingAddresses[0].city'),
		[stateTer]			=	JSON_VALUE(Order_jsonApi, '$.Client.BillingAddresses[0].state'),
		[ciudadTer]			=	JSON_VALUE(Order_jsonApi, '$.Client.BillingAddresses[0].country'),
		[origen]			=	JSON_VALUE(Order_jsonApi, '$.origin')
	FROM Orders
	WHERE
		IdEstado	=	2
		AND
		Intentos	<=	3
		-- AND
		-- IdOrder = '9aafdf7c-5920-41ee-9c1e-6c12620682f1';

	DECLARE @terceros	TABLE
	(
		F200_ID					NVARCHAR(100),
	    F200_NIT				NVARCHAR(100),
		F200_ID_TIPO_IDENT		NVARCHAR(1),
		F200_IND_TIPO_TERCERO	NVARCHAR(1), 
		F200_RAZON_SOCIAL		NVARCHAR(200),
		F200_APELLIDO1			NVARCHAR(200),
		F200_APELLIDO2			NVARCHAR(200),
		F200_NOMBRES			NVARCHAR(200),
		F015_CONTACTO			NVARCHAR(200),
		F015_DIRECCION1			NVARCHAR(200),
		F015_DIRECCION2			NVARCHAR(200),
		F015_ID_PAIS			NVARCHAR(3),
		F015_ID_DEPTO			NVARCHAR(2),
		F015_ID_CIUDAD			NVARCHAR(3),
		F015_TELEFONO			NVARCHAR(200),
		F015_EMAIL				NVARCHAR(300),
		F200_FECHA_NACIMIENTO	NVARCHAR(8),
		F015_CELULAR			NVARCHAR(10)
	);

	DECLARE	@cliente	TABLE
	(
		F201_ID_TERCERO				NVARCHAR(100),
		F201_DESCRIPCION_SUCURSAL	NVARCHAR(100),
		F201_ID_VENDEDOR			NVARCHAR(100),
		F015_CONTACTO				NVARCHAR(100),
		F015_DIRECCION1				NVARCHAR(300),
		F015_DIRECCION2				NVARCHAR(300),
		F015_ID_PAIS				NVARCHAR(3),
		F015_ID_DEPTO				NVARCHAR(2),
		F015_ID_CIUDAD				NVARCHAR(3),
		F015_TELEFONO				NVARCHAR(25),
		F015_EMAIL					NVARCHAR(255),
		F201_FECHA_INGRESO			NVARCHAR(8),
		f015_celular				NVARCHAR(20)
	);

	IF OBJECT_ID('tempdb..#company_impuestos') IS NOT NULL DROP TABLE #company_impuestos;
	IF OBJECT_ID('tempdb..#company_criterios') IS NOT NULL DROP TABLE #company_criterios;
	IF OBJECT_ID('tempdb..#company_entidadTercero') IS NOT NULL DROP TABLE #company_entidadTercero;
	IF OBJECT_ID('tempdb..#company_entidadCliente')	IS NOT NULL DROP TABLE #company_entidadCliente;

	--->	VARIABLES GENERALES
	DECLARE @pais_siesa		NVARCHAR(3),
			@dpto_siesa		NVARCHAR(3),
			@ciudad_siesa	NVARCHAR(3);

	DECLARE @json			NVARCHAR(MAX) = '';
	DECLARE @counter		INT = 1;
	DECLARE @total			INT;
	DECLARE @order			VARCHAR(50);
	DECLARE @conexion		NVARCHAR(MAX)	=	(SELECT TOP 1 cadena_conexion FROM Conexiones)
	DECLARE @base_datos		NVARCHAR(MAX)	=	(SELECT TOP 1 base_datos FROM Conexiones);

	SET @total = (SELECT COUNT(*) FROM @ordenes);
	WHILE @counter <= @total
	BEGIN
		BEGIN TRY
			DECLARE @id_tercero		NVARCHAR(100)	=	NULL;
			--Obtenemos el id de la orden y el tercero
			SELECT
				@order		=	IdOrder, 
	       		@id_tercero	=
					CASE
						WHEN	tipoTercero	=	2 
							THEN
								CASE
									WHEN	LEN(documentoTer)	>	9
										THEN	LEFT(documentoTer, 9)
									ELSE documentoTer
								END 
						ELSE	documentoTer
					END
			FROM @ordenes
			WHERE
				Orden	=	@counter;

			--->	Obtenemos Pais-Departamento-Ciudad
			DECLARE @total_registro_pais	INT;

			--->	Contamos cuántos registros coinciden por país
			SELECT
				@total_registro_pais	=	COUNT(*)
			FROM locaciones_erp
			WHERE
				f013_descripcion	=
					(
						SELECT TOP 1
							UPPER(paisTer)
						FROM @ordenes
						WHERE
							Orden	=	@counter
					);

			--->	Si hay más de un registro, se agrega el filtro adicional por departamento (stateTer)
			IF @total_registro_pais >= 2
			BEGIN
				SELECT 
					@pais_siesa   = f013_id_pais,
					@dpto_siesa   = f013_id_depto,
					@ciudad_siesa = f013_id
				FROM locaciones_erp
				WHERE
					f013_descripcion	=	(
						SELECT TOP 1 
							UPPER(paisTer)
						FROM @ordenes
						WHERE
							Orden	=	@counter
					)
					AND 
					f012_descripcion	=	(
						SELECT TOP 1 
							UPPER(stateTer)
						FROM @ordenes
						WHERE
							Orden	=	@counter
					);
			END
			ELSE IF	@total_registro_pais	=	0
			BEGIN
				SELECT 
					@pais_siesa   = f013_id_pais,
					@dpto_siesa   = f013_id_depto,
					@ciudad_siesa = f013_id
				FROM locaciones_erp
				WHERE
					REPLACE(
						f013_descripcion,
						'Bogotá, D.C.',
						'Bogotá D.C.'
					)	=	(
						SELECT TOP 1 
							UPPER(stateTer)
						FROM @ordenes
						WHERE
							Orden	=	@counter
					);
			END
			ELSE
			BEGIN
				SELECT 
					@pais_siesa   = f013_id_pais,
					@dpto_siesa   = f013_id_depto,
					@ciudad_siesa = f013_id
				FROM locaciones_erp
				WHERE
					f013_descripcion	=	(
						SELECT TOP 1 
							UPPER(paisTer)
						FROM @ordenes
						WHERE
							Orden	=	@counter
					);
			END

			--->	TERCEROS
			INSERT INTO @terceros
			(
				F200_ID,
				F200_NIT,
				F200_ID_TIPO_IDENT,
				F200_IND_TIPO_TERCERO, 
				F200_RAZON_SOCIAL,
				F200_APELLIDO1,
				F200_APELLIDO2,
				F200_NOMBRES,
				F015_CONTACTO,
				F015_DIRECCION1,
				F015_DIRECCION2,
				F015_ID_PAIS,
				F015_ID_DEPTO,
				F015_ID_CIUDAD,
				F015_TELEFONO,
				F015_EMAIL,
				F200_FECHA_NACIMIENTO,
				F015_CELULAR
			)
			SELECT
				[F200_ID]				=	@id_tercero,
				[F200_NIT]				=	@id_tercero,
				[F200_ID_TIPO_IDENT]	=	
					CASE
						WHEN	tipoTercero	=	'1'
							THEN	'C'
						ELSE	'N'
					END,
				[F200_IND_TIPO_TERCERO]	=
					CASE
						WHEN	tipoTercero	=	'1'
							THEN	'1'
						ELSE	'2'
					END,
				[F200_RAZON_SOCIAL]		=
					CASE
						WHEN	tipoTercero	=	'1'
							THEN	''
						ELSE	UPPER(nombreTer)
					END,
				[F200_APELLIDO1]		=
					CASE
						WHEN	tipoTercero	=	'1'
							THEN
								CASE
									WHEN
										LEN(
											ISNULL(
												LEFT(
													UPPER(apellidoTer), 
													CHARINDEX(
														' ', 
														UPPER(apellidoTer) + ' '
													) - 1
												),
												''
											)
										)	>	29 
										THEN
											ISNULL(
												LEFT(
													ISNULL(
														LEFT(
															UPPER(apellidoTer), 
															CHARINDEX(
																' ', 
																UPPER(apellidoTer) + ' '
															) - 1
														),
														''
													), 
													29
												),
												''
											)
									ELSE
										ISNULL(
											ISNULL(
												LEFT(
													UPPER(apellidoTer), 
													CHARINDEX(
														' ', 
														UPPER(apellidoTer) + ' '
													) - 1
												),
												''
											),
											''
										)
								END
						ELSE	''
					END,
				[F200_APELLIDO2]		=
					CASE
						WHEN	tipoTercero	=	'1' 
							THEN
								CASE
									WHEN
										LEN(
											ISNULL(
												LTRIM(
													SUBSTRING(
														UPPER(apellidoTer), 
														CHARINDEX(
															' ', 
															UPPER(apellidoTer) + ' '
														) + 1, 
														LEN(
															UPPER(apellidoTer)
														)
													)
												),
												''
											)
										)	>	29
										THEN
											ISNULL(
												LEFT(
													ISNULL(
														LTRIM(
															SUBSTRING(
																UPPER(apellidoTer), 
																CHARINDEX(
																	' ', 
																	UPPER(apellidoTer) + ' '
																) + 1, 
																LEN(
																	UPPER(apellidoTer)
																)
															)
														),
														''
													), 
													29
												),
												''
											)
									ELSE
										ISNULL(
											ISNULL(
												LTRIM(
													SUBSTRING(
														UPPER(apellidoTer), 
														CHARINDEX(
															' ', 
															UPPER(apellidoTer) + ' '
														) + 1, 
														LEN(
															UPPER(apellidoTer)
														)
													)
												),
												''
											),
											''
										)
								END
						ELSE	''
					END,
				[F200_NOMBRES]			=
					CASE
						WHEN	tipoTercero	=	'1'
							THEN
								CASE 
									WHEN	LEN(UPPER(nombreTer))	> 40
										THEN
											ISNULL(
												LEFT(
													UPPER(nombreTer), 
													40
												),
												''
											)
									ELSE
										ISNULL(UPPER(nombreTer),'')
								END
						ELSE	''
					END,
				[F015_CONTACTO]			=
					CASE
						WHEN	tipoTercero	=	'1'
							THEN
								CASE
									WHEN	LEN(UPPER(nombreCompletoTer))	>	50
										THEN	ISNULL(LEFT(UPPER(nombreCompletoTer), 50),'')
									ELSE	ISNULL(UPPER(nombreCompletoTer),'')
								END
						ELSE
							CASE
								WHEN	LEN(UPPER(nombreTer)) > 50
									THEN	ISNULL(LEFT(UPPER(nombreTer), 50),'')
								ELSE	ISNULL(UPPER(nombreTer),'')
							END
					END,
				[F015_DIRECCION1]		=
					CASE
						WHEN	LEN(UPPER(direccionUno)) > 40
							THEN	ISNULL(LEFT(UPPER(direccionUno), 40),'')
						ELSE	ISNULL(UPPER(direccionUno),'')
					END,
				[F015_DIRECCION2]		=
					CASE
						WHEN	LEN(UPPER(direccionDos)) > 40
							THEN	ISNULL(LEFT(UPPER(direccionDos), 40),'')
						ELSE	ISNULL(UPPER(direccionDos),'')
					END,
				[F015_ID_PAIS]			=	ISNULL(@pais_siesa, '169'),
				[F015_ID_DEPTO]			=	ISNULL(@dpto_siesa, '76'),
				[F015_ID_CIUDAD]		=   ISNULL(@ciudad_siesa, '999'),
				[F015_TELEFONO]			=
					ISNULL(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										UPPER(celularTer), 
										'#', 
										''
									), 
									'X', 
									''
								), 
								'+57', 
								''
							), 
							' ', 
							''
						), 
						''
					),
				[F015_EMAIL]			=
					CASE
						WHEN	origen	=	'mercadolibre'
							THEN
								CASE
									WHEN	ISNULL(emailTer, '') = ''
										THEN	'tpfe1@outlook.com' 
									ELSE	ISNULL(emailTer, '') 
								END
						ELSE	ISNULL(emailTer, '')
					END,
				[F200_FECHA_NACIMIENTO]	=   CONVERT(VARCHAR, GETDATE(), 112),
				[F015_CELULAR]			=
					ISNULL(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										UPPER(celularTer), 
										'#', 
										''
									), 
									'X', 
									''
								), 
								'+57', 
								''
							), 
							' ', 
							''
						), 
						''
					)
			FROM @ordenes
			WHERE
				Orden	=	@counter;

			-- CLIENTES
			INSERT INTO @cliente
			SELECT 
				[F201_ID_TERCERO]	=	@id_tercero,
				CASE 
					WHEN	tipoTercero	=	'1' 
						THEN 
							CASE 
								WHEN	LEN(UPPER(nombreCompletoTer)) > 40 
									THEN	ISNULL(LEFT(UPPER(nombreCompletoTer), 40),'')
								ELSE	ISNULL(UPPER(nombreCompletoTer),'')
							END                                                                            
					ELSE 
						CASE 
							WHEN LEN(UPPER(nombreTer)) > 40 
								THEN ISNULL(LEFT(UPPER(nombreTer), 40),'')
							ELSE ISNULL(UPPER(nombreTer),'')
						END 
				END	AS	F201_DESCRIPCION_SUCURSAL,
				CASE	origen
					WHEN	'shopify'
						THEN	'9999'
					WHEN	'fcom'
						THEN	'0102'
					WHEN	'mercadolibre' 
						THEN	'0100'
				END																              AS	F201_ID_VENDEDOR,
				CASE
					WHEN	tipoTercero	=	'1' 
						THEN
							CASE
								WHEN	LEN(UPPER(nombreCompletoTer)) > 50 
									THEN	ISNULL(LEFT(UPPER(nombreCompletoTer), 50),'')
								ELSE	ISNULL(UPPER(nombreCompletoTer),'')
						END                                                                            
						ELSE 
							CASE 
								WHEN LEN(UPPER(nombreTer)) > 50 
									THEN ISNULL(LEFT(UPPER(nombreTer), 50),'')
								ELSE ISNULL(UPPER(nombreTer),'')
							END 
				END                                                                           AS    F015_CONTACTO,
				CASE 
					WHEN LEN(UPPER(direccionUno)) > 40 
						THEN ISNULL(LEFT(UPPER(direccionUno), 40),'')
					ELSE ISNULL(UPPER(direccionUno),'')
				END	                                                                          AS	F015_DIRECCION1,
				CASE 
					WHEN LEN(UPPER(direccionDos)) > 40 
						THEN ISNULL(LEFT(UPPER(direccionDos), 40),'')
					ELSE ISNULL(UPPER(direccionDos),'')
				END 	                                                                      AS	F015_DIRECCION2,
				ISNULL(@pais_siesa, '169')		                                              AS	F015_ID_PAIS,
				ISNULL(@dpto_siesa, '76')			                                          AS	F015_ID_DEPTO,
				ISNULL(@ciudad_siesa, '999')		                                              AS	F015_ID_CIUDAD,
				ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(celularTer), '#', ''), 'X', ''), '+57', ''), ' ', ''), '')       	  AS	F015_TELEFONO,
				CASE 
					WHEN origen = 'mercadolibre' THEN 
						CASE 
							WHEN ISNULL(emailTer, '') = '' THEN 'tpfe1@outlook.com' 
							ELSE ISNULL(emailTer, '') 
						END
					ELSE ISNULL(emailTer, '')						
				END														                      AS	F015_EMAIL,
				CONVERT(VARCHAR, GETDATE(), 112)								              AS	F201_FECHA_INGRESO,
				ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(celularTer), '#', ''), 'X', ''), '+57', ''), ' ', ''), '')		      AS	f015_celular
			FROM @ordenes
			WHERE 
				Orden	=	@counter;

			--Creamos la tabla de los impuestos
			CREATE TABLE #company_impuestos (
				F_TIPO_REG         VARCHAR(255),
				F_ID_TERCERO       VARCHAR(255),
				F_ID_CLASE         VARCHAR(255),
				F_ID_VALOR_TERCERO VARCHAR(255)
			);

			-- IMPUESTOS Y RETENCIONES
			INSERT INTO #company_impuestos (
				F_TIPO_REG,
				F_ID_TERCERO,
				F_ID_CLASE
			)
			SELECT 
				'46'		AS	F_TIPO_REG,
				@id_tercero	AS	F_ID_TERCERO,
				'1'			AS	F_ID_CLASE
			UNION ALL
			SELECT 
				'47'		AS	F_TIPO_REG,
				@id_tercero	AS	F_ID_TERCERO,
				'41'		AS	F_ID_CLASE

			--Creamos la tabla de los Criterios Clasificacion
			CREATE TABLE #company_criterios (
				F207_ID_TERCERO        VARCHAR(255),
				F207_ID_CRITERIO_MAYOR VARCHAR(255)
			);
			
			-- CRITERIOS CLASIFICACION
	  		INSERT INTO #company_criterios (
				F207_ID_TERCERO,
				F207_ID_CRITERIO_MAYOR
	  		)
	  		SELECT
				@id_tercero														                  AS	F207_ID_TERCERO,
				CASE origen
					WHEN 'shopify' THEN '107'
					WHEN 'fcom' THEN '102'
					WHEN 'mercadolibre' THEN '101'
				END                                                                             AS    F207_ID_CRITERIO_MAYOR
			FROM @ordenes
      		WHERE
				Orden = @counter;

	  		--ENT. DINAMICA TERCERO
			CREATE TABLE #company_entidadTercero (
				f200_id                 VARCHAR(255),
				f753_id_entidad         VARCHAR(255),
				f753_id_atributo        VARCHAR(255),
				f753_id_maestro         VARCHAR(255),
				f753_id_maestro_detalle VARCHAR(255)
			);

			INSERT INTO #company_entidadTercero (
				f200_id,
				f753_id_entidad,
				f753_id_atributo,
				f753_id_maestro,
				f753_id_maestro_detalle
			)
			SELECT
				@id_tercero													                      AS	f200_id,
				'EUNOECO017'                                                                     AS    f753_id_entidad,
				'co017_codigo_regimen'                                                           AS    f753_id_atributo,
				'MUNOECO016'														              AS	f753_id_maestro,
				CASE WHEN tipoTercero = '1' THEN '49' ELSE '48' END						  AS	f753_id_maestro_detalle
			FROM @ordenes
			WHERE Orden = @counter
			UNION ALL
			SELECT
				@id_tercero													                      AS	f200_id,
				'EUNOECO031'                                                                     AS    f753_id_entidad,
				'co031_detalle_tributario1'                                                      AS    f753_id_atributo,
				'MUNOECO035'														              AS	f753_id_maestro,
				CASE WHEN tipoTercero = '1' THEN 'ZZ' ELSE '01' END						  AS	f753_id_maestro_detalle
			FROM @ordenes
			WHERE Orden = @counter;

			-- ENT. DINAMICAS CLIENTE
			CREATE TABLE #company_entidadCliente(
				f201_id_tercero         VARCHAR(255),
				f201_id_sucursal        VARCHAR(255),
				f753_id_entidad         VARCHAR(255),
				f753_id_atributo        VARCHAR(255),
				f753_id_maestro         VARCHAR(255),
				f753_id_maestro_detalle VARCHAR(255)
			);

			INSERT INTO #company_entidadCliente (
				f201_id_tercero,
				f753_id_entidad,
				f753_id_atributo,
				f753_id_maestro,
				f753_id_maestro_detalle
			)
			SELECT
				@id_tercero													                      AS	f201_id_tercero,
				'EUNOECO017'                                                                     AS    f753_id_entidad,
				'co017_codigo_regimen'                                                           AS    f753_id_atributo,
				'MUNOECO016'														              AS	f753_id_maestro,
				CASE WHEN tipoTercero = '1' THEN '49' ELSE '48' END						  AS	f753_id_maestro_detalle
			FROM @ordenes
			WHERE 
				Orden	=	@counter
			UNION ALL
			SELECT
				@id_tercero													                      AS	f201_id_tercero,
				'EUNOECO031'                                                                     AS    f753_id_entidad,
				'co031_detalle_tributario1'                                                      AS    f753_id_atributo,
				'MUNOECO035'														              AS	f753_id_maestro,
				CASE WHEN tipoTercero = '1' THEN 'ZZ' ELSE '01' END						  AS	f753_id_maestro_detalle
			FROM @ordenes
			WHERE Orden = @counter;

			---->	Construimos el json final para consumir
			INSERT INTO @final
			(
				idDocumento,
				descripcion,
				indicaParalelismo,
				idOrden,
				json
			)
			SELECT
				@id_documento,
				@descripcion_conector,
				@indica_paralelismo,
				@order					AS	idOrden,
				(
					SELECT
						[Terceros]				=	(
							SELECT * 
							FROM @terceros
							FOR JSON PATH
							,INCLUDE_NULL_VALUES
						),
						[Clientes]			=	(
							SELECT *
							FROM @cliente
							FOR JSON PATH
							,INCLUDE_NULL_VALUES
						),
						[ImptosReten]		=	(
							SELECT *
							FROM #company_impuestos
							FOR JSON PATH
							,INCLUDE_NULL_VALUES
						),
						[CriteriosClientes]	=	(
							SELECT *
							FROM #company_criterios
							FOR JSON PATH
							,INCLUDE_NULL_VALUES
						),
						[EntDinamicaTercero]	=	(
							SELECT *
							FROM #company_entidadTercero
							FOR JSON PATH
							,INCLUDE_NULL_VALUES
						),
						[EntDinamicaCliente]	=	(
							SELECT *
							FROM #company_entidadCliente
							FOR JSON PATH
							,INCLUDE_NULL_VALUES
						)
					FOR JSON PATH,
					WITHOUT_ARRAY_WRAPPER,
					INCLUDE_NULL_VALUES
				)
		END TRY
		BEGIN CATCH
		END CATCH
		DELETE @terceros;
		DELETE @cliente;
		IF OBJECT_ID('tempdb..#company_impuestos') IS NOT NULL DROP TABLE #company_impuestos;
		IF OBJECT_ID('tempdb..#company_criterios') IS NOT NULL DROP TABLE #company_criterios;
		IF OBJECT_ID('tempdb..#company_entidadTercero') IS NOT NULL DROP TABLE #company_entidadTercero;
		IF OBJECT_ID('tempdb..#company_entidadCliente')	IS NOT NULL DROP TABLE #company_entidadCliente;
		SET @counter = @counter + 1;
	END

	SELECT * from @final AS final_json;
END TRY
BEGIN CATCH
END CATCH
 