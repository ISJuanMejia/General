DECLARE @endpoint_guias	NVARCHAR(255) = 'https://guias.coordinadora.com/ws/guias/1.6/server.php',
		@Conexion		NVARCHAR(2000) = (SELECT conexion FROM conexiones WHERE id = 1),
		@ConsFactura	NVARCHAR(255),
		@COFactura		NVARCHAR(255),
		@TipoFactura	NVARCHAR(255);

SELECT @endpoint_guias, @Conexion, @ConsFactura, @COFactura, @TipoFactura

/*

IF OBJECT_ID('tempdb..#ListadoFacturas') IS NOT NULL DROP TABLE #ListadoFacturas
IF OBJECT_ID('tempdb..#tmp_PedidosProcesar') IS NOT NULL DROP TABLE #tmp_PedidosProcesar
IF OBJECT_ID('tempdb..#InfoTerceroCliente') IS NOT NULL DROP TABLE #InfoTerceroCliente
IF OBJECT_ID('tempdb..#EntidadesTipoTexto') IS NOT NULL DROP TABLE #EntidadesTipoTexto
IF OBJECT_ID('tempdb..#EntidadesMaestroDetalle') IS NOT NULL DROP TABLE #EntidadesMaestroDetalle
IF OBJECT_ID('tempdb..#FacturaYPedido') IS NOT NULL DROP TABLE #FacturaYPedido

CREATE TABLE #InfoTerceroCliente
(
	f350_consec_docto   NVARCHAR(255),
	nombre_destinatario NVARCHAR(255),
	f015_direccion1     NVARCHAR(255),
	f015_direccion2     NVARCHAR(255),
	f015_direccion3     NVARCHAR(255),
	f015_id_pais        NVARCHAR(255),
	f015_id_depto       NVARCHAR(255),
	f015_id_ciudad      NVARCHAR(255),
	f015_celular        NVARCHAR(255)
);

CREATE TABLE #EntidadesTipoTexto
(
	f350_consec_docto   NVARCHAR(255),
	f743_etiqueta       NVARCHAR(255),
	valor               NVARCHAR(255),
	NumUnidades         NVARCHAR(255),
	TipoEnvio           NVARCHAR(255),
	TipoGuia            NVARCHAR(255)
);

CREATE TABLE #EntidadesMaestroDetalle
(
	f350_consec_docto   NVARCHAR(255),
	f743_etiqueta       NVARCHAR(255),
	valor               NVARCHAR(255)
);

CREATE TABLE #FacturaYPedido
(
	f350_consec_docto	NVARCHAR(255),
	f430_consec_docto	NVARCHAR(255),
	referencia       	NVARCHAR(255),
	observaciones    	NVARCHAR(255),
	ValorFactura     	DECIMAL(18,2)
)

--Validamos las facturas a que se deben generar guia
SELECT * 
INTO #ListadoFacturas
FROM OPENROWSET(
    'SQLNCLI',
    'server=siesa-m4-sqlsw-db10new.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Logintegral_Real;uid=Logintegral;pwd=Logintegral$12$%;',
    '
		SELECT
			f350_consec_docto,
			f350_id_tipo_docto,
			f350_id_co,
			f743_etiqueta,
			f753_dato_texto,
			f350_id_cia
		FROM  t350_co_docto_contable
			INNER JOIN t750_mm_movto_entidad
				ON 
					f350_rowid_movto_entidad	=	f750_rowid
			INNER JOIN t753_mm_movto_entidad_columna
				ON
					f750_rowid	=	f753_rowid_movto_entidad
			INNER JOIN t743_mm_entidad_atributo
				ON
					f753_rowid_entidad_atributo	=	f743_rowid
		WHERE
			f350_id_tipo_docto	=	''CFE'' 
			AND 
			f743_etiqueta	=	''GUIA''
			AND 
			f753_dato_texto	=	''Si'' 
			AND 
			f350_id_cia	=	1
		ORDER BY f350_consec_docto
	'
) AS remoto
WHERE 
	NOT EXISTS (
		SELECT 1 
		FROM documentos d 
		WHERE
			d.documento_referencia = remoto.f350_consec_docto
	);

SELECT
	ROW_NUMBER() OVER (ORDER by f350_consec_docto ASC) AS Orden, 
	* 
INTO #tmp_PedidosProcesar
FROM #ListadoFacturas

--Recorrer los registros a insertar para que sean procesados
DECLARE	@cantidadRegistros	INT	=	(SELECT COUNT(*) FROM #tmp_PedidosProcesar),
		@i					INT;
SET	@i	=	1;

WHILE @i <= @cantidadRegistros
BEGIN 
	SELECT
		@ConsFactura	=	f350_consec_docto, 
		@COFactura		=	f350_id_co, 
		@TipoFactura	=	f350_id_tipo_docto
	FROM #tmp_PedidosProcesar
	WHERE 
		Orden = @i;

	DECLARE	@sql_InfoTerceroCliente AS VARCHAR(MAX);
	SET	@sql_InfoTerceroCliente = 
	'
		SELECT
		*
		FROM	OPENROWSET(
			''SQLNCLI'', 
			'''+@Conexion+''',
			''
				SELECT DISTINCT
					t350.f350_consec_docto,
					CASE 
						WHEN	f200_ind_tipo_tercero	=	''''1'''' 
							THEN
								CONCAT(f200_nombres, '''' '''', f200_apellido1, '''' '''', f200_apellido2)
						WHEN	f200_ind_tipo_tercero	=	''''2'''' 
							THEN	f200_razon_social 
					END AS nombre_destinatario,
					f015_direccion1,
					f015_direccion2,
					f015_direccion3,
					f015_id_pais,
					f015_id_depto,
					f015_id_ciudad,
					f015_celular
				FROM t350_co_docto_contable AS t350
					INNER JOIN t461_cm_docto_factura_venta   
						ON 
							t350.f350_rowid	=	f461_rowid_docto
					INNER JOIN t215_mm_puntos_envio_cliente  
						ON
							f461_rowid_punto_envio_rem	=	f215_rowid
					INNER JOIN t015_mm_contactos
						ON
							f215_rowid_contacto	=	f015_rowid      
					INNER JOIN t200_mm_terceros
						ON
							t350.f350_rowid_tercero	=	f200_rowid
				WHERE
					t350.f350_consec_docto	=	'''''+ @ConsFactura +'''''
					AND 
					t350.f350_id_co	=	'''''+ @COFactura +'''''
					AND 
					t350.f350_id_tipo_docto	=	'''''+ @TipoFactura +'''''
					AND 
					f350_id_cia	=	1
			''
		);
	';
	
	INSERT INTO #InfoTerceroCliente
	EXEC(@sql_InfoTerceroCliente)
	
	DECLARE @sql_EntidadesTipoTexto AS VARCHAR(MAX);
	SET @sql_EntidadesTipoTexto = 
	'
		SELECT
		*
		FROM	OPENROWSET(
			''SQLNCLI'', 
			'''+@Conexion+''',
			''
				SELECT
					t350.f350_consec_docto,
					t743.f743_etiqueta,
					t753.f753_dato_texto AS valor,
					PARSENAME(REPLACE(t753.f753_dato_texto, '''','''', ''''.''''), 3) AS NumUnidades,
					CASE
						WHEN PARSENAME(REPLACE(t753.f753_dato_texto, '''','''', ''''.''''), 2) = 0 
							THEN ''''Mercancia''''
						WHEN PARSENAME(REPLACE(t753.f753_dato_texto, '''','''', ''''.''''), 2) = 1 
							THEN ''''Paquete''''
						WHEN PARSENAME(REPLACE(t753.f753_dato_texto, '''','''', ''''.''''), 2) = 2 
							THEN ''''FletePago''''
					END AS TipoEnvio,
					CASE 
						WHEN PARSENAME(REPLACE(t753.f753_dato_texto, '''','''', ''''.''''), 1) = 6 
							THEN ''''Estandar'''' 
					END  AS TipoGuia
				FROM  t350_co_docto_contable	AS	t350
					INNER JOIN	t750_mm_movto_entidad	AS	t750
						ON
							t350.f350_rowid_movto_entidad	=	t750.f750_rowid
					INNER JOIN	t753_mm_movto_entidad_columna	AS	t753
						ON
							t750.f750_rowid	=	t753.f753_rowid_movto_entidad
			INNER JOIN t743_mm_entidad_atributo	       AS t743	                 ON t753.f753_rowid_entidad_atributo  = t743.f743_rowid
			WHERE t350.f350_consec_docto           = '''''+ @ConsFactura +'''''
			  AND t350.f350_id_co                  = '''''+ @COFactura +'''''
			  AND t350.f350_id_tipo_docto          = '''''+ @TipoFactura +'''''
			  AND t743.f743_etiqueta IN (''''# DE CAJAS'''') 
			  AND f350_id_cia = 1
			''
		);
		'
	  INSERT INTO #EntidadesTipoTexto
	  EXEC(@sql_EntidadesTipoTexto)
	  --SELECT * FROM #EntidadesTipoTexto

	  DECLARE @sql_EntidadesMaestroDetalle AS VARCHAR(MAX);
	  SET @sql_EntidadesMaestroDetalle = 
		'
			SELECT
			*
			FROM 
			OPENROWSET(
			''SQLNCLI'', 
			'''+@Conexion+''',
			''
			SELECT 
			 t350.f350_consec_docto
			,t743.f743_etiqueta
			,f741_descripcion     AS Valor
			FROM t350_co_docto_contable                 AS t350
			INNER JOIN t750_mm_movto_entidad            AS t750                ON  t350.f350_rowid_movto_entidad      = t750.f750_rowid

			INNER JOIN t753_mm_movto_entidad_columna    AS t753	             ON  t753.f753_rowid_movto_entidad      = t750.f750_rowid
																												 AND t753.f753_id_cia                   = t750.f750_id_cia	
			INNER JOIN t743_mm_entidad_atributo         AS t743                ON  t753.f753_rowid_entidad_atributo   = t743.f743_rowid
																												 AND t753.f753_id_cia	                = t743.f743_id_cia	
			INNER JOIN t742_mm_entidad                  AS t742                ON  t743.f743_rowid_entidad            = t742.f742_rowid
																												 AND t743.f743_id_cia                   = t742.f742_id_cia
			INNER JOIN t740_mm_maestro                  AS t740                ON  t743.f743_rowid_maestro            = t740.f740_rowid
																												 AND t743.f743_id_cia                   = t740.f740_id_cia 
			INNER JOIN t741_mm_maestro_detalle          AS t741                ON  f740_rowid                         = t741.f741_rowid_maestro
																												 AND t741.f741_rowid                    = t753.f753_rowid_maestro_detalle
																												 AND t740.f740_id_cia                   = t741.f741_id_cia
			WHERE t350.f350_consec_docto           = '''''+ @ConsFactura +'''''
			  AND t350.f350_id_co                  = '''''+ @COFactura +'''''
			  AND t350.f350_id_tipo_docto          = '''''+ @TipoFactura +'''''
			  AND f350_id_cia = 1
			''
		);
		'
	  INSERT INTO #EntidadesMaestroDetalle
	  EXEC(@sql_EntidadesMaestroDetalle)
	  --SELECT * FROM #EntidadesMaestroDetalle

	  DECLARE @sql_FacturaYPedido AS VARCHAR(MAX);
	  SET @sql_FacturaYPedido = 
	  '
			SELECT
			*
			FROM 
			OPENROWSET(
			''SQLNCLI'', 
			'''+@Conexion+''',
			''
			SELECT DISTINCT
			t350.f350_consec_docto
			,t430.f430_consec_docto
			,CONCAT(t430.f430_id_tipo_docto,''''-'''',''''000'''',t430.f430_consec_docto)                                                                         AS referencia
			,CONCAT(t350.f350_id_tipo_docto,''''-'''',''''000'''',t350.f350_consec_docto,'''' Doc. '''',t430.f430_id_tipo_docto,''''-'''',''''000'''',t430.f430_consec_docto) AS observaciones
			,SUM(f431_vlr_neto)                                                                                                                           AS ValorFactura
			FROM t430_cm_pv_docto AS t430
			INNER JOIN t431_cm_pv_movto AS t431        ON t430.f430_rowid               = t431.f431_rowid_pv_docto
			INNER JOIN t470_cm_movto_invent AS t470    ON t431.f431_rowid               = t470.f470_rowid_pv_movto
			INNER JOIN t350_co_docto_contable AS t350  ON t470.f470_rowid_docto_fact    = t350.f350_rowid
			WHERE t350.f350_consec_docto           = '''''+ @ConsFactura +'''''
			  AND t350.f350_id_co                  = '''''+ @COFactura +'''''
			  AND t350.f350_id_tipo_docto          = '''''+ @TipoFactura +'''''
			  AND f350_id_cia = 1
			GROUP BY t350.f350_consec_docto,t430.f430_consec_docto,t430.f430_id_tipo_docto, t350.f350_id_tipo_docto
			''
		);
		'

	  INSERT INTO #FacturaYPedido
	  EXEC(@sql_FacturaYPedido)
	  --SELECT * FROM #FacturaYPedido


      DECLARE @RecaudoGuia     NVARCHAR(MAX) = '';
	  DECLARE @TipoEnvio       NVARCHAR(MAX) = (SELECT TipoEnvio FROM #EntidadesTipoTexto WHERE f350_consec_docto = @ConsFactura); 
	  DECLARE @valorFactura    DECIMAL(18,2) = (SELECT ValorFactura FROM #FacturaYPedido WHERE f350_consec_docto = @ConsFactura);

	  IF @TipoEnvio = 'FletePago' AND @valorFactura > 1000000
	     BEGIN
	          PRINT('MERCANCIA')
	     END
	  ELSE
	     BEGIN
	          --Armar el XML
		 SELECT CONCAT('<soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
							xmlns:xsd="http://www.w3.org/2001/XMLSchema"
							xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
							xmlns:ser="https://guias.coordinadora.com/ws/guias/1.6/server.php"
							xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
							<soapenv:Header/>
							<soapenv:Body>
								<ser:Guias_generarGuia soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
								<p xsi:type="ser:Agw_typeGenerarGuiaIn">
									<codigo_remision xsi:type="xsd:string"/>
									<fecha xsi:type="xsd:string"/>
									<id_cliente xsi:type="xsd:int">',CASE @TipoEnvio WHEN 'FletePago' THEN '46620' ELSE '46531' END,'</id_cliente>
									<id_remitente xsi:type="xsd:int">0</id_remitente>
									<nombre_remitente xsi:type="xsd:string">Ruby Rose</nombre_remitente>
									<direccion_remitente xsi:type="xsd:string">CRA 48B N° 99 SUR 59 BODEGAS 20-21 UNIDAD DE BODEGAS SAN BARTOLOME SECTOR LA TABLAZA</direccion_remitente>
									<telefono_remitente xsi:type="xsd:string">3113790999</telefono_remitente>
									<ciudad_remitente xsi:type="xsd:string">05380000</ciudad_remitente>
									<nit_destinatario xsi:type="xsd:string"></nit_destinatario>
									<div_destinatario xsi:type="xsd:string">',CASE @TipoEnvio WHEN 'FletePago' THEN '00' ELSE '01' END,'</div_destinatario>
									<nombre_destinatario xsi:type="xsd:string">',nombre_destinatario,'</nombre_destinatario>
									<direccion_destinatario xsi:type="xsd:string">',CONCAT(f015_direccion1, ' ', f015_direccion2, ' ', f015_direccion3),'</direccion_destinatario>
									<ciudad_destinatario xsi:type="xsd:string">',CONCAT(f015_id_depto,f015_id_ciudad,'000'),'</ciudad_destinatario>
									<telefono_destinatario xsi:type="xsd:string">',f015_celular,'</telefono_destinatario>
									<valor_declarado xsi:type="xsd:float">50000</valor_declarado>
									<codigo_cuenta xsi:type="xsd:int">',CASE @TipoEnvio WHEN 'FletePago' THEN '6' ELSE '2' END,'</codigo_cuenta>
									<codigo_producto xsi:type="xsd:int">0</codigo_producto>
									<nivel_servicio xsi:type="xsd:int">1</nivel_servicio>
									<linea xsi:type="xsd:string"/>
									<contenido xsi:type="xsd:string">Cosmeticos (delicado)</contenido>
									<referencia xsi:type="xsd:string">',CASE WHEN ValorFactura = '0.00' THEN REPLACE(referencia,'CPV','CPPV') ELSE referencia END,'</referencia>
									<observaciones xsi:type="xsd:string">',CASE WHEN ValorFactura = '0.00' THEN REPLACE(observaciones,'CPV','CPPV') ELSE observaciones END,'</observaciones>
									<estado xsi:type="xsd:string">IMPRESO</estado>
									<detalle SOAP-ENC:arrayType="ns1:Agw_typeGuiaDetalle[1]" xsi:type="ns1:ArrayOfAgw_typeGuiaDetalle">
										<item xsi:type="ns1:Agw_typeGuiaDetalle">
											<ubl xsi:type="xsd:int">0</ubl>
											<alto xsi:type="xsd:float">',CASE @TipoEnvio WHEN 'Paquete' THEN '1' WHEN 'Mercancia' THEN '30' ELSE '15' END,'</alto>
											<ancho xsi:type="xsd:float">',CASE @TipoEnvio WHEN 'Paquete' THEN '50' WHEN 'Mercancia' THEN '50' ELSE '9' END,'</ancho>
											<largo xsi:type="xsd:float">',CASE @TipoEnvio WHEN 'Paquete' THEN '50' WHEN 'Mercancia' THEN '50' ELSE '5' END,'</largo>
											<peso xsi:type="xsd:float">',CASE @TipoEnvio WHEN 'Paquete' THEN '1' WHEN 'Mercancia' THEN '7' ELSE '1' END,'</peso>
											<unidades xsi:type="xsd:int">',NumUnidades,'</unidades>
											<referencia xsi:type="xsd:string"/>
											<nombre_empaque xsi:type="xsd:string"></nombre_empaque>
										</item>
									</detalle>
									<cuenta_contable xsi:type="xsd:string"/>
									<centro_costos xsi:type="xsd:string"/>
									<recaudos xsi:type="ser:ArrayOfAgw_typeGuiaDetalleRecaudo" soapenc:arrayType="ser:Agw_typeGuiaDetalleRecaudo[0]"/>
									<margen_izquierdo xsi:type="xsd:float"/>
									<margen_superior xsi:type="xsd:float"/>
									<id_rotulo xsi:type="xsd:int"/>
									<usuario_vmi xsi:type="xsd:string"/>
									<formato_impresion xsi:type="xsd:string"/>
									<atributo1_nombre xsi:type="xsd:string"/>
									<atributo1_valor xsi:type="xsd:string"/>
									<notificaciones xsi:type="ns1:ArrayOfAgw_typeNotificaciones"/>
									<atributos_retorno xsi:type="ns1:Agw_typeAtributosRetorno"/>
									<nro_doc_radicados xsi:type="xsd:string"/>
									<nro_sobre xsi:type="xsd:string"/>
									<usuario xsi:type="xsd:string">transvision.ws</usuario>
				                    <clave xsi:type="xsd:string">b914367c9899bdd191eeb9571293b0dd39777a21759d18dc6b0a12fe73c35cfb</clave>
								</p>
							</ser:Guias_generarGuia>
						</soapenv:Body>
					</soapenv:Envelope>') AS xmlGuia
		  INTO #tmp_XML
		  FROM #InfoTerceroCliente I
			   INNER JOIN #EntidadesTipoTexto T ON I.f350_consec_docto = T.f350_consec_docto
			   --INNER JOIN #EntidadesMaestroDetalle M ON T.f350_consec_docto = M.f350_consec_docto
			   INNER JOIN #FacturaYPedido F ON T.f350_consec_docto = F.f350_consec_docto


		 --select * from #tmp_XML
		 --Insertamos para que el registro se pueda procesar
		 INSERT INTO documentos (id_cia_connekta,id_transportadora,documento_referencia,connikey,endpoint,obj_transportadora)
			  SELECT 8227,
					 1,
					 @ConsFactura,
					 'cf01638bdc8f6187830cae1728055fb2',
					 'https://guias.coordinadora.com/ws/guias/1.6/server.php',
					 xmlGuia
				FROM #tmp_XML;
	  END

      DELETE FROM #InfoTerceroCliente;
	  DELETE FROM #EntidadesTipoTexto;
	  DELETE FROM #EntidadesMaestroDetalle;
	  DELETE FROM #FacturaYPedido;
	  DROP TABLE #tmp_XML;

	  SET @i += 1;
END

DROP TABLE #ListadoFacturas, #tmp_PedidosProcesar

*/

