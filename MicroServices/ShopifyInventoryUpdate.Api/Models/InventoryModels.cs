using System.Text.Json.Serialization;

namespace ShopifyInventoryUpdate.Api.Models
{
    public class InventoryItem
    {
        [JsonPropertyName("location_id")]
        public string LocationId { get; set; } = string.Empty;

        [JsonPropertyName("inventory_item_id")]
        public string InventoryItemId { get; set; } = string.Empty;

        [JsonPropertyName("available")]
        public int Available { get; set; }
    }

    public class InventoryRecord
    {
        public int Id { get; set; }
        public string VariantId { get; set; } = string.Empty;
        public string Warehouse { get; set; } = string.Empty;
        public string ErpSku { get; set; } = string.Empty;
        public string InventoryObj { get; set; } = string.Empty;
        public bool Synchronized { get; set; }
        public System.DateTime? SynchronizationDate { get; set; }
    }

    public class WarehouseRecord
    {
        public string WarehouseErp { get; set; } = string.Empty;
        public bool IsActive { get; set; }
        public bool IsActiveShopify { get; set; }
    }

    public class InventoryLocationValidation
    {
        public long InventoryItemId { get; set; }
        public long LocationId { get; set; }
        public bool StockedAtLocation { get; set; }
        public string? ErrorMessage { get; set; }
        public System.DateTime ValidationDate { get; set; }
    }
}
