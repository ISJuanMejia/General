# VTEX Estándar V2 - Suite de Consultas SQL

Esta carpeta contiene la colección oficial y optimizada de consultas SQL para la integración **VTEX Estándar (V2)** basada en base de datos intermedia desacoplada y arquitectura de conectores.

---

## 1. Estructura de Scripts y Conectores

```
VTEX_V2/Estándar/
├── 01_Creacion_Productos.sql        # Inserta catálogo maestro en 'productos' (sincronizado = 0)
├── 02_Creacion_SKUs.sql             # Inserta variantes vinculadas en 'variantes' (sincronizado = 0)
├── 03_Especificaciones_Productos.sql# Inserta campos técnicos en 'especificaciones_productos'
├── 04_Especificaciones_SKUs.sql     # Inserta tallas/colores en 'especificaciones_variantes'
├── 05_Actualizacion_Precios.sql     # MERGE incremental de listas de precios en 'precios'
├── 06_Actualizacion_Inventarios.sql # MERGE incremental de saldos netos por bodega en 'inventarios'
├── 07_Importar_ERP_Terceros.sql     # Conector de Terceros: Genera payload y endpoint en 'ordenes'
├── 07_Importar_ERP_Pedidos.sql      # Conector de Pedidos: Genera payload y endpoint en 'ordenes'
├── 08_Cambio_Estado_Invoiced.sql    # Cruza factura contable y remisión para VTEX Invoice API
├── 09_Guias_Coordinadora.sql        # Genera sobre SOAP XML para Web Service de Coordinadora
└── README.md                        # Documentación técnica
```

---

## 2. Importar ERP: Arquitectura de Conectores

El proceso **Importar ERP** opera como mínimo a través de dos conectores REST de Connekta Cloud hacia Siesa UnoEE:

1. **Conector de Terceros (`07_Importar_ERP_Terceros.sql`):**
   * Configura el `endpoint` de importación de terceros en la tabla `ordenes`.
   * Construye en `orden_obj_destino` los nodos JSON:
     * `Terceros`: Datos del maestro principal `f200`.
     * `Clientes`: Datos de la sucursal del cliente `f201`.
     * `ImpuestosyRetenciones`: Clases impositivas para clientes de ventas web.
     * `EntDinamicaTercero`: Parámetros de Facturación Electrónica DIAN.
   * Valida existencia en `t200_mm_terceros` para avanzar inmediatamente a Estado 3.

2. **Conector de Pedidos (`07_Importar_ERP_Pedidos.sql`):**
   * Configura el `endpoint` de importación de pedidos en la tabla `ordenes`.
   * Construye en `orden_obj_destino` los nodos JSON:
     * `Pedidos`: Encabezado `f430` y datos de despacho y contacto `f419`.
     * `Movimientos`: Detalle de ítems `f431` numerados y registro adicional de `FLETES`.
     * `Impuestos`: Tasas de IVA por ítem según grupo impositivo del ERP.
     * `Descuentos`: Descuentos comerciales aplicados en el checkout.
   * Valida existencia previa en `t430_cm_pv_docto` para evitar duplicidad y avanzar a Estado 4.

---

## 3. Parámetros Configurables

* `@id_tienda`: Identificador de tienda en la base intermedia (Default: `1`).
* `@id_cia`: Identificador de compañía dentro de Siesa UnoEE (Default: `1`).
* `@id_co`: Centro de operación del documento (Default: `'300'`).
* `@id_tipo_docto`: Tipo de documento de pedido en Siesa (Default: `'PVW'`).
* `@id_bodega`: Bodega de despacho e-commerce (Default: `'BV300'`).
* `@id_vendedor`: Identificador del vendedor para canal online (Default: `'0126'`).
* `@id_lista_precio`: Código de lista de precios ERP (Default: `'100'`).
* `@id_bodega_vtex`: ID de bodega en Logistics VTEX (Default: `'1'`).
* `@endpoint`: URL del web service / endpoint Connekta del conector.
