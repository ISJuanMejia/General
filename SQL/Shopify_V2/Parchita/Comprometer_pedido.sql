/*  PARCHITA    -   PARCHITA_COMPROMISOS_V6
    ----------------------------------------------------------------------------------------
    Nombre del Script: Comprometer_pedido.sql
    Descripción:
        Genera JSON para el compromiso de pedidos en el ERP SIESA para órdenes en estado 3.
    ----------------------------------------------------------------------------------------
*/
BEGIN TRY
    /*
        *	Definición de tabla de resultados
    */
    DECLARE @final	TABLE (
        idDocumento			INT,
        indicaParalelismo	BIT,
        descripcion			VARCHAR(50),
        idOrden				VARCHAR(50),
        json				VARCHAR(MAX)
    );

    DECLARE 
        @idDocumento		INT				=	202966,
        @indicaParalelismo	BIT				=	1,
        @descripcion		VARCHAR(100)	=	'PARCHITA_COMPROMISOS_V6';

--->================================================================================================================<---

    /*
        *	Configuración de ejecución del script
    */
    DECLARE @batch_size		INT			=	25;                           -- Órdenes por petición (lote de 25)
    DECLARE @max_intentos	INT			=	3;                            -- Límite estricto de intentos (< no <=)
    DECLARE @fecha_inicio	DATETIME	=	DATEADD(DAY, -30, GETDATE()); -- Filtro de ordenes no más viejas a 30 días

    DECLARE @conexion	NVARCHAR(MAX);
    DECLARE @base_datos	NVARCHAR(MAX);

    SELECT TOP 1
        @conexion		=	cadena_conexion,
        @base_datos	    =	base_datos
    FROM [shopify-colombia-parchita].dbo.conexiones;

--->================================================================================================================<---

    DECLARE	@t430_cm_pv_docto	TABLE	(
        f430_consec_docto	NVARCHAR(50),
        f430_referencia		NVARCHAR(50),
        f430_rowid 			NVARCHAR(50)
    );

    DECLARE	@t430_cm_pv_docto_2	TABLE	(
        f430_referencia		NVARCHAR(50),
        f430_ind_estado		INT,
        f430_ind_facturado	INT
    );

    DECLARE @T431_cm_pv_movto	TABLE (
        f431_rowid					NVARCHAR(50),
        f431_rowid_pv_docto			NVARCHAR(50),
        f431_cant1_pedida			NVARCHAR(50),
        f120_id						NVARCHAR(50),
        f121_id_ext1_detalle		NVARCHAR(50),
        f121_id_ext2_detalle		NVARCHAR(50),
        f121_id_barras_principal	NVARCHAR(50)
    );

