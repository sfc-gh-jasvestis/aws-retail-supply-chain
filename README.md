# Supply Chain Intelligence — Reference Architecture Demo
### Snowflake + AWS S3 + Glue/Iceberg + QuickSight | Retail/CPG

> An end-to-end supply chain analytics platform across 10 APJ warehouses and 50 suppliers — from partner file ingestion to ML-powered demand forecasting, with results exported back to the data lake as Iceberg tables.

```
Amazon S3 (partner files) ──► External Stage ──► Snowflake RAW
                                                      │
                              ┌────────────────────────┤
                              ▼                        ▼
                       Dynamic Tables             Cortex AI
                       (5 min refresh)         (sentiment, classify)
                              │                        │
                              ▼                        ▼
                        Snowflake ML            Cortex Search
                     (FORECAST + ANOMALY)    (100 supplier contracts)
                              │
                              ▼
                    Iceberg Table ──► AWS Glue Catalog
                   (queryable from Athena, EMR)
                              │
                              ▼
              Streamlit in Snowflake ──► Amazon QuickSight + Q
              (analyst UI, 5 tabs)       (executive dashboards + NLP)
```

## What It Does

| Capability | Technology | Detail |
|---|---|---|
| Data Ingestion | Amazon S3 + External Stage | Partner PO files, demand feeds |
| Transform | Dynamic Tables (5 min lag) | INVENTORY_HEALTH, SUPPLIER_PERFORMANCE, DEMAND_TRENDS |
| AI Enrichment | Cortex AI_SENTIMENT, AI_CLASSIFY | Contract risk sentiment, PO delay classification |
| Search (RAG) | Cortex Search | Semantic search over 100 supplier contracts |
| ML Forecast | Snowflake ML FORECAST | 14-day demand prediction per product/warehouse |
| Anomaly Detection | Snowflake ML ANOMALY_DETECTION | Inventory level anomalies |
| Data Lake Export | Iceberg → AWS Glue | Forecast results as Parquet on S3, registered in Glue catalog |
| Analyst UI | Streamlit in Snowflake | 5-tab Supply Chain Hub |
| Executive BI | Amazon QuickSight + Amazon Q | Inventory & supplier dashboards + NLP queries |
| NL Queries | Semantic View + Cortex Agent | "Which warehouses have the lowest fill rate?" |

## Two Personas

| Persona | Tool | What they see |
|---|---|---|
| **Supply Chain Analyst** | Streamlit in Snowflake | Stockouts, supplier scorecards, demand forecasts, contract search, NL queries |
| **VP Supply Chain** | Amazon QuickSight + Amazon Q | Inventory KPIs, supplier risk heatmap, NLP: "Which suppliers missed SLA?" |

## Key AWS Differentiators

This demo uniquely showcases **bidirectional data flow**:
1. **S3 → Snowflake**: Partner files ingested via external stages
2. **Snowflake → S3/Glue**: ML forecast results exported as Iceberg tables, queryable from Athena/EMR

No Bedrock — Cortex AI handles all intelligence natively.

## Repo Structure

```
retail-supply-chain/
├── snowflake/
│   ├── 00_setup.sql              # DB, schemas, warehouse
│   ├── 01_integrations.sql       # S3 external stage
│   ├── 02_raw_tables.sql         # 7 tables + synthetic data
│   ├── 03_curated.sql            # 3 Dynamic Tables + Cortex AI
│   ├── 04_search.sql             # Cortex Search (supplier contracts)
│   ├── 05_ml.sql                 # FORECAST + ANOMALY_DETECTION
│   ├── 06_iceberg.sql            # Iceberg table → Glue catalog
│   └── 07_semantic.sql           # Semantic View
├── streamlit/
│   ├── streamlit_app.py          # 5-tab Supply Chain Hub
│   └── deploy/                   # Snowflake deploy version
├── quicksight/
│   └── deploy.sh                 # 2 datasets + Q topic + dashboard
├── demo/
│   └── demo_script.md            # 3-min video narration
└── README.md
```

## Data

| Table | Rows | Content |
|---|---|---|
| SUPPLIERS | 50 | APJ suppliers across 12 countries |
| PRODUCTS | 500 | Food & beverage product catalog |
| WAREHOUSES | 10 | Distribution centers (SG, SYD, TKY, BKK, MUM, SH, JKT, SEL, AKL, KL) |
| INVENTORY_SNAPSHOTS | 50,000 | Daily stock levels per product/warehouse |
| PURCHASE_ORDERS | 10,000 | PO tracking with delivery dates and delay reasons |
| DEMAND_SIGNALS | 100,000 | Point-of-sale demand by product/warehouse/channel |
| SUPPLIER_CONTRACTS | 100 | Contract documents for Cortex Search |

## Quick Start

### Prerequisites
- Snowflake account with ACCOUNTADMIN
- `snow` CLI configured
- AWS CLI with S3, Glue, QuickSight access (us-west-2)

### Build
Run SQL files in order (00 → 07), then deploy Streamlit and QuickSight:
```bash
cd streamlit/deploy && snow streamlit deploy --replace --connection <CONNECTION>
bash quicksight/deploy.sh
```

### Health Check
```sql
SELECT
    (SELECT COUNT(*) FROM RETAIL_SUPPLY_CHAIN.RAW.SUPPLIERS) AS suppliers,
    (SELECT COUNT(*) FROM RETAIL_SUPPLY_CHAIN.RAW.PRODUCTS) AS products,
    (SELECT COUNT(*) FROM RETAIL_SUPPLY_CHAIN.CURATED.INVENTORY_HEALTH) AS inventory,
    (SELECT COUNT(*) FROM RETAIL_SUPPLY_CHAIN.ML.DEMAND_FORECAST_RESULTS) AS forecasts;
```

## Streamlit App (5 Tabs)

| Tab | Feature | Key Capability |
|---|---|---|
| Inventory Health | Stock heatmap, stockout alerts, value by warehouse | Dynamic Tables |
| Supplier Scorecard | On-time %, grades A-D, spend analysis | Dynamic Tables + AI |
| Demand Forecast | 14-day predictions, anomaly detection, Iceberg export | Snowflake ML |
| Contract Search | Semantic search + AI summary over 100 contracts | Cortex Search |
| Ask Supply Chain | Natural language queries | Semantic View + Agent |

## Legal

Licensed under the Apache License, Version 2.0.

This is a personal project and is **not an official Snowflake offering**. It comes with no support or warranty. Do not use in production without thorough review and testing.
