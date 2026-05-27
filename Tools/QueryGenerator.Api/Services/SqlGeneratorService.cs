using System.Text;
using QueryGenerator.Api.Models;

namespace QueryGenerator.Api.Services
{
    public interface ISqlGeneratorService
    {
        string GenerateTercerosSql(QueryConfiguration config);
    }

    public class SqlGeneratorService : ISqlGeneratorService
    {
        private string Sanitize(string? value)
        {
            if (value == null) return "";
            return value.Replace("'", "''");
        }

        public string GenerateTercerosSql(QueryConfiguration config)
        {
            var sb = new StringBuilder();

            sb.AppendLine($@"/*
* SCRIPT GENERADO AUTOMÁTICAMENTE PARA: {Sanitize(config.ClientName)}
* GENERACIÓN DE TERCEROS Y CLIENTES
*/

BEGIN TRY
    /*
        * Definición de tabla de resultados
    */
    DECLARE @final TABLE (
        idDocumento         INT,
        indicaParalelismo   BIT,
        descripcion         VARCHAR(50),
        idOrden             VARCHAR(50),
        json                VARCHAR(MAX)
    );

    /*
        * Definición de información del conector
    */
    DECLARE @idDocumento            INT         = {config.IdDocumento},
            @descripcionConector    VARCHAR(50) = '{Sanitize(config.DescripcionConector)}',
            @indicaParalelismo      BIT         = {(config.IndicaParalelismo ? 1 : 0)};

    DECLARE @IdSucursal             NVARCHAR(3) = '{Sanitize(config.IdSucursal)}';

    /*
        * Configuración de ejecución del script
    */
    DECLARE @batch_size INT = 25;

    /*
        * Origen de los datos del cliente/tercero
        * 1 = Customer, 2 = Billing, 3 = Customer -> Billing, 4 = Billing -> Customer
    */
    DECLARE @client_origin_data INT = {config.ClientOriginData};

    /*
        * Procesar clientes/terceros sin ID
        * 0 = No procesar, 1 = Pasar a estado 2
    */
    DECLARE @process_client_without_id BIT = {(config.ProcessClientWithoutId ? 1 : 0)};

    DECLARE @id_pais_defecto    NVARCHAR(3) = '{Sanitize(config.IdPaisDefecto)}',
            @id_dpto_defecto    NVARCHAR(3) = '{Sanitize(config.IdDptoDefecto)}',
            @id_ciudad_defecto  NVARCHAR(3) = '{Sanitize(config.IdCiudadDefecto)}';

    /*
        * Definición de variables para la obtención de la ubicación desde Shopify
        * 1 = Customer, 2 = Billing, 3 = Shipping
    */
    DECLARE @location_origin_data INT = {config.LocationOriginData};

    /*
        * Definición de las secciones del conector usando VARIABLES DE TABLA
    */
    DECLARE @Terceros TABLE (
        F200_ID                 NVARCHAR(15),
        F200_NIT                NVARCHAR(25),
        F200_ID_TIPO_IDENT      NVARCHAR(1),
        F200_IND_TIPO_TERCERO   NVARCHAR(1),
        F200_RAZON_SOCIAL       NVARCHAR(100),
        F200_APELLIDO1          NVARCHAR(29),
        F200_APELLIDO2          NVARCHAR(29),
        F200_NOMBRES            NVARCHAR(40),
        F200_NOMBRE_EST         NVARCHAR(50),
        F015_CONTACTO           NVARCHAR(50),
        F015_DIRECCION1         NVARCHAR(40),
        F015_DIRECCION2         NVARCHAR(40),
        F015_ID_PAIS            NVARCHAR(3),
        F015_ID_DEPTO           NVARCHAR(2),
        F015_ID_CIUDAD          NVARCHAR(3),
        F015_TELEFONO           NVARCHAR(20),
        F015_EMAIL              NVARCHAR(255),
        F200_FECHA_NACIMIENTO   NVARCHAR(8),
        F200_ID_CIIU            NVARCHAR(4),
        F015_CELULAR            NVARCHAR(50)
    );

    DECLARE @Clientes TABLE (
        F201_ID_TERCERO             NVARCHAR(15),
        F201_ID_SUCURSAL            NVARCHAR(3),
        F201_DESCRIPCION_SUCURSAL   NVARCHAR(40),
        F201_ID_MONEDA              NVARCHAR(3),
        F201_ID_LISTA_PRECIO        NVARCHAR(3),
        F015_CONTACTO               NVARCHAR(50),
        F015_DIRECCION1             NVARCHAR(40),
        F015_DIRECCION2             NVARCHAR(40),
        F015_ID_PAIS                NVARCHAR(3),
        F015_ID_DEPTO               NVARCHAR(2),
        F015_ID_CIUDAD              NVARCHAR(3),
        F015_TELEFONO               NVARCHAR(20),
        F015_EMAIL                  NVARCHAR(255),
        F201_FECHA_INGRESO          NVARCHAR(8),
        f015_celular                NVARCHAR(50)
    );

    DECLARE @Impuestos TABLE (
        F_TIPO_REG          VARCHAR(10),
        F_ID_TERCERO        VARCHAR(50),
        F_ID_SUCURSAL       VARCHAR(10),
        F_ID_CLASE          VARCHAR(10),
        F_ID_VALOR_TERCERO  VARCHAR(10)
    );

    DECLARE @EntDinamica TABLE (
        f200_id                 VARCHAR(255),
        f753_id_grupo_entidad   VARCHAR(255),
        f753_id_entidad         VARCHAR(255),
        f753_id_atributo        VARCHAR(255),
        f753_id_maestro         VARCHAR(255),
        f753_id_maestro_detalle VARCHAR(255)
    );

    DECLARE @ordenes TABLE (
        id_orden    NVARCHAR(20),
        orden_obj   NVARCHAR(MAX)
    );

    INSERT INTO @ordenes (id_orden, orden_obj)
    SELECT TOP (@batch_size) id_orden, orden_obj
    FROM ordenes
    WHERE id_estado = 1 AND intentos <= 3;

    DECLARE @total      INT = (SELECT COUNT(*) FROM @ordenes);
    DECLARE @counter    INT = 1;
    DECLARE @json       NVARCHAR(MAX);
    DECLARE @order      NVARCHAR(30);

    WHILE @counter <= @total
    BEGIN
        SET @json = (SELECT orden_obj FROM (SELECT orden_obj, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn FROM @ordenes) AS temp WHERE rn = @counter);
        SET @order = JSON_VALUE(@json, '$.name');

        -- Localización
        DECLARE @base_path NVARCHAR(100) = CASE @location_origin_data WHEN 1 THEN '$.customer.default_address' WHEN 2 THEN '$.billing_address' WHEN 3 THEN '$.shipping_address' ELSE '' END;
        DECLARE @pais_shopify NVARCHAR(100) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, @base_path + '.country')));
        DECLARE @dpto_shopify NVARCHAR(100) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, @base_path + '.province')));
        DECLARE @ciudad_shopify NVARCHAR(100) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, @base_path + '.city')));

        DECLARE @id_pais_erp NVARCHAR(3), @id_dptos_erp NVARCHAR(2), @id_ciudad_erp NVARCHAR(3);

        SELECT TOP 1 @id_pais_erp = ISNULL(f013_id_pais, @id_pais_defecto), @id_dptos_erp = ISNULL(f013_id_depto, @id_dpto_defecto), @id_ciudad_erp = ISNULL(f013_id, @id_ciudad_defecto)
        FROM locaciones_erp
        WHERE dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = @pais_shopify
        AND (dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = @dpto_shopify AND dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = @ciudad_shopify);

        -- Identificación del cliente
        DECLARE @id_cliente NVARCHAR(100) = CASE @client_origin_data
            WHEN 1 THEN NULLIF(TRIM(JSON_VALUE(@json, '$.customer.default_address.company')), '')
            WHEN 2 THEN NULLIF(TRIM(JSON_VALUE(@json, '$.billing_address.company')), '')
            WHEN 3 THEN ISNULL(NULLIF(TRIM(JSON_VALUE(@json, '$.customer.default_address.company')), ''), JSON_VALUE(@json, '$.billing_address.company'))
            WHEN 4 THEN ISNULL(NULLIF(TRIM(JSON_VALUE(@json, '$.billing_address.company')), ''), JSON_VALUE(@json, '$.customer.default_address.company'))
        END;

        IF @id_cliente IS NULL OR @id_cliente = ''
        BEGIN
            UPDATE ordenes SET intentos = intentos + 1, id_estado = CASE WHEN @process_client_without_id = 1 THEN 2 ELSE id_estado END WHERE id_orden = @order;
            SET @counter = @counter + 1;
            CONTINUE;
        END

        -- Limpiar ID
        SET @id_cliente = dbo.OnlyNumbers(@id_cliente);

        DECLARE @razon_social NVARCHAR(100) = UPPER(ISNULL(JSON_VALUE(@json, '$.customer.default_address.name'), JSON_VALUE(@json, '$.billing_address.name')));
        DECLARE @nombres NVARCHAR(40) = UPPER(ISNULL(JSON_VALUE(@json, '$.customer.default_address.first_name'), JSON_VALUE(@json, '$.billing_address.first_name')));
        DECLARE @apellidos NVARCHAR(80) = UPPER(ISNULL(JSON_VALUE(@json, '$.customer.default_address.last_name'), JSON_VALUE(@json, '$.billing_address.last_name')));

        DECLARE @apellido1 NVARCHAR(29) = LEFT(@apellidos, CHARINDEX(' ', @apellidos + ' ') - 1);
        DECLARE @apellido2 NVARCHAR(29) = LTRIM(SUBSTRING(@apellidos, CHARINDEX(' ', @apellidos + ' '), LEN(@apellidos)));

        DECLARE @direccion1 NVARCHAR(40) = LEFT(UPPER(ISNULL(JSON_VALUE(@json, @base_path + '.address1'), '')), 40);
        DECLARE @direccion2 NVARCHAR(40) = LEFT(UPPER(ISNULL(JSON_VALUE(@json, @base_path + '.address2'), '')), 40);
        DECLARE @telefono NVARCHAR(20) = REPLACE(ISNULL(JSON_VALUE(@json, '$.customer.default_address.phone'), ''), '+57', '');
        DECLARE @email NVARCHAR(255) = JSON_VALUE(@json, '$.customer.email');
        DECLARE @fecha NVARCHAR(8) = REPLACE(CONVERT(VARCHAR(10), CAST(JSON_VALUE(@json, '$.customer.created_at') AS DATE), 120), '-', '');

        -- Reglas especiales de tipo Identificación
        DECLARE @tipo_ident CHAR(1) = CASE WHEN @id_cliente LIKE '[789]%' AND LEN(@id_cliente) >= 10 THEN 'N' ELSE '{Sanitize(config.IdTipoIdentDefecto)}' END;
        DECLARE @ind_tercero CHAR(1) = CASE WHEN @tipo_ident = 'N' THEN '2' ELSE '{Sanitize(config.IndTipoTerceroDefecto)}' END;

        -- Insertar en @Terceros
        INSERT INTO @Terceros (F200_ID, F200_NIT, F200_ID_TIPO_IDENT, F200_IND_TIPO_TERCERO, F200_RAZON_SOCIAL, F200_APELLIDO1, F200_APELLIDO2, F200_NOMBRES, F200_NOMBRE_EST, F015_CONTACTO, F015_DIRECCION1, F015_DIRECCION2, F015_ID_PAIS, F015_ID_DEPTO, F015_ID_CIUDAD, F015_TELEFONO, F015_EMAIL, F200_FECHA_NACIMIENTO, F200_ID_CIIU, F015_CELULAR)
        VALUES (LEFT(@id_cliente, 15), LEFT(@id_cliente, 25), @tipo_ident, @ind_tercero, @razon_social, @apellido1, @apellido2, @nombres, LEFT(@razon_social, 50), LEFT(@razon_social, 50), @direccion1, @direccion2, ISNULL(@id_pais_erp, @id_pais_defecto), ISNULL(@id_dptos_erp, @id_dpto_defecto), ISNULL(@id_ciudad_erp, @id_ciudad_defecto), @telefono, @email, @fecha, '{Sanitize(config.IdCiiu)}', @telefono);

        -- Insertar en @Clientes
        INSERT INTO @Clientes (F201_ID_TERCERO, F201_ID_SUCURSAL, F201_DESCRIPCION_SUCURSAL, F201_ID_MONEDA, F201_ID_LISTA_PRECIO, F015_CONTACTO, F015_DIRECCION1, F015_DIRECCION2, F015_ID_PAIS, F015_ID_DEPTO, F015_ID_CIUDAD, F015_TELEFONO, F015_EMAIL, F201_FECHA_INGRESO, f015_celular)
        VALUES (LEFT(@id_cliente, 15), @IdSucursal, LEFT(@razon_social, 40), 'COP', '{Sanitize(config.IdListaPrecio)}', LEFT(@razon_social, 50), @direccion1, @direccion2, ISNULL(@id_pais_erp, @id_pais_defecto), ISNULL(@id_dptos_erp, @id_dpto_defecto), ISNULL(@id_ciudad_erp, @id_ciudad_defecto), @telefono, @email, @fecha, @telefono);

        -- Impuestos
