#!/usr/bin/env bash
set -euo pipefail

REGION="us-west-2"
ACCT="__AWS_ACCOUNT_ID__"
DS_ID="fsi-snowflake-ds"
DS_ARN="arn:aws:quicksight:${REGION}:${ACCT}:datasource/${DS_ID}"
QS_USER_ARN="arn:aws:quicksight:us-west-2:__AWS_ACCOUNT_ID__:user/default/__AWS_ACCOUNT_ID__"

fail() { echo "FAILED: $1"; exit 1; }
ok()   { echo "  OK: $1"; }

echo "=== Supply Chain Intelligence QuickSight Deployment ==="

echo "Creating dataset: sc-inventory-health..."
aws quicksight create-data-set \
  --aws-account-id "$ACCT" --region "$REGION" \
  --data-set-id "sc-inventory-health" \
  --name "Supply Chain - Inventory Health" \
  --import-mode DIRECT_QUERY \
  --physical-table-map '{
    "inventory": {
      "CustomSql": {
        "DataSourceArn": "'"${DS_ARN}"'",
        "Name": "InventoryHealth",
        "SqlQuery": "SELECT PRODUCT_NAME, CATEGORY, SUB_CATEGORY, WAREHOUSE_NAME, REGION, WAREHOUSE_COUNTRY, SNAPSHOT_DATE, QUANTITY_ON_HAND, REORDER_POINT, DAYS_OF_SUPPLY, INVENTORY_STATUS, ALERT_SEVERITY, INVENTORY_VALUE, SUPPLIER_NAME, SUPPLIER_RELIABILITY FROM RETAIL_SUPPLY_CHAIN.CURATED.INVENTORY_HEALTH",
        "Columns": [
          {"Name": "PRODUCT_NAME", "Type": "STRING"},
          {"Name": "CATEGORY", "Type": "STRING"},
          {"Name": "SUB_CATEGORY", "Type": "STRING"},
          {"Name": "WAREHOUSE_NAME", "Type": "STRING"},
          {"Name": "REGION", "Type": "STRING"},
          {"Name": "WAREHOUSE_COUNTRY", "Type": "STRING"},
          {"Name": "SNAPSHOT_DATE", "Type": "DATETIME"},
          {"Name": "QUANTITY_ON_HAND", "Type": "INTEGER"},
          {"Name": "REORDER_POINT", "Type": "INTEGER"},
          {"Name": "DAYS_OF_SUPPLY", "Type": "DECIMAL"},
          {"Name": "INVENTORY_STATUS", "Type": "STRING"},
          {"Name": "ALERT_SEVERITY", "Type": "STRING"},
          {"Name": "INVENTORY_VALUE", "Type": "DECIMAL"},
          {"Name": "SUPPLIER_NAME", "Type": "STRING"},
          {"Name": "SUPPLIER_RELIABILITY", "Type": "DECIMAL"}
        ]
      }
    }
  }' \
  --permissions '[{"Principal":"'"${QS_USER_ARN}"'","Actions":["quicksight:DescribeDataSet","quicksight:DescribeDataSetPermissions","quicksight:PassDataSet","quicksight:DescribeIngestion","quicksight:ListIngestions","quicksight:UpdateDataSet","quicksight:DeleteDataSet","quicksight:CreateIngestion","quicksight:CancelIngestion","quicksight:UpdateDataSetPermissions"]}]' \
  2>&1 && ok "Dataset: sc-inventory-health" || fail "Dataset creation"

echo "Creating dataset: sc-supplier-performance..."
aws quicksight create-data-set \
  --aws-account-id "$ACCT" --region "$REGION" \
  --data-set-id "sc-supplier-performance" \
  --name "Supply Chain - Supplier Performance" \
  --import-mode DIRECT_QUERY \
  --physical-table-map '{
    "suppliers": {
      "CustomSql": {
        "DataSourceArn": "'"${DS_ARN}"'",
        "Name": "SupplierPerformance",
        "SqlQuery": "SELECT SUPPLIER_NAME, COUNTRY, CITY, CATEGORY, RELIABILITY_SCORE, CONTRACTED_LEAD_TIME, TOTAL_POS, DELIVERED, DELAYED, CANCELLED, ON_TIME_DELIVERY_PCT, AVG_ACTUAL_LEAD_TIME, TOTAL_SPEND, PERFORMANCE_GRADE FROM RETAIL_SUPPLY_CHAIN.CURATED.SUPPLIER_PERFORMANCE",
        "Columns": [
          {"Name": "SUPPLIER_NAME", "Type": "STRING"},
          {"Name": "COUNTRY", "Type": "STRING"},
          {"Name": "CITY", "Type": "STRING"},
          {"Name": "CATEGORY", "Type": "STRING"},
          {"Name": "RELIABILITY_SCORE", "Type": "DECIMAL"},
          {"Name": "CONTRACTED_LEAD_TIME", "Type": "INTEGER"},
          {"Name": "TOTAL_POS", "Type": "INTEGER"},
          {"Name": "DELIVERED", "Type": "INTEGER"},
          {"Name": "DELAYED", "Type": "INTEGER"},
          {"Name": "CANCELLED", "Type": "INTEGER"},
          {"Name": "ON_TIME_DELIVERY_PCT", "Type": "DECIMAL"},
          {"Name": "AVG_ACTUAL_LEAD_TIME", "Type": "DECIMAL"},
          {"Name": "TOTAL_SPEND", "Type": "DECIMAL"},
          {"Name": "PERFORMANCE_GRADE", "Type": "STRING"}
        ]
      }
    }
  }' \
  --permissions '[{"Principal":"'"${QS_USER_ARN}"'","Actions":["quicksight:DescribeDataSet","quicksight:DescribeDataSetPermissions","quicksight:PassDataSet","quicksight:DescribeIngestion","quicksight:ListIngestions","quicksight:UpdateDataSet","quicksight:DeleteDataSet","quicksight:CreateIngestion","quicksight:CancelIngestion","quicksight:UpdateDataSetPermissions"]}]' \
  2>&1 && ok "Dataset: sc-supplier-performance" || fail "Dataset creation"

