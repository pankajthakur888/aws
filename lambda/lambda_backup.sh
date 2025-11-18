#!/bin/bash

REGION="ap-south-1"
BACKUP_DIR="lambda_backup_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"

echo "Listing Lambda functions..."
FUNCTIONS=$(aws lambda list-functions --region $REGION --query 'Functions[].FunctionName' --output text)

for FN in $FUNCTIONS; do
    echo "Backing up: $FN"

    FN_DIR="$BACKUP_DIR/$FN"
    mkdir -p "$FN_DIR"

    # Save function configuration
    aws lambda get-function-configuration \
        --function-name "$FN" \
        --region "$REGION" \
        > "$FN_DIR/config.json"

    # Save function code (ZIP)
    aws lambda get-function \
        --function-name "$FN" \
        --region "$REGION" \
        --query 'Code.Location' \
        --output text \
        | xargs curl -o "$FN_DIR/code.zip"

    echo "Backup completed for: $FN"
done

echo "All Lambda functions are backed up in: $BACKUP_DIR"
