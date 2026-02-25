DECLARE @endpoint NVARCHAR(500) = 'http://guias.coordinadora.com/ws/guias/1.6/server.php';

/*
    *   GENERAL
*/
DECLARE @batch_size         INT             =   15; --  *   ->  Cuantas guias se traen por petición
DECLARE @fecha              VARCHAR(10)     =   FORMAT(GETDATE(), 'yyyy-MM-dd')
DECLARE @valor_declarado    INT             =   30000;

/*
    *   Declara una variable para especificar el tipo de código de cuenta para el envío:
    *       1   ->   Cuenta corriente
    *       2   ->   Acuerdo semanal
    *       3   ->   Flete pago
*/
DECLARE @codigo_cuenta  INT             =   1;
    
/*
    *   Declara una variable para especificar el tipo de código de producto para el envío:
    *       0   ->  Auto, se determina automaticamente a partir del detalle de la guia
    *       1   ->  Mercancia
    *       2   ->  Paquetes de 1-2 Kg
    *       3   ->  Documentos
    *       6   ->  Paquetes de 3-5 Kg
*/
DECLARE @codigo_producto    INT             =   1;

/*
    *   Declara una variable para especificar el tipo de nivel de servicio para el envío:
    *       1   ->  Estándar
    *       2   ->  Express
    *       3   ->  Programado
*/
DECLARE @nivel_servicio INT             =   1;
DECLARE @contenido      VARCHAR(255)    =   'confecciones';
DECLARE @observaciones  VARCHAR(255)    =   'THM: TECNOLOGÍA, MODA Y FUNCIONALIDAD';

/*
    *   Declara una variable para especificar el estado para la generación de la guía:
    *       PENDIENTE   ->  Se registra la guia, no se genera el codigo remision ni se genera el PDF.
    *       IMPRESO     ->  Se registra la guia, se genera el codigo remision y el PDF.
*/
DECLARE @estado     VARCHAR(10)     =   'IMPRESO';
DECLARE @usuario    VARCHAR(255)    =   'maderkit.usuario'; --> 
DECLARE @clave      VARCHAR(255)    =   '16d9e5009bf5721df3cae29e257ab95cbc22305ac2dde4579bb6008cadff36e4'; --> Maderkit2025 -> falta convertir a SHA256

/*
    *   REMITENTE
*/
DECLARE @id_cliente             INT             =   20482;
DECLARE @id_remitente           INT             =   0;
DECLARE @nit_remitente          VARCHAR(10)     =   '815001802';
DECLARE @nombre_remitente       VARCHAR(255)    =   'Maderkit S.A.';
DECLARE @direccion_remitente    VARCHAR(255)    =   'Carrera 25A 13-130 Arroyohondo';
DECLARE @telefono_remitente     VARCHAR(15)     =   '6954555';
DECLARE @ciudad_remitente       VARCHAR(255)    =   '76892000'; --> * Yumbo (Valle del Cauca)

/*
    *   DESTINATARIO
*/
DECLARE @div_destinatario   VARCHAR(255)    =   '01';

/*
    *   DETALLE GUÍA
*/
DECLARE @ubl        INT =   1;
-- DECLARE @alto       INT =   4;
-- DECLARE @ancho      INT =   50;
-- DECLARE @largo      INT =   50;
DECLARE @peso       INT =   3;
DECLARE @unidades   INT =   1;


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
                    <id_cliente xsi:type="xsd:int">' + @id_cliente + '</id_cliente>
                    <id_remitente xsi:type="xsd:int">' + @id_remitente + '</id_remitente>
                    <nombre_remitente xsi:type="xsd:string">' + @nombre_remitente + '</nombre_remitente>
                    <direccion_remitente xsi:type="xsd:string">' + @direccion_remitente + '</direccion_remitente>
                    <telefono_remitente xsi:type="xsd:string">' + @telefono_remitente + '</telefono_remitente>
                    <ciudad_remitente xsi:type="xsd:string">' + @ciudad_remitente + '</ciudad_remitente>
                    <nit_destinatario xsi:type="xsd:string">' + JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') + '</nit_destinatario>
                    <div_destinatario xsi:type="xsd:string">' + @div_destinatario + '</div_destinatario>
                    <nombre_destinatario xsi:type="xsd:string">' + CONCAT(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'), ' ', JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName')) + '</nombre_destinatario>
                    <direccion_destinatario xsi:type="xsd:string">' + CONCAT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.street'), ' ', JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.complement'), ' ',JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.neighborhood')) + '</direccion_destinatario>
                    <ciudad_destinatario xsi:type="xsd:string">' + CONCAT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.postalCode'),'000') + '</ciudad_destinatario>
                    <telefono_destinatario xsi:type="xsd:string">' + REPLACE(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.phone'), '+57', '') + '</telefono_destinatario>
                    <valor_declarado xsi:type="xsd:float">34000</valor_declarado>
                    <codigo_cuenta xsi:type="xsd:int">1</codigo_cuenta>
                    <codigo_producto xsi:type="xsd:int">0</codigo_producto>
                    <nivel_servicio xsi:type="xsd:int">' + CASE WHEN JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany') = 'Contra-entrega' THEN '22' ELSE '1' END + '</nivel_servicio>
                    <contenido xsi:type="xsd:string">confección</contenido>
                    <referencia xsi:type="xsd:string">' + JSON_VALUE(o.orden_obj_origen, '$.orderId') + '</referencia>
                    <observaciones xsi:type="xsd:string">' + 
                        SUBSTRING(
                            'Entregar a: ' + CONCAT(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'), ' ', JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName')) +
                            ' Factura: ' + f350_id_co + '-' + f350_id_tipo_docto + '-' + CONVERT(CHAR, f350_consec_docto),
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
                            <peso xsi:type="xsd:float">5</peso>
                            <unidades xsi:type="xsd:int">1</unidades>
                        </item>
                    </detalle>
                    <usuario xsi:type="xsd:string">edem.cedi11</usuario>
                    <clave xsi:type="xsd:string">665b79613ad78a503106fe44379eb1e897c7cd282f7952fde56f0430b74480fb</clave>
                </p>
            </ser:Guias_generarGuia>
        </soapenv:Body>
    </soapenv:Envelope>'
FROM ordenes o
INNER JOIN [UnoEE].[dbo].[t430_cm_pv_docto] ON f430_notas LIKE '%' + JSON_VALUE(o.orden_obj_origen, '$.orderId') + '%'
INNER JOIN [UnoEE].[dbo].[t460_cm_docto_remision_venta] ON f430_rowid = f460_rowid_pv_docto
INNER JOIN [UnoEE].[dbo].[t461_cm_docto_factura_venta] ON f461_rowid_docto = f460_rowid_docto_factura
INNER JOIN [UnoEE].[dbo].[t350_co_docto_contable] ON f350_rowid = f461_rowid_docto
WHERE 
    o.id_estado = 7
    AND o.intentos <= 3
    AND JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany') = 'Contra-entrega'
    AND ISNULL(o.endpoint, '') != @endpoint;

-- Actualización para otros valores de deliveryCompany
UPDATE o
SET 
    o.id_estado = 8,
    o.intentos = 0,
    o.fecha_creacion = GETDATE(),
    o.orden_obj_destino = null,
	o.endpoint = null
FROM ordenes o
WHERE 
    o.id_estado = 7
    AND o.intentos <= 3
    AND JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany') != 'Contra-entrega';