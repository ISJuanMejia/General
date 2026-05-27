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

            string sql = _sqlGeneratorService.GenerateTercerosSql(config);
            var bytes = Encoding.UTF8.GetBytes(sql);
            var fileName = $"{config.ClientName}_Terceros.sql";

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
                    new TaxConfig { TipoReg = "46", Clase = "1", ValorTercero = "1" },
                    new TaxConfig { TipoReg = "47", Clase = "41", ValorTercero = "1" }
                },
                DynamicEntities = new List<DynamicEntityConfig>
                {
                    new DynamicEntityConfig { IdEntidad = "EUNOECO017", IdAtributo = "co017_codigo_regimen", IdMaestro = "MUNOECO016", IdMaestroDetalle = "49" }
                }
            };
            return Ok(config);
        }
    }
}
