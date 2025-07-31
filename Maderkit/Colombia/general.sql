SELECT * FROM t038_mm_clases_retencion

/*  COLOMBIA  */
--> f038_id | f038_descripcion            | f038_sigla <--
--> ================================================== <--
--> 1       | Renta                       | Renta      <--
--> 11      | RETENCION DE BIENES         | RTEBIEN    <--
--> 12      | RETENCION DE HONORARIOS     | RTEHONO    <--
--> 13      | RETENCION DE SERVICIOS      | RTESERV    <--
--> 14      | RETENCION DE ARRENDAMIENTOS | RTEARRE    <--
--> 15      | RETENCION DE COMISIONES     | RTECOMI    <--
--> 21      | RETENCION DE IVA BIENES     | RTEIVABN   <--
--> 22      | RETENCION DE IVA SERVICIOS  | RTIVASER   <--
--> 31      | RETENCION ICA SERVICIOS     | ICASERV    <--
--> 32      | RETENCION ICA BIENES        | ICABIEN    <--
--> 41      | AUTORRETENCION RENTA        | AUTORTA    <--
--> 42      | AUTORRETENCION ICA EN YUMBO | AUTICAY    <--
--> 91      | DESCUENTOS                  | DCTO       <--

SELECT * FROM t040_mm_llaves_retencion
WHERE f040_id_cia = 1
ORDER BY f040_id_clase_retencion

/*  COLOMBIA  */
--> f040_id | f040_descripcion                      | f040_id_clase_retencion <--
--> ========================================================================= <--
--> 1001    | RTEFTE BIENES (14) 2.5%               | 11                      <--
--> 1002    | RETEFTE BIENES (14) 3.5%              | 11                      <--
--> 1003    | OTRA COMPRAS 2.5%                     | 11                      <--
--> 1004    | OTRAS COMPRAS 3.5%                    | 11                      <--
--> 1005    | COMPRA ACTIVO FIJO 2.5%               | 11                      <--
--> 1006    | COMPRA ACTIVO FIJO 3.5%               | 11                      <--
--> 1007    | LICENCIAS 3.5%                        | 11                      <--
-->---------------------------------------------------------------------------<--
--> 1101    | RTEFTE HONORARIOS 11%                 | 12                      <--
--> 1102    | RETEFTE HONORARIOS 10%                | 12                      <--
--> 1103    | RETEFTE HONORARIOS INGENIERIA PROY 6% | 12                      <--
-->---------------------------------------------------------------------------<--
--> 1201    | RETEFTE SERVICIOS 4%                  | 13                      <--
--> 1202    | RETEFTE SERVICIOS 6%                  | 13                      <--
--> 1203    | RETEFTE SERVICIOS 1%                  | 13                      <--
--> 1204    | RETEFUENTE SERVICIOS 2%               | 13                      <--
--> 1205    | RTEFTE SERVICIOS DE CONSTRUCCION 2%   | 13                      <--
--> 1206    | RTEFTE INTERESES 4%                   | 13                      <--
--> 1207    | RTEFTE SERVICIOS 3.5%                 | 13                      <--
--> 1208    | RTEFTE SERVICIOS TP 3.5%              | 13                      <--
--> 1209    | RTEFTE SERVICIOS  3%o                 | 13                      <--
--> 1210    | RTEFTE SERVICIOS  3,5%                | 13                      <--
--> 1211    | RTEFTE SERVICIOS TP 3.5%              | 13                      <--
--> 1212    | RETENCION DEL 10% EXTERIOR            | 13                      <--
-->---------------------------------------------------------------------------<--
--> 1301    | RETE ARRENDAMIENTO 3.5%               | 14                      <--
--> 1302    | RETE ARRENDAMIENTO 4%                 | 14                      <--
-->---------------------------------------------------------------------------<--
--> 1401    | RETEFTE COMISIONES 10%                | 15                      <--
--> 1402    | RETEFTE COMISIONES 11%                | 15                      <--
-->---------------------------------------------------------------------------<--
--> 2001    | RETEIVA BIENES  15%                   | 21                      <--
-->---------------------------------------------------------------------------<--
--> 2002    | RETEIVA SERVICIOS 15%                 | 22                      <--
--> 2003    | RETEIVA REGIMEN SIMPLE 15% BIENES     | 22                      <--
--> 2004    | RETEIVA DEL 100%                      | 22                      <--
-->---------------------------------------------------------------------------<--
--> 3001    | RETEICA HONORARIOS 10 x 1000          | 31                      <--
--> 3007    | RETEICA  ARRIENDOS 10X1000            | 31                      <--
--> 3008    | RETEICA  SERVICIOS 6X1000             | 31                      <--
--> 3009    | RETEICA SERVICIOS 4 X 1000            | 31                      <--
--> 3010    | RETEICA EN SERVICIOS 5X1000           | 31                      <--
--> 3011    | RETEICA EN SERVICIOS 7X1000           | 31                      <--
--> 3012    | RETEICA EN SERVICIOS 8X1000           | 31                      <--
--> 3013    | RETEICA EN SERVICIOS 10 X 1000        | 31                      <--
--> 3014    | RETEICA EN SERVICIOS 3 X 1000         | 31                      <--
--> 3016    | YUM - RETEICA EN SERVICIOS 11,5%o     | 31                      <--
-->---------------------------------------------------------------------------<--
--> 3002    | RETEICA BIENES 6X1000                 | 32                      <--
--> 3003    | RETEICA COMPRAS 5 X 1000              | 32                      <--
--> 3004    | RETEICA  6 X 1000                     | 32                      <--
--> 3005    | RETEICA EN COMPRAS 7 X 1000           | 32                      <--
--> 3006    | RETEICA EN COMPRAS 8X1000             | 32                      <--
--> 3015    | RETEICA EN COMPRAS 6,5 X 1000         | 32                      <--
-->---------------------------------------------------------------------------<--
--> 4001    | AUTORTA - 0.40%                       | 41                      <--
--> 4002    | AUTORRETENCION 0,55% DECRETO 261      | 41                      <--
-->---------------------------------------------------------------------------<--
--> 4101    | AUTORRETENCION DE ICA 0.6             | 42                      <--
-->---------------------------------------------------------------------------<--
--> 9002    | DCTO 2%                               | 91                      <--
--> 9003    | DCTO 3%                               | 91                      <--
--> 9005    | DCTO 5%                               | 91                      <--
--> 9010    | DCTO 10%                              | 91                      <--

