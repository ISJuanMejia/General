DELETE inv
FROM    [shopify-colombia-womder].[dbo].[inventarios]   inv
    LEFT JOIN [shopify-colombia-womder].[dbo].variantes var
        ON
            inv.sku_erp =   var.sku_erp
WHERE
    var.sku_erp IS NULL