# Deployment Guide — GetRicher Lambda

Swift Lambda on AWS behind API Gateway, deployed via CDK from GitHub Actions.

## Architecture

```
push to main
  → GitHub Actions (deploy_dev.yml)
    → build.sh (Docker / Amazon Linux 2)
      → lambda.zip
    → cdk deploy
      → Lambda function updated
      → API Gateway: https://qzklnxo41m.execute-api.us-east-1.amazonaws.com/prod/
```

**AWS resources** (all in `us-east-1`, managed by CDK stack `GetRicherStack`):
- Lambda function: `get-richer`
- API Gateway (REST)
- DynamoDB table: `get-richer`
- SQS queue + DLQ
- S3 bucket
- CloudWatch monitoring

---

## First-Time Setup (one-time per AWS account)

### 1. Bootstrap CDK

CDK needs staging resources in the account before any stack can deploy.

```bash
cd cdk
npm ci
npx cdk bootstrap aws://<ACCOUNT_ID>/us-east-1
```

This creates the CDK bootstrap stack (`CDKToolkit`) with the IAM roles that `cdk deploy` assumes. Only needs to run once per account/region.

### 2. Create the GitHub OIDC provider in AWS

GitHub Actions uses OIDC (no long-lived credentials). The provider must exist before the CDK stack can reference it.

In the AWS Console → IAM → Identity Providers → Add provider:
- **Provider type**: OpenID Connect
- **Provider URL**: `https://token.actions.githubusercontent.com`
- **Audience**: `sts.amazonaws.com`

Or via CLI:
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

> **One provider per account.** If you already have one (from another project), skip this — `GitHubActionsConstruct` in CDK imports the existing provider by ARN rather than creating a new one.

### 3. Deploy the CDK stack (creates the IAM deploy role)

```bash
# From repo root — build.sh must have run first so lambda.zip exists
touch lambda.zip        # placeholder so CDK asset ref resolves
cd cdk
npm ci
npx cdk deploy --profile production
```

CDK outputs the role ARN you'll need for GitHub:
```
Outputs:
  GetRicherStack.GitHubActionsRoleArn = arn:aws:iam::<ACCOUNT>:role/get-richer-github-actions-deploy
```

### 4. Configure GitHub

#### Create the `dev` environment

GitHub repo → Settings → Environments → New environment → name it **`dev`**.

> The deploy workflow references `environment: dev`. If this environment doesn't exist GitHub will fail with `startup_failure` before any job runs.

#### Set secrets

GitHub repo → Settings → Secrets and variables → Actions → Repository secrets:

| Secret | Value | Required |
|--------|-------|----------|
| `AWS_ROLE_ARN` | ARN from CDK output above | Yes |
| `SWIFT_PACKAGE_MANAGER_PAT` | GitHub token for private deps | Only if using private packages |

Also set `AWS_ROLE_ARN` on the `dev` environment (Settings → Environments → dev → Environment secrets) so the workflow can access it within the environment context.

---

## How Deployment Works

Pushing to `main` triggers `.github/workflows/deploy_dev.yml` automatically.

**Workflow steps:**
1. Checkout
2. Configure AWS credentials via OIDC (assumes `get-richer-github-actions-deploy` role)
3. `build.sh LambdaApp linux/amd64` — builds `lambda.zip` in Docker
4. `cd cdk && npm ci && npx cdk deploy --require-approval never`
5. Upload `lambda/` as a GitHub artifact (kept 5 days)

Build takes ~10–15 minutes (Swift compilation in Amazon Linux container).

### Manual deploy (without push)

```bash
# Trigger from GitHub UI or CLI:
gh workflow run deploy_dev.yml --repo gestrich/GetRicher --ref main

# Or build and deploy locally (requires AWS credentials):
./build.sh LambdaApp linux/amd64
cd cdk && npx cdk deploy --profile production
```

### Verify the deploy

```bash
curl https://qzklnxo41m.execute-api.us-east-1.amazonaws.com/prod/hello
# {"message":"hello"}
```

---

## Local Development (running Lambda on macOS)

The `CLIApp` invokes the Lambda handler locally without Docker or AWS.

```bash
# Terminal 1 — start Lambda local server
LOCAL_LAMBDA_SERVER_ENABLED=1 \
LOCAL_LAMBDA_HOST=0.0.0.0 \
LOCAL_LAMBDA_PORT=8080 \
MOCK_AWS_CREDENTIALS=true \
swift run --package-path FinancePackage LambdaApp

# Terminal 2 — invoke it
swift run --package-path FinancePackage CLIApp invoke --route /hello
```

**Why `LOCAL_LAMBDA_HOST=0.0.0.0`**: On macOS, `localhost` resolves to IPv6 (`::1`) by default. Binding to `0.0.0.0` covers both IPv4 and IPv6, so the CLIApp can always reach the server.

**Why port 8080**: macOS ControlCenter occupies port 7000 (AirPlay receiver).

**Why `MOCK_AWS_CREDENTIALS=true`**: Skips real AWS SDK client initialization so you don't need credentials just to test the handler locally.

