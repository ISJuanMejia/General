---- * -------- * ----
---- * TERCEROS * ----
---- * -------- * ----
/*
*   Nacional natural
"Terceros": [
    {
        "F200_ID_TIPO_IDENT": "1",
        "F200_IND_TIPO_TERCERO": "R"
    }
]

*   Nacional juridico
"Terceros": [
    {
        "F200_ID_TIPO_IDENT": "2",
        "F200_IND_TIPO_TERCERO": "N"
    }
]

*   Extranjero natural
"Terceros": [
    {
        "F200_ID_TIPO_IDENT": "1",
        "F200_IND_TIPO_TERCERO": "E"
    }
]
*/

SELECT * FROM t203_mm_tipo_ident

----> f203_id | f203_descripcion                    <--
----> ============================================= <--
----* N       | Numero de identificacion tributaria <--
----* E       | Cedula de extranjeria               <--
----* R       | Registro Federal de Contribuyentes  <--

--------------------------------------------------------------------------------------

---- * ----------------------- * ----
---- * IMPUESTOS Y RETENCIONES * ----
---- * ----------------------- * ----

SELECT * FROM t035_mm_clases_impuesto

/*  MEXICO  */
--> f035_id | f035_descripcion                         | f035_sigla <--
--> =============================================================== <--
--> 1       | IVA MX                                   | IVA        <--
--> 2       | ICA                                      | ICA        <--
--> 33      | Impuesto Nacional Productos Plásticos    | INPP       <--
--> 34      | Impto Bebidas Ultraprocesadas Azucaradas | IBUA       <--
--> 35      | Impto Produc Comestibles Ultraprocesados | IPCU       <--
--> 3       | IESP AL COMBUSTIBLE                      | IESP       <--

SELECT * FROM t037_mm_llaves_impuesto

/*  MEXICO  */
--> f037_id | f037_descripcion    | f037_id_clase_impuesto <--
--> ====================================================== <--
--> 001     | IVA 16 %            | 1                      <--
--> 002     | IVA 0% - TASA CERO  | 1                      <--
--> 003     | IVA 16% + TASA IESP | 1                      <--

SELECT * FROM t038_mm_clases_retencion

/*  MEXICO  */
--> f038_id | f038_descripcion       | f038_sigla <--
--> ============================================= <--
--> 1       | Retención de Renta ISR | RET-ISR    <--
--> 2       | Retención de IVA       | RET-IVA    <--
--> 3       | Retención de ICA       | ICA        <--

SELECT * FROM t040_mm_llaves_retencion

/*  MEXICO  */
--> f040_id | f040_descripcion              | f040_id_clase_retencion <--
--> ================================================================= <--
--> 001     | RETENCION DE IVA DEL 4%       | 2                       <--
--> 002     | RETENCION DE IVA DEL 10.6666%	| 2                       <--
--> 003     | RETENCION DE ISR DEL 10%      | 1                       <--
--> 004     | RETENCION ISR DEL 1.25%       | 1                       <--
--> 005     | RETENCION DE IVA DEL 16%      | 2                       <--

SELECT * FROM t044_mm_clase_impuesto_valores

