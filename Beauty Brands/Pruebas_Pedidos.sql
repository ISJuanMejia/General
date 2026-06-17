/*SELECT COUNT(*) FROM ordenes
SELECT COUNT(*) FROM ordenes WHERE id_estado = 1
SELECT COUNT(*) FROM ordenes WHERE id_estado = 2
SELECT COUNT(*) FROM ordenes WHERE id_estado = 3*/

DECLARE @conexion   NVARCHAR(MAX);
DECLARE @base_datos NVARCHAR(MAX);

  SELECT TOP 1 
    @conexion   = cadena_conexion,
    @base_datos = base_datos 
  FROM conexiones

  DECLARE @items_erp TABLE (
    f120_id         NVARCHAR(100),
    f120_descripcion NVARCHAR(100),
    f121_id_barras_principal NVARCHAR(100),
    f131_id NVARCHAR(100)
  )

  /*
		*	Consulta a la tabla de pedidos del ERP
	*/
    INSERT INTO @items_Erp
	EXEC
    (
        '
        SELECT DISTINCT 
            f120_id,
                    f120_descripcion,
                    f121_id_barras_principal,
                    f131_id
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f120_id,
                    f120_descripcion,
                    f121_id_barras_principal,
                    f131_id
                FROM t120_mc_items
                    LEFT JOIN t121_mc_items_extensiones
                        ON
                            f120_rowid  =   f121_rowid_item
                    LEFT JOIN t131_mc_items_barras
                        ON 
                            f121_rowid  =   f131_rowid_item_ext
                WHERE
                    f120_id_cia =   2
            ''
        )
        '
    );

  DECLARE @ordenes TABLE (
		id_orden	NVARCHAR(20),
		orden_obj	NVARCHAR(MAX)
	);

INSERT INTO @ordenes
SELECT TOP 25 id_orden, orden_obj
FROM ordenes
WHERE
    intentos > 0
    AND
    id_estado =2
ORDER BY ID DESC


  DECLARE @json VARCHAR(MAX) = '';
  DECLARE @counter        INT = 1;
  DECLARE @total          INT;
  DECLARE @order          varchar(30)

  SET @total = (SELECT COUNT(*) FROM @ordenes);
   
  WHILE @counter <= @total
  BEGIN
    BEGIN TRY
      SET @json = (
          SELECT
              orden_obj
          FROM (
              SELECT
                  orden_obj,
                  rn  =   ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
              FROM @ordenes
          ) AS temp
          WHERE
              rn  =   @counter
      );

      SET @order  =   JSON_VALUE(@json, '$.name');

      SELECT
        quantity                =   JSON_VALUE(LI.value, '$.name'),
        sku                     =   JSON_VALUE(LI.value, '$.sku'),
        @order--,
        -- f120_descripcion
      FROM OPENJSON(@json,'$.line_items') AS LI
        -- LEFT JOIN @items_erp ON 
        --     f121_id_barras_principal    =   JSON_VALUE(LI.value, '$.sku')
        --     OR
        --     f131_ID = JSON_VALUE(LI.value, '$.sku');
        
        SET @counter = @counter + 1;
    END TRY
    BEGIN CATCH
      SELECT
        ErrorNumber     =   ERROR_NUMBER(),
        ErrorSeverity   =   ERROR_SEVERITY(),
        ErrorState      =   ERROR_STATE(),
        ErrorProcedure  =   ERROR_PROCEDURE(),
        ErrorLine       =   ERROR_LINE(),
        ErrorMessage    =   ERROR_MESSAGE();
      /*
      UPDATE [shopify-colombia-beautybrands].dbo.ordenes
      SET intentos = intentos + 1
      WHERE
          id_orden = @order
      */
    END CATCH
  END

  /*
  /*SELECT COUNT(*) FROM ordenes
SELECT COUNT(*) FROM ordenes WHERE id_estado = 1
SELECT COUNT(*) FROM ordenes WHERE id_estado = 2
SELECT COUNT(*) FROM ordenes WHERE id_estado = 3*/

DECLARE @conexion   NVARCHAR(MAX);
DECLARE @base_datos NVARCHAR(MAX);

  SELECT TOP 1 
    @conexion   = cadena_conexion,
    @base_datos = base_datos 
  FROM conexiones

  DECLARE @items_erp TABLE (
    f120_id         NVARCHAR(100),
    f120_descripcion NVARCHAR(100),
    f121_id_barras_principal NVARCHAR(100),
    f131_id NVARCHAR(100)
  )

  /*
		*	Consulta a la tabla de pedidos del ERP
	*/
    INSERT INTO @items_Erp
	EXEC
    (
        '
        SELECT DISTINCT 
            f120_id,
                    f120_descripcion,
                    f121_id_barras_principal,
                    f131_id
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f120_id,
                    f120_descripcion,
                    f121_id_barras_principal,
                    f131_id
                FROM t120_mc_items
                    LEFT JOIN t121_mc_items_extensiones
                        ON
                            f120_rowid  =   f121_rowid_item
                    LEFT JOIN t131_mc_items_barras
                        ON 
                            f121_rowid  =   f131_rowid_item_ext
                WHERE
                    f120_id_cia =   2
            ''
        )
        '
    );

  DECLARE @ordenes TABLE (
		id_orden	NVARCHAR(20),
		orden_obj	NVARCHAR(MAX)
	);

INSERT INTO @ordenes
SELECT TOP 25 id_orden, orden_obj
FROM ordenes
WHERE
    intentos > 0
    AND
    id_estado =2
ORDER BY ID DESC


  DECLARE @json VARCHAR(MAX) = '';
  DECLARE @counter        INT = 1;
  DECLARE @total          INT;
  DECLARE @order          varchar(30)

  SET @total = (SELECT COUNT(*) FROM @ordenes);
   
  WHILE @counter <= @total
  BEGIN
    BEGIN TRY
      SET @json = (
          SELECT
              orden_obj
          FROM (
              SELECT
                  orden_obj,
                  rn  =   ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
              FROM @ordenes
          ) AS temp
          WHERE
              rn  =   @counter
      );

      SET @order  =   JSON_VALUE(@json, '$.name');

      SELECT
        name                =   JSON_VALUE(LI.value, '$.name'),
        sku                     =   JSON_VALUE(LI.value, '$.sku'),
        @order,
        f120_descripcion
      FROM OPENJSON(@json,'$.line_items') AS LI
        LEFT JOIN @items_erp ON 
            f121_id_barras_principal    =   JSON_VALUE(LI.value, '$.sku')
            OR
            f131_ID = JSON_VALUE(LI.value, '$.sku');
    END TRY
    BEGIN CATCH
      SELECT
        ErrorNumber     =   ERROR_NUMBER(),
        ErrorSeverity   =   ERROR_SEVERITY(),
        ErrorState      =   ERROR_STATE(),
        ErrorProcedure  =   ERROR_PROCEDURE(),
        ErrorLine       =   ERROR_LINE(),
        ErrorMessage    =   ERROR_MESSAGE();
      /*
      UPDATE [shopify-colombia-beautybrands].dbo.ordenes
      SET intentos = intentos + 1
      WHERE
          id_orden = @order
      */
    END CATCH
  END*/