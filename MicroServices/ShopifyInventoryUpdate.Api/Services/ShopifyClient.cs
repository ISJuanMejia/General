using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using ShopifyInventoryUpdate.Api.Models;

namespace ShopifyInventoryUpdate.Api.Services
{
    public interface IShopifyClient
    {
        Task<(bool Success, string Error)> UpdateInventoryAsync(string shopUrl, string accessToken, string apiVersion, List<InventoryItem> items);
    }

    public class ShopifyClient : IShopifyClient
    {
        private readonly HttpClient _httpClient;

        public ShopifyClient(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<(bool Success, string Error)> UpdateInventoryAsync(string shopUrl, string accessToken, string apiVersion, List<InventoryItem> items)
        {
            try
            {
                var url = $"{shopUrl.TrimEnd('/')}/{(apiVersion ?? "2024-01")}/graphql.json";

                var quantities = items.Select(item => new
                {
                    inventoryItemId = item.InventoryItemId.StartsWith("gid://") ? item.InventoryItemId : $"gid://shopify/InventoryItem/{item.InventoryItemId}",
                    locationId = item.LocationId.StartsWith("gid://") ? item.LocationId : $"gid://shopify/Location/{item.LocationId}",
                    quantity = item.Available
                }).ToList();

                var mutation = new
                {
                    query = @"mutation inventorySetQuantities($input: InventorySetQuantitiesInput!) {
                        inventorySetQuantities(input: $input) {
                            userErrors { field message }
                        }
                    }",
                    variables = new
                    {
                        input = new
                        {
                            name = "available",
                            reason = "correction",
                            ignoreCompareQuantity = true,
                            quantities = quantities
                        }
                    }
                };

                var request = new HttpRequestMessage(HttpMethod.Post, url);
                request.Headers.Add("X-Shopify-Access-Token", accessToken);
                request.Content = new StringContent(JsonSerializer.Serialize(mutation), Encoding.UTF8, "application/json");

                var response = await _httpClient.SendAsync(request);
                var body = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                    return (false, $"Shopify API Error: {response.StatusCode} - {body}");

                using var doc = JsonDocument.Parse(body);
                if (doc.RootElement.TryGetProperty("errors", out var errors))
                {
                    return (false, errors.ToString());
                }

                var data = doc.RootElement.GetProperty("data");
                var inventorySetQuantities = data.GetProperty("inventorySetQuantities");
                var userErrors = inventorySetQuantities.GetProperty("userErrors");

                if (userErrors.GetArrayLength() > 0)
                {
                    var firstError = userErrors[0].GetProperty("message").GetString();
                    return (false, firstError ?? "Unknown User Error");
                }

                return (true, string.Empty);
            }
            catch (Exception ex)
            {
                return (false, ex.Message);
            }
        }
    }
}
