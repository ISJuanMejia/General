SET NOCOUNT ON;

-- ==========================================
-- 0. LIMPIEZA PREVIA DE TABLAS TEMPORALES
-- ==========================================
IF OBJECT_ID('tempdb..#OrdenesEstado5Speedo') IS NOT NULL DROP TABLE #OrdenesEstado5Speedo;
IF OBJECT_ID('tempdb..#UpdateCoordinadoraSpeedo') IS NOT NULL DROP TABLE #UpdateCoordinadoraSpeedo;
IF OBJECT_ID('tempdb..#UpdateOtrosSpeedo') IS NOT NULL DROP TABLE #UpdateOtrosSpeedo;

DECLARE @endpoint NVARCHAR(500) = 'http://guias.coordinadora.com/ws/guias/1.6/server.php';
DECLARE @FechaFiltro DATETIME = DATEADD(day, -15, GETDATE());

-- ==========================================
-- 1. AISLAR EL UNIVERSO DE TRABAJO (Últimos 15 días)
-- ==========================================
CREATE TABLE #OrdenesEstado5Speedo (
    id INT PRIMARY KEY CLUSTERED,
    orden_obj_origen NVARCHAR(MAX),
    DeliveryCompany NVARCHAR(150),
    TieneGuia BIT,
    INDEX IX_#OrdenesEstado5Speedo_Delivery (DeliveryCompany, TieneGuia) 
);

INSERT INTO #OrdenesEstado5Speedo (id, orden_obj_origen, DeliveryCompany, TieneGuia)
SELECT 
    o.id,
    o.orden_obj_origen,
    JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany'),
    CASE WHEN g.id_orden IS NOT NULL THEN 1 ELSE 0 END
FROM ordenes o
LEFT JOIN guias_transportadoras g ON g.id_orden = o.id
WHERE o.fecha_creacion >= DATEADD(day, -15, GETDATE())
  AND o.id_estado = 5
  AND o.intentos <= 3
  AND o.fecha_creacion >= @FechaFiltro;

-- ==========================================
-- 2. CASO 1: ACTUALIZACIÓN PARA 'COORDINADORA' (Construcción de XML local)
-- ==========================================
CREATE TABLE #UpdateCoordinadoraSpeedo (
    id INT PRIMARY KEY CLUSTERED,
    XmlDestino NVARCHAR(MAX)
);

