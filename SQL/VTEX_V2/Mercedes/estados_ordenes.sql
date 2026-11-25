/*
    ================================================================================
    INTEGRACIÓN VTEX - MERCEDES CAMPUZANO
    SCRIPT: estados_ordenes.sql
    DESCRIPCIÓN:
        - Creación (DDL) y actualización (DML MERGE) de la tabla de estados de órdenes.
        - Define formalmente los estados para el flujo con Guías Coordinadora antes de Invoiced.
    ================================================================================
*/

-- ============================================================================
-- 1. CREACIÓN DE LA TABLA (SI NO EXISTE)
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.estados_ordenes') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.estados_ordenes (
        id_estado          INT           NOT NULL,
        descripcion        NVARCHAR(150) NOT NULL,
        activo             BIT           NOT NULL DEFAULT 1,
        fecha_creacion     DATETIME      NOT NULL DEFAULT GETDATE(),
        fecha_modificacion DATETIME      NULL,
        CONSTRAINT PK_estados_ordenes PRIMARY KEY CLUSTERED (id_estado ASC)
    );
END;

-- ============================================================================
-- 2. CATÁLOGO OFICIAL DE ESTADOS (MERGE DML)
-- ============================================================================
MERGE dbo.estados_ordenes AS target
USING (
    VALUES
        (1, N'Tercero por integrar a Siesa ERP', 1),
        (2, N'Tercero en proceso de integración a Siesa ERP', 1),
        (3, N'Pedido por integrar a Siesa ERP', 1),
        (4, N'Pedido integrado a Siesa ERP / Start Handling VTEX', 1),
        (5, N'Guía Coordinadora por generar (Pre-Invoiced)', 1),
        (6, N'Factura VTEX (Invoiced) por integrar', 1),
        (7, N'Factura VTEX (Invoiced) integrada exitosamente', 1),
        (8, N'Orden finalizada / Despachada', 1),
        (9, N'Marketplace externo (Bypass Guía Coordinadora)', 1)
) AS source (id_estado, descripcion, activo)
ON (target.id_estado = source.id_estado)
WHEN MATCHED AND (target.descripcion != source.descripcion OR target.activo != source.activo) THEN
    UPDATE SET 
        target.descripcion        = source.descripcion,
        target.activo             = source.activo,
        target.fecha_modificacion = GETDATE()
WHEN NOT MATCHED BY TARGET THEN
    INSERT (id_estado, descripcion, activo, fecha_creacion)
    VALUES (source.id_estado, source.descripcion, source.activo, GETDATE());

-- ============================================================================
-- 3. CONSULTA DE VALIDACIÓN
-- ============================================================================
SELECT 
    id_estado, 
    descripcion, 
    activo, 
    fecha_creacion, 
    fecha_modificacion
FROM dbo.estados_ordenes
ORDER BY id_estado ASC;
