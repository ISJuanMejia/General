SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Sp_InventariosMerge]
AS
BEGIN
-- Declarar variables
    DECLARE @conexion   VARCHAR(1000),
            @bd         VARCHAR(100);

    -- Obtener conexión y base de datos
    EXEC Sp_ConsultaConexionSiesa @conexion OUTPUT, @bd OUTPUT;

    -- Declarar la variable de tabla
    DECLARE @data TABLE (
        Cantidad    INT,
        Bodega      VARCHAR(50),
        EAN         VARCHAR(50),
        Descripcion NVARCHAR(255)
    );

    /*
    *   21/04/2026 -> JCMEJIAE: Se refactorizó la consulta que obtiene el inventario desde el ERP, este es el bloque de código
    *               original si depronto es necesario revertir cambios
    EXEC('
        SELECT 
            Cantidad    =   
                CASE 
                    WHEN 
                        (SUM(f400_cant_existencia_1) - SUM(f400_cant_comprometida_1) - SUM(f400_cant_salida_sin_conf_1)) < 0 
                        THEN 0
                    ELSE CONVERT(INT, (SUM(f400_cant_existencia_1) - SUM(f400_cant_comprometida_1) - SUM(f400_cant_salida_sin_conf_1)))
                END,
            Bodega      =   F150_ID,
            EAN         =   f120_referencia,
            Descripcion =   f120_descripcion
        FROM OPENROWSET(''SQLNCLI'',' + @conexion + ',[' + @bd + '].dbo.T120_MC_ITEMS) AS T120
            INNER JOIN OPENROWSET(''SQLNCLI'', ' + @conexion + ', [' + @bd + '].dbo.t121_mc_items_extensiones) AS T121
                ON
                    T120.f120_rowid =   T121.f121_rowid_item
            INNER JOIN OPENROWSET(''SQLNCLI'', ' + @conexion + ', [' + @bd + '].dbo.t400_cm_existencia) AS T400
                ON
                    T121.f121_rowid =   T400.f400_rowid_item_ext
            INNER JOIN OPENROWSET(''SQLNCLI'', ' + @conexion + ', [' + @bd + '].dbo.t150_mc_bodegas) AS T150
                ON
                    T400.f400_rowid_bodega  =   T150.f150_rowid
        WHERE
            f120_id_cia = 2
            AND
            f121_id_cia = 2
            AND
            f150_id_cia = 2
            AND
            F120_NOTAS  != '''' 
            AND 
            T150.f150_id    =   T120.f120_notas
        GROUP BY
            F150_ID,
            f120_referencia,
            f120_descripcion
    ');
    */

    -- Insertar datos directamente en la variable de tabla
    INSERT INTO @data (
        Cantidad, 
        Bodega, 
        EAN, 
        Descripcion
    )
    --  *   21/04/2026 -> JCMEJIAE: Este es la consulta refactorizada de inventarios, se obtienen menos registros que 
    --  *                   la anterior debido a la agrupación de datos (los SUM y el GROUP BY)
    EXEC('
        SELECT DISTINCT
            Cantidad    =   
                CASE 
                    WHEN 
                        (SUM(f400_cant_existencia_1) - SUM(f400_cant_comprometida_1) - SUM(f400_cant_salida_sin_conf_1)) < 0 
                        THEN 0
                    ELSE CONVERT(INT, (SUM(f400_cant_existencia_1) - SUM(f400_cant_comprometida_1) - SUM(f400_cant_salida_sin_conf_1)))
                END,
            Bodega      =   F150_ID,
            EAN         =   f120_referencia,
            Descripcion =   f120_descripcion
        FROM OPENROWSET(''SQLNCLI'',' + @conexion + ',['+@bd+'].dbo.t120_mc_items)  AS t120
            INNER JOIN OPENROWSET(''SQLNCLI'',' + @conexion + ',['+ @bd +'].dbo.t121_mc_items_extensiones)    AS  t121
                ON
                    f120_rowid  = f121_rowid_item
            INNER JOIN OPENROWSET(''SQLNCLI'',' + @conexion + ',[' + @bd + '].dbo.t400_cm_existencia)   AS  t400
                ON
                    f121_rowid  =   f400_rowid_item_ext
            INNER JOIN OPENROWSET(''SQLNCLI'',' + @conexion + ',[' + @bd + '].dbo.t150_mc_bodegas) AS t150
                ON
                    f150_rowid  =   f400_rowid_bodega
        WHERE
            f120_id_cia = 2
            AND
            f121_id_cia = 2
            AND
            f150_id_cia = 2
            AND
            f150_id IN (''002'', ''003'', ''005'', ''007'')
            AND
            F120_NOTAS  != '''' 
            AND 
            f150_id    =   f120_notas
        GROUP BY f120_referencia, f120_notas, f150_id,f120_descripcion
        ORDER BY f120_referencia
    ');

    -- Realizar el MERGE
    MERGE Inventory_Siesa AS Destino
    USING @data AS Origen
        ON (
            Destino.EAN = Origen.EAN 
            AND 
            Destino.Bodega = Origen.Bodega
        )
    WHEN 
        MATCHED 
        AND 
        Destino.Cantidad <> Origen.Cantidad 
        AND 
        Destino.Estado = '0'
        THEN 
            UPDATE SET 
                Destino.Cantidad    =   Origen.Cantidad,
                Destino.Bodega      =   Origen.Bodega,
                Destino.EAN         =   Origen.EAN,
                Destino.Estado      =   '0',
                Destino.Descripcion =   Origen.Descripcion
    WHEN NOT MATCHED BY TARGET THEN 
   INSERT (Cantidad, Bodega, EAN, Estado, Descripcion) 
   VALUES (Origen.Cantidad, Origen.Bodega, Origen.EAN, '0', Origen.Descripcion);

END
GO
