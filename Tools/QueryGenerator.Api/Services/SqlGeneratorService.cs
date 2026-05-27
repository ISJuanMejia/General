using System.Text;
using QueryGenerator.Api.Models;

namespace QueryGenerator.Api.Services
{
    public interface ISqlGeneratorService
    {
        string GenerateSql(QueryConfiguration config);
    }

    public class SqlGeneratorService : ISqlGeneratorService
    {
        private string Sanitize(string? value)
        {
            if (value == null) return "";
            return value.Replace("'", "''");
        }

        public string GenerateSql(QueryConfiguration config)
        {
            if (config.QueryType == QueryType.Terceros)
                return GenerateTercerosSql(config);
            else
                return GeneratePedidosSql(config);
        }

        private string GenerateTercerosSql(QueryConfiguration config)
        {
            var sb = new StringBuilder();
            bool isVtex = config.Ecommerce == EcommerceType.VTEX;

            string idPath = isVtex ? "$.clientProfileData.document" : "$.customer.default_address.company";
            string namePath = isVtex ? "$.clientProfileData.firstName" : "$.customer.default_address.name";
            // Note: VTEX often uses firstName/lastName instead of just 'name'

            sb.AppendLine($@"/*
* SCRIPT GENERADO AUTOMÁTICAMENTE PARA: {Sanitize(config.ClientName)}
* GENERACIÓN DE TERCEROS Y CLIENTES ({config.Ecommerce})
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
        * Definición de variables para la obtención de la ubicación desde Shopify/VTEX
        * 1 = Customer/Profile, 2 = Billing, 3 = Shipping
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
        id_orden    NVARCHAR(50),
        orden_obj   NVARCHAR(MAX)
    );

    INSERT INTO @ordenes (id_orden, orden_obj)
    SELECT TOP (@batch_size) id_orden, orden_obj
    FROM ordenes
    WHERE id_estado = 1 AND intentos <= 3;

    DECLARE @total      INT = (SELECT COUNT(*) FROM @ordenes);
    DECLARE @counter    INT = 1;
    DECLARE @json       NVARCHAR(MAX);
    DECLARE @order      NVARCHAR(50);

    WHILE @counter <= @total
    BEGIN
        SET @json = (SELECT orden_obj FROM (SELECT orden_obj, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn FROM @ordenes) AS temp WHERE rn = @counter);
        SET @order = ISNULL(JSON_VALUE(@json, '$.name'), JSON_VALUE(@json, '$.orderId'));

        -- Localización
        DECLARE @base_path NVARCHAR(100) =
            CASE '{(isVtex ? "VTEX" : "SHOPIFY")}'
                WHEN 'SHOPIFY' THEN CASE @location_origin_data WHEN 1 THEN '$.customer.default_address' WHEN 2 THEN '$.billing_address' WHEN 3 THEN '$.shipping_address' ELSE '' END
                WHEN 'VTEX' THEN CASE @location_origin_data WHEN 1 THEN '$.clientProfileData' WHEN 2 THEN '$.shippingData.address' WHEN 3 THEN '$.shippingData.address' ELSE '' END
            END;

        DECLARE @pais_shopify NVARCHAR(100) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, @base_path + '{(isVtex ? ".country" : ".country")}')));
        DECLARE @dpto_shopify NVARCHAR(100) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, @base_path + '{(isVtex ? ".state" : ".province")}')));
        DECLARE @ciudad_shopify NVARCHAR(100) = dbo.fn_RemoveAccentMarks(LOWER(JSON_VALUE(@json, @base_path + '.city')));

        DECLARE @id_pais_erp NVARCHAR(3), @id_dptos_erp NVARCHAR(2), @id_ciudad_erp NVARCHAR(3);

        SELECT TOP 1 @id_pais_erp = ISNULL(f013_id_pais, @id_pais_defecto), @id_dptos_erp = ISNULL(f013_id_depto, @id_dpto_defecto), @id_ciudad_erp = ISNULL(f013_id, @id_ciudad_defecto)
        FROM locaciones_erp
        WHERE dbo.fn_RemoveAccentMarks(LOWER(f011_descripcion)) = @pais_shopify
        AND (dbo.fn_RemoveAccentMarks(LOWER(f012_descripcion)) = @dpto_shopify AND dbo.fn_RemoveAccentMarks(LOWER(f013_descripcion)) = @ciudad_shopify);

        -- Identificación del cliente
        DECLARE @id_cliente NVARCHAR(100) =
            CASE '{(isVtex ? "VTEX" : "SHOPIFY")}'
                WHEN 'SHOPIFY' THEN
                    CASE @client_origin_data
                        WHEN 1 THEN NULLIF(TRIM(JSON_VALUE(@json, '$.customer.default_address.company')), '')
                        WHEN 2 THEN NULLIF(TRIM(JSON_VALUE(@json, '$.billing_address.company')), '')
                        WHEN 3 THEN ISNULL(NULLIF(TRIM(JSON_VALUE(@json, '$.customer.default_address.company')), ''), JSON_VALUE(@json, '$.billing_address.company'))
                        WHEN 4 THEN ISNULL(NULLIF(TRIM(JSON_VALUE(@json, '$.billing_address.company')), ''), JSON_VALUE(@json, '$.customer.default_address.company'))
                    END
                WHEN 'VTEX' THEN
                    ISNULL(JSON_VALUE(@json, '$.clientProfileData.document'), JSON_VALUE(@json, '$.clientProfileData.corporateDocument'))
            END;

        IF @id_cliente IS NULL OR @id_cliente = ''
        BEGIN
            UPDATE ordenes SET intentos = intentos + 1, id_estado = CASE WHEN @process_client_without_id = 1 THEN 2 ELSE id_estado END WHERE id_orden = @order;
            SET @counter = @counter + 1;
            CONTINUE;
        END

        -- Limpiar ID
        SET @id_cliente = dbo.OnlyNumbers(@id_cliente);

        DECLARE @razon_social NVARCHAR(100) =
            CASE '{(isVtex ? "VTEX" : "SHOPIFY")}'
                WHEN 'SHOPIFY' THEN UPPER(ISNULL(JSON_VALUE(@json, '$.customer.default_address.name'), JSON_VALUE(@json, '$.billing_address.name')))
                WHEN 'VTEX' THEN UPPER(CONCAT(JSON_VALUE(@json, '$.clientProfileData.firstName'), ' ', JSON_VALUE(@json, '$.clientProfileData.lastName')))
            END;

        DECLARE @nombres NVARCHAR(40) =
            CASE '{(isVtex ? "VTEX" : "SHOPIFY")}'
                WHEN 'SHOPIFY' THEN UPPER(ISNULL(JSON_VALUE(@json, '$.customer.default_address.first_name'), JSON_VALUE(@json, '$.billing_address.first_name')))
                WHEN 'VTEX' THEN UPPER(JSON_VALUE(@json, '$.clientProfileData.firstName'))
            END;

        DECLARE @apellidos NVARCHAR(80) =
            CASE '{(isVtex ? "VTEX" : "SHOPIFY")}'
                WHEN 'SHOPIFY' THEN UPPER(ISNULL(JSON_VALUE(@json, '$.customer.default_address.last_name'), JSON_VALUE(@json, '$.billing_address.last_name')))
                WHEN 'VTEX' THEN UPPER(JSON_VALUE(@json, '$.clientProfileData.lastName'))
            END;

        DECLARE @apellido1 NVARCHAR(29) = LEFT(@apellidos, CHARINDEX(' ', @apellidos + ' ') - 1);
        DECLARE @apellido2 NVARCHAR(29) = LTRIM(SUBSTRING(@apellidos, CHARINDEX(' ', @apellidos + ' '), LEN(@apellidos)));

        DECLARE @direccion1 NVARCHAR(40) =
            CASE '{(isVtex ? "VTEX" : "SHOPIFY")}'
                WHEN 'SHOPIFY' THEN LEFT(UPPER(ISNULL(JSON_VALUE(@json, @base_path + '.address1'), '')), 40)
                WHEN 'VTEX' THEN LEFT(UPPER(ISNULL(JSON_VALUE(@json, @base_path + '.street'), '')), 40)
            END;
        DECLARE @direccion2 NVARCHAR(40) =
            CASE '{(isVtex ? "VTEX" : "SHOPIFY")}'
                WHEN 'SHOPIFY' THEN LEFT(UPPER(ISNULL(JSON_VALUE(@json, @base_path + '.address2'), '')), 40)
                WHEN 'VTEX' THEN LEFT(UPPER(ISNULL(JSON_VALUE(@json, @base_path + '.complement'), '')), 40)
            END;

        DECLARE @telefono NVARCHAR(20) = REPLACE(ISNULL(JSON_VALUE(@json, '$.customer.default_address.phone'), ISNULL(JSON_VALUE(@json, '$.clientProfileData.phone'), '')), '+57', '');
        DECLARE @email NVARCHAR(255) = ISNULL(JSON_VALUE(@json, '$.customer.email'), JSON_VALUE(@json, '$.clientProfileData.email'));
        DECLARE @fecha NVARCHAR(8) = REPLACE(CONVERT(VARCHAR(10), CAST(ISNULL(JSON_VALUE(@json, '$.customer.created_at'), GETDATE()) AS DATE), 120), '-', '');

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

        private string GeneratePedidosSql(QueryConfiguration config)
        {
            var sb = new StringBuilder();
            bool isVtex = config.Ecommerce == EcommerceType.VTEX;

            string itemsPath = isVtex ? "$.items" : "$.line_items";
            string skuPath = isVtex ? "$.refId" : "$.sku"; // VTEX items often use refId or ean
            string idTerceroPath = isVtex ? "$.clientProfileData.document" : "$.billing_address.company";

            sb.AppendLine($@"/*
* SCRIPT GENERADO AUTOMÁTICAMENTE PARA: {Sanitize(config.ClientName)}
* GENERACIÓN DE PEDIDOS ({config.Ecommerce})
*/

BEGIN TRY
    SET XACT_ABORT ON;

    DECLARE @final TABLE (
        idDocumento         INT,
        indicaParalelismo   BIT,
        descripcion         VARCHAR(100),
        idOrden             VARCHAR(50),
        json                VARCHAR(MAX)
    );

    DECLARE @idDocumento        INT          = {config.IdDocumento},
            @indicaParalelismo  BIT          = {(config.IndicaParalelismo ? 1 : 0)},
            @descripcion        VARCHAR(100) = '{Sanitize(config.DescripcionConector)}';

    DECLARE @IdCo               NVARCHAR(3)  = '{Sanitize(config.IdCo)}',
            @IdTipoDocto        NVARCHAR(3)  = '{Sanitize(config.IdTipoDocto)}',
            @IdVendedor         NVARCHAR(15) = '{Sanitize(config.IdVendedor)}',
            @UnidadMedidaItem   NVARCHAR(4)  = '{Sanitize(config.UnidadMedidaItem)}',
            @ReferenciaFlete    NVARCHAR(50) = '{Sanitize(config.ReferenciaFlete)}';

    DECLARE @pedidos TABLE (
        f430_consec_docto           INT,
        f430_id_co                  NVARCHAR(3),
        f430_id_tipo_docto          NVARCHAR(3),
        f430_id_fecha               NVARCHAR(8),
        f430_id_tercero_fact        NVARCHAR(15),
        f430_id_sucursal_fact       NVARCHAR(3),
        f430_id_tercero_rem         NVARCHAR(15),
        f430_id_sucursal_rem        NVARCHAR(3),
        f430_id_tipo_cli_fact       NVARCHAR(4),
        f430_fecha_entrega          NVARCHAR(8),
        f430_referencia             NVARCHAR(50),
        f430_num_docto_referencia   NVARCHAR(50),
        f430_notas                  NVARCHAR(2000),
        f430_id_tercero_vendedor    NVARCHAR(15)
    );

    DECLARE @movimientos TABLE (
        f431_consec_docto       INT,
        f431_nro_registro       INT,
        f431_referencia_item    NVARCHAR(50),
        f431_codigo_barras      NVARCHAR(20),
        f431_id_motivo          NVARCHAR(2),
        f431_precio_unitario    DECIMAL(18,2),
        f431_cant_pedida_base   DECIMAL(18,2),
        f431_id_unidad_medida   NVARCHAR(4),
        f431_fecha_entrega      NVARCHAR(8)
    );

    DECLARE @descuentos TABLE (
        f431_nro_registro   INT,
        f432_vlr_uni        DECIMAL(18,2)
    );

    DECLARE @ordenes TABLE (
        id_orden    NVARCHAR(50),
        orden_obj   NVARCHAR(MAX)
    );

    INSERT INTO @ordenes (id_orden, orden_obj)
    SELECT TOP 25 id_orden, orden_obj FROM ordenes WHERE id_estado = 2 AND intentos <= 3;

    DECLARE @total INT = (SELECT COUNT(*) FROM @ordenes), @counter INT = 1;
    DECLARE @json NVARCHAR(MAX), @order NVARCHAR(50);

    WHILE @counter <= @total
    BEGIN
        SET @json = (SELECT orden_obj FROM (SELECT orden_obj, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn FROM @ordenes) AS temp WHERE rn = @counter);
        SET @order = ISNULL(JSON_VALUE(@json, '$.name'), JSON_VALUE(@json, '$.orderId'));

        -- Mapeo de Pago
        DECLARE @metodo_pago_ecommerce NVARCHAR(100) =
            CASE '{(isVtex ? "VTEX" : "SHOPIFY")}'
                WHEN 'SHOPIFY' THEN (SELECT TOP 1 [value] FROM OPENJSON(@json, '$.payment_gateway_names') WHERE [value] != 'gift_card')
                WHEN 'VTEX' THEN (SELECT TOP 1 JSON_VALUE(value, '$.paymentSystemName') FROM OPENJSON(@json, '$.paymentData.transactions[0].payments'))
            END;

        DECLARE @payment_code_erp NVARCHAR(4) = CASE @metodo_pago_ecommerce
");
            foreach (var p in config.Payments)
            {
                sb.AppendLine($@"            WHEN '{Sanitize(p.GatewayName)}' THEN '{Sanitize(p.ErpCode)}'");
            }
            sb.AppendLine($@"            ELSE '0001' END;

        DECLARE @id_tercero NVARCHAR(15) = ISNULL(JSON_VALUE(@json, '{idTerceroPath}'), JSON_VALUE(@json, '$.customer.default_address.company'));
        DECLARE @fecha NVARCHAR(8) = FORMAT(CAST(ISNULL(JSON_VALUE(@json, '$.created_at'), GETDATE()) AS DATE), 'yyyyMMdd');

        INSERT INTO @pedidos (f430_consec_docto, f430_id_co, f430_id_tipo_docto, f430_id_fecha, f430_id_tercero_fact, f430_id_sucursal_fact, f430_id_tercero_rem, f430_id_sucursal_rem, f430_id_tipo_cli_fact, f430_fecha_entrega, f430_referencia, f430_num_docto_referencia, f430_notas, f430_id_tercero_vendedor)
        VALUES (1, @IdCo, @IdTipoDocto, @fecha, @id_tercero, '001', @id_tercero, '001', @payment_code_erp, @fecha, @order, @order, @order, @IdVendedor);

        INSERT INTO @movimientos (f431_consec_docto, f431_nro_registro, f431_referencia_item, f431_codigo_barras, f431_id_motivo, f431_precio_unitario, f431_cant_pedida_base, f431_id_unidad_medida, f431_fecha_entrega)
        SELECT 1, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), '', JSON_VALUE(value, '{skuPath}'), '01',
            {(isVtex ? "JSON_VALUE(value, '$.price')/100.0" : "JSON_VALUE(value, '$.price')")},
            JSON_VALUE(value, '$.quantity'), @UnidadMedidaItem, @fecha
        FROM OPENJSON(@json, '{itemsPath}');

        -- Fletes
        INSERT INTO @movimientos (f431_consec_docto, f431_nro_registro, f431_referencia_item, f431_codigo_barras, f431_id_motivo, f431_precio_unitario, f431_cant_pedida_base, f431_id_unidad_medida, f431_fecha_entrega)
        SELECT 1, 0, @ReferenciaFlete, '', '01',
            CASE '{(isVtex ? "VTEX" : "SHOPIFY")}'
                WHEN 'SHOPIFY' THEN JSON_VALUE(value, '$.price')
                WHEN 'VTEX' THEN JSON_VALUE(value, '$.value')/100.0
            END, 1, 'UND', @fecha
        FROM OPENJSON(@json, '{(isVtex ? "$.totals" : "$.shipping_lines")}')
        WHERE {(isVtex ? "JSON_VALUE(value, '$.id') = 'Shipping'" : "JSON_VALUE(value, '$.price') > 0")};

        INSERT INTO @final (idDocumento, descripcion, indicaParalelismo, idOrden, json)
        SELECT @idDocumento, @descripcion, @indicaParalelismo, @order,
        (
            SELECT [Pedidos] = (SELECT * FROM @pedidos FOR JSON PATH),
                   [{(config.Version == AppVersion.V2 ? "Movimientos" : "Movto_Pedidos_comercial")}] = (SELECT * FROM @movimientos FOR JSON PATH),
                   [Descuentos] = (SELECT * FROM @descuentos FOR JSON PATH)
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        DELETE FROM @pedidos; DELETE FROM @movimientos; DELETE FROM @descuentos;
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
