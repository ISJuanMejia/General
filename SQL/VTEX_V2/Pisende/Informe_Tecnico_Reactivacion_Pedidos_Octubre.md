# Informe Técnico: Diagnóstico de Reactivación de Pedidos, Duplicidad y Blindaje de Idempotencia en Siesa UnoEE

**Empresa:** Pisende  
**Sistema / Plataforma:** VTEX - Siesa UnoEE (Connekta V2)  
**ID Compañía:** 6618 | **ID Sistema:** 167  
**Fecha de Emisión:** 23 de Octubre de 2026  
**Alcance:** Diagnóstico de causa raíz, afectaciones operativas, análisis de reintentos infinitos, blindaje integral en consultas SQL y gestión de procesos fallidos.

---

## 1. Resumen Ejecutivo

Durante la revisión técnica del flujo de integración entre VTEX y Siesa UnoEE para el cliente Pisende, se identificó la re-ejecución masiva de órdenes históricas originadas en los meses de mayo, junio y julio de 2026. El incidente derivó en la duplicación de pedidos comerciales en el ERP y la reserva duplicada de inventario en bodegas físicas, sin la generación de nuevos recibos de caja.

Adicionalmente, se detectó una saturación de logs con miles de ejecuciones fallidas en Connekta (`¿Exitosa? No`), provocada por un bucle infinito en el conector de compromisos.

A partir del análisis técnico en la base de datos intermedia `Connekta-Ecommerce-Vtex-Pisende`, las consultas activas en Connekta API y las trazas de VTEX OMS, se determinó la causa raíz y se implementó un **blindaje integral de idempotencia** en todas las fases del flujo (Anticipos, Pedidos y Compromisos).

---

## 2. Diagnóstico de Causa Raíz

### 2.1. Causa de la reactivación el 20 de octubre
- **Origen en VTEX OMS:**  
  En la consulta a la API de VTEX (`GET /api/oms/pvt/orders/1638080501854-01`), el pedido evidenciaba:
  - `creationDate`: `2026-06-08T16:21:56.4243037+00:00`
  - `lastChange`: `2026-10-20T14:50:24.0318383+00:00` (09:50 AM hora Colombia)
  - `status`: `handling` (*"Preparando Entrega"*)
  - `invoicedDate`: `null`
- **Mecanismo de reactivación:**  
  El 20 de octubre se registró una actualización de estado hacia `handling` en VTEX (acción de *Start Handling* / "Iniciar Preparación" en OMS o reproceso general de órdenes pendientes sin facturar). Al actualizarse el atributo `lastChange`, **VTEX insertó automáticamente los eventos correspondientes en el Order Feed (`/api/orders/feed`)**.

### 2.2. Causa de la re-ejecución en Connekta y Duplicidad en Siesa
- **Consumo de eventos y reactivación del servicio:**  
  Al reactivarse el servicio de integración en Connekta el 20 de octubre, la tarea `vtex_descargar_ordenes` procesó la cola de eventos del feed.
- **Falta de Idempotencia en `Pedido Por Integrar.sql`:**  
  La consulta que genera el conector de pedidos no contaba con una validación `NOT EXISTS` contra `t430_cm_pv_docto` de Siesa UnoEE. Al enviar el nodo `Pedidos` con `f430_consec_docto = '1'`, Siesa autogeneró nuevos consecutivos de pedidos de venta en octubre (ej. **`18056`** y **`18057`**), retornando `200 OK`.

### 2.3. Causa de la no generación del Recibo de Caja (RCA)
1. **Estado del ciclo de vida en VTEX:**  
   El Recibo de Caja de Anticipo (`id_estado = 3`, conector `Ecommerce_Recibo_Caja_Anticipo`) opera únicamente en la fase de recaudo inicial (`ready-for-handling`). Al reactivarse en VTEX con estado `handling` (preparación logística posterior al pago), el flujo omitió la etapa de anticipo o se reanudó directamente desde `id_estado = 4` (*Pedido Por Integrar*).
