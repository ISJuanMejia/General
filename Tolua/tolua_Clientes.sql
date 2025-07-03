/*  Tolua   -   Clientes    */
DECLARE @IdTercero  VARCHAR(20) =   '-1'   /*    {IdTercero}   */
DECLARE @IdCia      INT         =   -1         /*    {IdCia}       */

SELECT DISTINCT	  top 100 
	--t200.f200_rowid,
	--t201.f201_rowid_tercero,
	T200.f200_id_cia							AS 'cia',			
	t200.f200_nit								AS 'id_tercero',
	t200.f200_ind_estado						AS 'activo/inactivo',		
	t200.f200_id_tipo_ident						AS 'tipo_id',
	t200.f200_nit								AS 'numero',
	t200.f200_ind_tipo_tercero					AS 'tipo_tercero',
	t200.f200_razon_social						AS 'razon_social',
	t200.f200_nombres							AS 'nombres',
	t200.f200_apellido1							AS 'apellido',
	t200.f200_apellido2							AS 'apellido2',
	t200.f200_fecha_nacimiento					AS 'fecha_nacimiento',
	t200.f200_id_ciiu							AS 'CIUU',
	t015.f015_contacto							AS 'contacto',
	t015.f015_id_pais							AS 'id_pais',
	t015.f015_id_depto							AS 'id_departamento',
	t015.f015_id_ciudad							AS 'id_ciudad',
	t015.f015_direccion1						AS 'direccion_1',
	t015.f015_telefono							AS 'telefono',
	t015.f015_email								AS 'correo',
	f201_fecha_ingreso							AS 'fecha_ingreso',
	t201.f201_ind_calificacion					AS 'indicativo_clasificacion',
	--t210.f210_id								AS 'id_vendedor',
	t200.f200_razon_social						AS 'nombre_vendedor',
	t201.f201_id_sucursal						AS 'id_sucursal',
	t201.f201_descripcion_sucursal				AS 'sucursal',
	t201.f201_id_moneda							AS 'id_moneda',
	t201.f201_id_tipo_cli						AS 'tipo_cliente',
	t215.f215_descripcion						AS 'descripcion',
	--t0152.f015_contacto							AS 'contacto',
	t0152.f015_direccion1						AS 'direccion',
	t0152.f015_direccion2						AS 'direccion_2',
	t0152.f015_direccion3						AS 'direccion_3 ',
	--t0152.f015_id_pais							AS 'id_pais',
	--t011.f011_descripcion						AS 'pais',
	--t0152.f015_id_depto							AS 'id_departamento',
	t012.f012_descripcion						AS 'departamento',
	--t0152.f015_contacto							AS 'contacto',
	--t0152.f015_id_ciudad						AS 'id_ciudad',
	--t013.f013_descripcion						AS 'ciudad',
	--t0152.f015_id_barrio						AS 'id_barrio',
	--t0152.f015_telefono							AS 'telefono',
	t015.f015_celular							AS 'celular',
	t0152.f015_fax								AS 'fax',
	t0152.f015_cod_postal						AS 'cod_postal',
	--t0152.f015_email							AS 'correo',
	--t215.f215_id_vendedor						AS 'id_vendedor',
	t200.f200_razon_social						AS 'vendedor',
	t215.f215_vlr_pedido_minimo					AS 'valor_minimo',
	t208.f208_id								AS 'id_condicion_pago',
	t208.f208_descripcion						AS 'condicion_pago',
	t208.f208_dias_pronto_pago					AS 'dias_gracia',
	t208.f208_porcentaje_anticipo				AS 'porc_anticipo',
	t201.f201_cupo_credito						AS 'cupo_credito',
	t201.f201_ind_estado_bloqueado				AS 'bloqueado',
	t201.f201_ind_bloqueo_mora					AS 'bloquear_por_cupo',
	t201.f201_ind_bloqueo_cupo					AS 'bloquear_por_mora'
    ,
    ( 
        SELECT  DISTINCT
            f204_id             AS  'id_plan'
            ,f204_descripcion   AS  'descripcion_plan'
            ,f206_id            AS  'id_criterio_mayor'
            ,f206_descripcion   AS  'descripcion_criterio_mayor'
        FROM t207_mm_criterios_clientes  AS  t207
            INNER JOIN t206_mm_criterios_mayores AS t206 ON t207.f207_id_cia = t206.f206_id_cia
                AND t207.f207_id_plan_criterios = t206.f206_id_plan 
                AND t207.f207_id_criterio_mayor = t206.f206_id
            INNER JOIN t204_mm_planes_criterios AS t204 ON t207.f207_id_cia = t204.f204_id_cia
                AND t207.f207_id_plan_criterios = t204.f204_id 
        WHERE
            t201.f201_rowid_tercero = t207.f207_rowid_tercero
            AND
            t201.f201_id_sucursal = t207.f207_id_sucursal
            AND 
            t201.f201_id_cia = t207.f207_id_cia
        FOR JSON PATH
    )   AS  'clasificaciones_cliente' 
from t200_mm_terceros AS t200
INNER JOIN t015_mm_contactos AS t015							ON t200.f200_rowid_contacto = t015.f015_rowid  			AND t200.f200_id_cia=t015.f015_id_cia
INNER JOIN t201_mm_clientes AS t201								ON t200.f200_rowid = t201.f201_rowid_tercero  
LEFT JOIN t210_mm_vendedores AS t210							ON t200.f200_rowid = t210.f210_rowid_tercero  
LEFT JOIN t017_mm_monedas AS t017								ON t017.f017_id = t201.f201_id_moneda
LEFT JOIN t215_mm_puntos_envio_cliente AS t215					ON t201.f201_id_sucursal = t215.f215_id_sucursal		AND t201.f201_id_cia = t215.f215_id_cia				AND t201.f201_id_sucursal = t215.f215_id_sucursal    AND t201.f201_id_vendedor = t017.f017_id
LEFT JOIN t015_mm_contactos AS t0152							ON t215.f215_rowid_contacto = t0152.f015_rowid
LEFT JOIN t011_mm_paises AS	t011								ON t0152.f015_id_pais = t011.f011_id					AND t0152.f015_id_cia = t201.f201_id_cia
LEFT JOIN t012_mm_deptos AS	t012								ON t0152.f015_id_depto = t012.f012_id					AND t0152.F015_id_pais	=	T012.f012_id_pais
LEFT JOIN t013_mm_ciudades	AS t013								ON t0152.f015_id_ciudad	= t013.f013_id					AND t0152.f015_id_depto	=	T013.f013_id_depto		AND	t0152.F015_id_pais	=	T013.f013_id_pais
LEFT JOIN t208_mm_condiciones_pago AS t208						ON t201.f201_id_cond_pago = t208.f208_id				AND t201.f201_id_cia = t208.f208_id_cia

WHERE 
	(
		@IdTercero = '-1' 
		OR 
		(f200_nit = @IdTercero)
	)
	AND
	(
		@IdCia = '-1'
		OR
		(f200_id_cia = @IdCia)
	)