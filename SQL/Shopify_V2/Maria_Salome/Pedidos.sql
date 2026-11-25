
/** MARIA SALOME - CREACIÓN DE PEDIDOS **/

/*
--------------------------------------------------------------------------------
Nombre del Script: Pedido Integracion.sql  
Proyecto: MARIA SALOME  
Propósito:  
    Este script procesa e integra pedidos de Shopify en el sistema ERP Siesa.  
    Recupera pedidos pendientes, valida y transforma los datos, y prepara  
    las estructuras necesarias para la creación de pedidos, incluyendo el  
    manejo de líneas de envío y descuentos.  

Pasos Principales:  
    1. Recuperar información de conexión y pedidos existentes de Siesa.  
    2. Preparar los mapeos de unidad de medida de productos.  
    3. Seleccionar hasta 20 nuevos pedidos de Shopify que aún no se han procesado.  
    4. Para cada pedido:  
        a. Analizar el JSON del pedido y extraer los campos relevantes.  
        b. Determinar la información del cliente y de facturación.  
        c. Insertar los datos del encabezado del pedido en una tabla temporal.  
        d. Insertar las líneas de artículo del pedido, incluidas las líneas de producto y envío.  
        e. Gestionar y aplicar descuentos tanto a nivel de pedido como de línea de artículo.  
        f. Agregar todos los datos procesados en una estructura JSON final.  
    5. Limpiar las tablas y variables temporales.  
    6. Devolver los pedidos procesados finales en formato JSON.  

Manejo de Errores:  
    - Utiliza TRY…CATCH para capturar y reportar errores.  
    - Asegura la limpieza de todas las tablas y variables temporales en caso de error.  

Tablas Temporales Clave:  
    - @final: Almacena el JSON final de salida para cada pedido procesado.  
    - @t430_cm_pv_docto: Lleva el registro de los pedidos ya creados en Siesa.  
    - @unidades_medida_productos: Mapea códigos de barras de productos a unidades de medida.  
    - @Ordenes: Contiene la lista de pedidos de Shopify a procesar.  
    - @pedidos, @movto_pedidos_comercial, @descuentos: Almacenan detalles de pedidos, líneas y descuentos para cada pedido procesado.  

Notas:  
    - Solo procesa pedidos con id_estado = 2 y hasta 3 intentos.  
    - Omite pedidos que ya existen en Siesa.  
    - Gestiona descuentos a nivel de pedido y de línea de artículo.  
    - Añade el envío como una línea de artículo si aplica.  
    - Diseñado para el procesamiento por lotes de hasta 20 pedidos por ejecución.  

--------------------------------------------------------------------------------
*/
SET XACT_ABORT ON;

