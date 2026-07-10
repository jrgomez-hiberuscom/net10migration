using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Newtonsoft.Json;
using SsidArqNet.Ateka.TokenExchanger.Extensions;
using SsidArqNet.InternalComponents.Blazor.TemplateBuilder.Options;
using SsidArqNet.InternalComponents.Blazor.TemplateBuilder.Services.Impl;
using SsidArqNet.OpenApiClient.Core.Contracts;
using SsidArqNet.OpenApiClient.Net.Extensions;
using SsidArqNet.Reporta.Components.OpenApi.Reporta;

namespace SsidArqNet.Reporta.Components.UnitTest;

public class ConectividadReportaTest : Bunit.TestContext
{
    private const string EndpointHealth = "health";

    private IConfigurationSection? _templateBuilderSection;
    private string? _urlReporta;
    private string? _idConversorString;

    private IReportaOpenApiClient _reportaOpenApiClient;

    [OneTimeSetUp]
    public void OneTimeSetup()
    {
        // Recuperamos la configuración desde el fichero appsettings.json

        IConfigurationRoot configuration = new ConfigurationBuilder()
            .AddJsonFile(path: "appsettings.json", optional: false, reloadOnChange: false)
            .Build();

        _templateBuilderSection = configuration.GetSection(
            key: InternalComponentsBlazorTemplateBuilderOptions.SectionName
        );

        _urlReporta = _templateBuilderSection[
            nameof(InternalComponentsBlazorTemplateBuilderOptions.UrlReporta)
        ];
        _idConversorString = _templateBuilderSection[
            nameof(InternalComponentsBlazorTemplateBuilderOptions.IdConversor)
        ];

        // Configuramos el servicio de encargado de obtener el token de ATEKA

        Services.AddScoped<ITokenAtekaService, TokenAtekaService>();
        Services.AddSsidArqNetTokenExchangerFromSettings(configuration: configuration);

        // Configuramos el cliente de OpenApi para Reporta

        Services.AddSsidArqNetOpenApiClientFromAppSettings(
            configuration: configuration,
            defaultAssembly: typeof(IReportaOpenApiClient).Assembly
        );

        // Obtenemos el cliente de Reporta

        _reportaOpenApiClient = Services.GetRequiredService<IReportaOpenApiClient>();
    }

    [Test]
    public async Task DADO_ConfiguracionAppsetting_CUANDO_SeInvocaEndpointHealthReporta_ENTONCES_RespondeHealthy()
    {
        ////////////////////
        // Arrange && Act //
        ////////////////////

        string? response = null;

        Func<Task> action = async () => response = await _reportaOpenApiClient.HealthAsync();

        ////////////
        // Assert //
        ////////////

        // Verificamos que la API responde correctamente

        await action
            .Should()
            .NotThrowAsync<HttpRequestException>(
                because: $"El endpoint /{EndpointHealth} debe responder correctamente."
            );

        // Verificamos que la respuesta es "Healthy"

        response
            .Should()
            .Be(expected: "Healthy", because: "El endpoint de health debe responder \"Healthy\".");
    }

    [Test]
    public void DADO_ConfiguracionAppsetting_CUANDO_SeRecuperaLaUrlReporta_ENTONCES_EsUrlValida()
    {
        ////////////////////
        // Arrange && Act //
        ////////////////////

        // Obtenemos la url del servicio Reporta desde la configuración

        string? urlReporta = _templateBuilderSection is not null
            ? _templateBuilderSection[key: "UrlReporta"]
            : null;

        ////////////
        // Assert //
        ////////////

        // Verificamos que la sección de configuración del paquete existe

        _templateBuilderSection
            .Should()
            .NotBeNull(
                because: "La sección de configuracion \"SsidArqNet.InternalComponents.Blazor.TemplateBuilder\" debe existir."
            );

        // Verificamos que el parámetro UrlReporta existe y es una URL válida

        _urlReporta
            .Should()
            .NotBeNull(
                because: "El parámetro \"UrlReporta\" debe estar definido en la configuración."
            );

        EsUriHttpAbsolutaValida(_urlReporta)
            .Should()
            .BeTrue(
                because: "El parámetro \"UrlReporta\" debe ser una URL absoluta válida con esquema http o https."
            );
    }

