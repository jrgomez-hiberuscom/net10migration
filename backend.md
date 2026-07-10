## Índice

- [1. Resumen](#1-resumen)
- [2. Tabla de tiempos estimados](#2-tabla-de-tiempos-estimados)
- [3. Estructura de la solución](#3-estructura-de-la-soluci%C3%B3n)
- [4. Migración de la solución](#4-migraci%C3%B3n-de-la-soluci%C3%B3n)
  - [Paso 1 – Prerrequisitos y preparación del entorno](#paso-1--prerrequisitos-y-preparaci%C3%B3n-del-entorno) :stopwatch: 15-45 min
    - [1.1 Instalar Visual Studio 2026 y el SDK de .NET 10](#11-instalar-visual-studio-2026-y-el-sdk-de-net-10)
    - [1.2 Crear rama de trabajo en control de versiones](#12-crear-rama-de-trabajo-en-control-de-versiones)
    - [1.3 Realizar una build limpia del proyecto en NET 8](#13-realizar-una-build-limpia-del-proyecto-en-net-8)
    - [1.4 Verificar que `Project.Build.targets` existe y está referenciado en todos los `.csproj`](#14-verificar-que-projectbuildtargets-existe-y-est%C3%A1-referenciado-en-todos-los-csproj)
    - [1.5 Verificar la centralización de versiones NuGet (`Directory.Packages.props`)](#15-verificar-la-centralizaci%C3%B3n-de-versiones-nuget-directorypackagesprops)
    - [1.6 Compilación y tests pre-migración](#16-compilaci%C3%B3n-y-tests-pre-migraci%C3%B3n)
  - [Paso 2 – Actualización del Target Framework en todos los .csproj](#paso-2--actualizaci%C3%B3n-del-target-framework-en-todos-los-csproj) :stopwatch: 15 min
  - [Paso 3 – Actualización centralizada de Paquetes NuGet (`Directory.Packages.props`)](#paso-3--actualizaci%C3%B3n-centralizada-de-paquetes-nuget-directorypackagesprops) :stopwatch: 15-45 min
    - [3.1 Ejemplos de actualizaciones estándar](#31-ejemplos-de-actualizaciones-est%C3%A1ndar)
    - [3.2 Caso especial: AutoMapper y Fluent Assertions](#32-caso-especial-automapper-y-fluent-assertions)
    - [3.3 Otros paquetes](#33-otros-paquetes)
    - [3.4 Paquetes de la arquitectura de referencia SsidArqNet (GAT-SSD)](#34-paquetes-de-la-arquitectura-de-referencia-ssidarqnet-gat-ssd)
    - [3.5 Resultado final del fichero `Directory.Packages.props`](#35-resultado-final-del-fichero-directorypackagesprops)
  - [Paso 4 – Actualización de `Program.cs` (cambio de APIs internas paquetes de GAT-SSD)](#paso-4--actualizaci%C3%B3n-de-programcs-cambio-de-apis-internas-paquetes-de-gat-ssd) :stopwatch: 15 min
    - [4.1 Cambio en la nomenclatura](#41-cambio-en-la-nomenclatura)
  - [Paso 5 – Verificación de breaking changes de EF Core 9 y 10](#paso-5--verificaci%C3%B3n-de-breaking-changes-de-ef-core-9-y-10) :stopwatch: 15-45 min
  - [Paso 6 – Revisión y actualización de los proyectos de Test](#paso-6--revisi%C3%B3n-y-actualizaci%C3%B3n-de-los-proyectos-de-test) :stopwatch: 15-30 min
  - [Paso 7 (Opcional) - Actualización del fichero de solución (`.sln` → `.slnx`)](#paso-7-opcional---actualizaci%C3%B3n-del-fichero-de-soluci%C3%B3n-sln--slnx) :stopwatch: 10 min
  - [Paso 8 – Compilación completa y corrección de errores](#paso-8--compilaci%C3%B3n-completa-y-correcci%C3%B3n-de-errores) :stopwatch: 15-60 min
  - [Paso 9 – Verificación del pipeline de CI/CD y entornos](#paso-9--verificaci%C3%B3n-del-pipeline-de-cicd-y-entornos) :stopwatch: 15-30 min
  - [Paso 10 – Prueba de conectividad (entorno de validación)](#paso-10--prueba-de-conectividad-entorno-de-validaci%C3%B3n) :stopwatch: 15-60 min
  - [Paso 11 – Merge y cierre de rama](#paso-11--merge-y-cierre-de-rama) :stopwatch: 10 min
- [5. Tabla resumen con cambios por archivo](#5-tabla-resumen-con-cambios-por-archivo)
- [6. Riesgos y consideraciones](#6-riesgos-y-consideraciones)
- [7. Checklist de migración](#7-checklist-de-migraci%C3%B3n)
- [8. Errores frecuentes y su solución](#8-errores-frecuentes-y-su-soluci%C3%B3n)

---

## 1. Resumen

El proceso de migración consiste en actualizar una solución basada en `SsidArqNet.Backend` de **.NET 8** a **.NET 10**.

Se trata de una migración que afecta a todos los proyectos de la solución y puede describirse como de **complejidad baja-media**:

- La mayor parte del trabajo es **mecánico** (cambio de versiones en ficheros de configuración).
- Existen **cambios de nombre en las APIs internas** de los paquetes `SsidArqNet.*` que requieren actualización en `Program.cs`.
- No hay cambios en la lógica de negocio (Domain, Application, CompositionRoot), en los appsettings ni en la configuración de entornos.
- Hay determinados paquetes que se deben mantener en una versión específica.

---

## 2. Tabla de tiempos estimados

| Paso | Descripción | Tiempo estimado |
|------|-------------|-----------------|
| Paso 1 | Prerrequisitos y preparación del entorno | 15-45 min |
| Paso 2 | Actualización del Target Framework en todos los `.csproj` | 15 min |
| Paso 3 | Actualización centralizada de paquetes NuGet | 15-45 min |
| Paso 4 | Actualización de `Program.cs` (cambio de APIs internas paquetes de GAT-SSD) | 15 min |
| Paso 5 | Verificación de breaking changes de EF Core 9 y 10 | 15-45 min |
| Paso 6 | Revisión y actualización de los proyectos de Test | 15-30 min |
| Paso 7 (opcional) | Actualización del fichero de solución (`.sln` → `.slnx`) | 10 min |
| Paso 8 | Compilación completa y corrección de errores | 15-60 min |
| Paso 9 | Verificación del pipeline de CI/CD y entornos | 15-30 min |
| Paso 10 | Prueba de conectividad (entorno de validación) | 15-60 min |
| Paso 11 | Merge y cierre de rama | 10 min |
| **Total estimado** | **10 pasos obligatorios + 1 paso opcional** | **2 h 25 min - 6 h 05 min** |

Los rangos propuestos contemplan la complejidad del producto:

- **Límite inferior**: producto estable, pocos acoplamientos y sin incidencias en dependencias.
- **Límite superior**: producto con mayor complejidad técnica, más integración externa o incidencias durante la validación.

Los tiempos se han estimado para un desarrollador medio que ya conoce el proyecto.

Para un desarrollador que esté comenzando en el proyecto, se recomienda multiplicar el rango por **1.5x** (total estimado: \~3 h 40 min a \~9 h 10 min con paso opcional).

> :pushpin: **Nota**: Si aparecen breaking changes inesperados en EF Core, AutoMapper o WCF que requieran cambios de código en capas de negocio, el Paso 8 puede extenderse significativamente.

---

## 3. Estructura de la solución

La solución cuenta con los siguientes proyectos organizados en capas:

```
SsidArqNet.Backend/
├── Fuentes/
│   ├── SsidArqNet.Backend.API               ← Capa de presentación (ASP.NET Core Web API)
│   ├── SsidArqNet.Backend.Application       ← Casos de uso / servicios de aplicación
│   ├── SsidArqNet.Backend.Infrastructure    ← Repositorios, EF Core, WCF, DataContext
│   ├── SsidArqNet.Backend.Domain            ← Entidades y contratos de dominio
│   ├── SsidArqNet.Backend.CompositionRoot   ← Registro de dependencias (DI)
│   ├── SsidArqNet.Backend.GlobalResources   ← Recursos globales (resx)
│   ├── SsidArqNet.Backend.Test.Arquitecture ← Tests de arquitectura
│   ├── SsidArqNet.Backend.Test.Integration  ← Tests de integración (TestHost)
│   ├── SsidArqNet.Backend.Test.Unit         ← Tests unitarios
│   └── SsidArqNet.Backend.Test.Common       ← Utilidades compartidas de test
├── Directory.Packages.props                 ← Gestión centralizada de versiones NuGet
└── Project.Build.targets                    ← Post-build (firma de ensamblados)
```

**Dependencias entre proyectos:**

[Ver archivo de dependencias de la arquitectura (abrir html con un navegador)](https://gesfuentes.admon-cfnavarra.es/repos/gruposArquitectura/gatSsid/ssidarquitecturanet/ssidarqnet.backend/-/blob/master/DependenciasSsidArqNet.BackEnd.html?ref_type=heads)

---

## 4. Migración de la solución

### Paso 1 – Prerrequisitos y preparación del entorno

**:stopwatch: Tiempo estimado: 15-45 minutos**

#### 1.1 Instalar Visual Studio 2026 y el SDK de .NET 10

Antes de iniciar cualquier cambio en el código, verificar que la máquina de desarrollo dispone del SDK correcto:

```powershell
# Verificar versiones instaladas
dotnet --list-sdks

# La salida debe incluir una versión 10.x, por ejemplo:
# 10.0.100 [C:\Program Files\dotnet\sdk]
```

Si el SDK de .NET 10 o Visual Studio 2026 no está instalado, solicitar su instalación a través de [catálogo interno](https://catalogointerno.admon-cfnavarra.es/buscar?search_api_fulltext=+Instalaci%C3%B3n+de+herramientas+del+est%C3%A1ndar+del+puesto+de+desarrollador).

#### 1.2 Crear rama de trabajo en control de versiones

```bash
git checkout -b migration_net10
```

#### 1.3 Realizar una build limpia del proyecto en NET 8

Antes de hacer cualquier cambio, compilar y ejecutar todos los tests en .NET 8 para confirmar que el punto de partida es estable:

> :warning: **Si hay tests fallando en este punto, deben corregirse antes de continuar la migración.**

#### 1.4 Verificar que `Project.Build.targets` existe y está referenciado en todos los `.csproj`

`Project.Build.targets` contiene el target de post-build para la **firma de ensamblados** (`%VSFIRMA%`). Como el fichero no sigue la convención de nombre `Directory.Build.targets`, MSBuild no lo importa automáticamente. Por ello, cada `.csproj` debe referenciarlo con un `<Import>` explícito:

```xml
<Import Project="../../Project.Build.targets" />
```

Si en la solución a migrar algún proyecto no incluye esta referencia, debe añadirse al inicio del `.csproj` antes de continuar.

**Criterio de aceptación:**

- :white_check_mark: `Project.Build.targets` existe en la raíz de la solución.
- :white_check_mark: Todos los `.csproj` contienen `<Import Project="../../Project.Build.targets" />`.

#### 1.5 Verificar la centralización de versiones NuGet (`Directory.Packages.props`)

La solución debe usar **Central Package Management** de NuGet.

Todas las versiones de paquetes deben declararse en `Directory.Packages.props`; los archivos `.csproj` deben usar `PackageReference` sin atributo `Version`.

Criterio de aceptación:

- :white_check_mark: Existe `Directory.Packages.props` en la raíz de la solución.
- :white_check_mark: El archivo contiene `ManagePackageVersionsCentrally` con valor `true`.
- :white_check_mark: No hay archivos `.csproj` con `Version=` en `PackageReference`.

#### 1.5.1 Crear y habilitar centralización de versiones NuGet si no existe

Este apartado solo aplica si la solución a migrar no dispone del archivo `Directory.Packages.props`.

En ese caso:

1. Crear `Directory.Packages.props` en la raíz con este contenido mínimo:

   ```xml
   <Project>
     <PropertyGroup>
       <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
     </PropertyGroup>
     <ItemGroup>
     </ItemGroup>
   </Project>
   ```
2. Mover a `Directory.Packages.props` las versiones que estén definidas inline en los `.csproj`.
3. Eliminar el atributo `Version` de todos los `PackageReference` en los `.csproj`.
4. Ejecutar restore y build para validar los cambios.

Criterio de aceptación:

- :white_check_mark: `Directory.Packages.props` creado en raíz.
- :white_check_mark: Centralización habilitada (`ManagePackageVersionsCentrally=true`).
- :white_check_mark: Sin `Version` inline en `PackageReference` dentro de los `.csproj`.
- :white_check_mark: Restore y build completan sin errores.

> **Nota:** Si lo prefieres, puedes pedir a un agente de IA como Copilot que realice esta tarea con un prompt similar al siguiente:
>
> <details>
> <summary>:rocket: Prompt — Centralización de paquetes .NET 10</summary>
>
> Actúa como un experto en .NET 10 y automatización de repositorios.
>
> ---
>
> ### :dart: Objetivo
>
> Centralizar completamente la gestión de versiones de NuGet usando `Directory.Packages.props` en toda la solución.
>
> ---
>
> ### :mag: Contexto
>
> - La solución puede contener múltiples proyectos (`.csproj`).
> - Puede haber versiones definidas inline en `PackageReference`.
> - Puede o no existir `Directory.Packages.props`.
>
> ---
>
> ### :gear: Tareas
>
> #### 1. Detectar si existe `Directory.Packages.props`
>
> Si **NO existe**, crea el fichero con el siguiente contenido:
>
> ```xml
> <Project>
>   <PropertyGroup>
>     <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
>   </PropertyGroup>
>   <ItemGroup>
>   </ItemGroup>
> </Project>
> ```
>
> #### 2. Eliminar versiones inline en los `.csproj`
>
> :x: Incorrecto:
>
> ```xml
> <PackageReference Include="Newtonsoft.Json" Version="13.0.1" />
> ```
>
> :white_check_mark: Correcto:
>
> ```xml
> <PackageReference Include="Newtonsoft.Json" />
> ```
>
> Validación:
>
> ```bash
> grep -R 'PackageReference.*Version=' .
> ```
>
> #### 3. Centralizar las versiones en `Directory.Packages.props`
>
> ```xml
> <Project>
>   <PropertyGroup>
>     <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
>   </PropertyGroup>
>   <ItemGroup>
>     <PackageVersion Include="Newtonsoft.Json" Version="13.0.3" />
>     <PackageVersion Include="Serilog" Version="3.1.0" />
>     <PackageVersion Include="Microsoft.EntityFrameworkCore" Version="9.0.0" />
>   </ItemGroup>
> </Project>
> ```
>
> Reglas:
>
> - Una versión por paquete.
> - Sin duplicados.
>
> ##### Criterios de aceptación
>
> - :white_check_mark: Existe `Directory.Packages.props`.
> - :white_check_mark: Centralización habilitada.
> - :white_check_mark: Ningún `.csproj` contiene `Version=`.
> - :white_check_mark: Restore completado sin warnings.
> - :white_check_mark: Build completado correctamente.
>
> </details>

#### 1.6 Compilación y tests pre-migración

Una vez realizados los puntos anteriores, conviene ejecutar una compilación limpia para garantizar que el punto de partida es correcto antes de modificar la versión del framework o los paquetes NuGet.

**Criterio de aceptación:**

- :white_check_mark: `Build succeeded` sin errores.
- :white_check_mark: El proyecto está listo para iniciar la migración a .NET 10.
- :white_check_mark: Los tests pasan.

---

### Paso 2 – Actualización del Target Framework en todos los .csproj

**:stopwatch: Tiempo estimado: 15 minutos**

Todos los proyectos de la solución deben cambiar su `<TargetFramework>` de `net8.0` a `net10.0`.

#### Cambio a realizar (en cada .csproj):

```xml
<!-- ANTES (.NET 8) -->
<TargetFramework>net8.0</TargetFramework>

<!-- DESPUÉS (.NET 10) -->
<TargetFramework>net10.0</TargetFramework>
```

> :bulb: **Tip**: Se puede usar una búsqueda o un reemplazo global en el directorio de la solución (`Ctrl+H`, sustituir: `net8` =\> `net10`).

**Criterio de aceptación:**

- :white_check_mark: Todos los `.csproj` de la solución tienen `net10.0` en `<TargetFramework>`.
- :white_check_mark: No queda ningún `<TargetFramework>net8.0</TargetFramework>` en la solución.

---

### Paso 3 – Actualización centralizada de Paquetes NuGet (`Directory.Packages.props`)

**:stopwatch: Tiempo estimado: 15-45 minutos**

El proyecto usa **Central Package Management** de NuGet, por lo que todas las versiones se gestionan en un único fichero: `Directory.Packages.props`, en la raíz de la solución. Los paquetes pueden actualizarse desde la interfaz de NuGet de forma habitual.

A continuación se detallan **todos los cambios de versión** necesarios.

#### 3.1 Ejemplos de actualizaciones estándar

| Paquete | Versión .NET 8 | Versión .NET 10 |
|---------|----------------|-----------------|
| `Microsoft.AspNetCore.Authentication.JwtBearer` | `8.0.7` | `10.0.5` |
| `Microsoft.AspNetCore.Authentication.OpenIdConnect` | `8.0.7` | `10.0.5` |
| `Microsoft.AspNetCore.Mvc.Core` | `2.2.5` | `2.3.9` |
| `Microsoft.Extensions.Configuration.Binder` | `8.0.2` | `10.0.5` |
| `Microsoft.EntityFrameworkCore` | `8.0.11` | `10.0.5` |
| `Microsoft.EntityFrameworkCore.Design` | `8.0.11` | `10.0.5` |
| `Microsoft.EntityFrameworkCore.InMemory` | `8.0.7` | `10.0.5` |
| `Microsoft.EntityFrameworkCore.SqlServer` | `8.0.11` | `10.0.5` |
| `Microsoft.EntityFrameworkCore.Tools` | `8.0.11` | `10.0.5` |

#### 3.2 Caso especial: AutoMapper y Fluent Assertions

| Paquete | Versión .NET 8 | Versión .NET 10 |
|---------|----------------|-----------------|
| `AutoMapper` | `13.X.X` | `14.0.0` |
| `FluentAssertions` | `7.X.X` | `7.2.2` |

> :warning: **Atención**: AutoMapper 14 es un cambio de versión mayor. Ver [Sección 6](#6-riesgos-y-consideraciones) para verificación.

Estos paquetes **NO deben actualizarse** a una versión superior por motivos de licenciamiento. Desde GAT-SSD se está trabajando en alternativas para estas librerías.

#### 3.3 Otros paquetes

Algunos paquetes no tienen una versión 10.X.X. En ese caso, se actualizarán a la versión estable más reciente. Algunos ejemplos:

| Paquete | Versión .NET 8 | Versión .NET 10 |
|---------|----------------|-----------------|
| `System.ServiceModel.Federation` | `6.0.0` | `10.0.652802` |
| `System.ServiceModel.Http` | `8.1.1` | `10.0.652802` |
| `System.ServiceModel.NetTcp` | `6.0.0` | `10.0.652802` |

#### 3.4 Paquetes de la arquitectura de referencia SsidArqNet (GAT-SSD)

Estos paquetes internos han tenido un salto de versión mayor, pasando de versiones `1.x`/`2.x`/`8.x` a `10.0.0`, y también han sufrido **cambios en los nombres de sus métodos de extensión**:

| Paquete | Versión .NET 8 | Versión .NET 10 |
|---------|----------------|-----------------|
| `SsidArqNet.Ateka.AspNetCoreApi` | `1.2.0` | Renombrado a `SsidArqNet.Ateka.AspNetCore.Api` =\> `10.0.0` |
| `SsidArqNet.Ateka.AspNetCoreApi.Swagger` | `2.1.0` | Renombrado a `SsidArqNet.Ateka.AspNetCore.Api.Swagger` =\> `10.0.0` |
| `SsidArqNet.Core` | `1.1.2` | `10.0.0` |
| `SsidArqNet.Core.SeedWork` | `2.0.0` | `10.0.0` |
| `SsidArqNet.ExceptionManagement.AspNetCore.Api` | `1.0.1` | `10.0.0` |
| `SsidArqNet.ExceptionManagement.Core` | `1.0.0` | `10.0.0` |
| `SsidArqNet.Logger.Serilog.Net.Extension` | `1.0.1` | `10.0.0` |

En el caso de los paquetes de GAT-SSD, se ha simplificado su uso y versionado: todas las versiones para .NET 10 empiezan por `10.X.X` (ver paso 4).

#### 3.5 Resultado final del fichero `Directory.Packages.props`:

Este es un ejemplo del resultado final del fichero de centralización de versiones de paquetes:

```xml
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
  <ItemGroup>
    <!-- ASP.NET Core -->
    <PackageVersion Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="10.0.5" />
    <PackageVersion Include="Microsoft.AspNetCore.Authentication.OpenIdConnect" Version="10.0.5" />
    <PackageVersion Include="Microsoft.AspNetCore.Mvc.Core" Version="2.3.9" />
    <!-- Configuration -->
    <PackageVersion Include="Microsoft.Extensions.Configuration.Binder" Version="10.0.5" />
    <!-- Entity Framework Core -->
    <PackageVersion Include="Microsoft.EntityFrameworkCore" Version="10.0.5" />
    <PackageVersion Include="Microsoft.EntityFrameworkCore.Design" Version="10.0.5" />
    <PackageVersion Include="Microsoft.EntityFrameworkCore.InMemory" Version="10.0.5" />
    <PackageVersion Include="Microsoft.EntityFrameworkCore.SqlServer" Version="10.0.5" />
    <PackageVersion Include="Microsoft.EntityFrameworkCore.Tools" Version="10.0.5" />
    <!-- Mapping -->
    <PackageVersion Include="AutoMapper" Version="14.0.0" />
    <!-- System.ServiceModel -->
    <PackageVersion Include="System.ServiceModel.Duplex" Version="6.0.0" />
    <PackageVersion Include="System.ServiceModel.Federation" Version="10.0.652802" />
    <PackageVersion Include="System.ServiceModel.Http" Version="10.0.652802" />
    <PackageVersion Include="System.ServiceModel.NetTcp" Version="10.0.652802" />
    <PackageVersion Include="System.ServiceModel.Security" Version="6.0.0" />
    <!-- Testing -->
    <PackageVersion Include="Bogus" Version="35.6.5" />
    <PackageVersion Include="coverlet.collector" Version="8.0.1" />
    <PackageVersion Include="FluentAssertions" Version="7.2.2" />
    <PackageVersion Include="Microsoft.AspNetCore.Mvc.Testing" Version="10.0.5" />
    <PackageVersion Include="Microsoft.AspNetCore.TestHost" Version="10.0.5" />
    <PackageVersion Include="Microsoft.NET.Test.Sdk" Version="18.3.0" />
    <PackageVersion Include="Moq" Version="4.20.72" />
    <PackageVersion Include="NUnit" Version="4.5.1" />
    <PackageVersion Include="NUnit.Analyzers" Version="4.12.0" />
    <PackageVersion Include="NUnit3TestAdapter" Version="6.2.0" />
    <!-- GAT -->
    <PackageVersion Include="SsidArqNet.Ateka.AspNetCore.Api" Version="10.0.0" />
    <PackageVersion Include="SsidArqNet.Ateka.AspNetCore.Api.Swagger" Version="10.0.0" />
    <PackageVersion Include="SsidArqNet.Core" Version="10.0.0" />
    <PackageVersion Include="SsidArqNet.Core.SeedWork" Version="10.0.0" />
    <PackageVersion Include="SsidArqNet.ExceptionManagement.AspNetCore.Api" Version="10.0.0" />
    <PackageVersion Include="SsidArqNet.ExceptionManagement.Core" Version="10.0.0" />
    <PackageVersion Include="SsidArqNet.Logger.Serilog.Net.Extension" Version="10.0.0" />
  </ItemGroup>
</Project>
```

**Criterio de aceptación:**

- :white_check_mark: `Directory.Packages.props` contiene todas las versiones actualizadas definidas para la migración.
- :white_check_mark: Los paquetes renombrados de GAT-SSD se han sustituido correctamente.
- :white_check_mark: `dotnet restore` se completa sin errores.

---

### Paso 4 – Actualización de `Program.cs` (cambio de APIs internas paquetes de GAT-SSD)

**:stopwatch: Tiempo estimado: 15 minutos**

Este es el único fichero de código C# que requiere cambios. Los paquetes corporativos `SsidArqNet.*`, en su versión `10.0.0`, han renombrado sus métodos de extensión para adoptar una nomenclatura más consistente con las convenciones de .NET.

#### 4.1 Cambio en la nomenclatura

Con el objetivo de unificar la experiencia de uso y simplificar la incorporación de nuevos paquetes, todos los componentes de la arquitectura adoptan una nomenclatura común para su registro en el contenedor de dependencias.

##### Beneficios

- Nomenclatura homogénea en todos los paquetes de la arquitectura.
- Mayor facilidad de descubrimiento mediante IntelliSense.
- Curva de aprendizaje reducida para nuevos desarrolladores.
- Separación clara entre configuración basada en `appsettings` y configuración basada en objetos de opciones.
- Mayor consistencia en la documentación y ejemplos de uso.

A partir de esta versión, cada paquete expondrá dos mecanismos de configuración:

- **Desde `appsettings.json`**, utilizando la configuración proporcionada por `IConfiguration`.
- **Desde un objeto de opciones (POCO)**, permitiendo la configuración programática sin depender de archivos de configuración.

La convención general será la siguiente:

```csharp
builder.Services.AddSsidArqNet{NombrePaquete}FromAppSettings(
    builder.Configuration
);

builder.Services.AddSsidArqNet{NombrePaquete}FromOptions(
    {ObjetoPocoPaquete}
);

...

app.UseSsidArqNet{NombrePaquete}()
```

##### Ejemplo de uso

```csharp
// Registro desde appsettings.json





builder.Services.AddSsidArqNetLoggerFromAppSettings(
    configuration: builder.Configuration
);

// Registro mediante objeto de opciones





SsidArqNetLoggerOptions options = new(...);

builder.Services.AddSsidArqNetLoggerFromOptions(
    options: options
);
```

#### 4.2 Migración desde versiones anteriores

Las extensiones de registro existentes han sido renombradas para alinearse con esta nueva convención:

##### Service collection (builder.Services)

```diff
- RegistradorSerilogLogger.RegistrarLoggerDesdeConfiguracionSerilog(
-     loggingBuilder: loggingBuilder,
-     configuration: builder.Configuration
- )
+ builder.Services.AddSsidArqNetLoggerFromAppSettings(
+     configuration: builder.Configuration
+ )
 
- builder.Services.ConfigurarAspNetCoreApiSanitizacionDesdeAppSettings(config: builder.Configuration)
+ builder.Services.AddSsidArqNetApiSanitizacionFromAppSettings(config: builder.Configuration)
 
- builder.Services.RegistrarAutenticacionNetCoreApiFromSettings(conf: builder.Configuration);
+ builder.Services.AddSsidArqNetApiAuthenticationFromAppSettings(conf: builder.Configuration);
 
- builder.Services.AddSwaggerAtekaFromSettings(config: builder.Configuration);
+ builder.Services.AddSsidArqNetSwaggerAtekaFromAppSettings(config: builder.Configuration);
```

##### WebApplication (app)

```diff
- app.UseSwaggerAtekaFromSettings(config: builder.Configuration);
+ app.UseSsidArqNetSwaggerAteka(config: builder.Configuration);
```

A partir de este momento, todos los nuevos paquetes desarrollados seguirán esta convención de nomenclatura.

**Criterio de aceptación:**

- :white_check_mark: `Program.cs` compila con los nuevos métodos de extensión de GAT-SSD.
- :white_check_mark: No hay referencias a métodos obsoletos del registro anterior.

---

### Paso 5 – Verificación de breaking changes de EF Core 9 y 10

**:stopwatch: Tiempo estimado: 15-45 minutos**

Consultar las guías oficiales de breaking changes:

- https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-9.0/breaking-changes
- https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-10.0/breaking-changes

Los puntos más relevantes para este proyecto son los siguientes:

- **Cambios en el comportamiento de `UseQueryTrackingBehavior`** (no aplica, el proyecto usa `LazyLoadingEnabled = false`).
- **Cambios en la generación de SQL para operaciones de fecha/hora** — Revisar queries que usen `DateTime`.

**Criterio de aceptación:**

- :white_check_mark: Se han revisado los breaking changes de EF Core 9 y 10 aplicables al proyecto.
- :white_check_mark: No quedan incidencias abiertas relacionadas con esos cambios antes de continuar.

---

### Paso 6 – Revisión y actualización de los proyectos de Test

**:stopwatch: Tiempo estimado: 15-30 minutos**

En este paso, revisar la compatibilidad y la ejecución de los tests.

**Criterio de aceptación:**

- :white_check_mark: Los proyectos de test compilan en `net10.0`.
- :white_check_mark: Los tests unitarios e integración se ejecutan correctamente.

---

### Paso 7 (Opcional) - Actualización del fichero de solución (`.sln` → `.slnx`)

**:stopwatch: Tiempo estimado: 10 minutos**

.NET 10 introduce el nuevo formato `.slnx` (XML) como reemplazo del formato `.sln`.

Para crear el fichero `.slnx`, abrir una terminal en la carpeta de la solución y lanzar el comando:

```bash
dotnet sln {NombreSolucion}.sln migrate
```

Además, el archivo `Jenkinsfile` debe apuntar al nuevo fichero:

```groovy
// ANTES




FicheroSolucion: "${nombreSolucion}.sln",

// DESPUÉS




FicheroSolucion: "${nombreSolucion}.slnx",
```

**Criterio de aceptación (si se ejecuta este paso):**

- :white_check_mark: El fichero `.slnx` se ha generado correctamente.
- :white_check_mark: `Jenkinsfile` referencia el fichero `.slnx` cuando aplica.

---

### Paso 8 – Compilación completa y corrección de errores

**:stopwatch: Tiempo estimado: 15-60 minutos**

Una vez realizados todos los cambios anteriores, ejecutar la compilación y la ejecución completa de la solución, incluyendo pruebas funcionales básicas.

**Criterio de aceptación:**

- :white_check_mark: La solución compila sin errores.
- :white_check_mark: La ejecución principal y las comprobaciones funcionales básicas finalizan correctamente.

---

### Paso 9 – Verificación del pipeline de CI/CD y entornos

**:stopwatch: Tiempo estimado: 15-30 minutos**

Actualizar el fichero `Jenkinsfile` para utilizar la nueva pipeline de .NET 10.

```groovy
@Library("gn-jenkinspipeline-library@Pipeline_DOTNET")
```

Ejecutar el pipeline completo de Jenkins y validar que finaliza correctamente en todos sus stages.

**Criterio de aceptación:**

- :white_check_mark: `Jenkinsfile` está actualizado para la pipeline de .NET 10.
- :white_check_mark: La pipeline de CI/CD finaliza sin errores.

---

### Paso 10 – Prueba de conectividad (entorno de validación)

**:stopwatch: Tiempo estimado: 15-60 minutos**

Desplegar el producto en el entorno de validación y realizar pruebas funcionales básicas de la API (autenticación, llamadas GET, uso de Swagger, etc.).

**Criterio de aceptación:**

- :white_check_mark: El despliegue en el entorno de validación se completa correctamente.
- :white_check_mark: Las pruebas funcionales de la API (autenticación, GET y Swagger) son satisfactorias.

---

### Paso 11 – Merge y cierre de rama

**:stopwatch: Tiempo estimado: 10 minutos**

Una vez validado en VAL:

```bash
git add .
git commit -m "41307 - FUN - Migración de .NET 8 a .NET 10"
git push origin migration_net10
# Crear Pull Request hacia la rama principal
```

**Criterio de aceptación:**

- :white_check_mark: Los cambios de migración están versionados en la rama de trabajo.
- :white_check_mark: La Pull Request está creada y lista para revisión/merge.

---

## 5. Tabla resumen con cambios por archivo

| Fichero | Tipo de cambio | Descripción |
|---------|----------------|-------------|
| `Project.Build.targets` | **Verificar / Crear** | Debe existir en raíz; crear si no existe (post-build con `%VSFIRMA%`) |
| `Directory.Packages.props` | **Verificar / Crear** | Debe existir con `ManagePackageVersionsCentrally=true`. |
| `Directory.Packages.props` | **Obligatorio** | Actualizar versiones de los paquetes NuGet |
| `SsidArqNet.Backend.API\SsidArqNet.Backend.API.csproj` | **Obligatorio** | `net8.0` → `net10.0` |
| `SsidArqNet.Backend.Application\*.csproj` | **Obligatorio** | `net8.0` → `net10.0` |
| `SsidArqNet.Backend.CompositionRoot\*.csproj` | **Obligatorio** | `net8.0` → `net10.0` |
| `SsidArqNet.Backend.Domain\*.csproj` | **Obligatorio** | `net8.0` → `net10.0` |
| `SsidArqNet.Backend.GlobalResources\*.csproj` | **Obligatorio** | `net8.0` → `net10.0` |
| `SsidArqNet.Backend.Infrastructure\*.csproj` | **Obligatorio** | `net8.0` → `net10.0` |
| `SsidArqNet.Backend.Test.Arquitecture\*.csproj` | **Obligatorio** | `net8.0` → `net10.0` |
| `SsidArqNet.Backend.Test.Common\*.csproj` | **Obligatorio** | `net8.0` → `net10.0` |
| `SsidArqNet.Backend.Test.Integration\*.csproj` | **Obligatorio** | `net8.0` → `net10.0` |
| `SsidArqNet.Backend.Test.Unit\*.csproj` | **Obligatorio** | `net8.0` → `net10.0` |
| `SsidArqNet.Backend.API\Program.cs` | **Obligatorio** | Cambios en métodos de extensión |
| `Connected Services\WSEnvioCorreos\Reference.cs` | **Verificar** | Puede requerir regeneración del proxy WCF |

---

## 6. Riesgos y consideraciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Runtime de .NET 10/ Visual Studio 2026 no disponible en estaciones | Media | Alto | Planificar instalación con Gobierno de Navarra |
| Breaking changes en EF Core 10 que afecten a queries existentes | Media | Alto | Ejecutar tests de integración en base de datos InMemory y real |
| Breaking changes en AutoMapper 14 que afecten a perfiles de mapeo | Baja | Medio | Revisar changelog y compilar; los perfiles actuales son simples |
| Incompatibilidad del proxy WCF generado con las nuevas versiones de System.ServiceModel | Media | Alto | Regenerar el proxy desde el WSDL del servicio |

---

## 7. Checklist de migración

### :white_check_mark: Prerrequisitos (Paso 1)

- [ ] SDK de .NET 10 instalado (`dotnet --list-sdks` muestra versión `10.x`)
- [ ] Visual Studio 2026 instalado
- [ ] Rama de trabajo creada (`migration_net10`)
- [ ] Build limpia de .NET 8 confirmada
- [ ] `Project.Build.targets` existe en la raíz y está referenciado en todos los `.csproj`
- [ ] `Directory.Packages.props` existe con `ManagePackageVersionsCentrally=true`
- [ ] No existen ficheros `.csproj` con `Version=` en `<PackageReference>`
- [ ] Tests pre-migración pasan en .NET 8

### :arrows_counterclockwise: Cambios de código

- [ ] `<TargetFramework>` actualizado a `net10.0` en todos los `.csproj` (Paso 2)
- [ ] Versiones de los paquetes estándar (Microsoft.\*, EF Core, WCF) actualizadas en `Directory.Packages.props` (Paso 3)
- [ ] Paquetes de GAT-SSD (`SsidArqNet.*`) actualizados a `10.0.0` en `Directory.Packages.props` (Paso 3)
- [ ] `Program.cs` actualizado con nuevos nombres de extension methods de GAT-SSD (Paso 4)
- [ ] `using` de Serilog actualizado en `Program.cs` (Paso 4)
- [ ] Breaking changes de EF Core 9 y 10 revisados y resueltos (Paso 5)

### :test_tube: Verificación

- [ ] Tests unitarios pasan con .NET 10 (Paso 6)
- [ ] Tests de integración pasan con .NET 10 (Paso 6)
- [ ] Build completa sin errores ni warnings críticos (Paso 8)
- [ ] Despliegue en entorno de validación exitoso (Paso 10)
- [ ] Pruebas de autenticación, llamadas GET y Swagger superadas (Paso 10)

### :rocket: CI/CD y cierre

- [ ] Jenkinsfile actualizado con `@Library("gn-jenkinspipeline-library@Pipeline_DOTNET")` (Paso 9)
- [ ] Pipeline de CI/CD ejecutada completamente sin errores (Paso 9)
- [ ] Pull Request creada hacia la rama principal (Paso 11)
- [ ] Merge a rama principal completado (Paso 11)

---

## 8. Errores frecuentes y su solución:

<table>
<tr>
<th>Error</th>
<th>Causa probable</th>
<th>Solución</th>
</tr>
<tr>
<td>

`CS0246: tipo o espacio de nombres no encontrado`
</td>
<td>

`using` incorrecto del Logger
</td>
<td>

Cambiar `using SsidArqNet.Logger.Serilog.Net.Extension;` a `using SsidArqNet.Logger.Serilog.Net.Extension.Extensions;`
</td>
</tr>
<tr>
<td>

`CS1061: no contiene definición para 'RegistrarAutenticacionNetCoreApiFromSettings'`
</td>
<td>Método renombrado en v10.0.0</td>
<td>

Usar `AddSsidArqNetApiAuthenticationFromAppSettings`
</td>
</tr>
<tr>
<td>

`CS1061: no contiene definición para 'AddSwaggerAtekaFromSettings'`
</td>
<td>Método renombrado en v10.0.0</td>
<td>

Usar `AddSsidArqNetSwaggerAtekaFromAppSettings`
</td>
</tr>
<tr>
<td>

`CS1061: no contiene definición para 'ConfigurarAspNetCoreApiSanitizacionDesdeAppSettings'`
</td>
<td>Método renombrado en v10.0.0</td>
<td>

Usar `AddSsidArqNetApiSanitizacionFromAppSettings`
</td>
</tr>
<tr>
<td>

`NU1202: paquete no compatible con net10.0`
</td>
<td>Paquete sin soporte para .NET 10</td>
<td>Verificar si existe versión actualizada del paquete</td>
</tr>
<tr>
<td>

`NU1202: No se encuentran los paquetes SsidArqnet.Ateka.AspNetCoreApi o SsidArqnet.Ateka.AspNetCoreApi.Swagger`
</td>
<td>Paquete renombrado</td>
<td>

Revisar si el proyecto utiliza los paquetes `SsidArqNet.Ateka.AspNetCoreApi` y `SsidArqNet.Ateka.AspNetCoreApi.Swagger`.

En caso afirmativo, deberán actualizarse sus referencias a los nuevos paquetes `SsidArqNet.Ateka.AspNetCore.Api` y `SsidArqNet.Ateka.AspNetCore.Api.Swagger`, respectivamente, utilizando en ambos casos la versión `10.0.0`.
</td>
</tr>
</table>

