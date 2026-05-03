# AWS Integration Guide — Supply Chain Intelligence Demo

> **This is optional.** The Snowflake demo (Streamlit, Dynamic Tables, Cortex Search, ML, Semantic View) works standalone. This guide adds S3 ingestion, Iceberg export to Glue, Athena queries, and QuickSight dashboards.

## Prerequisites

- AWS account with IAM admin, S3, Glue, Lake Formation, Athena access
- AWS CLI configured (`aws configure`)
- Region: **us-west-2** (all resources must be in the same region)
- Snowflake account with ACCOUNTADMIN

## Step 1: S3 Bucket

```bash
export BUCKET=<your-bucket-name>
export REGION=us-west-2

aws s3 mb s3://${BUCKET} --region ${REGION}
aws s3api put-object --bucket ${BUCKET} --key supply-chain/
aws s3api put-object --bucket ${BUCKET} --key iceberg/
aws s3api put-object --bucket ${BUCKET} --key athena-results/
```

## Step 2: IAM Role

Create a role that Snowflake will assume. You'll update the trust policy in step 3 after creating the Snowflake storage integration.

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ROLE_NAME=snowflake-retail-demos-role

aws iam create-role \
  --role-name ${ROLE_NAME} \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::'${AWS_ACCOUNT_ID}':root"},"Action":"sts:AssumeRole"}]}'
```

Attach this inline policy:

```bash
aws iam put-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-name snowflake-s3-glue-policy \
  --policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Access",
      "Effect": "Allow",
      "Action": ["s3:GetObject","s3:GetObjectVersion","s3:ListBucket","s3:GetBucketLocation","s3:PutObject","s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::'${BUCKET}'","arn:aws:s3:::'${BUCKET}'/*"]
    },
    {
      "Sid": "GlueAccess",
      "Effect": "Allow",
      "Action": ["glue:GetTable","glue:GetTables","glue:GetDatabase","glue:GetDatabases","glue:CreateTable","glue:UpdateTable","glue:DeleteTable","glue:CreateDatabase"],
      "Resource": ["arn:aws:glue:'${REGION}':'${AWS_ACCOUNT_ID}':catalog","arn:aws:glue:'${REGION}':'${AWS_ACCOUNT_ID}':database/*","arn:aws:glue:'${REGION}':'${AWS_ACCOUNT_ID}':table/*/*"]
    }
  ]
}'
```

## Step 3: Snowflake Integrations

Run in Snowflake as ACCOUNTADMIN. Replace placeholders with your values.

```sql
-- Storage Integration
CREATE OR REPLACE STORAGE INTEGRATION RETAIL_DEMOS_S3_INTEGRATION
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<AWS_ACCOUNT_ID>:role/<ROLE_NAME>'
  ENABLED = TRUE
  STORAGE_ALLOWED_LOCATIONS = ('s3://<BUCKET>/');

-- *** IMPORTANT: Retrieve these values ***
DESC STORAGE INTEGRATION RETAIL_DEMOS_S3_INTEGRATION;
-- Record: STORAGE_AWS_IAM_USER_ARN  (e.g. arn:aws:iam::891377248908:user/abc-s)
-- Record: STORAGE_AWS_EXTERNAL_ID

-- External Volume (Iceberg writes)
CREATE OR REPLACE EXTERNAL VOLUME RETAIL_ICEBERG_VOLUME
  STORAGE_LOCATIONS = (
    (
      NAME = 'retail-iceberg-s3'
      STORAGE_PROVIDER = 'S3'
      STORAGE_BASE_URL = 's3://<BUCKET>/iceberg/'
      STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<AWS_ACCOUNT_ID>:role/<ROLE_NAME>'
    )
  )
  ALLOW_WRITES = TRUE;

-- Catalog Integration (Glue)
CREATE OR REPLACE CATALOG INTEGRATION RETAIL_GLUE_CATALOG_INT
  CATALOG_SOURCE = GLUE
  CATALOG_NAMESPACE = 'retail_demos_iceberg'
  TABLE_FORMAT = ICEBERG
  GLUE_AWS_ROLE_ARN = 'arn:aws:iam::<AWS_ACCOUNT_ID>:role/<ROLE_NAME>'
  GLUE_CATALOG_ID = '<AWS_ACCOUNT_ID>'
  GLUE_REGION = 'us-west-2'
  ENABLED = TRUE;

