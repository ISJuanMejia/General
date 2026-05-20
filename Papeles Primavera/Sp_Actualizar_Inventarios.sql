--USE [Integracion-VTEX]
--GO
--/****** Object:  StoredProcedure [dbo].[Sp_Actualizar_Inventarios]    Script Date: 20/05/2026 8:39:59 a. m. ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--ALTER PROCEDURE [dbo].[Sp_Actualizar_Inventarios]

--AS

BEGIN

	SELECT Id_Item, Id_Extension_Uno, Id_Extension_Dos, Referencia, Id_Bodega, Id_Ubicacion, Existencias, Id_Bodega_VTex
	INTO #tmp_VW_Consultar_Inventario 
	FROM [Integracion-VTEX].dbo.VW_Consultar_Inventario;

	SELECT Id_Item, Id_Extension_Uno, Id_Extension_Dos, Referencia, Id_Bodega, Id_Ubicacion, Existencias, Id_Bodega_VTex, Integrado, Fecha_Actualizado_VTex, 'False' AS NuevoRegistro
	INTO #Movimientos_Inventario_Temp
	FROM [Integracion-VTEX].dbo.Inventarios_Temp
	WHERE Id_Inventario_Temp 
	IN (
		SELECT MAX(T.Id_Inventario_Temp) 
		FROM [Integracion-VTEX].dbo.Inventarios_Temp T
		GROUP BY T.Id_Item, T.Id_Extension_Uno, T.Id_Extension_Dos, T.Referencia, T.Id_Bodega
	)

	MERGE #Movimientos_Inventario_Temp	AS T
	USING #tmp_VW_Consultar_Inventario	AS S 

		   ON 
			(
				T.Id_Item = S.Id_Item AND 
				T.Id_Extension_Uno = S.Id_Extension_Uno AND
				T.Id_Extension_Dos = S.Id_Extension_Dos AND
				T.Referencia = S.Referencia AND
				T.Id_Bodega = S.Id_Bodega AND
				T.Id_Ubicacion = S.Id_Ubicacion AND
				T.Existencias = S.Existencias AND		
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
				,NuevoRegistro
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
					 0, 
					 'True'
				);


			INSERT INTO [Integracion-VTEX].dbo.Inventarios_Temp
			(
			 Id_Item
			,Id_Extension_Uno
			,Id_Extension_Dos
			,Referencia
			,Id_Bodega
			,Id_Ubicacion
			,Existencias
			,Id_Bodega_Vtex
			,Integrado

			)
			SELECT 
			 Id_Item
			,Id_Extension_Uno
			,Id_Extension_Dos
			,Referencia
			,Id_Bodega
			,Id_Ubicacion
			,Existencias
			,Id_Bodega_Vtex
			,Integrado

			from #Movimientos_Inventario_Temp
			where NuevoRegistro = 'True'

	DROP TABLE #tmp_VW_Consultar_Inventario
	DROP TABLE #Movimientos_Inventario_Temp


	;WITH Datos AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY Referencia
               ORDER BY Id_Inventario_Temp DESC
           ) AS RN
    FROM [Integracion-VTEX].dbo.Inventarios_Temp ITE
    WHERE ITE.Integrado = 0
    AND Existencias <> 0
    
)
SELECT *
FROM Datos
WHERE RN = 1

END