--->================================================================================================================<---

    INSERT INTO @t430_cm_pv_docto (f430_consec_docto, f430_referencia, f430_rowid)
    EXEC('
        SELECT 
            f430_consec_docto,
            f430_referencia,
            f430_rowid
        FROM OPENROWSET(
            ''SQLNCLI'', 
            ''' + @conexion + ''', 
            ''
                SELECT 
                    f430_consec_docto,
                    f430_referencia,
                    f430_rowid 
                FROM ' + @base_datos + '.dbo.t430_cm_pv_docto 
                WHERE
                    f430_referencia			IS NOT NULL
                    AND
                    TRIM(f430_referencia)	!=	''''''''
                    AND
                    f430_ind_estado			=	3 
                    AND 
                    f430_ind_facturado		=	0 
                    AND 
                    f430_id_cia				=	1
            ''
        )
    ');

    INSERT INTO @t430_cm_pv_docto_2 (f430_referencia, f430_ind_estado, f430_ind_facturado)
    EXEC('
        SELECT 
            f430_referencia,
            f430_ind_estado,
            f430_ind_facturado
        FROM OPENROWSET(
            ''SQLNCLI'', 
            ''' + @conexion + ''', 
            ''
                SELECT 
                    f430_referencia,
                    MAX(f430_ind_estado) AS f430_ind_estado,
                    MAX(f430_ind_facturado) AS f430_ind_facturado
                FROM ' + @base_datos + '.dbo.t430_cm_pv_docto 
                WHERE
                    f430_referencia			IS NOT NULL
                    AND
                    TRIM(f430_referencia)	!=	''''''''
                    AND
                    f430_id_cia				=	1
                GROUP BY
                    f430_referencia
            ''
        )
    ');

    INSERT INTO @T431_cm_pv_movto (
        f431_rowid, f431_rowid_pv_docto, f431_cant1_pedida, 
        f120_id, f121_id_ext1_detalle, f121_id_ext2_detalle, f121_id_barras_principal
    )
    EXEC('
        SELECT
            f431_rowid,
            f431_rowid_pv_docto,
            f431_cant1_pedida,
            f120_id,
            f121_id_ext1_detalle,
            f121_id_ext2_detalle,
            f121_id_barras_principal 
        FROM OPENROWSET(
            ''SQLNCLI'',
            ''' + @conexion + ''',
            ''
                SELECT
                    f431_rowid,
                    f431_rowid_pv_docto,
                    f431_cant1_pedida,
                    f120_id,
                    f121_id_ext1_detalle,
                    f121_id_ext2_detalle,
                    f121_id_barras_principal
                FROM T431_cm_pv_movto
                    INNER JOIN t121_mc_items_extensiones
                        ON	f121_rowid		=	f431_rowid_item_ext
                    INNER JOIN t120_mc_items
                        ON	F121_rowid_item	=	f120_rowid
            ''
        )
    ');

    /*
        *   Actualizar órdenes en estado 3 según estado real en ERP
    */
    UPDATE ord
    SET 
        intentos  = CASE WHEN pac.f430_referencia IS NULL THEN intentos + 1 ELSE 0 END,
        id_estado = CASE
                        WHEN pac.f430_referencia IS NULL AND intentos + 1 > @max_intentos THEN 99
                        WHEN pac.f430_referencia IS NULL THEN 2
                        WHEN pac.f430_ind_estado = 3 OR pac.f430_ind_facturado = 1 THEN 4
                        ELSE 3
                    END
    FROM [shopify-colombia-parchita].dbo.ordenes AS ord
        LEFT JOIN @t430_cm_pv_docto_2 AS pac ON ord.id_orden = pac.f430_referencia
    WHERE ord.id_estado = 3;

    /*
        *   Generar JSON de compromisos limitando a 25 órdenes por lote, ordenadas por ID DESC
    */
    SELECT TOP (@batch_size)
        idDocumento			=	@idDocumento,
        indicaParalelismo	=	@indicaParalelismo,
        descripcion			=	@descripcion,
        idOrden				=	pac.f430_referencia,
        JSON				=
            (
                SELECT
                    [Compromisos] = (
                        SELECT DISTINCT
                            f430_consec_docto				=	PAC.f430_consec_docto,
                            f431_id_item					=	m.f120_id,
                            f431_id_ext1_detalle			=	ISNULL(TRIM(m.f121_id_ext1_detalle), ''),
                            f431_id_ext2_detalle			=	ISNULL(TRIM(m.f121_id_ext2_detalle), ''),
                            f431_cant_base					=	m.f431_cant1_pedida,
                            f431_nro_registro				=	m.f431_rowid,
                            f405_cant_por_remisionar_base	=	m.f431_cant1_pedida
                        FROM @T431_cm_pv_movto AS m
                        WHERE m.f431_rowid_pv_docto = PAC.f430_rowid
                        FOR JSON PATH
                    )
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
    FROM [shopify-colombia-parchita].dbo.ordenes AS o
        INNER JOIN @t430_cm_pv_docto AS pac ON o.id_orden = pac.f430_referencia
    WHERE
        o.id_estado	=	3 
        AND 
        o.intentos	<=	@max_intentos
        AND
        o.fecha_creacion >= @fecha_inicio
    ORDER BY o.id DESC;
END TRY
BEGIN CATCH
    SELECT
		indicaError         =   CAST(1 AS BIT), 
        descripcionError    =   CONCAT('Error: ', ERROR_MESSAGE()),
        ErrorNumber         =   ERROR_NUMBER(),
        ErrorSeverity       =   ERROR_SEVERITY(),
        ErrorState          =   ERROR_STATE(),
        ErrorProcedure      =   ERROR_PROCEDURE(),
        ErrorLine           =   ERROR_LINE(),
        ErrorMessage        =   ERROR_MESSAGE();
END CATCH;