-- External Stage
CREATE STAGE IF NOT EXISTS RETAIL_SUPPLY_CHAIN.RAW.SUPPLY_CHAIN_S3_STAGE
  URL = 's3://<BUCKET>/supply-chain/'
  STORAGE_INTEGRATION = RETAIL_DEMOS_S3_INTEGRATION
  FILE_FORMAT = (TYPE = 'JSON' STRIP_OUTER_ARRAY = TRUE);
```

## Step 4: Update IAM Trust Policy

After step 3, update the IAM role trust policy with the Snowflake IAM user ARN:

```bash
export SF_IAM_USER_ARN=<STORAGE_AWS_IAM_USER_ARN from step 3>
export SF_ACCOUNT_LOCATOR=<your Snowflake account locator, e.g. <YOUR_SF_ACCOUNT_LOCATOR>>

aws iam update-assume-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"AWS": "'${SF_IAM_USER_ARN}'"},
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringLike": {
        "sts:ExternalId": "'${SF_ACCOUNT_LOCATOR}'_SFCRole=2_*"
      }
    }
  }]
}'
```

## Step 5: Glue Database

```bash
aws glue create-database \
  --database-input '{"Name": "retail_demos_iceberg"}' \
  --region ${REGION}
```

## Step 6: Iceberg Table + Glue Registration

### 6a. Create Iceberg table in Snowflake

Run `snowflake/06_iceberg.sql`.

### 6b. Find the metadata file

```bash
aws s3 ls s3://${BUCKET}/iceberg/ --recursive --region ${REGION} \
  | grep metadata.json | sort | tail -1
```

Note the full path (e.g. `iceberg/demand_forecast.XXXXX/metadata/00001-xxxx.metadata.json`).

### 6c. Register in Glue

```bash
export METADATA_LOCATION=s3://${BUCKET}/<path from 6b>
export TABLE_LOCATION=s3://${BUCKET}/iceberg/<base_location_dir>/

aws glue create-table \
  --database-name retail_demos_iceberg \
  --region ${REGION} \
  --table-input '{
    "Name": "demand_forecast_iceberg",
    "TableType": "EXTERNAL_TABLE",
    "Parameters": {
      "table_type": "ICEBERG",
      "metadata_location": "'${METADATA_LOCATION}'"
    },
    "StorageDescriptor": {
      "Columns": [
        {"Name": "product_id", "Type": "string"},
        {"Name": "forecast_date", "Type": "timestamp"},
        {"Name": "forecast_units", "Type": "float"},
        {"Name": "lower_bound", "Type": "float"},
        {"Name": "upper_bound", "Type": "float"},
        {"Name": "generated_at", "Type": "timestamp"}
      ],
      "Location": "'${TABLE_LOCATION}'",
      "InputFormat": "org.apache.iceberg.mr.hive.HiveIcebergInputFormat",
      "OutputFormat": "org.apache.iceberg.mr.hive.HiveIcebergOutputFormat",
      "SerdeInfo": {
        "SerializationLibrary": "org.apache.iceberg.mr.hive.HiveIcebergSerDe"
      }
    }
  }'
```

> **Column names must be lowercase** in the Glue registration, even though Snowflake uses UPPERCASE. Athena reads schema from Iceberg metadata, but Glue registration requires column definitions to exist.

## Step 7: Lake Formation Permissions (CRITICAL)

Most AWS accounts use Lake Formation for data access control. **Without these grants, Athena will fail with:**

```
Insufficient Lake Formation permission(s): Required Describe on retail_demos_iceberg
```

```bash
# Grant on database
aws lakeformation grant-permissions \
  --principal '{"DataLakePrincipalIdentifier": "IAM_ALLOWED_PRINCIPALS"}' \
  --resource '{"Database": {"Name": "retail_demos_iceberg"}}' \
  --permissions DESCRIBE ALL \
  --region ${REGION}

# Grant on table
aws lakeformation grant-permissions \
  --principal '{"DataLakePrincipalIdentifier": "IAM_ALLOWED_PRINCIPALS"}' \
  --resource '{"Table": {"DatabaseName": "retail_demos_iceberg", "Name": "demand_forecast_iceberg"}}' \
  --permissions SELECT DESCRIBE \
  --region ${REGION}
