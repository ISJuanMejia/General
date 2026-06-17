using Connekta.Shared.Services;
using ShopifyInventoryUpdate.Api.Repositories;
using ShopifyInventoryUpdate.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure Connekta Client based on environment variable
var connektaBaseUrl = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") == "Production"
    ? "https://servicios.siesacloud.com"
    : "https://serviciosqa.siesacloud.com";

builder.Services.AddHttpClient<IConnektaClient, ConnektaClient>(client =>
{
    client.BaseAddress = new Uri(connektaBaseUrl);
});

builder.Services.AddHttpClient<IShopifyClient, ShopifyClient>();

builder.Services.AddScoped<IInventoryRepository, InventoryRepository>();

var app = builder.Build();

// Configure the HTTP request pipeline.
// Always show Swagger for testing as requested
app.UseSwagger();
app.UseSwaggerUI();

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
