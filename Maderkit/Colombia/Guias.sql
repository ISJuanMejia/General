DECLARE @endpoint NVARCHAR(500) = 'http://guias.coordinadora.com/ws/guias/1.6/server.php';
 
--GENERAL
DECLARE @fecha              VARCHAR(10)     =   FORMAT(GETDATE(), 'yyyy-MM-dd')
DECLARE @valor_declarado    INT             =   30000;
 
/*
	Declara una variable para especificar el tipo de código de cuenta para el envío:
	1   - Cuenta corriente
	2   - Acuerdo semanal
	3   - Flete pago
*/
DECLARE @codigo_cuenta  INT             =   1;
   
/*
	Declara una variable para especificar el tipo de código de producto para el envío:
	0   ->  Auto, se determina automaticamente a partir del detalle de la guia
	1   ->  Mercancia
	2   ->  Paquetes de 1-2 Kg
	3   ->  Documentos
	6   ->  Paquetes de 3-5 Kg
*/
DECLARE @codigo_producto    INT             =   0;
 
/*
    *   Declara una variable para especificar el tipo de nivel de servicio para el envío:
    *       1   ->  Estándar
    *       2   ->  Express
    *       3   ->  Programado
*/
DECLARE @nivel_servicio INT             =   1;
DECLARE @contenido      VARCHAR(255)    =   'Mobiliario';
DECLARE @observaciones  VARCHAR(255)    =   'Maderkit';
 
/*
    Declara una variable para especificar el estado para la generación de la guía:
    PENDIENTE   ->  Se registra la guia, no se genera el codigo remision ni se genera el PDF.
    IMPRESO     ->  Se registra la guia, se genera el codigo remision y el PDF.
*/
DECLARE @estado     VARCHAR(10)     =   'IMPRESO';
DECLARE @usuario    VARCHAR(255)    =   'maderkit.ws'; -->
DECLARE @clave      VARCHAR(255)    =   'a2fc2475d64464e8149cb66d2757c06bc04534e12d34ac274f74da36bfc2d0bb';
 
--REMITENTE
DECLARE @id_cliente             INT             =   20482;
DECLARE @id_remitente           INT             =   0;
DECLARE @nit_remitente          VARCHAR(10)     =   '815001802';
DECLARE @nombre_remitente       VARCHAR(255)    =   'Maderkit S.A.';
DECLARE @direccion_remitente    VARCHAR(255)    =   'Carrera 25A 13-130 Arroyohondo';
DECLARE @telefono_remitente     VARCHAR(15)     =   '6954555';
DECLARE @ciudad_remitente       VARCHAR(255)    =   '76892000'; --> * Yumbo (Valle del Cauca)
 
-- DESTINATARIO
DECLARE @div_destinatario   VARCHAR(255)    =   '01';
 
--DETALLE GUÍA
DECLARE @ubl        INT =   1;
-- DECLARE @alto       INT =   4;
-- DECLARE @ancho      INT =   50;
-- DECLARE @largo      INT =   50;
DECLARE @peso       INT =   3;
DECLARE @unidades   INT =   1;
 
DECLARE @peso_total FLOAT;
DECLARE @unidades_total INT;

SELECT
    @peso_total =SUM((CAST(JSON_VALUE(i.value, '$.additionalInfo.dimension.weight') AS FLOAT) / 1000)* CAST(JSON_VALUE(i.value, '$.quantity') AS FLOAT)),
    @unidades_total =SUM(CAST(JSON_VALUE(i.value, '$.quantity') AS INT))
