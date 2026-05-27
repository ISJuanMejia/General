
DECLARE @final  TABLE (
    idDocumento         INT,
    indicaParalelismo   BIT,
    descripcion         VARCHAR(50),
    idOrden             VARCHAR(50),
    json                VARCHAR(MAX)
);
 
/*
    *   Definición de información del conector: ID del documento, descripción y si indica paralelismo:
    *       ID del documento: Consultar en Connekta el Id del Conector.
    *       Descripción: Nombre del conector
    *       Indica paralelismo: 1 = Sí, 0 = No, dependiendo si el conector soporta múltiples hilos de ejecución.
*/
DECLARE
    @idDocumento        INT             =   244255,
    @indicaParalelismo  BIT             =   1,
    @descripcion        VARCHAR(100)    =   'COMPROMISOS_NATURA';
 
--->================================================================================================================<---
 
/*
    *   Configuración de ejecución del script
*/
DECLARE @batch_size     INT         =   25;  -- Órdenes por petición
DECLARE @max_intentos   INT         =   4;   -- Límite estricto de intentos (< no <=)
 
DECLARE @conexion   NVARCHAR(MAX);
DECLARE @base_datos NVARCHAR(MAX);
 
SELECT
    @conexion       =   cadena_conexion
    ,@base_datos    =   base_datos
FROM Conexiones
 

--->================================================================================================================<---
 
/*
    *   Definición de la tabla de pedidos del ERP
*/
DECLARE @t430_cm_pv_docto   TABLE   (
    f430_consec_docto               INT,
    f430_num_docto_referencia       NVARCHAR(50),
    f430_ind_estado                 INT,
    f430_ind_facturado              INT,
    f430_rowid                      INT
);
 
/*
    *   Definición de la tabla de movimientos de pedidos del ERP
*/
DECLARE @T431_cm_pv_movto   TABLE (
    f431_rowid                  NVARCHAR(50),
    f431_rowid_pv_docto         NVARCHAR(50),
    f431_cant1_pedida           NVARCHAR(50),
    f120_id                     NVARCHAR(50),
    f121_id_ext1_detalle        NVARCHAR(50),
    f121_id_ext2_detalle        NVARCHAR(50),
    f121_id_barras_principal    NVARCHAR(50)
);
 
--->================================================================================================================<---

/*
*   f430_ind_estado
*       0   ->  Elaboración
*       1   ->  Retenido
*       2   ->  Aprobado
*       3   ->  Comprometido
*       4   ->  Cumplido
*       9   ->  Anulado
*/
INSERT INTO @t430_cm_pv_docto
(
    f430_consec_docto,
    f430_num_docto_referencia,
    f430_ind_estado,
    f430_ind_facturado,
    f430_rowid
)
EXEC('
    SELECT
        f430_consec_docto,
        f430_num_docto_referencia,
        f430_ind_estado,
        f430_ind_facturado,
        f430_rowid
    FROM OPENROWSET(
        ''SQLNCLI'',
        ''' + @conexion + ''',
        ''
            SELECT
                f430_consec_docto,
                f430_num_docto_referencia,
                f430_ind_estado,
                f430_ind_facturado,
                f430_rowid
            FROM    '   +@base_datos + '.dbo.t430_cm_pv_docto
            WHERE
                f430_num_docto_referencia   IS NOT NULL
                AND
                f430_id_tipo_docto          =   ''''PDV''''
                AND
                f430_id_cia                 =   3
        ''
    )
');
 
INSERT INTO @T431_cm_pv_movto
(
    f431_rowid,
    f431_rowid_pv_docto,
    f431_cant1_pedida,
    f120_id,
    f121_id_ext1_detalle,
    f121_id_ext2_detalle,
    f121_id_barras_principal
)
EXEC('
    SELECT
        f431_rowid,
        f431_rowid_pv_docto,
        f431_cant1_pedida,
        f120_id,
        f121_id_ext1_detalle,
        f121_id_ext2_detalle,
        f121_id_barras_principal
    FROM OPENROWSET(
        ''SQLNCLI''
        ,''' + @conexion + '''
        ,''
            SELECT
                f431_rowid,
                f431_rowid_pv_docto,
                f431_cant1_pedida,
                f120_id,
                f121_id_ext1_detalle,
                f121_id_ext2_detalle,
                ISNULL(
                f121_id_barras_principal,
                f131_id
                ) AS f121_id_barras_principal
            FROM   '   +@base_datos + '.dbo.T431_cm_pv_movto
                INNER JOIN ' + @base_datos + '.dbo.t121_mc_items_extensiones
                    ON  f121_rowid      =   f431_rowid_item_ext
                INNER JOIN ' + @base_datos + '.dbo.t120_mc_items
                    ON  F121_rowid_item =   f120_rowid
                 LEFT JOIN ' + @base_datos + '.dbo.t131_mc_items_barras
            ON f131_rowid_item_ext = f121_rowid
        ''
    )
');

/*
*   f430_ind_estado
*       0   ->  Elaboración
*       1   ->  Retenido
*       2   ->  Aprobado
*       3   ->  Comprometido
*       4   ->  Cumplido
*       9   ->  Anulado
*/
UPDATE ord
    SET
        ord.intentos    =   0,
        ord.id_estado   =
            CASE    
                WHEN    f430_ind_facturado = 1 
                    THEN    5
                WHEN    
                    f430_num_docto_referencia IS NOT NULL  
                    AND 
                    f430_ind_estado =   3
                    AND 
                    ISNULL(f430_ind_facturado, 0) = 0
                    THEN    4
                ELSE    id_estado
            END
FROM [shopify-colombia-naturalisimos].dbo.ordenes   AS  ord
    LEFT JOIN @t430_cm_pv_docto    
        ON  
            f430_num_docto_referencia   =   id_orden
WHERE
    id_estado   =   3;

SELECT
    idDocumento         =   @idDocumento,
    indicaParalelismo   =   @indicaParalelismo,
    descripcion         =   @descripcion,
    idOrden             =   Nat.f430_num_docto_referencia,
    JSON                =
        (
            SELECT
                [Compromisos] = (
                    SELECT DISTINCT
                        f430_consec_docto               =   Nat.f430_consec_docto,
                        f431_id_item                    =   m.f120_id,
                        f431_codigo_barras              =   ISNULL(TRIM(m.f121_id_barras_principal),''),
                        f431_id_ext1_detalle            =   ISNULL(TRIM(m.f121_id_ext1_detalle), ''),
                        f431_id_ext2_detalle            =   ISNULL(TRIM(m.f121_id_ext2_detalle), ''),
                        f431_cant_base                  =   m.f431_cant1_pedida,
                        f431_nro_registro               =   m.f431_rowid,
                        f405_cant_por_remisionar_base   =   m.f431_cant1_pedida
                    FROM @T431_cm_pv_movto  AS  m
                    WHERE
                        m.f431_rowid_pv_docto   =   Nat.f430_rowid
                    FOR JSON PATH
                )
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
FROM @t430_cm_pv_docto  AS  Nat
    INNER JOIN  [shopify-colombia-naturalisimos].dbo.ordenes AS  o
        ON
            id_orden    =   f430_num_docto_referencia
WHERE
    o.id_estado =   3
    AND
    f430_ind_estado IN  (0,  2,  3)
    AND
    o.intentos  <=  @max_intentos;
 