/*  MEXICO  */
--> f044_id_clase_impuesto | f044_ind_tipo_indicador | f044_id | f044_descripcion     <--
--> ================================================================================= <--
--> 1                      | 1                       | 0       | Libre de IVA         <--
--> 1                      | 1                       | 1       | Le aplica IVA        <--
--> 1                      | 2                       | 0       | Libre de impuesto    <--
--> 1                      | 2                       | 1       | Responsable de IVA   <--
--> 1                      | 2                       | 2       | Régimen simplificado <--
--> 1                      | 3                       | 0       | Libre de impuesto    <--
--> 1                      | 3                       | 1       | Responsable de IVA   <--
--> 1                      | 4                       | 0       | Libre de IVA         <--
--> 1                      | 4                       | 1       | Le aplica IVA        <--
-----------------------------------------------------------------------------------------
--> 2                      | 3                       | 0       | Libre de impuesto    <--
--> 2                      | 3                       | 1       | Responsable de ICA   <--
--> 2                      | 4                       | 0       | Libre de impuesto    <--
--> 2                      | 4                       | 1       | Le aplica ICA        <--
-----------------------------------------------------------------------------------------
--> 33                     | 1                       | 0       | Libre de INPP        <--
--> 33                     | 1                       | 1       | Liquida INPP         <--
--> 33                     | 3                       | 0       | Libre de INPP        <--
--> 33                     | 3                       | 1       | Liquida INPP         <--
--> 33                     | 4                       | 0       | Libre de INPP        <--
--> 33                     | 4                       | 1       | Responsable de INPP  <--
--> 33                     | 2                       | 0       | Libre de INPP        <--
--> 33                     | 2                       | 1       | Responsable de INPP  <--
-----------------------------------------------------------------------------------------
--> 34                     | 1                       | 0       | Libre de IBUA        <--
--> 34                     | 1                       | 1       | Liquida IBUA         <--
--> 34                     | 3                       | 0       | Libre de IBUA        <--
--> 34                     | 3                       | 1       | Liquida IBUA         <--
--> 34                     | 4                       | 0       | Libre de IBUA        <--
--> 34                     | 4                       | 1       | Responsable de IBUA  <--
--> 34                     | 2                       | 0       | Libre de IBUA        <--
--> 34                     | 2                       | 1       | Responsable de IBUA  <--
-----------------------------------------------------------------------------------------
--> 35	                   | 1                       | 0       | Libre de IPCU        <--
--> 35	                   | 1                       | 1       | Liquida IPCU         <--
--> 35	                   | 3                       | 0       | Libre de IPCU        <--
--> 35	                   | 3                       | 1       | Liquida IPCU         <--
--> 35	                   | 4                       | 0       | Libre de IPCU        <--
--> 35	                   | 4                       | 1       | Responsable de IPCU  <--
--> 35	                   | 2                       | 0       | Libre de IPCU        <--
--> 35	                   | 2                       | 1       | Responsable de IPCU  <--

SELECT * FROM t046_mm_cliente_base_impuesto

SELECT * FROM t114_mc_grupos_impo_impuestos

--------------------------------------------------------------------------------------

---- * ------------------ * ----
---- * CRITERIOS CLIENTES * ----
---- * ------------------ * ----

/*
*   NACIONAL INTERNET
"Criterios_Clientes": [
    {
        "F207_ID_PLAN_CRITERIOS": "001",
        "F207_ID_CRITERIO_MAYOR": "13"
    }
]

*   EXTRANJERO INTERNET
"Criterios_Clientes": [
    {
        "F207_ID_PLAN_CRITERIOS": "002",
        "F207_ID_CRITERIO_MAYOR": "13"
    }
]
*/

SELECT * 
FROM t204_mm_planes_criterios
WHERE f204_id_cia = 1

----> f204_id | f204_descripcion          <---
----> =================================== <---
----* 001     | TIPO DE CLIENTE           <---
----* 002     | CANAL DE COMERCIALIZACION <---

SELECT
    f204_id,
    f204_descripcion,
    (
        SELECT
            f206_id,
            f206_descripcion
        FROM t206_mm_criterios_mayores
        WHERE
            f206_id_cia = f204_id_cia
            AND
            f206_id_plan = f204_id
        FOR JSON PATH
    ) AS criterios_mayores
FROM t204_mm_planes_criterios
WHERE f204_id_cia = 1

----> f206_id_plan | f206_id | f206_descripcion              <---
----> ====================================================== <---
----* 001          | 1       |  NACIONAL                     <---
----* 001          | 2       |  EXTERIOR                     <---
---->--------------------------------------------------------<---
----> 002          | 11      |  MODERNO                      <---
----> 002          | 12      |  TRADICIONAL                  <---
----* 002          | 13      |  INTERNET                     <---
----> 002          | 15      |  CARPINTERIA ARQUITECTONICA   <---
----> 002          | 16      |  CLIENTES VARIOS              <---
----> 002          | 17      |  DISTRIBUIDORES               <---
----> 002          | 21      |  EXTERIOR                     <---

--------------------------------------------------------------------------------------

---- * ---------------------------- * ----
---- * ENTIDADES DINAMICAS TERCEROS * ----
---- * ---------------------------- * ----

