SET XACT_ABORT ON;
DECLARE @json VARCHAR(MAX) = '';
DECLARE @final table (idDocumento int,indicaParalelismo bit,descripcion varchar(100),idOrden varchar(50),json varchar(max))
DECLARE @TmpError table (indicaError int,idDocumento int, indicaParalelismo bit, descripcionError varchar(max),idOrden varchar(50))
DECLARE @idDocumento INT = 227666,
        @indicaParalelismo BIT = 0,
		@descripcion varchar(100) = 'Pedidos De Venta'
DECLARE @counter INT = 1;
DECLARE @total INT;
DECLARE @order varchar(30)
DECLARE @tmpDescuento table ([row] int,amount nvarchar(20))
DECLARE @paymentType NVARCHAR(MAX)
DECLARE @paymentValue NVARCHAR(MAX)

DECLARE	@conexion	            VARCHAR(max)
		,@bd		            VARCHAR(100)


SELECT TOP 1 
	@conexion   =   cadena_conexion
	,@bd        =   base_datos 
FROM conexiones

begin try

IF OBJECT_ID('tempdb..##tmp_OrdenesCreadas_natura') IS NOT NULL 
    DROP TABLE ##tmp_OrdenesCreadas_natura;

CREATE TABLE ##tmp_OrdenesCreadas_natura
(
    f430_referencia VARCHAR(50)
);

