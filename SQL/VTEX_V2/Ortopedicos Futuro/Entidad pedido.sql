DECLARE @endpoint NVARCHAR(500) = 'http://localhost:8083/v3.1/ConectoresImportar?idCompania=4826&idSistema=2&idDocumento=231390&nombreDocumento=ENTIDAD_PEDIDO_VTEXX&validarEstructura=true';

;WITH UNOEE_Entidades AS (
    SELECT
        t430.f430_num_docto_referencia,
        t430.f430_consec_docto
    FROM [UnoEE_PruebasProyectosCol].[dbo].[t430_cm_pv_docto] t430
)
UPDATE o
SET 
    o.endpoint          =   @endpoint,
    o.intentos          =   0,
    o.fecha_creacion    =   GETDATE(),
    o.orden_obj_destino =
        JSON_QUERY(
            (
                SELECT
                    EntidadesDinamicas  =
                        JSON_QUERY(
                            (
                                SELECT
                                    f350_consec_docto   =   ue.f430_consec_docto,
                                    f753_id_maestro_detalle =
                                        CASE   
                                            WHEN JSON_VALUE(o.orden_obj_origen, '$.orderId') LIKE 'NVC-%' 
                                                THEN 'NO VARIX'
                                            WHEN JSON_VALUE(o.orden_obj_origen, '$.orderId') LIKE 'DDD-%' 
                                                THEN 'ADDI'
                                            ELSE 'ORTOPEDICOS FUTURO'
                                        END
                                FROM UNOEE_Entidades ue
                                WHERE 
                                    ue.f430_num_docto_referencia    =   LEFT(
                                        CONCAT(
                                            JSON_VALUE(o.orden_obj_origen, '$.orderId'), 
                                            ' (', 
                                            JSON_VALUE(o.orden_obj_origen, '$.sequence'), 
                                            ')' 
                                        ), 
                                        15
                                    )
                                FOR JSON PATH, 
                                INCLUDE_NULL_VALUES
                            )
                        )
                FOR JSON PATH, 
                WITHOUT_ARRAY_WRAPPER, 
                INCLUDE_NULL_VALUES
            )
        )
FROM dbo.ordenes o
WHERE 
    o.id_estado =   5
    AND 
    (
        o.intentos  <=  3
        OR 
        o.intentos IS NULL
    )
    AND 
    ISNULL(o.endpoint, '') <> @endpoint
    
