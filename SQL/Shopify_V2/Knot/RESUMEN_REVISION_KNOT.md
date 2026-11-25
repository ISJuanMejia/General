# Revisión y Corrección Integración KNOT SAS (Connekta v2)

**Fecha:** `2026-11-23`  
**Compañía:** `KNOT SAS` (`NIT 901224634`, `IdCompania = 8148`, `IdSistema = 175`)  
**Arquitectura activa:** Shopify (`somosfilipa.myshopify.com`, API `2022-07`) → Connekta v2 (`shopify-colombia-knot`) → Siesa UnoEE (`SUnoEE_Knot_Real`, `wsknot.siesacloud.com:8043`)

---

## 1. Diagnóstico Inicial
- **Connekta v2 (`shopify-colombia-knot`):** Activa y operando en tiempo real hacia `SUnoEE_Knot_Real` (`t430_cm_pv_docto`, documentos `003 PDV`, último verificado `#10165` el `23/11/2026 15:01:27`).
- **Ciclo de estados (`dbo.estados_ordenes`):**
  - `1` (`Descargado`) → `5036_Tercero.sql` (`228556`) → `2` (`Tercero`)
  - `2` (`Tercero`) → `5037_Pedido.sql` (`228557`) → `3` (`Pedido` creado en Siesa)
  - `5038_Factura_desde_pedido.sql` tiene `WHERE id_estado = 2` (no toma órdenes en `3`, por lo que el ciclo automático termina en `3`).

## 2. Auditoría Shopify vs BD (`#9916` a `#10165` — 250 órdenes)
De las `250` órdenes más recientes en Shopify (`2026-11-18` a `2026-11-23`):
- `248` órdenes descargadas e importadas correctamente en Siesa (`id_estado = 3`).
- **`#10122`** (`2026-11-22T18:40:25-05:00`, `paid`): Faltante en `dbo.ordenes` (transacción `sale success` ya existía en `dbo.transacciones_ordenes`, `id = 3178`).
- **`#10128`** (`2026-11-22T21:07:44-05:00`, `paid`): Falló en `id_estado = 1` (`intentos = 4`) porque `first_name` (`"Esteban (hermano Valentina Cardozo)"`, 35 chars) y `name` (43 chars) excedían la longitud de `F200_NOMBRES` / `F201_DESCRIPCION_SUCURSAL` en el conector `228556`.

## 3. Acciones Realizadas
1. Descargados parámetros y los `11` procesos de Connekta v2 (`8148` / `175`) en `C:\Medellin\General\SQL\Shopify_V2\Knot\`.
2. Descargada e insertada la orden **`#10122`** en `shopify-colombia-knot.dbo.ordenes` (`id = 3025`, `id_estado = 1`, `intentos = 0`).
3. Corregido en `dbo.ordenes` (`id = 2987`, **`#10128`**) `first_name = 'Esteban'` y `name = 'Esteban Cardozo'` en `customer.default_address`, `billing_address` y `shipping_address`, restableciendo `id_estado = 1`, `intentos = 0`.
4. Validado con `5036_Tercero.sql` (en transacción con `ROLLBACK`): ambas órdenes (`#10122` y `#10128`) generan payload JSON válido para el conector `228556` y quedan en cola (`id_estado = 1`, `intentos = 0`) para su procesamiento en el próximo ciclo.
5. Registrada la configuración de **Connekta v2** de `KNOT SAS` en `C:\Medellin\General\general.json`.
