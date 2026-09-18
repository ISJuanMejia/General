/* =========================================================================================
   PROYECTO: VTEX ESTÁNDAR V2
   PROCESO: 09. GUÍAS COORDINADORA
   TABLA DESTINO: dbo.ordenes (columnas endpoint y orden_obj_destino)
   DESCRIPCIÓN: Genera la trama SOAP estándar para el Web Service de Coordinadora 
                (Guias_generarGuia) para órdenes con entrega asignada a dicha transportadora.
   ========================================================================================= */

SET NOCOUNT ON;

DECLARE @id_tienda INT = 1;
DECLARE @endpoint  NVARCHAR(500) = 'http://guias.coordinadora.com/ws/guias/1.6/server.php';

-- 1. Actualizar órdenes que apliquen para generación de guía Coordinadora
UPDATE o
SET 
    o.endpoint          = @endpoint,
    o.intentos          = 0,
    o.fecha_creacion    = GETDATE(),
    o.orden_obj_destino = 
    '<soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' +
                       'xmlns:xsd="http://www.w3.org/2001/XMLSchema" ' +
                       'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                       'xmlns:ser="https://sandbox.coordinadora.com/agw/ws/guias/1.6/server.php" ' +
                       'xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">' +
        '<soapenv:Header/>' +
        '<soapenv:Body>' +
            '<ser:Guias_generarGuia soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">' +
                '<p xsi:type="ser:Agw_typeGenerarGuiaIn">' +
                    '<codigo_remision xsi:type="xsd:string"/>' +
                    '<fecha xsi:type="xsd:string"/>' +
                    '<id_cliente xsi:type="xsd:int">37768</id_cliente>' +
                    '<id_remitente xsi:type="xsd:int">0</id_remitente>' +
                    '<nombre_remitente xsi:type="xsd:string">Ecommerce Central S.A.</nombre_remitente>' +
                    '<direccion_remitente xsi:type="xsd:string">CRA 67 # 78 - 280</direccion_remitente>' +
                    '<telefono_remitente xsi:type="xsd:string">6041234567</telefono_remitente>' +
                    '<ciudad_remitente xsi:type="xsd:string">05001000</ciudad_remitente>' +
                    '<nit_destinatario xsi:type="xsd:string">' + TRIM(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document')) + '</nit_destinatario>' +
                    '<div_destinatario xsi:type="xsd:string"></div_destinatario>' +
                    '<nombre_destinatario xsi:type="xsd:string">' + 
                        SUBSTRING(UPPER(TRIM(CONCAT(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'), ' ', ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'), '')))), 1, 60) + 
                    '</nombre_destinatario>' +
                    '<direccion_destinatario xsi:type="xsd:string">' + 
                        SUBSTRING(REPLACE(UPPER(TRIM(CONCAT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.street'), ' ', ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.number'), ''), ' ', ISNULL(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.neighborhood'), '')))), '''', ' '), 1, 80) + 
                    '</direccion_destinatario>' +
                    '<ciudad_destinatario xsi:type="xsd:string">' + CONCAT(SUBSTRING(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.postalCode'), 1, 5), '000') + '</ciudad_destinatario>' +
                    '<telefono_destinatario xsi:type="xsd:string">' + SUBSTRING(REPLACE(ISNULL(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.phone'), '0'), '+57', ''), 1, 15) + '</telefono_destinatario>' +
                    '<valor_declarado xsi:type="xsd:float">' + CAST(CAST(JSON_VALUE(o.orden_obj_origen, '$.value') AS INT) / 100 AS VARCHAR(20)) + '</valor_declarado>' +
                    '<codigo_cuenta xsi:type="xsd:int">1</codigo_cuenta>' +
                    '<codigo_producto xsi:type="xsd:int">0</codigo_producto>' +
                    '<nivel_servicio xsi:type="xsd:int">' + 
                        CASE WHEN JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany') = 'Pago contra entrega' THEN '22' ELSE '1' END + 
                    '</nivel_servicio>' +
                    '<contenido xsi:type="xsd:string">Mercancia E-commerce</contenido>' +
                    '<referencia xsi:type="xsd:string">' + JSON_VALUE(o.orden_obj_origen, '$.orderId') + '</referencia>' +
                    '<observaciones xsi:type="xsd:string">' + 
                        SUBSTRING(CONCAT('Pedido: ', JSON_VALUE(o.orden_obj_origen, '$.orderId')), 1, 80) + 
                    '</observaciones>' +
                    '<estado xsi:type="xsd:string">IMPRESO</estado>' +
                    '<detalle SOAP-ENC:arrayType="ns1:Agw_typeGuiaDetalle[1]" xsi:type="ns1:ArrayOfAgw_typeGuiaDetalle">' +
                        '<item xsi:type="ns1:Agw_typeGuiaDetalle">' +
                            '<ubl xsi:type="xsd:int">0</ubl>' +
                            '<alto xsi:type="xsd:float">10</alto>' +
                            '<ancho xsi:type="xsd:float">20</ancho>' +
                            '<largo xsi:type="xsd:float">20</largo>' +
                            '<peso xsi:type="xsd:float">1</peso>' +
                            '<unidades xsi:type="xsd:int">1</unidades>' +
                        '</item>' +
                    '</detalle>' +
                    '<usuario xsi:type="xsd:string">ws_coordinadora</usuario>' +
                    '<clave xsi:type="xsd:string">df54e3fc6dce34f780f645f934ac18d77d7bc4a5cf113f9bec9a8f6ad5f55e7d</clave>' +
                '</p>' +
            '</ser:Guias_generarGuia>' +
        '</soapenv:Body>' +
    '</soapenv:Envelope>'
FROM [dbo].[ordenes] o
LEFT JOIN [dbo].[guias_transportadoras] g 
    ON g.id_orden = o.id
WHERE o.id_tienda = @id_tienda
  AND o.id_estado = 5 -- Fase logística / despacho previo a facturar
  AND o.intentos <= 3
  AND g.id_orden IS NULL
  AND JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany') = 'Coordinadora'
  AND ISNULL(o.endpoint, '') <> @endpoint;

-- 2. Transicionar directamente a Estado 6 órdenes con otras transportadoras o con guía ya existente
UPDATE o
SET 
    o.id_estado = 6,
    o.intentos = 0,
    o.fecha_creacion = GETDATE(),
    o.orden_obj_destino = NULL,
    o.endpoint = NULL
FROM [dbo].[ordenes] o
LEFT JOIN [dbo].[guias_transportadoras] g 
    ON g.id_orden = o.id
WHERE o.id_tienda = @id_tienda
  AND o.id_estado = 5
  AND o.intentos <= 3
  AND (
      JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany') <> 'Coordinadora' 
      OR g.id_orden IS NOT NULL
  );
