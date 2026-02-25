BEGIN TRY

    IF OBJECT_ID('tempdb..#tercero') IS NOT NULL DROP TABLE #tercero;
    IF OBJECT_ID('tempdb..#cliente') IS NOT NULL DROP TABLE #cliente;
	IF OBJECT_ID('tempdb..#impuestos') IS NOT NULL DROP TABLE #impuestos;

    DECLARE @json NVARCHAR(MAX) = '';
    DECLARE @final table (
        idDocumento INT,
        indicaParalelismo BIT,
        descripcion VARCHAR(50),
        idOrden varchar(50),
        json varchar(max)
        );
    DECLARE @counter INT = 1;
    DECLARE @total INT;

    DECLARE @order VARCHAR(30)

    DECLARE @paisSiesa NVARCHAR(3),
            @dptoSiesa NVARCHAR(3),
            @ciudadSiesa NVARCHAR(3);
    -- cambiar datos a los reales del conector.
    DECLARE @idDocumento INT =228302
    DECLARE @descripcionConector VARCHAR(50)='Terceros_Cliente_Clemont'
    DECLARE @indicaParalelismo BIT =1

	--* IDENTIFICACIÓN DE SUCURSAL *--
	DECLARE @IdSucursalCol	NVARCHAR(10) =	'001';

    /* TABLAS TEMPORALES */
	DECLARE @Tercero	TABLE (
		F_CIA						NVARCHAR(5),
		F200_ID						NVARCHAR(50),
		F200_NIT					NVARCHAR(25),
		F200_ID_TIPO_IDENT			NVARCHAR(10),
		F200_IND_TIPO_TERCERO		NVARCHAR(5),
		F200_RAZON_SOCIAL			NVARCHAR(100),
		F200_APELLIDO1				NVARCHAR(29),
		F200_APELLIDO2				NVARCHAR(29),
		F200_NOMBRES				NVARCHAR(40),
		F200_NOMBRE_EST				NVARCHAR(40),
		F015_CONTACTO				NVARCHAR(30),
		F015_DIRECCION1				NVARCHAR(40),
		F015_DIRECCION2				NVARCHAR(40),
		F015_DIRECCION3				NVARCHAR(40),
		F015_ID_PAIS				NVARCHAR(3),
		F015_ID_DEPTO				NVARCHAR(3),
		F015_ID_CIUDAD				NVARCHAR(3),
		F015_TELEFONO				NVARCHAR(20),
		F015_EMAIL					NVARCHAR(255),
		F200_FECHA_NACIMIENTO		NVARCHAR(40),
		F015_CELULAR				NVARCHAR(20)
	);

	DECLARE @Cliente	TABLE (
		F_CIA						NVARCHAR(5),
		F201_ID_TERCERO				NVARCHAR(5),
		F201_ID_SUCURSAL			NVARCHAR(10),
		F201_DESCRIPCION_SUCURSAL	NVARCHAR(40),
		F201_ID_MONEDA				NVARCHAR(5),
		F201_ID_COND_PAGO			NVARCHAR(5),
		F201_ID_TIPO_CLI			NVARCHAR(10),
		F201_ID_LISTA_PRECIO		NVARCHAR(10),
		F201_ID_CO_FACTURA			NVARCHAR(5),
		F015_CONTACTO				NVARCHAR(40),
		F015_DIRECCION1				NVARCHAR(29),
		F015_DIRECCION2				NVARCHAR(29),
		F015_DIRECCION3				NVARCHAR(29),
		F015_ID_PAIS				NVARCHAR(3),
		F015_ID_DEPTO				NVARCHAR(3),
		F015_ID_CIUDAD				NVARCHAR(3),
		F015_TELEFONO				NVARCHAR(20),
		F015_EMAIL					NVARCHAR(255),
		F201_FECHA_INGRESO			NVARCHAR(40),
		f015_celular				NVARCHAR(20)
	);

	DECLARE @Impuestos	TABLE	(
		F_CIA						NVARCHAR(5),
		F_ID_TERCERO				NVARCHAR(20),
		F_ID_SUCURSAL				NVARCHAR(10)
    );

	DECLARE @ordenes TABLE (
        id_orden                    NVARCHAR(900),
        orden_obj                   NVARCHAR(MAX)
    );

    IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL DROP TABLE #ordenes;

    SELECT	TOP 20 
		id_orden, 
		orden_obj
    INTO #ordenes
    FROM ordenes 
    WHERE id_estado =1
    AND intentos<=3 --and id_orden='"#27865"'

    SET @total = (SELECT COUNT(*) FROM #ordenes);
    WHILE @counter <= @total
    BEGIN

        SET @json = (
            SELECT 
                orden_obj
            FROM (
                SELECT orden_obj, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                FROM #ordenes
            ) AS temp
            WHERE rn = @counter
        );

    SELECT TOP 1 
        @paisSiesa=isnull(f013_id_pais,'169'),
        @dptoSiesa=isnull(f013_id_depto,'05'),
        @ciudadSiesa=isnull(f013_id,'001') 
    FROM locaciones_erp 
    WHERE 
          -- dbo.fn_RemoveAccentMarks(
              REPLACE(
                  REPLACE(
                      REPLACE(
                          REPLACE(
                              REPLACE(
                                  REPLACE(
                                      LOWER(f011_descripcion), 
                                      'ü', 
                                      'u'
                                  ), 
                                  'á', 
                                  'a'
                              ),
                              'é',
                              'e'
                          ),
                          'í',
                          'i'
                      ),
                      'ó',
                      'o'
                  ),
                  'ú',
                  'u'
              )
          -- )
          =
          -- dbo.fn_RemoveAccentMarks(
              REPLACE(
                  REPLACE(
                      REPLACE(
                          REPLACE(
                              REPLACE(
                                  REPLACE(
                                      LOWER(JSON_VALUE(@json, '$.customer.default_address.country')), 
                                      'ü', 
                                      'u'
                                  ), 
                                  'á', 
                                  'a'
                              ),
                              'é',
                              'e'
                          ),
                          'í',
                          'i'
                      ),
                      'ó',
                      'o'
                  ),
                  'ú',
                  'u'
              )
          -- )
          and   
          -- dbo.fn_RemoveAccentMarks(
              REPLACE(
                  REPLACE(
                      REPLACE(
                          REPLACE(
                              REPLACE(
                                  REPLACE(
                                      LOWER(f012_descripcion), 
                                      'ü', 
                                      'u'
                                  ), 
                                  'á', 
                                  'a'
                              ),
                              'é',
                              'e'
                          ),
                          'í',
                          'i'
                      ),
                      'ó',
                      'o'
                  ),
                  'ú',
                  'u'
              )
          -- )
          =
          -- dbo.fn_RemoveAccentMarks(
              REPLACE(
                  REPLACE(
                      REPLACE(
                          REPLACE(
                              REPLACE(
                                  REPLACE(
                                      LOWER(JSON_VALUE(@json, '$.customer.default_address.province')), 
                                      'ü', 
                                      'u'
                                  ), 
                                  'á', 
                                  'a'
                              ),
                              'é',
                              'e'
                          ),
                          'í',
                          'i'
                      ),
                      'ó',
                      'o'
                  ),
                  'ú',
                  'u'
              )
          -- )
          and   
          -- dbo.fn_RemoveAccentMarks(
              REPLACE(
                  REPLACE(
                      REPLACE(
                          REPLACE(
                              REPLACE(
                                  REPLACE(
                                      LOWER(f013_descripcion), 
                                      'ü', 
                                      'u'
                                  ), 
                                  'á', 
                                  'a'
                              ),
                              'é',
                              'e'
                          ),
                          'í',
                          'i'
                      ),
                      'ó',
                      'o'
                  ),
                  'ú',
                  'u'
              )
          -- )
          =
          -- dbo.fn_RemoveAccentMarks(
              REPLACE(
                  REPLACE(
                      REPLACE(
                          REPLACE(
                              REPLACE(
                                  REPLACE(
                                      LOWER(JSON_VALUE(@json, '$.customer.default_address.city')), 
                                      'ü', 
                                      'u'
                                  ), 
                                  'á', 
                                  'a'
                              ),
                              'é',
                              'e'
                          ),
                          'í',
                          'i'
                      ),
                      'ó',
                      'o'
                  ),
                  'ú',
                  'u'
              );
          -- ) ;
    
    SET @order=JSON_VALUE(@json, '$.name')

    DECLARE @F200_ID            NVARCHAR(40)   = ISNULL(JSON_VALUE(@json, '$.billing_address.company'),
                                                JSON_VALUE(@json, '$.customer.default_address.company'))
    DECLARE @F200_ID_TIPO_IDENT NVARCHAR(10)   = 'C'
    DECLARE @F200_IND_TIPO_TERCERO NVARCHAR(10) = '1'----VALIDAR CONECTOR
    DECLARE @F200_RAZON_SOCIAL  NVARCHAR(100)  = UPPER(ISNULL(JSON_VALUE(@json, '$.billing_address.name'),
                                                JSON_VALUE(@json, '$.customer.default_address.name')))
    DECLARE @F015_DIRECCION1    NVARCHAR(40)   = UPPER(JSON_VALUE(@json, '$.customer.default_address.address1'))
    DECLARE @F015_DIRECCION2    NVARCHAR(40)   = ISNULL(UPPER(JSON_VALUE(@json, '$.customer.default_address.address2')), '')
    DECLARE @F015_DIRECCION3    NVARCHAR(40)   = ISNULL(UPPER(JSON_VALUE(@json, '$.customer.default_address.address3')),'')
    DECLARE @F015_TELEFONO      NVARCHAR(20)   = REPLACE(JSON_VALUE(@json, '$.customer.default_address.phone'),'+57','')
    DECLARE @F015_EMAIL         NVARCHAR(255)  = JSON_VALUE(@json, '$.customer.email')
    DECLARE @FECHA              NVARCHAR(40)   = REPLACE(CONVERT(VARCHAR(10), CAST(JSON_VALUE(@json, '$.customer.created_at') AS DATE)), '-', '')
    DECLARE @F201_ID_MONEDA     NVARCHAR(3)    = UPPER(JSON_VALUE(@json, '$.currency'))
    DECLARE @F201_ID_TIPO_CLI   NVARCHAR(4);

    DECLARE @gateway NVARCHAR(50)   =   'C001';

    SELECT TOP 1 @F201_ID_TIPO_CLI = 
        CASE 
            WHEN JSON_VALUE(transaccion_obj, '$.gateway') = 'Addi Payment'
                THEN 'C004'
            WHEN JSON_VALUE(transaccion_obj, '$.gateway') IN ('cash', 'manual')
                THEN 'C001'
            WHEN JSON_VALUE(transaccion_obj, '$.gateway') IN ('Checkout Mercado Pago', 'Pago TC MercadoPago', 'Pago TD MercadoPago')
                THEN 'C008'
            WHEN JSON_VALUE(transaccion_obj, '$.gateway') = 'gift_card'
                THEN 'C006'
            WHEN JSON_VALUE(transaccion_obj, '$.gateway') = 'Sistecredito'
                THEN '?'
            WHEN JSON_VALUE(transaccion_obj, '$.gateway') = 'Wompi'
                THEN '?'
            ELSE 'C001'
        END
    FROM transacciones_ordenes
    WHERE
        id_orden = JSON_VALUE(@json, '$.id')
        AND
        JSON_VALUE(transaccion_obj, '$.status') = 'success'
    
    --tercero
    SELECT F200_ID          =	@F200_ID
        ,F200_NIT           =	@F200_ID
		,F200_ID_TIPO_IDENT	=	@F200_ID_TIPO_IDENT --Agregado
		,F200_IND_TIPO_TERCERO = @F200_IND_TIPO_TERCERO --Agregado
        ,F200_RAZON_SOCIAL  =   @F200_RAZON_SOCIAL
        ,F200_APELLIDO1     =   LEFT(UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name')), 
                                CHARINDEX(' ', UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name')) + ' ') - 1) 
        ,F200_APELLIDO2     =   LTRIM(SUBSTRING(UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name')), 
                                CHARINDEX(' ', UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name')) + ' '), 
                                LEN(upper(JSON_VALUE(@json, '$.customer.default_address.last_name'))) - 
                                CHARINDEX(' ', UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name'))) + 1)) 
        ,F200_NOMBRES       =   UPPER(JSON_VALUE(@json, '$.customer.default_address.name'))
		,F200_NOMBRE_EST	=	LEFT(@F200_RAZON_SOCIAL, 50) --Agregado
        ,F015_CONTACTO      =   LEFT(@F200_RAZON_SOCIAL, 50)
        ,F015_DIRECCION1    =   @F015_DIRECCION1
        ,F015_DIRECCION2    =   @F015_DIRECCION2
		,F015_DIRECCION3	=	@F015_DIRECCION3--Agregado
        ,F015_ID_PAIS       =   @paisSiesa															
        ,F015_ID_DEPTO      =   @dptoSiesa															
        ,F015_ID_CIUDAD     =   @ciudadSiesa														
        ,F015_TELEFONO      =   @F015_TELEFONO
        ,F015_EMAIL         =   @F015_EMAIL									
        ,F200_FECHA_NACIMIENTO= @FECHA
        ,F015_CELULAR       =   @F015_TELEFONO
        INTO #tercero

    --cliente
    SELECT F201_ID_TERCERO  =           @F200_ID
        ,F201_ID_SUCURSAL   =		    '001'
        ,F201_DESCRIPCION_SUCURSAL=     @F200_RAZON_SOCIAL
        ,F201_ID_MONEDA =			    @F201_ID_MONEDA
        ,F201_ID_COND_PAGO =		    'CR'
        ,F201_ID_TIPO_CLI =		        @F201_ID_TIPO_CLI
        ,F201_ID_LISTA_PRECIO =         'LPL'
        ,F201_ID_CO_FACTURA =		    '001'
        ,F015_CONTACTO      =           @F200_RAZON_SOCIAL
        ,F015_DIRECCION1    =   		@F015_DIRECCION1
        ,F015_DIRECCION2    =		    @F015_DIRECCION2
        ,F015_DIRECCION3    =		    @F015_DIRECCION3
        ,F015_ID_PAIS       =			@paisSiesa
        ,F015_ID_DEPTO      =			@dptoSiesa
        ,F015_ID_CIUDAD     =			@ciudadSiesa
        ,F015_TELEFONO      =			@F015_TELEFONO
        ,F015_EMAIL         =           @F015_EMAIL
        ,F201_FECHA_INGRESO =           @FECHA
        ,f015_celular       =           @F015_TELEFONO  
        INTO #cliente

	--Impuesto y reten
	SELECT
	  F_ID_TERCERO          =           @F200_ID
	  ,F_ID_SUCURSAL        =           '001',--------VALIDAR CONECTOR
	  CASE WHEN  @F201_ID_MONEDA ='COP' THEN 
	  '1' ELSE '0' END AS F_ID_VALOR_TERCERO
	  --CUANDO ES CLIENTE NACIONAL SE APLICA EL IVA, CUANDO ES EXTRAJERO NO SE APLICA EL IVA.
	  INTO #impuestos


    INSERT INTO @final(idDocumento, descripcion, indicaParalelismo, idOrden, json)
            SELECT  
                @idDocumento,
                @descripcionConector,
                @indicaParalelismo,
                @order AS idOrden,
        (
    SELECT
        [Terceros] = (
        SELECT *
        FROM #tercero
        FOR JSON PATH,INCLUDE_NULL_VALUES
        ),
        [Clientes] = (
        SELECT *
        FROM #cliente
        FOR JSON PATH,INCLUDE_NULL_VALUES
        ),
        [Imptos y Reten] = (
        SELECT *
        FROM #impuestos
        FOR JSON PATH,INCLUDE_NULL_VALUES
        )
        -- ,
        -- [Criterios Clientes] = (
        -- SELECT 
        --     @F200_ID AS F207_ID_TERCERO,
        --     '001' AS F207_ID_SUCURSAL,
        --     '' AS F207_ID_PLAN_CRITERIOS,
        --     '' AS F207_ID_CRITERIO_MAYOR
        -- FOR JSON PATH, INCLUDE_NULL_VALUES
        -- )
        -- ,
        -- [Ent Dinamica Cliente] = (
        -- SELECT
        --     @F200_ID AS f201_id_tercero,
        --     '001' AS f201_id_sucursal,
        --     '' AS f753_dato_texto
        -- FOR JSON PATH, INCLUDE_NULL_VALUES
        -- )
    FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);

    IF OBJECT_ID('tempdb..#tercero') IS NOT NULL DROP TABLE #tercero;
    IF OBJECT_ID('tempdb..#cliente') IS NOT NULL DROP TABLE #cliente;
	IF OBJECT_ID('tempdb..#impuestos') IS NOT NULL DROP TABLE #impuestos;

    SET @counter = @counter + 1;
    END

    SELECT * from @final AS final_json;
END TRY
BEGIN CATCH
    SELECT
        indicaError         =   CAST(1 AS BIT), 
        descripcionError    =   CONCAT('Error: ', ERROR_MESSAGE())
END CATCH