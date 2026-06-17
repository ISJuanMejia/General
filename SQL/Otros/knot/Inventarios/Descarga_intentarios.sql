/** KNOT - DESCARGA DE INVENTARIO DESDE SIESA **/
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
        f121_id_barras_principal VARCHAR(20)
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

    -- * Descargar inventario
    SELECT
        VariantId,
        Id_Barras_Principal     =   f121_id_barras_principal,
        Id_Bodega               =   f150_id,
        id_location             =   @IdBodegaShopify,
        inventory_item_id,
        Cantidad                = 
            CAST(ISNULL(f400_cant_existencia_1, 0) AS INT) - CAST(ISNULL(f400_cant_comprometida_1, 0) AS INT) - CAST(ISNULL(f400_cant_pos_1, 0) AS INT),
        inventory_level_json    =
        (
            SELECT
                location_id = @IdBodegaShopify,
                inventory_item_id,
                available = CAST(ISNULL(f400_cant_existencia_1, 0) AS INT) - CAST(ISNULL(f400_cant_comprometida_1, 0) AS INT) - CAST(ISNULL(f400_cant_pos_1, 0) AS INT)
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    FROM @t121 AS t121
        INNER JOIN @t400 AS t400 
            ON 
                t121.f121_rowid = t400.f400_rowid_item_ext
        INNER JOIN @t150 AS t150 
            ON 
                t400.f400_rowid_item_ext = t121.f121_rowid
                AND
                t400.f400_rowid_bodega = t150.f150_rowid
        INNER JOIN Products
            ON
                TRIM(sku) = TRIM(t121.f121_id_barras_principal)
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();

    SELECT
        CAST(1 AS BIT) AS indicaError,
        CONCAT('Error: ', @ErrorMessage, ' Severity: ', @ErrorSeverity, ' State: ', @ErrorState) AS descripcionError;
END CATCH;