#  GetRicher

A personal finance app backed by a Lambda-first data architecture. Lambda polls Lunch Money hourly and stores all financial data in DynamoDB. The iOS app and CLI read exclusively from Lambda — Lunch Money is never called from a client.

## Architecture

```
Lunch Money API
      │  (hourly, per-user)
      ▼
AWS Lambda ──► DynamoDB (accounts, transactions, users)
      │
      ▼
API Gateway
  ├── iOS app (SwiftData cache, sources from Lambda)
  └── Swift CLI (get-richer)
```

## CLI

The `get-richer` CLI provides full feature parity with the iOS app and is the primary tool for verifying the Lambda data flow.

### Setup

The CLI reads its configuration from environment variables. For local use, create a `.env` file at the repo root (already in `.gitignore`) and source it before running commands:

```bash
# .env (do not commit)
GETRICHER_API_URL="https://<api-gateway-id>.execute-api.<region>.amazonaws.com/prod"
GETRICHER_USERNAME="alice"
GETRICHER_PASSWORD="secret"
GETRICHER_ADMIN_PASSWORD="<admin-password>"
# Optional: lets you hit the Lunch Money API directly to compare against the
# DynamoDB cache when debugging discrepancies. Pull from AWS Secrets Manager:
#   aws secretsmanager get-secret-value --secret-id LUNCH_MONEY_TOKEN \
#     --profile production --region us-east-1 --query SecretString --output text
LUNCH_MONEY_TOKEN="<lm-api-token>"
```

Load it once per shell session:

```bash
set -a; source .env; set +a
```

After sourcing, the example commands below can omit `--username`/`--password`/`--base-url`.

### Commands

```bash
# Fetch cached accounts
swift run get-richer accounts --username alice --password secret

# Fetch transactions for a date range
swift run get-richer transactions --username alice --password secret \
  --start-date 2026-04-01 --end-date 2026-05-01

# Trigger an immediate on-demand refresh from Lunch Money
swift run get-richer refresh --username alice --password secret

# Fetch the current weekly paydown (the same data the iOS tab and daily push use)
swift run get-richer paydown

# Trigger a one-off paydown push notification right now
swift run get-richer send-report --username alice --password secret

# (Legacy) Generate a paydown report — same as paydown, kept for compatibility
swift run get-richer report --username alice --password secret

# List and resolve pending review items
swift run get-richer review-items --username alice --password secret
swift run get-richer resolve-item <id> --status resolved --username alice --password secret

# Admin commands (require --admin-password or GETRICHER_ADMIN_PASSWORD)
swift run get-richer admin list-users
swift run get-richer admin delete-user alice
swift run get-richer admin list-reports
swift run get-richer admin delete-report <id>
swift run get-richer admin update-lm-token alice --lm-token $LM_TOKEN
swift run get-richer admin errors
```

All commands accept `--base-url` to override the API URL, or read `GETRICHER_API_URL` from the environment.

For detailed debugging guidance (curl examples, DynamoDB verification, CloudWatch logs), see [`.claude/skills/fetch-lambda-data.md`](.claude/skills/fetch-lambda-data.md).

## Deployment

See [docs/deployment.md](docs/deployment.md) for setup, CI/CD pipeline, OIDC configuration, local Lambda invocation, and troubleshooting.

