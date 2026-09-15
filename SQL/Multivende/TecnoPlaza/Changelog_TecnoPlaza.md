# Changelog - TecnoPlaza

---

## [2026-09-14] Refactorización de Rendimiento, Seguridad y Blindaje Geográfico

### Resumen de Cambios
Implementación integral del plan de mejoras técnicas en los 4 scripts de integración Siesa ↔ Multivende. Se resolvieron cuellos de botella críticos de red y memoria, se eliminaron credenciales cableadas, se solucionó el bug de herencia de ubicación en terceros y se añadieron comparaciones tolerantes a tildes y variantes de Bogotá D.C.

---

### Detalles por Archivo

#### 1. `SQL/Multivende/TecnoPlaza/Pedidos.sql`
- **Pre-carga de Unidades de Medida Fuera del Bucle (`#ItemsUnidad`)**:
  - Se eliminó la llamada remota `OPENROWSET` que descargaba `t120_mc_items` por cada iteración del `WHILE`. Ahora se cargan los 3,845 ítems una sola vez al inicio en la tabla temporal `#ItemsUnidad` indexada por `f120_referencia`.
  - **Impacto de Rendimiento**: De ~25 consultas remotas masivas por lote a 1 sola consulta inicial; el tiempo de respuesta por orden pasa de segundos a milisegundos.
- **Eliminación Total de Credenciales Cableadas**:
  - Se suprimió la cadena de conexión estática en texto plano con contraseñas de Siesa (`server=siesa-m3...`). Se utiliza exclusivamente `@conexion` de la tabla `dbo.Conexiones`.
- **Estandarización de Tipo de Tercero**:
  - Se homologó el criterio para empresas: `LEN(taxId) >= 9` cuando inicia por `[789]`, alineándolo con `Terceros.sql`.
- **Cálculo Aritmético Seguro**:
  - Se agregó `TRY_CAST` a los valores monetarios y descuentos del JSON para prevenir errores por valores no numéricos.
- **Auditoría de Errores**:
  - Se instrumentó el bloque `CATCH` dentro del cursor para registrar la orden fallida sin suspender el procesamiento de las órdenes restantes.

#### 2. `SQL/Multivende/TecnoPlaza/Terceros.sql`
- **Corrección de Bug Crítico de Herencia de Ubicación**:
  - Se agregaron los reinicios obligatorios `SET @pais_siesa = NULL; SET @dpto_siesa = NULL; SET @ciudad_siesa = NULL;` al inicio de cada iteración, evitando que órdenes sin coincidencia hereden la ubicación de la orden previa.
- **Homologación Geográfica Insensible a Tildes (`Latin1_General_CI_AI`)**:
  - La base de datos es `_AS` (Accent-Sensitive), lo que impedía que `MEDELLIN` coincidiera con `Medellín` o `CHIA` con `Chía`. Se incorporó el collation `Latin1_General_CI_AI` para todas las comparaciones contra `locaciones_erp`.
- **Tolerancia a Variantes de Bogotá**:
  - Se incorporó soporte nativo para comparar `BOGOTA` contra `Bogotá, D.C.` (código `169-11-001`), resolviendo el principal motivo de fallo en órdenes de la capital.
- **División Segura de Apellidos**:
  - Se reemplazó la lógica frágil de `CHARINDEX - 1` por partición controlada sobre `@posEspacio`, garantizando que nunca se produzcan índices negativos de longitud.

#### 3. `SQL/Multivende/TecnoPlaza/Inventario.sql`
- **Eliminación de Tablas Temporales Globales**:
  - Se reemplazó `##stockSiesa` por `#stockSiesa` local con inyección dinámica mediante `sp_executesql`.
- **Prevención de Error MERGE 8672**:
  - Se removió `descripcion` de la agrupación remota para asegurar que solo exista un registro por `(codigo_barras, bodega)`.
  - En la fuente del `MERGE`, se garantiza unicidad por `(warehouse, sku)` mediante `MAX(b.cantidad)`.
- **Protección contra Cantidades Negativas**:
  - Se aplicó `CASE WHEN SUM(cantidad) < 0 THEN 0 ELSE SUM(cantidad) END`.
- **Casting Numérico Seguro**:
  - Comparación protegida con `ISNULL(TRY_CAST(sp.amount AS INT), 0)`.

#### 4. `SQL/Multivende/TecnoPlaza/Descarga_Ubicaciones_Siesa.sql`
- **Transaccionalidad Atómica y Protección contra Pérdida de Datos**:
  - La descarga remota se realiza primero sobre `#tmp_locaciones`. Si y solo si retorna registros (`> 0`), se ejecuta la transacción con `TRUNCATE TABLE locaciones_erp` e inserción con lista explícita de columnas. Si falla la red, la tabla previa no se borra.
- **Corrección de Enlace Relacional**:
  - Se agregó `c.f013_id_pais = d.f012_id_pais` en el JOIN directo entre ciudades y departamentos.

---

## [2026-09-14] Optimización de Terceros, Pedidos, Inventario y Nuevo Script de Ubicaciones

### Resumen de Cambios
Se versionaron los cambios realizados en los scripts de integración con Multivende y el ERP Siesa: migración de tablas temporales a memoria en terceros, ajuste en la lógica de contacto de pedidos según tipo de tercero, simplificación de la consulta de inventario y adición del script de descarga de locaciones maestras.

### Detalles por Archivo
- **Terceros.sql**: Umbral de NIT ajustado a `>= 9` y migración a variables de tabla `@impuestos`, `@criterios`, `@entidadTercero`, `@entidadCliente`.
- **Pedidos.sql**: Mapeo dinámico de contacto (`f419_contacto`) según `@tipo_tercero`.
- **Inventario.sql**: Uso de tablas `#product` y `#stockEcommerce`.
- **Descarga_Ubicaciones_Siesa.sql**: Script inicial de descarga de geografía.

### Estado de Versionamiento
- **Commit**: `0b92f8b1`
- **Rama**: `Shopify_Estandar`
- **Mensaje**: `feat(multivende-tecnoplaza): actualizar queries de inventario, pedidos, terceros y descarga ubicaciones`
- **Push remoto**: Completado hacia `origin/Shopify_Estandar`.
