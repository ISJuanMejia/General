SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Sp_InventariosMerge]
AS
BEGIN
-- Declarar variables
DECLARE @conexion VARCHAR(1000),
        @bd VARCHAR(100);

-- Obtener conexión y base de datos
EXEC Sp_ConsultaConexionSiesa @conexion OUTPUT, @bd OUTPUT;

-- Declarar la variable de tabla
DECLARE @data TABLE (
    Cantidad INT,
    Bodega VARCHAR(50),
    EAN VARCHAR(50),
    Descripcion NVARCHAR(255)
);

-- Insertar datos directamente en la variable de tabla
INSERT INTO @data (Cantidad, Bodega, EAN, Descripcion)
EXEC('
    SELECT 
        CASE 
            WHEN (f400_cant_existencia_1 - f400_cant_comprometida_1 - f400_cant_salida_sin_conf_1) < 0 THEN 0
            ELSE CONVERT(INT, (f400_cant_existencia_1 - f400_cant_comprometida_1 - f400_cant_salida_sin_conf_1))
        END AS Cantidad,
        F150_ID AS Bodega,
        f120_referencia AS EAN,
        f120_descripcion AS Descripcion
    FROM OPENROWSET(''SQLNCLI'', ' + @conexion + ', [' + @bd + '].dbo.T120_MC_ITEMS) AS T120
    INNER JOIN OPENROWSET(''SQLNCLI'', ' + @conexion + ', [' + @bd + '].dbo.t121_mc_items_extensiones) AS T121
        ON T120.f120_rowid = T121.f121_rowid_item
    INNER JOIN OPENROWSET(''SQLNCLI'', ' + @conexion + ', [' + @bd + '].dbo.t400_cm_existencia) AS T400
        ON T121.f121_rowid = T400.f400_rowid_item_ext
    INNER JOIN OPENROWSET(''SQLNCLI'', ' + @conexion + ', [' + @bd + '].dbo.t150_mc_bodegas) AS T150
        ON T400.f400_rowid_bodega = T150.f150_rowid
    WHERE F120_NOTAS != '''' AND T150.f150_id = T120.f120_notas
');

-- Realizar el MERGE
MERGE Inventory_Siesa AS Destino
USING @data AS Origen
   ON (Destino.EAN = Origen.EAN AND Destino.Bodega = Origen.Bodega)
WHEN MATCHED AND Destino.Cantidad <> Origen.Cantidad AND Destino.Estado = '0'
  THEN 
   UPDATE SET Destino.Cantidad     = Origen.Cantidad, 
              Destino.Bodega       = Origen.Bodega, 
              Destino.EAN          = Origen.EAN,
              Destino.Estado       = '0', 
              Destino.Descripcion  = Origen.Descripcion
WHEN NOT MATCHED BY TARGET THEN 
   INSERT (Cantidad, Bodega, EAN, Estado, Descripcion) 
   VALUES (Origen.Cantidad, Origen.Bodega, Origen.EAN, '0', Origen.Descripcion);

END
GO
