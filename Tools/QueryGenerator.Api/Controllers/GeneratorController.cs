using Microsoft.AspNetCore.Mvc;
using QueryGenerator.Api.Models;
using QueryGenerator.Api.Services;
using System.Text;

namespace QueryGenerator.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class GeneratorController : ControllerBase
    {
        private readonly ISqlGeneratorService _sqlGeneratorService;

        public GeneratorController(ISqlGeneratorService sqlGeneratorService)
        {
            _sqlGeneratorService = sqlGeneratorService;
        }

        [HttpPost("generate")]
        public IActionResult Generate([FromBody] QueryConfiguration config)
        {
            if (config == null) return BadRequest("Invalid configuration");

            string sql = _sqlGeneratorService.GenerateSql(config);
            var bytes = Encoding.UTF8.GetBytes(sql);
            var suffix = config.QueryType == QueryType.Terceros ? "Terceros" : "Pedidos";
            var fileName = $"{config.ClientName}_{suffix}.sql";

            return File(bytes, "application/sql", fileName);
        }

        [HttpGet("template")]
        public IActionResult GetTemplate()
        {
            var config = new QueryConfiguration
            {
                ClientName = "SampleClient",
                Taxes = new List<TaxConfig>
                {
                    new TaxConfig { TipoReg = "46", Clase = "1", ValorTercero = "1" }
                },
                Payments = new List<PaymentMapping>
                {
                    new PaymentMapping { GatewayName = "Sistecredito", ErpCode = "C005" },
                    new PaymentMapping { GatewayName = "Addi Payment", ErpCode = "C004" }
                }
            };
            return Ok(config);
        }
    }
}
