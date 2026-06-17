DECLARE @idDocumento            INT             =   238506
        , @indicaParalelismo    BIT             =   0
        , @descripcion          NVARCHAR(100)   =   'Fact Desde Pedido_NATURALISIMO V1';

DECLARE @fecha_actual   NVARCHAR(8) =   FORMAT(GETDATE(), 'yyyyMMdd');

DECLARE @conexion   NVARCHAR(MAX);
DECLARE @base_datos NVARCHAR(MAX);
 
SELECT
    @conexion   =   cadena_conexion,
    @base_datos =   base_datos
FROM Conexiones;
 
DECLARE @t430_cm_pv_docto TABLE (
    f430_consec_docto           INT,
    f430_num_docto_referencia   VARCHAR(20)
)
 
/*  
*   Paso 1: Obtener transacciones por orden
*   f430_ind_estado
*       0   ->  Elaboración
*       1   ->  Retenido
*       2   ->  Aprobado
*       3   ->  Comprometido
*       4   ->  Cumplido
*       9   ->  Anulado
*/
INSERT INTO @t430_cm_pv_docto
EXEC('
    SELECT
        f430_consec_docto,
        f430_num_docto_referencia
    FROM ordenes o
    INNER JOIN OPENROWSET(
        ''SQLNCLI''
        , ''' + @conexion + '''
        ,''
            SELECT
                f430_consec_docto,
                f430_num_docto_referencia
            FROM ' + @base_datos + '.dbo.t430_cm_pv_docto
            WHERE
                f430_ind_estado     =   3
                AND
                f430_ind_facturado  =   0
                AND
                f430_id_cia         =   3
        ''
    ) AS t
       ON id_orden = t.f430_num_docto_referencia
WHERE 
    id > 1020
    AND 
    id_estado   =   4
    AND 
    intentos    <=  3
    '
);

/*  Paso 3: Construir JSON con lógica condicional   */
SELECT 
    idDocumento         =   @idDocumento,
    indicaParalelismo   =   @indicaParalelismo,
    descripcion         =   @descripcion,
    idOrden             =   ord.id_orden,
    JSON                =   (
        SELECT
            [Docto_ventas_comercial] = (
                SELECT
					F350_FECHA          =   @fecha_actual,
					F430_CONSEC_PEDIDO  =   CAST(p.f430_consec_docto AS VARCHAR)
                FOR JSON PATH
            ),
            [Cuotas_CxC] = (
                SELECT
                    F353_FECHA_VCTO     =   @fecha_actual,
                    F353_FECHA_DSCTO_PP =   @fecha_actual
                FOR JSON PATH
            )
            -- ,
            -- [Caja] = (
            --     SELECT
            --         F_VLR_MEDIO_PAGO    =  JSON_VALUE(o.orden_obj, '$.current_subtotal_price')
            --     FOR JSON PATH
            -- )
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )
FROM @t430_cm_pv_docto  AS  p
	INNER JOIN ordenes  AS  ord 
        ON 
            id_orden    =   p.f430_num_docto_referencia;