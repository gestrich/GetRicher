# AWS CDK + Swift Lambda Scaffold

## Relevant Skills

| Skill | Description |
|-------|-------------|
| `swift-app-architecture:swift-architecture` | 4-layer Swift architecture (Apps/Features/Services/SDKs) — layer responsibilities, dependency rules, placement, code style. |

## Background

This is the foundational scaffolding plan for the broader [Lambda Reporting & Modeling Split](2026-05-07-a-lambda-reporting-and-modeling-split.md). The goal is to get a working end-to-end system — Swift Lambda behind API Gateway, deployed to AWS via CDK from GitHub Actions — before any GetRicher domain logic is introduced. Scaffold first, wire in domain later.

### Reference repos

- **`/Users/bill/Developer/personal/swift-lambda-sample`** — source of the Lambda scaffold, CDK infrastructure, Dockerfile, build scripts, and GitHub Actions workflows. Copy selectively (see Phase 1).
- **`/Users/bill/Developer/personal/AIDevTools`** — reference for the platform compilation pattern in `Package.swift` (see below).

### Platform compilation pattern (from AIDevTools)

`FinancePackage` must build on both Apple platforms (iOS/macOS app) and Linux (Lambda). Whole targets are compiled in or out at the **package level** — never via `#if` inside source files.

Two mechanisms from `AIDevTools/Package.swift`:

1. **Wholesale block exclusion** — wrap Apple-only targets, products, and dependencies in `#if os(macOS) || os(iOS)`:

   ```swift
   #if os(macOS) || os(iOS)
   targets.append(contentsOf: [
       // PersistenceService, SwiftUI feature targets, CLIApp, etc.
   ])
   products.append(contentsOf: [ ... ])
   #endif
   ```

2. **Conditional single dependency** — use `.when(platforms:)` when only one dep in an otherwise cross-platform target is platform-specific:

   ```swift
   .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))
   ```

Rule: any target importing `SwiftData`, `SwiftUI`, `UIKit`, or `AppKit` → Apple-only block. `LambdaApp`, `ClientService` → unconditional, must build everywhere. `CLIApp` → Apple-only block (local dev tool, not needed on Linux).

### AWS infrastructure choices

- **No VPC, no NAT Gateway, no RDS/PostgreSQL** — Lambda runs in the AWS-managed public network.
- **Keep**: Lambda, API Gateway, DynamoDB, S3, Secrets Manager, CloudWatch, SNS, SQS.
- GetRicher is a **public GitHub repo** — no secrets, AWS account IDs, ARNs, or actual config files may ever be committed.

## Phases

## - [x] Phase 1: Copy swift-lambda-sample scaffold and trim

**Skills to read**: `swift-app-architecture:swift-architecture`

Port the infrastructure and Swift Lambda scaffold from `swift-lambda-sample`, then strip everything not needed. Adapt all names and config for GetRicher.

### What to copy

| Source (`swift-lambda-sample/`) | Destination (`GetRicher/`) | Notes |
|----------------------------------|----------------------------|-------|
| `cdk/` | `cdk/` | Full CDK infra; adapt stack/app names |
| `Dockerfile` | `Dockerfile` | Lambda Linux build |
| `build.sh` | `build.sh` | Docker build + `lambda.zip` packaging |
| `.github/workflows/deploy_dev.yml` | `.github/workflows/deploy_dev.yml` | Adapt product + Lambda function name |
| `.github/workflows/test.yml` | `.github/workflows/test.yml` | Adapt for GetRicher targets |
| `aws-config.json.example` | `aws-config.json.example` | Template only — actual file never committed |
| `Sources/apps/LambdaApp/` | `FinancePackage/Sources/apps/LambdaApp/` | Hello-world Lambda skeleton |
| `Sources/apps/CLIApp/` | `FinancePackage/Sources/apps/CLIApp/` | Local invocation harness only (trim below) |
| `Sources/services/ClientService/` | `FinancePackage/Sources/services/ClientService/` | Shared request/response models |

### What NOT to copy

- `Sources/apps/MacApp/` — deployment management GUI; not needed.
- `Sources/features/` (SetupFeature, DeployRemoteFeature, DeployXcodeFeature, DeployLinuxFeature, LocalServicesFeature) — deployment tooling; not needed.
- `Sources/services/DeployCoreService/`, `DeployLocalService/`, `LambdaBuildService/`, `StorageService/` — deployment services; not needed.
- `Sources/sdks/` (CLISDK, AWSSDK, GitHubSDK, DockerCLISDK, MinioSDK, PostgreSQLSDK, DynamoDBSDK, BrewCLISDK, NodeCLISDK, Uniflow, CLIMacrosSDK) — deployment SDKs; not needed.
- `tools.sh`, `PostgresDockerfile` — not needed.
- `Tests/DeployRemoteFeatureTests/`, `Tests/CLISDKTests/` — deployment tests; not needed.
- `README.md`, `CLAUDE.md`, `REFACTORING_PLAN.md`, `docs/` — reference only; do not copy.
- `aws-config.json` (actual file) — **secrets risk; never commit**.
- Any `.env`, `samconfig.toml`, or file containing AWS account IDs, ARNs, or API keys.

