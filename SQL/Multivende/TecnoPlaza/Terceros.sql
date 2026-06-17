-- AJUSTAR CON LOS PARAMETROS DE TU CONECTOR.
DECLARE @idDocumento			INT			    =	222302;
DECLARE @descripcionConector	VARCHAR(100)	=	'TecnoPlaza_Terceros';
DECLARE @indicaParalelismo		BIT			    =	1;
DECLARE @IdSucursal				NVARCHAR(3)	    =	'002';

-- Variables
DECLARE @json					NVARCHAR(MAX) = '';
DECLARE @final					TABLE (idDocumento	INT,indicaParalelismo	BIT,descripcion	VARCHAR(100),idOrden	VARCHAR(100),json VARCHAR(MAX));
DECLARE @counter				INT = 1;
DECLARE @total					INT;
DECLARE @order					VARCHAR(50);
DECLARE @tercero				NVARCHAR(50);
DECLARE @paisSiesa				NVARCHAR(3), @dptoSiesa	NVARCHAR(3), @ciudadSiesa	NVARCHAR(3);
DECLARE @conexion				NVARCHAR(MAX)	=	(SELECT TOP 1 cadena_conexion FROM Conexiones)
DECLARE @base_datos				NVARCHAR(MAX)	=	(SELECT TOP 1 base_datos FROM Conexiones)

-- Tablas 
IF OBJECT_ID('tempdb..#company_ordenes') IS NOT NULL DROP TABLE #company_ordenes;
IF OBJECT_ID('tempdb..#company_terceros') IS NOT NULL DROP TABLE #company_terceros;
IF OBJECT_ID('tempdb..#company_cliente') IS NOT NULL DROP TABLE #company_cliente;
IF OBJECT_ID('tempdb..#company_impuestos') IS NOT NULL DROP TABLE #company_impuestos;
IF OBJECT_ID('tempdb..#company_criterios') IS NOT NULL DROP TABLE #company_criterios;
IF OBJECT_ID('tempdb..#company_entidadTercero') IS NOT NULL DROP TABLE #company_entidadTercero;
IF OBJECT_ID('tempdb..#company_entidadCliente')	IS NOT NULL DROP TABLE #company_entidadCliente;

UPDATE Orders
SET idEstado = 5
WHERE 
    SWITCHOFFSET(
        TRY_CONVERT(datetimeoffset, JSON_VALUE(Order_jsonApi, '$.createdAt')),
        DATENAME(TzOffset, SYSDATETIMEOFFSET())
    ) < '2025-11-26T15:00:00'
    AND idEstado = 2
    AND intentos = 0;

--Obtenemos las ordenes a recorrer
SELECT TOP 25
	   IdOrder
	   ,Order_jsonApi
	   ,ROW_NUMBER() OVER (ORDER BY (SELECT IdOrder)) AS Orden
	   --Datos Tercero
	   ,dbo.OnlyNumbers(JSON_VALUE(Order_jsonApi, '$.Client.taxId'))        AS documentoTer
	   ,JSON_VALUE(Order_jsonApi, '$.Client.type')                          AS tipoDocTer
	   ,CASE 
			WHEN JSON_VALUE(Order_jsonApi, '$.Client.taxId') LIKE '[789]%'
				 AND LEN(JSON_VALUE(Order_jsonApi, '$.Client.taxId')) >= 10
			THEN 2
			ELSE 1
		END                                                                 AS tipoTercero
	   ,REPLACE(JSON_VALUE(Order_jsonApi, '$.Client.fullName'),'&','')                      AS nombreCompletoTer
	   ,REPLACE(JSON_VALUE(Order_jsonApi, '$.Client.name'),'&','')                          AS nombreTer
	   ,REPLACE(JSON_VALUE(Order_jsonApi, '$.Client.lastName'),'&','')                      AS apellidoTer
	   ,JSON_VALUE(Order_jsonApi, '$.Client.email')                         AS emailTer
	   ,JSON_VALUE(Order_jsonApi, '$.Client.BillingAddresses[0].address_1') AS direccionUno
	   ,JSON_VALUE(Order_jsonApi, '$.Client.BillingAddresses[0].address_2') AS direccionDos
	   ,JSON_VALUE(Order_jsonApi, '$.Client.phoneNumber')                   AS celularTer
	   ,JSON_VALUE(Order_jsonApi, '$.Client.BillingAddresses[0].city')      AS paisTer
	   ,JSON_VALUE(Order_jsonApi, '$.Client.BillingAddresses[0].state')     AS stateTer
	   ,JSON_VALUE(Order_jsonApi, '$.Client.BillingAddresses[0].country')   AS ciudadTer
	   ,JSON_VALUE(Order_jsonApi, '$.origin')                               AS origen
  INTO #company_ordenes
  FROM Orders 
 WHERE IdEstado = 2 
   AND Intentos <= 1 
   --AND 
   --IdOrder IN (
   --'8bee5a8d-c8ff-4c85-9d57-b88fdf21f9b5'
   --)


