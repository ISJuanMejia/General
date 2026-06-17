CREATE OR ALTER PROCEDURE Sp_SincronizarInventarioSiesaShopify
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @json       NVARCHAR(MAX);
    DECLARE @conexion   VARCHAR(200);
    DECLARE @bd         VARCHAR(200);
    DECLARE @IdBodegaERP      VARCHAR(5) = '00301';
    DECLARE @IdBodegaShopify  VARCHAR(20) = '64820576410';

    BEGIN TRY
        -- * Obtener datos de conexion Siesa
        EXEC Sp_ConsultaConexionSiesa @conexion OUTPUT, @bd OUTPUT

        -- * Tablas temporales
        DECLARE @t400 TABLE (
            f400_cant_existencia_1 DECIMAL(18, 2),
            f400_cant_comprometida_1 DECIMAL(18, 2),
            f400_cant_pos_1 DECIMAL(18, 2),
            f400_rowid_item_ext VARCHAR(20),
            f400_rowid_bodega VARCHAR(20),
            f400_id_cia VARCHAR(20)
        );

        -- * Cargar existencia desde Siesa
        INSERT INTO @t400
        EXEC('
            SELECT
                f400_cant_existencia_1,
                f400_cant_comprometida_1,
                f400_cant_pos_1,
                f400_rowid_item_ext,
                f400_rowid_bodega,
                f400_id_cia
            FROM OPENROWSET(
                ''sqlncli'',
                ' + @conexion + ',
                ''
                    SELECT
                        f400_cant_existencia_1,
                        f400_cant_comprometida_1,
                        f400_cant_pos_1,
                        f400_rowid_item_ext,
                        f400_rowid_bodega,
                        f400_id_cia
                    FROM ' + @bd + '.dbo.t400_cm_existencia
                ''
            )'
        );

        DECLARE @t121 TABLE (
            f121_rowid VARCHAR(20),
            f121_rowid_item VARCHAR(20),
            f121_id_barras_principal VARCHAR(50)
        );

        -- * Cargar items con codigo de barras desde Siesa
        INSERT INTO @t121
        EXEC('
            SELECT
                f121_rowid,
                f121_rowid_item,
                f121_id_barras_principal
            FROM OPENROWSET(
                ''sqlncli'',
                ' + @conexion + ',
                ''
                    SELECT
                        f121_rowid,
                        f121_rowid_item,
                        f121_id_barras_principal
                    FROM ' + @bd + '.dbo.t121_mc_items_extensiones
                    WHERE f121_id_barras_principal IS NOT NULL
                ''
            )'
        );

        DECLARE @t150 TABLE (
            f150_rowid VARCHAR(20),
            f150_id VARCHAR(20),
            f150_id_cia VARCHAR(20)
        );

        -- * Cargar bodega desde Siesa
        INSERT INTO @t150
        EXEC('
            SELECT
                f150_rowid,
                f150_id,
                f150_id_cia
            FROM OPENROWSET(
                ''sqlncli'',
                ' + @conexion + ',
                ''
                    SELECT
                        f150_rowid,
                        f150_id,
                        f150_id_cia
                    FROM ' + @bd + '.dbo.t150_mc_bodegas
                    WHERE
                        f150_id = ''''' + @IdBodegaERP + '''''
            ''
        )'
        );

        -- * Tabla temporal para los datos actuales
        DECLARE @InventarioActual TABLE (
            VariantId VARCHAR(50),
            Id_Barras_Principal VARCHAR(50),
            Id_Bodega VARCHAR(20),
            id_location VARCHAR(20),
            inventory_item_id VARCHAR(50) NULL,
            Cantidad INT,
            inventory_level_json NVARCHAR(MAX)
        );

        -- * Obtener inventario actual desde Siesa
        INSERT INTO @InventarioActual
        SELECT
            VariantId = Products.VariantId,
            Id_Barras_Principal = t121.f121_id_barras_principal,
            Id_Bodega = t150.f150_id,
            id_location = @IdBodegaShopify,
            inventory_item_id = Products.inventory_item_id,
            Cantidad = 
                CAST(ISNULL(t400.f400_cant_existencia_1, 0) AS INT) - 
                CAST(ISNULL(t400.f400_cant_comprometida_1, 0) AS INT) - 
                CAST(ISNULL(t400.f400_cant_pos_1, 0) AS INT),
            inventory_level_json =
            (
                SELECT
                    location_id = @IdBodegaShopify,
                    Products.inventory_item_id,
                    available = CAST(ISNULL(t400.f400_cant_existencia_1, 0) AS INT) - 
                               CAST(ISNULL(t400.f400_cant_comprometida_1, 0) AS INT) - 
                               CAST(ISNULL(t400.f400_cant_pos_1, 0) AS INT)
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM @t121 AS t121
            INNER JOIN @t400 AS t400 
                ON t121.f121_rowid = t400.f400_rowid_item_ext
            INNER JOIN @t150 AS t150 
                ON t400.f400_rowid_bodega = t150.f150_rowid
                AND t400.f400_id_cia = t150.f150_id_cia
            INNER JOIN Products
                ON TRIM(Products.sku) = TRIM(t121.f121_id_barras_principal);

        -- * MERGE con la tabla InventarioSiesaShopify
        MERGE InventarioSiesaShopify AS TARGET
        USING @InventarioActual AS SOURCE
        ON (TARGET.VariantId = SOURCE.VariantId AND TARGET.id_location = SOURCE.id_location)
        
        -- Cuando existe el registro
        WHEN MATCHED THEN
            UPDATE SET
                TARGET.sincronizado = CASE 
                    WHEN TARGET.Id_Barras_Principal <> SOURCE.Id_Barras_Principal 
                      OR TARGET.Id_Bodega <> SOURCE.Id_Bodega 
                      OR TARGET.Cantidad <> SOURCE.Cantidad 
                      OR ISNULL(TARGET.inventory_item_id, '') <> ISNULL(SOURCE.inventory_item_id, '')
                    THEN 0 
                    ELSE TARGET.sincronizado 
                END,
                TARGET.fecha_sincronizacion = CASE 
                    WHEN TARGET.Id_Barras_Principal <> SOURCE.Id_Barras_Principal 
                      OR TARGET.Id_Bodega <> SOURCE.Id_Bodega 
                      OR TARGET.Cantidad <> SOURCE.Cantidad 
                      OR ISNULL(TARGET.inventory_item_id, '') <> ISNULL(SOURCE.inventory_item_id, '')
                    THEN NULL 
                    ELSE TARGET.fecha_sincronizacion 
                END,
                TARGET.Id_Barras_Principal = SOURCE.Id_Barras_Principal,
                TARGET.Id_Bodega = SOURCE.Id_Bodega,
                TARGET.Cantidad = SOURCE.Cantidad,
                TARGET.inventory_item_id = SOURCE.inventory_item_id,
                TARGET.inventory_level_json = SOURCE.inventory_level_json,
                TARGET.fecha_actualizacion = GETDATE()
        
        -- Cuando no existe el registro
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (VariantId, Id_Barras_Principal, Id_Bodega, id_location, 
                   inventory_item_id, Cantidad, inventory_level_json, 
                   sincronizado, fecha_sincronizacion, fecha_actualizacion)
            VALUES (SOURCE.VariantId, SOURCE.Id_Barras_Principal, SOURCE.Id_Bodega, 
                   SOURCE.id_location, SOURCE.inventory_item_id, SOURCE.Cantidad, 
                   SOURCE.inventory_level_json, 0, NULL, GETDATE());

        -- Retornar estadísticas
        SELECT 
            TotalRegistros = @@ROWCOUNT,
            NuevosRegistros = (SELECT COUNT(*) FROM @InventarioActual ia 
                              WHERE NOT EXISTS (SELECT 1 FROM InventarioSiesaShopify iss 
                                              WHERE iss.VariantId = ia.VariantId 
                                              AND iss.id_location = ia.id_location)),
            RegistrosActualizados = (SELECT COUNT(*) FROM InventarioSiesaShopify 
                                   WHERE sincronizado = 0 
                                   AND fecha_actualizacion >= DATEADD(MINUTE, -5, GETDATE()));

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        -- Insertar en tabla de logs si existe, o retornar error

        -- Re-lanzar el error
        THROW;
    END CATCH;
END;