BEGIN TRY
	DECLARE @final	TABLE	(
		idDocumento			INT
		,indicaParalelismo	BIT
		,descripcion		VARCHAR(100)
		,idOrden			VARCHAR(50)
		,json				VARCHAR(MAX)
	);

	DECLARE @shipping_lines	TABLE	(
		price	DECIMAL(10, 4)
	)
	
	DECLARE @order		VARCHAR(30);
	DECLARE	@json		VARCHAR(MAX)	=	'';
	DECLARE @total		INT;
	DECLARE	@counter	INT				=	1;
	DECLARE	@AuxCoun	INT				=	0;

	/*	Configuración conector	*/
	DECLARE
		@id_conector			INT				=	203309,
		@indica_paralelismo		BIT				=	0,
		@descripcion_conector	VARCHAR(100)	=	'Pedido Integracion';

	DECLARE	@criterio					NVARCHAR(40);

	/*	Tercero	*/
	DECLARE	@id_tercero					NVARCHAR(40);
	DECLARE	@id_tercero_predeterminado	NVARCHAR(40)	=	'99999999';

	/*	Código de barras	*/
	DECLARE	@codigo_barras_flete		NVARCHAR(20)	=	'7700000000000';

	/*	Lista de precios	*/
	DECLARE @id_lista_precios_productos_erp	NVARCHAR(3)	=	'030';
	DECLARE @id_lista_precios_flete_erp		NVARCHAR(3)	=	'999';

	/*	Indicador de precio	*/
	DECLARE @ind_precio_productos_erp	INT	=	1;
	DECLARE @ind_precio_flete_erp		INT	=	2;

	/*	Bodegas	*/
	DECLARE @id_bodega_erp						NVARCHAR(5)		=	'CADI';
	DECLARE @id_bodega_coordinadora_fulfillment	NVARCHAR(5)		=	'BGTAC';

	DECLARE @conexion NVARCHAR(MAX);
	DECLARE @base_datos NVARCHAR(MAX);

	SELECT TOP 1
		@conexion		=	cadena_conexion
		,@base_datos	=	base_datos
	FROM Conexiones;

	DECLARE	@t430_cm_pv_docto	TABLE	(
		f430_num_docto_referencia	VARCHAR(50)
	);

	INSERT INTO @t430_cm_pv_docto
	EXEC sp_ObtenerDoctosPV;

	DECLARE	@unidades_medida_productos	TABLE	(
		v121_id_barras_principal	NVARCHAR(20)
		,v121_id_unidad_inventario	NVARCHAR(10)
		,f150_id					NVARCHAR(10)
	)

	INSERT INTO @unidades_medida_productos
	EXEC ('
		SELECT *
		FROM OPENROWSET(
			''SQLNCLI''
			, ''' + @conexion + '''
			, ''
				SELECT
					v121_id_barras_principal
					,v121_id_unidad_inventario
					,f150_id
				FROM ' + @base_datos + '.dbo.v121
					INNER JOIN ' + @base_datos +'.dbo.t150_mc_bodegas
						ON
							f150_id_cia	=	v121_id_cia
				WHERE
					v121_id_cia	= 	1
					AND
					f150_id	= '''''+ @id_bodega_erp +'''''
			''
		)'
	)

	DECLARE	@precios_por_items	TABLE (
		f121_id_barras_principal	VARCHAR(20),
		f126_precio					MONEY
	)

	INSERT INTO @precios_por_items
	EXEC('
		SELECT DISTINCT
			f121_id_barras_principal,
			f126_precio
		FROM OPENROWSET(
			''SQLNCLI''
			, ''' + @conexion + '''
			, ''
				SELECT
					f121_id_barras_principal	=
						CASE
							WHEN f121_id_barras_principal IS NULL
								THEN f131_id
							ELSE f121_id_barras_principal
						END,
					f126_precio =
						(
							SELECT TOP 1
								f126_precio
							FROM ' + @base_datos + '.dbo.t126_mc_items_precios
							WHERE
								(
									f120_rowid = f126_rowid_item
									OR
									f121_rowid = f126_rowid_item_ext
								)
								AND
								f126_id_lista_precio = ''''' + @id_lista_precios_productos_erp + '''''
							ORDER BY f126_fecha_activacion DESC
						)
				FROM ' + @base_datos + '.dbo.t121_mc_items_extensiones
					INNER JOIN ' + @base_datos + '.dbo.t120_mc_items
						ON 
							f120_rowid = f121_rowid_item
					LEFT JOIN ' + @base_datos + '.dbo.t131_mc_items_barras
						ON
							f131_rowid_item_ext = f121_rowid
				WHERE
					EXISTS (
						SELECT 1
						FROM ' + @base_datos + '.dbo.t126_mc_items_precios
						WHERE
							(
								f120_rowid = f126_rowid_item
								OR
								f121_rowid = f126_rowid_item_ext
							)
							AND
							f126_id_lista_precio = ''''' + @id_lista_precios_productos_erp + '''''
					)
			''
		)
	');

	DECLARE	@pais_erp			VARCHAR(3)
			,@departamento_erp	VARCHAR(2)
			,@ciudad_erp		VARCHAR(3);
	
	DECLARE	@error_ciudad_terceros	VARCHAR(100)	=	', el tercero ingresó una ciudad incorrecta';

	DECLARE @notas	VARCHAR(255);

	DECLARE	@pedidos	TABLE	(
		f430_consec_docto			INT
		,f430_id_fecha				NVARCHAR(8)
		,f430_id_tercero_fact		NVARCHAR(15)
		,f430_id_tercero_rem		NVARCHAR(15)
		,f430_fecha_entrega			NVARCHAR(8)
		,f430_num_docto_referencia	NVARCHAR(15)
		,f430_notas					NVARCHAR(2000)
	);

	DECLARE	@movto_pedidos_comercial	TABLE	(
		f431_consec_docto			INT
		,f431_nro_registro			INT
		,f431_codigo_barras			NVARCHAR(20)
		,f431_id_bodega				NVARCHAR(5)
		,f431_fecha_entrega			NVARCHAR(8)
		,f431_id_lista_precio		NVARCHAR(3)
		,f431_cant_pedida_base		DECIMAL
		,f431_precio_unitario		DECIMAL(10, 4)
		,f431_ind_precio			INT
		,precio_descuento			DECIMAL(10, 4)
	);

	DECLARE @descuentos	TABLE	(
		f430_consec_docto	NVARCHAR(20)
		,f431_nro_registro	INT
		,f432_tasa			DECIMAL(10, 4)
	);

	DECLARE	@Ordenes	TABLE(
		id_orden	VARCHAR(50)
		,orden_obj	VARCHAR(MAX)
	)

	INSERT INTO @Ordenes
	SELECT TOP 25
		id_orden
		,orden_obj
	FROM ordenes 
		LEFT JOIN @t430_cm_pv_docto	ON	f430_num_docto_referencia	=	REPLACE(id_orden, '"', '')
	WHERE  
		id_estado	=	2
		AND 
		intentos	<=	3 
		AND 
		f430_num_docto_referencia IS NULL 

	UPDATE ordenes
	SET	id_estado	=	3
	WHERE 
		id_estado	=	2 
		AND
		intentos	<=	3
		AND
		id_orden	IN	(
			SELECT
				REPLACE(id_orden, '"', '')
			FROM @t430_cm_pv_docto
			WHERE
				f430_num_docto_referencia	=	REPLACE(id_orden, '"', '')
		);

	SET	@total	=	(SELECT COUNT(*) FROM @Ordenes);

	WHILE	@counter	<=	@total
	BEGIN
		BEGIN TRY
			SET @json = (
				SELECT
					orden_obj
				FROM (
					SELECT
						orden_obj
						,ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RN
					FROM @Ordenes
				) AS TEMP
				WHERE
					RN	=	@counter
			);

			SET	@order	=	JSON_VALUE(@json, '$.name');

			SET	@criterio = JSON_VALUE(@json, '$.tags');

            DECLARE @na_documento       NVARCHAR(100)   =   NULL,
                    @na_departamento    NVARCHAR(100)   =   NULL,
                    @na_ciudad          NVARCHAR(100)   =   NULL,
                    @na_zoko_session_id	NVARCHAR(100)   =   NULL;

            SELECT
                @na_documento       =	MAX(CASE WHEN Nombre = 'documento'          THEN Valor END),
                @na_departamento    =	MAX(CASE WHEN Nombre = 'departamento'       THEN Valor END),
                @na_ciudad          =	MAX(CASE WHEN Nombre = 'ciudad'             THEN Valor END),
				@na_zoko_session_id	=	MAX(CASE WHEN Nombre = 'zoko_session_id'	THEN Valor END)
            FROM
            (
                SELECT
                    Nombre = JSON_VALUE(value, '$.name'),
                    Valor  = JSON_VALUE(value, '$.value')
                FROM OPENJSON(@json, '$.note_attributes')
            ) AS NA;

			DECLARE @billing_address_company	NVARCHAR(100)	=   dbo.fn_KeepNumbersHyphen(JSON_VALUE(@json, '$.billing_address.company'));
            
            DECLARE @formatted_billing_address_company	NVARCHAR(100)	=
                REPLACE(
                    @billing_address_company
                    , '-'
                    , ''
                );
            
            DECLARE @customer_default_address_company	NVARCHAR(100)	=   dbo.fn_KeepNumbersHyphen(JSON_VALUE(@json, '$.customer.default_address.company'));

            DECLARE @formatted_customer_default_address_company	NVARCHAR(100)	=
                REPLACE(
                    @customer_default_address_company
                    , '-'
                    , ''
                );

			SET	@id_tercero	= 
				CASE
                    WHEN    @na_documento   IS NOT NULL
                        THEN    @na_documento
					WHEN 
						TRY_CAST(
							@formatted_billing_address_company AS DECIMAL(30,0)
						) IS NOT NULL   
                        AND 
                        @na_documento   IS NULL
						THEN @billing_address_company
					WHEN 
						TRY_CAST(
							@formatted_customer_default_address_company AS DECIMAL(30,0)
						) IS NOT NULL    
                        AND 
                        @na_documento   IS NULL
						THEN @customer_default_address_company
					ELSE @id_tercero_predeterminado
				END;
			
			SET @id_tercero = 
				CASE
					WHEN dbo.fn_KeepNumbersHyphen(@id_tercero) = '' THEN @id_tercero_predeterminado
					ELSE dbo.fn_KeepNumbersHyphen(@id_tercero)
				END;
			
			SELECT
				@pais_erp			=	NULL,
                @departamento_erp	=	NULL,
                @ciudad_erp		    =	NULL;

			DECLARE @current_bodega NVARCHAR(5) = NULL;
			
            IF (@na_departamento    IS NULL AND @na_ciudad  IS NULL)
            BEGIN
                SELECT TOP 1 
                    @pais_erp			=	ISNULL(f013_id_pais		,'169'),
                    @departamento_erp	=	ISNULL(f013_id_depto	,'05'),
                    @ciudad_erp			=	ISNULL(f013_id			,'999'),
                    @current_bodega		=	
                        CASE
                            WHEN UPPER(dbo.fn_RemoveAccentMarks(f013_indicativo))	LIKE	'%COORDINADORA FULL%' 
                                THEN	@id_bodega_coordinadora_fulfillment 
                            ELSE
                                @id_bodega_erp
                        END
                FROM locaciones_erp
                WHERE
                    dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.country')))
                    AND 
                    (
                        -- Caso 1: Bogotá D.C. (ciudad y departamento son Bogotá)
                        (
                            (
                                '%' + dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.province'))) + '%' LIKE '%cundinamarca%' 
                                OR
                                '%' + dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.province'))) + '%' LIKE '%bogota%' 
                            )
                            AND 
                            dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.customer.default_address.city'))) LIKE    '%bogota%'
                            AND
                            dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion))   LIKE    '%bogota%'
                            AND
                            dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion))   LIKE    '%bogota%'
                        )
                        OR 
                        -- Caso 2: Provincia es Bogotá pero ciudad NO es Bogotá
                        (
                            (
                                '%' + dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.province'))) + '%' LIKE '%cundinamarca%' 
                                OR
                                '%' + dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.province'))) + '%' LIKE '%bogota%' 
                            )
                            AND 
                            dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.city'))) NOT LIKE 'bogota'
                            AND
                            dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) LIKE    '%cundinamarca%'
                            AND
                            dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.city')))))
                        )
                        OR 
                        -- Caso 3: Bolívar y Cartagena (caso especial)
                        (
                            dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.province')))  LIKE    '%bolivar%'
                            AND
                            (
                                dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion))   LIKE    '%cartagena%'
                                AND
                                dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.city'))) LIKE '%cartagena%'
                            )
                        )
                        OR
                        -- Caso 4: Caso general (otros departamentos)
                        (
                            dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.province')))
                            AND 
                            (
                                dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.city'))) = dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion))
                                OR 
                                (
                                    NOT EXISTS (
                                        SELECT 1 FROM locaciones_erp l2
                                        WHERE 
                                            dbo.fn_RemoveAccentMarks(LOWER(l2.f011_descripcion))    =   dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.country')))
                                            AND
                                            dbo.fn_RemoveAccentMarks(LOWER(l2.f012_descripcion))    =   dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.province')))
                                            AND
                                            dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.city')))    =   dbo.fn_RemoveAccentMarks(LOWER(l2.f013_descripcion))
                                    )
                                    AND
                                    dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, '$.shipping_address.city')))    LIKE    '%' + dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) + '%'
                                )
                            )
                        )
                    );
            END
            ELSE
            BEGIN
                SELECT TOP 1 
                    @pais_erp			=	ISNULL(f013_id_pais		,'169'),
                    @departamento_erp	=	ISNULL(f013_id_depto	,'05'),
                    @ciudad_erp			=	ISNULL(f013_id			,'999'),
                    @current_bodega		=	
                        CASE
                            WHEN UPPER(dbo.fn_RemoveAccentMarks(f013_indicativo))	LIKE	'%COORDINADORA FULL%' 
                                THEN	@id_bodega_coordinadora_fulfillment 
                            ELSE
                                @id_bodega_erp
                        END
                FROM locaciones_erp
                WHERE
                    f013_id_pais    =   '169'
                    AND
                    f013_id_depto   =   @na_departamento
                    AND
                    f013_id         =   RIGHT(LEFT(@na_ciudad, 5), 3);
            END
		
			SELECT 
				@pais_erp			=	ISNULL(@pais_erp,	'169'),
                @departamento_erp	=	ISNULL(@departamento_erp,	'05'),
                @ciudad_erp		    =	ISNULL(@ciudad_erp,	'999'),
                @current_bodega	    =	ISNULL(@current_bodega, @id_bodega_erp);
			
			SET @notas	=
				(
					CASE
						WHEN	NULLIF(TRIM(@criterio), '') IS NULL AND NULLIF(TRIM(@na_zoko_session_id), '') IS NULL
							THEN	'ECOMMERCE'
						ELSE	'WHATSAPP'
					END
				) + (
					CASE
						WHEN
							@pais_erp	=	'169'	
							AND	
							@departamento_erp	=	'05'	
							AND	
							@ciudad_erp	=	'999'
							THEN	@error_ciudad_terceros
						ELSE	''
					END
				) + (
					CASE
						WHEN
							@current_bodega	=	@id_bodega_coordinadora_fulfillment
							THEN
								' - Coordinadora Full'
						ELSE
							''
					END
				)

			/*	PEDIDO	*/
			INSERT INTO @pedidos
			SELECT 
				f430_consec_docto			=	1,
                f430_id_fecha				=	FORMAT(GETDATE(), 'yyyyMMdd'),
                f430_id_tercero_fact		=	@id_tercero,
                f430_id_tercero_rem		    =	@id_tercero,
                f430_fecha_entrega			=	FORMAT(DATEADD(DAY, 1, GETDATE()), 'yyyyMMdd'),
                f430_num_docto_referencia	=	@order,
                f430_notas					=	@notas

			/*	MOVIMIENTO	*/
			INSERT INTO @movto_pedidos_comercial
			SELECT
				f431_consec_docto		=	'1',
                f431_nro_registro		=	ROW_NUMBER() OVER (ORDER BY (JSON_VALUE(LI.value, '$.id'))),
                f431_codigo_barras		=	v.sku_erp,
                f431_id_bodega			=	@current_bodega,
                f431_fecha_entrega		=	FORMAT(DATEADD(DAY, 1, GETDATE()), 'yyyyMMdd'),
                f431_id_lista_precio	=	@id_lista_precios_productos_erp,
                f431_cant_pedida_base	=	JSON_VALUE(LI.value, '$.quantity'),
                f431_precio_unitario	=	ISNULL(ppi.f126_precio, 0),
                f431_ind_precio			=	@ind_precio_productos_erp,
                precio_descuento		=
					CASE
                        WHEN    ppi.f126_precio IS NULL
                            THEN 0
                        ELSE
                            CASE
                                WHEN EXISTS (SELECT [amount] = JSON_VALUE(da.value, '$.amount') FROM OPENJSON(LI.value, '$.discount_allocations')   AS  da)
                                    THEN
                                        (
                                            (
                                                (
                                                    (ppi.f126_precio - JSON_VALUE(LI.value, '$.price')) * JSON_VALUE(LI.value, '$.quantity')
                                                ) + (
                                                    SELECT
                                                        [amount] = JSON_VALUE(da.value, '$.amount')
                                                    FROM OPENJSON(LI.value, '$.discount_allocations')   AS  da
                                                )
                                            ) * 100
                                        ) / (ppi.f126_precio * JSON_VALUE(LI.value, '$.quantity'))
                                ELSE
                                (
                                    (
                                        (ppi.f126_precio - JSON_VALUE(LI.value, '$.price')) * JSON_VALUE(LI.value, '$.quantity')
                                    ) * 100
                                ) / (ppi.f126_precio * JSON_VALUE(LI.value, '$.quantity'))
                            END
                    END
			FROM OPENJSON(@json, '$.line_items') AS LI
				INNER JOIN variantes	AS	V
					ON
						v.id_variante	=	JSON_VALUE(LI.value, '$.variant_id')
				LEFT JOIN @unidades_medida_productos	AS	UMP
					ON
						v121_id_barras_principal	=	v.sku_erp
				LEFT JOIN @precios_por_items	AS	ppi
					ON
						ppi.f121_id_barras_principal	=	v.sku_erp
			ORDER BY JSON_VALUE(LI.value, '$.id')

			SELECT
				@AuxCoun	=	COUNT(f431_nro_registro)
			FROM @movto_pedidos_comercial

			/*	Valida si tiene envío	*/
			INSERT INTO @shipping_lines
			SELECT
				price	=	JSON_VALUE(SL.value, '$.price')
			FROM OPENJSON(@json,'$.shipping_lines') AS SL
			WHERE
				JSON_VALUE(SL.value, '$.is_removed') = 'false'

			IF EXISTS(
				SELECT 1
				FROM @shipping_lines
			)
			BEGIN
				INSERT INTO @movto_pedidos_comercial
				SELECT
					f431_consec_docto			=	'1',
                    f431_nro_registro			=	@AuxCoun + 1,
                    f431_codigo_barras			=	@codigo_barras_flete,
                    f431_id_bodega				=	@current_bodega,
                    f431_fecha_entrega			=	FORMAT(DATEADD(DAY, 1, GETDATE()), 'yyyyMMdd'),
                    f431_id_lista_precio		=	@id_lista_precios_flete_erp,
                    f431_cant_pedida_base		=	1,
                    f431_precio_unitario		=	price,
                    f431_ind_precio			    =	@ind_precio_flete_erp,
                    precio_descuento			=	0
				FROM @shipping_lines
				WHERE price > 0
			END

			/*	Valida el descuento	*/
			IF EXISTS	(
				SELECT 1
				FROM @movto_pedidos_comercial
				WHERE
					precio_descuento > 0
			)
			BEGIN
				INSERT INTO @descuentos
				SELECT
					f430_consec_docto	=	1,
					f431_nro_registro	=	f431_nro_registro,
					f432_tasa			=	precio_descuento
				FROM @movto_pedidos_comercial
				WHERE
					precio_descuento > 0
			END 

			INSERT INTO	@final	(
				idDocumento,
                indicaParalelismo,
                descripcion,
                idOrden,
                json
			)
			SELECT 
				@id_conector,
                @indica_paralelismo,
                @descripcion_conector,
                idOrden	=	@order,
                (
					SELECT
						[Pedidos]	=	(
							SELECT *
							FROM @pedidos
							FOR JSON PATH
						),
                        [Movto Pedidos comercial]	=	(
							SELECT *
							FROM @movto_pedidos_comercial
							FOR JSON PATH
						),
                        [Descuentos]	=	(
							SELECT *
							FROM @descuentos
							FOR JSON PATH
						)
					FOR JSON PATH
					,WITHOUT_ARRAY_WRAPPER
				);

			/*	Eliminar datos de tablas temporales	*/
			DELETE	@pedidos;
			DELETE	@movto_pedidos_comercial;
			DELETE	@descuentos;
			DELETE	@shipping_lines;
			DELETE	@t430_cm_pv_docto;

			/*	Eliminar datos de tablas temporales	*/
			SET	@criterio	=	NULL;
			SET	@id_tercero	=	NULL;

			SET @counter = @counter + 1;
		END TRY
		BEGIN CATCH
			/*	Eliminar datos de tablas temporales	*/
			DELETE	@pedidos;
			DELETE	@movto_pedidos_comercial;
			DELETE	@descuentos;
			DELETE	@shipping_lines;
			DELETE	@t430_cm_pv_docto;

			/*	Eliminar datos de tablas temporales	*/
			SET	@criterio	=	NULL;
			SET	@id_tercero	=	NULL;

			SET @counter = @counter + 1;
		END CATCH
	END
END TRY
BEGIN CATCH
	SELECT
		indicaError			=	CAST(1 AS BIT),
        descripcionError	=	CONCAT('Error: ', ERROR_MESSAGE())
	GOTO Cleanup;
END CATCH
Cleanup:
BEGIN
	DELETE	@pedidos;
	DELETE	@movto_pedidos_comercial;
	DELETE	@descuentos
	DELETE	@shipping_lines;
	DELETE	@t430_cm_pv_docto;
	DELETE	@Ordenes;
	DELETE	@unidades_medida_productos;
END

SELECT *
FROM @final	AS	final_json;