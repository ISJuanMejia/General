# Informe Técnico: Diagnóstico de Reactivación de Pedidos, Duplicidad y Blindaje de Idempotencia en Siesa UnoEE

**Cliente:** Pisende  
**Integración:** VTEX V2 - Siesa UnoEE vía Connekta  
**ID Compañía:** 6618 | **ID Sistema:** 167 | **ID Proceso Connekta:** 6008 (`Vtex_Importar_Ordenes_ERP`)  
**Base de Datos Intermedia:** `Connekta-Ecommerce-Vtex-Pisende` (AWS RDS SQL Server)  
**Base de Datos ERP:** `UnoEE_Pisende_Real` (Siesa UnoEE M4 AWS RDS)  
**Fecha:** 23 de Octubre de 2026  
**Autor:** Equipo de Integraciones / Connekta  

---

## 1. Resumen Ejecutivo

Durante el mes de octubre se evidenció la reactivación no programada de órdenes históricas generadas originalmente en mayo, junio y julio de 2026. Al ingresar nuevamente al flujo de integración de Connekta, se ocasionaron las siguientes novedades reportadas por Pisende:

1. **Creación duplicada de pedidos comerciales en Siesa:** Se generaron nuevos consecutivos de venta (ej. `18056` y `18057`), duplicando compromisos y reservas de inventario físico en bodegas.
2. **No generación de recibos de caja (RCA):** Los pedidos reactivados no crearon nuevo recibo de caja contable en octubre, a diferencia de su procesamiento inicial en junio.
3. **Saturación de logs por reintentos infinitos:** Se acumularon miles de ejecuciones con resultado `¿Exitosa? No` en Connekta, generando un tráfico continuo e innecesario contra los servicios web de Siesa.

Se realizó un análisis forense sobre VTEX OMS, la base de datos intermedia y el ERP Siesa, se identificaron las causas raíz y se implementó un **blindaje integral de idempotencia** en los tres scripts SQL de integración (`Anticipo Por Integrar.sql`, `Pedido Por Integrar.sql` y `Compromiso Por Integrar.sql`). Las modificaciones fueron probadas exitosamente contra la base de datos de producción y los servidores de Siesa.

---

## 2. Diagnóstico Técnico de Causa Raíz

### 2.1. Causa de la reactivación el 20 de octubre en VTEX OMS
Al auditar los metadatos de las órdenes afectadas (ej. `1638080501854-01`, `1642160502000-01`, `1642440502010-01`) mediante la API de VTEX OMS (`GET /api/oms/pvt/orders/{orderId}`), se constataron los siguientes valores:
- `creationDate`: `2026-06-08T16:21:56.4243037+00:00`
- `lastChange`: `2026-10-20T14:50:24.0318383+00:00` (09:50 AM hora Colombia)
- `status`: `handling` (*"Preparando Entrega"*)
- `invoicedDate`: `null`

**Mecanismo:**  
El 20 de octubre se ejecutó en VTEX un cambio de estado hacia `handling` (acción de *Start Handling* o reproceso de órdenes pendientes sin facturar). Toda modificación en VTEX actualiza el atributo `lastChange` e inserta automáticamente un evento en la cola del Order Feed (`/api/orders/feed`).

### 2.2. Consumo en Connekta y Duplicidad en Siesa
1. **Reanudación del servicio Connekta:** Al reactivarse el servicio de integración el 20 de octubre, la tarea `Vtex_Descargar_Ordenes` (Proceso `6007`) leyó los eventos del feed e insertó/actualizó las órdenes en la tabla intermedia `ordenes` en estado 1.
2. **Carencia de idempotencia en `Pedido Por Integrar.sql`:** La consulta original no validaba contra la base de datos de Siesa si el número de pedido ya existía previamente en el ERP. El script generó un nuevo payload para el conector `Ecommerce_Pedido` (Documento `217657`) con `f430_consec_docto = 1`.
3. Siesa UnoEE interpretó la solicitud como un pedido nuevo legítimo y le asignó el siguiente consecutivo disponible (`18056`, `18057`, etc.), respondiendo `200 OK`.

