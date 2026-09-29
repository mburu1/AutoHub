#Requires -Version 7.0
<#
.SYNOPSIS
  Scaffolds the AutoHub repository (backend .NET 10 + Angular frontend) with AutoHub.slnx in the repo root.

.EXAMPLE
  pwsh -File .\Initialize-AutoHub.ps1
  pwsh -File .\Initialize-AutoHub.ps1 -InitGit -OpenInVS
  pwsh -File .\Initialize-AutoHub.ps1 -SkipFrontend
#>
[CmdletBinding()]
param(
    [string]$Root = 'D:\Mwangi Wa Mburu\Coding\autohub',
    [string]$Author = 'AutoHub Contributors',
    [switch]$SkipFrontend,
    [switch]$InitGit,
    [switch]$OpenInVS
)

$ErrorActionPreference = 'Stop'

function Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }

function Run {
    $exe, $rest = $args
    & $exe @rest
    if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $exe $($rest -join ' ')" }
}

function Write-TextFile([string]$Path, [string]$Content) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM
}

# ---------------------------------------------------------------- prerequisites
Step 'Checking prerequisites'
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { throw '.NET SDK not found. Install the .NET 10 SDK first.' }
$sdkVersion = (& dotnet --version).Trim()
if ([int]($sdkVersion.Split('.')[0]) -lt 10) { throw ".NET SDK $sdkVersion found; .NET 10 or newer is required for .slnx and net10.0." }
if (-not $SkipFrontend -and -not (Get-Command npx -ErrorAction SilentlyContinue)) { throw 'Node.js/npm not found. Install Node LTS or pass -SkipFrontend.' }
if ($InitGit -and -not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git not found.' }

if (-not (Test-Path -LiteralPath $Root)) { New-Item -ItemType Directory -Path $Root -Force | Out-Null }
Set-Location -LiteralPath $Root
if (Test-Path -LiteralPath 'AutoHub.slnx') { throw "AutoHub.slnx already exists in $Root. Aborting to avoid overwriting." }

# ---------------------------------------------------------------- folder tree
Step 'Creating folder tree'
$folders = @(
    'backend/src', 'backend/tests',
    'frontend',
    'sql/schema', 'sql/seed', 'sql/procedures', 'sql/views', 'sql/performance',
    'infra/docker', 'infra/bicep',
    'docs/architecture', 'docs/adr', 'docs/integrations', 'docs/security', 'docs/api',
    'scripts',
    '.github/workflows', '.github/ISSUE_TEMPLATE'
)
foreach ($f in $folders) { New-Item -ItemType Directory -Path $f -Force | Out-Null }

# ---------------------------------------------------------------- root files
Step 'Writing root files'
Write-TextFile 'global.json' (@{
    sdk = [ordered]@{
        version         = $sdkVersion
        rollForward     = 'latestFeature'
        allowPrerelease = $true
    }
} | ConvertTo-Json -Depth 5)

Run dotnet new gitignore --force
Run dotnet new editorconfig --force

Write-TextFile '.gitattributes' @'
* text=auto
*.sh text eol=lf
*.slnx text
'@

if (-not (Test-Path -LiteralPath 'README.md')) {
    Write-TextFile 'README.md' "# AutoHub`n`nReplace this file with the generated README.md."
}

Write-TextFile 'LICENSE' @"
MIT License

Copyright (c) $(Get-Date -Format yyyy) $Author

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@

Write-TextFile 'CONTRIBUTING.md' @'
# Contributing

- Branch from `main`: `feat/...`, `fix/...`, `chore/...`
- Use Conventional Commits (`feat: add OEM stock sync`)
- Run `dotnet test AutoHub.slnx` and `ng test` before opening a PR
- Record significant design decisions in `docs/adr/`
'@

Write-TextFile '.github/PULL_REQUEST_TEMPLATE.md' @'
## What
<!-- What does this PR change? -->

## Why
<!-- Link the issue / motivation -->

## How tested
- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual

## Checklist
- [ ] No secrets committed
- [ ] Docs / ADR updated if needed
'@

Write-TextFile 'docs/adr/0001-record-architecture-decisions.md' @'
# 0001. Record architecture decisions

Status: Accepted

We record significant architecture decisions as ADRs in this folder, one file per decision,
numbered sequentially.
'@

Write-TextFile 'infra/docker/docker-compose.yml' @'
services:
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      ACCEPT_EULA: "Y"
      MSSQL_SA_PASSWORD: "ChangeMe_Str0ng!Passw0rd"   # local dev only; move to .env
    ports:
      - "1433:1433"
    volumes:
      - sqldata:/var/opt/mssql

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  sqldata:
'@

Write-TextFile '.github/workflows/backend-ci.yml' @'
name: backend-ci
on:
  push:
    paths: ['backend/**', 'AutoHub.slnx', 'global.json']
  pull_request:
    paths: ['backend/**', 'AutoHub.slnx', 'global.json']
jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          global-json-file: global.json
      - run: dotnet restore AutoHub.slnx
      - run: dotnet build AutoHub.slnx --no-restore -c Release
      - run: dotnet test AutoHub.slnx --no-build -c Release
'@

Write-TextFile '.github/workflows/frontend-ci.yml' @'
name: frontend-ci
on:
  push:
    paths: ['frontend/**']
  pull_request:
    paths: ['frontend/**']
jobs:
  build:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend/autohub-web
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
          cache-dependency-path: frontend/autohub-web/package-lock.json
      - run: npm ci
      - run: npm run build
'@

# keep empty folders in git
foreach ($f in @('sql/schema','sql/seed','sql/procedures','sql/views','sql/performance','infra/bicep',
                 'docs/architecture','docs/integrations','docs/security','docs/api','scripts','.github/ISSUE_TEMPLATE')) {
    Write-TextFile "$f/.gitkeep" ''
}

# ---------------------------------------------------------------- solution (.slnx in root)
Step 'Creating AutoHub.slnx'
Run dotnet new sln -n AutoHub --format slnx

# ---------------------------------------------------------------- backend props
Write-TextFile 'backend/Directory.Build.props' @'
<Project>
  <PropertyGroup>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <Deterministic>true</Deterministic>
  </PropertyGroup>
</Project>
'@

# ---------------------------------------------------------------- projects
function New-Proj([string]$Template, [string]$Name, [string]$Group) {
    $dir = "backend/$Group/$Name"
    Step "Creating $Name"
    Run dotnet new $Template -n $Name -o $dir --no-restore
    Run dotnet sln AutoHub.slnx add "$dir/$Name.csproj" --solution-folder "backend/$Group"
}

function Add-Ref([string]$From, [string[]]$To) {
    $fromPath = (Get-ChildItem -Path backend -Recurse -Filter "$From.csproj").FullName
    foreach ($t in $To) {
        $toPath = (Get-ChildItem -Path backend -Recurse -Filter "$t.csproj").FullName
        Run dotnet add $fromPath reference $toPath
    }
}

New-Proj 'webapi'    'AutoHub.Api'            'src'
New-Proj 'classlib'  'AutoHub.Application'    'src'
New-Proj 'classlib'  'AutoHub.Domain'         'src'
New-Proj 'classlib'  'AutoHub.Infrastructure' 'src'
New-Proj 'worker'    'AutoHub.Workers'        'src'
New-Proj 'razor'     'AutoHub.Admin'          'src'
New-Proj 'web'       'AutoHub.MockServices'   'src'

New-Proj 'xunit'     'AutoHub.UnitTests'         'tests'
New-Proj 'xunit'     'AutoHub.IntegrationTests'  'tests'
New-Proj 'xunit'     'AutoHub.ContractTests'     'tests'
New-Proj 'xunit'     'AutoHub.ArchitectureTests' 'tests'

# remove template boilerplate classes
Get-ChildItem backend -Recurse -Filter 'Class1.cs' | Remove-Item -Force

Step 'Wiring project references'
Add-Ref 'AutoHub.Application'    @('AutoHub.Domain')
Add-Ref 'AutoHub.Infrastructure' @('AutoHub.Application', 'AutoHub.Domain')
Add-Ref 'AutoHub.Api'            @('AutoHub.Application', 'AutoHub.Infrastructure')
Add-Ref 'AutoHub.Workers'        @('AutoHub.Application', 'AutoHub.Infrastructure')
Add-Ref 'AutoHub.Admin'          @('AutoHub.Application')
Add-Ref 'AutoHub.UnitTests'         @('AutoHub.Domain', 'AutoHub.Application')
Add-Ref 'AutoHub.IntegrationTests'  @('AutoHub.Api', 'AutoHub.Infrastructure')
Add-Ref 'AutoHub.ContractTests'     @('AutoHub.Infrastructure')
Add-Ref 'AutoHub.ArchitectureTests' @('AutoHub.Domain', 'AutoHub.Application', 'AutoHub.Infrastructure', 'AutoHub.Api')

# ---------------------------------------------------------------- Scalar + Program.cs
Step 'Adding Scalar to AutoHub.Api'
$apiCsproj = 'backend/src/AutoHub.Api/AutoHub.Api.csproj'
Run dotnet add $apiCsproj package Scalar.AspNetCore --no-restore

Write-TextFile 'backend/src/AutoHub.Api/Program.cs' @'
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();               // /openapi/v1.json
    app.MapScalarApiReference();    // /scalar/v1
}