2. **Control contable de Siesa UnoEE:**  
   En Siesa, el conector `Ecommerce_Recibo_Caja_Anticipo` valida el auxiliar contable `280505` y la referencia `f357_referencia = orderId`. Debido a que en junio ya se había liquidado y cruzado dicho recibo de caja contra la factura contable, el ERP no admitió la duplicación del cruce.

---

## 3. Análisis de Procesos Fallidos y Bucle Infinito de Reintentos

### 3.1. ¿Por qué se procesaron los pedidos tantas veces? (Saturación de Logs)
En el script [Compromiso Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Compromiso%20Por%20Integrar.sql):
- El query seleccionaba órdenes con: `WHERE id_estado = 6 AND intentos < 3`.
- Sin embargo, en el UPDATE final existía la instrucción:
  ```sql
  UPDATE o
  SET 
      o.endpoint = t.endpoint,
      o.intentos = 0,               -- Bucle Infinito
      o.fecha_creacion = t.fecha_creacion,
      o.orden_obj_destino = t.orden_obj_destino
  ...
  ```
- **Mecánica del bucle:**
  1. Connekta ejecutaba la tarea programada cada 10-15 minutos.
  2. Siesa rechazaba el compromiso (`Ecommerce_Compromiso`) debido a que las órdenes de junio ya estaban facturadas o cerradas en el ERP, o por saldos de lotes.
  3. Connekta marcaba `¿Exitosa? = No` y aumentaba `intentos = 1`.
  4. En la siguiente ejecución, el query seleccionaba la orden ($1 < 3$), pero **el UPDATE volvía a setear `intentos = 0`**.
  5. La orden **nunca alcanzaba los 3 intentos para ser descartada**, disparando llamadas perpetuas a la API de Siesa (más de 400 llamadas fallidas por hora para las 97 órdenes reactivadas).

### 3.2. ¿Qué sucede con los procesos fallidos al corregir el script?
Con la eliminación de `o.intentos = 0`:
1. **Tope estricto de reintentos:** Cuando una orden falla en Siesa, Connekta incrementa `intentos` secuencialmente (1, 2, 3).
2. **Entrada en Cuarentena:** Al alcanzar `intentos = 3`, la condición `WHERE ISNULL(intentos, 0) < 3` evalúa a falso. La consulta **deja de seleccionar la orden**.
3. **Aislamiento seguro:** La orden queda congelada en su estado actual sin saturar la base de datos ni los servicios de Siesa.
4. **Desbloqueo controlado:** Si un fallo es temporal (ej. falta de inventario o caída de conexión), un operador puede corregir la causa en Siesa y reiniciar los reintentos ejecutando `UPDATE ordenes SET intentos = 0 WHERE id = <ID>` de forma controlada.

---

## 4. Blindaje de Idempotencia Implementado

Para evitar de manera definitiva la duplicidad en cualquier reactivación futura, se blindaron los 3 queries del flujo de integración hacia Siesa:

### 4.1. Anticipos: [Anticipo Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Anticipo%20Por%20Integrar.sql)
- **Validación previa en Siesa:** Consulta mediante `OPENROWSET` los documentos `RCA` en `t357_co_recaudos` / `t350_co_docto_contable` (por referencia `orderId`) y las notas de crédito de servicios (Addi, Sistecrédito, Servicrédito).
- **Avance automático:** Si el anticipo ya existe en Siesa, actualiza directamente la orden a **`id_estado = 4`** (*Pedido Por Integrar*).
- **Exclusión:** Solo construye payload para órdenes que verdaderamente no tengan recaudo en Siesa.
- **Control de reintentos:** Se eliminó `o.intentos = 0` del UPDATE final.

### 4.2. Pedidos: [Pedido Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Pedido%20Por%20Integrar.sql)
- **Validación previa en Siesa:** Consulta en `t430_cm_pv_docto` si ya existe un documento `PED` o `TMS` en centro de operación `010` con la referencia `f430_num_docto_referencia`.
- **Avance automático:** Si el pedido ya existe en Siesa, actualiza directamente la orden a **`id_estado = 5`** (*Start Handling Por Integrar*).
- **Exclusión:** La inserción al temporal `#ordenes` filtra con `LEFT JOIN ... WHERE f430_num_docto_referencia IS NULL`.
- **Control de reintentos:** Se eliminó `o.intentos = 0` del UPDATE final.