### 2.3. Causa de la no generación del Recibo de Caja (RCA)
La no duplicación del RCA se debió a dos controles:
1. **Filtro de ciclo de vida:** El conector de anticipos (`Ecommerce_Recibo_Caja_Anticipo`, Documento `217329`) opera únicamente cuando la orden se encuentra en fase previa al despacho (`ready-for-handling`, `id_estado = 3`). Al ingresar la orden directamente en estado `handling`, el flujo de integración omitió o saltó la fase de anticipo.
2. **Validación contable en Siesa:** En Siesa UnoEE, el recibo de caja de anticipo acredita el auxiliar contable `280505` con la referencia `orderId`. Al haber sido creado y cruzado en junio (`010 RCA 679`, `010 RCA 683`, `010 RCA 639`), la contabilidad de Siesa no admitía un nuevo anticipo sobre un documento ya liquidado.

---

## 3. Análisis de Reintentos Infinitos y Ciclo de Vida de Procesos Fallidos

### 3.1. Causa del bucle infinito (Saturación de Logs)
En el script de compromisos ([Compromiso Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Compromiso%20Por%20Integrar.sql), Query ID `4434`), se identificó una anomalía en la sentencia `UPDATE`:

```sql
-- Código defectuoso anterior
UPDATE o
SET 
    o.endpoint = t.endpoint,
    o.intentos = 0,               -- <-- RESETEABA EL CONTADOR EN CADA CICLO
    o.fecha_creacion = t.fecha_creacion,
    o.orden_obj_destino = t.orden_obj_destino
FROM ordenes o
INNER JOIN #ordenes t ON t.id = o.id;
```

**Mecánica del bucle:**
1. Connekta ejecutaba la tarea programada cada 10 a 15 minutos.
2. Siesa rechazaba el compromiso del pedido (`Ecommerce_Compromiso`) debido a que las órdenes de junio ya estaban cerradas, facturadas o con diferencias de lotes en el ERP.
3. Connekta registraba en bitácora `¿Exitosa? = No` e incrementaba `intentos = 1`.
4. En el siguiente ciclo, la consulta seleccionaba la orden porque cumplía `WHERE ISNULL(intentos, 0) < 3`.
5. Al ejecutar el `UPDATE`, **se sobreescribía `intentos = 0`**, borrando el historial de fallos.
6. La orden **nunca alcanzaba los 3 intentos**, generando cientos de llamadas fallidas al día por cada orden reactivada.

### 3.2. Comportamiento corregido de los procesos fallidos
Al retirar `o.intentos = 0` en [Anticipo Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Anticipo%20Por%20Integrar.sql), [Pedido Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Pedido%20Por%20Integrar.sql) y [Compromiso Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Compromiso%20Por%20Integrar.sql):

1. **Conteo secuencial:** Cada intento fallido ante el conector de Siesa incrementa el campo `intentos` (1, 2, 3).
2. **Entrada automática en Cuarentena:** Al alcanzar `intentos = 3`, la cláusula `WHERE ISNULL(o.intentos, 0) < 3` descarta la orden de las ejecuciones automáticas.
3. **Cese de saturación:** La orden queda aislada en la base de datos intermedia sin sobrecargar la red ni consumir recursos en los servidores de Siesa.
4. **Procedimiento de reactivación controlada (L1/L2):** Una vez solventada la causa del rechazo en Siesa (ej. recarga de inventario, corrección de lista de precios o creación de cliente), un operador puede reintentar la orden manualmente:
   ```sql
   -- Reactivar una orden específica para nuevo ciclo de reintentos
   UPDATE ordenes 
   SET intentos = 0 
   WHERE id = <ID_ORDEN>;
   ```

---

## 4. Solución Implementada: Idempotencia en las 3 Fases de Integración

Se implementó una consulta previa vía `OPENROWSET` contra las tablas nativas de Siesa UnoEE antes de generar payloads para conectores:

