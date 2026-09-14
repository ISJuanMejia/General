# Contexto - Creaciones Nadar (Speedo)

## Información General

| Campo | Valor |
|-------|-------|
| **Cliente** | Creaciones Nadar S.A |
| **Marca** | Speedo |
| **Plataforma** | VTEX (Connekta V2) |
| **Base de Datos** | `Connekta-Ecommerce-Vtex` |
| **Servidor BD** | `database-1.copjsjcqn7hc.us-east-1.rds.amazonaws.com` |
| **id_tienda** | `1` |
| **Transportadora Principal** | Coordinadora |

---

## Coordinadora - Datos de Integración

| Campo | Valor |
|-------|-------|
| **Endpoint SOAP** | `http://guias.coordinadora.com/ws/guias/1.6/server.php` |
| **WSDL** | `http://guias.coordinadora.com/ws/guias/1.6/server.php?wsdl` |
| **id_cliente** | `31724` |
| **Usuario WS** | `nadar.ws` |
| **Remitente** | Creaciones Nadar S.A |
| **Dirección Remitente** | CRA 67 # 78 - 280 |
| **Teléfono Remitente** | 6049467 |
| **Ciudad Remitente (DANE)** | 05001000 (Medellín) |

---

## Arquitectura del Flujo de Guías

```
[VTEX] → ImportarOdenes.bat → ordenes (id_estado=5)
                                    ↓
                           guias.sql (arma XML SOAP)
                                    ↓
                           GenerarGuias.bat → Coordinadora API
                                    ↓
                           guias_transportadoras (guía, URL, rótulo)
                                    ↓
                           CambioEstadoStartHandling.bat
                                    ↓
                           CambioEstadoInvoiced.bat
```

### Tabla `ordenes` - Columnas Relevantes

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | INT | PK |
| `id_tienda` | INT | 1 = Speedo |
| `id_estado` | INT | 5 = pendiente de guía |
| `orden_obj_origen` | NVARCHAR(MAX) | JSON completo de la orden VTEX |
| `orden_obj_destino` | NVARCHAR(MAX) | XML SOAP construido para Coordinadora |
| `endpoint` | NVARCHAR | URL del WS de la transportadora |
| `intentos` | INT | Reintentos (máx 3, luego queda atrapada) |
| `fecha_creacion` | DATETIME2 | Se actualiza en cada procesamiento |

### Tabla `guias_transportadoras` - Columnas

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id_orden` | INT | FK a ordenes.id |
| `guia` | NVARCHAR | PDF en Base64 |
| `url` | NVARCHAR | URL de tracking de Coordinadora |
| `remision` | NVARCHAR | Código de remisión (ej: 98462133645) |

---

## Archivos del Proyecto

| Archivo | Descripción |
|---------|-------------|
| `guias.sql` | Construye el XML SOAP para Coordinadora y actualiza `orden_obj_destino` |
| `OrdenEjecucionDeTrabaj.bat` | Orquestador principal: importar → guías → start handling → invoiced |
| `guia.xml` | Template vacío (no se usa activamente) |
| `terceros.sql` | SQL de terceros |
| `Insertar_sku.sql` | Inserción de SKUs |
| `Insertar_especificaciones_variantes.sql` | Inserción de especificaciones de variantes |

---

## Problemas Conocidos

### Órdenes atrapadas en estado 5 con intentos agotados
- **Causa**: Cuando Coordinadora genera la guía pero la respuesta no se procesa correctamente (timeout, error de red), la guía queda registrada en Coordinadora pero no en la BD local. Los reintentos fallan con "llave duplicada" en `codigo_remision`.
- **Solución**: Resetear `intentos = 0` para reprocesar. Si persiste el error de duplicado, verificar en Coordinadora las remisiones existentes.

### Namespace XML sandbox
- **Estado**: Corregido el 2026-09-14. Se cambió de `https://sandbox.coordinadora.com/agw/ws/guias/1.6/server.php` a `http://guias.coordinadora.com/ws/guias/1.6/server.php`.
- **Nota**: Coordinadora ignoraba el namespace incorrecto, pero es técnicamente correcto usar el de producción.

---

*Última actualización: 2026-09-14*
