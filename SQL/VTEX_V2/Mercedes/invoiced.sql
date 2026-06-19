/*
UPDATE o
SET
orden_obj_destino = 
    '{
        "type": "Output",
        "invoiceNumber": "' + remote.f350_id_co + '-' + remote.f350_id_tipo_docto + '-' + RTRIM(LTRIM(CONVERT(CHAR, remote.f350_consec_docto))) + '",
        "invoiceValue": ' + JSON_VALUE(o.orden_obj_origen, '$.value') + ',
        "issuanceDate": "' + CONVERT(VARCHAR, remote.f350_fecha, 23) + '",
        "trackingNumber": "''",
        "trackingUrl": "''",
        "courier": "''",
        "items": [' + (
            SELECT 
                STUFF((
                    SELECT 
                        ',{"id":"' + JSON_VALUE(item.value, '$.id') + '",' +
                        '"price":' + 
                        CASE 
                            WHEN ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) = 1 THEN 
                                CAST(CAST(JSON_VALUE(item.value, '$.sellingPrice') AS INT) + 
                                     CAST(JSON_VALUE(o.orden_obj_origen, '$.totals[2].value') AS INT) AS NVARCHAR)
                            ELSE 
                                CAST(CAST(JSON_VALUE(item.value, '$.sellingPrice') AS INT) AS NVARCHAR)
                        END + ',' +
                        '"quantity":' + JSON_VALUE(item.value, '$.quantity') + '}'
                    FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 1, '')
        ) + ']
    }'
FROM ordenes o
INNER JOIN (
    SELECT 
        f430_rowid,
        f430_num_docto_referencia,
        f350_id_co,
        f350_id_tipo_docto,
        f350_consec_docto,
        f350_fecha
    FROM OPENROWSET(
        'SQLNCLI',
        'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Rehemma_Real;UID=Rehemma;PWD=Rehemma$12$%',
        '
        SELECT 
            t430.f430_rowid AS f430_rowid,
            t430.f430_num_docto_referencia AS f430_num_docto_referencia,
            t350.f350_id_co AS f350_id_co,
            t350.f350_id_tipo_docto AS f350_id_tipo_docto,
            t350.f350_consec_docto AS f350_consec_docto,
            t350.f350_fecha AS f350_fecha
        FROM dbo.t430_cm_pv_docto t430
        INNER JOIN dbo.t460_cm_docto_remision_venta t460 ON t430.f430_rowid = t460.f460_rowid_pv_docto
        INNER JOIN dbo.t461_cm_docto_factura_venta t461 ON t461.f461_rowid_docto = t460.f460_rowid_docto_factura
        INNER JOIN dbo.t350_co_docto_contable t350 ON t350.f350_rowid = t461.f461_rowid_docto
        '
    ) AS remote_data
) AS remote 
    ON (
        CASE 
            WHEN LEN(REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-', '')) <= 15 
            THEN REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-', '') 
            ELSE JSON_VALUE(o.orden_obj_origen, '$.sequence') 
        END
    ) = remote.f430_num_docto_referencia

WHERE 
    o.id_estado = 5
	AND 
    o.id_tienda = 1
    AND 
    o.intentos <= 3
    AND 
    ISNULL(o.orden_obj_destino, '') = ''
*/

DECLARE @cadena_conexion    NVARCHAR(255)   =   'Server=siesa-m5-sqlsw-db5.czlbpo9rvzqf.us-east-1.rds.amazonaws.com;Database=UnoEE_Rehemma_Real;UID=Rehemma;PWD=Rehemma$12$%'

DECLARE @t430_cm_pv_docto   TABLE
(
    f430_rowid                  INT,
    f430_num_docto_referencia   NVARCHAR(100)
);

INSERT INTO @t430_cm_pv_docto
EXEC ( 
    '
    SELECT
        f430_rowid,
        f430_num_docto_referencia 
    FROM OPENROWSET ( 
        ''SQLNCLI'', 
        ''' + @cadena_conexion + ''', 
        ''
            SELECT
                f430_rowid, 
                f430_num_docto_referencia 
            FROM dbo.t430_cm_pv_docto
            WHERE
                NULLIF(TRIM(f430_num_docto_referencia), '''''''') IS NOT NULL
        '' 
     )' 
);

DECLARE @t460_cm_docto_remision_venta   TABLE
(
    f460_rowid_pv_docto         INT,
    f460_rowid_docto_factura    INT
);

