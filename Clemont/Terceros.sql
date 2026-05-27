---QUERY TERCEROS CLEMONT CON REMOVEACCENTMARKS---

BEGIN TRY
    IF OBJECT_ID('tempdb..#tercero') IS NOT NULL DROP TABLE #tercero;
    IF OBJECT_ID('tempdb..#cliente') IS NOT NULL DROP TABLE #cliente;
    IF OBJECT_ID('tempdb..#impuestos') IS NOT NULL DROP TABLE #impuestos;

    DECLARE @json   NVARCHAR(MAX)   =   '';
    DECLARE @final  TABLE
    (
        idDocumento INT,
        indicaParalelismo BIT,
        descripcion VARCHAR(50),
        idOrden varchar(50),
        json varchar(max)
    );

    DECLARE @counter    INT = 1;
    DECLARE @total      INT;

    DECLARE @order VARCHAR(30)

    DECLARE @paisSiesa      NVARCHAR(3),
            @dptoSiesa      NVARCHAR(3),
            @ciudadSiesa    NVARCHAR(3);
    
    /*
    *   DATOS DEL CONECTOR
    */
    DECLARE @idDocumento            INT         =   228302
    DECLARE @descripcionConector    VARCHAR(50) =   'Terceros_Cliente_Clemont'
    DECLARE @indicaParalelismo      BIT         =   0

	--* IDENTIFICACIÓN DE SUCURSAL *--
	DECLARE @IdSucursalCol          NVARCHAR(10)    =	'001';

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

    SELECT	TOP 25
        id_orden, 
		orden_obj
    INTO #ordenes
    FROM ordenes 
    WHERE 
        id_estado =1
        AND 
        intentos<=3

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
            @paisSiesa      =   isnull(f013_id_pais,'169'),
            @dptoSiesa      =   isnull(f013_id_depto,'05'),
            @ciudadSiesa    =   isnull(f013_id,'001') 
        FROM locaciones_erp 
        WHERE 
            dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.customer.default_address.country')))
            AND 
            dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.customer.default_address.province')))
            AND 
            dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.customer.default_address.city')))
            OR 
            dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.billing_address.country')))
            OR 
            dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.billing_address.province')))
            OR 
            dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.billing_address.city')));
    
        SET @order=JSON_VALUE(@json, '$.name')

        DECLARE @F200_ID    NVARCHAR(40)    =
            ISNULL(
                JSON_VALUE(@json, '$.billing_address.company'),
                JSON_VALUE(@json, '$.customer.default_address.company')
            );
        DECLARE @F200_ID_TIPO_IDENT NVARCHAR(10)        =   'C'
        DECLARE @F200_IND_TIPO_TERCERO  NVARCHAR(10)    =   '1'----VALIDAR CONECTOR
        DECLARE @F200_RAZON_SOCIAL  NVARCHAR(100)   =
            UPPER(
                ISNULL(
                    ISNULL(
                        JSON_VALUE(@json, '$.billing_address.name'),
                        JSON_VALUE(@json, '$.customer.default_address.name')
                    ), 
                    ''
                )
            );
        DECLARE @F200_NOMBRES       NVARCHAR(100)   = 
            UPPER(
                ISNULL(
                    ISNULL(
                        JSON_VALUE(@json, '$.billing_address.first_name'),
                        JSON_VALUE(@json, '$.customer.default_address.first_name')
                    ), 
                    ''
                )   
            );
        DECLARE @apellido           NVARCHAR(100)   = 
            UPPER(
                ISNULL(
                    ISNULL(
                        JSON_VALUE(@json, '$.billing_address.last_name'),
                        JSON_VALUE(@json, '$.customer.default_address.last_name')
                    ), 
                    ''
                )   
            );
        DECLARE @F015_DIRECCION1    NVARCHAR(40)   = 
            UPPER(
                ISNULL(
                    JSON_VALUE(@json, '$.billing_address.address1'),
                    ISNULL(
                        JSON_VALUE(@json, '$.customer.default_address.address1'), 
                        ''
                    )
                )
            );
        DECLARE @F015_DIRECCION2    NVARCHAR(40)   = 
            UPPER(
                ISNULL(
                    JSON_VALUE(@json, '$.billing_address.address2'),
                    ISNULL(
                        JSON_VALUE(@json, '$.customer.default_address.address2'), 
                        ''
                    )
                )
            );
        DECLARE @F015_DIRECCION3    NVARCHAR(40)   = 
            UPPER(
                ISNULL(
                    JSON_VALUE(@json, '$.billing_address.address3'),
                    ISNULL(
                        JSON_VALUE(@json, '$.customer.default_address.address3'), 
                        ''
                    )
                )
            )
        DECLARE @F015_TELEFONO      NVARCHAR(20)   = 
            REPLACE(
                ISNULL(
                    JSON_VALUE(@json, '$.billing_address.phone'),
                    ISNULL(
                        JSON_VALUE(@json, '$.customer.default_address.phone')
                        , ''
                    )
                ),
                '+57',
                ''
            )
        DECLARE @F015_EMAIL         NVARCHAR(255)  =    JSON_VALUE(@json, '$.customer.email')
        DECLARE @FECHA              NVARCHAR(40)   =
            REPLACE(
                CONVERT(
                    VARCHAR(10), 
                    CAST(
                        JSON_VALUE(@json, '$.customer.created_at') AS DATE
                    )
                ), 
                '-', 
                ''
            );
        DECLARE @F201_ID_MONEDA     NVARCHAR(3)    =    UPPER(JSON_VALUE(@json, '$.currency'))
        DECLARE @F201_ID_TIPO_CLI   NVARCHAR(4);

        DECLARE @gateway    NVARCHAR(50)    =   'C001';

        SELECT TOP 1 
            @F201_ID_TIPO_CLI = 
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
                        THEN 'C005'
                    WHEN JSON_VALUE(transaccion_obj, '$.gateway') = 'Wompi'
                        THEN 'C009'
                    ELSE 'C001'
                END
        FROM transacciones_ordenes
        WHERE
            id_orden = JSON_VALUE(@json, '$.id')
            AND
            JSON_VALUE(transaccion_obj, '$.status') =   'success';
    
        /*
        *   Tercero
        */
        SELECT 
            F200_ID                 =	@F200_ID,
            F200_NIT                =	@F200_ID,
            F200_ID_TIPO_IDENT      =	@F200_ID_TIPO_IDENT,
            F200_IND_TIPO_TERCERO   =   @F200_IND_TIPO_TERCERO,
            F200_RAZON_SOCIAL       =   @F200_RAZON_SOCIAL,
            F200_APELLIDO1          =
                LEFT(
                    @apellido, 
                    CHARINDEX(
                        ' ', 
                        @apellido + ' '
                    ) - 1
                ),
            F200_APELLIDO2          =   
                LTRIM(
                    SUBSTRING(
                        @apellido, 
                        CHARINDEX(
                            ' ', 
                            @apellido + ' '
                        ), 
                        LEN(@apellido) - CHARINDEX(' ', @apellido) + 1)
                ),
            F200_NOMBRES            =   @F200_NOMBRES,
            F200_NOMBRE_EST         =	LEFT(@F200_RAZON_SOCIAL, 50),
            F015_CONTACTO           =   LEFT(@F200_RAZON_SOCIAL, 50),
            F015_DIRECCION1         =   ISNULL(@F015_DIRECCION1, ''),
            F015_DIRECCION2         =   ISNULL(@F015_DIRECCION2, ''),
            F015_DIRECCION3         =	ISNULL(@F015_DIRECCION3, ''),
            F015_ID_PAIS            =   ISNULL(@paisSiesa, ''),
            F015_ID_DEPTO           =   ISNULL(@dptoSiesa, ''),
            F015_ID_CIUDAD          =   ISNULL(@ciudadSiesa, ''),
            F015_TELEFONO           =   ISNULL(@F015_TELEFONO, ''),
            F015_EMAIL              =   ISNULL(@F015_EMAIL, ''),
            F200_FECHA_NACIMIENTO   =   @FECHA,
            F015_CELULAR            =   ISNULL(@F015_TELEFONO, '')
        INTO #tercero

        /*
        *   Cliente
        */
        SELECT
            F201_ID_TERCERO             =   @F200_ID,
            F201_ID_SUCURSAL            =   @IdSucursalCol,
            F201_DESCRIPCION_SUCURSAL   =   @F200_RAZON_SOCIAL
            ,F201_ID_MONEDA             =   @F201_ID_MONEDA
            ,F201_ID_COND_PAGO          =   'CR'
            ,F201_ID_TIPO_CLI           =   @F201_ID_TIPO_CLI
            ,F201_ID_LISTA_PRECIO       =   'LPL'
            ,F201_ID_CO_FACTURA         =   '001'
            ,F015_CONTACTO              =   @F200_RAZON_SOCIAL
            ,F015_DIRECCION1            =   @F015_DIRECCION1
            ,F015_DIRECCION2            =   @F015_DIRECCION2
            ,F015_DIRECCION3            =   @F015_DIRECCION3
            ,F015_ID_PAIS               =   @paisSiesa
            ,F015_ID_DEPTO              =   @dptoSiesa
            ,F015_ID_CIUDAD             =   @ciudadSiesa
            ,F015_TELEFONO              =   @F015_TELEFONO
            ,F015_EMAIL                 =   @F015_EMAIL
            ,F201_FECHA_INGRESO         =   @FECHA
            ,f015_celular               =   @F015_TELEFONO  
        INTO #cliente

	    /*
        *   Impuesto y reten
        */
	    SELECT
            F_ID_TERCERO        =   @F200_ID,
            F_ID_SUCURSAL       =   @IdSucursalCol,
            F_ID_VALOR_TERCERO  =
                CASE
                    WHEN  @F201_ID_MONEDA ='COP' 
                        THEN '1'
                    ELSE '0'
                END
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
                        FOR JSON PATH,
                        INCLUDE_NULL_VALUES
                    ),
                    [Clientes] = (
                        SELECT *
                        FROM #cliente
                        FOR JSON PATH,
                        INCLUDE_NULL_VALUES
                    ),
                    [Imptos y Reten] = (
                        SELECT *
                        FROM #impuestos
                        FOR JSON PATH,
                        INCLUDE_NULL_VALUES
                    )
                FOR JSON PATH,
                WITHOUT_ARRAY_WRAPPER,
                INCLUDE_NULL_VALUES
            );

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