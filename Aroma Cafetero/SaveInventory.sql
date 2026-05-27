SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SaveInventory]
 @inventory_item_id   nvarchar(100),
 @location_id         nvarchar(100) = '',
 @available	          int,
 @updated_at          datetime2
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    -- Validar que la cantidad no sea negativa
    IF @available < 0
    BEGIN
        RAISERROR ('La cantidad disponible no puede ser negativa.', 16, 1);
        RETURN;
    END

    -- Verificar si el registro existe
    IF NOT EXISTS (SELECT * FROM Inventory WHERE inventory_item_id = @inventory_item_id AND location_id = @location_id)
    BEGIN
        -- Insertar nuevo registro
        INSERT INTO Inventory
        VALUES (@inventory_item_id, @location_id, @available, @updated_at, GETDATE());
    END
    ELSE
    BEGIN
        -- Actualizar registro existente
        UPDATE Inventory
        SET available = @available, updated_at = @updated_at, Audit = GETDATE()
        WHERE inventory_item_id = @inventory_item_id AND location_id = @location_id;
    END

    -- Actualizar cantidad en la tabla Products
    UPDATE Products
    SET Inventory_quantity = @available
    WHERE Inventory_item_id = @inventory_item_id;
END
GO
