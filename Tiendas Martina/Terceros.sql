DECLARE @json NVARCHAR(MAX) = '';
DECLARE @final table (idDocumento int,indicaParalelismo bit,descripcion varchar(50),idOrden varchar(50),json varchar(max))
DECLARE @counter INT = 1;
DECLARE @total INT;
DECLARE @order varchar(30)
DECLARE @paisSiesa nvarchar(3),@dptoSiesa nvarchar(3),@ciudadSiesa nvarchar(3);
-- cambiar datos a los reales del conector.
declare @idDocumento int = 207135
declare @descripcionConector varchar(50)='01_Ecommerce_Connekta_Terceros'
declare @indicaParalelismo bit = 1

IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL DROP TABLE #ordenes;

SELECT id_orden, orden_obj
INTO #ordenes
FROM ordenes 
WHERE id_estado='1' and intentos<='3'
--and id_orden='#9970'

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

 select top 1 @paisSiesa=isnull(f013_id_pais,'169') ,@dptoSiesa=isnull(f013_id_depto,'05') ,@ciudadSiesa=isnull(f013_id,'001') 
 from locaciones_erp 
 where 
		replace(replace(replace(replace(replace(lower(f011_descripcion),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')=replace(replace(replace(replace(replace(lower(JSON_VALUE(@json, '$.customer.default_address.country')),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')
 and	replace(replace(replace(replace(replace(lower(f012_descripcion),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')=replace(replace(replace(replace(replace(lower(JSON_VALUE(@json, '$.customer.default_address.province')),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')
 and	replace(replace(replace(replace(replace(lower(f013_descripcion),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')=replace(replace(replace(replace(replace(lower(JSON_VALUE(@json, '$.customer.default_address.city')),'á','a'),'é','e'),'í','i'),'ó','o'),'ú','u')
 
 SET @order=JSON_VALUE(@json, '$.name')

 declare @F200_ID nvarchar(40)= isnull(JSON_VALUE(@json, '$.billing_address.company'),JSON_VALUE(@json, '$.customer.default_address.company'))
 declare @F200_RAZON_SOCIAL nvarchar(100)=upper(isnull(JSON_VALUE(@json, '$.billing_address.name'),JSON_VALUE(@json, '$.customer.default_address.name')))
 declare @F015_DIRECCION1 nvarchar(40)=upper(JSON_VALUE(@json, '$.customer.default_address.address1'))
 declare @F015_DIRECCION2 nvarchar(40)=upper(JSON_VALUE(@json, '$.customer.default_address.address2'))
 declare @F015_TELEFONO nvarchar(20)=replace(JSON_VALUE(@json, '$.customer.default_address.phone'),'+57','')
 declare @F015_EMAIL nvarchar(255)=JSON_VALUE(@json, '$.customer.email')
 declare @FECHA nvarchar(40)=replace(convert(varchar(10), cast(JSON_VALUE(@json, '$.customer.created_at') as date)), '-', '')

 --tercero
 select F200_ID=		  @F200_ID
	   ,F200_NIT=		  @F200_ID
	   ,F200_RAZON_SOCIAL=@F200_RAZON_SOCIAL
	   ,F200_APELLIDO1=   upper(JSON_VALUE(@json, '$.customer.default_address.last_name')) 
	   ,F200_APELLIDO2 =   ''
	   ,F200_NOMBRES=    upper(JSON_VALUE(@json, '$.customer.default_address.first_name'))
	   ,F015_CONTACTO=   CONCAT(upper(JSON_VALUE(@json, '$.customer.default_address.first_name')),' ',upper(JSON_VALUE(@json, '$.customer.default_address.last_name')))
	   ,F015_DIRECCION1=@F015_DIRECCION1
	   ,F015_DIRECCION2=@F015_DIRECCION2
		,F015_ID_PAIS   = ISNULL(@paisSiesa, '169')
		,F015_ID_DEPTO  = ISNULL(@dptoSiesa, '05')
		,F015_ID_CIUDAD = ISNULL(@ciudadSiesa, '001')														
	   ,F015_TELEFONO=  @F015_TELEFONO
	   ,F015_EMAIL=     @F015_EMAIL									
	   ,F200_FECHA_NACIMIENTO=@FECHA
	   ,F015_CELULAR=   @F015_TELEFONO
	   into #tercero

--cliente
select F201_ID_TERCERO=           @F200_ID
	  ,F201_DESCRIPCION_SUCURSAL= @F200_RAZON_SOCIAL
	  ,F201_ID_LISTA_PRECIO =''
	  ,F015_CONTACTO =            @F200_RAZON_SOCIAL
	  ,F015_DIRECCION1 =		  @F015_DIRECCION1
	  ,F015_DIRECCION2 =		  @F015_DIRECCION2
	  ,F015_ID_PAIS   = ISNULL(@paisSiesa, '169')
	   ,F015_ID_DEPTO  = ISNULL(@dptoSiesa, '05')
		,F015_ID_CIUDAD = ISNULL(@ciudadSiesa, '001')	
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
    [ImptosyReten] = (
      SELECT @F200_ID as F_ID_TERCERO
      FOR JSON PATH,INCLUDE_NULL_VALUES
    )
FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);

IF OBJECT_ID('tempdb..#tercero') IS NOT NULL DROP TABLE #tercero;
IF OBJECT_ID('tempdb..#cliente') IS NOT NULL DROP TABLE #cliente;


SET @counter = @counter + 1;
end

SELECT * from @final AS final_json;