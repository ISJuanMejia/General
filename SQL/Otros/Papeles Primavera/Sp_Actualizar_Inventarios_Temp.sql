USE [Integracion-VTEX]
GO
/****** Object:  StoredProcedure [dbo].[Sp_Actualizar_Inventarios_Temp]    Script Date: 20/05/2026 2:51:24 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Sp_Actualizar_Inventarios_Temp]

AS

BEGIN
	/*	
	*	Eliminar datos duplicados de la tabla Inventarios_Temp
	*/
	/*
	;WITH CTE AS
	(
		SELECT
			Id_Inventario_Temp,
			REFERENCIA,
			ROW_NUMBER() OVER (
				PARTITION BY REFERENCIA 
				ORDER BY Id_Inventario_Temp DESC
			) AS RN
		FROM [Integracion-VTEX].dbo.Inventarios_Temp
	)
	DELETE FROM CTE
	WHERE RN > 1;
	*/
	
	/*
	*	Elimina registros que no sean la principal del parametro 8
	*/
	DELETE it
	FROM [Integracion-VTEX].dbo.Inventarios_Temp	AS	it 
		INNER JOIN [Integracion-VTEX].dbo.Parametros	AS	PAR 
			ON
				PAR.Id_Parametro = '8'
	WHERE id_bodega != PAR.Valor_Uno

	MERGE [Integracion-VTEX].dbo.Inventarios_Temp	AS T
	USING [Integracion-VTEX].dbo.VW_Consultar_Movimientos_Inventario	AS S 
		ON 
			(
				T.Referencia = S.Referencia 
				AND
				T.Id_Bodega = S.Id_Bodega 
				AND
				T.Id_Ubicacion = S.Id_Ubicacion 
				AND	
				T.Id_Bodega_VTex = S.Id_Bodega_VTex
			) 
	 WHEN NOT MATCHED BY TARGET THEN 
		INSERT (
			 [Id_Item]
			,[Id_Extension_Uno]
			,[Id_Extension_Dos]
			,[Referencia]
			,[Id_Bodega]
			,[Id_Ubicacion]
			,[Existencias]
			,[Id_Bodega_VTex]
			,[Integrado]
		)
		VALUES (			
			S.Id_Item,
			S.Id_Extension_Uno,
			S.Id_Extension_Dos, 
			S.Referencia, 
			S.Id_Bodega, 
			S.Id_Ubicacion, 
			S.Existencias, 
			S.Id_Bodega_VTex, 
			0
		)
	WHEN	MATCHED AND CAST(T.Existencias AS INT) <> CAST(S.Existencias AS INT) THEN
		UPDATE SET
			T.[Existencias]	= s.[Existencias],
			T.[Integrado]	= 0;

	SELECT *
    FROM [Integracion-VTEX].dbo.Inventarios_Temp
    WHERE
		Integrado = 0
END