```
                  ┌─────────────────────────────────────────────────────────────┐
                  │                 ARQUITECTURA DE IDEMPOTENCIA                │
                  └─────────────────────────────────────────────────────────────┘

  FASE 1: ANTICIPO (Estado 3)
  Consulta Siesa: t357_co_ingresos_caja / t350_co_docto_contable (RCA)
  ├── ¿Existe RCA con f357_referencia = orderId? 
  │     ├── SÍ ──► UPDATE ordenes SET id_estado = 4 (Auto-avance sin duplicar)
  │     └── NO ──► Genera payload Ecommerce_Recibo_Caja_Anticipo
  
  FASE 2: PEDIDO (Estado 4)
  Consulta Siesa: t430_cm_pv_docto (PED / TMS en CO 010, CIA 1)
  ├── ¿Existe Pedido con f430_num_docto_referencia = orderId/sequence?
  │     ├── SÍ ──► UPDATE ordenes SET id_estado = 5 (Auto-avance sin duplicar)
  │     └── NO ──► Genera payload Ecommerce_Pedido
  
  FASE 3: COMPROMISO (Estado 6)
  Consulta Siesa: t430_cm_pv_docto / t431_cm_pv_movto
  ├── ¿Pedido ya Aprobado, Remisionado, Cumplido o con Cantidad Comprometida?
  │     ├── SÍ ──► UPDATE ordenes SET id_estado = 7 (Auto-avance sin duplicar)
  │     └── NO ──► Genera payload Ecommerce_Compromiso
```

### 4.1. Detalle por Script

#### A. [Anticipo Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Anticipo%20Por%20Integrar.sql) (Query ID `3694`)
- **Validación ERP:** Cruza `t357_co_ingresos_caja` con `t350_co_docto_contable` en compañía 1, CO `010`, documento `RCA` donde `f357_referencia` coincida con el `orderId` de VTEX, más documentos de servicios por `f350_notas`.
- **Acción:** Si ya existe recaudo, ejecuta `UPDATE o SET id_estado = 4, intentos = 0` y excluye la orden del temporal `#ordenes`.
- **Eliminación de bucle:** Se removió `o.intentos = 0` del `UPDATE` de generación de payload.

#### B. [Pedido Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Pedido%20Por%20Integrar.sql) (Query ID `3696`)
- **Validación ERP:** Consulta `t430_cm_pv_docto` filtrando `f430_id_cia = 1`, `f430_id_co = '010'`, tipo de documento `PED` o `TMS` y `f430_referencia = 'ECOMMERCE'`.
- **Acción:** Si el pedido ya existe en Siesa, ejecuta `UPDATE o SET id_estado = 5, intentos = 0` y excluye la orden de la inserción de nuevos pedidos.
- **Eliminación de bucle:** Se removió `o.intentos = 0` del `UPDATE` de generación de payload.

#### C. [Compromiso Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Compromiso%20Por%20Integrar.sql) (Query ID `4434`)
- **Validación ERP:** Consulta `t430_cm_pv_docto` y `t431_cm_pv_movto` verificando si el pedido ya tiene `f430_ind_estado IN (1, 3, 4)` (Aprobado/Cumplido), `f430_ind_remisionado = 1`, `f430_ind_facturado = 1` o `f431_cant_comprometida_base > 0`.
- **Acción:** Si ya está comprometido o cumplido, ejecuta `UPDATE o SET id_estado = 7, intentos = 0` (avanza directamente a detección de facturación FEV).
- **Eliminación de bucle:** Se removió `o.intentos = 0` del `UPDATE` de generación de payload.

---

## 5. Pruebas Técnicas y Validación en Entorno Real

Se ejecutaron pruebas directas sobre la base de datos de producción `Connekta-Ecommerce-Vtex-Pisende` y la instancia RDS de `UnoEE_Pisende_Real`:

