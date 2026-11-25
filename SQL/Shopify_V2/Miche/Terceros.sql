DECLARE @json NVARCHAR(MAX) = '';
DECLARE @final TABLE (
    idDocumento INT,
    indicaParalelismo BIT,
    descripcion VARCHAR(50),
    idOrden VARCHAR(50),
    json VARCHAR(MAX)
);

DECLARE @counter INT = 1;
DECLARE @total INT;
DECLARE @order VARCHAR(30);

DECLARE @paisSiesa NVARCHAR(3), @dptoSiesa NVARCHAR(3), @ciudadSiesa NVARCHAR(3);

-- Datos del conector
DECLARE @idDocumento INT = 215568;
DECLARE @descripcionConector VARCHAR(50) = 'Ecommerce_Terceros_Clientes';
DECLARE @indicaParalelismo BIT = 1;

-- Limpiar si existe
IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL DROP TABLE #ordenes;
IF OBJECT_ID('tempdb..#tercero')  IS NOT NULL DROP TABLE #tercero;
IF OBJECT_ID('tempdb..#cliente')  IS NOT NULL DROP TABLE #cliente;

------------------------------------------------------------
-- TABLA TEMPORAL ORDENES
------------------------------------------------------------
CREATE TABLE #ordenes (
    id_orden NVARCHAR(30),
    orden_obj NVARCHAR(MAX)
);

INSERT INTO #ordenes (id_orden, orden_obj)
SELECT  id_orden, orden_obj
FROM ordenes
WHERE id_estado = 1;


SET @total = (SELECT COUNT(*) FROM #ordenes);

------------------------------------------------------------
-- CREAR TABLA TEMPORAL TERCERO
------------------------------------------------------------
CREATE TABLE #tercero (
    F200_ID NVARCHAR(40),
    F200_NIT NVARCHAR(40),
    F200_RAZON_SOCIAL NVARCHAR(100),
    F200_APELLIDO1 NVARCHAR(100),
    F200_APELLIDO2 NVARCHAR(100),
    F200_NOMBRES NVARCHAR(100),
	F200_NOMBRE_EST NVARCHAR(100),
    F015_CONTACTO NVARCHAR(100),
    F015_DIRECCION1 NVARCHAR(40),
    F015_DIRECCION2 NVARCHAR(40),
    F015_DIRECCION3 NVARCHAR(40),
    F015_ID_PAIS NVARCHAR(3),
    F015_ID_DEPTO NVARCHAR(3),
    F015_ID_CIUDAD NVARCHAR(3),
    F015_TELEFONO NVARCHAR(20),
    F015_EMAIL NVARCHAR(255),
    F200_FECHA_NACIMIENTO NVARCHAR(40),
    F015_CELULAR NVARCHAR(20)
);

------------------------------------------------------------
-- CREAR TABLA TEMPORAL CLIENTE
------------------------------------------------------------
CREATE TABLE #cliente (
    F201_ID_TERCERO NVARCHAR(40),
	F201_ID_SUCURSAL NVARCHAR(10),
    F201_DESCRIPCION_SUCURSAL NVARCHAR(100),
	F201_ID_MONEDA NVARCHAR(10),
	F201_ID_TIPO_CLI NVARCHAR(10),
    F201_ID_LISTA_PRECIO NVARCHAR(10),
    F015_CONTACTO NVARCHAR(100),
    F015_DIRECCION1 NVARCHAR(40),
    F015_DIRECCION2 NVARCHAR(40),
    F015_DIRECCION3 NVARCHAR(40),
    F015_ID_PAIS NVARCHAR(3),
    F015_ID_DEPTO NVARCHAR(3),
    F015_ID_CIUDAD NVARCHAR(3),
    F015_TELEFONO NVARCHAR(20),
    F015_EMAIL NVARCHAR(255),
    F201_FECHA_INGRESO NVARCHAR(20),
    F015_CELULAR NVARCHAR(20)
);