FROM ordenes o
CROSS APPLY OPENJSON(o.orden_obj_origen, '$.items') i
WHERE o.id in (1135,1136);


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
                        <id_cliente xsi:type="xsd:int">' + CAST(@id_cliente AS VARCHAR(20)) + '</id_cliente>
                        <id_remitente xsi:type="xsd:int">' + CAST(@id_remitente AS VARCHAR(20)) + '</id_remitente>
                        <nombre_remitente xsi:type="xsd:string">' + @nombre_remitente + '</nombre_remitente>
                        <direccion_remitente xsi:type="xsd:string">' + @direccion_remitente + '</direccion_remitente>
                        <telefono_remitente xsi:type="xsd:string">' + @telefono_remitente + '</telefono_remitente>
                        <ciudad_remitente xsi:type="xsd:string">' + @ciudad_remitente + '</ciudad_remitente>
                        <nit_destinatario xsi:type="xsd:string">' + JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.document') + '</nit_destinatario>
                        <div_destinatario xsi:type="xsd:string">' + @div_destinatario + '</div_destinatario>
                        <nombre_destinatario xsi:type="xsd:string">'+ CONCAT(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.firstName'),' ',JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.lastName'))+ '</nombre_destinatario>
                        <direccion_destinatario xsi:type="xsd:string">'+ CONCAT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.street'),' ',JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.neighborhood'))+ '</direccion_destinatario>
                        <ciudad_destinatario xsi:type="xsd:string">'+ CONCAT(JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.postalCode'),'000')+ '</ciudad_destinatario>
                        <telefono_destinatario xsi:type="xsd:string">'+ REPLACE(JSON_VALUE(o.orden_obj_origen, '$.clientProfileData.phone'),'+57','')+ '</telefono_destinatario>
                        <valor_declarado xsi:type="xsd:float">' + JSON_VALUE(o.orden_obj_origen, '$.totals[0].value') + '</valor_declarado>
                        <codigo_cuenta xsi:type="xsd:int">' + CAST(@codigo_cuenta AS VARCHAR(10)) + '</codigo_cuenta>
                        <codigo_producto xsi:type="xsd:int">' + CAST(@codigo_producto AS VARCHAR(10)) + '</codigo_producto>
                        <nivel_servicio xsi:type="xsd:int">' + CAST(@nivel_servicio AS VARCHAR(10)) + '</nivel_servicio>
                        <contenido xsi:type="xsd:string">'+ LEFT((SELECT STRING_AGG(CONCAT(JSON_VALUE(i.value, '$.name'),' (',JSON_VALUE(i.value, '$.refId'),')'),', ')FROM OPENJSON(o.orden_obj_origen, '$.items') i),100)+ '</contenido>
                        <referencia xsi:type="xsd:string">' + JSON_VALUE(o.orden_obj_origen, '$.orderId') + '</referencia>
                        <observaciones xsi:type="xsd:string">' + LEFT (JSON_VALUE(o.orden_obj_origen, '$.shippingData.address.complement'),100) + '</observaciones>
                        <estado xsi:type="xsd:string">' + @estado + '</estado>
                        <detalle SOAP-ENC:arrayType="ns1:Agw_typeGuiaDetalle[1]" xsi:type="ns1:ArrayOfAgw_typeGuiaDetalle">
							<item xsi:type="ns1:Agw_typeGuiaDetalle">
								<ubl xsi:type="xsd:int">0</ubl>
								<alto xsi:type="xsd:float">1</alto>
								<ancho xsi:type="xsd:float">1</ancho>
								<largo xsi:type="xsd:float">1</largo>
								<peso xsi:type="xsd:float">' + CAST(@peso_total AS VARCHAR(20)) + '</peso>
								<unidades xsi:type="xsd:int">' + CAST(@unidades_total AS VARCHAR(10)) + '</unidades>
							</item>
						</detalle>
                        <usuario xsi:type="xsd:string">' + @usuario + '</usuario>
                        <clave xsi:type="xsd:string">' + @clave + '</clave>
                    </p>
                </ser:Guias_generarGuia>
            </soapenv:Body>
        </soapenv:Envelope>'
FROM ordenes o
INNER JOIN (
    SELECT
        f430_notas,
        f350_id_co,
        f350_id_tipo_docto,
        f350_consec_docto
    FROM OPENROWSET(
        'SQLNCLI',
        'Server=ec2-52-6-38-24.compute-1.amazonaws.com;Database=UnoEE_Maderkit_Pruebas;UID=Maderkit;PWD=Maderkit$12$%',
        'SELECT
            t430.f430_notas,
            t350.f350_id_co,
            t350.f350_id_tipo_docto,
            t350.f350_consec_docto
         FROM [t430_cm_pv_docto] t430
         INNER JOIN [t460_cm_docto_remision_venta] t460
            ON t430.f430_rowid = t460.f460_rowid_pv_docto
         INNER JOIN [t461_cm_docto_factura_venta] t461
            ON t461.f461_rowid_docto = t460.f460_rowid_docto_factura
         INNER JOIN [t350_co_docto_contable] t350
            ON t350.f350_rowid = t461.f461_rowid_docto
         WHERE t430.f430_id_cia = 1'
    )
) unoee ON unoee.f430_notas LIKE '%' + JSON_VALUE(o.orden_obj_origen, '$.orderId') + '%'
WHERE o.id in (1135,1136)
    --o.id_estado = 7
    --AND o.intentos <= 3
    --AND JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany') = 'Contra-entrega'
    --AND ISNULL(o.endpoint, '') != @endpoint;
 
-- Actualización para otros valores de deliveryCompany
UPDATE o
SET 
    o.id_estado = 6,
    o.intentos = 0,
    o.fecha_creacion = GETDATE(),
    o.orden_obj_destino = null,
	o.endpoint = null
FROM ordenes o
WHERE 
	id in (1135,1136)
    --o.id_estado = 7
    --AND o.intentos <= 3
    --AND JSON_VALUE(o.orden_obj_origen, '$.shippingData.logisticsInfo[0].deliveryCompany') != 'Contra-entrega';