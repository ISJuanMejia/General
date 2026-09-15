# Contexto - TecnoPlaza

## Información General

| Campo | Valor |
|---|---|
| **Cliente** | TecnoPlaza |
| **Plataforma Origen** | Multivende (Marketplaces: Mercado Libre, Falabella/fcom, Shopify) |
| **ERP Destino** | Siesa Enterprise (UnoEE) |
| **Base de Datos Integración** | `Integracion-TecnoPlaza-Multivende` |
| **Servidor BD Integración** | `awsdbinterfaces.siesacloud.com,20446` |
| **Base de Datos ERP Siesa** | `SUnoEE_TecnoPlaza_Real` |
| **Conector Terceros (Doc)** | `222302` (`TecnoPlaza_Terceros`) |
| **Conector Pedidos (Doc)** | `225805` (`TecnoPlaza_PedidosDesc`) |

---

## Arquitectura del Flujo de Integración

```
[Multivende Webhook / API]
           ↓
    Tabla: Orders (IdEstado = 1: Webhook -> 2: Api)
           ↓
    Terceros.sql (Genera payload JSON de clientes, impuestos y entidades dinámicas)
           ↓
    [Connekta ERP Service] → Crea/Actualiza Tercero en Siesa (Orders pasa a IdEstado = 3)
           ↓
    Pedidos.sql (Verifica contra t430_cm_pv_docto y genera payload JSON de pedidos y movimientos)
           ↓
    [Connekta ERP Service] → Crea Pedido en Siesa (Orders pasa a IdEstado = 4)
```

### Tabla `estados_ordenes`

| IdEstado | Descripción |
|---|---|
| **1** | Descargado Webhook |
| **2** | Descargado Api (Listo para procesar Tercero) |
| **3** | Tercero (Tercero integrado / Listo para Pedido) |
| **4** | Pedido (Procesado a Pedido en ERP Siesa) |
| **5** | No Procesar (Órdenes canceladas, antiguas o descartadas) |

---

## Configuración de Bodegas y Canales

### Mapeo de Bodegas (`warehouse` vs Siesa)

| Bodega Multivende | ID Store Multivende | ID Bodega Siesa (`f150_id`) |
|---|---|---|
| **Bodega Online** | `64256c87-345e-42b4-951b-35cf6b8e622d` | `01` |
| **Bodega Bogota** | `f6be82ba-465c-49a6-ab8d-406f6daca35d` | `02` |
| **Bodega Ingram** | - | `01` |
| **FULL** | - | `04` |
| **FULL FALABELLA** | - | `08` |
| **FULL ML BOGOTA** | - | `11` |
| **FULL ML TIENDA OFICIAL** | - | `06` |

### Criterios de Clasificación por Canal (`origen`)

| Canal (`origen`) | Criterio Mayor Siesa (`F207_ID_CRITERIO_MAYOR`) | Vendedor Siesa (`F201_ID_VENDEDOR`) |
|---|---|---|
| **mercadolibre** | `101` | `0100` |
| **fcom** (Falabella) | `102` | `0102` |
| **shopify** | `107` | `9999` |

### Reglas de Transformación de SKUs

- **Marca HP**: Si el SKU contiene guión (`-`), se transforma a `#` (ej: `ABC-123` → `ABC#123`).
- **Marca APPLE**: Si el SKU contiene guión (`-`), se transforma a `/` (ej: `MD-123` → `MD/123`).

---

## Archivos del Módulo SQL

| Archivo | Función Principal |
|---|---|
| `Descarga_Ubicaciones_Siesa.sql` | Consulta ciudades, departamentos y países remotos en Siesa mediante OPENROWSET y actualiza `locaciones_erp`. |
| `Inventario.sql` | Compara existencias netas de Siesa (`f400_cant_existencia_1 - compromisos`) con stock de Multivende (`stockProduct`) y alimenta `dbo.Inventario` vía `MERGE`. |
| `Terceros.sql` | Extrae órdenes en `IdEstado = 2`, tipifica el cliente (Persona Natural vs Empresa), resuelve la ubicación geográfica en `locaciones_erp` y construye el JSON de integración con Terceros, Clientes, Impuestos (46, 47) y Entidades Dinámicas (`EUNOECO017`, `EUNOECO031`). |
| `Pedidos.sql` | Valida órdenes en `IdEstado = 3`, comprueba si ya existen en `t430_cm_pv_docto`, consulta tasas impositivas por ítem (`t114`/`t037`), limpia números de referencia y genera el JSON del pedido comercial con movimientos y cabecera. |

---

## Puntos Críticos y Hallazgos Técnicos

1. **Credenciales en consultas de loop**:
   - `Pedidos.sql` tenía una llamada `OPENROWSET` estática dentro del bucle de órdenes con credenciales explícitas en texto plano. Debe desacoplarse para leer únicamente fuera del loop usando `@conexion` de la tabla `Conexiones`.
2. **Consumo de memoria en `t120_mc_items`**:
   - La consulta dentro del loop intentaba traer la tabla completa de ítems para resolver la unidad de medida (`f120_id_unidad_inventario`), lo cual ocasiona alta latencia y riesgo de saturación de tempdb.
3. **Manejo de variables de ubicación en `Terceros.sql`**:
   - Las variables `@pais_siesa`, `@dpto_siesa`, `@ciudad_siesa` no se reseteaban a `NULL` al inicio de cada iteración del cursor/bucle, lo que permitía herencia de ciudades erróneas si la siguiente orden no encontraba coincidencia en `locaciones_erp`.
4. **Discrepancia en validación de Tipo de Tercero**:
   - En `Terceros.sql` se modificó a `LEN(taxId) >= 9` para clasificar tipo 2 (Empresa), mientras que en `Pedidos.sql` se mantuvo en `>= 10`. Esto debe estandarizarse.
5. **Colisión de tablas globales temporales (`##`)**:
   - El uso de `##tmp`, `##stockSiesa` y `##company_OrdenesCreadas` en entornos concurrentes produce bloqueos o errores de colisión. Deben reemplazarse por tablas temporales locales de sesión o inserciones directas.