### 4.3. Compromisos: [Compromiso Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Compromiso%20Por%20Integrar.sql)
- **Validación previa en Siesa:** Consulta en `t430_cm_pv_docto` si el pedido ya se encuentra en estados aprobados/cumplidos (`f430_ind_estado IN (1, 3, 4)`), o si ya está remisionado (`f430_ind_remisionado = 1`), facturado (`f430_ind_facturado = 1`), o con movimientos comprometidos en `t431_cm_pv_movto`.
- **Avance automático:** Si el compromiso ya fue generado o el pedido ya fue aprobado/cumplido, actualiza directamente la orden a **`id_estado = 7`** (*Estado Invoiced Por Integrar*).
- **Exclusión:** `#ordenes` solo procesa pedidos que realmente estén pendientes de comprometer y tengan `ISNULL(intentos, 0) < 3`.
- **Control de reintentos:** Se eliminó `o.intentos = 0` del UPDATE final.

---

## 5. Matriz del Flujo Blindado (Idempotente)

```
[Orden en VTEX]
       │
       ▼
 [id_estado = 1: Orden Descargada]
       │
       ▼ (Terceros.sql)
 [id_estado = 2: Tercero Por Integrar] ───(200 OK Siesa)───► [id_estado = 3]
                                                                  │
 ┌────────────────────────────────────────────────────────────────┘
 │
 ▼
[id_estado = 3: Anticipo Por Integrar]
 ├─► ¿Existe RCA / Recaudo en Siesa? ──(SÍ)──► Auto-avance a [id_estado = 4]
 └─► (NO) ──► Envía RCA a Siesa ──(200 OK)──► [id_estado = 4]
                                                    │
 ┌──────────────────────────────────────────────────┘
 │
 ▼
[id_estado = 4: Pedido Por Integrar]
 ├─► ¿Existe Pedido en Siesa t430? ────(SÍ)──► Auto-avance a [id_estado = 5]
 └─► (NO) ──► Envía Pedido a Siesa ──(200 OK)► [id_estado = 5]
                                                    │
 ┌──────────────────────────────────────────────────┘
 │
 ▼
[id_estado = 5: Start Handling Por Integrar]
 └─► Notifica Start Handling a VTEX ──(200 OK)► [id_estado = 6]
                                                    │
 ┌──────────────────────────────────────────────────┘
 │
 ▼
[id_estado = 6: Compromiso Por Integrar]
 ├─► ¿Ya Comprometido / Cumplido en Siesa? ─(SÍ)─► Auto-avance a [id_estado = 7]
 └─► (NO) ──► Envía Compromiso a Siesa ──(200 OK)► [id_estado = 7]
                                                        │
 ┌──────────────────────────────────────────────────────┘
 │
 ▼
[id_estado = 7: Invoiced Por Integrar]
 └─► Detecta Factura FEV en Siesa ──► Envía Factura a VTEX ──► [id_estado = 8: Finalizado]
```

---

## 6. Acciones Operativas Pendientes en Siesa UnoEE

1. **Anulación de Pedidos Duplicados:**  
   El área de cartera y logística de Pisende debe anular los pedidos duplicados generados en octubre (ej. consecutivos `18056`, `18057`, etc.) para liberar los saldos comprometidos indebidamente en las bodegas `BD001` y `BDAPG`.
2. **Cierre de órdenes históricas en BD intermedia (Paso 1):**  
   Cuando se autorice, pasar a `id_estado = 8` las órdenes de mayo a julio para limpiar completamente la cola:
   ```sql
   UPDATE ordenes 
   SET id_estado = 8, intentos = 0 
   WHERE id_estado IN (3, 4, 6) 
     AND JSON_VALUE(orden_obj_origen, '$.creationDate') < '2026-09-01';
   ```
