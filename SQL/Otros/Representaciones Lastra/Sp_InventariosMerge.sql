SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =========================================================================================
-- Procedimiento: [dbo].[Sp_InventariosMerge]
-- Base de Datos: IntegracionWoocomerce-Representaciones-Lastra
-- Descripción  : Sincronización y combinación (MERGE) de inventario disponible desde Siesa ERP
--                hacia la tabla local Inventory_Siesa (Bodega 00101).
-- Dependencias : Sp_ConsultaConexionSiesa, Connekta..Propiedades, UnoEE_Lastra_Real
-- =========================================================================================
ALTER PROCEDURE [dbo].[Sp_InventariosMerge]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @conexion VARCHAR(1000),
            @bd       VARCHAR(100);

    -- Obtiene la cadena de conexión configurada en Connekta..Propiedades
    EXEC Sp_ConsultaConexionSiesa @conexion OUTPUT, @bd OUTPUT;

    IF OBJECT_ID('tempdb..##tmp_Lastra') IS NOT NULL
        DROP TABLE ##tmp_Lastra;

    -- Extracción de inventarios mediante OPENROWSET
    EXEC('
        SELECT
            CAST((f400_cant_existencia_1 - f400_cant_comprometida_1) - f400_cant_pos_1 AS INT) AS Cantidad,
            f120_referencia                                                                    AS EAN,
            f150_id                                                                            AS Bodega
        INTO ##tmp_Lastra
        FROM OPENROWSET(''SQLNCLI'', ' + @conexion + ', [' + @bd + '].dbo.t120_mc_items)
        INNER JOIN OPENROWSET(''SQLNCLI'', ' + @conexion + ', [' + @bd + '].dbo.t121_mc_items_extensiones) ON f120_rowid = f121_rowid_item
        INNER JOIN OPENROWSET(''SQLNCLI'', ' + @conexion + ', [' + @bd + '].dbo.t400_cm_existencia)        ON f121_rowid = f400_rowid_item_ext
        INNER JOIN OPENROWSET(''SQLNCLI'', ' + @conexion + ', [' + @bd + '].dbo.t150_mc_bodegas)           ON f150_rowid = f400_rowid_bodega
        INNER JOIN Stores                                                                                   ON Warehouse_siesa = f150_id
        WHERE f120_referencia IS NOT NULL
          AND f150_id = ''00101'';
    ');

    -- Merge hacia la tabla de integración
    MERGE Inventory_Siesa AS Destino
    USING ##tmp_Lastra AS Origen 
       ON (Destino.EAN = Origen.EAN AND Destino.Bodega = Origen.Bodega) 

    WHEN MATCHED AND Destino.Cantidad <> Origen.Cantidad THEN 
        UPDATE SET 
            Destino.Cantidad = Origen.Cantidad, 
            Destino.Bodega   = Origen.Bodega, 
            Destino.EAN      = Origen.EAN,
            Destino.Estado   = '0'

    WHEN NOT MATCHED BY TARGET THEN 
        INSERT (Cantidad, Bodega, EAN, Estado) 
        VALUES (Origen.Cantidad, Origen.Bodega, Origen.EAN, '0');

    -- Limpieza de tabla temporal global
    IF OBJECT_ID('tempdb..##tmp_Lastra') IS NOT NULL
        DROP TABLE ##tmp_Lastra;
END
GO