SELECT
    f744_rowid,
    f744_id
FROM t744_mm_grupo_entidad
WHERE f744_id_cia = 1

---> f744_rowid | f744_id                    <---
---> ======================================= <---
---> 1          | DIOT 1                     <---
---> 2          | DIOT 2                     <---
---> 3          | DIOT 3                     <---
---> 4          | DIOT 4                     <---
---> 5          | FE INFO MEDIO DE PAGO      <---
---> 6          | F.E. TERCEROS              <---
---> 7          | F.E. CONDICION DE PAGO     <---
---> 8          | F.E. CATALOGO MONEDAS      <---
---> 9          | F.E. CENTROS DE OPERACION  <---
---> 10         | F.E. DOCUMENTOS            <---
---> 11         | F.E. SAT IMPUESTOS         <---
---> 12         | F.E. SAT ITEM              <---
---> 13         | C.E. NUMERO DE ORDEN       <---
---> 14         | C.E. TRANSFERENCIAS        <---
---> 16         | DATOS SAT                  <---
---> 17         | DATOS COMPLEMENTO PAGO     <---
---> 18         | COMPLEMENTO PAGO FACTORAJE <---

SELECT
    f744_id,
    (
        SELECT
            f742_rowid,
            f742_id,
            f742_etiqueta,
            (
                SELECT
                    f743_rowid,
                    F743_id,
                    f743_etiqueta,
                    (
                        SELECT
                            f740_rowid
                            ,f740_id
                            ,f740_descripcion
                            ,(
                                SELECT
                                    f741_id,
                                    f741_descripcion
                                FROM t741_mm_maestro_detalle
                                WHERE f741_rowid_maestro = f740_rowid
                                FOR JSON PATH
                            ) AS maestro_detalle
                        FROM t740_mm_maestro
                        WHERE f740_rowid = f743_rowid_maestro
                        FOR JSON PATH
                    ) AS maestro
                FROM t743_mm_entidad_atributo
                WHERE
                    f742_rowid = f743_rowid_entidad
                FOR JSON PATH
            ) AS atributo
        FROM t745_mm_grupo_entidad_relacion
            INNER JOIN t742_mm_entidad
                ON f742_rowid = f745_rowid_entidad
        WHERE 
            f744_rowid = f745_rowid_grupo_entidad
        FOR JSON PATH
    ) AS entidades
FROM t744_mm_grupo_entidad
WHERE
    f744_rowid = 1

--------------------------------------------------------------------------------------

---- * ---------------------------- * ----
---- * ENTIDADES DINAMICAS CLIENTES * ----
---- * ---------------------------- * ----

/*
"Ent_Dinamica_Cliente": [
    {
        "f201_id_sucursal": "001",
        "f753_id_grupo_entidad": "F.E. TERCEROS",
        "f753_id_entidad": "EUNOEMX019",
        "f753_id_atributo": "mx019_id_forma_pago",
        "f753_id_maestro": "MUNOEMX012",
        "f753_id_maestro_detalle": "99"
    },
    {
        "f201_id_sucursal": "001",
        "f753_id_grupo_entidad": "F.E. TERCEROS",
        "f753_id_entidad": "EUNOEMX021",
        "f753_id_atributo": "mx021_id_metodo_pago",
        "f753_id_maestro": "MUNOEMX014",
        "f753_id_maestro_detalle": "PUE"
    },
    {
        "f201_id_sucursal": "001",
        "f753_id_grupo_entidad": "F.E. TERCEROS",
        "f753_id_entidad": "EUNOEMX022",
        "f753_id_atributo": "mx022_id_uso_cfdi",
        "f753_id_maestro": "MUNOEMX018",
        "f753_id_maestro_detalle": "S01"
    },
    {
        "f201_id_sucursal": "001",
        "f753_id_grupo_entidad": "F.E. TERCEROS",
        "f753_id_entidad": "EUNOEMX022",
        "f753_id_atributo": "mx022_regimen_fiscal",
        "f753_id_maestro": "MUNOEMX022",
        "f753_id_maestro_detalle": "616"
    }
]
*/

SELECT
    f744_rowid,
    f744_id
FROM t744_mm_grupo_entidad
WHERE f744_id_cia = 1

