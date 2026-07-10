using Bunit;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.JSInterop;
using Newtonsoft.Json;
using Reporta.Templates.GAT_SSID.SsidArqNet.ReporteSimple;
using SsidArqNet.InternalComponents.Blazor.TemplateBuilder.Components.Renderizador;
using SsidArqNet.InternalComponents.Blazor.TemplateBuilder.Extensions;
using static Reporta.Templates.GAT_SSID.SsidArqNet.ReporteSimple.PlantillaReporteSimple;

namespace Reporta.TemplateBuilder.Test.Unit;

public class PruebaBasicaRenderizadoTest : BunitContext
{
    [SetUp]
    public void Setup()
    {
        // Configuramos el paquete SsidArqNet.InternalComponents.Blazor.TemplateBuilder desde el archivo appsettings.json del proyecto Reporta.TemplateBuilder

        string solutionPath = Path.GetFullPath(
            Path.Combine(Directory.GetCurrentDirectory(), "../../../../")
        );

        string appsettingsPath = Path.Combine(
            solutionPath,
            "Reporta.TemplateBuilder",
            "appsettings.json"
        );

        IConfigurationRoot configuration = new ConfigurationBuilder()
            .AddJsonFile(path: appsettingsPath, optional: false, reloadOnChange: false)
            .Build();

        Services.ConfigurarTemplateBuilderInternalComponentDesdeAppSettings(
            configuration: configuration
        );
    }

    [Test]
    public void DADO_RenderizadoDePlantillaSimpleHtml_ENTONCES_SeRenderizaElReporteCorrectamente()
    {
        /////////////
        // Arrange //
        /////////////

        // Configuramos el JSInterop para el módulo de ayuda al renderizado

        JSInterop.SetupModule(moduleName: @"./_content\SsidArqNet.InternalComponents.Blazor.TemplateBuilder\js/renderer-helper.js");

        // Cargamos el JSON de ejemplo

        string solutionPath = Path.GetFullPath(
            Path.Combine(Directory.GetCurrentDirectory(), "../../../../")
        );

        string jsonPath = Path.Combine(
            solutionPath,
            "Reporta.Templates.GAT_SSID.SsidArqNet.ReporteSimple",
            "PlantillaReporteSimple.Example.json"
        );

        string jsonEjemplo = File.ReadAllText(path: jsonPath);

        // Deserializamos el JSON para obtener el modelo

        PlantillaReporteSimpleModelo modelo =
            JsonConvert.DeserializeObject<PlantillaReporteSimpleModelo>(value: jsonEjemplo)!;

        /////////
        // Act //
        /////////

        // Renderizamos el componente

        IRenderedComponent<Renderizador> cut = Render<Renderizador>(parameterBuilder: parameters =>
            parameters
                .Add(
                    parameterSelector: r => r.ReportType,
                    value: typeof(PlantillaReporteSimple)
                )
                .Add(parameterSelector: r => r.JsonString, value: jsonEjemplo)
                .Add(parameterSelector: r => r.Renderizado_PdfApiReporta, value: false)
                .Add(parameterSelector: r => r.Renderizado_HtmlEnVentana, value: false)
                .Add(parameterSelector: r => r.Renderizado_HtmlPaginaPrincipal, value: true)
        );

        ////////////
        // Assert //
        ////////////

        cut.Markup.Should()
            .NotBeNullOrEmpty(because: "El renderizado debe generar contenido HTML");

        // Verificar que los valores del modelo aparecen en el markup renderizado

        cut.Markup.Should().Contain(expected: modelo.Nombre);
        cut.Markup.Should().Contain(expected: modelo.Apellido);
        cut.Markup.Should().Contain(expected: modelo.Edad.ToString());

        // Verificar que el HTML contiene los elementos estructurales básicos

        cut.Markup.Should()
            .Contain(
                expected: "<html>",
                because: "El componente renderizado debe contener un elemento html"
            );
        cut.Markup.Should()
            .Contain(
                expected: "<head>",
                because: "El componente renderizado debe contener un elemento head"
            );
        cut.Markup.Should()
            .Contain(
                expected: "<body>",
                because: "El componente renderizado debe contener un elemento body"
            );
    }
}