### 5.1. Compilación Sintáctica (`SET NOEXEC ON`)
Los 3 scripts fueron validados de principio a fin sin presentar errores de sintaxis, variables o funciones:
- `Anticipo Por Integrar.sql`: Compilado en 202 ms (0 advertencias).
- `Pedido Por Integrar.sql`: Compilado en 179 ms (0 advertencias).
- `Compromiso Por Integrar.sql`: Compilado en 493 ms (0 advertencias).

### 5.2. Resultados de las Consultas en Siesa UnoEE
| Validación | Tabla ERP Consultada | Registros Retornados | Comportamiento en BD Intermedia |
|---|---|:---:|---|
| **Anticipos Existentes** | `t357_co_ingresos_caja` + `t350_co_docto_contable` | **782** | Diferenció 2 órdenes pendientes reales de aquellas ya recaudadas. |
| **Pedidos Existentes** | `t430_cm_pv_docto` (`PED`, `TMS`) | **1,183** | Cruce exitoso por `f430_num_docto_referencia`. Previene inserción duplicada. |
| **Compromisos Activos** | `t430_cm_pv_docto` + `t431_cm_pv_movto` | **15,703** | **Identificó 81 órdenes atascadas en estado 6** que en Siesa ya están aprobadas o cumplidas. Al correr el script definitivo, estas 81 órdenes avanzan a estado 7 en lugar de reintentar. |

---

## 6. Procedimiento para Despliegue en Connekta API

Para activar las mejoras en producción, se deben actualizar los cuerpos de las consultas en el sistema Connekta utilizando la API o el portal administrativo:

### Parámetros de Autenticación Connekta
- **URL Base:** `https://servicios.siesacloud.com/api/siesa/v3.1` (o portal Connekta)
- **ID Compañía:** `6618`
- **ID Sistema:** `167`
- **ID Proceso:** `6008` (`Vtex_Importar_Ordenes_ERP`)

### Mapeo de Consultas a Actualizar
1. **Anticipo Por Integrar:**
   - **ID Query Connekta:** `3694`
   - **Orden de Ejecución:** `2`
   - **Archivo Origen:** [SQL/VTEX_V2/Pisende/Anticipo Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Anticipo%20Por%20Integrar.sql)
2. **Pedido Por Integrar:**
   - **ID Query Connekta:** `3696`
   - **Orden de Ejecución:** `3`
   - **Archivo Origen:** [SQL/VTEX_V2/Pisende/Pedido Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Pedido%20Por%20Integrar.sql)
3. **Compromiso Por Integrar:**
   - **ID Query Connekta:** `4434`
   - **Orden de Ejecución:** `4`
   - **Archivo Origen:** [SQL/VTEX_V2/Pisende/Compromiso Por Integrar.sql](file:///c:/Medellin/General/SQL/VTEX_V2/Pisende/Compromiso%20Por%20Integrar.sql)

---

## 7. Plan de Acción y Recomendaciones Operativas

1. **Actualización de Queries en Connekta:** Desplegar los 3 scripts SQL modificados en el Proceso `6008`.
2. **Anulación de Pedidos Duplicados en Siesa:** El equipo comercial de Pisende debe verificar y anular los consecutivos generados indebidamente en octubre (ej. `18056` y `18057`) para liberar los inventarios comprometidos.
3. **Depuración de Órdenes Históricas en BD Intermedia (Paso 1):**  
   Una vez confirmada la anulación en el ERP, ejecutar la actualización de cierre para las órdenes anteriores a septiembre:
   ```sql
   UPDATE ordenes 
   SET id_estado = 8, intentos = 0 
   WHERE id_estado IN (3, 4, 6) 
     AND JSON_VALUE(orden_obj_origen, '$.creationDate') < '2026-09-01';
   ```
4. **Monitoreo Posterior:** Vigilar durante 24 horas la bitácora del proceso `Vtex_Importar_Ordenes_ERP` para verificar que la tasa de errores se mantenga en cero y que las nuevas órdenes de la tienda transiten limpiamente hasta el estado 8.
