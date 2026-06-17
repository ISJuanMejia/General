---CONECTOR PEDIDOS BEAUTYBRANDS VERSION FINAL
SET XACT_ABORT ON;
BEGIN TRY
  DECLARE @json VARCHAR(MAX) = '';
  
  DECLARE @final table
  (
    idDocumento         int,
    indicaParalelismo   bit,
    descripcion         varchar(MAX),
    idOrden             varchar(50),
    json                varchar(max)
  )
  DECLARE @idDocumento        INT             =   226458,
          @indicaParalelismo  BIT             =   0,
          @descripcion        VARCHAR(100)    =   'Ecommerce_Pedidos_Estandar';
  
  DECLARE @counter        INT = 1;
  DECLARE @total          INT;
  DECLARE @order          varchar(30)

  /*
      *	Definición de la sección de Descuentos del conector
    */
  DECLARE @vendedor       NVARCHAR(50)

  DECLARE @unidad_negocio NVARCHAR(10)

  DECLARE @id_item_flete     NVARCHAR(20) = '85' -- Referencia del flete en SIESA

  DECLARE @t430_cm_pv_docto TABLE (
    f430_num_docto_referencia   NVARCHAR(15)
  );

  /*
		*	Definición de la sección de Pedidos del conector
	*/
  DECLARE @Pedidos TABLE (
    f430_id_fecha               NVARCHAR(8),
    f430_id_tercero_fact        NVARCHAR(15),
    f430_id_tercero_rem         NVARCHAR(15),
    f430_id_tipo_cli_fact       NVARCHAR(4),
    f430_fecha_entrega          NVARCHAR(8),
    f430_referencia             NVARCHAR(10),
    f430_num_docto_referencia   NVARCHAR(15),
    f430_notas                  NVARCHAR(2000),
    f430_id_tercero_vendedor    NVARCHAR(15)
  );

  /*
		*	Definición de la sección de Movto Pedidos comercial del conector
	*/
  DECLARE @Movto_Pedidos_comercial TABLE (
    id                    NVARCHAR(50),
    f431_nro_registro     NVARCHAR(10),
    f431_id_item          NVARCHAR(50),
    f431_codigo_barras    NVARCHAR(50),
    f431_id_un_movto      NVARCHAR(10),
    f431_fecha_entrega    NVARCHAR(8),
    f431_cant_pedida_base NVARCHAR(10),
    f431_precio_unitario  NVARCHAR(20)
  );

	DECLARE @Descuentos	TABLE (
		f431_nro_registro	NVARCHAR(10),
    f432_vlr_uni        NVARCHAR(20)
	);

  DECLARE @line_items TABLE
  (
    id                      NVARCHAR(20),
    price                   NVARCHAR(20),
    quantity                NVARCHAR(20),
    sku                     NVARCHAR(20),
    discount_amount         NVARCHAR(MAX)
  );
	
  DECLARE @conexion   NVARCHAR(MAX);
  DECLARE @base_datos NVARCHAR(MAX);

  SELECT TOP 1 
    @conexion   = cadena_conexion,
    @base_datos = base_datos 
  FROM conexiones

  /*
		*	Consulta a la tabla de pedidos del ERP
	*/
    INSERT INTO @t430_cm_pv_docto
	EXEC
    (
        '
        SELECT DISTINCT 
            f430_num_docto_referencia
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT 
                    f430_num_docto_referencia
                FROM ' + @base_datos + '.[dbo].[t430_cm_pv_docto]
                    WHERE
                        F430_id_tipo_docto = ''''CPS''''
                        AND
                        f430_ind_estado != 9
                        AND 
                        f430_id_cia = 2
            ''
        )
        '
    );

    UPDATE ord
    SET id_estado = 2
    FROM [shopify-colombia-beautybrands].[dbo].[ordenes] AS ord 
        LEFT JOIN @t430_cm_pv_docto
            ON
                f430_num_docto_referencia   =   id_orden
    WHERE
        id_estado   >=  3
        AND
        f430_num_docto_referencia   IS NULL
    
  DECLARE @ordenes TABLE (
		id_orden	NVARCHAR(20),
		orden_obj	NVARCHAR(MAX)
	);

  INSERT INTO @ordenes
  SELECT TOP 25
    id_orden,
    orden_obj
  FROM ordenes
    LEFT JOIN @t430_cm_pv_docto oc
      ON
        oc.f430_num_docto_referencia  =   REPLACE(id_orden, '"', '')
  WHERE
    id_estado   =   2
    AND
    intentos    <=  3
    AND
    oc.f430_num_docto_referencia IS NULL
  ORDER BY ID DESC;

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

      SET @order  =   JSON_VALUE(@json, '$.name')
      DECLARE @tags NVARCHAR(MAX) = LOWER(ISNULL(JSON_VALUE(@json,'$.order.tags'), ''));

      SET @vendedor   = '';
      SET @unidad_negocio = '';
      IF CHARINDEX('whatsapp', @tags) > 0
      BEGIN
          SET @unidad_negocio = '002'
          SET @vendedor = '1000566733' -- Maria Camila Sosa Ospina
      END
      ELSE IF CHARINDEX('ecommerce', @tags) > 0
      BEGIN
          SET @unidad_negocio = '007'
      END
      ELSE SET @unidad_negocio = '007'
      IF ISNULL(NULLIF(@vendedor, ''), '') = '' SET @vendedor = '901182975' --BeautyBrands

      DECLARE @fecha_actual   VARCHAR(8)  =   FORMAT(CAST(JSON_VALUE(@json, '$.updated_at') AS DATE),'yyyyMMdd');
      DECLARE @fecha_entrega  VARCHAR(8)  =   FORMAT(DATEADD(DAY,1,CAST(JSON_VALUE(@json, '$.updated_at') AS DATE)),'yyyyMMdd');

      /*
        * PEDIDOS
      */
      INSERT INTO @Pedidos
      (
        f430_id_fecha,
        f430_id_tercero_fact,
        f430_id_tercero_rem,
        f430_fecha_entrega,
        f430_num_docto_referencia,
        f430_notas,
        f430_id_tercero_vendedor
      )
      select
        f430_id_fecha               =   @fecha_actual,
        f430_id_tercero_fact        =   LEFT(isnull(JSON_VALUE(@json, '$.billing_address.company'),JSON_VALUE(@json, '$.customer.default_address.company')), 15),
        f430_id_tercero_rem         =   LEFT(isnull(JSON_VALUE(@json, '$.billing_address.company'),JSON_VALUE(@json, '$.customer.default_address.company')), 15),
        f430_fecha_entrega          =   @fecha_entrega,
        f430_num_docto_referencia   =   @order,
        f430_notas                  =   @order,
        f430_id_tercero_vendedor    =   @vendedor

      INSERT INTO @line_items
      (
        id,
        price,
        quantity,
        sku,
        discount_amount
      )
      SELECT
        id                      =   JSON_VALUE(LI.value, '$.id'),
        price                   =   JSON_VALUE(LI.value, '$.price_set.presentment_money.amount'),
        quantity                =   JSON_VALUE(LI.value, '$.quantity'),
        sku                     =   JSON_VALUE(LI.value, '$.sku'),
        discount_amount         =
          (
            SELECT
              amount          =   
                SUM(
                  CAST(
                    JSON_VALUE(DA.value, '$.amount') AS DECIMAL(10,4)
                  )
                ) / CAST(
                  JSON_VALUE(LI.value, '$.quantity') AS INT
                )
            FROM OPENJSON(LI.VALUE, '$.discount_allocations') AS DA
          )
      FROM OPENJSON(@json,'$.line_items') AS LI;

        /*
      SELECT
        quantity                =   JSON_VALUE(LI.value, '$.name'),
        sku                     =   JSON_VALUE(LI.value, '$.sku'),
        @order
      FROM OPENJSON(@json,'$.line_items') AS LI;*/

      /*
        * MOVIMIENTO
      */
      INSERT INTO @Movto_Pedidos_comercial
      (
        id,
        f431_nro_registro,
        f431_id_item,
        f431_codigo_barras,
        f431_id_un_movto,
        f431_fecha_entrega,
        f431_cant_pedida_base,
        f431_precio_unitario
      )
      SELECT
        id                      =   id,
        f431_nro_registro       =   ROW_NUMBER() OVER (ORDER BY (id)),
        f431_id_item            =   CAST('' AS VARCHAR(50)),
        f431_codigo_barras      =   sku,
        f431_id_un_movto        =   CAST(@unidad_negocio AS VARCHAR(10)),
        f431_fecha_entrega      =   @fecha_entrega,
        f431_cant_pedida_base   =   quantity,
        f431_precio_unitario    =   CAST(price AS DECIMAL(18,0))
      FROM @line_items

      /* ========= SHIPPING ========= */
      INSERT INTO @Movto_Pedidos_comercial
      (
        id,
        f431_nro_registro,
        f431_id_item,
        f431_codigo_barras,
        f431_id_un_movto,
        f431_fecha_entrega,
        f431_cant_pedida_base,
        f431_precio_unitario
      )
      SELECT
        id                      =   0,
        f431_nro_registro       =   0,
        f431_id_item            =   @id_item_flete,
        f431_codigo_barras      =   '',
        f431_id_un_movto        =   @unidad_negocio,
        f431_fecha_entrega      =   @fecha_entrega,
        f431_cant_pedida_base   =   1,
        f431_precio_unitario    =   JSON_VALUE(sl.value,'$.price')
      FROM OPENJSON(@json, '$.shipping_lines') AS SL
      WHERE
        CAST(JSON_VALUE(SL.value, '$.price') AS DECIMAL(10,4)) > 0

      INSERT INTO @Descuentos
      (
        f431_nro_registro,
        f432_vlr_uni
      )
      SELECT
        f431_nro_registro   =   MPC.f431_nro_registro,
        f432_vlr_uni        =   CAST(LI.discount_amount AS DECIMAL(10,4))
      FROM @Movto_Pedidos_comercial AS MPC
        INNER JOIN @line_items AS LI
          ON
            LI.id   =   MPC.id
      WHERE
        LI.discount_amount  IS NOT NULL
        AND 
        CAST(LI.discount_amount AS DECIMAL) >   0
        AND
        CAST(LI.discount_amount AS DECIMAL) !=  CAST(LI.price AS DECIMAL);

      /* =========================================================================
       * ESTRUCTURACIÓN DEL JSON FINAL
       * ========================================================================= */
      INSERT INTO @final (idDocumento,indicaParalelismo,descripcion,idOrden,json)
      SELECT
        @idDocumento,
        @indicaParalelismo,
        @descripcion,
        @order,
        (
          SELECT
            [Pedidos] = (
              SELECT *
              FROM @Pedidos
              FOR JSON PATH, INCLUDE_NULL_VALUES -- Mantiene nulos de clientes/fechas
            ),
            [Movto Pedidos comercial] = (
              SELECT *
              FROM @Movto_Pedidos_comercial
              FOR JSON PATH, INCLUDE_NULL_VALUES -- Mantiene nulos de items/barras
            ),
            [Descuentos] = (
              SELECT *
              FROM @Descuentos
              FOR JSON PATH, INCLUDE_NULL_VALUES
            )
          FOR JSON PATH,
          WITHOUT_ARRAY_WRAPPER
        );

      DELETE @Pedidos
      DELETE @Movto_Pedidos_comercial
      DELETE @Descuentos
      DELETE @Line_Items

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
END TRY
BEGIN CATCH
    INSERT INTO @final (idDocumento, indicaParalelismo, descripcion, idOrden, json)
    SELECT
      0,
      0,
      ERROR_MESSAGE(),
      '0',
      NULL;
END CATCH
 
SELECT * from @final AS final_json;