---

## CDK / Infrastructure

Stack definition: `cdk/lib/get-richer-stack.ts`  
Environment config: `cdk/lib/config/dev.ts`

### IAM role for GitHub Actions

`cdk/lib/constructs/github-actions-construct.ts` creates `get-richer-github-actions-deploy` with:
- Trust: GitHub OIDC, scoped to `repo:gestrich/GetRicher:*`
- Permissions: `sts:AssumeRole` on the four CDK bootstrap roles (deploy, file-publishing, image-publishing, lookup) — just enough for `cdk deploy`, nothing more.

After deploying this stack, copy `GitHubActionsRoleArn` from the outputs into the `AWS_ROLE_ARN` GitHub secret.

### Synth locally

```bash
cd cdk
npm ci
touch ../lambda.zip     # CDK validates this asset exists at synth time
npx cdk synth
```

---

## Build Script

`build.sh <product> [platform] [github-token]`

**What it does:**
1. Builds a Docker image (`builder`) based on Amazon Linux 2 — same OS as Lambda
2. Copies pre-resolved Swift dependencies out of the image into `.aws-sam/build-<product>/`
3. Extracts `Package.resolved` from the Linux builder image (see note below)
4. Compiles the Swift product with `--disable-automatic-resolution`
5. Copies Swift runtime `.so` dependencies alongside the binary
6. Strips debug symbols
7. Zips everything into `lambda.zip`

**Critical: Linux `Package.resolved`**

The macOS `Package.resolved` includes macOS-only packages (e.g. `swift-argument-parser` platform-specific targets) that don't exist in the Linux dependency graph. Mounting the macOS file into the Linux build causes `swift package resolve` to hang indefinitely trying to fetch packages that will never resolve.

`build.sh` extracts the Linux-generated `Package.resolved` from the builder image and mounts it as read-only for the compilation step. Do not skip or shortcut this.

---

## Package.swift — Platform Compilation

`FinancePackage/Package.swift` gates Apple-only targets so `LambdaApp` builds clean on Linux.

**Rule:**
- Targets importing `SwiftData`, `SwiftUI`, `UIKit`, or `AppKit` → inside `#if os(macOS) || os(iOS)` block
- `LambdaApp`, `ClientService` → unconditional (must build on Linux)
- `CLIApp` → Apple-only block (macOS dev tool, not needed on Lambda)
- Use `.when(platforms: [.linux])` for a single platform-specific dep inside an otherwise cross-platform target

Never use `#if os()` inside source files — gate at the package level only.

---

## Troubleshooting

### `startup_failure` in GitHub Actions (no jobs created)

Most common causes, in order:

1. **`if: success()` on a `uses:` job** — GitHub forbids status-check functions on reusable workflow call jobs. Remove the `if:` condition.

2. **`dev` environment doesn't exist** — Create it in GitHub repo Settings → Environments before the first deploy.

3. **Missing `id-token: write` in the calling workflow** — The OIDC token doesn't pass through to a reusable workflow unless the *caller* explicitly declares `permissions: id-token: write`. Both `deploy_dev.yml` and `deploy.yml` must have this permission declared.

### AWS credential / OIDC failure

- Verify the GitHub OIDC provider exists in IAM: `arn:aws:iam::<ACCOUNT>:oidc-provider/token.actions.githubusercontent.com`
- Verify `AWS_ROLE_ARN` secret is set (repo level and `dev` environment level)
- Verify the role trust policy includes `repo:gestrich/GetRicher:*` and audience `sts.amazonaws.com`

### Docker build hangs on `swift package resolve`

The macOS `Package.resolved` is mounted instead of the Linux one. Check the `build.sh` section that extracts `Package.resolved` from the builder image — if that `docker run` fails silently, `RESOLVED_MOUNT` will be empty and the macOS file gets used by default. Run `build.sh` with `set -x` to trace.

### `cdk deploy` fails locally — `lambda.zip not found`

CDK validates assets at synth time. Create a placeholder before running CDK commands locally:
```bash
touch lambda.zip
cd cdk && npx cdk synth
```

### Lambda returns 502 / no response

Check CloudWatch Logs for the `get-richer` Lambda function. Common causes: missing environment variable, Swift runtime library not bundled (check `build.sh` `ldd` step output).

---

## Key Files

| File | Purpose |
|------|---------|
| `.github/workflows/deploy_dev.yml` | Trigger: push to main → calls deploy.yml |
| `.github/workflows/deploy.yml` | Reusable workflow: build + CDK deploy |
| `build.sh` | Docker-based Lambda zip builder |
| `Dockerfile` | Amazon Linux 2 Swift build image |
| `FinancePackage/Package.swift` | Platform-gated package manifest |
| `cdk/bin/cdk.ts` | CDK app entry point |
| `cdk/lib/get-richer-stack.ts` | Stack definition |
| `cdk/lib/config/dev.ts` | Dev environment config |
| `cdk/lib/constructs/github-actions-construct.ts` | OIDC role |
| `aws-config.json.example` | Template for local AWS profile config |