app.UseHttpsRedirection();

app.MapGet("/health", () => Results.Ok(new { status = "Healthy" }))
   .WithName("Health");

app.Run();

// Exposed for WebApplicationFactory<Program> in integration tests
public partial class Program;
'@

# ---------------------------------------------------------------- central package management
Step 'Converting to central package management (Directory.Packages.props)'
$pkgs = @{}
foreach ($proj in Get-ChildItem backend -Recurse -Filter '*.csproj') {
    [xml]$xml = Get-Content -LiteralPath $proj.FullName -Raw
    $changed = $false
    foreach ($node in @($xml.SelectNodes('//PackageReference[@Version]'))) {
        $id  = $node.GetAttribute('Include')
        $ver = $node.GetAttribute('Version')
        if ($pkgs.ContainsKey($id) -and $pkgs[$id] -ne $ver) {
            $a = $null; $b = $null
            if ([System.Management.Automation.SemanticVersion]::TryParse($ver, [ref]$a) -and
                [System.Management.Automation.SemanticVersion]::TryParse($pkgs[$id], [ref]$b) -and $a -gt $b) {
                $pkgs[$id] = $ver
            }
            Write-Warning "Version mismatch for $id ($ver vs $($pkgs[$id])); using $($pkgs[$id])."
        } else {
            $pkgs[$id] = $ver
        }
        [void]$node.RemoveAttribute('Version')
        $changed = $true
    }
    if ($changed) { $xml.Save($proj.FullName) }
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('<Project>')
[void]$sb.AppendLine('  <PropertyGroup>')
[void]$sb.AppendLine('    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>')
[void]$sb.AppendLine('  </PropertyGroup>')
[void]$sb.AppendLine('  <ItemGroup>')
foreach ($id in ($pkgs.Keys | Sort-Object)) {
    [void]$sb.AppendLine("    <PackageVersion Include=`"$id`" Version=`"$($pkgs[$id])`" />")
}
[void]$sb.AppendLine('  </ItemGroup>')
[void]$sb.AppendLine('</Project>')
Write-TextFile 'backend/Directory.Packages.props' $sb.ToString()

# ---------------------------------------------------------------- solution items (root files visible in VS)
Step 'Adding root files as solution items'
$slnxPath = Join-Path $Root 'AutoHub.slnx'
[xml]$sx = Get-Content -LiteralPath $slnxPath -Raw
$folder = $sx.CreateElement('Folder')
$folder.SetAttribute('Name', '/solution-items/')
foreach ($p in 'README.md', 'CONTRIBUTING.md', 'global.json', '.editorconfig', '.gitignore', '.gitattributes') {
    $file = $sx.CreateElement('File')
    $file.SetAttribute('Path', $p)
    [void]$folder.AppendChild($file)
}
[void]$sx.DocumentElement.AppendChild($folder)
$sx.Save($slnxPath)

# ---------------------------------------------------------------- frontend
if (-not $SkipFrontend) {
    Step 'Creating Angular app (frontend/autohub-web)'
    $env:NG_CLI_ANALYTICS = 'false'
    Run npx --yes '@angular/cli@latest' new autohub-web --directory frontend/autohub-web --routing --style=scss --skip-git --ssr=false --defaults
}

# ---------------------------------------------------------------- verify
Step 'Verifying solution'
Run dotnet sln AutoHub.slnx list
Run dotnet restore AutoHub.slnx
Run dotnet build AutoHub.slnx --no-restore -nologo -v minimal
Run dotnet test AutoHub.slnx --no-build -nologo -v minimal

# ---------------------------------------------------------------- git
if ($InitGit) {
    Step 'Initialising git'
    Run git init -b main
    Run git add -A
    Run git commit -m 'chore: scaffold AutoHub solution'
}

# ---------------------------------------------------------------- open in VS
if ($OpenInVS) {
    Step 'Opening AutoHub.slnx in Visual Studio'
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $devenv = $null
    if (Test-Path -LiteralPath $vswhere) {
        $devenv = (& $vswhere -products * -prerelease -latest -property productPath) | Select-Object -First 1
    }
    if ($devenv -and (Test-Path -LiteralPath $devenv)) {
        Start-Process -FilePath $devenv -ArgumentList "`"$slnxPath`""
    } else {
        Write-Warning 'Could not locate Visual Studio via vswhere; opening with the default .slnx handler.'
        Start-Process -FilePath $slnxPath
    }
}

Write-Host "`nDone. Solution: $slnxPath" -ForegroundColor Green
