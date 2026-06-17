SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SP_ListadoPreciosId]
AS
BEGIN
	DECLARE @id_lista_precios_base	VARCHAR(3)  = '001';
	DECLARE @id_cia_erp				INT         = 2;

	DECLARE @conexion	VARCHAR(1000),
			@bd			VARCHAR(100),
			@llenar		VARCHAR(1000);

	EXEC Sp_ConsultaConexionSiesa @conexion OUTPUT, @bd OUTPUT;

	DECLARE @t120_mc_items	TABLE
	(
		f120_rowid		INT,
		f120_referencia	NVARCHAR(50)
	);

	INSERT INTO @t120_mc_items
	EXEC('
		SELECT
			f120_rowid,
			f120_referencia
		FROM OPENROWSET(
			''SQLNCLI'', 
			'+@conexion+',
			''
				SELECT
					f120_rowid,
					f120_referencia
				FROM ['+@bd+'].dbo.t120_mc_items
			''
		)
	');

	DECLARE @t126_mc_items_precios TABLE
	(
		f126_rowid_item       VARCHAR(10),
		f126_precio           DECIMAL(18, 2),
		f126_fecha_activacion DATETIME
	);

	INSERT INTO @t126_mc_items_precios
	EXEC('
        SELECT
            f126_rowid_item,
            f126_precio,
            f126_fecha_activacion
        FROM OPENROWSET(
            ''SQLNCLI'',
            ' + @conexion + ',
            ''
                SELECT
                    f126_rowid_item,
                    f126_precio,
                    f126_fecha_activacion
                FROM (
                    SELECT
                        f126_rowid_item,
                        f126_precio,
                        f126_fecha_activacion,
                        ROW_NUMBER() OVER (
                            PARTITION BY
                                f126_rowid_item
                            ORDER BY f126_fecha_activacion DESC
                        ) AS rn
                    FROM ['+@bd+'].dbo.t126_mc_items_precios
                    WHERE
                        f126_id_lista_precio	=	''''' + @id_lista_precios_base + '''''
                        AND 
						f126_id_cia				=	''''' + @id_cia_erp + '''''
                ) AS precios_vigentes
                WHERE rn = 1
            ''
        )
    ');

	SELECT
		price		=	f126_precio,
		VariantId	=	VariantId,
		sku			=	Sku
	FROM [Integracion-AromaCafetero].dbo.Products
		INNER JOIN @t120_mc_items
			ON
				f120_referencia	=	Sku
		INNER JOIN @t126_mc_items_precios
			ON	
				f120_rowid	=	f126_rowid_item
	WHERE
		compare_at_price	!=	f126_precio;
END
GO