SET @total = (SELECT COUNT(*) FROM #company_ordenes);
WHILE @counter <= @total
BEGIN

    --Obtenemos el id de la orden y el tercero
	SELECT @order = IdOrder, 
	       @tercero = CASE WHEN tipoTercero = 2 
		                   THEN CASE WHEN LEN(documentoTer) > 9 
									 THEN LEFT(documentoTer, 9)
									 ELSE documentoTer
								 END 
					  ELSE documentoTer END
	  FROM #company_ordenes 
	 WHERE Orden = @counter;

    --Obtenemos Pais-Departamento-Ciudad
    DECLARE @totalRegistroPais INT;

	-- Contamos cuántos registros coinciden por país
	SELECT @totalRegistroPais = COUNT(*)
	FROM locaciones_erp
	WHERE f013_descripcion = (
		SELECT TOP 1 UPPER(paisTer)
		FROM #company_ordenes
		WHERE Orden = @counter
	);

	-- Si hay más de un registro, se agrega el filtro adicional por departamento (stateTer)
	IF @totalRegistroPais >= 2
	BEGIN
		SELECT 
			@paisSiesa   = f013_id_pais,
			@dptoSiesa   = f013_id_depto,
			@ciudadSiesa = f013_id
		FROM locaciones_erp
		WHERE f013_descripcion = (
			SELECT TOP 1 UPPER(paisTer)
			FROM #company_ordenes
			WHERE Orden = @counter
		)
		AND f012_descripcion = (
			SELECT TOP 1 UPPER(stateTer)
			FROM #company_ordenes
			WHERE Orden = @counter
		);
	END
	ELSE IF @totalRegistroPais = 0
	BEGIN
		SELECT 
			@paisSiesa   = f013_id_pais,
			@dptoSiesa   = f013_id_depto,
			@ciudadSiesa = f013_id
		FROM locaciones_erp
		WHERE REPLACE(f013_descripcion,'Bogotá, D.C.','Bogotá D.C.') = (
			SELECT TOP 1 UPPER(stateTer)
			FROM #company_ordenes
			WHERE Orden = @counter
		);
	END
	ELSE
	BEGIN
		SELECT 
			@paisSiesa   = f013_id_pais,
			@dptoSiesa   = f013_id_depto,
			@ciudadSiesa = f013_id
		FROM locaciones_erp
		WHERE f013_descripcion = (
			SELECT TOP 1 UPPER(paisTer)
			FROM #company_ordenes
			WHERE Orden = @counter
		);
	END


    -- TERCEROS
	SELECT @tercero                                                                       AS	F200_ID,
	       @tercero                                                                       AS	F200_NIT,
		   CASE WHEN tipoTercero = '1' THEN 'C' ELSE 'N' END                              AS	F200_ID_TIPO_IDENT,
		   CASE WHEN tipoTercero = '1' THEN '1' ELSE '2' END						      AS	F200_IND_TIPO_TERCERO, 
		   CASE WHEN tipoTercero = '1' THEN '' ELSE UPPER(nombreTer) END                  AS	F200_RAZON_SOCIAL,
		   CASE WHEN tipoTercero = '1' 
		        THEN CASE 
							WHEN LEN(ISNULL(LEFT(UPPER(apellidoTer), CHARINDEX(' ', UPPER(apellidoTer) + ' ') - 1),'')) > 29 
								THEN ISNULL(LEFT(ISNULL(LEFT(UPPER(apellidoTer), CHARINDEX(' ', UPPER(apellidoTer) + ' ') - 1),''), 29),'')
							ELSE ISNULL(ISNULL(LEFT(UPPER(apellidoTer), CHARINDEX(' ', UPPER(apellidoTer) + ' ') - 1),''),'')
					   END
				ELSE '' 
		   END                                                                            AS    F200_APELLIDO1,
		   CASE WHEN tipoTercero = '1' 
		        THEN CASE 
							WHEN LEN(ISNULL(LTRIM(SUBSTRING(UPPER(apellidoTer), CHARINDEX(' ', UPPER(apellidoTer) + ' ') + 1, LEN(UPPER(apellidoTer)))),'')) > 29 
								THEN ISNULL(LEFT(ISNULL(LTRIM(SUBSTRING(UPPER(apellidoTer), CHARINDEX(' ', UPPER(apellidoTer) + ' ') + 1, LEN(UPPER(apellidoTer)))),''), 29),'')
							ELSE ISNULL(ISNULL(LTRIM(SUBSTRING(UPPER(apellidoTer), CHARINDEX(' ', UPPER(apellidoTer) + ' ') + 1, LEN(UPPER(apellidoTer)))),''),'')
					   END 
				ELSE '' 
		   END                                                                            AS    F200_APELLIDO2,
		   CASE WHEN tipoTercero = '1' 
		        THEN CASE 
							WHEN LEN(UPPER(nombreTer)) > 40 
								THEN ISNULL(LEFT(UPPER(nombreTer), 40),'')
							ELSE ISNULL(UPPER(nombreTer),'')
					   END
				ELSE '' 
		   END                                                                            AS    F200_NOMBRES,
		   
		   CASE WHEN tipoTercero = '1' 
		        THEN 
				   CASE 
						WHEN LEN(UPPER(nombreCompletoTer)) > 50 
							THEN ISNULL(LEFT(UPPER(nombreCompletoTer), 50),'')
						ELSE ISNULL(UPPER(nombreCompletoTer),'')
				   END                                                                            
		        ELSE 
					CASE 
						WHEN LEN(UPPER(nombreTer)) > 50 
							THEN ISNULL(LEFT(UPPER(nombreTer), 50),'')
						ELSE ISNULL(UPPER(nombreTer),'')
					END 
		   END                                                                            AS    F015_CONTACTO,
		   CASE 
				WHEN LEN(UPPER(direccionUno)) > 40 
					THEN ISNULL(LEFT(UPPER(direccionUno), 40),'')
				ELSE ISNULL(UPPER(direccionUno),'')
		   END                                                                            AS	F015_DIRECCION1,
		   CASE 
				WHEN LEN(UPPER(direccionDos)) > 40 
					THEN ISNULL(LEFT(UPPER(direccionDos), 40),'')
				ELSE ISNULL(UPPER(direccionDos),'')
		   END                                                                            AS	F015_DIRECCION2,
		   ISNULL(@paisSiesa, '169')	       				                              AS	F015_ID_PAIS,
		   ISNULL(@dptoSiesa, '76')						                                  AS	F015_ID_DEPTO,
		   ISNULL(@ciudadSiesa, '999')					                                  AS	F015_ID_CIUDAD,
		   ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(celularTer), '#', ''), 'X', ''), '+57', ''), ' ', ''), '')	          AS	F015_TELEFONO,
		   CASE 
				WHEN origen = 'mercadolibre' THEN 
					CASE 
						WHEN ISNULL(emailTer, '') = '' THEN 'tpfe1@outlook.com' 
						ELSE ISNULL(emailTer, '') 
					END
				ELSE ISNULL(emailTer, '')						
		   END                                                                            AS	F015_EMAIL,
		   CONVERT(VARCHAR, GETDATE(), 112)											      AS	F200_FECHA_NACIMIENTO,
		   ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(celularTer), '#', ''), 'X', ''), '+57', ''), ' ', ''), '')		      AS	F015_CELULAR
	  INTO #company_terceros
	  FROM #company_ordenes
     WHERE Orden = @counter;


	 -- CLIENTES
	 SELECT @tercero													                  AS	F201_ID_TERCERO,
			@IdSucursal															          AS	F201_ID_SUCURSAL,
			CASE WHEN tipoTercero = '1' 
		        THEN 
				   CASE 
						WHEN LEN(UPPER(nombreCompletoTer)) > 40 
							THEN ISNULL(LEFT(UPPER(nombreCompletoTer), 40),'')
						ELSE ISNULL(UPPER(nombreCompletoTer),'')
				   END                                                                            
		        ELSE 
					CASE 
						WHEN LEN(UPPER(nombreTer)) > 40 
							THEN ISNULL(LEFT(UPPER(nombreTer), 40),'')
						ELSE ISNULL(UPPER(nombreTer),'')
					END 
		   END												                              AS	F201_DESCRIPCION_SUCURSAL,
			'COP'															              AS	F201_ID_MONEDA,
			CASE origen
				WHEN 'shopify' THEN '9999'
				WHEN 'fcom' THEN '0102'
				WHEN 'mercadolibre' THEN '0100'
			END																              AS	F201_ID_VENDEDOR,
			'090'															              AS	F201_ID_LISTA_PRECIO,
			CASE WHEN tipoTercero = '1' 
		        THEN 
				   CASE 
						WHEN LEN(UPPER(nombreCompletoTer)) > 50 
							THEN ISNULL(LEFT(UPPER(nombreCompletoTer), 50),'')
						ELSE ISNULL(UPPER(nombreCompletoTer),'')
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
			ISNULL(@paisSiesa, '169')		                                              AS	F015_ID_PAIS,
			ISNULL(@dptoSiesa, '76')			                                          AS	F015_ID_DEPTO,
			ISNULL(@ciudadSiesa, '999')		                                              AS	F015_ID_CIUDAD,
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
	   INTO #company_cliente
	   FROM #company_ordenes
      WHERE Orden = @counter;
	  

	  --Creamos la tabla de los impuestos
	  CREATE TABLE #company_impuestos (
			F_TIPO_REG         VARCHAR(255),
			F_ID_TERCERO       VARCHAR(255),
			F_ID_SUCURSAL      VARCHAR(255),
			F_ID_CLASE         VARCHAR(255),
			F_ID_VALOR_TERCERO VARCHAR(255)
			);

	  -- IMPUESTOS Y RETENCIONES
	  INSERT INTO #company_impuestos (
			F_TIPO_REG,
		    F_ID_TERCERO,
		    F_ID_SUCURSAL,
		    F_ID_CLASE,
		    F_ID_VALOR_TERCERO
	  )
	  SELECT '46'							                                    AS	F_TIPO_REG,
		     @tercero						                                    AS	F_ID_TERCERO,
		     @IdSucursal							                            AS	F_ID_SUCURSAL,
		     '1'								                                AS	F_ID_CLASE,
		     '1'								                                AS	F_ID_VALOR_TERCERO
	  UNION ALL
	  SELECT '47'							                                    AS	F_TIPO_REG,
		     @tercero						                                    AS	F_ID_TERCERO,
		     @IdSucursal							                            AS	F_ID_SUCURSAL,
		     '41'							                                    AS	F_ID_CLASE,
		     '1'								                                AS	F_ID_VALOR_TERCERO


	  --Creamos la tabla de los Criterios Clasificacion
	  CREATE TABLE #company_criterios (
			F207_ID_TERCERO        VARCHAR(255),
			F207_ID_SUCURSAL       VARCHAR(255),
			F207_ID_PLAN_CRITERIOS VARCHAR(255),
			F207_ID_CRITERIO_MAYOR VARCHAR(255)
			);

	  -- CRITERIOS CLASIFICACION
	  INSERT INTO #company_criterios (
			F207_ID_TERCERO,
			F207_ID_SUCURSAL,
			F207_ID_PLAN_CRITERIOS,
			F207_ID_CRITERIO_MAYOR
	  )
	   SELECT @tercero														                  AS	F207_ID_TERCERO,
		      @IdSucursal														              AS	F207_ID_SUCURSAL,
			  '001'                                                                           AS    F207_ID_PLAN_CRITERIOS,
			  CASE origen
				WHEN 'shopify' THEN '107'
				WHEN 'fcom' THEN '102'
				WHEN 'mercadolibre' THEN '101'
			  END                                                                             AS    F207_ID_CRITERIO_MAYOR
		 FROM #company_ordenes
        WHERE Orden = @counter;


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
	  SELECT @tercero													                      AS	f200_id,
	         'EUNOECO017'                                                                     AS    f753_id_entidad,
			 'co017_codigo_regimen'                                                           AS    f753_id_atributo,
		     'MUNOECO016'														              AS	f753_id_maestro,
			 CASE WHEN tipoTercero = '1' THEN '49' ELSE '48' END						  AS	f753_id_maestro_detalle
		FROM #company_ordenes
       WHERE Orden = @counter
	  UNION ALL
	  SELECT @tercero													                      AS	f200_id,
	         'EUNOECO031'                                                                     AS    f753_id_entidad,
			 'co031_detalle_tributario1'                                                      AS    f753_id_atributo,
		     'MUNOECO035'														              AS	f753_id_maestro,
			 CASE WHEN tipoTercero = '1' THEN 'ZZ' ELSE '01' END						  AS	f753_id_maestro_detalle
		FROM #company_ordenes
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
			f201_id_sucursal,
		    f753_id_entidad,
		    f753_id_atributo,
		    f753_id_maestro,
		    f753_id_maestro_detalle
	  )
	  SELECT @tercero													                      AS	f201_id_tercero,
	         @IdSucursal                                                                      AS    f201_id_sucursal,
	         'EUNOECO017'                                                                     AS    f753_id_entidad,
			 'co017_codigo_regimen'                                                           AS    f753_id_atributo,
		     'MUNOECO016'														              AS	f753_id_maestro,
			 CASE WHEN tipoTercero = '1' THEN '49' ELSE '48' END						  AS	f753_id_maestro_detalle
		FROM #company_ordenes
       WHERE Orden = @counter
	  UNION ALL
	  SELECT @tercero													                      AS	f201_id_tercero,
	         @IdSucursal                                                                      AS    f201_id_sucursal,
	         'EUNOECO031'                                                                     AS    f753_id_entidad,
			 'co031_detalle_tributario1'                                                      AS    f753_id_atributo,
		     'MUNOECO035'														              AS	f753_id_maestro,
			 CASE WHEN tipoTercero = '1' THEN 'ZZ' ELSE '01' END						  AS	f753_id_maestro_detalle
		FROM #company_ordenes
       WHERE Orden = @counter;


    -- Construimos el json final para consumir
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
				),[ImptosReten]		=	(
					SELECT *
					FROM #company_impuestos
					FOR JSON PATH
					,INCLUDE_NULL_VALUES
				),[CriteriosClientes]	=	(
					SELECT *
					FROM #company_criterios
					FOR JSON PATH
					,INCLUDE_NULL_VALUES
				),[EntDinamicaTercero]	=	(
					SELECT *
					FROM #company_entidadTercero
					FOR JSON PATH
					,INCLUDE_NULL_VALUES
				),[EntDinamicaCliente]	=	(
					SELECT *
					FROM #company_entidadCliente
					FOR JSON PATH
					,INCLUDE_NULL_VALUES
				)FOR JSON PATH
				,WITHOUT_ARRAY_WRAPPER
			,INCLUDE_NULL_VALUES
		)
		
	IF OBJECT_ID('tempdb..#company_terceros') IS NOT NULL DROP TABLE #company_terceros;
	IF OBJECT_ID('tempdb..#company_cliente') IS NOT NULL DROP TABLE #company_cliente;
	IF OBJECT_ID('tempdb..#company_impuestos') IS NOT NULL DROP TABLE #company_impuestos;
	IF OBJECT_ID('tempdb..#company_criterios') IS NOT NULL DROP TABLE #company_criterios;
	IF OBJECT_ID('tempdb..#company_entidadTercero') IS NOT NULL DROP TABLE #company_entidadTercero;
	IF OBJECT_ID('tempdb..#company_entidadCliente')	IS NOT NULL DROP TABLE #company_entidadCliente;
		
	SET @counter = @counter + 1;
END
 
SELECT * from @final AS final_json;