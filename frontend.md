## Índice

- [1. Resumen](#1-resumen)
- [2. Tabla de tiempos estimados](#2-tabla-de-tiempos-estimados)
- [3. Estructura de la solución](#3-estructura-de-la-soluci%C3%B3n)
- [4. Migración de la solución](#4-migraci%C3%B3n-de-la-soluci%C3%B3n)
  - [Paso 1 – Prerrequisitos y preparación del entorno](#paso-1--prerrequisitos-y-preparaci%C3%B3n-del-entorno) :stopwatch: 30-45 min
    - [1.1 Instalar Visual Studio 2026 y el SDK de .NET 10](#11-instalar-visual-studio-2026-y-el-sdk-de-net-10)
    - [1.2 Crear rama de trabajo en control de versiones](#12-crear-rama-de-trabajo-en-control-de-versiones)
    - [1.3 Realizar una build limpia del proyecto en NET 8](#13-realizar-una-build-limpia-del-proyecto-en-net-8)
    - [1.4 Verificar que `Project.Build.targets` existe y está referenciado en todos los `.csproj`](#14-verificar-que-projectbuildtargets-existe-y-est%C3%A1-referenciado-en-todos-los-csproj)
    - [1.5 Verificar la centralización de versiones NuGet (`Directory.Packages.props`)](#15-verificar-la-centralizaci%C3%B3n-de-versiones-nuget-directorypackagesprops)
    - [1.6 Compilación y tests pre-migración](#16-compilaci%C3%B3n-y-tests-pre-migraci%C3%B3n)
  - [Paso 2 – Actualización del Target Framework en todos los `.csproj`](#paso-2--actualizaci%C3%B3n-del-target-framework-en-todos-los-csproj) :stopwatch: 20 min
  - [Paso 3 – Actualización centralizada de paquetes NuGet (`Directory.Packages.props`)](#paso-3--actualizaci%C3%B3n-centralizada-de-paquetes-nuget-directorypackagesprops) :stopwatch: 30 min
    - [3.1 Ejemplos de actualizaciones estándar](#31-ejemplos-de-actualizaciones-est%C3%A1ndar)
    - [3.2 Caso especial: Radzen y FluentAssertions](#32-caso-especial-radzen-y-fluentassertions)
    - [3.3 Otros paquetes](#33-otros-paquetes)
    - [3.4 Paquetes de la arquitectura SsidArqNet (GAT-SSD)](#34-paquetes-de-la-arquitectura-ssidarqnet-gat-ssd)
    - [3.5 Resultado final del fichero `Directory.Packages.props`](#35-resultado-final-del-fichero-directorypackagesprops)
  - [Paso 4 – Actualización de los `Program.cs` y `.csproj` (cambio de APIs internas de GAT-SSD)](#paso-4--actualizaci%C3%B3n-de-los-programcs-y-csproj-cambio-de-apis-internas-de-gat-ssd) :stopwatch: 45 min
    - [4.1 Cambio en la nomenclatura](#41-cambio-en-la-nomenclatura)
    - [4.2 `UI.Internet`](#42-uiinternet)
    - [4.3 `UI.Internet.Client`](#43-uiinternetclient)
    - [4.4 `UI.Intranet`](#44-uiintranet)
    - [4.5 `UI.Intranet.Client`](#45-uiintranetclient)
    - [4.6 `UI.Shared`](#46-uishared)
  - [Paso 5 – Actualización de la capa `CompositionRoot`](#paso-5--actualizaci%C3%B3n-de-la-capa-compositionroot) :stopwatch: 15 min
    - [5.1 `IServiceCollectionExtensions.cs`](#51-iservicecollectionextensionscs)
    - [5.2 `IApplicationBuilderExtensions.cs`](#52-iapplicationbuilderextensionscs)
  - [Paso 6 – Revisión y actualización de los proyectos de Test](#paso-6--revisi%C3%B3n-y-actualizaci%C3%B3n-de-los-proyectos-de-test) :stopwatch: 20 min
  - [Paso 7 (Opcional) – Actualización del fichero de solución (`.sln` → `.slnx`)](#paso-7-opcional--actualizaci%C3%B3n-del-fichero-de-soluci%C3%B3n-sln--slnx) :stopwatch: 10 min
  - [Paso 8 – Compilación completa y corrección de errores](#paso-8--compilaci%C3%B3n-completa-y-correcci%C3%B3n-de-errores) :stopwatch: 30 min
  - [Paso 9 – Ejecución de todos los tests](#paso-9--ejecuci%C3%B3n-de-todos-los-tests) :stopwatch: 20 min
  - [Paso 10 – Verificación del pipeline de CI/CD y entornos](#paso-10--verificaci%C3%B3n-del-pipeline-de-cicd-y-entornos) :stopwatch: 20 min
  - [Paso 11 – Validación funcional y despliegue](#paso-11--validaci%C3%B3n-funcional-y-despliegue) :stopwatch: 20 min
- [5. Tabla resumen con cambios por archivo](#5-tabla-resumen-con-cambios-por-archivo)
- [6. Riesgos y consideraciones](#6-riesgos-y-consideraciones)
- [7. Checklist de migración](#7-checklist-de-migraci%C3%B3n)

---

## 1. Resumen

Esta migración consiste en actualizar una solución basada en `SsidArqNet.FrontEnd` de **.NET 8** a **.NET 10**. Se trata de una migración que afecta a **13 proyectos** dentro de la solución y que puede describirse como de **complejidad media**:

- La mayor parte del trabajo es **mecánico** (cambio de versiones en ficheros de configuración y renombrado de extension methods).
- Los paquetes corporativos `SsidArqNet.*` han sufrido un **refactoring profundo** separando configuraciones de proyectos Blazor.WebAssembly y Blazor.Server, lo que requiere actualizar los cuatro ficheros `Program.cs` (dos proyectos de Blazor Server y dos proyectos WebAssembly), además de la capa `CompositionRoot`.
- Hay **paquetes GAT que han cambiado de nombre** (no solo de versión): deberán añadirse las nuevas referencias y eliminar las obsoletas en los `.csproj`.
- El API de ASP.NET Core cambia `UseStaticFiles()` por `MapStaticAssets()` para activos estáticos en Blazor.
- No hay cambios en la lógica de negocio (Domain, Application, Infrastructure), en los `appsettings` ni en los componentes Razor (`.razor`).

---

## 2. Tabla de tiempos estimados

| Paso | Descripción | Tiempo estimado |
|------|-------------|-----------------|
| Paso 1 | Prerrequisitos y preparación del entorno | 30-45 min |
| Paso 2 | Actualización del Target Framework en todos los `.csproj` | 20 min |
| Paso 3 | Actualización centralizada de paquetes NuGet | 30 min |
| Paso 4 | Actualización de `Program.cs` y `.csproj` (APIs internas GAT-SSD) | 45 min |
| Paso 5 | Actualización de `CompositionRoot` | 15 min |
| Paso 6 | Revisión y actualización de los proyectos de Test | 20 min |
| Paso 7 (opcional) | Actualización del fichero de solución (`.sln` → `.slnx`) | 10 min |
| Paso 8 | Compilación completa y corrección de errores | 30 min |
| Paso 9 | Ejecución de todos los tests | 20 min |
| Paso 10 | Verificación del pipeline de CI/CD y entornos | 20 min |
| Paso 11 | Validación funcional y despliegue | 20 min |
| **Total estimado** | **10 pasos obligatorios + 1 paso opcional** | **4 h 20 min - 4 h 30 min** |

Los rangos propuestos contemplan la complejidad del producto:

- **Límite inferior**: producto estable, pocos acoplamientos y sin incidencias en dependencias.
- **Límite superior**: producto con mayor complejidad técnica, más integración externa o incidencias durante la validación.

Los tiempos se han estimado para un desarrollador medio que ya conoce el proyecto.

Para un desarrollador que esté comenzando en el proyecto, se recomienda multiplicar el rango por **1.5x** (total estimado: \~6 h 30 min a \~6 h 45 min con paso opcional).

> :pushpin: **Nota**: El paso más complejo es el 4 (actualización de los cuatro `Program.cs` y los `.csproj`), ya que requiere comprender el nuevo patrón de nomenclatura de los paquetes GAT para Blazor Server y WebAssembly.

---

## 3. Estructura de la solución

La solución cuenta con **13 proyectos** organizados en capas:

```
SsidArqNet.FrontEnd/
├── Fuentes/
│   ├── SsidArqNet.FrontEnd.UI.Internet            ← Blazor Server – frontal Internet (host)
│   ├── SsidArqNet.FrontEnd.UI.Internet.Client     ← Blazor WebAssembly – Internet (cliente WASM)
│   ├── SsidArqNet.FrontEnd.UI.Intranet            ← Blazor Server – frontal Intranet (host)
│   ├── SsidArqNet.FrontEnd.UI.Intranet.Client     ← Blazor WebAssembly – Intranet (cliente WASM)
│   ├── SsidArqNet.FrontEnd.UI.Shared              ← Componentes Razor compartidos
│   ├── SsidArqNet.FrontEnd.CompositionRoot        ← Registro de dependencias (DI)
│   ├── SsidArqNet.FrontEnd.Domain                 ← Entidades y contratos de dominio
│   ├── SsidArqNet.FrontEnd.GlobalResources        ← Recursos globales (resx)
│   ├── SsidArqNet.FrontEnd.Infrastructure         ← Repositorios y clientes OpenAPI
│   ├── SsidArqNet.FrontEnd.Test.Arquitecture      ← Tests de arquitectura
│   ├── SsidArqNet.FrontEnd.Test.Common            ← Utilidades compartidas de test
│   ├── SsidArqNet.FrontEnd.Test.Integration       ← Tests de integración (bunit)
│   └── SsidArqNet.FrontEnd.Test.Unit              ← Tests unitarios (bunit)
├── Directory.Packages.props                       ← Gestión centralizada de versiones NuGet
└── Project.Build.targets                          ← Post-build (firma de ensamblados)
```

**Dependencias entre proyectos:**

[Ver archivo de dependencias de la arquitectura (abrir html con un navegador)](https://gesfuentes.admon-cfnavarra.es/repos/gruposArquitectura/gatSsid/ssidarquitecturanet/ssidarqnet.frontend/-/blob/master/DependenciasSsidArqNet.FrontEnd.html)

---

## 4. Migración de la solución

### Paso 1 – Prerrequisitos y preparación del entorno

**:stopwatch: Tiempo estimado: 30-45 minutos**

#### 1.1 Instalar Visual Studio 2026 y el SDK de .NET 10

Antes de iniciar cualquier cambio en el código, verificar que la máquina de desarrollo dispone del SDK correcto:

```powershell
# Verificar versiones instaladas
dotnet --list-sdks

# La salida debe incluir una versión 10.x, por ejemplo:
# 10.0.100 [C:\Program Files\dotnet\sdk]
```

Si el SDK de .NET 10 o Visual Studio 2026 no está instalado, solicitar su instalación a través del [catálogo interno](https://catalogointerno.admon-cfnavarra.es/buscar?search_api_fulltext=+Instalaci%C3%B3n+de+herramientas+del+est%C3%A1ndar+del+puesto+de+desarrollador).

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
- :white_check_mark: Los 13 `.csproj` contienen `<Import Project="../../Project.Build.targets" />`.

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

### Paso 2 – Actualización del Target Framework en todos los `.csproj`

**:stopwatch: Tiempo estimado: 5 minutos**

Todos los proyectos de la solución deben cambiar su `<TargetFramework>` de `net8.0` a `net10.0`. Son **13 ficheros `.csproj`** a modificar.

#### Cambio a realizar (en cada `.csproj`):

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

### Paso 3 – Actualización centralizada de paquetes NuGet (`Directory.Packages.props`)

**:stopwatch: Tiempo estimado: 30 minutos**

El proyecto usa **Central Package Management** de NuGet, por lo que todas las versiones se gestionan en un único fichero: `Directory.Packages.props`, en la raíz de la solución. Los paquetes pueden actualizarse desde la interfaz de NuGet de forma habitual.

A continuación se detallan **todos los cambios de versión** necesarios, siendo `10.0.X` la última versión estable disponible (por simplicidad, se usa `10.0.5` en los ejemplos).

#### 3.1 Ejemplos de actualizaciones estándar

| Paquete | Versión .NET 8 | Versión .NET 10 |
|---------|----------------|-----------------|
| `Microsoft.AspNetCore.Components.Authorization` | `8.0.20` | `10.0.5` |
| `Microsoft.AspNetCore.Components.Web` | `8.0.14` | `10.0.5` |
| `Microsoft.AspNetCore.Components.WebAssembly` | `8.0.14` | `10.0.5` |
| `Microsoft.AspNetCore.Components.WebAssembly.Server` | `8.0.14` | `10.0.5` |
| `Microsoft.Extensions.Localization` | `9.0.3` | `10.0.8` |

#### 3.2 Caso especial: Radzen y FluentAssertions

| Paquete | Versión .NET 8 | Versión .NET 10 |
|---------|----------------|-----------------|
| `Radzen.Blazor` | `6.4.0` | `9.1.0` |
| `FluentAssertions` | `7.X.X` | `7.2.2` |

> :warning: **Atención**: Estos paquetes **NO deben actualizarse** a una versión superior.

- `FluentAssertions` **no debe actualizarse** a una versión superior por motivos de licenciamiento. Desde GAT-SSD se está trabajando en alternativas para esta librería.
- En el caso de `Radzen.Blazor`, se ha estandarizado esa versión en todos los componentes de la arquitectura. Si existiera una necesidad concreta de versionado, contactar con GAT.

#### 3.3 Otros paquetes

Algunos paquetes no tienen una versión `10.X.X`. En ese caso, se actualizarán a la versión estable más reciente. Algunos ejemplos:

| Paquete | Versión .NET 8 | Versión .NET 10 |
|---------|----------------|-----------------|
| `Microsoft.AspNetCore.Diagnostics` | `2.3.0` | `2.3.10` *(sin cambio mayor)* |
| `Microsoft.AspNetCore.Http` | `2.3.0` | `2.3.10` *(sin cambio mayor)* |
| `Newtonsoft.Json` | `13.0.3` | `13.0.3` *(sin cambios)* |
| `NSwag.ApiDescription.Client` | `14.4.0` | `14.7.1` |
| `Bogus` | `35.6.5` | `35.6.5` *(sin cambios)* |
| `bunit` | `1.39.5` | `2.7.2` |
| `Microsoft.NET.Test.Sdk` | `17.x.x` | `18.6.0` |
| `NUnit` | `4.x.x` | `4.6.1` |
| `NUnit.Analyzers` | `4.x.x` | `4.13.0` |
| `NUnit3TestAdapter` | `5.x.x` | `6.2.0` |

#### 3.4 Paquetes de la arquitectura SsidArqNet (GAT-SSD)

Los paquetes internos han sufrido un **refactoring profundo**: además del salto de versión a `10.0.0`, varios paquetes han sido **renombrados** y se han añadido nuevos paquetes específicos para Blazor Server y Blazor WebAssembly:

| Paquete .NET 8 | Versión .NET 8 | Paquete .NET 10 | Versión .NET 10 |
|----------------|---------------:|-----------------|----------------:|
| `SsidArqNet.Ateka.UserContext` | `1.1.1` | `SsidArqNet.Ateka.Blazor.Server.UserContext` | `10.0.0` |
| `SsidArqNet.Ateka.UserContext.AspNetCore` | `1.1.1` | `SsidArqNet.Ateka.Blazor.Wasm.UserContext` | `10.0.0` |
| `SsidArqNet.Components.Blazor.Layout.Internet` | `1.1.1` | `SsidArqNet.Components.Blazor.Server.Layout.Internet` | `10.0.0` |
| `SsidArqNet.Components.Blazor.Layout.Internet` | `1.1.1` | `SsidArqNet.Components.Blazor.Wasm.Layout.Internet` | `10.0.0` |
| `SsidArqNet.Internationalization.AspNetCore.Blazor` | `2.0.2` | `SsidArqNet.Internationalization.Blazor.Server` | `10.0.0` |
| `SsidArqNet.Internationalization.AspNetCore.Blazor` | `2.0.2` | `SsidArqNet.Internationalization.Blazor.Wasm` | `10.0.0` |
| — | — | `SsidArqNet.Ateka.Blazor.Wasm` | `10.0.0` |
| — | — | `SsidArqNet.Ateka.Blazor.Server` | `10.0.0` |
| — | — | `SsidArqNet.Ateka.Core` | `10.0.0` |

Además, varios paquetes internos existentes pasan directamente a `10.0.0`, como `SsidArqNet.Core`, `SsidArqNet.Core.ProblemDetails`, `SsidArqNet.PublisherProxy`, `SsidArqNet.OpenApiClient.AspNetCore` y otros.

En el caso de los paquetes de GAT-SSD, se ha simplificado su uso y versionado: todas las versiones para .NET 10 empiezan por `10.X.X`.

#### 3.5 Resultado final del fichero `Directory.Packages.props`

Para consultar las dependencias y versiones de los paquetes utilizados en el frontend, puede revisar el archivo [Directory.Packages.props](https://gesfuentes.admon-cfnavarra.es/repos/gruposArquitectura/gatSsid/ssidarquitecturanet/ssidarqnet.frontend/-/blob/master/Directory.Packages.props?ref_type=heads).

Para simplificar esta gestión, se recomienda sustituir en el fichero `Directory.Packages.props` los paquetes de la arquitectura por el siguiente bloque de paquetes de GAT:

```xml
<Project>
    <PropertyGroup>
        <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    </PropertyGroup>
    <ItemGroup>
      <!-- Otros paquetes -->

      <!-- ... -->

      <!-- GAT -->
      <PackageVersion Include="SsidArqNet.Ateka.AspNetCore.Blazor.Server" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Ateka.Blazor.Server.UserContext" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Ateka.Blazor.Wasm.UserContext" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Ateka.UserContext" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Ateka.UserContext.AspNetCore" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Ateka.PublisherProxy" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Ateka.Blazor.Wasm" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Ateka.Core" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Ateka.Blazor.Server" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Components.Blazor.Server.Layout.Internet" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Components.Blazor.Wasm.Layout.Internet" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Components.Blazor.MenuManagement" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Core" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Core.ProblemDetails" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.ExceptionManagement.AspNetCore.Blazor" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Internationalization.IcuData" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Internationalization.Blazor.Server" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Internationalization.Blazor.Wasm" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.Logger.Serilog.Net.Extension" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.OpenApiClient.AspNetCore" Version="10.0.0" />
      <PackageVersion Include="SsidArqNet.StorageManagement.Blazor.Server" Version="10.0.0" />
    </ItemGroup>
</Project>
```

**Criterio de aceptación:**

- :white_check_mark: `Directory.Packages.props` contiene todas las versiones actualizadas definidas para la migración.
- :white_check_mark: Los paquetes renombrados de GAT-SSD se han sustituido correctamente.
- :white_check_mark: `dotnet restore` se completa sin errores.

---

### Paso 4 – Actualización de los `Program.cs` y `.csproj` (cambio de APIs internas de GAT-SSD)

**:stopwatch: Tiempo estimado: 45 minutos**

Este paso cubre los cambios necesarios en los cuatro ficheros `Program.cs` (dos hosts Blazor Server y dos proyectos Blazor WebAssembly) y en los ficheros `.csproj` de los proyectos de interfaz de usuario.

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

##### Migración desde versiones anteriores

Las extensiones de registro existentes han sido renombradas para alinearse con esta nueva convención. Por ejemplo:

```diff
- RegistrarLoggerDesdeConfiguracionSerilog(...);
+ AddSsidArqNetLoggerFromAppSettings(...);

- ConfigurarAspNetCoreApiSanitizacionDesdeAppSettings(...);
+ AddSsidArqNetApiSanitizationFromAppSettings(...);

- RegistrarAutenticacionNetCoreApiFromSettings(...);
+ AddSsidArqNetApiAuthenticationFromAppSettings(...);

- AddSwaggerAtekaFromSettings(...);
+ AddSsidArqNetSwaggerAtekaFromAppSettings(...);
```

En el caso de `WebApplication`:

```diff
- app.UseSwaggerAtekaFromSettings(config: builder.Configuration);
+ app.UseSsidArqNetSwaggerAteka(config: builder.Configuration);
```

A partir de este momento, todos los nuevos paquetes desarrollados seguirán esta convención de nomenclatura.

---

#### 4.2 `UI.Internet`

Para más información revisar el [`.csproj`](https://gesfuentes.admon-cfnavarra.es/repos/gruposArquitectura/gatSsid/ssidarquitecturanet/ssidarqnet.frontend/-/blob/master/Fuentes/SsidArqNet.FrontEnd.UI.Internet/SsidArqNet.FrontEnd.UI.Internet.csproj?ref_type=heads) y el [`Program.cs`](https://gesfuentes.admon-cfnavarra.es/repos/gruposArquitectura/gatSsid/ssidarquitecturanet/ssidarqnet.frontend/-/blob/master/Fuentes/SsidArqNet.FrontEnd.UI.Internet/Program.cs?ref_type=heads).

**Cambios en el `.csproj`:**

| Acción | Paquete |
|--------|---------|
| :x: Eliminar | `SsidArqNet.Ateka.AspNetCore.Blazor.Server` |
| :white_check_mark: Añadir | `SsidArqNet.Ateka.Blazor.Server` |
| :white_check_mark: Añadir | `SsidArqNet.Ateka.Core` |
| :white_check_mark: Añadir | `SsidArqNet.Ateka.Blazor.Server.UserContext` |
| :white_check_mark: Añadir | `SsidArqNet.Components.Blazor.Server.Layout.Internet` |
| :white_check_mark: Añadir | `SsidArqNet.StorageManagement.Blazor.Server` |

```diff
 <ItemGroup>
         <PackageReference Include="Microsoft.AspNetCore.Components.WebAssembly.Server" />
         <PackageReference Include="SsidArqNet.Ateka.PublisherProxy" />

-        <PackageReference Include="SsidArqNet.Ateka.AspNetCore.Blazor.Server">
-            <ExcludeAssets>contentFiles</ExcludeAssets>
-        </PackageReference>

+        <PackageReference Include="SsidArqNet.Ateka.Blazor.Server" />
+        <PackageReference Include="SsidArqNet.Ateka.Core" />
+        <PackageReference Include="SsidArqNet.Ateka.Blazor.Server.UserContext" />
+        <PackageReference Include="SsidArqNet.Components.Blazor.Server.Layout.Internet" />
+        <PackageReference Include="SsidArqNet.StorageManagement.Blazor.Server" />
 </ItemGroup>
```

**Cambios en el `Program.cs`:**

Se refactoriza `Program.cs` para adoptar las nuevas extensiones de configuración de SsidArqNet, centralizando la configuración de proxy, logging, autenticación, sanitización, almacenamiento, layout y cliente OpenAPI. Además, se actualiza el pipeline de middlewares y se incorpora el soporte de assets estáticos mediante `MapStaticAssets()`.

##### Service collection

```diff
 builder
     .Services.AddServerSideBlazor()
     .AddCircuitOptions(configure: options =>
         options.DetailedErrors = builder.Environment.EsEntornoPruebas()
     )
     .Services.AddRazorComponents(configure: options =>
         options.DetailedErrors = builder.Environment.EsEntornoPruebas()
     )
     .AddInteractiveServerComponents()
     .AddInteractiveWebAssemblyComponents()
+   .AddSsidArqNetBlazorServerAuthenticationStateSerialization();

- // Configuración manual de logging basada en Serilog
+ AddSsidArqNetLoggerFromAppSettings(builder.Configuration)

- AddAspNetCoreBlazorSanitizacionFromAppSettings(...)
+ AddSsidArqNetBlazorSanitizacionFromAppSettings(...)

- AddAspNetCoreBlazorServerAuthenticationFromAppSettings(...)
+ AddSsidArqNetBlazorServerAuthenticationFromAppSettings(...)

- AddAspNetCoreBlazorServerStorageManagement()
+ AddSsidArqNetBlazorServerStorageManagement()

- AddOpenApiClientAspNetCoreBlazorServerFromAppSettings(...)
+ AddSsidArqNetOpenApiClientAspNetCoreBlazorServerFromAppSettings(...)

- AddAspNetCoreBlazorServerLayoutInternetFromAppSettings<MenuItemManager>(...)
+ AddSsidArqNetBlazorServerLayoutInternetFromAppSettings<MenuItemManager>(...)

- AddAspNetCoreBlazorServerUserContext()
+ AddSsidArqNetBlazorServerUserContext()
```

##### WebApplication

```diff
- app.UsarAspNetCoreBlazorServerLayoutInternet();

+ app.UseSsidArqNetBlazorServerLayoutInternet()
+    .UseSsidArqNetBlazorServerStorageManagement();

+ app.MapStaticAssets();

+ app.UseAntiforgery();
```

---

#### 4.3 `UI.Internet.Client`

Para más información revisar el [`.csproj`](https://gesfuentes.admon-cfnavarra.es/repos/gruposArquitectura/gatSsid/ssidarquitecturanet/ssidarqnet.frontend/-/blob/master/Fuentes/SsidArqNet.FrontEnd.UI.Internet.Client/SsidArqNet.FrontEnd.UI.Internet.Client.csproj?ref_type=heads).

**Cambios en el `.csproj`:**

| Acción | Paquete |
|--------|---------|
| :x: Eliminar | `SsidArqNet.Components.Blazor.Layout.Internet` |
| :white_check_mark: Añadir | `SsidArqNet.Components.Blazor.Wasm.Layout.Internet` |
| :white_check_mark: Añadir | `SsidArqNet.Ateka.Blazor.Wasm` |
| :white_check_mark: Añadir | `SsidArqNet.Ateka.Blazor.Wasm.UserContext` |

```diff
 <ItemGroup>
-    <PackageReference Include="SsidArqNet.Components.Blazor.Layout.Internet" />
+    <PackageReference Include="SsidArqNet.Components.Blazor.Wasm.Layout.Internet" />

     <PackageReference Include="SsidArqNet.Internationalization.IcuData" GeneratePathProperty="true" />

+    <PackageReference Include="SsidArqNet.Ateka.Blazor.Wasm" />
+    <PackageReference Include="SsidArqNet.Ateka.Blazor.Wasm.UserContext" />
 </ItemGroup>
```

**Cambios en el `Program.cs`:**

Se refactoriza `Program.cs` para adoptar las nuevas extensiones de configuración de SsidArqNet.

```diff
- Services.ConfigurarAspNetCoreBlazorSanitizacionDesdeAppSettings(config: builder.Configuration)
+ Services.AddSsidArqNetBlazorSanitizacionFromAppSettings(config: builder.Configuration)

- .ConfigurarAspNetCoreBlazorWebAssemblyLayoutInternetDesdeAppSettings<MenuItemManager>(
-         configuration: builder.Configuration
-     );
+ .AddSsidArqNetBlazorWebAssemblyLayoutInternetFromAppSettings<MenuItemManager>(
+         configuration: builder.Configuration
+     )

- await host.UsarAspNetCoreBlazorWebAssemblyLayoutInternetAsync();
+ await host.UseSsidArqNetBlazorWebAssemblyLayoutInternetAsync();
```

---

#### 4.4 `UI.Intranet`

**Cambios en el `.csproj`:**

| Acción | Paquete |
|--------|---------|
| :x: Eliminar | `SsidArqNet.Ateka.AspNetCore.Blazor.Server` (con `ExcludeAssets`) |
| :x: Eliminar | `SsidArqNet.Ateka.UserContext.AspNetCore` |
| :white_check_mark: Añadir | `SsidArqNet.Ateka.Blazor.Server` |
| :white_check_mark: Añadir | `SsidArqNet.Ateka.Blazor.Server.UserContext` |
| :white_check_mark: Añadir | `SsidArqNet.StorageManagement.Blazor.Server` |
| :white_check_mark: Añadir | `SsidArqNet.Internationalization.Blazor.Server` |

```diff
 <ItemGroup>
     <PackageReference Include="Microsoft.AspNetCore.Components.WebAssembly.Server" />
     <PackageReference Include="SsidArqNet.Ateka.PublisherProxy" />

-    <PackageReference Include="SsidArqNet.Ateka.AspNetCore.Blazor.Server">
-        <ExcludeAssets>contentFiles</ExcludeAssets>
-    </PackageReference>
+    <PackageReference Include="SsidArqNet.Ateka.Blazor.Server" />

-    <PackageReference Include="SsidArqNet.Ateka.UserContext.AspNetCore" />
+    <PackageReference Include="SsidArqNet.Ateka.Blazor.Server.UserContext" />

+    <PackageReference Include="SsidArqNet.StorageManagement.Blazor.Server" />
+    <PackageReference Include="SsidArqNet.Internationalization.Blazor.Server" />
 </ItemGroup>
```

**Cambios en el `Program.cs`:**

##### Sustituciones

```diff
- builder.ConfigurarProxyDesdeAppSettings();
+ builder.AddSsidArqNetAtekaProxyFromAppSettings();

- RegistradorSerilogLogger.RegistrarLoggerDesdeConfiguracionSerilog(...)
+ AddSsidArqNetLoggerFromAppSettings(...)

- ConfigurarAspNetCoreBlazorSanitizacionDesdeAppSettings(...)
+ AddSsidArqNetBlazorSanitizacionFromAppSettings(...)

- RegistrarAutenticacionNetCoreBlazorServerSideIncluidasRazorPagesFromSettings(...)
+ AddSsidArqNetBlazorServerAuthenticationFromAppSettings(...)

- ConfigurarAspNetCoreMenuManagement<MenuItemManager>()
+ AddSsidArqNetMenuManagement<MenuItemManager>()
```

##### Nuevas incorporaciones

```diff
+ .AddSsidArqNetBlazorServerAuthenticationStateSerialization()
    .AddInteractiveServerComponents()
    .AddInteractiveWebAssemblyComponents()
+   .AddSsidArqNetBlazorServerUserContext()
```

---

#### 4.5 `UI.Intranet.Client`

**Cambios en el `.csproj`:**

```diff
 <ItemGroup>
-    <PackageReference Include="SsidArqNet.Ateka.AspNetCore.Blazor.Server">
-        <ExcludeAssets>contentFiles</ExcludeAssets>
-    </PackageReference>
-    <PackageReference Include="SsidArqNet.StorageManagement.Blazor.Server" />
-    <PackageReference Include="SsidArqNet.Ateka.Blazor.Server" />
-    <PackageReference Include="SsidArqNet.Ateka.Core" />
-    <PackageReference Include="SsidArqNet.Ateka.Blazor.Server.UserContext" />
-    <PackageReference Include="SsidArqNet.Components.Blazor.Server.Layout.Internet" />

+    <PackageReference
+      Include="SsidArqNet.Internationalization.IcuData"
+      GeneratePathProperty="true"
+    />
+    <PackageReference Include="SsidArqNet.Internationalization.Blazor.Wasm" />
+    <PackageReference Include="SsidArqNet.Ateka.Blazor.Wasm" />
+    <PackageReference Include="SsidArqNet.Ateka.Blazor.Wasm.UserContext" />
 </ItemGroup>
```

**Cambios en el `Program.cs`:**

```diff
- .ConfigurarAspNetCoreBlazorSanitizacionDesdeAppSettings(
-     config: builder.Configuration
- )
+ .AddSsidArqNetBlazorSanitizacionFromAppSettings(
+     config: builder.Configuration
+ )

- .ConfigurarAspNetCoreBlazorWebAssemblyInternationalizationDesdeAppSettings(
-     configuration: builder.Configuration
- )
+ .AddSsidArqNetBlazorWebAssemblyInternationalizationFromAppSettings(
+     configuration: builder.Configuration
+ )

- .ConfigurarAspNetCoreMenuManagement<MenuItemManager>();
+ .AddSsidArqNetBlazorWasmAuthentication()
+ .AddSsidArqNetBlazorWasmUserContext()
+ .AddSsidArqNetMenuManagement<MenuItemManager>();

  WebAssemblyHost host = builder.Build();

- await host.UsarAspNetCoreBlazorWebAssemblyInternationalizationAsync();
+ await host.UseSsidArqNetBlazorWebAssemblyInternationalizationAsync();
```

---

#### 4.6 `UI.Shared`

**Cambios en el `.csproj`:**

| Acción | Paquete |
|--------|---------|
| :x: Eliminar | `SsidArqNet.StorageManagement.AspNetCore.Blazor` |

```xml
<!-- Eliminar esta línea del ItemGroup de UI.Shared -->
<PackageReference Include="SsidArqNet.StorageManagement.AspNetCore.Blazor" />
```

**Criterio de aceptación:**

- :white_check_mark: Los cuatro `Program.cs` compilan con los nuevos métodos de extensión de GAT-SSD.
- :white_check_mark: Los ficheros `.csproj` de los proyectos UI referencian los paquetes correctos.
- :white_check_mark: No hay referencias a métodos ni paquetes obsoletos del registro anterior.

---

### Paso 5 – Actualización de la capa `CompositionRoot`

**:stopwatch: Tiempo estimado: 15 minutos**

La capa `CompositionRoot` expone extension methods propios del proyecto. Dos ficheros requieren actualizaciones por el renombrado de los paquetes GAT.

#### 5.1 `IServiceCollectionExtensions.cs`

El método de registro del cliente OpenAPI cambia de nombre:

```csharp
// ANTES
services.ConfigurarOpenApiAspNetCore(configuration: configuration, ensamblado: ensamblado);

// DESPUÉS
services.AddSsidArqNetOpenApiClientAspNetCoreBlazorServerFromAppSettings(
    configuration: configuration,
    ensamblado: ensamblado
);
```

#### 5.2 `IApplicationBuilderExtensions.cs`

El middleware de páginas de error cambia de redirección a re-ejecución (necesario para que el enrutamiento de Blazor funcione correctamente en .NET 10):

```csharp
// ANTES
app.UseStatusCodePagesWithRedirects(locationFormat: url);

// DESPUÉS
app.UseStatusCodePagesWithReExecute(pathFormat: url);
```

> :pushpin: **Nota**: `UseStatusCodePagesWithReExecute` es el método recomendado en .NET 10 para aplicaciones Blazor, ya que evita cambiar la URL del navegador y permite que el componente de error tenga acceso al código de estado HTTP original.

**Criterio de aceptación:**

- :white_check_mark: `IServiceCollectionExtensions.cs` compila con el nuevo nombre del método OpenAPI.
- :white_check_mark: `IApplicationBuilderExtensions.cs` usa `UseStatusCodePagesWithReExecute`.

---

### Paso 6 – Revisión y actualización de los proyectos de Test

**:stopwatch: Tiempo estimado: 20 minutos**

Los cuatro proyectos de test solo necesitan el cambio de `TargetFramework` (ya incluido en el Paso 2). Sin embargo, se deben revisar los siguientes aspectos.

#### bunit 1.39.5 → 2.7.2

bunit 2.x es un salto de versión mayor. Revisar el changelog en https://bunit.dev/docs/getting-started/index.html para identificar breaking changes. Los puntos más relevantes:

- La API de `TestContext` se mantiene compatible en los usos habituales.
- Si se usan métodos de extensión de renderizado avanzados, revisar las sobrecargas disponibles y métodos deprecados.

**Criterio de aceptación:**

- :white_check_mark: Los proyectos de test compilan en `net10.0`.
- :white_check_mark: Los tests unitarios e integración se ejecutan correctamente.

---

### Paso 7 (Opcional) – Actualización del fichero de solución (`.sln` → `.slnx`)

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

**:stopwatch: Tiempo estimado: 30 minutos**

Una vez realizados todos los cambios anteriores, ejecutar la compilación y la ejecución completa de la solución, incluyendo pruebas funcionales básicas.

**Criterio de aceptación:**

- :white_check_mark: La solución compila sin errores.
- :white_check_mark: La ejecución principal y las comprobaciones funcionales básicas finalizan correctamente.

---

### Paso 9 – Ejecución de todos los tests

**:stopwatch: Tiempo estimado: 20 minutos**

**Criterio de aceptación:**

- :white_check_mark: **0 tests fallidos** respecto al estado inicial en .NET 8.
- :white_check_mark: El porcentaje de cobertura no ha disminuido.

---

### Paso 10 – Verificación del pipeline de CI/CD y entornos

**:stopwatch: Tiempo estimado: 20 minutos**

#### 10.1 Actualizar Jenkinsfile

Actualizar en la primera línea del fichero `Jenkinsfile` la librería usando la rama `Pipeline_DOTNET`:

```groovy
// ANTES
@Library("gn-jenkinspipeline-library@Pipeline_NET8") _

// DESPUÉS
@Library("gn-jenkinspipeline-library@Pipeline_DOTNET") _
```

Ejecutar el pipeline completo de Jenkins y validar que finaliza correctamente en todos sus stages.

**Criterio de aceptación:**

- :white_check_mark: `Jenkinsfile` está actualizado para la pipeline de .NET 10.
- :white_check_mark: La pipeline de CI/CD finaliza sin errores.

---

### Paso 11 – Validación funcional y despliegue

**:stopwatch: Tiempo estimado: 20 minutos**

#### 11.1 Validación en entorno de Desarrollo

#### 11.2 Validación en entorno VAL (Validación)

#### 11.3 Merge y cierre de rama

Una vez validado en VAL:

**Criterio de aceptación:**

- :white_check_mark: El despliegue en el entorno de validación se completa correctamente.
- :white_check_mark: Las pruebas funcionales (autenticación, navegación, internacionalización) son satisfactorias.
- :white_check_mark: Los cambios de migración están versionados en la rama de trabajo.
- :white_check_mark: La Pull Request está creada y lista para revisión/merge.

---

## 5. Tabla resumen con cambios por archivo

| Fichero | Tipo de cambio | Descripción |
|---------|----------------|-------------|
| `Project.Build.targets` | **Verificar** | Debe existir en raíz; confirmar Import en los 13 `.csproj` |
| `Directory.Packages.props` | **Verificar / Crear** | Debe existir con `ManagePackageVersionsCentrally=true`. |
| `Directory.Packages.props` | **Obligatorio** | Actualizar versiones + renombrar paquetes GAT + añadir nuevos paquetes |
| `SsidArqNet.FrontEnd.UI.Internet\*.csproj` | **Obligatorio** | `net8.0` \u2192 `net10.0` + cambio de paquetes |
| `SsidArqNet.FrontEnd.UI.Internet.Client\*.csproj` | **Obligatorio** | `net8.0` \u2192 `net10.0` + rutas ICU + cambio de paquetes |
| `SsidArqNet.FrontEnd.UI.Intranet\*.csproj` | **Obligatorio** | `net8.0` \u2192 `net10.0` + cambio de paquetes |
| `SsidArqNet.FrontEnd.UI.Intranet.Client\*.csproj` | **Obligatorio** | `net8.0` \u2192 `net10.0` + rutas ICU + cambio de paquetes |
| `SsidArqNet.FrontEnd.UI.Shared\*.csproj` | **Obligatorio** | `net8.0` \u2192 `net10.0` + eliminar paquete renombrado |
| `SsidArqNet.FrontEnd.CompositionRoot\*.csproj` | **Obligatorio** | `net8.0` \u2192 `net10.0` |
| `SsidArqNet.FrontEnd.Domain\*.csproj` | **Obligatorio** | `net8.0` \u2192 `net10.0` |
| `SsidArqNet.FrontEnd.GlobalResources\*.csproj` | **Obligatorio** | `net8.0` \u2192 `net10.0` |
| `SsidArqNet.FrontEnd.Infrastructure\*.csproj` | **Obligatorio** | `net8.0` \u2192 `net10.0` |
| `SsidArqNet.FrontEnd.Test.*.csproj` (×4) | **Obligatorio** | `net8.0` → `net10.0` |
| `UI.Internet\Program.cs` | **Obligatorio** | Proxy + Logger + Auth + Storage + Layout + UserContext + MapStaticAssets |
| `UI.Intranet\Program.cs` | **Obligatorio** | Proxy + Logger + Auth + I18n + Storage + UserContext + MenuManagement + MapStaticAssets |
| `UI.Internet.Client\Program.cs` | **Obligatorio** | Sanitizaci\u00f3n + Layout + WasmAuth + WasmUserContext |
| `UI.Intranet.Client\Program.cs` | **Obligatorio** | Sanitizaci\u00f3n + WasmAuth + I18n + WasmUserContext + MenuManagement |
| `CompositionRoot\Extensions\IServiceCollectionExtensions.cs` | **Obligatorio** | Renombrar `ConfigurarOpenApiAspNetCore` |
| `CompositionRoot\Extensions\IApplicationBuilderExtensions.cs` | **Obligatorio** | `UseStatusCodePagesWithRedirects` \u2192 `UseStatusCodePagesWithReExecute` |
| `Jenkinsfile` | **Obligatorio** | `Pipeline_NET8` → `Pipeline_DOTNET` |
| `SsidArqNet.FrontEnd.slnx` | **Opcional** | Nuevo fichero de solución en formato XML |
| `appsettings*.json` | **Sin cambios** | Idénticos en .NET 8 y .NET 10 |
| `Properties\launchSettings.json` | **Sin cambios** | Id\u00e9ntico en .NET 8 y .NET 10 |
| Componentes Razor (`.razor`, `.razor.cs`) | **Sin cambios** | La lógica de componentes no requiere cambios |
| `Infrastructure\OpenApi\**` | **Sin cambios** | Los clientes generados por NSwag son compatibles |

---

## 6. Riesgos y consideraciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Breaking changes en Radzen.Blazor 9.x (salto de versión mayor) | Media | Alto | Revisar el changelog en https://www.radzen.com/changelog/ antes de migrar; ejecutar todos los tests de componentes |
| Breaking changes en bunit 2.x que afecten a tests de componentes | Baja | Medio | Revisar el changelog de bunit 2.x; los tests básicos de renderizado son compatibles |
| Runtime de .NET 10 / Visual Studio 2026 no disponible en estaciones | Media | Alto | Planificar instalación del runtime con el equipo de sistemas con antelación |
| El nuevo método `UseStatusCodePagesWithReExecute` altera el comportamiento de las páginas de error | Baja | Medio | Verificar que los componentes `Error404` y similares funcionan correctamente con re-ejecución |
| Incompatibilidad del archivo ICU personalizado (`icudt_GdN.dat`) con la ruta `net10.0` | Media | Alto | Verificar que el paquete `SsidArqNet.Internationalization.IcuData 10.0.0` incluye la ruta `net10.0` en su `contentFiles` |
| `MapStaticAssets()` no sirve los mismos archivos estáticos que `UseStaticFiles()` | Baja | Medio | Verificar que todos los recursos en `wwwroot` se sirven correctamente tras el cambio |

---

## 7. Checklist de migración

### :white_check_mark: Prerrequisitos (Paso 1)

- [ ] SDK de .NET 10 instalado (`dotnet --list-sdks` muestra versión `10.x`)
- [ ] Visual Studio 2026 instalado
- [ ] Rama de trabajo creada (`migration_net10`)
- [ ] Build limpia de .NET 8 confirmada
- [ ] `Project.Build.targets` existe en la raíz y está referenciado en los 13 `.csproj`
- [ ] `Directory.Packages.props` existe con `ManagePackageVersionsCentrally=true`
- [ ] No existen ficheros `.csproj` con `Version=` en `<PackageReference>`
- [ ] Tests pre-migración pasan en .NET 8

### :arrows_counterclockwise: Cambios de código

- [ ] `<TargetFramework>` actualizado a `net10.0` en los 13 `.csproj` (Paso 2)
- [ ] Versiones de los paquetes estándar (Microsoft.\*) actualizadas en `Directory.Packages.props` (Paso 3)
- [ ] Paquetes de GAT-SSD (`SsidArqNet.*`) actualizados a `10.0.0` en `Directory.Packages.props` (Paso 3)
- [ ] Referencias de paquetes actualizadas en `UI.Internet` (Paso 4.2)
- [ ] Referencias de paquetes actualizadas en `UI.Internet.Client` (Paso 4.3)
- [ ] Referencias de paquetes actualizadas en `UI.Intranet` (Paso 4.4)
- [ ] Rutas ICU actualizadas a `net10.0` en `UI.Internet.Client` y `UI.Intranet.Client` (Paso 4.3 y 4.5)
- [ ] Referencias de paquetes actualizadas en `UI.Intranet.Client` (Paso 4.5)
- [ ] Paquete obsoleto eliminado de `UI.Shared` (Paso 4.6)
- [ ] `UI.Internet\Program.cs` actualizado (proxy + logger + auth + storage + layout + usercontext + MapStaticAssets) (Paso 4.2)
- [ ] `UI.Intranet\Program.cs` actualizado (proxy + logger + auth + i18n + storage + usercontext + menu + MapStaticAssets) (Paso 4.4)
- [ ] `UI.Internet.Client\Program.cs` actualizado (sanitización + layout + wasm auth + wasm usercontext) (Paso 4.3)
- [ ] `UI.Intranet.Client\Program.cs` actualizado (sanitización + wasm auth + i18n + wasm usercontext + menu) (Paso 4.5)
- [ ] `IServiceCollectionExtensions.cs` actualizado (`ConfigurarOpenApiAspNetCore` renombrado) (Paso 5.1)
- [ ] `IApplicationBuilderExtensions.cs` actualizado (`UseStatusCodePagesWithReExecute`) (Paso 5.2)

### :test_tube: Verificación

- [ ] Proyectos de test revisados (bunit 2.x, NUnit 4.6, coverlet, Radzen 9.x) (Paso 6)
- [ ] Compilación completa exitosa (`dotnet build` sin errores) (Paso 8)
- [ ] Todos los tests pasan (`dotnet test` sin fallos) (Paso 9)
- [ ] Validación funcional en entorno Desarrollo completada (Internet + Intranet) (Paso 11)
- [ ] Validación funcional en entorno VAL completada (Paso 11)

### :rocket: CI/CD y cierre

- [ ] Jenkinsfile actualizado con `@Library("gn-jenkinspipeline-library@Pipeline_DOTNET")` (Paso 10)
- [ ] Pipeline de CI/CD ejecutada completamente sin errores (Paso 10)
- [ ] Fichero de solución `.slnx` creado y referenciado en Jenkinsfile (Paso 7, opcional)
- [ ] Pull Request creada hacia la rama principal (Paso 11)
- [ ] Merge a rama principal completado (Paso 11)
