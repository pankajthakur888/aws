#!/bin/bash

OLD="ec2-15-206-123-222.ap-south-1.compute.amazonaws.com"
NEW="mongodb-prod.hippostores.com"
REGION="ap-south-1"

TMP_DIR="/tmp/lambda_update"
mkdir -p "$TMP_DIR"

echo "Fetching Lambda functions..."
FUNCTIONS=$(aws lambda list-functions --region $REGION --query "Functions[].FunctionName" --output text)

for fn in $FUNCTIONS; do
    echo "============================================================"
    echo "Lambda: $fn"
    
    ZIP_PATH="$TMP_DIR/${fn}.zip"
    WORK_DIR="$TMP_DIR/${fn}_src"

    rm -rf "$ZIP_PATH" "$WORK_DIR"
    mkdir -p "$WORK_DIR"

    echo "📥 Downloading Lambda code..."
    aws lambda get-function \
        --function-name "$fn" \
        --region "$REGION" \
        --query 'Code.Location' \
        --output text | xargs wget -q -O "$ZIP_PATH"

    echo "📦 Extracting..."
    unzip -q "$ZIP_PATH" -d "$WORK_DIR"

    echo "🔍 Searching & replacing OLD → NEW in source code..."
    COUNT=$(grep -R "$OLD" -n "$WORK_DIR" | wc -l)

    if [ "$COUNT" -eq 0 ]; then
        echo "⚠ No occurrences found. Skipping update."
        continue
    fi

    echo "Found $COUNT occurrences — applying replacement..."
    grep -R "$OLD" -n "$WORK_DIR"

    # Replace in all text/code files safely
    find "$WORK_DIR" -type f -exec sed -i "s|$OLD|$NEW|g" {} +

    echo "📦 Re-packaging ZIP..."
    UPDATED_ZIP="$TMP_DIR/${fn}_updated.zip"
    cd "$WORK_DIR"
    zip -qr "$UPDATED_ZIP" .

    echo "⬆ Uploading updated Lambda code..."
    aws lambda update-function-code \
        --function-name "$fn" \
        --region "$REGION" \
        --zip-file "fileb://$UPDATED_ZIP" >/dev/null

    echo "✔ Updated code for Lambda: $fn"
    echo ""
done

echo "✨ All Lambdas processed!"