----> f744_rowid | f744_id                    <----
----> ======================================= <----
----> 1          | DIOT 1                     <----
----> 2          | DIOT 2                     <----
----> 3          | DIOT 3                     <----
----> 4          | DIOT 4                     <----
----> 5          | FE INFO MEDIO DE PAGO      <----
----* 6          | F.E. TERCEROS              <----
----> 7          | F.E. CONDICION DE PAGO     <----
----> 8          | F.E. CATALOGO MONEDAS      <----
----> 9          | F.E. CENTROS DE OPERACION  <----
----> 10         | F.E. DOCUMENTOS            <----
----> 11         | F.E. SAT IMPUESTOS         <----
----> 12         | F.E. SAT ITEM              <----
----> 13         | C.E. NUMERO DE ORDEN       <----
----> 14         | C.E. TRANSFERENCIAS        <----
----> 16         | DATOS SAT                  <----
----> 17         | DATOS COMPLEMENTO PAGO     <----
----> 18         | COMPLEMENTO PAGO FACTORAJE <----

SELECT
    f744_id,
    (
        SELECT
            f742_rowid,
            f742_id,
            f742_etiqueta,
            (
                SELECT
                    f743_rowid,
                    F743_id,
                    f743_etiqueta,
                    (
                        SELECT
                            f740_rowid
                            ,f740_id
                            ,f740_descripcion
                            ,(
                                SELECT
                                    f741_id,
                                    f741_descripcion
                                FROM t741_mm_maestro_detalle
                                WHERE f741_rowid_maestro = f740_rowid
                                FOR JSON PATH
                            ) AS maestro_detalle
                        FROM t740_mm_maestro
                        WHERE f740_rowid = f743_rowid_maestro
                        FOR JSON PATH
                    ) AS maestro
                FROM t743_mm_entidad_atributo
                WHERE
                    f742_rowid = f743_rowid_entidad
                FOR JSON PATH
            ) AS atributo
        FROM t745_mm_grupo_entidad_relacion
            INNER JOIN t742_mm_entidad
                ON f742_rowid = f745_rowid_entidad
        WHERE 
            f744_rowid = f745_rowid_grupo_entidad
            AND
            f745_rowid_entidad IN (19, 21, 22)
        FOR JSON PATH
    ) AS entidades
FROM t744_mm_grupo_entidad
WHERE
    f744_rowid = 6

