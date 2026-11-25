/*
    ================================================================================
    INTEGRACIÓN VTEX - MERCEDES CAMPUZANO
    SCRIPT: Coordinadora.sql
    DESCRIPCIÓN:
        - Genera las Guías de despacho con Coordinadora ANTES del proceso de Invoiced.
        - Ubicación en el flujo: Posterior a Start Handling / Factura Siesa (id_estado = 5)
                                 y previo a Invoiced en VTEX (id_estado = 6).
        - Incluye SWITCH para habilitar / deshabilitar fácilmente la generación de guías.
    ================================================================================
*/

-- ============================================================================
-- 1. CONFIGURACIÓN Y SWITCH DE ACTIVACIÓN
-- ============================================================================
DECLARE @genera_guia BIT            = 1; -- 1: Habilitar generación de Guías | 0: Omitir Guías (Pasa directo a Invoiced)
DECLARE @endpoint    NVARCHAR(500)  = 'https://guias.coordinadora.com/ws/guias/1.6/server.php';
DECLARE @id_estado_origen  INT      = 5; -- Estado post Start Handling / con Factura Siesa
DECLARE @id_estado_destino INT      = 6; -- Estado para Invoiced

-- ============================================================================
-- 2. COMPORTAMIENTO SI EL SWITCH ESTÁ DESACTIVADO (@genera_guia = 0)
-- ============================================================================
IF (@genera_guia = 0)
BEGIN
    -- Omitir generación de guías y avanzar todas las órdenes directamente a Invoiced
    UPDATE ordenes 
    SET 
        id_estado         = @id_estado_destino,
        intentos          = 0,
        endpoint          = NULL,
        orden_obj_destino = NULL,
        fecha_creacion    = GETDATE()
    WHERE 
        id_estado = @id_estado_origen;

    RETURN;
END;

-- ============================================================================
-- 3. BYPASS DE MARKETPLACES EXTERNOS (No generan guía propia con Coordinadora)
-- ============================================================================
UPDATE ordenes 
SET 
    id_estado         = @id_estado_destino,
    intentos          = 0,
    endpoint          = NULL,
    orden_obj_destino = NULL,
    fecha_creacion    = GETDATE()
WHERE 
    id_estado = @id_estado_origen 
    AND JSON_VALUE(orden_obj_origen, '$.marketplace.name') != 'mercedescampuzano';

-- ============================================================================
-- 4. OBTENCIÓN DE ÓRDENES A PROCESAR (Con Factura en Siesa ERP)
-- ============================================================================
IF OBJECT_ID('tempdb..#tmp_ordenesProcesar') IS NOT NULL DROP TABLE #tmp_ordenesProcesar;

