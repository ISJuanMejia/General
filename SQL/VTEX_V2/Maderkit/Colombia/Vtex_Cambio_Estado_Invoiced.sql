DECLARE @guias_erp  TABLE
(
    f430_consec_docto                   INT,
    f430_num_docto_referencia           NVARCHAR(50),
    f753_dato_texto_numero_guia         NVARCHAR(255),
    f741_descripcion_transportadora     NVARCHAR(255),
    f741_descripcion_guia_incidencia    NVARCHAR(255)
)

INSERT INTO @guias_erp
EXEC('
    SELECT DISTINCT
        f430_consec_docto,
        f430_num_docto_referencia,
        f753_dato_texto_numero_guia,
        f741_descripcion_transportadora,
        f741_descripcion_guia_incidencia
    FROM OPENROWSET(
        ''SQLNCLI'',
        ''Server=ec2-52-6-38-24.compute-1.amazonaws.com;Database=UnoEE_Maderkit_Pruebas;UID=Maderkit;PWD=Maderkit$12$%'',
        ''
            SELECT DISTINCT
                T430PP.f430_consec_docto,
                T430PP.f430_num_docto_referencia,
                f753_dato_texto_numero_guia =
                    ISNULL(
                        (
                            SELECT  TOP 1
                                f753_dato_texto
                            FROM t430_cm_pv_docto AS T430ENT
                                INNER JOIN t750_mm_movto_entidad    
                                    ON
                                        f750_rowid  =   T430ENT.f430_rowid_movto_entidad
                                INNER jOIN t753_mm_movto_entidad_columna
                                    ON
                                        f753_rowid_movto_entidad    =   f750_rowid
                                INNER JOIN t743_mm_entidad_atributo 
                                    ON
                                        f743_rowid  =   f753_rowid_entidad_atributo
                            WHERE  
                                f743_etiqueta   =   ''''NO_GUIA''''
                                AND 
                                T430PP.f430_rowid   =   T430ENT.f430_rowid
                        ), 
                        '''' ''''
                    ),
                f741_descripcion_transportadora =
                    ISNULL(
                        (
                            SELECT DISTINCT TOP 1
                                f741_descripcion
                            FROM t430_cm_pv_docto AS T430ENT
                                INNER JOIN t750_mm_movto_entidad
                                    ON
                                        T430ENT.f430_rowid_movto_entidad    =   f750_rowid
                                INNER JOIN t753_mm_movto_entidad_columna
                                    ON
                                        f753_rowid_movto_entidad    =   f750_rowid
                                INNER JOIN t743_mm_entidad_atributo
                                    ON
                                        f753_rowid_entidad_atributo =   f743_rowid
                                INNER JOIN t741_mm_maestro_detalle 
                                    ON
                                        f741_rowid  =   f753_rowid_maestro_detalle
                            WHERE 
                                f743_etiqueta   =   ''''TRANSPORTADORA''''
                                AND 
                                T430PP.f430_rowid = T430ENT.f430_rowid
                        ), 
                        '''' ''''
                    ),
                f741_descripcion_guia_incidencia    =
                    ISNULL(
                        (
                            SELECT DISTINCT TOP 1
                                f741_descripcion
                            FROM t430_cm_pv_docto AS T430ENT
                                INNER JOIN  t750_mm_movto_entidad
                                    ON
                                        T430ENT.f430_rowid_movto_entidad    =   f750_rowid
                                INNER JOIN  t753_mm_movto_entidad_columna
                                    ON
                                        f753_rowid_movto_entidad    =   f750_rowid
                                INNER JOIN  t743_mm_entidad_atributo 
                                    ON
                                        f753_rowid_entidad_atributo =   f743_rowid
                                INNER JOIN  t741_mm_maestro_detalle 
                                    ON
                                        f741_rowid  =   f753_rowid_maestro_detalle
                            WHERE 
                                f743_etiqueta   =   ''''GUIA_DE_INCIDENCIA''''
                                AND 
                                T430PP.f430_rowid   =   T430ENT.f430_rowid
                        )
                        , '''' ''''
                    )
            FROM t430_cm_pv_docto   AS  T430PP
                INNER JOIN  t431_cm_pv_movto 
                    ON
                        f431_rowid_pv_docto =   f430_rowid
            WHERE
                T430PP.f430_id_tipo_docto IN (''''PVI'''')
                AND
                T430PP.f430_num_docto_referencia IS NOT NULL
                AND
                (
                    SELECT  TOP 1
                        ISNULL(TRIM(f753_dato_texto), '''''''')
                    FROM t430_cm_pv_docto AS T430ENT
                        INNER JOIN  t750_mm_movto_entidad
                            ON
                                f750_rowid  =   T430ENT.f430_rowid_movto_entidad
                        INNER jOIN  t753_mm_movto_entidad_columna
                            ON
                                f753_rowid_movto_entidad    =   f750_rowid
                        INNER JOIN  t743_mm_entidad_atributo
                            ON
                                f743_rowid  =   f753_rowid_entidad_atributo
                    WHERE  
                        f743_etiqueta = ''''NO_GUIA''''
                        AND 
                        T430PP.f430_rowid = T430ENT.f430_rowid
                        AND
                        ISNULL(TRIM(f753_dato_texto), '''''''') IS NOT NULL
                        AND
                        f753_dato_texto NOT IN (''''CEDI'''', ''''MADERKIT'''')
                ) IS NOT NULL
            ORDER BY T430PP.f430_consec_docto DESC
        '')
');

--UPDATE o
--SET 
select top 1000
id_orden,
        -- "invoiceNumber": "' + remote_ERP.f350_id_co + '-' + remote_ERP.f350_id_tipo_docto + '-' + RTRIM(LTRIM(CONVERT(CHAR, remote_ERP.f350_consec_docto))) + '",
        -- "issuanceDate": "' + CONVERT(VARCHAR, remote_ERP.f350_fecha, 23) + '",
orden_obj_destino =
    '{
        "type": "Output",
        "invoiceValue": ' + JSON_VALUE(o.orden_obj_origen, '$.value') + ',
        "trackingNumber": "'+remote_ERP.f753_dato_texto_numero_guia+'",
        "trackingUrl": "",
        "courier": "'+remote_ERP.f741_descripcion_transportadora+'",
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
    INNER JOIN @guias_erp AS remote_ERP 
        ON
            (
                CASE
                    -- 1. GVL-1606052333945-01 -> G-1606052333945
                    WHEN JSON_VALUE(o.orden_obj_origen, '$.orderId') LIKE 'GVL-%'
                        THEN 'G-' + PARSENAME(REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-', '.'), 2)
                    -- 2. DDD-1606063453165-01 -> D-1606063453165
                    WHEN JSON_VALUE(o.orden_obj_origen, '$.orderId') LIKE 'DDD-%'
                        THEN 'D-' + PARSENAME(REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-', '.'), 2)
                    -- 3. VPC-1605981861393-01 -> P-1605981861393
                    WHEN JSON_VALUE(o.orden_obj_origen, '$.orderId') LIKE 'VPC-%'
                        THEN 'P-' + PARSENAME(REPLACE(JSON_VALUE(o.orden_obj_origen, '$.orderId'), '-', '.'), 2)
                    -- 4. 1606010618206-01 -> 1606010618206-0
                    WHEN JSON_VALUE(o.orden_obj_origen, '$.orderId') LIKE '[0-9]%'
                        THEN LEFT(JSON_VALUE(o.orden_obj_origen, '$.orderId'), 15)
                    -- 5. Default → usar sequence
                    ELSE JSON_VALUE(o.orden_obj_origen, '$.sequence')
                END
            ) = remote_ERP.f430_num_docto_referencia
-- WHERE 
--    o.id_estado = 5
--    AND 
--    o.intentos <= 3
ORDER BY ID_ORDEN DESC