");
            foreach (var tax in config.Taxes)
            {
                sb.AppendLine($@"        INSERT INTO @Impuestos (F_TIPO_REG, F_ID_TERCERO, F_ID_SUCURSAL, F_ID_CLASE, F_ID_VALOR_TERCERO) VALUES ('{Sanitize(tax.TipoReg)}', @id_cliente, @IdSucursal, '{Sanitize(tax.Clase)}', '{Sanitize(tax.ValorTercero)}');");
            }

            // Entidades Dinámicas
            foreach (var entity in config.DynamicEntities)
            {
                sb.AppendLine($@"        INSERT INTO @EntDinamica (f200_id, f753_id_grupo_entidad, f753_id_entidad, f753_id_atributo, f753_id_maestro, f753_id_maestro_detalle) VALUES (@id_cliente, '{Sanitize(entity.GrupoEntidad)}', '{Sanitize(entity.IdEntidad)}', '{Sanitize(entity.IdAtributo)}', '{Sanitize(entity.IdMaestro)}', '{Sanitize(entity.IdMaestroDetalle)}');");
            }

            sb.AppendLine($@"
        -- Generar JSON final para esta orden
        INSERT INTO @final (idDocumento, descripcion, indicaParalelismo, idOrden, json)
        SELECT @idDocumento, @descripcionConector, @indicaParalelismo, @order,
        (
            SELECT [Terceros] = (SELECT * FROM @Terceros FOR JSON PATH, INCLUDE_NULL_VALUES),
                   [Clientes] = (SELECT * FROM @Clientes FOR JSON PATH, INCLUDE_NULL_VALUES),
                   [ImptosyReten] = (SELECT * FROM @Impuestos FOR JSON PATH, INCLUDE_NULL_VALUES),
                   [EntDinamicaTercero] = (SELECT * FROM @EntDinamica FOR JSON PATH, INCLUDE_NULL_VALUES)
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );

        DELETE FROM @Terceros;
        DELETE FROM @Clientes;
        DELETE FROM @Impuestos;
        DELETE FROM @EntDinamica;

        SET @counter = @counter + 1;
    END

    SELECT * FROM @final;
END TRY
BEGIN CATCH
    SELECT indicaError = CAST(1 AS BIT), descripcionError = CONCAT('Error: ', ERROR_MESSAGE())
END CATCH
");

            return sb.ToString();
        }
    }
}
