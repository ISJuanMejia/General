SET XACT_ABORT ON;
DECLARE @json VARCHAR(MAX) = '';
DECLARE @final table (idDocumento int,indicaParalelismo bit,descripcion varchar(100),idOrden varchar(50),json varchar(max))
DECLARE @TmpError table (indicaError int,idDocumento int, indicaParalelismo bit, descripcionError varchar(max),idOrden varchar(50))
DECLARE @idDocumento INT = 215646,
        @indicaParalelismo BIT = 0,
		@descripcion varchar(100) = 'Pedido_Eccomerce'
DECLARE @counter INT = 1;
DECLARE @total INT;
DECLARE @order varchar(30)
DECLARE @tmpDescuento table ([row] int,amount nvarchar(20))
DECLARE @paymentType NVARCHAR(MAX)
DECLARE @paymentValue NVARCHAR(MAX)

begin try
DECLARE @base_datos NVARCHAR(MAX) = (SELECT TOP 1 base_datos FROM Conexiones);

-- armamos la referencia a la tabla
DECLARE @sql NVARCHAR(MAX) = '
SELECT DISTINCT f430_referencia 
INTO ##tmp_OrdenesCreadas
FROM ' + QUOTENAME(@base_datos) + '.dbo.t430_cm_pv_docto
WHERE f430_ind_estado != 9 
  AND f430_id_cia = 1;
';

EXEC(@sql);

DECLARE @sql2 NVARCHAR(MAX);

SET @sql2 = '
SELECT 
    a.f120_referencia,
    b.f121_id_ext2_detalle,
    c.f117_descripcion,
    c.f117_id
INTO ##tmp_Items2
FROM ' + QUOTENAME(@base_datos) + '.dbo.t120_mc_items a
INNER JOIN ' + QUOTENAME(@base_datos) + '.dbo.t121_mc_items_extensiones b 
    ON a.f120_rowid = b.f121_rowid_item
INNER JOIN ' + QUOTENAME(@base_datos) + '.dbo.t117_mc_extensiones1_detalle c 
    ON b.f121_id_ext1_detalle = c.f117_id;
';

EXEC(@sql2);


SELECT id_orden, orden_obj
INTO #ordenes
FROM ordenes o
LEFT JOIN ##tmp_OrdenesCreadas oc 
    ON oc.f430_referencia = REPLACE(o.id_orden, '"', '')
WHERE id_estado = 2
AND intentos <= 3;


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
			WHEN value = 'Sistecredito' THEN '003'
			WHEN value = 'Addi Payment' THEN '004'
			WHEN value = 'Wompi' THEN '006'
			WHEN value = 'Checkout Mercado Pago' OR value = 'Mercado Pago Checkout Pro' THEN '007'
			ELSE '001' 
		END
	FROM OPENJSON(@json, '$.payment_gateway_names') as payment
	WHERE [value] != 'gift_card'
	ORDER BY [key] desc

 --encabezado
select 
	FORMAT(GETDATE(), 'yyyyMMdd')								as f430_id_fecha
	,isnull(JSON_VALUE(@json, '$.billing_address.company'),JSON_VALUE(@json, '$.customer.default_address.company'))	as f430_id_tercero_fact
	,'001'                                                      as f430_id_sucursal_fact
	,isnull(JSON_VALUE(@json, '$.billing_address.company'),JSON_VALUE(@json, '$.customer.default_address.company'))	as f430_id_tercero_rem
	,'001'                                                      as f430_id_sucursal_rem
	,FORMAT(GETDATE(), 'yyyyMMdd')								as f430_fecha_entrega
	,'1'														as f430_num_dias_entrega
	,JSON_VALUE(@json, '$.name')								as f430_num_docto_referencia
	,JSON_VALUE(@json, '$.name')								as f430_referencia	
	,@paymentType								                as f430_notas
	,''                                                         as f430_id_tercero_vendedor	
into #pedidos

