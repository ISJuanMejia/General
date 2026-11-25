DECLARE @json NVARCHAR(MAX);
DECLARE @conexion VARCHAR(200);
DECLARE @sql NVARCHAR(MAX);

BEGIN TRY
    -- 1. Obtener la cadena de conexión directamente
    SELECT TOP 1 @conexion = cadena_conexion FROM conexiones;
    
    IF @conexion IS NULL
    BEGIN
        SELECT 'No se encontró la cadena de conexión.' AS Mensaje;
        RETURN;
    END

    -- 2. Consulta dinámica directa con las bodegas fijas en el WHERE
    -- Nota: En SQL dinámico, para meter una comilla simple dentro de un string, se usan cuatro comillas ('''')
    SET @sql = N'
    SELECT 
        SUM(ISNULL(TRY_CAST((f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1)) AS INT), 0)) AS cantidad,
        v121_referencia AS codigo_barras,
        MAX(v121_descripcion) AS descripcion,
        ''CONSOLIDADO'' AS bodega -- <-- Ponemos un texto fijo para el grupo en vez de sumar 206+204
    INTO ##inventario_siesa_miche
    FROM OPENROWSET(
        ''sqlncli'',
        ''' + @conexion + ''',
        ''
            SELECT 
                f400_cant_existencia_1,
                f400_cant_comprometida_1,
                f400_cant_pos_1,
                v121_referencia,
                v121_descripcion,
                f150_id
            FROM t400_cm_existencia
            INNER JOIN v121 ON v121.v121_rowid_item_ext = t400_cm_existencia.f400_rowid_item_ext
            INNER JOIN t150_mc_bodegas ON f400_rowid_bodega = f150_rowid AND f400_id_cia = f150_id_cia
            WHERE v121_referencia IS NOT NULL 
              AND f150_id IN (''''206'''', ''''204'''') -- <-- Aquí quedan fijas y bien escapadas para que no fallen
        ''
    ) AS datos
    GROUP BY v121_referencia;'; 

    EXEC sp_executesql @sql;

    -- 3. Armar la tabla temporal para el MERGE sin depender de #bodegas
    SELECT 
        MIN(i.inventory_item_id) AS inventory_item_id, 
        iss.codigo_barras AS sku,
        iss.cantidad, 
        MIN(i.id_location) AS id_location,
        iss.bodega
    INTO #tmpVariantes
    FROM inventario_bodega_ecommerce i
    INNER JOIN ##inventario_siesa_miche iss ON i.sku = iss.codigo_barras
    GROUP BY iss.codigo_barras, iss.bodega, iss.cantidad;
                                    
    -- 4. MERGE final
    MERGE INTO dbo.inventarios AS target
    USING #tmpVariantes AS source
    ON 
        target.sku_erp = source.sku 
        AND 
        target.bodega = source.bodega 
        AND 
        source.inventory_item_id   =   JSON_VALUE(target.inventario_obj, '$.inventory_item_id')
    WHEN MATCHED AND JSON_VALUE(target.inventario_obj, '$.available') <> CAST(source.cantidad AS NVARCHAR) THEN
        UPDATE SET
            target.sincronizado = 0,
            target.fecha_sincronizacion = NULL,
            target.inventario_obj = (JSON_QUERY((
                SELECT source.id_location AS location_id, 
                       source.inventory_item_id, 
                       source.cantidad AS available 
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )))
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (id_variante, bodega, sku_erp, inventario_obj, sincronizado, fecha_sincronizacion)
        VALUES (0, source.bodega, source.sku,
                JSON_QUERY((
                    SELECT source.id_location AS location_id, 
                           source.inventory_item_id, 
                           source.cantidad AS available 
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )),
                0, NULL);

END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() AS 'Error';
    GOTO Cleanup;
END CATCH

Cleanup:
IF OBJECT_ID('tempdb..##inventario_siesa_miche') IS NOT NULL DROP TABLE ##inventario_siesa_miche;
IF OBJECT_ID('tempdb..#tmpVariantes') IS NOT NULL DROP TABLE #tmpVariantes;