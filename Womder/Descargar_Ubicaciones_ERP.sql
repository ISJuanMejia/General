DECLARE @conexion   NVARCHAR(200),
        @bd         NVARCHAR(100);

SELECT TOP 1 
    @conexion   =   cadena_conexion,
    @bd         =   base_datos 
FROM conexiones;

DECLARE @locaciones_erp TABLE   
(
    f013_id_pais        NVARCHAR(3),
    f013_id_depto       NVARCHAR(2),
    f013_id             NVARCHAR(3),
    f011_descripcion    NVARCHAR(100),
    f012_descripcion    NVARCHAR(100),
    f013_descripcion    NVARCHAR(100)
);

INSERT INTO @locaciones_erp
EXEC
('
    SELECT
        f013_id_pais,
        f013_id_depto,
        f013_id,
        f011_descripcion,
        f012_descripcion,
        f013_descripcion
    FROM    OPENROWSET
    (
        ''SQLNCLI'', 
        ''' +   @conexion   +   ''',
        ''
            SELECT
                c.f013_id_pais,
                c.f013_id_depto,
                c.f013_id,
                p.f011_descripcion,
                d.f012_descripcion,
                c.f013_descripcion 
		    FROM    t013_mm_ciudades c
		        INNER JOIN  t012_mm_deptos  d
                    ON
                        c.f013_id_depto =   d.f012_id
		        INNER JOIN  t011_mm_paises  p
                    ON
                        c.f013_id_pais  =   p.f011_id
                        AND
                        d.f012_id_pais  =   p.f011_id
		''
    ) AS a
');

DELETE  locaciones_erp;

INSERT INTO locaciones_erp
SELECT
    f013_id_pais,
    f013_id_depto,
    f013_id,
    f011_descripcion,
    f012_descripcion,
    f013_descripcion
FROM @locaciones_erp;