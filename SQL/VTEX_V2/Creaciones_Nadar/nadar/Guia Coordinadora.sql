DECLARE @endpoint NVARCHAR(500) = 'http://guias.coordinadora.com/ws/guias/1.6/server.php';

-- Actualización para 'Contra-entrega'
UPDATE o
SET 
    o.endpoint = @endpoint,
    o.intentos = 0,
    o.fecha_creacion = GETDATE(),
    o.orden_obj_destino = 
    '<soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
                       xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
                       xmlns:ser="https://sandbox.coordinadora.com/agw/ws/guias/1.6/server.php" 
                       xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <soapenv:Header/>
        <soapenv:Body>
            <ser:Guias_generarGuia soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
                <p xsi:type="ser:Agw_typeGenerarGuiaIn">
                    <codigo_remision xsi:type="xsd:string"/>
                    <fecha xsi:type="xsd:string"/>
                    <id_cliente xsi:type="xsd:int">37768</id_cliente>
                    <id_remitente xsi:type="xsd:int">0</id_remitente>
                    <nombre_remitente xsi:type="xsd:string">Creaciones Nadar S.A</nombre_remitente>
                    <direccion_remitente xsi:type="xsd:string">CRA 67 # 78 - 280</direccion_remitente>
                    <telefono_remitente xsi:type="xsd:string">6049467</telefono_remitente>
                    <ciudad_remitente xsi:type="xsd:string">05001000</ciudad_remitente>
                    <nit_destinatario xsi:type="xsd:string">' + JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') + '</nit_destinatario>
                    <div_destinatario xsi:type="xsd:string"></div_destinatario>
                    <nombre_destinatario xsi:type="xsd:string">' + CONCAT(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'), ' ', JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName')) + '</nombre_destinatario>
                    <direccion_destinatario xsi:type="xsd:string">' + 
					REPLACE(
					    CONCAT(
					        JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.street'), ' ',
					        JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.complement'), ' ',
					        JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.neighborhood')), '''', ' ') + 
					'</direccion_destinatario>
                    <ciudad_destinatario xsi:type="xsd:string">' + CONCAT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.postalCode'),'000') + '</ciudad_destinatario>
                    <telefono_destinatario xsi:type="xsd:string">' + REPLACE(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.phone'), '+57', '') + '</telefono_destinatario>
                    <valor_declarado xsi:type="xsd:float">50000</valor_declarado>
                    <codigo_cuenta xsi:type="xsd:int">1</codigo_cuenta>
                    <codigo_producto xsi:type="xsd:int">0</codigo_producto>
                    <nivel_servicio xsi:type="xsd:int">' + CASE WHEN JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany') = 'Pago contra entrega' THEN '22' ELSE '1' END + '</nivel_servicio>
                    <contenido xsi:type="xsd:string">Prendas</contenido>
                    <referencia xsi:type="xsd:string">' + JSON_VALUE(o.orden_obj_origen, '$.orderId') + '</referencia>
                    <observaciones xsi:type="xsd:string">' + 
                        SUBSTRING(
                            'Entregar a: ' + CONCAT(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'), ' ', JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName')),
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
                    <usuario xsi:type="xsd:string">nadar.despachos04</usuario>
                    <clave xsi:type="xsd:string">df54e3fc6dce34f780f645f934ac18d77d7bc4a5cf113f9bec9a8f6ad5f55e7d</clave>
                </p>
            </ser:Guias_generarGuia>
        </soapenv:Body>
    </soapenv:Envelope>'
FROM ordenes o
left join guias_transportadoras g on g.id_orden = o.id
WHERE 
    o.id_estado = 5
	AND o.id_tienda = 2
    AND o.intentos <= 3
	AND g.id_orden IS NULL
    AND JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany') = 'Transportadora'
    AND ISNULL(o.endpoint, '') != @endpoint;

-- Actualización para otros valores de deliveryCompany
UPDATE o
SET 
    o.id_estado = 6,
    o.intentos = 0,
    o.fecha_creacion = GETDATE(),
    o.orden_obj_destino = null,
	o.endpoint = null
FROM ordenes o
left join guias_transportadoras g on g.id_orden = o.id
WHERE 
    o.id_estado = 5
	AND o.id_tienda = 2
    AND o.intentos <= 3
    AND (JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany') != 'Transportadora' OR g.id_orden IS NOT NULL);