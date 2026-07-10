using Microsoft.AspNetCore.Components;

namespace Reporta.TemplateBuilder.Components;

public partial class App
{
    [Inject]
    private IConfiguration Configuration { get; set; } = default!;
}
