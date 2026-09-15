SET XACT_ABORT ON;

BEGIN TRY
	DECLARE @conexion NVARCHAR(MAX), 
	        @bd       NVARCHAR(MAX);

	-- Obtener conexion y base de datos configurada
	SELECT TOP 1 
		@conexion = cadena_conexion,
		@bd       = base_datos 
	FROM dbo.conexiones;

	IF @conexion IS NULL OR @bd IS NULL
	BEGIN
		RAISERROR('No se encontró configuración activa en la tabla conexiones.', 16, 1);
		RETURN;
	END

	IF OBJECT_ID('tempdb..#tmp_locaciones') IS NOT NULL DROP TABLE #tmp_locaciones;

	CREATE TABLE #tmp_locaciones
	(
		f013_id_pais        NVARCHAR(3),
		f013_id_depto       NVARCHAR(2),
		f013_id             NVARCHAR(3),
		f011_descripcion    NVARCHAR(255),
		f012_descripcion    NVARCHAR(255),
		f013_descripcion    NVARCHAR(255)
	);

	-- Ejecutar consulta remota usando OPENROWSET con MSOLEDBSQL
	DECLARE @sql NVARCHAR(MAX) = N'
	INSERT INTO #tmp_locaciones (
		f013_id_pais,
		f013_id_depto,
		f013_id,
		f011_descripcion,
		f012_descripcion,
		f013_descripcion
	)
	SELECT 
		a.f013_id_pais,
		a.f013_id_depto,
		a.f013_id,
		a.f011_descripcion,
		a.f012_descripcion,
		a.f013_descripcion
	FROM OPENROWSET(
		''MSOLEDBSQL'',
		''' + REPLACE(@conexion, '''', '''''') + ''',
		''SELECT 
			c.f013_id_pais,
			c.f013_id_depto,
			c.f013_id,
			p.f011_descripcion,
			d.f012_descripcion,
			c.f013_descripcion 
		  FROM ' + @bd + '.dbo.t013_mm_ciudades c
		  INNER JOIN ' + @bd + '.dbo.t012_mm_deptos d 
			  ON c.f013_id_pais = d.f012_id_pais 
			 AND c.f013_id_depto = d.f012_id
		  INNER JOIN ' + @bd + '.dbo.t011_mm_paises p 
			  ON c.f013_id_pais = p.f011_id''
	) AS a;';

	EXEC sp_executesql @sql;

	DECLARE @total_descargados INT = (SELECT COUNT(*) FROM #tmp_locaciones);

	-- Actualizar locaciones_erp de forma atómica solo si la extracción remota fue exitosa
	IF @total_descargados > 0
	BEGIN
		BEGIN TRANSACTION;
			TRUNCATE TABLE dbo.locaciones_erp;

			INSERT INTO dbo.locaciones_erp (
				f013_id_pais,
				f013_id_depto,
				f013_id,
				f011_descripcion,
				f012_descripcion,
				f013_descripcion
			)
			SELECT 
				f013_id_pais,
				f013_id_depto,
				f013_id,
				f011_descripcion,
				f012_descripcion,
				f013_descripcion
			FROM #tmp_locaciones;
		COMMIT TRANSACTION;

		SELECT 
			CAST(0 AS BIT) AS indicaError, 
			CONCAT('Sincronización exitosa. Registros insertados en locaciones_erp: ', @total_descargados) AS mensaje;
	END
	ELSE
	BEGIN
		SELECT 
			CAST(1 AS BIT) AS indicaError, 
			'La consulta remota no retornó registros. locaciones_erp se mantuvo intacta.' AS mensaje;
	END

	IF OBJECT_ID('tempdb..#tmp_locaciones') IS NOT NULL DROP TABLE #tmp_locaciones;
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
	IF OBJECT_ID('tempdb..#tmp_locaciones') IS NOT NULL DROP TABLE #tmp_locaciones;

	SELECT 
		CAST(1 AS BIT) AS indicaError, 
		CONCAT('Error en Descarga_Ubicaciones_Siesa: ', ERROR_MESSAGE()) AS mensaje;
END CATCH;