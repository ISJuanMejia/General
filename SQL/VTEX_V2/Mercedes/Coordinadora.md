# Integración Guías Coordinadora - Mercedes Campuzano (VTEX V2)

Documentación técnica y operativa del proceso de generación de guías con Coordinadora mediante scripts SQL y motor de integración.

---

## 1. Modelo Operativo del Motor de Integración

El motor de integración (código fuente) opera de forma estándar y desacoplada bajo la siguiente regla:

* **Lectura:** Consume registros de la tabla `ordenes` que tengan asignado `endpoint` y `orden_obj_destino`, con `intentos <= 3`.
* **Ejecución:** Envía la petición HTTP/SOAP a Coordinadora con el contenido de `orden_obj_destino`.
* **Éxito (HTTP 200):** Incrementa automáticamente el estado de la orden (`id_estado = id_estado + 1`) y registra la respuesta.
* **Fallo (HTTP != 200 / Error SOAP):** Incrementa el contador de reintentos (`intentos = intentos + 1`) y almacena el error.
* **Control total por SQL:** La selección de registros, construcción de payloads XML, configuración de endpoints, filtros de exclusión y reinicio de reintentos se gestionan **100% mediante SQL**.

---

## 2. Flujo de Estados con Switch de Activación

El flujo cuenta con una variable switch `DECLARE @genera_guia BIT` (en `Coordinadora.sql` e `invoiced.sql`) que permite activar o desactivar la generación de guías sin alterar la lógica de consultas:

### A. Flujo con Guías Activadas (`@genera_guia = 1`)
```
Start Handling VTEX (Estado 4)
             │
             ▼
Factura en Siesa ERP (Estado 5)
             │
             ▼
Generar Guía Coordinadora (Estado 5) ──[Éxito HTTP 200]──► Estado 6
             │ (Marketplaces Externos Bypass)
             ▼
Invoiced VTEX con Tracking (Estado 6) ──[Éxito HTTP 200]──► Estado 7
```

### B. Flujo con Guías Desactivadas (`@genera_guia = 0`)
```
Start Handling VTEX (Estado 4)
             │
             ▼
Factura en Siesa ERP (Estado 5)
             │
             ▼ (Bypass automático en Coordinadora.sql)
Invoiced VTEX sin Guía (Estado 5/6) ──[Éxito HTTP 200]──► Estado 7
```

---

## 3. Matriz de Estados (`dbo.estados_ordenes`)

| `id_estado` | Descripción Oficial | Acción / Responsable |
|:---:|---|---|
| **1** | Tercero por integrar a Siesa ERP | Descarga de orden desde VTEX |
| **2** | Tercero en proceso de integración a Siesa ERP | Conector Siesa Terceros |
| **3** | Pedido por integrar a Siesa ERP | Conector Siesa Pedidos |
| **4** | Pedido integrado a Siesa ERP / Start Handling VTEX | Cambio de estado en VTEX |
| **5** | **Guía Coordinadora por generar (Pre-Invoiced)** | [Coordinadora.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Mercedes/Coordinadora.sql) |
| **6** | **Factura VTEX (Invoiced) por integrar** | [invoiced.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Mercedes/invoiced.sql) |
| **7** | Factura VTEX (Invoiced) integrada exitosamente | Finalización del flujo de factura |
| **8** | Orden finalizada / Despachada | Cierre operativo |
| **9** | Marketplace externo (Bypass Guía Coordinadora) | Órdenes de Falabella, Dafiti, etc. |

---

## 4. Archivos Modificados y Creados

1. **[Coordinadora.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Mercedes/Coordinadora.sql)**:
   - Parámetro `@genera_guia = 1 | 0`.
   - Si `@genera_guia = 0`, transiciona las órdenes de `5` a `6` sin consumir el WebService.
   - Si `@genera_guia = 1`, procesa `id_estado = 5` con bypass de marketplaces ajenos y genera el XML SOAP para el motor.
2. **[invoiced.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Mercedes/invoiced.sql)**:
   - Script consolidado y unificado.
   - Parámetro `@genera_guia = 1 | 0` (determina si lee en estado `6` o `5`).
   - Construye el JSON de facturación para VTEX con datos de tracking/courier si existen.
3. **[estados_ordenes.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Mercedes/estados_ordenes.sql)**:
   - Script DDL y DML (MERGE) para inicializar o actualizar el catálogo de estados en base de datos.