SELECT * FROM t044_mm_clase_impuesto_valores

/*  COLOMBIA  */
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
-->-----------------------------------------------------------------------------------<--
--> 2                      | 3                       | 0       | Libre de impuesto    <--
--> 2                      | 3                       | 1       | Responsable de ICA   <--
--> 2                      | 4                       | 0       | Libre de impuesto    <--
--> 2                      | 4                       | 1       | Le aplica ICA        <--
-->-----------------------------------------------------------------------------------<--
--> 3                      | 1                       | 0       | Libre de IVA         <--
--> 3                      | 1                       | 1       | Le aplica IVA        <--
--> 3                      | 3                       | 0       | Libre de impuesto    <--
--> 3                      | 3                       | 1       | Responsable de IVA   <--
--> 3                      | 4                       | 0       | Libre de IVA         <--
--> 3                      | 4                       | 1       | Le aplica IVA        <--
--> 3                      | 2                       | 0       | Libre de impuesto    <--
--> 3                      | 2                       | 1       | Responsable de IVA   <--
--> 3                      | 2                       | 2       | Régimen simplificado <--
-->-----------------------------------------------------------------------------------<--
--> 33                     | 1                       | 0       | Libre de INPP        <--
--> 33                     | 1                       | 1       | Liquida INPP         <--
--> 33                     | 3                       | 0       | Libre de INPP        <--
--> 33                     | 3                       | 1       | Liquida INPP         <--
--> 33                     | 4                       | 0       | Libre de INPP        <--
--> 33                     | 4                       | 1       | Responsable de INPP  <--
--> 33                     | 2                       | 0       | Libre de INPP        <--
--> 33                     | 2                       | 1       | Responsable de INPP  <--
-->-----------------------------------------------------------------------------------<--
--> 34                     | 1                       | 0       | Libre de IBUA        <--
--> 34                     | 1                       | 1       | Liquida IBUA         <--
--> 34                     | 3                       | 0       | Libre de IBUA        <--
--> 34                     | 3                       | 1       | Liquida IBUA         <--
--> 34                     | 4                       | 0       | Libre de IBUA        <--
--> 34                     | 4                       | 1       | Responsable de IBUA  <--
--> 34                     | 2                       | 0       | Libre de IBUA        <--
--> 34                     | 2                       | 1       | Responsable de IBUA  <--
-->-----------------------------------------------------------------------------------<--
--> 35                     | 1                       | 0       | Libre de IPCU        <--
--> 35                     | 1                       | 1       | Liquida IPCU         <--
--> 35                     | 3                       | 0       | Libre de IPCU        <--
--> 35                     | 3                       | 1       | Liquida IPCU         <--
--> 35                     | 4                       | 0       | Libre de IPCU        <--
--> 35                     | 4                       | 1       | Responsable de IPCU  <--
--> 35                     | 2                       | 0       | Libre de IPCU        <--
--> 35                     | 2                       | 1       | Responsable de IPCU  <--