INSERT INTO @t460_cm_docto_remision_venta
EXEC ( 
    '
    SELECT
        f460_rowid_pv_docto,
        f460_rowid_docto_factura 
    FROM OPENROWSET ( 
        ''SQLNCLI'', 
        ''' + @cadena_conexion + ''', 
        ''
            SELECT
                f460_rowid_pv_docto, 
                f460_rowid_docto_factura 
            FROM dbo.t460_cm_docto_remision_venta
            WHERE
                f460_rowid_pv_docto         IS NOT NULL
                AND
                f460_rowid_docto_factura    IS NOT NULL
        '' 
     )' 
);

DECLARE @t461_cm_docto_factura_venta    TABLE
(
    f461_rowid_docto    INT
);

INSERT INTO @t461_cm_docto_factura_venta
EXEC ( 
    '
    SELECT
        f461_rowid_docto
    FROM OPENROWSET ( 
        ''SQLNCLI'', 
        ''' + @cadena_conexion + ''', 
        ''
            SELECT
                f461_rowid_docto
            FROM dbo.t461_cm_docto_factura_venta
        '' 
     )' 
);

DECLARE @t350_co_docto_contable TABLE
(
    f350_rowid          INT,
    f350_id_co          NVARCHAR(3),
    f350_id_tipo_docto  NVARCHAR(3),
    f350_consec_docto   INT,
    f350_fecha          DATETIME
);

INSERT INTO @t350_co_docto_contable
EXEC ( 
    '
    SELECT
        f350_rowid,
        f350_id_co,
        f350_id_tipo_docto,
        f350_consec_docto,
        f350_fecha
    FROM OPENROWSET ( 
        ''SQLNCLI'', 
        ''' + @cadena_conexion + ''', 
        ''
            SELECT
                f350_rowid,
                f350_id_co,
                f350_id_tipo_docto,
                f350_consec_docto,
                f350_fecha
            FROM dbo.t350_co_docto_contable
        '' 
     )' 
);

UPDATE O
SET
    orden_obj_destino   =
        (
            SELECT
                [type]              =   'Output',
                [invoiceNumber]     =   CONCAT(f350_id_co, '-', f350_id_tipo_docto, '-', RTRIM(LTRIM(CONVERT(CHAR, f350_consec_docto)))),
                [invoiceValue]      =   JSON_VALUE(o.orden_obj_origen, '$.value'),
                [issuanceDate]      =   CONVERT(VARCHAR, f350_fecha, 23),
                [trackingNumber]    =   '',
                [trackingUrl]       =   '',
                [courier]           =   '',
                [items]             =   
                    (
                        SELECT
                            [id]        =   JSON_VALUE(item.value, '$.id'),
                            [price]     =   
                                CASE 
                                    WHEN ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) = 1 
                                        THEN 
                                            CAST(
                                                CAST(
                                                    JSON_VALUE(item.value, '$.sellingPrice') AS INT
                                                ) + 
                                                CAST(
                                                    JSON_VALUE(o.orden_obj_origen, '$.totals[2].value') AS INT
                                                ) AS NVARCHAR
                                            )
                                    ELSE 
                                        CAST(
                                            CAST(
                                                JSON_VALUE(item.value, '$.sellingPrice') AS INT
                                            ) AS NVARCHAR
                                        )
                                END,
                            [quantity]  =   JSON_VALUE(item.value, '$.quantity')
                        FROM OPENJSON(o.orden_obj_origen, '$.items') AS item
                        FOR JSON PATH
                    )
            FOR JSON PATH,
            WITHOUT_ARRAY_WRAPPER
        )
FROM ORDENES O
    INNER JOIN @t430_cm_pv_docto
        ON
            f430_num_docto_referencia   =
                CASE 
                    WHEN
                        LEN(
                            REPLACE(
                                JSON_VALUE(o.orden_obj_origen, '$.orderId'), 
                                '-', 
                                ''
                            )
                        ) <= 15 
                        THEN
                            REPLACE(
                                JSON_VALUE(o.orden_obj_origen, '$.orderId'), 
                                '-', 
                                ''
                            ) 
                    ELSE    JSON_VALUE(o.orden_obj_origen, '$.sequence') 
                END
    INNER JOIN @t460_cm_docto_remision_venta
        ON
            f430_rowid  =   f460_rowid_pv_docto
    INNER JOIN @t461_cm_docto_factura_venta
        ON
            f461_rowid_docto    =   f460_rowid_docto_factura
    INNER JOIN @t350_co_docto_contable
        ON
            f350_rowid  =   f461_rowid_docto
WHERE 
    o.id_estado =   5
	AND 
    o.id_tienda =   1
    AND 
    o.intentos  <=  3
    AND 
    ISNULL(o.orden_obj_destino, '') =   '';