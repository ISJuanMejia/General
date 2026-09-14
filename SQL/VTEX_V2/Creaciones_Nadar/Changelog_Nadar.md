# Changelog - Creaciones Nadar (Speedo)

---

## [2026-09-14] Diagnóstico, desbloqueo y reprocesamiento de guías Coordinadora

### Problema
Las guías de Coordinadora dejaron de generarse para todas las órdenes. 56 órdenes en estado 5 con intentos agotados (= 3) desde el 6 de septiembre.

### Diagnóstico
- **API de Coordinadora**: Activa y funcional. Credenciales válidas.
- **Causa raíz del bloqueo**: El secuenciador interno de remisiones de Coordinadora para el cliente 31724 se trabó intentando reasignar la remisión `98462133644` (que ya existía), generando error de llave duplicada.
- **Namespace en `guias.sql`**: Apuntaba a sandbox (`https://sandbox.coordinadora.com/agw/ws/guias/1.6/server.php`), corregido a producción (`http://guias.coordinadora.com/ws/guias/1.6/server.php`).

### Acciones Realizadas

#### 1. Verificación de guías 32849 y 32850
- Validado contra Coordinadora mediante `Guias_reimprimirGuia`:
  - **Orden 32850**: Remisión `98462133647` (Válida, PDF confirmado).
  - **Orden 32849**: Remisión `98462133648` (Válida, PDF confirmado).
- Actualizado su estado en BD: `id_estado = 6` e `intentos = 0`.

#### 2. Generación exitosa de orden 32848
- Se probó la emisión de la orden 32848 contra Coordinadora:
  - Generó exitosamente la remisión `98462133650`.
  - Se insertó en `guias_transportadoras` con su PDF y se actualizó a `id_estado = 6`, `intentos = 0`.
- Esto confirmó que el secuenciador de Coordinadora quedó completamente desbloqueado y operativo.

#### 3. Reprocesamiento de órdenes pendientes
- Se resetearon a `intentos = 0` y `fecha_creacion = GETDATE()` las 55 órdenes pendientes en `id_estado = 5`:
```sql
UPDATE ordenes 
SET intentos = 0, fecha_creacion = GETDATE() 
WHERE id_tienda = 1 AND id_estado = 5 AND fecha_creacion >= DATEADD(day, -30, GETDATE());
-- (55 rows affected)
```
- Connekta toma automáticamente estas órdenes en su ciclo de despacho.

---