---- * -------- * ----
---- * TERCEROS * ----
---- * -------- * ----

SELECT *
FROM t203_mm_tipo_ident
WHERE f203_id_cia = 1

----> f203_id | f203_descripcion                    <----
----> ============================================= <----
----* C       | Cedula de ciudadania                <----
----* N       | Numero de identificacion tributaria <----

---------------------------------------------------------------------------------------

---- * -------- * ----
---- * CLIENTES * ----
---- * -------- * ----

SELECT * FROM t224_mm_ciiu

----> f224_id | f224_descripcion                                                   <--
----> ============================================================================ <--
----* 0081    | PERSONAS NATURALES Y SUCESIONES ILÍQUIDAS SIN ACTIVIDAD ECONÓMICA. <-- ==> CUANDO ES PERSONA NATURAL

--------------------------------------------------------------------------------------

---- * ----------------------- * ----
---- * IMPUESTOS Y RETENCIONES * ----
---- * ----------------------- * ----

/*
"Imptos_y_Reten": [
    {
        "F_TIPO_REG": "46",         //46: Impuesto cliente
        "F_ID_TERCERO": "11111",
        "F_ID_CLASE": "1",          //IVA
    }
    {
       "F_TIPO_REG": "47",       //47: Retención cliente
       "F_ID_TERCERO": "11111",
       "F_ID_CLASE": "41",       //41: AUTORRETENCION RENTA | AUTORTA
    }
]
*/

---- * Impuestos

SELECT
    f035_id,
    f035_descripcion,
    f035_sigla
FROM t035_mm_clases_impuesto

/*  COLOMBIA  */
----> f035_id | f035_descripcion | f035_sigla <--
----> ======================================= <--
----* 1       | IVA              | IVA        <--

---- * Retenciones

--------------------------------------------------------------------------------------

---- * ------------------ * ----
---- * CRITERIOS CLIENTES * ----
---- * ------------------ * ----

/*
"Criterios_Clientes": [
    {
        "F207_ID_TERCERO": "11111",
        "F207_ID_PLAN_CRITERIOS": "001",  // ==> TIPO DE CLIENTE
        "F207_ID_CRITERIO_MAYOR": "1"     // ==> NACIONAL
    },
    {
        "F207_ID_TERCERO": "11111",
        "F207_ID_PLAN_CRITERIOS": "002",  // ==> CANAL DE COMERCIALIZACION
        "F207_ID_CRITERIO_MAYOR": "13"    // ==> INTERNET
    },
    {
        "F207_ID_TERCERO": "11111",
        "F207_ID_PLAN_CRITERIOS": "003",  // ==> CLIENTE
        "F207_ID_CRITERIO_MAYOR": "1301"  // ==> PAGINA WEB PROPIA
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
----* 003     | CLIENTE                   <---

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
---->--------------------------------------------------------<---
----* 002          | 13      |  INTERNET                     <---
---->--------------------------------------------------------<---
----* 003          | 1301    |  PAGINA WEB PROPIA            <---

--------------------------------------------------------------------------------------

---- * ---------------------------- * ----
---- * ENTIDADES DINAMICAS TERCEROS * ----
---- * ---------------------------- * ----
/*
"Ent_Dinamica_Tercero": [
    {
      "f200_id": "11111",
      "f753_id_entidad": "EUNOECO017",                  // ==> Códigos Tercero - FE 2.1
      "f753_id_atributo": "co017_codigo_regimen",       // ==> Código régimen
      "f753_id_maestro": "MUNOECO016",                  // ==> Regimen Fiscal - FE 2.1
      "f753_id_maestro_detalle": "48"                   // ==> Impuesto sobre las ventas - IVA
    },
    {
      "f200_id": "11111",
      "f753_id_entidad": "EUNOECO017",                  // ==> Códigos Tercero - FE 2.1
      "f753_id_atributo": "co017_cod_tipo_oblig",       // ==> Código obligación 1
      "f753_id_maestro": "MUNOECO019",                  // ==> Responsabilidades fiscales - FE 2.1
      "f753_id_maestro_detalle": "R-99-PN"              // ==> No responsable
    },
    {
      "f200_id": "11111",
      "f753_id_entidad": "EUNOECO031",                  // ==> Detalles tributarios - FE 2.1
      "f753_id_atributo": "co031_detalle_tributario1",  // ==> Detalle tributario 1
      "f753_id_maestro": "MUNOECO035",                  // ==> Detalles tributarios - FE 2.1
      "f753_id_maestro_detalle": "01"                   // ==> IVA
    },
    {
      "f200_id": "11111",
      "f753_id_entidad": "EUNOECO036",                  // ==> Info adicional tcro FE 21 DS
      "f753_id_atributo": "co036_id_procedencia_org",   // ==> Id. Procedencia organización
        "f753_id_maestro": "MUNOECO043",                // ==> Id. Procedencia ORG FE 2.1 DS
        "f753_id_maestro_detalle": "10"                 // ==> Residente
    }
]
*/