    private static bool EsUriHttpAbsolutaValida(string uriString)
    {
        return !string.IsNullOrWhiteSpace(uriString)
            && Uri.TryCreate(uriString, UriKind.Absolute, out Uri? uri)
            && (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps);
    }

    [Test]
    public async Task DADO_IdConversorDesdeAppsettings_CUANDO_SeConsultaApiConversores_ENTONCES_ElIdDebeSerValidoYExistir()
    {
        ///////////////////
        // Arrange & Act //
        ///////////////////

        // Llamamos al endpoint que devuelve la lista de conversores disponibles en la API

        ICollection<GetAllConversorAsyncResponseDto>? conversores =
            await _reportaOpenApiClient.ConversoresGetAsync();

        ////////////
        // Assert //
        ////////////

        // Verificamos que la API responde correctamente

        conversores
            .Should()
            .NotBeNullOrEmpty(
                because: "No se ha podido obtener la lista de conversores desde la API."
            );

        // Verificamos que el IdConversor proporcionado existe y es un número válido

        int idConversor;

        bool esValidoIdConversor = int.TryParse(_idConversorString, out idConversor);

        esValidoIdConversor
            .Should()
            .BeTrue(because: "El parámetro \"IdConversor\" debe ser un numero.");

        idConversor
            .Should()
            .BeGreaterThanOrEqualTo(
                expected: 0,
                because: "El parámetro \"IdConversor\" debe ser un número mayor que 0."
            );

        // Verificamos que la lista de conversores contiene el conversor con el identificador proporcionado

        conversores
            .Should()
            .NotBeNull()
            .And.NotBeEmpty(because: "No se ha encontrado ningún conversor disponible en la API.");

        conversores!
            .Any(predicate: x => x.Id == idConversor)
            .Should()
            .BeTrue(
                because: "El conversor especificado en el parámetro \"IdConversor\" no está disponible en la API."
            );
    }

    [Test]
    public async Task DADO_TemplateBuilderConfig_CUANDO_SeInvocaEndpointConversor_ENTONCES_ResponseConContenidoValido()
    {
        /////////////
        // Arrange //
        /////////////

        // Obtenemos el identificador del conversor desde la configuración

        int idConversor = Convert.ToInt16(value: _idConversorString);
        TipoConversorDto tipoConversor = (TipoConversorDto)idConversor;

        // Obtenemos el resultado esperado de la conversión desde un fichero JSON

        string jsonContent = File.ReadAllText(path: "PlantillaEjemplo/LLamadaConversorPrueba.json");

        GetConversorSolicitudAsyncRequestDto? requestDto =
            JsonConvert.DeserializeObject<GetConversorSolicitudAsyncRequestDto>(value: jsonContent);

        /////////
        // Act //
        /////////

        // Llamamos al endpoint que realiza la conversión en la API

        GetConversorSolicitudAsyncResponseDto? responseDto =
            await _reportaOpenApiClient.ConversoresSolicitudAsync(tipoConversor, requestDto);

        ////////////
        // Assert //
        ////////////

        // Verificamos que la API responde correctamente

        responseDto
            .Should()
            .NotBeNull(because: $"El endpoint de conversores debe responder correctamente.");

        // Verificamos que el contenido del dto es correcto

        responseDto
            .Should()
            .NotBeNull(
                because: "El contenido devuelto debe ser deserializable al DTO de respuesta."
            );

        responseDto
            .TipoContenido.Should()
            .NotBeNullOrWhiteSpace(
                because: "La respuesta debe incluir el ContentType del contenido."
            );

        responseDto
            .Contenido.Should()
            .NotBeNullOrEmpty(
                because: "La respuesta debe incluir el resultado del conversor (byte[] no vacío)."
            );
    }
}
