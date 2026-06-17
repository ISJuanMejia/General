SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SP_ListadoInventarioId] -- [SP_ListadoInventarioId] 1
@IdStore int
AS
BEGIN
    -- DECLARE @IdStore int = 1
	SET NOCOUNT ON;
	EXEC    Sp_InventariosMerge;

    DECLARE @sku_list   TABLE
    (
        sku NVARCHAR(100)
    );

    INSERT INTO @sku_list
	SELECT DISTINCT
		sku--,max(Order_detail.RowId) as RowId
    FROM	[integracion-AromaCafetero].dbo.order_head
    	INNER JOIN [integracion-AromaCafetero].dbo.Order_detail
			ON
				order_head.order_id	=	Order_detail.order_id
    WHERE
		status IN (4,7) --and sku in('202120401021')
	EXCEPT
	SELECT DISTINCT 
		sku--,max(Order_detail.RowId) as RowId
    FROM [integracion-AromaCafetero].dbo.order_head
    	INNER JOIN [integracion-AromaCafetero].dbo.Order_detail 
			ON 
				order_head.order_id	=	Order_detail.order_id
    WHERE
		status NOT IN (4,7) --and sku in('202120401021')
    UNION ALL
	SELECT DISTINCT 
		Products.sku
    FROM [integracion-AromaCafetero].dbo.Products
		INNER JOIN [integracion-AromaCafetero].dbo.Inventory
			ON
				Products.Inventory_item_id	=	Inventory.inventory_item_id
		INNER JOIN [integracion-AromaCafetero].dbo.Inventory_Siesa
			ON
				Products.Sku	=	Inventory_Siesa.EAN
		LEFT JOIN [integracion-AromaCafetero].dbo.Order_detail
			ON
				Products.Sku	=	Order_detail.sku
	WHERE 
		rowid IS NULL;

	SELECT 
		Inventory.location_id,
		Inventory.available,
		Inventory.inventory_item_id,
		inventory_quantity	=	SUM(Inventory_Siesa.cantidad), --,Inventory_Siesa.cantidad,Inventory.available
		Products.Sku
	FROM [integracion-AromaCafetero].dbo.Products
		INNER JOIN [integracion-AromaCafetero].dbo.Inventory
			ON
				Products.Inventory_item_id	=	Inventory.inventory_item_id
		INNER JOIN [integracion-AromaCafetero].dbo.Inventory_Siesa 
			ON
				Products.Sku	=	Inventory_Siesa.EAN
		LEFT JOIN [integracion-AromaCafetero].dbo.stores
			ON
				Inventory.location_id	=	stores.location_id
		INNER JOIN @sku_list AS sku_list
			ON
				Products.sku	=	sku_list.sku
	WHERE
        NULLIF(NULLIF(TRIM(Products.sku), ''), '-1')    IS NOT NULL
        AND
		Inventory_Siesa.cantidad	<>	Inventory.available
		AND 
		stores.id_store	=	@IdStore
	GROUP BY
		Inventory.location_id,
		Inventory.available,
		Inventory.inventory_item_id,
		Products.Sku
    ORDER BY sku;
	END
GO