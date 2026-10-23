# Informe Técnico: Diagnóstico de Reactivación de Pedidos y Duplicidad en Siesa UnoEE

**Empresa:** Pisende  
**Sistema / Plataforma:** VTEX - Siesa UnoEE (Connekta V2)  
**ID Compañía:** 6618 | **ID Sistema:** 167  
**Fecha de Emisión:** 23 de Octubre de 2026  
**Alcance:** Diagnóstico de causa raíz, afectaciones operativas y acciones correctivas por re-ejecución de pedidos de junio en octubre de 2026.

---

## 1. Resumen Ejecutivo

Durante la revisión técnica del flujo de integración entre VTEX y Siesa UnoEE para el cliente Pisende, se identificó la re-ejecución masiva de órdenes históricas originadas en los meses de mayo, junio y julio de 2026. El incidente derivó en la duplicación de pedidos comerciales en el ERP y la reserva duplicada de inventario en bodegas físicas, sin la generación de nuevos recibos de caja.

A partir del análisis forense realizado en la base de datos intermedia `Connekta-Ecommerce-Vtex-Pisende`, las consultas activas en Connekta API y las trazas de VTEX OMS, se determinó la causa raíz y las medidas de remediación requeridas.

---

## 2. Respuestas a los Puntos del Reporte

### 2.1. Causa de la reactivación el 20 de octubre
- **Origen en VTEX OMS:**  
  En la consulta a la API de VTEX (`GET /api/oms/pvt/orders/1638080501854-01`), el pedido evidencia:
  - `creationDate`: `2026-06-08T16:21:56.4243037+00:00`
  - `lastChange`: `2026-10-20T14:50:24.0318383+00:00` (09:50 AM hora Colombia)
  - `status`: `handling` (*"Preparando Entrega"*)
  - `invoicedDate`: `null`
- **Mecanismo de reactivación:**  
  El 20 de octubre se registró una actualización de estado hacia `handling` en VTEX (acción de *Start Handling* / "Iniciar Preparación" en OMS o reproceso general de órdenes pendientes sin facturar).  
  Al actualizarse el atributo `lastChange`, **VTEX insertó automáticamente los eventos correspondientes en el Order Feed (`/api/orders/feed`)**.

### 2.2. Motivo de la nueva ejecución en Connekta
- **Consumo de eventos y reactivación del servicio:**  
  Al reactivarse el servicio de integración en Connekta el 20 de octubre, la tarea `vtex_descargar_ordenes` procesó la cola de eventos del feed.
- **Vulnerabilidad de Idempotencia en `Pedido Por Integrar.sql` (Query ID: 3696):**  
  La consulta que genera el conector de pedidos no cuenta con una validación `NOT EXISTS` contra `t430_cm_pv_docto` de Siesa UnoEE:
  ```sql
  SELECT * INTO #ordenes
  FROM ordenes
  WHERE id_tienda = 1 
    AND id_estado = 4
    AND intentos < 3
  ```
  Al enviar el nodo `Pedidos` con `f430_consec_docto = '1'`, Siesa autogeneró nuevos consecutivos de pedidos de venta en octubre (ej. **`18056`** y **`18057`**), retornando `200 OK`.

### 2.3. Causa de la no generación del Recibo de Caja (RCA)
1. **Estado del ciclo de vida en VTEX:**  
   El Recibo de Caja de Anticipo (`id_estado = 3`, conector `Ecommerce_Recibo_Caja_Anticipo`) opera únicamente en la fase de recaudo inicial (`ready-for-handling`). Al reactivarse en VTEX con estado `handling` (preparación logística posterior al pago), el flujo omitió la etapa de anticipo o se reanudó directamente desde `id_estado = 4` (*Pedido Por Integrar*).
2. **Control contable de Siesa UnoEE:**  
   En Siesa, el conector `Ecommerce_Recibo_Caja_Anticipo` valida el auxiliar contable `280505` y la referencia `f357_referencia = orderId`. Debido a que en junio ya se había liquidado y cruzado dicho recibo de caja contra la factura contable, el ERP no admite la duplicación del cruce.

### 2.4. Afectación y duplicidad identificada
- **Pedidos en Compromiso (`1642160502000-01` y `1642440502010-01`):**  
  Se crearon en Siesa los pedidos duplicados `PED 18056` y `PED 18057`. El conector `Compromiso Por Integrar` (Query ID: 4434) procedió a reservar stock real en bodegas `BDAPG` y `BD001` con lotes vigentes de octubre de 2026 (ej. lote `202610130000002`), generando **doble compromiso de inventario y descuento indebido del saldo disponible**.
- **Pedido Facturado (`1638080501854-01`):**  
  Avanzó a `id_estado = 7` (*Estado Invoiced Por Integrar*) al cruzar con la remisión/factura histórica existente en el ERP.
- **Magnitud del incidente:**  
  Se identificó que **143 pedidos históricos** de mayo a julio fueron reactivados:
  - `id_estado = 6` (Compromiso Por Integrar): 96 órdenes
  - `id_estado = 7` (Invoiced Por Integrar): 18 órdenes
  - `id_estado = 4` (Pedido Por Integrar): 13 órdenes
  - `id_estado = 3` (Anticipo Por Integrar): 2 órdenes

---

## 3. Plan de Acción y Medidas Correctivas

1. **Cierre inmediato de órdenes reactivadas en BD intermedia:**  
   Actualizar a estado terminal (`id_estado = 8`) las órdenes históricas en la base `Connekta-Ecommerce-Vtex-Pisende` para detener llamadas recurrentes a los conectores de Siesa:
   ```sql
   UPDATE ordenes 
   SET id_estado = 8, intentos = 0 
   WHERE id_estado IN (3, 4, 6) 
     AND JSON_VALUE(orden_obj_origen, '$.creationDate') < '2026-09-01';
   ```
2. **Anulación de pedidos duplicados en Siesa UnoEE:**  
   El área de operaciones / cartera de Pisende debe anular los pedidos duplicados generados en octubre (consecutivos `18056`, `18057`, etc.) para liberar los compromisos y restablecer las existencias disponibles de las bodegas.
3. **Idempotencia en `Pedido Por Integrar.sql`:**  
   Añadir en la consulta de pedidos la validación previa contra `t430_cm_pv_docto` de Siesa: si ya existe el pedido por `f430_num_docto_referencia`, no regenerar el conector y avanzar la orden automáticamente.