echo "Creating Q topic: supply-chain-q-topic..."
Q_TOPIC_DEF=$(mktemp)
cat > "$Q_TOPIC_DEF" <<EOJSON
{
  "AwsAccountId": "${ACCT}",
  "TopicId": "supply-chain-q-topic",
  "Topic": {
    "Name": "Supply Chain Intelligence",
    "Description": "Inventory health, supplier performance, and demand trends for APJ retail supply chain",
    "DataSets": [{
      "DatasetArn": "arn:aws:quicksight:${REGION}:${ACCT}:dataset/sc-inventory-health",
      "DatasetName": "Inventory Health",
      "Columns": [
        {"ColumnName": "PRODUCT_NAME", "ColumnFriendlyName": "Product", "ColumnSynonyms": ["item","sku","product name"], "IsIncludedInTopic": true},
        {"ColumnName": "CATEGORY", "ColumnFriendlyName": "Category", "ColumnSynonyms": ["product type","department"], "IsIncludedInTopic": true},
        {"ColumnName": "WAREHOUSE_NAME", "ColumnFriendlyName": "Warehouse", "ColumnSynonyms": ["DC","distribution center","location"], "IsIncludedInTopic": true},
        {"ColumnName": "REGION", "ColumnFriendlyName": "Region", "ColumnSynonyms": ["area","geography"], "IsIncludedInTopic": true},
        {"ColumnName": "INVENTORY_STATUS", "ColumnFriendlyName": "Stock Status", "ColumnSynonyms": ["status","stock level","availability"], "IsIncludedInTopic": true},
        {"ColumnName": "QUANTITY_ON_HAND", "ColumnFriendlyName": "Quantity", "ColumnSynonyms": ["stock","units","on hand"], "IsIncludedInTopic": true},
        {"ColumnName": "DAYS_OF_SUPPLY", "ColumnFriendlyName": "Days of Supply", "ColumnSynonyms": ["DOS","runway","coverage"], "IsIncludedInTopic": true},
        {"ColumnName": "INVENTORY_VALUE", "ColumnFriendlyName": "Inventory Value", "ColumnSynonyms": ["value","stock value","worth"], "IsIncludedInTopic": true},
        {"ColumnName": "SUPPLIER_NAME", "ColumnFriendlyName": "Supplier", "ColumnSynonyms": ["vendor","partner"], "IsIncludedInTopic": true}
      ]
    },{
      "DatasetArn": "arn:aws:quicksight:${REGION}:${ACCT}:dataset/sc-supplier-performance",
      "DatasetName": "Supplier Performance",
      "Columns": [
        {"ColumnName": "SUPPLIER_NAME", "ColumnFriendlyName": "Supplier", "ColumnSynonyms": ["vendor","partner"], "IsIncludedInTopic": true},
        {"ColumnName": "PERFORMANCE_GRADE", "ColumnFriendlyName": "Grade", "ColumnSynonyms": ["rating","score","tier"], "IsIncludedInTopic": true},
        {"ColumnName": "ON_TIME_DELIVERY_PCT", "ColumnFriendlyName": "On-Time %", "ColumnSynonyms": ["OTD","delivery rate","punctuality"], "IsIncludedInTopic": true},
        {"ColumnName": "TOTAL_SPEND", "ColumnFriendlyName": "Spend", "ColumnSynonyms": ["cost","expenditure","procurement"], "IsIncludedInTopic": true},
        {"ColumnName": "DELAYED", "ColumnFriendlyName": "Delayed POs", "ColumnSynonyms": ["late","overdue"], "IsIncludedInTopic": true}
      ]
    }]
  }
}
EOJSON

aws quicksight create-topic --cli-input-json "file://${Q_TOPIC_DEF}" --region "$REGION" 2>&1 \
  && ok "Q Topic: supply-chain-q-topic" || echo "  WARN: Q Topic may already exist"
rm -f "$Q_TOPIC_DEF"

aws quicksight update-topic-permissions \
  --aws-account-id "$ACCT" --region "$REGION" \
  --topic-id "supply-chain-q-topic" \
  --grant-permissions '[{"Principal":"'"${QS_USER_ARN}"'","Actions":["quicksight:DescribeTopic","quicksight:DescribeTopicPermissions","quicksight:DescribeTopicRefresh","quicksight:ListTopicReviewedAnswers","quicksight:CreateTopicReviewedAnswer","quicksight:DeleteTopicReviewedAnswer","quicksight:PassTopic"]}]' \
  2>&1 && ok "Q Topic permissions" || echo "  WARN: permissions"

echo ""
echo "=== Supply Chain QuickSight Done ==="
echo "Try Q: 'Which warehouses have the most stockouts?' or 'What is the average on-time delivery by grade?'"