SELECT 
    ROW_NUMBER() OVER (ORDER BY id_orden ASC) AS Orden,
    id_orden, 
    id_estado, 
    orden_obj_origen, 
    intentos, 
    fecha_creacion, 
    orden_obj_destino,
    JSON_VALUE(orden_obj_origen, '$.paymentData.transactions[0].payments[0].paymentSystemName') AS medioPago,
    JSON_VALUE(orden_obj_origen, '$.shippingData.logisticsInfo[0].selectedDeliveryChannel')     AS selectedDeliveryChannel,
    JSON_VALUE(orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany')             AS deliveryCompany,
    JSON_VALUE(orden_obj_origen, '$.shippingData.logisticsInfo[0].selectedSla')                 AS selectedSla,
    JSON_VALUE(orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryIds[0].courierName')  AS courierName,
    JSON_VALUE(orden_obj_origen, '$.origin')                                                    AS origin,
    JSON_VALUE(orden_obj_origen, '$.marketplace.name')                                          AS marketplaceName,
    f430_consec_docto, 
    f350_id_co, 
    f350_id_tipo_docto, 
    f350_consec_docto, 
    f461_vlr_neto, 
    58000 AS vlr_declarado
INTO #tmp_ordenesProcesar
FROM ordenes
    INNER JOIN OPENROWSET(
        'SQLNCLI', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Rehemma_Real;UID=Rehemma;PWD=Rehemma$12$%', 
        'SELECT * FROM dbo.t430_cm_pv_docto'
    ) AS pedido 
        ON pedido.f430_referencia = JSON_VALUE(orden_obj_origen, '$.sequence')
        AND LEFT(
            pedido.f430_notas,
            IIF(
                CHARINDEX('|', pedido.f430_notas) > 0,
                CHARINDEX('|', pedido.f430_notas) - 1,
                LEN(pedido.f430_notas)
            )
        ) = JSON_VALUE(orden_obj_origen, '$.orderId')
    INNER JOIN OPENROWSET(
        'SQLNCLI', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Rehemma_Real;UID=Rehemma;PWD=Rehemma$12$%', 
        'SELECT * FROM dbo.t460_cm_docto_remision_venta'
    ) AS remision 
        ON pedido.f430_rowid = remision.f460_rowid_pv_docto
    INNER JOIN OPENROWSET(
        'SQLNCLI', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Rehemma_Real;UID=Rehemma;PWD=Rehemma$12$%', 
        'SELECT * FROM dbo.t461_cm_docto_factura_venta'
    ) AS factura 
        ON factura.f461_rowid_docto = remision.f460_rowid_docto_factura
    INNER JOIN OPENROWSET(
        'SQLNCLI', 
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Rehemma_Real;UID=Rehemma;PWD=Rehemma$12$%', 
        'SELECT * FROM dbo.t350_co_docto_contable'
    ) AS mov 
        ON mov.f350_rowid = factura.f461_rowid_docto
WHERE 
    id_estado = @id_estado_origen
    AND intentos <= 3
    AND (endpoint != @endpoint OR endpoint IS NULL)
    AND orden_obj_destino IS NULL
    AND JSON_VALUE(orden_obj_origen, '$.marketplace.name') = 'mercedescampuzano';

-- ============================================================================
-- 5. CONSTRUCCIÓN DE PAYLOAD SOAP E INSERCIÓN EN TABLA DE ÓRDENES
-- ============================================================================
DECLARE @cantidadRegistros INT = (SELECT COUNT(*) FROM #tmp_ordenesProcesar);
DECLARE @i INT = 1;

WHILE @i <= @cantidadRegistros
BEGIN
    DECLARE @marketplaceName VARCHAR(100) = (SELECT marketplaceName FROM #tmp_ordenesProcesar WHERE Orden = @i);
    DECLARE @medioPago VARCHAR(100)       = (SELECT medioPago FROM #tmp_ordenesProcesar WHERE Orden = @i);
    DECLARE @selectedSla VARCHAR(100)     = (SELECT selectedSla FROM #tmp_ordenesProcesar WHERE Orden = @i);
    DECLARE @RecaudoGuia NVARCHAR(MAX)    = '';
    DECLARE @ContieneRecaudo INT          = 0;

    -- Recaudo contra entrega
    IF @medioPago = 'Pago contra entrega' OR (@medioPago = 'Vale' AND @selectedSla = 'Pago contra entrega')
    BEGIN
        SELECT @RecaudoGuia += CONCAT(
            '<item xsi:type="ser1:Agw_typeGuiaDetalleRecaudo">
                <referencia xsi:type="xsd:string">', id_orden, '</referencia>
                <valor xsi:type="xsd:float">', f461_vlr_neto, '</valor>
                <valor_base_iva xsi:type="xsd:float"></valor_base_iva>
                <valor_iva xsi:type="xsd:float"></valor_iva>
                <forma_pago xsi:type="xsd:int">1</forma_pago>
            </item>'
        )
        FROM #tmp_ordenesProcesar
        WHERE Orden = @i;

        SET @ContieneRecaudo = 1;
    END;

    -- Construcción del Sobre SOAP XML
    IF OBJECT_ID('tempdb..#tmp_guias') IS NOT NULL DROP TABLE #tmp_guias;

    SELECT 
        intentos,
        fecha_creacion,
        orden_obj_destino,
        orden_obj_origen,
        CONCAT(
            '<soapenv:Envelope
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
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
                            <id_cliente xsi:type="xsd:int">51613</id_cliente>
                            <id_remitente xsi:type="xsd:int">0</id_remitente>
                            <nombre_remitente xsi:type="xsd:string">REHEMMA S.A.S</nombre_remitente>
                            <direccion_remitente xsi:type="xsd:string">CRA 51 # 9 C SUR 85 - PISO 6 BODEGA 602</direccion_remitente>
                            <telefono_remitente xsi:type="xsd:string">3148889145</telefono_remitente>
                            <ciudad_remitente xsi:type="xsd:string">05001000</ciudad_remitente>
                            <nit_destinatario xsi:type="xsd:string">', JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '</nit_destinatario>
                            <div_destinatario xsi:type="xsd:string">01</div_destinatario>
                            <nombre_destinatario xsi:type="xsd:string">', CONCAT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')), '</nombre_destinatario>
                            <direccion_destinatario xsi:type="xsd:string">', CONCAT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), ' ', JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement'), ' ', JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood')), '</direccion_destinatario>
                            <ciudad_destinatario xsi:type="xsd:string">', CONCAT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), '000'), '</ciudad_destinatario>
                            <telefono_destinatario xsi:type="xsd:string">', REPLACE(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), '+57', ''), '</telefono_destinatario>
                            <valor_declarado xsi:type="xsd:float">', vlr_declarado, '</valor_declarado>
                            <codigo_cuenta xsi:type="xsd:int">1</codigo_cuenta>
                            <codigo_producto xsi:type="xsd:int">0</codigo_producto>
                            <nivel_servicio xsi:type="xsd:int">1</nivel_servicio>
                            <linea xsi:type="xsd:string"/>
                            <contenido xsi:type="xsd:string">Prendas Y Accesorios</contenido>
                            <referencia xsi:type="xsd:string">', JSON_VALUE(orden_obj_origen, '$.orderId'), '</referencia>
                            <observaciones xsi:type="xsd:string">', SUBSTRING('Entregar a: ' + CONCAT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')) + ' Factura: ' + f350_id_co + '-' + f350_id_tipo_docto + '-' + CONVERT(CHAR, f350_consec_docto), 1, 85), '</observaciones>
                            <estado xsi:type="xsd:string">IMPRESO</estado>
                            <detalle SOAP-ENC:arrayType="ns1:Agw_typeGuiaDetalle[1]" xsi:type="ns1:ArrayOfAgw_typeGuiaDetalle">
                                <item xsi:type="ns1:Agw_typeGuiaDetalle">
                                    <ubl xsi:type="xsd:int">0</ubl>
                                    <alto xsi:type="xsd:float">1</alto>
                                    <ancho xsi:type="xsd:float">50</ancho>
                                    <largo xsi:type="xsd:float">50</largo>
                                    <peso xsi:type="xsd:float">1</peso>
                                    <unidades xsi:type="xsd:int">1</unidades>
                                    <referencia xsi:type="xsd:string"/>
                                    <nombre_empaque xsi:type="xsd:string"/>
                                </item>
                            </detalle>
                            <cuenta_contable xsi:type="xsd:string"/>
                            <centro_costos xsi:type="xsd:string">015</centro_costos>
                            <recaudos SOAP-ENC:arrayType="ser:Agw_typeGuiaDetalleRecaudo[', @ContieneRecaudo, ']" xsi:type="ser:ArrayOfAgw_typeGuiaDetalleRecaudo">', @RecaudoGuia, '</recaudos>
                            <margen_izquierdo xsi:type="xsd:float"/>
                            <margen_superior xsi:type="xsd:float"/>
                            <id_rotulo xsi:type="xsd:int"/>
                            <usuario_vmi xsi:type="xsd:string"/>
                            <formato_impresion xsi:type="xsd:string"/>
                            <atributo1_nombre xsi:type="xsd:string"/>
                            <atributo1_valor xsi:type="xsd:string"/>
                            <notificaciones SOAP-ENC:arrayType="ns1:Agw_typeNotificacion[1]" xsi:type="ns1:ArrayOfAgw_typeNotificacion">
                                <item xsi:type="ns1:Agw_typeNotificacion">
                                    <tipo_medio xsi:type="xsd:string">1</tipo_medio>
                                    <destino_notificacion xsi:type="xsd:string">', JSON_VALUE(orden_obj_origen, '$.clientProfileData.email'), '</destino_notificacion>
                                </item>
                            </notificaciones>
                            <atributos_retorno xsi:type="ns1:Agw_typeAtributosRetorno"/>
                            <nro_doc_radicados xsi:type="xsd:string"/>
                            <nro_sobre xsi:type="xsd:string"/>
                            <usuario xsi:type="xsd:string">rehemma.ws</usuario>
                            <clave xsi:type="xsd:string">2f7bd9f79c8cbad25d15658048c92f17f2be3bd4e4a4bb7f27563c44032e4d4d</clave>
                        </p>
                    </ser:Guias_generarGuia>
                </soapenv:Body>
            </soapenv:Envelope>'
        ) AS xmlGuia
    INTO #tmp_guias
    FROM #tmp_ordenesProcesar
    WHERE Orden = @i;

    -- Asignación para que el motor de integración consuma Coordinadora
    UPDATE ordenes 
    SET 
        endpoint          = @endpoint, 
        intentos          = 0, 
        fecha_creacion    = GETDATE(),
        orden_obj_destino = xmlGuia
    FROM #tmp_guias
    WHERE id_orden = (SELECT id_orden FROM #tmp_ordenesProcesar WHERE Orden = @i);

    DROP TABLE #tmp_guias;

    SET @i = @i + 1;
END;

DROP TABLE #tmp_ordenesProcesar;