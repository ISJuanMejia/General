# Informe de Estado de Integración de Pedidos: VTEX - SIESA
**Empresa:** Ortopédicos Futuro  
**Fecha de Emisión:** 07 de Septiembre de 2026  
**Alcance:** Monitoreo y diagnóstico del flujo de integración de órdenes

---

## 1. Resumen Ejecutivo

Durante la revisión técnica del flujo de integración entre la plataforma de comercio electrónico VTEX y el ERP Siesa, se adelantó un diagnóstico integral del estado de los pedidos, identificando la situación de las órdenes en sus diferentes etapas y ejecutando acciones correctivas y de sincronización en el sistema.

A continuación se detalla el estado actual de la operación, las actividades ejecutadas y el reporte informativo de novedades.

---

## 2. Actividades Ejecutadas y en Proceso

1. **Procesamiento y Avance de Órdenes a Fase de Pedido:**
   - Se evaluó el lote de órdenes en espera en la etapa de transferencias de inventario.
   - Un total de **46 órdenes** que contaban con existencia suficiente en el ERP fueron procesadas de forma exitosa, avanzando a la etapa de generación e integración de pedido comercial en Siesa (**Estado 4**).

2. **Normalización y Desbloqueo de Terceros:**
   - Se identificó una novedad en la orden `1658770585938-01` en la cual la estructura de nombres del cliente presentó el primer apellido en blanco debido a un espacio en blanco inicial en el registro de origen.
   - Se aplicó la corrección del dato en base de datos para dar cumplimiento a los requerimientos de estructura de persona natural en Siesa y se reiniciaron los reintentos para su incorporación inmediata.
   - Se incorporó una mejora preventiva en el proceso de extracción para garantizar la limpieza automática de espacios en los nombres y apellidos de futuros clientes.

3. **Reactivación de Cola de Procesamiento:**
   - Se reactivaron los intentos de transmisión para las órdenes de la última semana que habían alcanzado el límite de reintentos en las fases de creación de pedido y compromisos de mercancía.

---

## 3. Novedades de Inventario: Órdenes en Espera por Disponibilidad

Actualmente se encuentran **62 órdenes** (correspondientes a 67 líneas de producto) retenidas en la etapa de transferencia de bodega debido a que los ítems solicitados no registran unidades disponibles en la bodega de origen configurada en el ERP.

A continuación se presenta la relación informativa de las órdenes, ítems y cantidades en esta condición:

