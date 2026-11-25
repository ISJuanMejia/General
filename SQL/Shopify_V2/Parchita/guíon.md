# Transcripción de la Reunión - Interno Desarrollo Verona

**Fecha:** 9 de septiembre de 2026
**Duración:** 15m 33s
**Participantes:** Juan Camilo Mejía Echavarría, Diana Carolina López Bermont, Joseph Felipe Lara Angulo

---

## Resumen de la Reunión

### Tema Principal
Se discute un ticket reportado por Juan José Londoño (cliente Parchita) sobre un problema con la generación de bonos/regalos (gift cards) a través de Shopify.

### Problema Identificado
- Los bonos regalo se están generando electrónicamente y reportando a la DIAN
- Esto está generando duplicidad en los ingresos
- El cliente requiere que para los bonos regalo, las facturas **no** se ingresen al sistema contable
- Se necesita crear "pedidos no facturables" en su lugar

### Contexto del Proceso Actual
1. El flujo actual en el ERP es: Crear tercero → Crear pedido → Comprometer pedido → Facturar pedido
2. Actualmente usan conectores estándar (no código fuente personalizado)
3. Existen 3 flujos posibles con gift cards:
   - Ítems normales sin gift card
   - Solo gift card
   - Combinación de ambos

### Validaciones Existentes
- Hay reglas para identificar gift cards por SKU según el valor (50,000, 100,000, 150,000, 250,000, 300,000 pesos)
- Existen validaciones para determinar si es un obsequio o ítem normal
- No hay una regla particular que diferencie cómo se factura cuando se compra una gift card

### Decisión Tomada
1. **No se debe avanzar** hasta que el cliente proporcione instrucciones claras sobre cómo se hace el proceso de "pedido no facturable" en su ERP
2. El equipo de integraciones **no es responsable** de enseñar procesos del ERP
3. Se debe contactar al CAM (Key Account Manager) y CXM (Customer Experience Manager) para que expliquen el proceso
4. Una vez el cliente indique cómo se hace, se evaluará si hay costo adicional (mínimo 560 USD = 8 horas de trabajo)

---

# Guión para Comunicación con el Cliente (Parchita)

---

## Versión Formal - Correo/Reunión

**Asunto:** Solicitud de aclaración sobre proceso de pedidos no facturables para bonos regalo

---

Estimado equipo de Parchita,

Hemos recibido y analizado el ticket reportado por Juan José Londoño respecto a la generación de bonos regalo y la duplicidad de ingresos reportados a la DIAN.

### Entendemos el requerimiento

De acuerdo con su solicitud, se requiere que para los pedidos que incluyan bonos regalo (gift cards), estos se manejen como **pedidos no facturables** en lugar de facturas electrónicas, evitando así la duplicidad en los ingresos reportados.

### Nuestra posición

Para poder proceder con esta implementación, necesitamos lo siguiente:

1. **Instrucciones claras del proceso en su ERP**: 
   - ¿Cómo se crea un "pedido no facturable" manualmente en su sistema?
   - ¿Qué pasos específicos se deben seguir en el ERP?

2. **Definición de casos de uso**:
   - Pedidos que contienen solo gift cards
   - Pedidos que contienen gift cards + otros productos
   - ¿Todos los pedidos con gift cards deben ser no facturables?

3. **Identificar la persona responsable**:
   - Necesitamos que nos indiquen quién en su equipo conoce el proceso completo en el ERP
   - Sugerimos contactar a su CAM (Key Account Manager) o CXM para esta orientación

### Alcance de nuestro equipo

Es importante aclarar que nuestro equipo de integraciones:
- **No tiene** el conocimiento detallado de los procesos funcionales del ERP
- **No puede** enseñar cómo realizar configuraciones internas en el ERP
- Nuestra responsabilidad se limita a replicar en la integración lo que ustedes ya saben hacer manualmente

### Próximos pasos

1. Una vez recibamos la documentación del proceso manual, evaluaremos el alcance técnico
2. Definiremos si el desarrollo requiere:
   - Configuración adicional en Conecta
   - Desarrollo personalizado
   - Tiempo estimado y costo asociado

### Costos estimados

Tengan en cuenta que cualquier desarrollo mínimo tiene un costo base de **560 USD** (equivalente a 8 horas de trabajo), el cual podría incrementarse dependiendo de la complejidad del requerimiento.

Quedamos atentos a sus comentarios y a la documentación del proceso en el ERP para poder avanzar con la implementación.

Saludos cordiales,

**Juan Camilo Mejía Echavarría**
*Equipo de Integraciones*

---

## Versión para Reunión Telefónica

---

"Buenos días, equipo de Parchita.

Hemos recibido su solicitud sobre los bonos regalo y el tema de los pedidos no facturables. Queremos comentarles que ya revisamos el ticket y tenemos claridad sobre el problema que están presentando con la duplicidad en los ingresos reportados a la DIAN.

**Para poder avanzar con esta implementación, necesitamos su colaboración en lo siguiente:**

El principal punto es que nosotros, como equipo de integraciones, no tenemos el conocimiento detallado de cómo se maneja el proceso de 'pedido no facturable' dentro de su ERP. Lo que hacemos es replicar en la integración lo que ustedes ya saben hacer manualmente en el sistema.

Por lo tanto, requerimos que nos indiquen:
1. ¿Cómo se crea un pedido no facturable en su ERP paso a paso?
2. ¿Quién en su equipo conoce este proceso y puede explicarlo?
3. ¿Qué casos específicos deben tratarse como no facturables?

Les sugerimos comunicarse con su Key Account Manager (CAM) o Customer Experience Manager (CXM) para obtener esta orientación, ya que son las áreas que tienen el expertise en los procesos funcionales del ERP.

Una vez tengamos esta información, podremos evaluar:
- Si se puede realizar con la configuración actual
- Si requiere un desarrollo adicional
- El tiempo estimado y el costo asociado

Tengan en cuenta que cualquier desarrollo mínimo tiene un costo base de 560 USD, equivalente a 8 horas de trabajo.

Quedamos atentos a sus comentarios y a la documentación que nos puedan compartir para poder avanzar."

---

## Puntos Clave a Destacar

| Tema | Mensaje |
|------|---------|
| **Problema** | Duplicidad en ingresos reportados a DIAN por bonos regalo |
| **Solución requerida** | Pedidos no facturables para gift cards |
| **Responsabilidad** | Cliente debe explicar el proceso manual en ERP |
| **Alcance de integraciones** | Solo replicamos procesos existentes, no enseñamos funcionalidades del ERP |
| **Contacto sugerido** | CAM (Patricia Paola Luna Jiménez) y CXM |
| **Costo estimado** | Mínimo 560 USD (8 horas de trabajo) |
| **Próximo paso** | Esperar documentación del proceso manual del cliente |

---

## Contexto Técnico para Referencia

### Configuración Actual
- **Conectores:** Estándar (no código fuente personalizado)
- **Flujo en ERP:** Crear tercero → Crear pedido → Comprometer pedido → Facturar pedido
- **Validaciones de Gift Card:** Por SKU según valores (50,000 - 300,000 pesos)

### Posibles Escenarios
1. Pedidos solo con ítems normales (sin gift card)
2. Pedidos solo con gift card
3. Pedidos con gift card + ítems normales

### Validaciones Existentes
- Identificación de gift cards por SKU según el valor
- Cambio de motivo según si es gift card o ítem normal
- No hay diferenciación en facturación al momento de comprar gift cards