# fetch-lambda-data — Debug Skill

Use this skill when you need to fetch real data from the production (or dev) Lambda during a debugging session.

## Environment Setup

```bash
export GETRICHER_API_URL="https://<api-gateway-id>.execute-api.<region>.amazonaws.com/prod"
export GETRICHER_USERNAME="your-username"
export GETRICHER_PASSWORD="your-password"
export GETRICHER_ADMIN_PASSWORD="your-admin-password"
```

The base URL is the API Gateway invoke URL for the deployed Lambda. Find it in the AWS Console under API Gateway, or in the CDK stack outputs.

## curl Examples

### Accounts

```bash
curl -G "$GETRICHER_API_URL/api/accounts" \
  --data-urlencode "username=$GETRICHER_USERNAME" \
  --data-urlencode "password=$GETRICHER_PASSWORD"
```

### Transactions (date range)

```bash
curl -G "$GETRICHER_API_URL/api/transactions" \
  --data-urlencode "username=$GETRICHER_USERNAME" \
  --data-urlencode "password=$GETRICHER_PASSWORD" \
  --data-urlencode "startDate=2026-04-01" \
  --data-urlencode "endDate=2026-05-01"
```

### Review Items

```bash
curl "$GETRICHER_API_URL/api/review-items"
```

### Trigger On-Demand Refresh

```bash
curl -X POST "$GETRICHER_API_URL/api/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$GETRICHER_USERNAME\",\"password\":\"$GETRICHER_PASSWORD\"}"
```

### Admin: List Users

```bash
curl -G "$GETRICHER_API_URL/api/admin/users" \
  --data-urlencode "adminPassword=$GETRICHER_ADMIN_PASSWORD"
```

### Admin: Errors

```bash
curl -G "$GETRICHER_API_URL/api/admin/errors" \
  --data-urlencode "adminPassword=$GETRICHER_ADMIN_PASSWORD"
```

## CLI Against Production

All CLI commands accept `--base-url` (or read `GETRICHER_API_URL`) and `--username`/`--password`.

```bash
# Fetch accounts
swift run get-richer accounts \
  --base-url "$GETRICHER_API_URL" \
  --username "$GETRICHER_USERNAME" \
  --password "$GETRICHER_PASSWORD"

# Fetch transactions
swift run get-richer transactions \
  --base-url "$GETRICHER_API_URL" \
  --username "$GETRICHER_USERNAME" \
  --password "$GETRICHER_PASSWORD" \
  --start-date 2026-04-01 \
  --end-date 2026-05-01

# Trigger a manual refresh
swift run get-richer refresh \
  --base-url "$GETRICHER_API_URL" \
  --username "$GETRICHER_USERNAME" \
  --password "$GETRICHER_PASSWORD"

# Generate a paydown report
swift run get-richer report \
  --base-url "$GETRICHER_API_URL" \
  --username "$GETRICHER_USERNAME" \
  --password "$GETRICHER_PASSWORD"

# List review items
swift run get-richer review-items \
  --base-url "$GETRICHER_API_URL" \
  --username "$GETRICHER_USERNAME" \
  --password "$GETRICHER_PASSWORD"

# Admin: list all users
swift run get-richer admin list-users \
  --base-url "$GETRICHER_API_URL" \
  --admin-password "$GETRICHER_ADMIN_PASSWORD"

# Admin: update a user's LM token
swift run get-richer admin update-lm-token alice \
  --base-url "$GETRICHER_API_URL" \
  --admin-password "$GETRICHER_ADMIN_PASSWORD" \
  --lm-token "$LM_TOKEN"
```

## Triggering a Manual Refresh and Verifying DynamoDB

1. Trigger refresh via CLI or curl (see above).
2. Verify the Lambda wrote new records using the AWS CLI:

```bash
# Scan accounts for a user
aws dynamodb query \
  --table-name GetRicher-dev \
  --key-condition-expression "PK = :pk AND begins_with(SK, :sk)" \
  --expression-attribute-values '{":pk":{"S":"alice"},":sk":{"S":"account#"}}' \
  --region us-east-1

# Scan transactions for a user
aws dynamodb query \
  --table-name GetRicher-dev \
  --key-condition-expression "PK = :pk AND begins_with(SK, :sk)" \
  --expression-attribute-values '{":pk":{"S":"alice"},":sk":{"S":"transaction#"}}' \
  --region us-east-1
```

## Common Debugging Patterns

**Check for recent Lambda errors:**
```bash
swift run get-richer admin errors \
  --base-url "$GETRICHER_API_URL" \
  --admin-password "$GETRICHER_ADMIN_PASSWORD"
```

**Verify a user has an LM token stored:**
```bash
swift run get-richer admin list-users \
  --base-url "$GETRICHER_API_URL" \
  --admin-password "$GETRICHER_ADMIN_PASSWORD"
# Look for "has-token" vs "no-token" in the output
```

**Confirm data is coming from DynamoDB (not Lunch Money directly):**  
Remove the LM token from Keychain on the iOS device (or use an invalid one), then fetch accounts via the CLI. If accounts are returned, they came from DynamoDB cache.

**Check CloudWatch logs** for Lambda execution errors:
```bash
aws logs tail /aws/lambda/GetRicher-dev --follow --region us-east-1
```

**Run Lambda locally** (via the local invoke server):
```bash
# Start local invoke server (from FinancePackage directory)
swift run LambdaApp

# Then use the CLI with a local port
swift run get-richer accounts \
  --base-url "http://localhost:7000" \
  --username test \
  --password test
```
