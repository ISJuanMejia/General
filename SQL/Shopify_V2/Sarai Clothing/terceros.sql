DECLARE @json NVARCHAR(MAX) = '';
DECLARE @final table (idDocumento int,indicaParalelismo bit,descripcion varchar(50),idOrden varchar(50),json varchar(max))
DECLARE @counter INT = 1;
DECLARE @total INT;
DECLARE @order varchar(30)
DECLARE @paisSiesa nvarchar(3),@dptoSiesa nvarchar(3),@ciudadSiesa nvarchar(3);
-- cambiar datos a los reales del conector.
declare @idDocumento int = 214917
declare @descripcionConector varchar(50)= 'Terceros_Clientes_Eccomerce'
declare @indicaParalelismo bit =1


IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL DROP TABLE #ordenes;

SELECT id_orden, orden_obj
INTO #ordenes
FROM ordenes 
WHERE id_estado =1
and intentos<=3 
--and id_orden='2985'

SET @total = (SELECT COUNT(*) FROM #ordenes);
WHILE @counter <= @total
BEGIN

    SET @json = (
        SELECT orden_obj
        FROM (
            SELECT orden_obj, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
            FROM #ordenes
        ) AS temp
        WHERE rn = @counter
    );
 select @paisSiesa='169',@dptoSiesa='05',@ciudadSiesa='001'

SELECT TOP 1 
    @paisSiesa   = f013_id_pais,
    @dptoSiesa   = f013_id_depto,
    @ciudadSiesa = f013_id
FROM locaciones_erp
WHERE dbo.fn_NormalizarTexto(f011_descripcion) = dbo.fn_NormalizarTexto(JSON_VALUE(@json, '$.customer.default_address.country'))
  AND dbo.fn_NormalizarTexto(f012_descripcion) = dbo.fn_NormalizarTexto(
        CASE WHEN JSON_VALUE(@json, '$.customer.default_address.province') = 'Bogotá, D.C.' THEN 'Bogota'
            ELSE JSON_VALUE(@json, '$.customer.default_address.province') END )
  AND dbo.fn_NormalizarTexto(f013_descripcion) = dbo.fn_NormalizarTexto(
        CASE WHEN JSON_VALUE(@json, '$.customer.default_address.province') = 'Bogotá, D.C.' THEN 'Bogotá, D.C.'
            ELSE JSON_VALUE(@json, '$.customer.default_address.city') END );


 SET @order=JSON_VALUE(@json, '$.name')

 declare @F200_ID nvarchar(40)= isnull(JSON_VALUE(@json, '$.billing_address.company'),JSON_VALUE(@json, '$.customer.default_address.company'))
 declare @F200_RAZON_SOCIAL nvarchar(100)=left(upper(isnull(JSON_VALUE(@json, '$.billing_address.name'),JSON_VALUE(@json, '$.customer.default_address.name'))),40)
 declare @F015_DIRECCION1 nvarchar(40)=upper(JSON_VALUE(@json, '$.customer.default_address.address1'))
 declare @F015_DIRECCION2 nvarchar(40)=upper(JSON_VALUE(@json, '$.customer.default_address.address2'))
 declare @F015_TELEFONO nvarchar(20)=replace(JSON_VALUE(@json, '$.customer.default_address.phone'),'+57','')
 declare @F015_EMAIL nvarchar(255)=JSON_VALUE(@json, '$.customer.email')
 declare @FECHA nvarchar(40)=replace(convert(varchar(10), cast(JSON_VALUE(@json, '$.customer.created_at') as date)), '-', '')
 --tercero
 select F200_ID=		  @F200_ID
	   ,F200_NIT=		  @F200_ID
	   ,F200_RAZON_SOCIAL=@F200_RAZON_SOCIAL
	   ,F200_APELLIDO1=   left(upper(JSON_VALUE(@json, '$.customer.default_address.last_name')), 
							charindex(' ', upper(JSON_VALUE(@json, '$.customer.default_address.last_name')) + ' ') - 1) 
	  ,F200_APELLIDO2=     ltrim(substring(upper(JSON_VALUE(@json, '$.customer.default_address.last_name')), 
			charindex(' ', upper(JSON_VALUE(@json, '$.customer.default_address.last_name')) + ' '), 
			len(upper(JSON_VALUE(@json, '$.customer.default_address.last_name'))) - 
			charindex(' ', upper(JSON_VALUE(@json, '$.customer.default_address.last_name'))) + 1)) 
	   ,F200_NOMBRES=    left(upper(JSON_VALUE(@json, '$.customer.default_address.first_name')), 40)
	   ,F015_CONTACTO=   left(upper(JSON_VALUE(@json, '$.customer.default_address.name')), 40)
	   ,F015_DIRECCION1=@F015_DIRECCION1
	   ,F015_DIRECCION2=@F015_DIRECCION2
	   ,F015_DIRECCION3 =		  ''
	   ,F015_ID_PAIS=   @paisSiesa															
	   ,F015_ID_DEPTO=  @dptoSiesa															
	   ,F015_ID_CIUDAD= @ciudadSiesa														
	   ,F015_TELEFONO=  @F015_TELEFONO
	   ,F015_EMAIL=     @F015_EMAIL									
	   ,F200_FECHA_NACIMIENTO=@FECHA
	   ,F015_CELULAR=   @F015_TELEFONO
	   into #tercero

--cliente
select F201_ID_TERCERO=           @F200_ID
	  ,F201_DESCRIPCION_SUCURSAL= @F200_RAZON_SOCIAL
	,F201_ID_TIPO_CLI = 
		CASE 
			WHEN EXISTS (SELECT 1 FROM OPENJSON(@json, '$.payment_gateway_names') WHERE TRIM(value) = 'Sistecredito') THEN '010'
			WHEN EXISTS (SELECT 1 FROM OPENJSON(@json, '$.payment_gateway_names') WHERE TRIM(value) = 'Addi Payment') THEN '015'
			WHEN EXISTS (SELECT 1 FROM OPENJSON(@json, '$.payment_gateway_names') WHERE TRIM(value) = 'Mercado Pago Checkout Pro') THEN '013'
			ELSE '012'
		END
	  ,F015_CONTACTO =            @F200_RAZON_SOCIAL
	  ,F015_DIRECCION1 =		  @F015_DIRECCION1
	  ,F015_DIRECCION2 =		  @F015_DIRECCION2
	  ,F015_DIRECCION3 =		  ''
	  ,F015_ID_PAIS =			  @paisSiesa
	  ,F015_ID_DEPTO =			  @dptoSiesa
	  ,F015_ID_CIUDAD =			  @ciudadSiesa
	  ,F015_TELEFONO=			  @F015_TELEFONO
	  ,F015_EMAIL=                @F015_EMAIL
	  ,F201_FECHA_INGRESO =       @FECHA
	  ,F015_CELULAR=              @F015_TELEFONO  
	  into #cliente


insert into @final(idDocumento,descripcion,indicaParalelismo,idOrden,json)
select  @idDocumento ,@descripcionConector,@indicaParalelismo ,@order as idOrden,(
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
	[Imptos_Reten] = (
	SELECT 
		'46' AS F_TIPO_REG,
		@F200_ID AS F_ID_TERCERO,
		'001' AS F_ID_SUCURSAL,
		'1' AS F_ID_CLASE,
		'1' AS F_ID_VALOR_TERCERO
	FOR JSON PATH, INCLUDE_NULL_VALUES
    )
FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);

IF OBJECT_ID('tempdb..#tercero') IS NOT NULL DROP TABLE #tercero;
IF OBJECT_ID('tempdb..#cliente') IS NOT NULL DROP TABLE #cliente;


SET @counter = @counter + 1;
end

SELECT * from @final AS final_json;