/*
[
    {
        *   "f742_id": "EUNOEMX019",
        "f742_etiqueta": "F.E. - Info medio de pago",
        "atributo": [
            {
                *   "F743_id": "mx019_id_forma_pago",
                "f743_etiqueta": "Forma de pago",
                "maestro": [
                    {
                        *   "f740_id": "MUNOEMX012",
                        "f740_descripcion": "Catalogo de formas de pago",
                        "maestro_detalle": [
                            {
                                *   "f741_id": "99                  ",
                                "f741_descripcion": "Por definir                             "
                            },
                            {
                                "f741_id": "04                  ",
                                "f741_descripcion": "Tarjeta de crédito                      "
                            },
                            {
                                "f741_id": "01                  ",
                                "f741_descripcion": "Efectivo                                "
                            },
                            {
                                "f741_id": "02                  ",
                                "f741_descripcion": "Cheque nominativo                       "
                            },
                            {
                                "f741_id": "03                  ",
                                "f741_descripcion": "Transferencia electrónica de fondos     "
                            },
                            {
                                "f741_id": "05                  ",
                                "f741_descripcion": "Monedero electrónico                    "
                            },
                            {
                                *   "f741_id": "06                  ",
                                "f741_descripcion": "Dinero electrónico                      "
                            },
                            {
                                "f741_id": "08                  ",
                                "f741_descripcion": "Vales de despensa                       "
                            },
                            {
                                "f741_id": "12                  ",
                                "f741_descripcion": "Dación en pago                          "
                            },
                            {
                                "f741_id": "13                  ",
                                "f741_descripcion": "Pago por subrogación                    "
                            },
                            {
                                "f741_id": "14                  ",
                                "f741_descripcion": "Pago por consignación                   "
                            },
                            {
                                "f741_id": "15                  ",
                                "f741_descripcion": "Condonación                             "
                            },
                            {
                                "f741_id": "17                  ",
                                "f741_descripcion": "Compensación                            "
                            },
                            {
                                "f741_id": "23                  ",
                                "f741_descripcion": "Novación                                "
                            },
                            {
                                "f741_id": "24                  ",
                                "f741_descripcion": "Confusión                               "
                            },
                            {
                                "f741_id": "25                  ",
                                "f741_descripcion": "Remisión de deuda                       "
                            },
                            {
                                "f741_id": "26                  ",
                                "f741_descripcion": "Prescripción o caducidad                "
                            },
                            {
                                "f741_id": "27                  ",
                                "f741_descripcion": "A satisfacción del acreedor             "
                            },
                            {
                                "f741_id": "28                  ",
                                "f741_descripcion": "Tarjeta de débito                       "
                            },
                            {
                                "f741_id": "29                  ",
                                "f741_descripcion": "Tarjeta de servicios                    "
                            },
                            {
                                "f741_id": "30                  ",
                                "f741_descripcion": "Aplicación de anticipos                 "
                            },
                            {
                                "f741_id": "31                  ",
                                "f741_descripcion": "Intermediario pagos                     "
                            }
                        ]
                    }
                ]
            }
        ]
    },
    {
        "f742_rowid": 21,
        *   "f742_id": "EUNOEMX021",
        "f742_etiqueta": "F.E. - Info condición de pago",
        "atributo": [
            {
                "f743_rowid": 61,
                *   "F743_id": "mx021_id_metodo_pago",
                "f743_etiqueta": "Metodo de pago",
                "maestro": [
                    {
                        "f740_rowid": 14,
                        *   "f740_id": "MUNOEMX014",
                        "f740_descripcion": "Catalogo de metodo de pago",
                        "maestro_detalle": [
                            {
                                "f741_id": "PPD",
                                "f741_descripcion": "Pago en parcialidades o diferido"
                            },
                            {
                                *   "f741_id": "PUE",
                                "f741_descripcion": "Pago en una sola exhibicion"
                            }
                        ]
                    }
                ]
            }
        ]
    },
    {
        "f742_rowid": 22,
        *   "f742_id": "EUNOEMX022",
        "f742_etiqueta": "F.E – Información tercero",
        "atributo": [
            {
                "f743_rowid": 63,
                *   "F743_id": "mx022_id_uso_cfdi",
                "f743_etiqueta": "UsoCDFI",
                "maestro": [
                    {
                        "f740_rowid": 18,
                        *   "f740_id": "MUNOEMX018",
                        "f740_descripcion": "Catálogo  uso de comprobantes",
                        "maestro_detalle": [
                            {
                                "f741_id": "G01",
                                "f741_descripcion": "Adquisición de mercancias"
                            },
                            {
                                "f741_id": "G02",
                                "f741_descripcion": "Devoluciones, descuentos o bonificacione"
                            },
                            {
                                *   "f741_id": "G03", 
                                "f741_descripcion": "Gastos en general"
                            },
                            {
                                "f741_id": "I01", 
                                "f741_descripcion": "Construcciones" 
                            },
                            {
                                "f741_id": "I02",
                                "f741_descripcion": "Mobilario y equipo de oficina por invers"
                            },
                            { 
                                "f741_id": "I03", 
                                "f741_descripcion": "Equipo de transporte" 
                            },
                            {
                                "f741_id": "I04",
                                "f741_descripcion": "Equipo de computo y accesorios"
                            },
                            {
                                "f741_id": "I05",
                                "f741_descripcion": "Dados, troqueles, moldes, matrices y her"
                            },
                            {
                                "f741_id": "I06",
                                "f741_descripcion": "Comunicaciones telefónicas"
                            },
                            {
                                "f741_id": "I07",
                                "f741_descripcion": "Comunicaciones satelitales"
                            },
                            {
                                "f741_id": "I08",
                                "f741_descripcion": "Otra maquinaria y equipo"
                            },
                            {
                                "f741_id": "D01",
                                "f741_descripcion": "Honorarios médicos, dentales y gastos h."
                            },
                            {
                                "f741_id": "D02",
                                "f741_descripcion": "Gastos médicos por incapacidad o discap"
                            },
                            { 
                                "f741_id": "D03", 
                                "f741_descripcion": "Gastos funerales" 
                            },
                            {
                                "f741_id": "D04",
                                "f741_descripcion": "Donativos."
                            },
                            {
                                "f741_id": "D05",
                                "f741_descripcion": "Intereses reales efectivamente pagados p"
                            },
                            {
                                "f741_id": "D06",
                                "f741_descripcion": "Aportaciones voluntarias al SAR"
                            },
                            {
                                "f741_id": "D07",
                                "f741_descripcion": "Primas por seguros de gastos médicos"
                            },
                            {
                                "f741_id": "D08",
                                "f741_descripcion": "Gastos de transportación escolar obliga"
                            },
                            {
                                "f741_id": "D09",
                                "f741_descripcion": "Depósitos en cuentas para el ahorro, pr"
                            },
                            {
                                "f741_id": "D10",
                                "f741_descripcion": "Pagos por servicios educativos (colegiat"
                            },
                            {
                                "f741_id": "P01",
                                "f741_descripcion": "Por definir" 
                            },
                            {
                                *   "f741_id": "S01",   ==> Cuando no se ingresa
                                "f741_descripcion": "Sin efectos fiscales"
                            },
                            {
                                "f741_id": "CP01",
                                "f741_descripcion": "Pagos"
                            }
                        ]
                    }
                ]
            },
            {
                "f743_rowid": 64,
                *   "F743_id": "mx022_regimen_fiscal",
                "f743_etiqueta": "Regimen Fiscal",
                "maestro": [
                    {
                        "f740_rowid": 22,
                        *   "f740_id": "MUNOEMX022",
                        "f740_descripcion": "Catálogo de regimen fiscal",
                        "maestro_detalle": [
                            {
                                "f741_id": "601", 
                                "f741_descripcion": "Personas morales" 
                            },
                            {
                                "f741_id": "603",
                                "f741_descripcion": "Personas Morales con fines no lucrativos"
                            },
                            { 
                                "f741_id": "605", 
                                "f741_descripcion": "Personas Físicas" 
                            },
                            {
                                *   "f741_id": "612",
                                "f741_descripcion": "Personas Físicas-Actividad Empresarial"
                            },
                            {
                                *   "f741_id": "616",
                                "f741_descripcion": "Sin obligaciones fiscales"
                            },
                            { 
                                "f741_id": "606", 
                                "f741_descripcion": "Arrendamiento" 
                            },
                            {
                                "f741_id": "607",
                                "f741_descripcion": "Regimen de Enagenacion o adquisicion de "
                            },
                            {
                                "f741_id": "608",
                                "f741_descripcion": "Demas Ingresos"
                            },
                            {
                                "f741_id": "610",
                                "f741_descripcion": "Residentes en el extrangero sin establec"
                            },
                            {
                                "f741_id": "611",
                                "f741_descripcion": "Ingresos por Dividendos (socios y accion"
                            },
                            {
                                "f741_id": "614",
                                "f741_descripcion": "Ingresos por Intereses"
                            },
                            {
                                "f741_id": "615",
                                "f741_descripcion": "Regimen de Ingresos x obtencion de premi"
                            },
                            {
                                "f741_id": "620",
                                "f741_descripcion": "Sociedades Cooperativas de Produccion qu"
                            },
                            {
                                "f741_id": "621", 
                                "f741_descripcion": "Incorporacion Fiscal" 
                            },
                            {
                                "f741_id": "622",
                                "f741_descripcion": "Actividades Agricolas, Ganaderas, Silvic"
                            },
                            {
                                "f741_id": "623",
                                "f741_descripcion": "Opcional para Grupos de Sociedades"
                            },
                            {
                                "f741_id": "624", 
                                "f741_descripcion": "Coordinados" 
                            },
                            {
                                "f741_id": "625",
                                "f741_descripcion": "Regimen de Actividades Empresariales"
                            },
                            {
                                "f741_id": "626",
                                "f741_descripcion": "Regimen Simplificado de Confianza"
                            }
                        ]
                    }
                ]
            }
        ]
    }
]
*/