INSERT INTO ##tmp_OrdenesCreadas_natura (f430_referencia)
EXEC('
    SELECT
        DISTINCT f430_referencia
    FROM OPENROWSET(
        ''SQLNCLI''
        ,''' + @conexion + '''
        ,
        ''
			SELECT 
				f430_referencia
			FROM ' + @bd + '.dbo.t430_cm_pv_docto
			WHERE 
				f430_ind_estado <> 9
				AND f430_id_cia = 1
        ''
    )
')

IF OBJECT_ID('tempdb..##tmp_Items2') IS NOT NULL 
    DROP TABLE ##tmp_Items2;

CREATE TABLE ##tmp_Items2
(
    barcodeTemp VARCHAR(50)
);

INSERT INTO ##tmp_Items2 (barcodeTemp)
EXEC('
    SELECT
        f131_id as barcodeTemp
    FROM OPENROWSET(
        ''SQLNCLI''
        ,''' + @conexion + '''
        ,
        ''
			SELECT 
				CIB.f131_id
			FROM ' + @bd + '.dbo.t120_mc_items a
				INNER JOIN ' + @bd + '.dbo.t121_mc_items_extensiones b ON a.f120_rowid = b.f121_rowid_item
				INNER JOIN ' + @bd + '.dbo.t131_mc_items_barras CIB ON b.f121_rowid = CIB.f131_rowid_item_ext
        ''
    )
')

SELECT id_orden, orden_obj
INTO #ordenes
FROM ordenes o
LEFT JOIN ##tmp_OrdenesCreadas_natura oc 
    ON oc.f430_referencia = REPLACE(o.id_orden, '"', '')
WHERE id > 1020
AND id_estado = 2
AND intentos <= 3


SET @total = (SELECT COUNT(*) FROM #ordenes);
WHILE @counter <= @total
BEGIN
    SET @json = (
        SELECT orden_obj
        FROM (
            SELECT orden_obj ,row_number() over (order by (select null)) as rn
            FROM #ordenes
        ) AS temp
		 where rn = @counter);

    SET @order = JSON_VALUE(@json, '$.name')

--validar metodos de pago
	SELECT TOP 1
		@paymentType = [value],
		@paymentValue = CASE 
			WHEN value = 'ePayco' THEN '003'
			ELSE '000' 
		END
	FROM OPENJSON(@json, '$.payment_gateway_names') as payment
	WHERE [value] != 'gift_card'
	ORDER BY [key] desc

 --encabezado
select 
	FORMAT(GETDATE(), 'yyyyMMdd')										as f430_id_fecha
	,isnull(
		JSON_VALUE(@json, '$.billing_address.company'),
		JSON_VALUE(@json, '$.customer.default_address.company'))	as f430_id_tercero_fact
	,isnull(
		JSON_VALUE(@json, '$.billing_address.company'),
		JSON_VALUE(@json, '$.customer.default_address.company'))	as f430_id_tercero_rem
	,FORMAT(GETDATE(), 'yyyyMMdd')										as f430_fecha_entrega
	,JSON_VALUE(@json, '$.id')									as f430_num_docto_referencia
	,@paymentType														as f430_notas
	,'53153993'															as f430_id_tercero_vendedor	
	,FORMAT(GETDATE(), 'yyyyMMdd')										as f430_fecha_entrega_min
	,FORMAT(GETDATE(), 'yyyyMMdd')										as f430_fecha_entrega_max
INTO #pedidos

--movimiento
SELECT
    t.barcodeTemp								as f431_codigo_barras
    ,FORMAT(GETDATE(), 'yyyyMMdd')				as f431_fecha_entrega
    ,JSON_VALUE(LineItems.value, '$.quantity')	as f431_cant_pedida_base
	,@paymentType as f431_notas
INTO #movimientos
FROM OPENJSON(@json, '$.line_items') AS LineItems
	INNER JOIN variantes v ON v.id_variante = JSON_VALUE(LineItems.value, '$.variant_id')
	INNER JOIN ##tmp_Items2 t ON t.barcodeTemp = JSON_VALUE(v.variante_obj, '$.barcode')
ORDER BY JSON_VALUE(LineItems.value, '$.id');

--Actuiza el inventario
/*
UPDATE Inv
SET Inv.sincronizado = 0
FROM Inventarios Inv
INNER JOIN  OPENJSON(@json, '$.line_items') AS  LineItems ON Inv.id_variante   =   JSON_VALUE(LineItems.value, '$.variant_id');
*/

-- valida si tiene envio
SELECT JSON_VALUE(ShippingLines.value, '$.discount_allocations[0].amount') as amount
INTO #Shipping_lines
FROM OPENJSON(@json,'$.shipping_lines') AS ShippingLines

if not exists (SELECT amount FROM #Shipping_lines WHERE amount is not null)
begin
    INSERT INTO #movimientos (
        f431_codigo_barras,
        f431_fecha_entrega,
        f431_cant_pedida_base,
		f431_notas
    )
    SELECT
        0,
        FORMAT(GETDATE(),'yyyyMMdd'),
        1,
		''
    FROM OPENJSON(@json,'$.shipping_lines') AS sl
    WHERE JSON_VALUE(sl.value,'$.price') NOT IN ('0.00','0')
      AND JSON_VALUE(sl.value,'$.is_removed') = 'false';
end

--valida el descuento
if exists (SELECT value FROM OPENJSON(@json,'$.discount_applications'))
begin
SELECT * ,@json as json
into #descuentostemp
FROM OPENJSON(@json) WITH (
    discount_applications nvarchar(max) '$.discount_applications[0].type',
	[value] nvarchar(5) '$.discount_applications[0].value',
	[name] varchar(10) '$.name',
	[target_type] varchar(50) '$.discount_applications[0].target_type',
	[value_type] varchar(50) '$.discount_applications[0].value_type'
) AS c1

--valida descuento por linea
if exists (select top 1 target_type from #descuentostemp where target_type='line_item')
begin
insert into @tmpDescuento
SELECT  ROW_NUMBER() OVER (ORDER BY (JSON_VALUE(LineItems.value, '$.id'))) as f431_nro_registro,
		convert(money,JSON_VALUE(Discount.value, '$.amount'))/convert(money,JSON_VALUE(LineItems.value, '$.quantity'))  as f432_vlr_uni
	FROM OPENJSON(@json, '$.line_items') AS LineItems
    CROSS APPLY OPENJSON(LineItems.value, '$.discount_allocations') AS Discount
end

end --termina descuento

insert into @final(idDocumento,indicaParalelismo,descripcion,idOrden,json)
select @idDocumento,@indicaParalelismo, @descripcion,@order as idOrden,(
SELECT
    [Pedidos] = (
        SELECT *
        FROM #pedidos
        FOR JSON PATH
    ),
    [Movimiento] = (
        SELECT *
        FROM #movimientos
        FOR JSON PATH
    ),
    [Descuentos] = (
        SELECT [row] as f431_nro_registro,
		amount as f432_vlr_uni
        FROM @tmpDescuento
       FOR JSON PATH
  )
FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);

 delete @tmpDescuento
IF OBJECT_ID('tempdb..#descuentostemp') IS NOT NULL DROP TABLE #descuentostemp;
IF OBJECT_ID('tempdb..#pedidos') IS NOT NULL DROP TABLE #pedidos;
IF OBJECT_ID('tempdb..#movimientos') IS NOT NULL DROP TABLE #movimientos;
IF OBJECT_ID('tempdb..#descuentos') IS NOT NULL DROP TABLE #descuentos;
IF OBJECT_ID('tempdb..#tmpDescuento') IS NOT NULL DROP TABLE #tmpDescuento;
IF OBJECT_ID('tempdb..#Shipping_lines') IS NOT NULL DROP TABLE #Shipping_lines;
IF OBJECT_ID('tempdb..##tmp_PreciosErp') IS NOT NULL DROP TABLE ##tmp_PreciosErp;

SET @counter = @counter + 1;
end
end try
begin catch
insert into @TmpError
select 1 as indicaError, 0 as idDocumento,0 as indicaParalelismo, ERROR_MESSAGE() as descripcionError,@order as idOrden

goto Cleanup;
end catch
Cleanup:
begin
IF OBJECT_ID('tempdb..#descuentostemp') IS NOT NULL DROP TABLE #descuentostemp;
IF OBJECT_ID('tempdb..#pedidos') IS NOT NULL DROP TABLE #pedidos;
IF OBJECT_ID('tempdb..#movimientos') IS NOT NULL DROP TABLE #movimientos;
IF OBJECT_ID('tempdb..#descuentos') IS NOT NULL DROP TABLE #descuentos;
IF OBJECT_ID('tempdb..#tmpDescuento') IS NOT NULL DROP TABLE #tmpDescuento;
IF OBJECT_ID('tempdb..#Shipping_lines') IS NOT NULL DROP TABLE #Shipping_lines;
IF OBJECT_ID('tempdb..##tmp_PreciosErp') IS NOT NULL DROP TABLE ##tmp_PreciosErp;
IF OBJECT_ID('tempdb..##tmp_OrdenesCreadas_natura') IS NOT NULL DROP TABLE ##tmp_OrdenesCreadas_natura;
IF OBJECT_ID('tempdb..##tmp_Items2') IS NOT NULL DROP TABLE ##tmp_Items2;
IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL DROP TABLE #ordenes;
end

SELECT * from @final AS final_json; 
select * from @TmpError
