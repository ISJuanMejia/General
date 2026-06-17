using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Connekta.Shared.Models;
using Connekta.Shared.Services;
using Microsoft.AspNetCore.Mvc;
using ShopifyInventoryUpdate.Api.Models;
using ShopifyInventoryUpdate.Api.Repositories;
using ShopifyInventoryUpdate.Api.Services;

namespace ShopifyInventoryUpdate.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class InventoryUpdateController : ControllerBase
    {
        private readonly IConnektaClient _connektaClient;
        private readonly IShopifyClient _shopifyClient;
        private readonly IInventoryRepository _inventoryRepository;
        private readonly List<Transaction> _transactions = new();
        private DateTime _processStartTime;

        public InventoryUpdateController(
            IConnektaClient connektaClient,
            IShopifyClient shopifyClient,
            IInventoryRepository inventoryRepository)
        {
            _connektaClient = connektaClient;
            _shopifyClient = shopifyClient;
            _inventoryRepository = inventoryRepository;
        }

        [HttpPost("process")]
        public async Task<IActionResult> ProcessUpdate(
            [FromQuery] string urlTienda,
            [FromQuery] int idInterfaz,
            [FromQuery] int idCompania,
            [FromQuery] int idSistema,
            [FromQuery] int batchSize = 250,
            [FromHeader] string? conniKey = null,
            [FromHeader] string? conniToken = null)
        {
            _processStartTime = DateTime.UtcNow;
            string? errorMessage = null;

            try
            {
                // 1. Fetch parameters from Connekta
                var parameters = await _connektaClient.GetParametersAsync(idCompania, idSistema, conniKey!, conniToken!);

                var shopUrl = parameters.FirstOrDefault(p => p.Name == "UrlTienda")?.Value ?? urlTienda;
                var accessToken = parameters.FirstOrDefault(p => p.Name == "APIAccessToken")?.Value;
                var apiVersion = parameters.FirstOrDefault(p => p.Name == "VersionAPI")?.Value;
                var dbConnectionString = parameters.FirstOrDefault(p => p.Name == "ConnectionString")?.Value;

                if (string.IsNullOrEmpty(accessToken))
                    throw new Exception("APIAccessToken not found in Connekta parameters.");

                if (string.IsNullOrEmpty(dbConnectionString))
                    throw new Exception("ConnectionString not found in Connekta parameters.");

                // 2. Fetch Active Warehouses
                var activeWarehouses = await _inventoryRepository.GetActiveWarehousesAsync(dbConnectionString);
                var activeWarehouseCodes = activeWarehouses.Select(w => w.WarehouseErp).ToList();

                if (!activeWarehouseCodes.Any())
                {
                    AddTransactionLog("No active warehouses found for Shopify sync.", true);
                    return Ok(new { success = true, transactions = _transactions });
                }

                // 3. Fetch Pending Inventory
                var pendingInventory = await _inventoryRepository.GetPendingInventoryAsync(dbConnectionString, activeWarehouseCodes);
                var inventoryList = pendingInventory.ToList();

                if (!inventoryList.Any())
                {
                    AddTransactionLog("No pending inventory records to update.", true);
                }
                else
                {
                    // 4. Fetch and Apply Location Validations
                    var validations = await _inventoryRepository.GetLocationValidationsAsync(dbConnectionString);
                    var validLocationSet = validations
                        .GroupBy(v => new { v.InventoryItemId, v.LocationId })
                        .Select(g => g.OrderByDescending(v => v.ValidationDate).First())
                        .Where(v => v.StockedAtLocation)
                        .Select(v => (v.InventoryItemId, v.LocationId))
                        .ToHashSet();

                    var eligibleInventory = new List<InventoryRecord>();
                    var skippedCount = 0;

                    foreach (var record in inventoryList)
                    {
                        try
                        {
                            var item = JsonSerializer.Deserialize<InventoryItem>(record.InventoryObj);
                            if (item != null &&
                                long.TryParse(item.InventoryItemId, out var invItemId) &&
                                long.TryParse(item.LocationId, out var locId) &&
                                validLocationSet.Contains((invItemId, locId)))
                            {
                                eligibleInventory.Add(record);
                            }
                            else
                            {
                                skippedCount++;
                            }
                        }
                        catch
                        {
                            skippedCount++;
                        }
                    }

                    if (skippedCount > 0)
                    {
                        AddTransactionLog($"{skippedCount} inventory records omitted: location not valid in Shopify.", false);
                    }

                    if (!eligibleInventory.Any())
                    {
                        AddTransactionLog("No eligible inventory records after location validation.", true);
                    }
                    else
                    {
                        // 5. Batch processing
                        var batches = eligibleInventory
                            .Select((item, index) => new { item, index })
                            .GroupBy(x => x.index / batchSize)
                            .Select(g => g.Select(x => x.item).ToList())
                            .ToList();

                        foreach (var batch in batches)
                        {
                            var itemsToUpdate = new List<InventoryItem>();
                            var validRecordsInBatch = new List<InventoryRecord>();

                            foreach (var record in batch)
                            {
                                var item = JsonSerializer.Deserialize<InventoryItem>(record.InventoryObj);
                                if (item != null)
                                {
                                    itemsToUpdate.Add(item);
                                    validRecordsInBatch.Add(record);
                                }
                            }

                            if (itemsToUpdate.Any())
                            {
                                var (success, error) = await _shopifyClient.UpdateInventoryAsync(shopUrl, accessToken, apiVersion!, itemsToUpdate);

                                if (success)
                                {
                                    foreach (var record in validRecordsInBatch)
                                    {
                                        await _inventoryRepository.UpdateInventoryStatusAsync(dbConnectionString, record.Id, true);
                                    }
                                    AddTransactionLog($"Successfully updated batch of {itemsToUpdate.Count} items.", true);
                                }
                                else
                                {
                                    AddTransactionLog($"Failed to update batch: {error}. Retrying individually.", false);
                                    await ProcessIndividualItems(shopUrl, accessToken, apiVersion!, validRecordsInBatch, dbConnectionString);
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                errorMessage = ex.Message;
                AddTransactionLog($"Critical Error: {ex.Message}", false);
            }
            finally
            {
                // 6. Send logs to Connekta
                try
                {
                    var logRequest = new LogRequest
                    {
                        InterfaceId = idInterfaz,
                        Error = errorMessage ?? (_transactions.Any(t => !t.IsSuccess) ? "Processing errors occurred" : null),
                        Transactions = _transactions
                    };
                    await _connektaClient.PostLogAsync(idCompania, logRequest, conniKey!, conniToken!);
                }
                catch (Exception logEx)
                {
                    Console.WriteLine($"Failed to post logs to Connekta: {logEx.Message}");
                }
            }

            return Ok(new { success = errorMessage == null, transactions = _transactions });
        }

        private async Task ProcessIndividualItems(string shopUrl, string accessToken, string apiVersion, List<InventoryRecord> items, string connectionString)
        {
            foreach (var record in items)
            {
                try
                {
                    var item = JsonSerializer.Deserialize<InventoryItem>(record.InventoryObj);
                    if (item != null)
                    {
                        var (success, error) = await _shopifyClient.UpdateInventoryAsync(shopUrl, accessToken, apiVersion, new List<InventoryItem> { item });
                        if (success)
                        {
                            await _inventoryRepository.UpdateInventoryStatusAsync(connectionString, record.Id, true);
                            AddTransactionLog($"Successfully updated item ID {record.Id} individually.", true);
                        }
                        else
                        {
                            AddTransactionLog($"Failed to update item ID {record.Id}: {error}", false);
                        }
                    }
                }
                catch (Exception ex)
                {
                    AddTransactionLog($"Error processing individual item ID {record.Id}: {ex.Message}", false);
                }
            }
        }

        private void AddTransactionLog(string description, bool success)
        {
            _transactions.Add(new Transaction
            {
                Description = Regex.Replace(description, "[\"'.{}\\r\\n]", " "),
                StartDate = _processStartTime.ToUniversalTime(),
                EndDate = DateTime.UtcNow.ToUniversalTime(),
                IsSuccess = success
            });
        }
    }
}