| Nro. Orden VTEX | Fecha de Orden | Referencia / Ítem | Cantidad Solicitada | Cantidad Disponible ERP | Estado de Inventario |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `1658300585695-01` | 2026-08-31 | `10105616` | 4 | 0 | Sin existencias en Bodega Origen |
| `1658340585750-01` | 2026-08-31 | `81001538` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658305382076-01` | 2026-08-31 | `80000124` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658305382749-02` | 2026-08-31 | `81000974` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658315383549-01` | 2026-08-31 | `81000898` | 1 | 0 | Sin existencias en Bodega Origen |
| `NVC-1658350553592-01` | 2026-08-31 | `10105643` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658480585794-01` | 2026-09-01 | `25771043` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658510585817-01` | 2026-09-01 | `23353112` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658520585820-01` | 2026-09-01 | `20907684` | 2 | 0 | Sin existencias en Bodega Origen |
| `1658530585825-01` | 2026-09-01 | `81000441` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658540585834-01` | 2026-09-01 | `17004903` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658550585837-01` | 2026-09-01 | `25760141` | 2 | 0 | Sin existencias en Bodega Origen |
| `1658550585839-01` | 2026-09-01 | `10106305` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658560585845-01` | 2026-09-01 | `10107212` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658560585852-01` | 2026-09-01 | `20950300` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658570585858-01` | 2026-09-01 | `10106813` | 4 | 0 | Sin existencias en Bodega Origen |
| `1658590585878-01` | 2026-09-01 | `21420963` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658600585885-01` | 2026-09-01 | `21420963` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658600585887-01` | 2026-09-01 | `81004176` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658555394175-01` | 2026-09-01 | `10105625` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658555394692-01` | 2026-09-01 | `81000629` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658605397864-01` | 2026-09-01 | `44000006` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658605397864-01` | 2026-09-01 | `44000033` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658615398045-02` | 2026-09-01 | `81000629` | 1 | 0 | Sin existencias en Bodega Origen |
| `NVC-1657610553357-01` | 2026-09-01 | `10105943` | 2 | 0 | Sin existencias en Bodega Origen |
| `NVC-1658580553625-01` | 2026-09-01 | `10105923` | 1 | 0 | Sin existencias en Bodega Origen |
| `NVC-1658610553627-01` | 2026-09-01 | `10109015` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658690585898-01` | 2026-09-02 | `20802104` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658710585904-01` | 2026-09-02 | `25800360` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658710585908-01` | 2026-09-02 | `10109003` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658710585915-01` | 2026-09-02 | `10105555` | 2 | 0 | Sin existencias en Bodega Origen |
| `1658730585919-01` | 2026-09-02 | `81004186` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658730585919-01` | 2026-09-02 | `33950218` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658730585919-01` | 2026-09-02 | `30605054` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658770585941-01` | 2026-09-02 | `10105506` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658780585943-01` | 2026-09-02 | `10106203` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658780585945-01` | 2026-09-02 | `22966720` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658810585951-01` | 2026-09-02 | `19003393` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658820585958-01` | 2026-09-02 | `10106913` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658830585962-01` | 2026-09-02 | `20802105` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658735401112-01` | 2026-09-02 | `81000270` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658795404982-01` | 2026-09-02 | `80000124` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658815406495-03` | 2026-09-02 | `81000145` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658835407461-02` | 2026-09-02 | `81000974` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658835407461-02` | 2026-09-02 | `81000977` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658845408178-02` | 2026-09-02 | `81000973` | 1 | 0 | Sin existencias en Bodega Origen |
| `NVC-1658740553631-01` | 2026-09-02 | `10109013` | 1 | 0 | Sin existencias en Bodega Origen |
| `NVC-1658760553633-01` | 2026-09-02 | `10109003` | 1 | 0 | Sin existencias en Bodega Origen |
| `NVC-1658830553637-01` | 2026-09-02 | `10109115` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658920585974-01` | 2026-09-03 | `20907684` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658940585981-01` | 2026-09-03 | `19003014` | 1 | 0 | Sin existencias en Bodega Origen |
| `1658950586006-01` | 2026-09-03 | `22966701` | 2 | 0 | Sin existencias en Bodega Origen |
| `1659010586034-01` | 2026-09-03 | `19007302` | 1 | 0 | Sin existencias en Bodega Origen |
| `1659040586040-01` | 2026-09-03 | `10114803` | 4 | 0 | Sin existencias en Bodega Origen |
| `1659090586052-01` | 2026-09-03 | `22003561` | 1 | 0 | Sin existencias en Bodega Origen |
| `1659090586052-01` | 2026-09-03 | `81000846` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1658995412828-01` | 2026-09-03 | `22300002` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1659005413276-01` | 2026-09-03 | `20909091` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1659025414036-01` | 2026-09-03 | `81001004` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1659055416388-01` | 2026-09-03 | `46000015` | 1 | 0 | Sin existencias en Bodega Origen |
| `DDD-1659065416900-01` | 2026-09-03 | `81000441` | 1 | 0 | Sin existencias en Bodega Origen |
| `NVC-1658960553639-01` | 2026-09-03 | `10109012` | 1 | 0 | Sin existencias en Bodega Origen |
| `NVC-1658990553642-01` | 2026-09-03 | `10109216` | 1 | 0 | Sin existencias en Bodega Origen |
| `NVC-1659050553644-01` | 2026-09-03 | `10106903` | 1 | 0 | Sin existencias en Bodega Origen |
| `NVC-1659060553646-01` | 2026-09-03 | `10109003` | 1 | 0 | Sin existencias en Bodega Origen |
| `NVC-1659060553647-01` | 2026-09-03 | `10106207` | 2 | 0 | Sin existencias en Bodega Origen |
| `DDD-1659175419354-02` | 2026-09-04 | `46000015` | 1 | 0 | Sin existencias en Bodega Origen |

---

## 4. Estado General de Recepción de Órdenes

- **Última orden registrada en base de datos:** `DDD-1659175419354-02` (04/09/2026 07:55:33 AM).
- **Periodo posterior al 04/09:** No se evidencian nuevas órdenes ingresadas al sistema de integración.
