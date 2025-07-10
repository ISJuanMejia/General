/*
    ------------------------------------------------------------------------------------------
    Script para sincronización y cálculo de inventarios por variante y bodega desde ERP a BD local
    ------------------------------------------------------------------------------------------
    Descripción general:
    Este script realiza la extracción, transformación y carga (ETL) de información de inventarios
    desde una base de datos ERP remota hacia una estructura local, permitiendo la actualización
    y sincronización de cantidades de inventario por variante de producto y bodega.

    Pasos principales:
    1. Conexión a la base de datos ERP y declaración de variables de conexión.
    2. Extracción de variantes relevantes para la tienda seleccionada.
    3. Obtención de datos de inventario desde tablas del ERP (v121, t400_cm_existencia, t150_mc_bodegas)
       utilizando OPENROWSET para conexión remota.
    4. Cálculo de cantidades disponibles por variante y agrupación por bodega lógica (1_1 y 1_3).
    5. Generación de combinaciones de variantes con ambas bodegas, asegurando que cada variante tenga
       registro para ambas, incluso si la cantidad es cero.
    6. Eliminación de posibles duplicados, dejando solo el registro más reciente por combinación.
    7. (Comentado) MERGE para actualizar o insertar registros en la tabla final de inventarios.
    8. Limpieza de variables tipo tabla utilizadas como temporales.
    9. Manejo de errores mediante TRY...CATCH.

    Notas:
    - El script utiliza variables tipo tabla para manipulación intermedia de datos.
    - El campo 'inventario_obj' se genera en formato JSON para integración con sistemas externos.
    - El MERGE está comentado; descomentar para ejecutar la actualización/inserción final.
    - El script está preparado para ejecutarse en SQL Server.
    - Se recomienda revisar y proteger las credenciales de conexión antes de uso en producción.

    Parámetros importantes:
    - @cadena_conexion: Cadena de conexión al ERP remoto.
    - @base_datos: Nombre de la base de datos ERP.
    - id_tienda: Filtro para la tienda específica (actualmente fijo en 1).
    - Bodegas lógicas: '1_1' y '1_3' corresponden a agrupaciones de bodegas físicas del ERP.

    Autor: Juan Camilo Mejía Echavarría
    Fecha de creación: 10/07/2025
    ------------------------------------------------------------------------------------------
*/
BEGIN TRY

    /*  Conexión a la base de datos */
    DECLARE @cadena_conexion VARCHAR(100) = 'server=ec2-52-6-38-24.compute-1.amazonaws.com;uid=maderkit;pwd=Maderkit$12$%';
    DECLARE @base_datos      VARCHAR(100) = 'UnoEE_Maderkit_Pruebas';

    -- Paso 1: Extraer datos de variantes relevantes
    DECLARE @variantes  TABLE(
        id_tienda               INT
        ,id_variante            INT
        ,sku_erp                VARCHAR(40)
        ,id_variante_ecommerce  INT
    )

    INSERT INTO @variantes
    SELECT 
        p.id_tienda
        ,id_variante    =   v.id
        ,v.sku_erp
        ,v.id_variante_ecommerce
    FROM variantes  AS  v
        INNER JOIN productos    AS  p
            ON  p.id_producto_ecommerce =   v.id_producto_ecommerce
    WHERE
        p.id_tienda     =   1
        AND
        v.sincronizado  =   1;

    /*  Paso 2: Calcular cantidades del ERP por variante y bodega   */
    DECLARE @inventarioERP TABLE(
        id_tienda               INT,
        id_variante_ecommerce   INT,
        id_bodega_ecommerce     VARCHAR(10),
        cantidad                INT
    );

    /*  Obtener información de la v121 del ERP  */
    DECLARE @v121    TABLE  (
        v121_id_cia                 INT,
        v121_id_barras_principal    VARCHAR(40),
        v121_rowid_item_ext         INT
    );

    INSERT INTO @v121
    EXEC('
        SELECT 
            v121_id_cia
            ,v121_id_barras_principal
            ,v121_rowid_item_ext
        FROM OPENROWSET(
            ''SQLNCLI''
            ,''' + @cadena_conexion + '''
            ,''
                SELECT 
                    v121_id_cia
                    ,v121_id_barras_principal
                    ,v121_rowid_item_ext
                FROM ' + @base_datos + '.dbo.v121
                WHERE
                    v121_id_cia = 1
            ''
        )
    ')

    /* Obtener información de la tabla t400_cm_existencia del ERP   */

    DECLARE @t400 TABLE (
        f400_id_cia                 INT,
        f400_rowid_item_ext         INT,
        f400_rowid_bodega           INT,
        f400_cant_existencia_1      INT,
        f400_cant_comprometida_1    INT,
        f400_cant_pos_1             INT
    );

    INSERT INTO @t400
    EXEC('
        SELECT 
            f400_id_cia
            ,f400_rowid_item_ext
            ,f400_rowid_bodega
            ,f400_cant_existencia_1
            ,f400_cant_comprometida_1
            ,f400_cant_pos_1
        FROM OPENROWSET(
            ''SQLNCLI''
            ,''' + @cadena_conexion + '''
            ,''
                SELECT 
                    f400_id_cia
                    ,f400_rowid_item_ext
                    ,f400_rowid_bodega
                    ,f400_cant_existencia_1
                    ,f400_cant_comprometida_1
                    ,f400_cant_pos_1
                FROM ' + @base_datos + '.dbo.t400_cm_existencia
                WHERE
                    f400_id_cia = 1
            ''
        )
    ')

    /* Obtener información de la tabla t150_mc_bodegas del ERP   */

    DECLARE @t150 TABLE (
        f150_id     VARCHAR(10),
        f150_rowid  INT,
        f150_id_cia INT
    );

    INSERT INTO @t150
    EXEC('
        SELECT 
            f150_id
            ,f150_rowid
            ,f150_id_cia
        FROM OPENROWSET(
            ''SQLNCLI''
            ,''' + @cadena_conexion + '''
            ,''
                SELECT 
                    f150_id
                    ,f150_rowid
                    ,f150_id_cia
                FROM ' + @base_datos + '.dbo.t150_mc_bodegas
                WHERE
                    f150_id_cia = 1
            ''
        )
    ')

    INSERT INTO @inventarioERP
    SELECT 
        p.id_tienda,
        v.id_variante_ecommerce,
        id_bodega_ecommerce =   CASE 
            WHEN
                t150.f150_id IN (
                    'CDONL'
                    ,'CDEDM'
                )
                THEN '1_1'
            WHEN
                t150.f150_id IN (
                    'ML430'
                    ,'MO422'
                    ,'ML666'
                    ,'ML213'
                    ,'ML211'
                    ,'PL145'
                    ,'PL147'
                    ,'PL06P'
                    ,'PL07P'
                    ,'PL14P'
                    ,'PL15P'
                    ,'PL08P'
                    ,'PL18P'
                    ,'PL09P'
                    ,'PL10P'
                    ,'PL11P'
                    ,'PL12P'
                    ,'ML607'
                    ,'ML605'
                )
                THEN '1_3'
            END
        ,cantidad   =
            SUM(
                CONVERT(
                    INT
                    ,f400_cant_existencia_1 - (f400_cant_comprometida_1 + f400_cant_pos_1)
                )
            )
    FROM variantes  AS  v
        INNER JOIN productos    AS  p
            ON  p.id_producto_ecommerce =   v.id_producto_ecommerce
        INNER JOIN @v121    AS  v121
            ON
                v121.v121_id_cia = 1
                AND
                v121.v121_id_barras_principal = v.sku_erp COLLATE DATABASE_DEFAULT
                AND
                p.id_tienda = 1
        INNER JOIN @t400    AS  t400
            ON
                t400.f400_id_cia = 1
                AND
                t400.f400_rowid_item_ext = v121.v121_rowid_item_ext
        INNER JOIN @t150    AS  t150
            ON
                t150.f150_id_cia = 1
                AND
                t150.f150_rowid = t400.f400_rowid_bodega
    WHERE
        t150.f150_id    IN  (
            'CDONL'
            ,'CDEDM'
            ,'ML430'
            ,'MO422'
            ,'ML666'
            ,'ML213'
            ,'ML211'
            ,'PL145'
            ,'PL147'
            ,'PL06P'
            ,'PL07P'
            ,'PL14P'
            ,'PL15P'
            ,'PL08P'
            ,'PL18P'
            ,'PL09P'
            ,'PL10P'
            ,'PL11P'
            ,'PL12P'
            ,'ML607'
            ,'ML605'
    )
    GROUP BY
        p.id_tienda
        ,v.id_variante_ecommerce
        ,CASE 
            WHEN
                t150.f150_id   IN  (
                    'CDONL'
                    ,'CDEDM'
                )
                THEN '1_1'
            WHEN t150.f150_id   IN  (
                'ML430'
                , 'MO422'
                , 'ML666'
                , 'ML213'
                , 'ML211'
                , 'PL145'
                , 'PL147'
                , 'PL06P'
                , 'PL07P'
                , 'PL14P'
                , 'PL15P'
                , 'PL08P'
                , 'PL18P'
                , 'PL09P'
                , 'PL10P'
                , 'PL11P'
                , 'PL12P'
                , 'ML607'
                , 'ML605'
            )
            THEN '1_3'
        END;

    -- Paso 3: Generar combinaciones de variantes con ambas bodegas (1_1 y 1_3) usando variable tipo tabla
    DECLARE @InventarioCombinadoPorBodega TABLE (
        id_tienda INT,
        id_variante INT,
        id_variante_ecommerce INT,
        id_bodega_ecommerce VARCHAR(10),
        sku_erp VARCHAR(40),
        cantidad INT,
        inventario_obj NVARCHAR(MAX),
        sincronizado INT,
        fecha_sincronizacion DATETIME
    );

    INSERT INTO @InventarioCombinadoPorBodega (
        id_tienda,
        id_variante,
        id_variante_ecommerce,
        id_bodega_ecommerce,
        sku_erp,
        cantidad,
        inventario_obj,
        sincronizado,
        fecha_sincronizacion
    )
    SELECT 
        v.id_tienda,
        v.id_variante,
        v.id_variante_ecommerce,
        b.id_bodega_ecommerce,
        v.sku_erp,
        cantidad    =   ISNULL(i.cantidad, 0),
        inventario_obj  =
            JSON_QUERY('
                {
                    "unlimitedQuantity": false,
                    "quantity": ' + CAST(ISNULL(i.cantidad, 0) AS VARCHAR) + ',
                    "dateUtcOnBalanceSystem": "",
                    "timeToRefill (deprecated)": ""
                }
            '), -- Generar inventario_obj
        sincronizado    =   0,
        fecha_sincronizacion    =   GETDATE()
    FROM @variantes AS  v
        CROSS JOIN (VALUES ('1_1'), ('1_3')) b(id_bodega_ecommerce) -- Crear combinaciones explícitas para las dos bodegas
        LEFT JOIN @inventarioERP    AS  i
            ON
                v.id_variante_ecommerce =   i.id_variante_ecommerce
                AND
                b.id_bodega_ecommerce   =   i.id_bodega_ecommerce;


    -- Paso 4: Eliminar duplicados en @InventarioCombinadoPorBodega
    DECLARE @InventarioFinalSinDuplicados TABLE (
        id_tienda INT,
        id_variante INT,
        id_variante_ecommerce INT,
        id_bodega_ecommerce VARCHAR(10),
        sku_erp VARCHAR(40),
        cantidad INT,
        inventario_obj NVARCHAR(MAX),
        sincronizado INT,
        fecha_sincronizacion DATETIME
    );

    WITH CTE AS (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY 
                    id_tienda,
                    id_variante_ecommerce,
                    id_bodega_ecommerce
                ORDER BY fecha_sincronizacion DESC
            ) AS rn
        FROM @InventarioCombinadoPorBodega
    )
    INSERT INTO @InventarioFinalSinDuplicados
    SELECT
        id_tienda,
        id_variante,
        id_variante_ecommerce,
        id_bodega_ecommerce,
        sku_erp,
        cantidad,
        inventario_obj,
        sincronizado,
        fecha_sincronizacion
    FROM CTE
    WHERE rn = 1;   
    /*
    -- Paso 5: MERGE para actualizar las filas que tienen diferencias
    MERGE INTO dbo.inventarios AS target
    USING @InventarioFinalSinDuplicados AS source
        ON (
            target.id_tienda    =   source.id_tienda
            AND
            target.id_variante_ecommerce    =   source.id_variante_ecommerce 
            AND
            target.id_bodega_ecommerce = source.id_bodega_ecommerce)
    WHEN MATCHED AND (target.cantidad <> source.cantidad) THEN
        UPDATE SET 
            target.cantidad = source.cantidad,
            target.inventario_obj = source.inventario_obj, -- Actualizar inventario_obj
            target.sincronizado = 0, -- Marcar como no sincronizado
            target.fecha_sincronizacion = source.fecha_sincronizacion
    WHEN NOT MATCHED THEN
        INSERT (
            id_tienda
            ,id_variante
            ,id_variante_ecommerce
            ,id_bodega_ecommerce
            ,sku_erp
            ,cantidad
            ,inventario_obj
            ,sincronizado
            ,fecha_sincronizacion
        )
        VALUES (
            source.id_tienda,
            source.id_variante,
            source.id_variante_ecommerce,
            source.id_bodega_ecommerce,
            source.sku_erp,
            source.cantidad,
            source.inventario_obj,
            source.sincronizado, 
            source.fecha_sincronizacion
        );

    */
    /*  Limpieza de tablas temporales   */
    DELETE @inventarioERP;
    DELETE @InventarioCombinadoPorBodega;
    DELETE @InventarioFinalSinDuplicados;

END TRY
BEGIN CATCH
    PRINT 'Error: ' + ERROR_MESSAGE();
END CATCH