INSERT INTO #UpdateCoordinadoraSpeedo (id, XmlDestino)
SELECT 
    id,
    '<soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
                       xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
                       xmlns:ser="http://guias.coordinadora.com/ws/guias/1.6/server.php" 
                       xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <soapenv:Header/>
        <soapenv:Body>
            <ser:Guias_generarGuia soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
                <p xsi:type="ser:Agw_typeGenerarGuiaIn">
                    <codigo_remision xsi:type="xsd:string"/>
                    <fecha xsi:type="xsd:string"/>
                    <id_cliente xsi:type="xsd:int">31724</id_cliente>
                    <id_remitente xsi:type="xsd:int">0</id_remitente>
                    <nombre_remitente xsi:type="xsd:string">Creaciones Nadar S.A</nombre_remitente>
                    <direccion_remitente xsi:type="xsd:string">CRA 67 # 78 - 280</direccion_remitente>
                    <telefono_remitente xsi:type="xsd:string">6049467</telefono_remitente>
                    <ciudad_remitente xsi:type="xsd:string">05001000</ciudad_remitente>
                    <nit_destinatario xsi:type="xsd:string">' + ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.document'), '') + '</nit_destinatario>
                    <div_destinatario xsi:type="xsd:string"></div_destinatario>
                    <nombre_destinatario xsi:type="xsd:string">' + CONCAT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')) + '</nombre_destinatario>
                    <direccion_destinatario xsi:type="xsd:string">' + 
                    REPLACE(
                        CONCAT(
                            JSON_VALUE(orden_obj_origen, '$.shippingData.address.street'), ' ',
                            JSON_VALUE(orden_obj_origen, '$.shippingData.address.complement'), ' ',
                            JSON_VALUE(orden_obj_origen, '$.shippingData.address.neighborhood')), '''', ' ') + 
                    '</direccion_destinatario>
                    <ciudad_destinatario xsi:type="xsd:string">' + CONCAT(JSON_VALUE(orden_obj_origen, '$.shippingData.address.postalCode'), '000') + '</ciudad_destinatario>
                    <telefono_destinatario xsi:type="xsd:string">' + REPLACE(ISNULL(JSON_VALUE(orden_obj_origen, '$.clientProfileData.phone'), ''), '+57', '') + '</telefono_destinatario>
                    <valor_declarado xsi:type="xsd:float">50000</valor_declarado>
                    <codigo_cuenta xsi:type="xsd:int">1</codigo_cuenta>
                    <codigo_producto xsi:type="xsd:int">0</codigo_producto>
                    <nivel_servicio xsi:type="xsd:int">' + CASE WHEN DeliveryCompany = 'Pago contra entrega' THEN '22' ELSE '1' END + '</nivel_servicio>
                    <contenido xsi:type="xsd:string">Prendas</contenido>
                    <referencia xsi:type="xsd:string">' + JSON_VALUE(orden_obj_origen, '$.orderId') + '</referencia>
                    <observaciones xsi:type="xsd:string">' + 
                        SUBSTRING(
                            'Entregar a: ' + CONCAT(JSON_VALUE(orden_obj_origen, '$.clientProfileData.firstName'), ' ', JSON_VALUE(orden_obj_origen, '$.clientProfileData.lastName')),
                            1, 
                            85
                        ) + '</observaciones>
                    <estado xsi:type="xsd:string">IMPRESO</estado>
                    <detalle SOAP-ENC:arrayType="ns1:Agw_typeGuiaDetalle[1]" xsi:type="ns1:ArrayOfAgw_typeGuiaDetalle">
                        <item xsi:type="ns1:Agw_typeGuiaDetalle">
                            <ubl xsi:type="xsd:int">0</ubl>
                            <alto xsi:type="xsd:float">1</alto>
                            <ancho xsi:type="xsd:float">50</ancho>
                            <largo xsi:type="xsd:float">50</largo>
                            <peso xsi:type="xsd:float">1</peso>
                            <unidades xsi:type="xsd:int">1</unidades>
                        </item>
                    </detalle>
                    <usuario xsi:type="xsd:string">nadar.ws</usuario>
                    <clave xsi:type="xsd:string">12d4e17e84824698dc0b18206ba7911c61551cf0d4c11cc5e6025b15a9e31cea</clave>
                </p>
            </ser:Guias_generarGuia>
        </soapenv:Body>
    </soapenv:Envelope>'
FROM #OrdenesEstado5Speedo
WHERE DeliveryCompany = 'Coordinadora'
  AND TieneGuia = 0;

-- Ejecutar el primer UPDATE quirúrgico
UPDATE o
SET 
    o.endpoint = @endpoint,
    o.intentos = 0,
    o.fecha_creacion = GETDATE(),
    o.orden_obj_destino = u.XmlDestino
FROM ordenes o
INNER JOIN #UpdateCoordinadoraSpeedo u ON o.id = u.id
WHERE o.fecha_creacion >= DATEADD(day, -15, GETDATE())
  AND ISNULL(o.endpoint, '') != @endpoint;

-- ==========================================
-- 3. CASO 2: ACTUALIZACIÓN PARA OTROS COURIER
-- ==========================================
CREATE TABLE #UpdateOtrosSpeedo (
    id INT PRIMARY KEY CLUSTERED
);

INSERT INTO #UpdateOtrosSpeedo (id)
SELECT id
FROM #OrdenesEstado5Speedo
WHERE DeliveryCompany != 'Coordinadora' 
   OR TieneGuia = 1;

-- Ejecutar el segundo UPDATE quirúrgico
UPDATE o
SET 
    o.id_estado = 6,
    o.intentos = 0,
    o.fecha_creacion = GETDATE(),
    o.orden_obj_destino = NULL,
    o.endpoint = NULL
FROM ordenes o
INNER JOIN #UpdateOtrosSpeedo u ON o.id = u.id
WHERE o.fecha_creacion >= DATEADD(day, -15, GETDATE())
  AND o.id_tienda = 1;

-- ==========================================
-- 4. LIMPIEZA FINAL
-- ==========================================
IF OBJECT_ID('tempdb..#OrdenesEstado5Speedo') IS NOT NULL DROP TABLE #OrdenesEstado5Speedo;
IF OBJECT_ID('tempdb..#UpdateCoordinadoraSpeedo') IS NOT NULL DROP TABLE #UpdateCoordinadoraSpeedo;
IF OBJECT_ID('tempdb..#UpdateOtrosSpeedo') IS NOT NULL DROP TABLE #UpdateOtrosSpeedo;