SELECT * 
FROM t744_mm_grupo_entidad
WHERE f744_id_cia = 1

---->f744_rowid | f744_id                        <----
----> ========================================== <----
----* 10        | FE CODIGOS TIPO OBLIGACION 2.1 <----

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
                                FROM t741_mm_maestro_detalle --F741_ROWID = f743_rowid_maestro_detalle_def
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
                    AND
                    f743_rowid IN (79, 80, 152, 239)
                FOR JSON PATH
            ) AS atributo
        FROM t745_mm_grupo_entidad_relacion
            INNER JOIN t742_mm_entidad
                ON f742_rowid = f745_rowid_entidad
        WHERE 
            f744_rowid = f745_rowid_grupo_entidad
            AND
            f742_rowid IN (28, 42, 55)
        FOR JSON PATH
    ) AS entidades
FROM t744_mm_grupo_entidad
WHERE
    f744_rowid = 10

/*
[
    {
        "f742_rowid": 28,
        *   "f742_id": "EUNOECO017",
        "f742_etiqueta": "Códigos Tercero - FE 2.1",
        "atributo": [
            {
                "f743_rowid": 79,
                *   "F743_id": "co017_codigo_regimen",
                "f743_etiqueta": "Código régimen",
                "maestro": [
                    {
                        "f740_rowid": 25,
                        *   "f740_id": "MUNOECO016",
                        "f740_descripcion": "Regimen Fiscal - FE 2.1",
                        "maestro_detalle": [
                            {
                                *   "f741_id": "48",
                                "f741_descripcion": "Impuesto sobre las ventas - IVA"
                            },
                            { 
                                "f741_id": "49", 
                                "f741_descripcion": "No responsable de IVA"
                            }
                        ]
                    }
                ]
            },
            {
                "f743_rowid": 80,
                *   "F743_id": "co017_cod_tipo_oblig",
                "f743_etiqueta": "Código obligación 1",
                "maestro": [
                    {
                        "f740_rowid": 28,
                        *   "f740_id": "MUNOECO019",
                        "f740_descripcion": "Responsabilidades fiscales - FE 2.1",
                        "maestro_detalle": [
                            {
                                *   "f741_id": "R-99-PN", 
                                "f741_descripcion": "No responsable"
                            }
                        ]
                    }
                ]
            }
        ]
    },
    {
        "f742_rowid": 42,
        *   "f742_id": "EUNOECO031",
        "f742_etiqueta": "Detalles tributarios - FE 2.1",
        "atributo": [
            {
                "f743_rowid": 152,
                *   "F743_id": "co031_detalle_tributario1",
                "f743_etiqueta": "Detalle tributario 1",
                "maestro": [
                    {
                        "f740_rowid": 44,
                        *   "f740_id": "MUNOECO035",
                        "f740_descripcion": "Detalles tributarios - FE 2.1",
                        "maestro_detalle": [
                            { 
                                *   "f741_id": "01", 
                                "f741_descripcion": "IVA" 
                            }
                        ]
                    }
                ]
            }
        ]
    },
    {
        "f742_rowid": 55,
        *   "f742_id": "EUNOECO036",
        "f742_etiqueta": "Info adicional tcro FE 21 DS",
        "atributo": [
            {
                "f743_rowid": 239,
                *   "F743_id": "co036_id_procedencia_org",
                "f743_etiqueta": "Id. Procedencia organización",
                "maestro": [
                    {
                        "f740_rowid": 61,
                        *   "f740_id": "MUNOECO043",
                        "f740_descripcion": "Id. Procedencia ORG FE 2.1 DS",
                        "maestro_detalle": [
                            {
                                *   "f741_id": "10", 
                                "f741_descripcion": "Residente" 
                            }
                        ]
                    }
                ]
            }
        ]
    }
]
*/