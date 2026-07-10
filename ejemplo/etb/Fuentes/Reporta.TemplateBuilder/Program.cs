using Reporta.TemplateBuilder.Components;
using SsidArqNet.Ateka.PublisherProxy.Extensions;
using SsidArqNet.InternalComponents.Blazor.TemplateBuilder;
using SsidArqNet.InternalComponents.Blazor.TemplateBuilder.Extensions;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

// Configura el proxy definido en appsettings.json, necesario para que la autenticaci�n mediante ATEKA funcione correctamente.

builder.AddSsidArqNetAtekaProxyFromAppSettings();

// Configura los servicios de Blazor Server y el modo de renderizado, habilitando el detalle de errores.

builder
    .Services.AddRazorComponents(configure: options => options.DetailedErrors = true)
    .AddInteractiveServerComponents()
    .AddCircuitOptions(configure: options => options.DetailedErrors = true);

// Configura los servicios comunes de la arquitectura, utilizando paquetes NuGet personalizados e inyecci�n de dependencias.

builder.Services.ConfigurarTemplateBuilderInternalComponentDesdeAppSettings(
    configuration: builder.Configuration
);

/*===================================================*/

WebApplication app = builder.Build();

// Aplica el middleware del proxy a partir de appsettings.json.

app.UseSsidArqNetProxy();

// Configura el uso del middleware de excepciones en producci�n.

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler(errorHandlingPath: "/Error", createScopeForErrors: true);
}

// Configura la redirecci�n a HTTPS, los archivos est�ticos, y el middleware de antifalsificaci�n.

app.UseHttpsRedirection().UseHsts();
app.UseStaticFiles().UseAntiforgery();

// Configura el componente ra�z y el modo de renderizado

app
    .MapRazorComponents<App>()
    .AddInteractiveServerRenderMode()
    .AddAdditionalAssemblies(TemplateBuilderBlazorRegistration.Assemblies);

await app.RunAsync();
