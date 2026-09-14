# Colección Postman - Coordinadora (Creaciones Nadar / Speedo)

## 1. Generar Guía (Simular Error de Connekta)

### Configuración del Request
- **Method:** `POST`
- **URL:** `http://guias.coordinadora.com/ws/guias/1.6/server.php`

### Headers
| Key | Value |
|---|---|
| `Content-Type` | `text/xml; charset=utf-8` |
| `SOAPAction` | `http://guias.coordinadora.com/ws/guias/1.6/server.php/Guias_generarGuia` |

### Body (`raw` -> `XML`)
```xml
<soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
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
                <nit_destinatario xsi:type="xsd:string">1019079506</nit_destinatario>
                <div_destinatario xsi:type="xsd:string"></div_destinatario>
                <nombre_destinatario xsi:type="xsd:string">Cristhian Sabogal caceres</nombre_destinatario>
                <direccion_destinatario xsi:type="xsd:string">Carrera11#112-65 Apto 104 edificio Marielena Santa Bárbara</direccion_destinatario>
                <ciudad_destinatario xsi:type="xsd:string">11001000</ciudad_destinatario>
                <telefono_destinatario xsi:type="xsd:string">3163253613</telefono_destinatario>
                <valor_declarado xsi:type="xsd:float">50000</valor_declarado>
                <codigo_cuenta xsi:type="xsd:int">1</codigo_cuenta>
                <codigo_producto xsi:type="xsd:int">0</codigo_producto>
                <nivel_servicio xsi:type="xsd:int">1</nivel_servicio>
                <contenido xsi:type="xsd:string">Prendas</contenido>
                <referencia xsi:type="xsd:string">1661560913233-01</referencia>
                <observaciones xsi:type="xsd:string">Entregar a: Cristhian Sabogal caceres</observaciones>
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
</soapenv:Envelope>
```

---

## 2. Reimprimir Guía (Consultar PDF existente)

### Configuración del Request
- **Method:** `POST`
- **URL:** `http://guias.coordinadora.com/ws/guias/1.6/server.php`

### Headers
| Key | Value |
|---|---|
| `Content-Type` | `text/xml; charset=utf-8` |
| `SOAPAction` | `http://guias.coordinadora.com/ws/guias/1.6/server.php/Guias_reimprimirGuia` |

### Body (`raw` -> `XML`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
                  xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
                  xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
                  xmlns:ser="http://guias.coordinadora.com/ws/guias/1.6/server.php">
    <soapenv:Header/>
    <soapenv:Body>
        <ser:Guias_reimprimirGuia soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <p xsi:type="ser:Agw_typeReimprimirGuiaIn">
                <codigo_remision xsi:type="xsd:string">98462133644</codigo_remision>
                <id_empresa xsi:type="xsd:int">31724</id_empresa>
                <id_archivo xsi:type="xsd:int">0</id_archivo>
                <tipo xsi:type="xsd:string"></tipo>
                <usuario xsi:type="xsd:string">nadar.ws</usuario>
                <clave xsi:type="xsd:string">12d4e17e84824698dc0b18206ba7911c61551cf0d4c11cc5e6025b15a9e31cea</clave>
            </p>
        </ser:Guias_reimprimirGuia>
    </soapenv:Body>
</soapenv:Envelope>
```