/*
DECLARE @endpoint_guias             NVARCHAR(500) = 'https://guias.coordinadora.com/ws/guias/1.6/server.php';
DECLARE @Conexion                   NVARCHAR(2000) = (SELECT conexion FROM conexiones WHERE id = 1);
DECLARE @ConsFactura				NVARCHAR(50);
DECLARE @COFactura				    NVARCHAR(50);
DECLARE @TipoFactura				NVARCHAR(50);


IF OBJECT_ID('tempdb..#ListadoFacturas') IS NOT NULL DROP TABLE #ListadoFacturas
IF OBJECT_ID('tempdb..#tmp_PedidosProcesar') IS NOT NULL DROP TABLE #tmp_PedidosProcesar
IF OBJECT_ID('tempdb..#InfoTerceroCliente') IS NOT NULL DROP TABLE #InfoTerceroCliente
IF OBJECT_ID('tempdb..#EntidadesTipoTexto') IS NOT NULL DROP TABLE #EntidadesTipoTexto
IF OBJECT_ID('tempdb..#EntidadesMaestroDetalle') IS NOT NULL DROP TABLE #EntidadesMaestroDetalle
IF OBJECT_ID('tempdb..#FacturaYPedido') IS NOT NULL DROP TABLE #FacturaYPedido


CREATE TABLE #InfoTerceroCliente
(
	 f350_consec_docto   NVARCHAR(MAX)
	,nombre_destinatario NVARCHAR(MAX)
	,f015_direccion1     NVARCHAR(40)
	,f015_direccion2     NVARCHAR(40)
	,f015_direccion3     NVARCHAR(40)
	,f015_id_pais        NVARCHAR(3)
	,f015_id_depto       NVARCHAR(3)
	,f015_id_ciudad      NVARCHAR(3)
	,f015_celular        NVARCHAR(100)
)

CREATE TABLE #EntidadesTipoTexto
(
	 f350_consec_docto   NVARCHAR(MAX)
	,f743_etiqueta       NVARCHAR(100)
	,valor               NVARCHAR(100)
	,NumUnidades         NVARCHAR(2)
	,TipoEnvio           NVARCHAR(20)
	,TipoGuia            NVARCHAR(20)
)

CREATE TABLE #EntidadesMaestroDetalle
(
	 f350_consec_docto   NVARCHAR(MAX)
	,f743_etiqueta       NVARCHAR(100)
	,valor               NVARCHAR(100)
)

CREATE TABLE #FacturaYPedido
(
	 f350_consec_docto       NVARCHAR(MAX)
	,f430_consec_docto       NVARCHAR(100)
	,referencia              NVARCHAR(100)
	,observaciones           NVARCHAR(MAX)
	,ValorFactura            DECIMAL(18,2)
)

--Validamos las facturas a que se deben generar guia
SELECT * INTO #ListadoFacturas
FROM OPENROWSET(
    'SQLNCLI',
    'server=siesa-m4-sqlsw-db10new.ceqnrhbwqaoo.us-east-1.rds.amazonaws.com;Database=UnoEE_Logintegral_Real;uid=Logintegral;pwd=Logintegral$12$%;',
    'SELECT  f350_consec_docto
			,f350_id_tipo_docto
			,f350_id_co
			,f743_etiqueta
			,f753_dato_texto
			,f350_id_cia
      FROM  t350_co_docto_contable
			INNER JOIN t750_mm_movto_entidad                       ON f350_rowid_movto_entidad     = f750_rowid
			INNER JOIN t753_mm_movto_entidad_columna	           ON f750_rowid                   = f753_rowid_movto_entidad
			INNER JOIN t743_mm_entidad_atributo		               ON f753_rowid_entidad_atributo  = f743_rowid
     WHERE f350_id_tipo_docto = ''CFE'' 
	   AND f743_etiqueta = ''GUIA'' 
	   AND f753_dato_texto = ''Si'' 
	   AND f350_id_cia = 1
	   --AND f350_consec_docto in (''17548'',''17544'',''17542'')
	 ORDER BY f350_consec_docto'
) AS remoto
WHERE NOT EXISTS (SELECT 1 FROM documentos d WHERE d.documento_referencia = remoto.f350_consec_docto);
--SELECT * FROM #ListadoFacturas

SELECT ROW_NUMBER() OVER (ORDER by f350_consec_docto ASC) AS Orden, * 
  INTO #tmp_PedidosProcesar
  FROM #ListadoFacturas


--Recorrer los registros a insertar para que sean procesados
DECLARE @cantidadRegistros INT = (SELECT COUNT(*) FROM #tmp_PedidosProcesar)
DECLARE @i INT SET @i = 1;

WHILE @i <= @cantidadRegistros
BEGIN 


	  SELECT @ConsFactura = f350_consec_docto, @COFactura = f350_id_co, @TipoFactura = f350_id_tipo_docto
	    FROM #tmp_PedidosProcesar
	   WHERE Orden = @i;
	 

	  DECLARE @sql_InfoTerceroCliente AS VARCHAR(MAX);
	  SET @sql_InfoTerceroCliente = 
		'
			SELECT
			*
			FROM 
			OPENROWSET(
			''SQLNCLI'', 
			'''+@Conexion+''',
			''
			SELECT DISTINCT
			 t350.f350_consec_docto
			,CASE 
				 WHEN f200_ind_tipo_tercero = ''''1'''' 
					 THEN CONCAT(f200_nombres, '''' '''', f200_apellido1, '''' '''', f200_apellido2)
				 WHEN f200_ind_tipo_tercero = ''''2'''' 
					 THEN f200_razon_social 
			 END AS nombre_destinatario
			,f015_direccion1
			,f015_direccion2
			,f015_direccion3
			,f015_id_pais
			,f015_id_depto
			,f015_id_ciudad
			,f015_celular
			FROM t350_co_docto_contable AS t350
			    INNER JOIN t461_cm_docto_factura_venta   ON t350.f350_rowid              = f461_rowid_docto
				INNER JOIN t215_mm_puntos_envio_cliente  ON f461_rowid_punto_envio_rem   = f215_rowid
				INNER JOIN t015_mm_contactos             ON f215_rowid_contacto          = f015_rowid      
			    INNER JOIN t200_mm_terceros              ON t350.f350_rowid_tercero      = f200_rowid
			WHERE t350.f350_consec_docto           = '''''+ @ConsFactura +'''''
			  AND t350.f350_id_co                  = '''''+ @COFactura +'''''
			  AND t350.f350_id_tipo_docto          = '''''+ @TipoFactura +'''''
			  AND f350_id_cia = 1
			''
		);
		'
	  INSERT INTO #InfoTerceroCliente
	  EXEC(@sql_InfoTerceroCliente)
	  --SELECT * FROM #InfoTerceroCliente


	  DECLARE @sql_EntidadesTipoTexto AS VARCHAR(MAX);
	  SET @sql_EntidadesTipoTexto = 
		'
			SELECT
			*
			FROM 
			OPENROWSET(
			''SQLNCLI'', 
			'''+@Conexion+''',
			''
			SELECT
			 t350.f350_consec_docto
			,t743.f743_etiqueta
			,t753.f753_dato_texto AS valor
			,PARSENAME(REPLACE(t753.f753_dato_texto, '''','''', ''''.''''), 3) AS NumUnidades
			,CASE 
			WHEN PARSENAME(REPLACE(t753.f753_dato_texto, '''','''', ''''.''''), 2) = 0 THEN ''''Mercancia''''
			WHEN PARSENAME(REPLACE(t753.f753_dato_texto, '''','''', ''''.''''), 2) = 1 THEN ''''Paquete''''
			WHEN PARSENAME(REPLACE(t753.f753_dato_texto, '''','''', ''''.''''), 2) = 2 THEN ''''FletePago''''
			END                                                                                       AS TipoEnvio
			,CASE WHEN PARSENAME(REPLACE(t753.f753_dato_texto, '''','''', ''''.''''), 1) = 6 THEN ''''Estandar'''' END  AS TipoGuia
			FROM  t350_co_docto_contable               AS t350
			INNER JOIN t750_mm_movto_entidad           AS t750                     ON t350.f350_rowid_movto_entidad     = t750.f750_rowid
			INNER JOIN t753_mm_movto_entidad_columna   AS t753	                 ON t750.f750_rowid                   = t753.f753_rowid_movto_entidad
			INNER JOIN t743_mm_entidad_atributo	       AS t743	                 ON t753.f753_rowid_entidad_atributo  = t743.f743_rowid
			WHERE t350.f350_consec_docto           = '''''+ @ConsFactura +'''''
			  AND t350.f350_id_co                  = '''''+ @COFactura +'''''
			  AND t350.f350_id_tipo_docto          = '''''+ @TipoFactura +'''''
			  AND t743.f743_etiqueta IN (''''# DE CAJAS'''') 
			  AND f350_id_cia = 1
			''
		);
		'
	  INSERT INTO #EntidadesTipoTexto
	  EXEC(@sql_EntidadesTipoTexto)
	  --SELECT * FROM #EntidadesTipoTexto

	  DECLARE @sql_EntidadesMaestroDetalle AS VARCHAR(MAX);
	  SET @sql_EntidadesMaestroDetalle = 
		'
			SELECT
			*
			FROM 
			OPENROWSET(
			''SQLNCLI'', 
			'''+@Conexion+''',
			''
			SELECT 
			 t350.f350_consec_docto
			,t743.f743_etiqueta
			,f741_descripcion     AS Valor
			FROM t350_co_docto_contable                 AS t350
			INNER JOIN t750_mm_movto_entidad            AS t750                ON  t350.f350_rowid_movto_entidad      = t750.f750_rowid

			INNER JOIN t753_mm_movto_entidad_columna    AS t753	             ON  t753.f753_rowid_movto_entidad      = t750.f750_rowid
																												 AND t753.f753_id_cia                   = t750.f750_id_cia	
			INNER JOIN t743_mm_entidad_atributo         AS t743                ON  t753.f753_rowid_entidad_atributo   = t743.f743_rowid
																												 AND t753.f753_id_cia	                = t743.f743_id_cia	
			INNER JOIN t742_mm_entidad                  AS t742                ON  t743.f743_rowid_entidad            = t742.f742_rowid
																												 AND t743.f743_id_cia                   = t742.f742_id_cia
			INNER JOIN t740_mm_maestro                  AS t740                ON  t743.f743_rowid_maestro            = t740.f740_rowid
																												 AND t743.f743_id_cia                   = t740.f740_id_cia 
			INNER JOIN t741_mm_maestro_detalle          AS t741                ON  f740_rowid                         = t741.f741_rowid_maestro
																												 AND t741.f741_rowid                    = t753.f753_rowid_maestro_detalle
																												 AND t740.f740_id_cia                   = t741.f741_id_cia
			WHERE t350.f350_consec_docto           = '''''+ @ConsFactura +'''''
			  AND t350.f350_id_co                  = '''''+ @COFactura +'''''
			  AND t350.f350_id_tipo_docto          = '''''+ @TipoFactura +'''''
			  AND f350_id_cia = 1
			''
		);
		'
	  INSERT INTO #EntidadesMaestroDetalle
	  EXEC(@sql_EntidadesMaestroDetalle)
	  --SELECT * FROM #EntidadesMaestroDetalle

	  DECLARE @sql_FacturaYPedido AS VARCHAR(MAX);
	  SET @sql_FacturaYPedido = 
	  '
			SELECT
			*
			FROM 
			OPENROWSET(
			''SQLNCLI'', 
			'''+@Conexion+''',
			''
			SELECT DISTINCT
			t350.f350_consec_docto
			,t430.f430_consec_docto
			,CONCAT(t430.f430_id_tipo_docto,''''-'''',''''000'''',t430.f430_consec_docto)                                                                         AS referencia
			,CONCAT(t350.f350_id_tipo_docto,''''-'''',''''000'''',t350.f350_consec_docto,'''' Doc. '''',t430.f430_id_tipo_docto,''''-'''',''''000'''',t430.f430_consec_docto) AS observaciones
			,SUM(f431_vlr_neto)                                                                                                                           AS ValorFactura
			FROM t430_cm_pv_docto AS t430
			INNER JOIN t431_cm_pv_movto AS t431        ON t430.f430_rowid               = t431.f431_rowid_pv_docto
			INNER JOIN t470_cm_movto_invent AS t470    ON t431.f431_rowid               = t470.f470_rowid_pv_movto
			INNER JOIN t350_co_docto_contable AS t350  ON t470.f470_rowid_docto_fact    = t350.f350_rowid
			WHERE t350.f350_consec_docto           = '''''+ @ConsFactura +'''''
			  AND t350.f350_id_co                  = '''''+ @COFactura +'''''
			  AND t350.f350_id_tipo_docto          = '''''+ @TipoFactura +'''''
			  AND f350_id_cia = 1
			GROUP BY t350.f350_consec_docto,t430.f430_consec_docto,t430.f430_id_tipo_docto, t350.f350_id_tipo_docto
			''
		);
		'

	  INSERT INTO #FacturaYPedido
	  EXEC(@sql_FacturaYPedido)
	  --SELECT * FROM #FacturaYPedido


      DECLARE @RecaudoGuia     NVARCHAR(MAX) = '';
	  DECLARE @TipoEnvio       NVARCHAR(MAX) = (SELECT TipoEnvio FROM #EntidadesTipoTexto WHERE f350_consec_docto = @ConsFactura); 
	  DECLARE @valorFactura    DECIMAL(18,2) = (SELECT ValorFactura FROM #FacturaYPedido WHERE f350_consec_docto = @ConsFactura);

	  IF @TipoEnvio = 'FletePago' AND @valorFactura > 1000000
	     BEGIN
	          PRINT('MERCANCIA')
	     END
	  ELSE
	     BEGIN
	          --Armar el XML
		 SELECT CONCAT('<soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
							xmlns:xsd="http://www.w3.org/2001/XMLSchema"
							xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
							xmlns:ser="https://guias.coordinadora.com/ws/guias/1.6/server.php"
							xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
							<soapenv:Header/>
							<soapenv:Body>
								<ser:Guias_generarGuia soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
								<p xsi:type="ser:Agw_typeGenerarGuiaIn">
									<codigo_remision xsi:type="xsd:string"/>
									<fecha xsi:type="xsd:string"/>
									<id_cliente xsi:type="xsd:int">',CASE @TipoEnvio WHEN 'FletePago' THEN '46620' ELSE '46531' END,'</id_cliente>
									<id_remitente xsi:type="xsd:int">0</id_remitente>
									<nombre_remitente xsi:type="xsd:string">Ruby Rose</nombre_remitente>
									<direccion_remitente xsi:type="xsd:string">CRA 48B N° 99 SUR 59 BODEGAS 20-21 UNIDAD DE BODEGAS SAN BARTOLOME SECTOR LA TABLAZA</direccion_remitente>
									<telefono_remitente xsi:type="xsd:string">3113790999</telefono_remitente>
									<ciudad_remitente xsi:type="xsd:string">05380000</ciudad_remitente>
									<nit_destinatario xsi:type="xsd:string"></nit_destinatario>
									<div_destinatario xsi:type="xsd:string">',CASE @TipoEnvio WHEN 'FletePago' THEN '00' ELSE '01' END,'</div_destinatario>
									<nombre_destinatario xsi:type="xsd:string">',nombre_destinatario,'</nombre_destinatario>
									<direccion_destinatario xsi:type="xsd:string">',CONCAT(f015_direccion1, ' ', f015_direccion2, ' ', f015_direccion3),'</direccion_destinatario>
									<ciudad_destinatario xsi:type="xsd:string">',CONCAT(f015_id_depto,f015_id_ciudad,'000'),'</ciudad_destinatario>
									<telefono_destinatario xsi:type="xsd:string">',f015_celular,'</telefono_destinatario>
									<valor_declarado xsi:type="xsd:float">50000</valor_declarado>
									<codigo_cuenta xsi:type="xsd:int">',CASE @TipoEnvio WHEN 'FletePago' THEN '6' ELSE '2' END,'</codigo_cuenta>
									<codigo_producto xsi:type="xsd:int">0</codigo_producto>
									<nivel_servicio xsi:type="xsd:int">1</nivel_servicio>
									<linea xsi:type="xsd:string"/>
									<contenido xsi:type="xsd:string">Cosmeticos (delicado)</contenido>
									<referencia xsi:type="xsd:string">',CASE WHEN ValorFactura = '0.00' THEN REPLACE(referencia,'CPV','CPPV') ELSE referencia END,'</referencia>
									<observaciones xsi:type="xsd:string">',CASE WHEN ValorFactura = '0.00' THEN REPLACE(observaciones,'CPV','CPPV') ELSE observaciones END,'</observaciones>
									<estado xsi:type="xsd:string">IMPRESO</estado>
									<detalle SOAP-ENC:arrayType="ns1:Agw_typeGuiaDetalle[1]" xsi:type="ns1:ArrayOfAgw_typeGuiaDetalle">
										<item xsi:type="ns1:Agw_typeGuiaDetalle">
											<ubl xsi:type="xsd:int">0</ubl>
											<alto xsi:type="xsd:float">',CASE @TipoEnvio WHEN 'Paquete' THEN '1' WHEN 'Mercancia' THEN '30' ELSE '15' END,'</alto>
											<ancho xsi:type="xsd:float">',CASE @TipoEnvio WHEN 'Paquete' THEN '50' WHEN 'Mercancia' THEN '50' ELSE '9' END,'</ancho>
											<largo xsi:type="xsd:float">',CASE @TipoEnvio WHEN 'Paquete' THEN '50' WHEN 'Mercancia' THEN '50' ELSE '5' END,'</largo>
											<peso xsi:type="xsd:float">',CASE @TipoEnvio WHEN 'Paquete' THEN '1' WHEN 'Mercancia' THEN '7' ELSE '1' END,'</peso>
											<unidades xsi:type="xsd:int">',NumUnidades,'</unidades>
											<referencia xsi:type="xsd:string"/>
											<nombre_empaque xsi:type="xsd:string"></nombre_empaque>
										</item>
									</detalle>
									<cuenta_contable xsi:type="xsd:string"/>
									<centro_costos xsi:type="xsd:string"/>
									<recaudos xsi:type="ser:ArrayOfAgw_typeGuiaDetalleRecaudo" soapenc:arrayType="ser:Agw_typeGuiaDetalleRecaudo[0]"/>
									<margen_izquierdo xsi:type="xsd:float"/>
									<margen_superior xsi:type="xsd:float"/>
									<id_rotulo xsi:type="xsd:int"/>
									<usuario_vmi xsi:type="xsd:string"/>
									<formato_impresion xsi:type="xsd:string"/>
									<atributo1_nombre xsi:type="xsd:string"/>
									<atributo1_valor xsi:type="xsd:string"/>
									<notificaciones xsi:type="ns1:ArrayOfAgw_typeNotificaciones"/>
									<atributos_retorno xsi:type="ns1:Agw_typeAtributosRetorno"/>
									<nro_doc_radicados xsi:type="xsd:string"/>
									<nro_sobre xsi:type="xsd:string"/>
									<usuario xsi:type="xsd:string">transvision.ws</usuario>
				                    <clave xsi:type="xsd:string">b914367c9899bdd191eeb9571293b0dd39777a21759d18dc6b0a12fe73c35cfb</clave>
								</p>
							</ser:Guias_generarGuia>
						</soapenv:Body>
					</soapenv:Envelope>') AS xmlGuia
		  INTO #tmp_XML
		  FROM #InfoTerceroCliente I
			   INNER JOIN #EntidadesTipoTexto T ON I.f350_consec_docto = T.f350_consec_docto
			   --INNER JOIN #EntidadesMaestroDetalle M ON T.f350_consec_docto = M.f350_consec_docto
			   INNER JOIN #FacturaYPedido F ON T.f350_consec_docto = F.f350_consec_docto


		 --select * from #tmp_XML
		 --Insertamos para que el registro se pueda procesar
		 INSERT INTO documentos (id_cia_connekta,id_transportadora,documento_referencia,connikey,endpoint,obj_transportadora)
			  SELECT 8227,
					 1,
					 @ConsFactura,
					 'cf01638bdc8f6187830cae1728055fb2',
					 'https://guias.coordinadora.com/ws/guias/1.6/server.php',
					 xmlGuia
				FROM #tmp_XML;
	  END

      DELETE FROM #InfoTerceroCliente;
	  DELETE FROM #EntidadesTipoTexto;
	  DELETE FROM #EntidadesMaestroDetalle;
	  DELETE FROM #FacturaYPedido;
	  DROP TABLE #tmp_XML;

	  SET @i += 1;
END

DROP TABLE #ListadoFacturas, #tmp_PedidosProcesar
*/