### Trim CLIApp

Remove all deploy-management subcommands (DeployRemoteCommand, DeployLinuxCommand, DeployXcodeCommand). Keep only the local Lambda invocation harness.

### Adapt Package.swift

- Add dependencies (pin to versions from `swift-lambda-sample`): `swift-aws-lambda-runtime` 2.x, `swift-aws-lambda-events`, `soto`, `swift-argument-parser`.
- Apply the **platform compilation pattern**: wrap all existing Apple-only targets (`PersistenceService`, SwiftUI feature targets) and `CLIApp` in `#if os(macOS) || os(iOS)` blocks. `LambdaApp` and `ClientService` are unconditional.
- Remove all references to targets that were not ported (MacApp, deploy features/SDKs).

### Add .gitignore entries

```
aws-config.json
.env
cdk/cdk.out/
```

### Adapt CDK stack

- Rename stack and app identifiers: `swift-lambda-sample` → `GetRicher` (or `get-richer`).
- `cdk/lib/config/dev.ts` — remove any actual AWS account IDs or resource names from `swift-lambda-sample`; replace with placeholder values or environment variable reads.
- **Remove constructs**: VPC, NAT Gateway, database (RDS/PostgreSQL).
- **Keep constructs**: Lambda, API Gateway, DynamoDB, S3, Secrets Manager, CloudWatch/monitoring, SNS, SQS.

### Verify

- `swift build --product LambdaApp` succeeds on macOS.
- `swift build --product CLIApp` succeeds on macOS.
- `cd cdk && npm install && npx cdk synth` succeeds (stack renders without errors).

## - [x] Phase 2: Local invocation via CLIApp

**Skills used**: `swift-app-architecture:swift-architecture`
**Principles applied**: `InvokeCommand` added as `AsyncParsableCommand` subcommand; uses `Task { @MainActor in }` to call `@MainActor APIClient` from non-isolated async context; default port changed to 8080 because macOS ControlCenter occupies 7000 (AirPlay). Lambda must be started with `LOCAL_LAMBDA_SERVER_ENABLED=1 LOCAL_LAMBDA_HOST=0.0.0.0 LOCAL_LAMBDA_PORT=8080`; the `LOCAL_LAMBDA_HOST=0.0.0.0` binding is required so `localhost` resolves on both IPv4 and IPv6.

Get the full local round-trip working so the hello-world Lambda handler can be exercised on macOS without deploying to AWS.

- CLIApp's `invoke` subcommand wraps a test payload in `APIGatewayRequestWrapper` format and POSTs it to the Lambda's local `/invoke` endpoint (the runtime listens when `LOCAL_LAMBDA_SERVER_ENABLED=1` is set).
- Set `MOCK_AWS_CREDENTIALS=true` so `ServiceComposer` skips real AWS client init.
- Verify: `swift run CLIApp invoke --route /hello` (or equivalent) prints the hello-world response to stdout.

## - [x] Phase 3: Deploy to AWS via CDK and verify end-to-end

**Skills to read**: `swift-app-architecture:swift-architecture`

Get the scaffold Lambda live in AWS behind API Gateway. This is the first Linux compilation pass — expect to find and fix any Apple-only import leaks.

- `build.sh` builds `lambda.zip` inside the Amazon Linux Docker container (from `swift-lambda-sample/build.sh`).
- `cdk deploy` provisions Lambda + API Gateway. No VPC, no NAT Gateway, no RDS.
- GitHub Actions `deploy_dev.yml` triggers on push to `main`: runs `build.sh`, then `cdk deploy`.
- Fix any `SwiftData` / `SwiftUI` / Apple-only imports that surface during the Linux build; use the platform compilation pattern (whole-target exclusion in `Package.swift`) rather than file-level `#if`.

## - [x] Phase 4: Validation

End-to-end success criteria — both must pass:

1. **GitHub deploys to AWS**: push to `main`, confirm `deploy_dev.yml` GitHub Actions workflow completes successfully and the Lambda function is updated in AWS.
2. **CLI command over HTTPS**: `curl https://<api-id>.execute-api.<region>.amazonaws.com/hello` returns `{"message": "hello"}` (or equivalent hello-world response from the deployed Lambda).

No domain logic is required at this point — the scaffold is complete when the pipeline is green and the endpoint responds.
