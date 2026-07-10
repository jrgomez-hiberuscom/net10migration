using Reporta.TemplateBuilder.Components;
using SsidArqNet.Ateka.PublisherProxy.Extensions;
using SsidArqNet.InternalComponents.Blazor.TemplateBuilder;
using SsidArqNet.InternalComponents.Blazor.TemplateBuilder.Extensions;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

// Configura el proxy definido en appsettings.json, necesario para que la autenticación mediante ATEKA funcione correctamente.

builder.ConfigurarProxyDesdeAppSettings();

// Configura los servicios de Blazor Server y el modo de renderizado, habilitando el detalle de errores.

builder
    .Services.AddRazorComponents(configure: options => options.DetailedErrors = true)
    .AddInteractiveServerComponents()
    .AddCircuitOptions(configure: options => options.DetailedErrors = true);

// Configura los servicios comunes de la arquitectura, utilizando paquetes NuGet personalizados e inyección de dependencias.

builder.Services.ConfigurarTemplateBuilderInternalComponentDesdeAppSettings(
    configuration: builder.Configuration
);

/*===================================================*/

WebApplication app = builder.Build();

// Aplica el middleware del proxy a partir de appsettings.json.

app.UsarProxyDesdeAppSettings();

// Configura el uso del middleware de excepciones en producción.

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler(errorHandlingPath: "/Error", createScopeForErrors: true);
}

// Configura la redirección a HTTPS, los archivos estáticos, y el middleware de antifalsificación.

app.UseHttpsRedirection().UseHsts();
app.UseStaticFiles().UseAntiforgery();

// Configura el componente raíz y el modo de renderizado

app
    .MapRazorComponents<App>()
    .AddInteractiveServerRenderMode()
    .AddAdditionalAssemblies(TemplateBuilderBlazorRegistration.Assemblies);

await app.RunAsync();
