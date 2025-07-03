/*
    DECLARE @id_co                  VARCHAR(MAX)    =   ''
    DECLARE @id_tipo_docto          VARCHAR(MAX)    =   ''
    DECLARE @consec_docto           VARCHAR(MAX)    =   ''
*/
DECLARE @num_docto_referencia   VARCHAR(MAX)    =   'cqdvun81v5'  /*{num_docto_referencia} 28918*/

SELECT TOP 100 
    T350.f350_id_co
    ,T350.f350_id_tipo_docto
    ,T350.f350_consec_docto
    ,T350.f350_fecha
    ,T461.f461_num_docto_referencia,
    f305_xml_cfd
FROM   dbo.t350_co_docto_contable AS T350
    INNER JOIN t461_cm_docto_factura_venta  AS  T461
        ON  T350.f350_rowid =   T461.f461_rowid_docto
    LEFT OUTER JOIN dbo.t305_co_cfd
        ON  t350.f350_rowid =   dbo.t305_co_cfd.f305_rowid_docto
WHERE
/*    
    T350.f350_id_co LIKE
    (
        CASE
            WHEN @id_co  != '' AND @id_co  != '-1' AND @id_co != 'id_co'
                THEN @id_co 
            ELSE
                '%%'
        END
    )
    AND
    T350.f350_id_tipo_docto LIKE
    (
        CASE
            WHEN @id_tipo_docto != '' AND @id_tipo_docto != '-1'
                THEN @id_tipo_docto
            ELSE
                '%%'
        END
    )
    AND
    T350.f350_consec_docto LIKE
    (
        CASE
            WHEN @consec_docto != '' AND @consec_docto != '-1'
                THEN @consec_docto
            ELSE
                '%%'
        END
    )
    AND
*/
    T461.f461_num_docto_referencia LIKE
    (
        CASE
            WHEN @num_docto_referencia != '' AND @num_docto_referencia != '-1'
                THEN @num_docto_referencia
            ELSE
                '%%'
        END
    )

SELECT T350.f350_id_co,
       T350.f350_id_tipo_docto,
       T350.f350_consec_docto,
       T350.f350_fecha,
       T461.f461_num_docto_referencia,
f305_xml_cfd
FROM   dbo.t350_co_docto_contable AS T350
       INNER JOIN dbo.t461_cm_docto_factura_venta AS T461
               ON T350.f350_rowid = T461.f461_rowid_docto
LEFT OUTER JOIN
                  dbo.t305_co_cfd ON t350.f350_rowid = dbo.t305_co_cfd.f305_rowid_docto
     
WHERE  ( T461.f461_num_docto_referencia = @num_docto_referencia ) 