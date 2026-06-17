using System;
using System.Collections.Generic;
using System.Data;
using Microsoft.Data.SqlClient;
using System.Threading.Tasks;
using Dapper;
using ShopifyInventoryUpdate.Api.Models;

namespace ShopifyInventoryUpdate.Api.Repositories
{
    public interface IInventoryRepository
    {
        Task<IEnumerable<InventoryRecord>> GetPendingInventoryAsync(string connectionString, IEnumerable<string> activeWarehouses);
        Task UpdateInventoryStatusAsync(string connectionString, int id, bool synchronized);
        Task<IEnumerable<WarehouseRecord>> GetActiveWarehousesAsync(string connectionString);
        Task<IEnumerable<InventoryLocationValidation>> GetLocationValidationsAsync(string connectionString);
    }

    public class InventoryRepository : IInventoryRepository
    {
        public async Task<IEnumerable<InventoryRecord>> GetPendingInventoryAsync(string connectionString, IEnumerable<string> activeWarehouses)
        {
            using IDbConnection db = new SqlConnection(connectionString);
            string query = "SELECT id as Id, id_variante as VariantId, bodega as Warehouse, sku_erp as ErpSku, inventario_obj as InventoryObj, sincronizado as Synchronized, fecha_sincronizacion as SynchronizationDate FROM inventarios WHERE sincronizado = 0 AND bodega IN @activeWarehouses";
            return await db.QueryAsync<InventoryRecord>(query, new { activeWarehouses });
        }

        public async Task UpdateInventoryStatusAsync(string connectionString, int id, bool synchronized)
        {
            using IDbConnection db = new SqlConnection(connectionString);
            string query = "UPDATE inventarios SET sincronizado = @synchronized, fecha_sincronizacion = @date WHERE id = @id";
            await db.ExecuteAsync(query, new { synchronized, date = DateTime.Now, id });
        }

        public async Task<IEnumerable<WarehouseRecord>> GetActiveWarehousesAsync(string connectionString)
        {
            using IDbConnection db = new SqlConnection(connectionString);
            string query = "SELECT bodega_erp as WarehouseErp, is_active as IsActive, is_active_shopify as IsActiveShopify FROM bodegas WHERE is_active = 1 AND is_active_shopify = 1";
            return await db.QueryAsync<WarehouseRecord>(query);
        }

        public async Task<IEnumerable<InventoryLocationValidation>> GetLocationValidationsAsync(string connectionString)
        {
            using IDbConnection db = new SqlConnection(connectionString);
            string query = "SELECT InventoryItemId, LocationId, StockedAtLocation, ErrorMessage, ValidationDate FROM shopifyInventoryLocationValidation WHERE StockedAtLocation = 1 AND ErrorMessage IS NULL";
            return await db.QueryAsync<InventoryLocationValidation>(query);
        }
    }
}
