namespace QueryGenerator.Api.Models
{
    public class QueryConfiguration
    {
        public string ClientName { get; set; } = "Standard";
        public int IdDocumento { get; set; } = 200000;
        public string DescripcionConector { get; set; } = "Ecommerce_Terceros_Clientes";
        public bool IndicaParalelismo { get; set; } = true;
        public string IdSucursal { get; set; } = "001";
        public string IdListaPrecio { get; set; } = "001";
        public int ClientOriginData { get; set; } = 4; // 1: Customer, 2: Billing, 3: Customer/Billing, 4: Billing/Customer
        public int LocationOriginData { get; set; } = 1; // 1: Customer, 2: Billing, 3: Shipping
        public string IdPaisDefecto { get; set; } = "169";
        public string IdDptoDefecto { get; set; } = "05";
        public string IdCiudadDefecto { get; set; } = "001";
        public string IdTipoIdentDefecto { get; set; } = "C";
        public string IndTipoTerceroDefecto { get; set; } = "1";
        public bool ProcessClientWithoutId { get; set; } = false;
        public string IdCiiu { get; set; } = "0081";
        public List<TaxConfig> Taxes { get; set; } = new();
        public List<DynamicEntityConfig> DynamicEntities { get; set; } = new();
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
}