```

> If your account does NOT use Lake Formation, these commands may error — that's fine, skip them.

## Step 8: Athena Workgroup Setup

Athena requires a query result location before you can run queries:

```bash
aws athena update-work-group \
  --work-group primary \
  --configuration-updates '{"ResultConfigurationUpdates":{"OutputLocation":"s3://'${BUCKET}'/athena-results/"}}' \
  --region ${REGION}
```

### Verify

```bash
aws athena start-query-execution \
  --query-string "SELECT * FROM retail_demos_iceberg.demand_forecast_iceberg LIMIT 5" \
  --result-configuration '{"OutputLocation":"s3://'${BUCKET}'/athena-results/"}' \
  --region ${REGION}
```

## Step 9: QuickSight (Optional)

Edit `quicksight/deploy.sh`:
- Set `ACCT` to your AWS account ID
- Set `DS_ARN` to your Snowflake data source ARN in QuickSight
- Set `QS_USER_ARN` to your QuickSight user ARN

Then run:
```bash
bash quicksight/deploy.sh
```

Requires: QuickSight Enterprise subscription + a Snowflake data source already configured in QuickSight.

---

## Troubleshooting

### "Insufficient Lake Formation permission(s)"
See Step 7. You must grant `IAM_ALLOWED_PRINCIPALS` access to both the database and table.

### Athena: "Before you run your first query, you need to set up a query result location"
See Step 8. Set the output location on the workgroup.

### Athena Catalog dropdown shows only "None"
Select `AwsDataCatalog` from the Data source dropdown. The Catalog dropdown is for federated catalogs — with the default Glue catalog, leave it as None and select the database directly.

### Athena: "TABLE_NOT_FOUND"
1. Verify the Glue table exists: `aws glue get-tables --database-name retail_demos_iceberg --region us-west-2`
2. Ensure you're in **us-west-2** region in the AWS console
3. Check Lake Formation permissions (Step 7)

### Athena: "COLUMN_NOT_FOUND: Relation contains no accessible columns"
The Glue table was registered with empty `Columns`. Re-create it with the full column definitions (Step 6c). Iceberg reads schema from metadata, but Glue registration still needs column stubs.

### Glue table not visible in console
Select the correct database (`retail_demos_iceberg`) from the "Choose database" dropdown in the Glue console. The tables view requires a database filter.

### Snowflake: "Object does not exist" for storage integration or external volume
These are account-level objects. Run `SHOW STORAGE INTEGRATIONS` and `SHOW EXTERNAL VOLUMES` to verify they exist. They require ACCOUNTADMIN to create.

### Iceberg table: CATALOG_SYNC is empty
Snowflake-managed Iceberg tables do NOT auto-sync to AWS Glue. You must manually register the table in Glue (Step 6c). CATALOG_SYNC only works with Snowflake Open Catalog (Polaris).

---

## Teardown

```bash
# S3 data (keeps bucket, removes demo data)
aws s3 rm s3://${BUCKET}/supply-chain/ --recursive --region ${REGION}
aws s3 rm s3://${BUCKET}/iceberg/ --recursive --region ${REGION}
aws s3 rm s3://${BUCKET}/athena-results/ --recursive --region ${REGION}

# Glue
aws glue delete-table --database-name retail_demos_iceberg --name demand_forecast_iceberg --region ${REGION}
aws glue delete-database --name retail_demos_iceberg --region ${REGION}

# QuickSight (if deployed)
aws quicksight delete-data-set --aws-account-id ${AWS_ACCOUNT_ID} --data-set-id sc-inventory-health --region ${REGION} 2>/dev/null
aws quicksight delete-data-set --aws-account-id ${AWS_ACCOUNT_ID} --data-set-id sc-supplier-performance --region ${REGION} 2>/dev/null
aws quicksight delete-topic --aws-account-id ${AWS_ACCOUNT_ID} --topic-id supply-chain-q-topic --region ${REGION} 2>/dev/null

# Snowflake (run as ACCOUNTADMIN)
# DROP TABLE IF EXISTS RETAIL_SUPPLY_CHAIN.LAKE.DEMAND_FORECAST_ICEBERG;
# DROP STAGE IF EXISTS RETAIL_SUPPLY_CHAIN.RAW.SUPPLY_CHAIN_S3_STAGE;
# DROP SCHEMA IF EXISTS RETAIL_SUPPLY_CHAIN.LAKE;
```
