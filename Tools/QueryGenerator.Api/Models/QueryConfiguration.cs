namespace QueryGenerator.Api.Models
{
    public enum QueryType { Terceros, Pedidos }
    public enum EcommerceType { Shopify, VTEX }
    public enum AppVersion { V1, V2 }

    public class QueryConfiguration
    {
        public string ClientName { get; set; } = "Standard";
        public QueryType QueryType { get; set; } = QueryType.Terceros;
        public EcommerceType Ecommerce { get; set; } = EcommerceType.Shopify;
        public AppVersion Version { get; set; } = AppVersion.V1;

        public int IdDocumento { get; set; } = 200000;
        public string DescripcionConector { get; set; } = "Ecommerce_Terceros_Clientes";
        public bool IndicaParalelismo { get; set; } = true;

        // General
        public string IdSucursal { get; set; } = "001";
        public string IdListaPrecio { get; set; } = "001";
        public int ClientOriginData { get; set; } = 4;
        public int LocationOriginData { get; set; } = 1;
        public string IdPaisDefecto { get; set; } = "169";
        public string IdDptoDefecto { get; set; } = "05";
        public string IdCiudadDefecto { get; set; } = "001";

        // Terceros specific
        public string IdTipoIdentDefecto { get; set; } = "C";
        public string IndTipoTerceroDefecto { get; set; } = "1";
        public bool ProcessClientWithoutId { get; set; } = false;
        public string IdCiiu { get; set; } = "0081";
        public List<TaxConfig> Taxes { get; set; } = new();
        public List<DynamicEntityConfig> DynamicEntities { get; set; } = new();

        // Pedidos specific
        public string IdTipoDocto { get; set; } = "EPV";
        public string IdCo { get; set; } = "001";
        public string IdVendedor { get; set; } = "9999";
        public string UnidadMedidaItem { get; set; } = "UND";
        public string ReferenciaFlete { get; set; } = "FLETES";
        public List<PaymentMapping> Payments { get; set; } = new();
    }

    public class TaxConfig
    {
        public string TipoReg { get; set; } = "46";
        public string Clase { get; set; } = "1";
        public string ValorTercero { get; set; } = "1";
    }

    public class DynamicEntityConfig
    {
        public string GrupoEntidad { get; set; } = "FE TERCERO";
        public string IdEntidad { get; set; } = "";
        public string IdAtributo { get; set; } = "";
        public string IdMaestro { get; set; } = "";
        public string IdMaestroDetalle { get; set; } = "";
    }

    public class PaymentMapping
    {
        public string GatewayName { get; set; } = "";
        public string ErpCode { get; set; } = "";
    }
}
