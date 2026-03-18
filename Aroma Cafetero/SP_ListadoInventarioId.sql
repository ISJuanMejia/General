SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SP_ListadoInventarioId] -- [SP_ListadoInventarioId] 1
@IdStore int
AS
BEGIN
	SET NOCOUNT ON;
	--exec Sp_InventariosMerge
	select distinct sku--,max(Order_detail.RowId) as RowId
    into  #tmpSku
    from order_head
    inner join Order_detail on order_head.order_id=Order_detail.order_id
    where status in(4,7) --and sku in('202120401021')
	except
	select distinct sku--,max(Order_detail.RowId) as RowId
    from order_head
    inner join Order_detail on order_head.order_id=Order_detail.order_id
    where status not in(4,7) --and sku in('202120401021')

    union all
	select distinct Products.sku
    from Products
	inner join Inventory       on Products.Inventory_item_id=Inventory.inventory_item_id
	inner join Inventory_Siesa on Products.Sku=Inventory_Siesa.EAN
	left join Order_detail on Products.Sku=Order_detail.sku
	where rowid is null


	select Inventory.location_id
		,Inventory.available
	    ,Inventory.inventory_item_id
		,Inventory_Siesa.cantidad  as inventory_quantity--,Inventory_Siesa.cantidad,Inventory.available
		,Products.Sku
	from Products
	inner join Inventory       on Products.Inventory_item_id=Inventory.inventory_item_id
	inner join Inventory_Siesa on Products.Sku=Inventory_Siesa.EAN
	left join stores           on Inventory.location_id=stores.location_id
	inner join #tmpSku         on Products.sku=#tmpSku.sku
	where Inventory_Siesa.cantidad <>Inventory.available
	and stores.id_store=@IdStore --AND Products.Sku = 'INSU-0050'
	--and Inventory.inventory_item_id=44298015473826
	DROP TABLE #tmpSku
	end
GO
