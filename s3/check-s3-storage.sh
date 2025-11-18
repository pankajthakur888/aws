#!/bin/bash

AWS_PROFILE="dalsapprod"
TXT_OUTPUT_FILE="s3_bucket_sizes.txt"
CSV_OUTPUT_FILE="s3_bucket_sizes.csv"

# Clear output files
echo "S3 Bucket Storage Report (profile: $AWS_PROFILE):" > "$TXT_OUTPUT_FILE"
echo "----------------------------------------------------------------------------" >> "$TXT_OUTPUT_FILE"
printf "%-40s %-25s %-15s %-20s\n" "Bucket Name" "Creation Date" "Size" "Last Upload" | tee -a "$TXT_OUTPUT_FILE"
echo "----------------------------------------------------------------------------" | tee -a "$TXT_OUTPUT_FILE"

# Prepare CSV file with headers
echo "BucketName,CreationDate,SizeGB,LastModified" > "$CSV_OUTPUT_FILE"

# Get list of buckets
buckets_json=$(aws s3api list-buckets --profile "$AWS_PROFILE" --output json)

# Loop through each bucket
echo "$buckets_json" | jq -c '.Buckets[]' | while read -r bucket; do
  name=$(echo "$bucket" | jq -r '.Name')
  creation_date=$(echo "$bucket" | jq -r '.CreationDate')

  # Get bucket region
  region=$(aws s3api get-bucket-location --bucket "$name" --profile "$AWS_PROFILE" --output text 2>/dev/null)
  [[ "$region" == "None" || -z "$region" ]] && region="us-east-1"

  # Get bucket size from CloudWatch
  size_bytes=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/S3 \
    --metric-name BucketSizeBytes \
    --start-time "$(date -u -d '3 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --period 86400 \
    --statistics Average \
    --dimensions Name=BucketName,Value="$name" Name=StorageType,Value=StandardStorage \
    --region "$region" \
    --profile "$AWS_PROFILE" \
    --query 'Datapoints[0].Average' \
    --output text 2>/dev/null)

  # Convert size to human readable
  readable_size="No data"
  size_gb=""
  if [[ "$size_bytes" != "None" && -n "$size_bytes" ]]; then
    size_kb=$(echo "$size_bytes / 1024" | bc -l)
    size_mb=$(echo "$size_bytes / 1024 / 1024" | bc -l)
    size_gb=$(echo "$size_bytes / 1024 / 1024 / 1024" | bc -l)
    size_tb=$(echo "$size_bytes / 1024 / 1024 / 1024 / 1024" | bc -l)

    if (( $(echo "$size_bytes < 1024 * 1024" | bc -l) )); then
      readable_size="$(printf "%.2f" "$size_kb") KB"
    elif (( $(echo "$size_bytes < 1024 * 1024 * 1024" | bc -l) )); then
      readable_size="$(printf "%.2f" "$size_mb") MB"
    elif (( $(echo "$size_bytes < 1024 * 1024 * 1024 * 1024" | bc -l) )); then
      readable_size="$(printf "%.2f" "$size_gb") GB"
    else
      readable_size="$(printf "%.2f" "$size_tb") TB"
    fi
  fi

  # Get last modified object (limit to 1000)
  last_modified=$(aws s3api list-objects-v2 \
    --bucket "$name" \
    --max-items 1000 \
    --profile "$AWS_PROFILE" \
    --region "$region" \
    --query 'sort_by(Contents,&LastModified)[-1].LastModified' \
    --output text 2>/dev/null)

  [[ -z "$last_modified" || "$last_modified" == "None" ]] && last_modified="No objects / Skipped"

  # Output to TXT
  printf "%-40s %-25s %-15s %-20s\n" "$name" "$creation_date" "$readable_size" "$last_modified" | tee -a "$TXT_OUTPUT_FILE"

  # Output to CSV
  size_gb_csv="0"
  [[ -n "$size_gb" ]] && size_gb_csv=$(printf "%.2f" "$size_gb")
  echo "\"$name\",\"$creation_date\",\"$size_gb_csv\",\"$last_modified\"" >> "$CSV_OUTPUT_FILE"

done
