SET XACT_ABORT ON;

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
	
	DECLARE @ordenes_seleccionadas	TABLE
	(
		Id					INT,
		IdTienda			NVARCHAR(100),
		IdOrder				NVARCHAR(100),
		IdEstado			INT,
		Order_jsonWebhook	NVARCHAR(MAX),
		Order_jsonApi		NVARCHAR(MAX),
		FechaCreacion		DATETIME
	);

	INSERT INTO @ordenes_seleccionadas
	SELECT TOP 25
		Id,
		IdTienda,
		IdOrder,
		IdEstado,
		Order_jsonWebhook,
		Order_jsonApi,
		FechaCreacion
	FROM Orders
	WHERE
		IdEstado	=	2
		AND
		Intentos	<=	4
		AND
		(
			SWITCHOFFSET(
				TRY_CONVERT(datetimeoffset, JSON_VALUE(Order_jsonApi, '$.createdAt')),
				DATENAME(TzOffset, SYSDATETIMEOFFSET())
			) > 
			CASE
				WHEN   JSON_VALUE(Order_jsonApi, '$.Warehouse.name')   IN   ('Bodega Ingram', 'Bodega Online', 'Bodega Bogota') 
					THEN    
						CASE
							WHEN    DATEADD(DAY, -7, GETDATE()) <=   '2026-06-12 17:00:00'
								THEN    '2026-06-12 17:00:00'
							ELSE    DATEADD(DAY, -7, GETDATE())
						END
				WHEN      JSON_VALUE(Order_jsonApi, '$.Warehouse.name')   IN   ('FULL', 'FULL FALABELLA', 'FULL ML BOGOTA', 'FULL ML TIENDA OFICIAL') 
					THEN    DATEADD(DAY, -7, GETDATE())
				ELSE 
					CASE
						WHEN    DATEADD(DAY, -7, GETDATE()) <=   '2026-06-12 17:00:00'
							THEN    '2026-06-12 17:00:00'
						ELSE    DATEADD(DAY, -7, GETDATE())
					END
			END 
		)
		/*
		IdOrder IN ('4b7171e7-efe7-4803-b088-a71dddfc57ff', 'c52363f4-119d-4fe6-aaf7-41ca6941cf7f', '4aa792f0-ad1d-4082-9a3f-c932495937d7')
		*/
	ORDER BY ID DESC;
	
	DECLARE	@ordenes	TABLE
	(
		IdOrder				NVARCHAR(100),
		Order_jsonApi		NVARCHAR(MAX),
		Orden				INT,
		documentoTer		NVARCHAR(100),
		tipoDocTer			NVARCHAR(100),
		tipoTercero			INT,
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
		[Orden]				=	ROW_NUMBER() OVER (ORDER BY IdOrder),
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
					)	>=	9
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
	FROM @ordenes_seleccionadas;

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

	DECLARE @impuestos	TABLE
	(
		F_TIPO_REG         VARCHAR(4),
		F_ID_TERCERO       VARCHAR(255),
		F_ID_CLASE         VARCHAR(255)
	);

	DECLARE @criterios TABLE
	(
		F207_ID_TERCERO        VARCHAR(255),
		F207_ID_CRITERIO_MAYOR VARCHAR(255)
	);

	DECLARE @entidadTercero TABLE
	(
		f200_id                 VARCHAR(255),
		f753_id_entidad         VARCHAR(255),
		f753_id_atributo        VARCHAR(255),
		f753_id_maestro         VARCHAR(255),
		f753_id_maestro_detalle VARCHAR(255)
	);

	DECLARE @entidadCliente TABLE
	(
		f201_id_tercero         VARCHAR(255),
		f753_id_entidad         VARCHAR(255),
		f753_id_atributo        VARCHAR(255),
		f753_id_maestro         VARCHAR(255),
		f753_id_maestro_detalle VARCHAR(255)
	);

	--->	VARIABLES GENERALES
	DECLARE @pais_siesa		NVARCHAR(3),
			@dpto_siesa		NVARCHAR(3),
			@ciudad_siesa	NVARCHAR(3);

	DECLARE @counter		INT = 1;
	DECLARE @total			INT;
	DECLARE @order			VARCHAR(50);

	SET @total = (SELECT COUNT(*) FROM @ordenes);
	WHILE @counter <= @total
	BEGIN
		BEGIN TRY
			-- REINICIO OBLIGATORIO DE VARIABLES PARA EVITAR HERENCIA ENTRE ORDENES
			SET @pais_siesa   = NULL;
			SET @dpto_siesa   = NULL;
			SET @ciudad_siesa = NULL;

			DECLARE @id_tercero			NVARCHAR(100)	=	NULL;
			DECLARE @ciudadBuscada		NVARCHAR(200)	=	NULL;
			DECLARE @deptoBuscado		NVARCHAR(200)	=	NULL;
			DECLARE @apeClean			NVARCHAR(200)	=	NULL;
			DECLARE @posEspacio			INT				=	0;
			DECLARE @ape1				NVARCHAR(100)	=	'';
			DECLARE @ape2				NVARCHAR(100)	=	'';

			-- Obtenemos el id de la orden y el tercero
			SELECT
				@order			=	IdOrder, 
	       		@id_tercero		=
					CASE
						WHEN	tipoTercero	=	2 
							THEN
								CASE
									WHEN	LEN(documentoTer)	>	9
										THEN	LEFT(documentoTer, 9)
									ELSE documentoTer
								END 
						ELSE	documentoTer
					END,
				@ciudadBuscada	=	UPPER(TRIM(ISNULL(paisTer, ''))),
				@deptoBuscado	=	UPPER(TRIM(ISNULL(stateTer, ''))),
				@apeClean		=	LTRIM(RTRIM(ISNULL(apellidoTer, '')))
			FROM @ordenes
			WHERE
				Orden	=	@counter;

			-- División segura de apellidos sin riesgo de longitud negativa
			SET @posEspacio = CHARINDEX(' ', @apeClean);
			IF @posEspacio > 0
			BEGIN
				SET @ape1 = SUBSTRING(@apeClean, 1, @posEspacio - 1);
				SET @ape2 = LTRIM(SUBSTRING(@apeClean, @posEspacio + 1, LEN(@apeClean)));
			END
			ELSE
			BEGIN
				SET @ape1 = @apeClean;
				SET @ape2 = '';
			END;

			--->	Homologación Pais-Departamento-Ciudad con Collation Insensible a Tildes (CI_AI)
			-- 1. Coincidencia exacta de ciudad (y departamento si se suministra)
			SELECT TOP 1
				@pais_siesa   = f013_id_pais,
				@dpto_siesa   = f013_id_depto,
				@ciudad_siesa = f013_id
			FROM dbo.locaciones_erp
			WHERE
				f013_descripcion COLLATE Latin1_General_CI_AI = @ciudadBuscada
				AND (@deptoBuscado = '' OR f012_descripcion COLLATE Latin1_General_CI_AI = @deptoBuscado);

			-- 2. Coincidencia tolerante (ej: 'Bogotá, D.C.' vs 'BOGOTA', o departamento en ciudad)
			IF @ciudad_siesa IS NULL
			BEGIN
				SELECT TOP 1
					@pais_siesa   = f013_id_pais,
					@dpto_siesa   = f013_id_depto,
					@ciudad_siesa = f013_id
				FROM dbo.locaciones_erp
				WHERE
					REPLACE(REPLACE(f013_descripcion, ', D.C.', ''), ' D.C.', '') COLLATE Latin1_General_CI_AI = @ciudadBuscada
					OR
					f013_descripcion COLLATE Latin1_General_CI_AI = @ciudadBuscada
					OR
					(@deptoBuscado <> '' AND (
						f012_descripcion COLLATE Latin1_General_CI_AI = @ciudadBuscada
						OR REPLACE(REPLACE(f013_descripcion, ', D.C.', ''), ' D.C.', '') COLLATE Latin1_General_CI_AI = @deptoBuscado
					));
			END;

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
						WHEN	tipoTercero	=	1
							THEN	'C'
						ELSE	'N'
					END,
				[F200_IND_TIPO_TERCERO]	=
					CASE
						WHEN	tipoTercero	=	1
							THEN	'1'
						ELSE	'2'
					END,
				[F200_RAZON_SOCIAL]		=
					CASE
						WHEN	tipoTercero	=	1
							THEN	''
						ELSE	TRIM(LEFT(UPPER(nombreTer), 100))
					END,
				[F200_APELLIDO1]		=
					CASE
						WHEN	tipoTercero	=	1
							THEN	LEFT(UPPER(@ape1), 29)
						ELSE	''
					END,
				[F200_APELLIDO2]		=
					CASE
						WHEN	tipoTercero	=	1
							THEN	LEFT(UPPER(@ape2), 29)
						ELSE	''
					END,
				[F200_NOMBRES]			=
					CASE
						WHEN	tipoTercero	=	1
							THEN	LEFT(UPPER(nombreTer), 40)
						ELSE	''
					END,
				[F015_CONTACTO]			=
					CASE
						WHEN	tipoTercero	=	1
							THEN	LEFT(UPPER(nombreCompletoTer), 50)
						ELSE	LEFT(UPPER(nombreTer), 50)
					END,
				[F015_DIRECCION1]		=	LEFT(ISNULL(UPPER(direccionUno), ''), 40),
				[F015_DIRECCION2]		=	LEFT(ISNULL(UPPER(direccionDos), ''), 40),
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
					WHEN	tipoTercero	=	1 
						THEN	LEFT(ISNULL(UPPER(nombreCompletoTer), ''), 40)
					ELSE	LEFT(ISNULL(UPPER(nombreTer), ''), 40)
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
					WHEN	tipoTercero	=	1 
						THEN	LEFT(ISNULL(UPPER(nombreCompletoTer), ''), 50)
					ELSE	LEFT(ISNULL(UPPER(nombreTer), ''), 50)
				END                                                                           AS    F015_CONTACTO,
				LEFT(ISNULL(UPPER(direccionUno), ''), 40)	                                  AS	F015_DIRECCION1,
				LEFT(ISNULL(UPPER(direccionDos), ''), 40) 	                                  AS	F015_DIRECCION2,
				ISNULL(@pais_siesa, '169')		                                              AS	F015_ID_PAIS,
				ISNULL(@dpto_siesa, '76')			                                          AS	F015_ID_DEPTO,
				ISNULL(@ciudad_siesa, '999')		                                          AS	F015_ID_CIUDAD,
				ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(celularTer), '#', ''), 'X', ''), '+57', ''), ' ', ''), '') AS F015_TELEFONO,
				CASE 
					WHEN origen = 'mercadolibre' THEN 
						CASE 
							WHEN ISNULL(emailTer, '') = '' THEN 'tpfe1@outlook.com' 
							ELSE ISNULL(emailTer, '') 
						END
					ELSE ISNULL(emailTer, '')						
				END														                      AS	F015_EMAIL,
				CONVERT(VARCHAR, GETDATE(), 112)								              AS	F201_FECHA_INGRESO,
				ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(celularTer), '#', ''), 'X', ''), '+57', ''), ' ', ''), '') AS f015_celular
			FROM @ordenes
			WHERE 
				Orden	=	@counter;

			-- IMPUESTOS Y RETENCIONES
			INSERT INTO @impuestos (
				F_TIPO_REG,
				F_ID_TERCERO,
				F_ID_CLASE
			)
			SELECT
				F_TIPO_REG		=	'46',
				F_ID_TERCERO	=	@id_tercero,
				F_ID_CLASE		=	'1'
			UNION ALL
			SELECT
				F_TIPO_REG		=	'47',
				F_ID_TERCERO	= 	@id_tercero,
				F_ID_CLASE		=	'41';
			
			-- CRITERIOS CLASIFICACION
	  		INSERT INTO @criterios (
				F207_ID_TERCERO,
				F207_ID_CRITERIO_MAYOR
	  		)
	  		SELECT
				F207_ID_TERCERO			=	@id_tercero,
				F207_ID_CRITERIO_MAYOR	=	
					CASE origen
						WHEN	'shopify' 
							THEN	'107'
						WHEN	'fcom' 
							THEN	'102'
						WHEN	'mercadolibre' 
							THEN	'101'
					END
			FROM @ordenes
      		WHERE
				Orden = @counter;

			INSERT INTO @entidadTercero (
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
				CASE WHEN tipoTercero = 1 THEN '49' ELSE '48' END							      AS	f753_id_maestro_detalle
			FROM @ordenes
			WHERE Orden = @counter
			UNION ALL
			SELECT
				@id_tercero													                      AS	f200_id,
				'EUNOECO031'                                                                     AS    f753_id_entidad,
				'co031_detalle_tributario1'                                                      AS    f753_id_atributo,
				'MUNOECO035'														              AS	f753_id_maestro,
				CASE WHEN tipoTercero = 1 THEN 'ZZ' ELSE '01' END							      AS	f753_id_maestro_detalle
			FROM @ordenes
			WHERE Orden = @counter;

			INSERT INTO @entidadCliente (
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
				CASE WHEN tipoTercero = 1 THEN '49' ELSE '48' END							      AS	f753_id_maestro_detalle
			FROM @ordenes
			WHERE 
				Orden	=	@counter
			UNION ALL
			SELECT
				@id_tercero													                      AS	f201_id_tercero,
				'EUNOECO031'                                                                     AS    f753_id_entidad,
				'co031_detalle_tributario1'                                                      AS    f753_id_atributo,
				'MUNOECO035'														              AS	f753_id_maestro,
				CASE WHEN tipoTercero = 1 THEN 'ZZ' ELSE '01' END							      AS	f753_id_maestro_detalle
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
							FROM @impuestos
							FOR JSON PATH
							,INCLUDE_NULL_VALUES
						),
						[CriteriosClientes]	=	(
							SELECT *
							FROM @criterios
							FOR JSON PATH
							,INCLUDE_NULL_VALUES
						),
						[EntDinamicaTercero]	=	(
							SELECT *
							FROM @entidadTercero
							FOR JSON PATH
							,INCLUDE_NULL_VALUES
						),
						[EntDinamicaCliente]	=	(
							SELECT *
							FROM @entidadCliente
							FOR JSON PATH
							,INCLUDE_NULL_VALUES
						)
					FOR JSON PATH,
					WITHOUT_ARRAY_WRAPPER,
					INCLUDE_NULL_VALUES
				);
		END TRY
		BEGIN CATCH
			PRINT CONCAT('Novedad procesando tercero para orden ', @order, ': ', ERROR_MESSAGE());
		END CATCH;

		DELETE @terceros;
		DELETE @cliente;
		DELETE @impuestos;
		DELETE @criterios;
		DELETE @entidadTercero;
		DELETE @entidadCliente;
		SET @counter = @counter + 1;
	END;

	SELECT * FROM @final AS final_json;
END TRY
BEGIN CATCH
	SELECT 
		CAST(1 AS BIT) AS indicaError, 
		CONCAT('Error general en Terceros: ', ERROR_MESSAGE()) AS descripcionError;
END CATCH;