------------------------------------------------------------
-- LOOP PRINCIPAL
------------------------------------------------------------
WHILE @counter <= @total
BEGIN
    --------------------------------------------------------
    -- TOMAR JSON DE LA ORDEN
    --------------------------------------------------------
    SET @json = (
        SELECT orden_obj
        FROM (
            SELECT orden_obj, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
            FROM #ordenes
        ) x
        WHERE rn = @counter
    );

    --------------------------------------------------------
    -- UBICACIÓN EN SIESA
    --------------------------------------------------------
    SELECT @paisSiesa='169', @dptoSiesa='05', @ciudadSiesa='001';

    SELECT TOP 1
        @paisSiesa = ISNULL(f013_id_pais, @paisSiesa),
        @dptoSiesa = ISNULL(f013_id_depto, @dptoSiesa),
        @ciudadSiesa = ISNULL(f013_id, @ciudadSiesa)
    FROM locaciones_erp
    WHERE dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.billing_address.country')))
      AND dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(
            CASE WHEN JSON_VALUE(@json, '$.billing_address.province') = 'Bogotá, D.C.' 
                 THEN 'Bogota'
                 ELSE JSON_VALUE(@json, '$.billing_address.province')
            END
        ))
      AND dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(
            CASE WHEN JSON_VALUE(@json, '$.billing_address.province') = 'Bogotá, D.C.'
                 THEN 'Bogotá, D.C.'
                 ELSE JSON_VALUE(@json, '$.billing_address.city')
            END
        ));

    --------------------------------------------------------
    -- VARIABLES
    --------------------------------------------------------
    SET @order = JSON_VALUE(@json, '$.name');

    DECLARE @F200_ID NVARCHAR(40) = ISNULL(JSON_VALUE(@json, '$.billing_address.company'), JSON_VALUE(@json, '$.customer.default_address.company'));
    --DECLARE @F200_RAZON_SOCIAL NVARCHAR(100) = UPPER(ISNULL(JSON_VALUE(@json, '$.billing_address.name'), JSON_VALUE(@json, '$.customer.default_address.name')));
	DECLARE @F200_RAZON_SOCIAL NVARCHAR(100) = LEFT( UPPER(ISNULL(JSON_VALUE(@json, '$.billing_address.name'),JSON_VALUE(@json, '$.customer.default_address.name') ) ),39);
    DECLARE @F015_DIRECCION1 NVARCHAR(40) = UPPER(JSON_VALUE(@json, '$.customer.default_address.address1'));
    DECLARE @F015_DIRECCION2 NVARCHAR(40) = UPPER(JSON_VALUE(@json, '$.customer.default_address.address2'));
    DECLARE @F015_TELEFONO NVARCHAR(20) = REPLACE(JSON_VALUE(@json, '$.customer.default_address.phone'), '+57', '');
    DECLARE @F015_EMAIL NVARCHAR(255) = JSON_VALUE(@json, '$.customer.email');
    DECLARE @FECHA NVARCHAR(40) = REPLACE(CONVERT(VARCHAR(10), CAST(JSON_VALUE(@json, '$.customer.created_at') AS DATE)), '-', '');



	--------------------------------------------------------
    -- REGLA TIPO CLIENTE SEGÚN PASARELA DE PAGO
    --------------------------------------------------------
    DECLARE @pasarela NVARCHAR(100) = JSON_VALUE(@json, '$.payment_gateway_names[0]');

    DECLARE @F201_ID_TIPO_CLI NVARCHAR(40) = 
        CASE 
            WHEN @pasarela = 'Crédito fácil Sumas'			THEN '0005'
            WHEN @pasarela = 'Crédito fácil Sistecrédito'	THEN '0003'
            WHEN @pasarela = 'Crédito fácil Addi'			THEN '0008'
            WHEN @pasarela LIKE '%Mercado Pago%'           THEN '0002'
            
        END;

    --------------------------------------------------------
    -- LIMPIAR TABLAS TEMPORALES PARA REUSO
    --------------------------------------------------------
    TRUNCATE TABLE #tercero;
    TRUNCATE TABLE #cliente;

    --------------------------------------------------------
    -- INSERTAR EN TABLA TEMPORAL TERCERO
    --------------------------------------------------------
    INSERT INTO #tercero
    SELECT 
        F200_ID = @F200_ID,
        F200_NIT = @F200_ID,
        F200_RAZON_SOCIAL = @F200_RAZON_SOCIAL,
        F200_APELLIDO1 = LEFT(UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name')), CHARINDEX(' ', UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name')) + ' ') - 1),
        F200_APELLIDO2 = LTRIM(SUBSTRING(UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name')), CHARINDEX(' ', UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name')) + ' '), LEN(UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name'))) - CHARINDEX(' ', UPPER(JSON_VALUE(@json, '$.customer.default_address.last_name'))) + 1)),
        F200_NOMBRES = UPPER(JSON_VALUE(@json, '$.customer.default_address.first_name')),
		F200_NOMBRE_EST = UPPER(JSON_VALUE(@json, '$.customer.default_address.name')),
        F015_CONTACTO = UPPER(JSON_VALUE(@json, '$.customer.default_address.name')),
        F015_DIRECCION1 = @F015_DIRECCION1,
        F015_DIRECCION2 = @F015_DIRECCION2,
        F015_DIRECCION3 = '',
        F015_ID_PAIS = @paisSiesa,
        F015_ID_DEPTO = @dptoSiesa,
        F015_ID_CIUDAD = @ciudadSiesa,
        F015_TELEFONO = @F015_TELEFONO,
        F015_EMAIL = @F015_EMAIL,
        F200_FECHA_NACIMIENTO = @FECHA,
        F015_CELULAR = @F015_TELEFONO;

    --------------------------------------------------------
    -- INSERTAR EN TABLA TEMPORAL CLIENTE
    --------------------------------------------------------
    INSERT INTO #cliente
    SELECT 
        F201_ID_TERCERO = @F200_ID,
		F201_ID_SUCURSAL = '001',
        F201_DESCRIPCION_SUCURSAL = @F200_RAZON_SOCIAL,
		F201_ID_MONEDA = 'COP',
		F201_ID_TIPO_CLI = @F201_ID_TIPO_CLI,
        F201_ID_LISTA_PRECIO = '01',
        F015_CONTACTO = @F200_RAZON_SOCIAL,
        F015_DIRECCION1 = @F015_DIRECCION1,
        F015_DIRECCION2 = @F015_DIRECCION2,
        F015_DIRECCION3 = '',
        F015_ID_PAIS = @paisSiesa,
        F015_ID_DEPTO = @dptoSiesa,
        F015_ID_CIUDAD = @ciudadSiesa,
        F015_TELEFONO = @F015_TELEFONO,
        F015_EMAIL = @F015_EMAIL,
        F201_FECHA_INGRESO = @FECHA,
        F015_CELULAR = @F015_TELEFONO;

    --------------------------------------------------------
    -- CONSTRUIR JSON FINAL
    --------------------------------------------------------
    INSERT INTO @final(idDocumento, descripcion, indicaParalelismo, idOrden, json)
    SELECT  
        @idDocumento,
        @descripcionConector,
        @indicaParalelismo,
        @order AS idOrden,
        (
            SELECT
                [Terceros] = (SELECT * FROM #tercero FOR JSON PATH, INCLUDE_NULL_VALUES),
                [Clientes] = (SELECT * FROM #cliente FOR JSON PATH, INCLUDE_NULL_VALUES),
                [ImptosyReten] = (SELECT @F200_ID AS F_ID_TERCERO FOR JSON PATH, INCLUDE_NULL_VALUES),
                [CriteriosClientes] = (SELECT @F200_ID AS F207_ID_TERCERO FOR JSON PATH, INCLUDE_NULL_VALUES),
                [EntidadDinamicaTercero] = (
                    SELECT *
                    FROM (
                        SELECT @F200_ID AS f200_id, 'EUNOECO017' AS f753_id_entidad, 'co017_codigo_regimen' AS f753_id_atributo, 'MUNOECO016' AS f753_id_maestro, '49' AS f753_id_maestro_detalle
                        UNION ALL SELECT @F200_ID, 'EUNOECO017', 'co017_cod_tipo_oblig', 'MUNOECO019', 'R-99-PN'
                        UNION ALL SELECT @F200_ID, 'EUNOECO031', 'co031_detalle_tributario1', 'MUNOECO035', 'ZZ'
                        UNION ALL SELECT @F200_ID, 'EUNOECO032', 'co032_tipo_cod', 'MUNOECO038', '999'
                        UNION ALL SELECT @F200_ID, 'EUNOECO036', 'co036_id_procedencia_org', 'MUNOECO043', '10'
                    ) E
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                ),
                [EntidadDinamicaCliente] = (
                    SELECT @F200_ID AS f201_id_tercero, @F015_EMAIL AS f753_dato_texto FOR JSON PATH, INCLUDE_NULL_VALUES
                )
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );

    SET @counter = @counter + 1;
END

------------------------------------------------------------
-- RESULTADO FINAL
------------------------------------------------------------
SELECT * FROM @final  ---where idorden IN( '#11741');