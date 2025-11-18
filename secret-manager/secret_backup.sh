PROFILE="dwhprod"
REGION="ap-south-1"
BACKUP_DIR="dwhprod_secrets_backup_$(date +%F)"

mkdir -p "$BACKUP_DIR"

for secret in $(aws secretsmanager list-secrets \
    --profile $PROFILE \
    --region $REGION \
    --query 'SecretList[].Name' \
    --output text); do
    echo "Backing up: $secret"
    aws secretsmanager get-secret-value \
      --secret-id "$secret" \
      --profile $PROFILE \
      --region $REGION \
      --query '{Name:Name, SecretString:SecretString, CreatedDate:CreatedDate}' \
      --output json > "$BACKUP_DIR/${secret//\//_}.json"
done
