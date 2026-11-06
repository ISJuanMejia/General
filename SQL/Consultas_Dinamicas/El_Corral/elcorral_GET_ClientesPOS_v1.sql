DECLARE @id_cliente VARCHAR(20) = '{id_cliente}';
DECLARE @correo_cliente VARCHAR(100) = '{correo_cliente}';

-- Limpieza previa de parámetros
SET @id_cliente = RTRIM(@id_cliente);
SET @correo_cliente = RTRIM(@correo_cliente);

/*StartQueryPagConnekta*/

SELECT 
    t9740.f9740_ts AS ts,
    t9740.f9740_id_cia AS id_cia,
    t9740.f9740_id AS id,
    t9740.f9740_fecha_ingreso AS fecha_ingreso,
    t9740.f9740_ts_fecha_actualizacion AS ts_fecha_actualizacion,
    CASE WHEN t9740.f9740_ind_estado_bloqueado = 0 THEN 'Si' ELSE 'No' END AS ind_estado_bloqueado,
    t9740.f9740_motivo_bloqueo AS motivo_bloqueo,
    t9740.f9740_ts_fecha_bloqueo AS ts_fecha_bloqueo,
    t9740.f9740_fecha_ts_creacion AS fecha_ts_creacion,
    t9740.f9740_fecha_ts_actualizacion AS fecha_ts_actualizacion,
    t9740.f9740_usuario_creacion AS usuario_creacion,
    t9740.f9740_usuario_actualizacion AS usuario_actualizacion,
    CASE 
        WHEN fidelizados.f9741_id_cliente_pdv IS NOT NULL THEN 'Si'
        ELSE 'No'
    END AS fidelizado_leal
FROM t9740_pdv_clientes t9740 WITH (NOLOCK)
LEFT JOIN t9741_pdv_criterios_clientes fidelizados WITH (NOLOCK)
    ON fidelizados.f9741_id_cia = t9740.f9740_id_cia
   AND fidelizados.f9741_id_cliente_pdv = t9740.f9740_id
   AND fidelizados.f9741_id_plan_criterios = 'PDV'
   AND fidelizados.f9741_id_criterio_mayor = '0004'
WHERE t9740.f9740_id_cia = 1
  AND (
        (@id_cliente = '-1' AND @correo_cliente = '-1') OR
        (t9740.f9740_id = @id_cliente AND @correo_cliente = '-1') OR
        (t9740.f9740_email = @correo_cliente AND @id_cliente = '-1') OR
        (t9740.f9740_id = @id_cliente AND t9740.f9740_email = @correo_cliente)
      )
/*EndQueryPagConnekta*/

OPTION (RECOMPILE);
