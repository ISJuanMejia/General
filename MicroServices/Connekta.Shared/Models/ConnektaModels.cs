using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace Connekta.Shared.Models
{
    public class ConnektaResponse<T>
    {
        [JsonPropertyName("success")]
        public bool Success { get; set; }

        [JsonPropertyName("message")]
        public string? Message { get; set; }

        [JsonPropertyName("data")]
        public T? Data { get; set; }
    }

    public class SystemParameter
    {
        [JsonPropertyName("nombre")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("valor")]
        public string Value { get; set; } = string.Empty;
    }

    public class InterfaceQueryResponse
    {
        [JsonPropertyName("detalle")]
        public List<InterfaceDetail> Details { get; set; } = new();
    }

    public class InterfaceDetail
    {
        [JsonPropertyName("id")]
        public int Id { get; set; }

        [JsonPropertyName("querys")]
        public List<QueryDetail> Queries { get; set; } = new();
    }

    public class QueryDetail
    {
        [JsonPropertyName("query")]
        public string Query { get; set; } = string.Empty;

        [JsonPropertyName("ejecutable")]
        public bool IsExecutable { get; set; }

        [JsonPropertyName("orderBy")]
        public int? OrderBy { get; set; }
    }

    public class LogRequest
    {
        [JsonPropertyName("idinterface")]
        public int InterfaceId { get; set; }

        [JsonPropertyName("error")]
        public string? Error { get; set; }

        [JsonPropertyName("transacciones")]
        public List<Transaction> Transactions { get; set; } = new();
    }

    public class Transaction
    {
        [JsonPropertyName("descripcion")]
        public string Description { get; set; } = string.Empty;

        [JsonPropertyName("fecha_inicio")]
        public System.DateTime StartDate { get; set; }

        [JsonPropertyName("fecha_fin")]
        public System.DateTime EndDate { get; set; }

        [JsonPropertyName("transaccion_exitosa")]
        public bool IsSuccess { get; set; }
    }
}
