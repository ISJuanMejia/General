using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using Connekta.Shared.Models;

namespace Connekta.Shared.Services
{
    public interface IConnektaClient
    {
        Task<List<SystemParameter>> GetParametersAsync(int companyId, int systemId, string conniKey, string conniToken);
        Task<InterfaceQueryResponse> GetQueriesAsync(int companyId, int systemId, string conniKey, string conniToken);
        Task PostLogAsync(int companyId, LogRequest logRequest, string conniKey, string conniToken);
    }

    public class ConnektaClient : IConnektaClient
    {
        private readonly HttpClient _httpClient;

        public ConnektaClient(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<List<SystemParameter>> GetParametersAsync(int companyId, int systemId, string conniKey, string conniToken)
        {
            var request = new HttpRequestMessage(HttpMethod.Get, $"/api/connekta/v3/parametrosporsistema?idCompania={companyId}&idSistema={systemId}");
            AddHeaders(request, conniKey, conniToken);

            var response = await _httpClient.SendAsync(request);
            response.EnsureSuccessStatusCode();

            return await response.Content.ReadFromJsonAsync<List<SystemParameter>>() ?? new List<SystemParameter>();
        }

        public async Task<InterfaceQueryResponse> GetQueriesAsync(int companyId, int systemId, string conniKey, string conniToken)
        {
            var request = new HttpRequestMessage(HttpMethod.Get, $"/api/connekta/v3/interfacesqueriesporsistema?idCompania={companyId}&idSistema={systemId}");
            AddHeaders(request, conniKey, conniToken);

            var response = await _httpClient.SendAsync(request);
            response.EnsureSuccessStatusCode();

            return await response.Content.ReadFromJsonAsync<InterfaceQueryResponse>() ?? new InterfaceQueryResponse();
        }

        public async Task PostLogAsync(int companyId, LogRequest logRequest, string conniKey, string conniToken)
        {
            var request = new HttpRequestMessage(HttpMethod.Post, $"/api/connekta/v3/gestionarlog?idCompania={companyId}");
            AddHeaders(request, conniKey, conniToken);
            request.Content = JsonContent.Create(logRequest);

            var response = await _httpClient.SendAsync(request);
            response.EnsureSuccessStatusCode();
        }

        private void AddHeaders(HttpRequestMessage request, string conniKey, string conniToken)
        {
            if (!string.IsNullOrEmpty(conniKey))
                request.Headers.Add("conniKey", conniKey);

            if (!string.IsNullOrEmpty(conniToken))
                request.Headers.Add("conniToken", conniToken);
        }
    }
}
