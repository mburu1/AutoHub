# AutoHub

> A multi-tenant dealership operations platform that consolidates stock, service, and customer data from multiple third-party automotive systems into one consistent model.

![.NET](https://img.shields.io/badge/.NET-10-512BD4?logo=dotnet)
![Angular](https://img.shields.io/badge/Angular-latest-DD0031?logo=angular)
![SQL Server](https://img.shields.io/badge/SQL%20Server-T--SQL-CC2927?logo=microsoftsqlserver)
![License](https://img.shields.io/badge/license-MIT-green)

AutoHub is a portfolio project that models the core challenges of an enterprise automotive SaaS platform:

- **Third-party integrations** (OEM stock feeds, finance providers, parts suppliers, webhooks) behind one provider abstraction
- **Data consistency** through idempotent imports, an outbox pattern, and reconciliation jobs
- **Performance** work on large datasets, with documented T-SQL and index tuning
- **Security** with tenant isolation, JWT auth, and secret management
- **Full lifecycle delivery**: tests, CI/CD, infrastructure as code, and ADRs

---

## Tech stack

| Layer | Technology |
|---|---|
| Backend | C#, .NET 10, ASP.NET Core Web API |
| API docs | OpenAPI + [Scalar](https://scalar.com) (`Scalar.AspNetCore`) |
| Data | SQL Server, EF Core, hand-written T-SQL |
| Resilience | Polly (retry, circuit breaker, timeout) |
| Messaging / jobs | Background workers, outbox pattern |
| Caching | Redis |
| Auth | JWT with tenant claims |
| Observability | Serilog, OpenTelemetry |
| Frontend | Angular (standalone components, signals) |
| Admin page | Razor Pages (diagnostics / admin) |
| Testing | xUnit, Testcontainers, WireMock.Net, Jasmine/Karma or Vitest |
| DevOps | Docker, GitHub Actions / Azure DevOps, Bicep |
| Cloud | Azure App Service, Azure SQL, Key Vault, Service Bus |

---

## Repository structure

The solution file lives in the **repo root** and references projects under `backend/`.

```
autohub/
├── AutoHub.slnx                      # Solution file (root)
├── global.json                       # Pins the .NET SDK version
├── .editorconfig
├── .gitignore
├── .gitattributes
├── README.md
├── CONTRIBUTING.md
├── LICENSE
│
├── backend/
│   ├── Directory.Build.props         # Shared MSBuild settings (nullable, analyzers, warnings as errors)
│   ├── Directory.Packages.props      # Central package management
│   │
│   ├── src/
│   │   ├── AutoHub.Api/              # Web API host, endpoints, Scalar, auth, middleware
│   │   ├── AutoHub.Application/      # Use cases, DTOs, validators, interfaces
│   │   ├── AutoHub.Domain/           # Entities, value objects, domain events
│   │   ├── AutoHub.Infrastructure/   # EF Core, repositories, Redis, integration clients, Polly
│   │   ├── AutoHub.Workers/          # Background sync jobs, outbox processor
│   │   ├── AutoHub.Admin/            # Razor Pages admin / diagnostics UI
│   │   └── AutoHub.MockServices/     # Simulated OEM / finance / parts APIs for local dev
│   │
│   └── tests/
│       ├── AutoHub.UnitTests/
│       ├── AutoHub.IntegrationTests/ # Testcontainers (SQL Server, Redis)
│       ├── AutoHub.ContractTests/    # Third-party API contract tests (WireMock.Net)
│       └── AutoHub.ArchitectureTests/# Layer dependency rules
│
├── frontend/
│   └── autohub-web/                  # Angular application
│       ├── src/
│       │   ├── app/
│       │   │   ├── core/             # Auth, interceptors, guards, config
│       │   │   ├── shared/           # Reusable components, pipes, directives
│       │   │   └── features/
│       │   │       ├── dashboard/
│       │   │       ├── stock/
│       │   │       ├── service-bookings/
│       │   │       ├── customers/
│       │   │       └── sync-health/  # Integration status and failures
│       │   ├── environments/
│       │   └── main.ts
│       ├── angular.json
│       └── package.json
│
├── sql/
│   ├── schema/                       # Reference DDL
│   ├── seed/                         # Large dataset generators (1M+ rows)
│   ├── procedures/                   # Stored procedures
│   ├── views/                        # Indexed views
│   └── performance/                  # Before/after execution plans, tuning notes
│
├── infra/
│   ├── docker/
│   │   ├── docker-compose.yml        # SQL Server, Redis, mock services
│   │   └── docker-compose.override.yml
│   └── bicep/                        # Azure resources (App Service, SQL, Key Vault, Service Bus)
│
├── docs/
│   ├── architecture/                 # Diagrams, C4 model
│   ├── adr/                          # Architecture Decision Records
│   ├── integrations/                 # One doc per third-party provider
│   ├── security/                     # Threat model, OWASP checklist
│   └── api/                          # Exported OpenAPI spec
│
├── scripts/                          # Helper scripts (setup, seed, run-all)
│
└── .github/
    ├── workflows/
    │   ├── backend-ci.yml
    │   ├── frontend-ci.yml
    │   └── deploy.yml
    ├── PULL_REQUEST_TEMPLATE.md
    └── ISSUE_TEMPLATE/
```

### `AutoHub.slnx`

`.slnx` is the XML-based solution format supported by Visual Studio 2026 and the .NET 10 SDK. Projects are referenced by relative path from the repo root:

```xml
<Solution>
  <Folder Name="/backend/">
    <Folder Name="/backend/src/">
      <Project Path="backend/src/AutoHub.Api/AutoHub.Api.csproj" />
      <Project Path="backend/src/AutoHub.Application/AutoHub.Application.csproj" />
      <Project Path="backend/src/AutoHub.Domain/AutoHub.Domain.csproj" />
      <Project Path="backend/src/AutoHub.Infrastructure/AutoHub.Infrastructure.csproj" />
      <Project Path="backend/src/AutoHub.Workers/AutoHub.Workers.csproj" />
      <Project Path="backend/src/AutoHub.Admin/AutoHub.Admin.csproj" />
      <Project Path="backend/src/AutoHub.MockServices/AutoHub.MockServices.csproj" />
    </Folder>
    <Folder Name="/backend/tests/">
      <Project Path="backend/tests/AutoHub.UnitTests/AutoHub.UnitTests.csproj" />
      <Project Path="backend/tests/AutoHub.IntegrationTests/AutoHub.IntegrationTests.csproj" />
      <Project Path="backend/tests/AutoHub.ContractTests/AutoHub.ContractTests.csproj" />
      <Project Path="backend/tests/AutoHub.ArchitectureTests/AutoHub.ArchitectureTests.csproj" />
    </Folder>
  </Folder>
  <Folder Name="/solution-items/">
    <File Path="README.md" />
    <File Path="global.json" />
    <File Path=".editorconfig" />
  </Folder>
</Solution>
```

---

## Architecture

```
Angular SPA ──► AutoHub.Api ──► Application ──► Domain
                    │               │
                    │               ▼
                    │         Infrastructure ──► SQL Server / Redis
                    │               │
                    │               ▼
                    │      Integration providers (Polly-wrapped)
                    │               │
                    ▼               ▼
              Scalar docs     OEM │ Finance │ Parts │ Webhooks
                                    ▲
                            AutoHub.Workers (scheduled sync, outbox)
```

- **Clean architecture**: dependencies point inward; enforced by `AutoHub.ArchitectureTests`.
- **Integration adapters**: each provider implements `IIntegrationProvider`, so adding a new one doesn't touch core logic.
- **Multi-tenancy**: tenant resolved from the JWT claim; enforced through EF Core global query filters.

See [`docs/architecture`](docs/architecture) and [`docs/adr`](docs/adr) for details and decisions.

---

## Integrations

| Provider | Simulates | Demonstrates |
|---|---|---|
| OEM stock feed | Manufacturer vehicle and stock API | Polling, pagination, field mapping |
| Finance provider | Finance quote and approval API | Retries, error handling, timeouts |
| Parts supplier | Parts availability and pricing | Rate limiting, caching |
| Service webhooks | Service completion events | Signature validation, idempotency |

All external systems are simulated by `AutoHub.MockServices`, so the project runs fully offline.

---

## Getting started

### Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- Visual Studio 2026 (Insiders/Community) or VS Code
- [Node.js](https://nodejs.org) (LTS) and Angular CLI
- Docker Desktop

### Run locally

```bash
# 1. Start infrastructure (SQL Server, Redis, mock services)
docker compose -f infra/docker/docker-compose.yml up -d

# 2. Restore and build the solution (from repo root)
dotnet restore AutoHub.slnx
dotnet build AutoHub.slnx

# 3. Apply database migrations
dotnet ef database update \
  --project backend/src/AutoHub.Infrastructure \
  --startup-project backend/src/AutoHub.Api

# 4. Run the API
dotnet run --project backend/src/AutoHub.Api

# 5. Run the frontend
cd frontend/autohub-web
npm install
ng serve
```

| Service | URL |
|---|---|
| API | `https://localhost:5001` |
| Scalar API docs | `https://localhost:5001/scalar/v1` |
| Angular app | `http://localhost:4200` |
| Admin (Razor) | `https://localhost:5001/admin` |

### Run tests

```bash
dotnet test AutoHub.slnx
cd frontend/autohub-web && ng test
```

---

## Roadmap

- [ ] Solution scaffold, central package management, CI skeleton
- [ ] Domain model and EF Core schema
- [ ] Tenant-aware CRUD API with Scalar docs
- [ ] OEM stock integration with mock server
- [ ] Background sync, retries, idempotency
- [ ] Angular stock list and dashboard
- [ ] Finance, parts, and webhook integrations
- [ ] Reconciliation and outbox pattern
- [ ] SQL performance tuning with documented results
- [ ] Security hardening and threat model
- [ ] Azure infrastructure (Bicep) and deployment pipeline

---

## Documentation

| Topic | Location |
|---|---|
| Architecture | [`docs/architecture`](docs/architecture) |
| Decisions (ADRs) | [`docs/adr`](docs/adr) |
| Integrations | [`docs/integrations`](docs/integrations) |
| Security | [`docs/security`](docs/security) |
| SQL performance | [`sql/performance`](sql/performance) |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Commits follow [Conventional Commits](https://www.conventionalcommits.org).

## License

MIT