--movimiento
SELECT
    ROW_NUMBER() OVER (ORDER BY (JSON_VALUE(LineItems.value, '$.id'))) as f431_nro_registro,
    LEFT(JSON_VALUE(LineItems.value, '$.sku'),
         CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku')) - 1) as f431_referencia_item,
    ISNULL(trim(t.f117_id),'') as f431_id_ext1_detalle,
    ISNULL(trim(t.f121_id_ext2_detalle), '') AS f431_id_ext2_detalle,

    'BOWB'  as f431_id_bodega,
    '01'    as f431_id_motivo,
    FORMAT(GETDATE(), 'yyyyMMdd') as f431_fecha_entrega,
    1       as f431_num_dias_entrega,
    'UND'   as f431_id_unidad_medida,
    JSON_VALUE(LineItems.value, '$.quantity') as f431_cant_pedida_base,
    '003'   as f431_id_lista_precio
INTO #movimientos
FROM OPENJSON(@json, '$.line_items') AS LineItems
LEFT JOIN ##tmp_Items2 t
    ON t.f120_referencia = LEFT(JSON_VALUE(LineItems.value, '$.sku'),
                                CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku')) - 1)
   AND t.f117_descripcion = RIGHT(JSON_VALUE(LineItems.value, '$.sku'),
                                  LEN(JSON_VALUE(LineItems.value, '$.sku')) - CHARINDEX('/', JSON_VALUE(LineItems.value, '$.sku')))
AND t.f121_id_ext2_detalle =
    CASE
        WHEN ISNUMERIC(
            CASE
                WHEN CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku')) > 0
                     AND CHARINDEX('/', JSON_VALUE(LineItems.value, '$.sku')) > CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku'))
                THEN SUBSTRING(
                        JSON_VALUE(LineItems.value, '$.sku'),
                        CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku')) + 1,
                        CHARINDEX('/', JSON_VALUE(LineItems.value, '$.sku')) - CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku')) - 1
                     )
                ELSE JSON_VALUE(LineItems.value, '$.sku')
            END
        ) = 1
        THEN RIGHT('00' +
            CASE
                WHEN CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku')) > 0
                     AND CHARINDEX('/', JSON_VALUE(LineItems.value, '$.sku')) > CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku'))
                THEN SUBSTRING(
                        JSON_VALUE(LineItems.value, '$.sku'),
                        CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku')) + 1,
                        CHARINDEX('/', JSON_VALUE(LineItems.value, '$.sku')) - CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku')) - 1
                     )
                ELSE JSON_VALUE(LineItems.value, '$.sku')
            END, 2)
        ELSE
            CASE
                WHEN CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku')) > 0
                     AND CHARINDEX('/', JSON_VALUE(LineItems.value, '$.sku')) > CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku'))
                THEN SUBSTRING(
                        JSON_VALUE(LineItems.value, '$.sku'),
                        CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku')) + 1,
                        CHARINDEX('/', JSON_VALUE(LineItems.value, '$.sku')) - CHARINDEX('-', JSON_VALUE(LineItems.value, '$.sku')) - 1
                     )
                ELSE JSON_VALUE(LineItems.value, '$.sku')
            END
    END
ORDER BY JSON_VALUE(LineItems.value, '$.id');

--Actuiza el inventario
UPDATE Inv
SET Inv.sincronizado = 0
FROM Inventarios Inv
INNER JOIN  OPENJSON(@json, '$.line_items') AS  LineItems ON Inv.id_variante   =   JSON_VALUE(LineItems.value, '$.variant_id');

-- valida si tiene envio
SELECT JSON_VALUE(ShippingLines.value, '$.discount_allocations[0].amount') as amount
INTO #Shipping_lines
FROM OPENJSON(@json,'$.shipping_lines') AS ShippingLines

if not exists (SELECT amount FROM #Shipping_lines WHERE amount is not null)
begin
    INSERT INTO #movimientos (
        f431_nro_registro,
        f431_referencia_item,
        f431_id_ext1_detalle,
        f431_id_ext2_detalle,
        f431_id_bodega,
        f431_id_motivo,
        f431_fecha_entrega,
        f431_num_dias_entrega,
        f431_id_unidad_medida,
        f431_cant_pedida_base,
        f431_id_lista_precio
    )
    SELECT
        0,
        '0000715',
        '',           -- f431_id_ext1_detalle
        '',           -- f431_id_ext2_detalle
        'BOWB',       -- f431_id_bodega
        '01',         -- f431_id_motivo
        FORMAT(GETDATE(),'yyyyMMdd'),
        1,
        'UND',
        1,
        '003'
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
    [Movto_Pedidos_Comercial] = (
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
IF OBJECT_ID('tempdb..##tmp_OrdenesCreadas') IS NOT NULL DROP TABLE ##tmp_OrdenesCreadas;
IF OBJECT_ID('tempdb..##tmp_Items2') IS NOT NULL DROP TABLE ##tmp_Items2;
IF OBJECT_ID('tempdb..#ordenes') IS NOT NULL DROP TABLE #ordenes;
end

SELECT * from @final AS final_json; 
select * from @TmpError
