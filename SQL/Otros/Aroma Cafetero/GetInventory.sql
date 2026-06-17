SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [dbo].[GetInventory]
@Id int=0
AS
BEGIN
	SET NOCOUNT ON;
	EXEC Sp_InventariosMerge
	SELECT
		Stores.Description														AS	Tienda
	    ,Products.ProductId
	    ,Products.sku
	    ,ISNULL(Inventory_Siesa.Cantidad, 0)                                    AS	InventarioSiesa
	    ,ISNULL(Inventory.available, 0)                                         AS	InventarioShopify
		,ABS(
			ISNULL(Inventory_Siesa.Cantidad, 0) - ISNULL(Inventory.available, 0)
		)																		AS	Diferencia
	    ,IIF(Inventory.Audit>='2021-09-01',Inventory.Audit,updated_at)			AS	FechaActualizacion
		 ,''																	AS	color
	FROM Inventory_Siesa
	FULL JOIN Products
		ON	Inventory_Siesa.EAN	=	Products.sku
	LEFT JOIN Inventory
		ON	Products.Inventory_item_id	=	Inventory.inventory_item_id
	LEFT JOIN Stores
		ON	Inventory.location_id	=	Stores.Location_id
	ORDER BY	Inventory.Audit DESC
END
GO
