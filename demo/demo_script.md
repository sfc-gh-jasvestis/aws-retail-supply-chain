# Demo Script: Supply Chain Intelligence Hub
## ~3-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Pre-requisites**: Data loaded, Streamlit deployed, QuickSight dashboard published

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Supply Chain Analyst** | Day-to-day operations | Streamlit in Snowflake | Stockouts, supplier performance, demand forecasts, contract terms |
| **VP Supply Chain** | Executive oversight | Amazon QuickSight + Amazon Q | Inventory KPIs, supplier risk heatmap, fill rates by region |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **Ingest (AWS)** | Amazon S3 | Supplier PO files, demand feeds, contract documents |
| **RAW** | 7 tables | SUPPLIERS (50), PRODUCTS (500), WAREHOUSES (10), INVENTORY_SNAPSHOTS (50K), PURCHASE_ORDERS (10K), DEMAND_SIGNALS (100K), SUPPLIER_CONTRACTS (100) |
| **CURATED** | 3 Dynamic Tables | INVENTORY_HEALTH, SUPPLIER_PERFORMANCE, DEMAND_TRENDS |
| **AI** | Cortex Search + Semantic View | Contract search (100 docs), Agent (11 dims, 9 metrics) |
| **ML** | FORECAST + ANOMALY | 14-period demand forecast (7K predictions across 500 products), inventory anomaly detection |
| **LAKE** | Iceberg → Glue | Forecast results as Iceberg table on S3, registered in AWS Glue catalog |
| **Consumption** | Streamlit | 5-tab Supply Chain Hub |
| | QuickSight | 2 datasets + Q Topic |

---

## Pre-Recording Checklist

- [ ] Verify Dynamic Tables: `SHOW DYNAMIC TABLES IN DATABASE RETAIL_SUPPLY_CHAIN` (all ACTIVE)
- [ ] Open Streamlit: `RETAIL_SUPPLY_CHAIN.APP.SUPPLY_CHAIN_HUB_APP`
- [ ] Confirm stockouts exist (Tab 1 — expect 31 stockouts, 10 in Singapore Hub, 3 in Fresh Produce)
- [ ] Confirm supplier grades: A(8), B(16), C(14), D(12) — check Tab 2
- [ ] Test Cortex Search: Tab 4, click "What are the late delivery penalties?" — confirm results
- [ ] Test Forecast: Tab 3, select a product — confirm chart renders
- [ ] Open QuickSight: https://us-west-2.quicksight.aws.amazon.com/
- [ ] Pre-open AWS tabs for demo:
  - S3: `https://s3.console.aws.amazon.com/s3/buckets/sg-retail-demos-2026?prefix=supply-chain/`
  - Glue: `https://us-west-2.console.aws.amazon.com/glue/home?region=us-west-2#/v2/data-catalog/tables` (filter `retail_demos_iceberg`)
  - Athena: `https://us-west-2.console.aws.amazon.com/athena/home?region=us-west-2` (have `SELECT * FROM retail_demos_iceberg.demand_forecast_iceberg LIMIT 10` ready)
- [ ] Audio: quiet room, external mic
- [ ] Resolution: 1920x1080

---

## Script

### [0:00–0:20] THE PROBLEM & ARCHITECTURE

**Show**: Architecture sidebar in Streamlit app

> "Imagine you're managing a supply chain across 50 suppliers in 12 APJ countries. Partner purchase orders and demand feeds land in **Amazon S3**. Snowflake picks them up, builds a curated layer with **Dynamic Tables** that refresh every 5 minutes, runs **ML Forecast** for demand prediction, **Cortex Search** over 100 supplier contracts, and a **Semantic View** so anyone can ask questions in plain English. The results? Written back to your data lake as **Apache Iceberg** — visible in **Glue**, queryable from **Athena**. Let me show you what that looks like."

### [0:20–0:50] TAB 1: INVENTORY HEALTH

**Show**: Click Inventory Health tab

**Tech**: `Dynamic Tables` (5-min refresh)

> "Six KPIs across 10 warehouses. We've got 31 stockouts and 323 critical items — flagged automatically by **Dynamic Tables** that refresh every 5 minutes. No ETL jobs, no Airflow."

**Action**: Scroll to stockout table

> "Singapore Hub has 10 stockouts — 4 of them from the same supplier. Let's check the scorecard."

### [0:50–1:15] TAB 2: SUPPLIER SCORECARD

**Show**: Click Supplier Scorecard tab

**Tech**: `Dynamic Tables` (supplier aggregation)

> "50 suppliers graded A through D. Incheon Frozen Logistics — Grade D, 0% on-time. Contracted lead time is 3 days, they're averaging 40. That one supplier caused 4 stockouts in Singapore Hub. That's your root cause. All from one **Dynamic Table** SQL statement."

### [1:15–1:45] TAB 4: CONTRACT SEARCH

**Show**: Click Contract Search tab, type "Incheon Frozen Logistics delivery penalties"

**Tech**: `Cortex Search` + `Cortex AI COMPLETE`

> "So Incheon is the problem — what does their contract actually say? **Cortex Search** across 100 supplier contracts, no vector DB to manage. There's Incheon's Fresh Produce Supply Agreement — penalties for spoilage exceeding 2%: 150% credit. **Cortex COMPLETE** summarizes the key terms instantly."

### [1:45–2:05] TAB 3: DEMAND FORECAST

**Show**: Click Demand Forecast tab, select a product

**Tech**: `ML FORECAST`, `ML ANOMALY_DETECTION`

> "**ML FORECAST** — 14 periods ahead, all 500 products, 7,000 predictions. No Python, no infrastructure to manage. **ANOMALY_DETECTION** flags unusual inventory movements below."

### [2:05–2:25] TAB 5: ASK SUPPLY CHAIN

**Show**: Click Ask Supply Chain tab

**Tech**: `Semantic View` + `Cortex Agent`

> "Natural language questions — a **Semantic View** with 11 dimensions and 9 metrics lets **Cortex Agent** turn plain English into SQL. 'Which warehouses have the most stockouts?' — answered instantly."

**Action**: Click the sample question, show results

### [2:25–2:55] THE AWS PAYOFF

> "Now here's where it gets interesting for your AWS teams."

**Show**: Switch to **AWS S3 console** → bucket `sg-retail-demos-2026/supply-chain/`

> "This is where partner files land — Amazon S3. Snowflake ingests directly from here."

**Show**: Switch to **AWS Glue console** → database `retail_demos_iceberg`

> "And those 7,000 ML forecast results? Snowflake wrote them back as an **Iceberg table**, registered here in **Glue**."

**Show**: Switch to **AWS Athena** → run `SELECT * FROM retail_demos_iceberg.demand_forecast_iceberg LIMIT 10`

> "Same data, queryable from **Athena**. Snowflake writes, AWS reads — one open table format, zero copy."

### [2:55–3:10] CLOSE

> "So let's recap what you just saw. Partner data lands in **Amazon S3** — Snowflake picks it up automatically. **Dynamic Tables** build a curated layer that refreshes every 5 minutes — no orchestration, no pipelines to maintain. **Cortex Search** gives you semantic search across 100 supplier contracts. **ML Forecast** predicts demand 14 periods ahead — and writes results back to your data lake as **Apache Iceberg**, registered in **AWS Glue**, queryable from **Athena**. And a **Semantic View** lets anyone — analyst or VP — ask questions in plain English."

> "That's six Snowflake capabilities, three AWS services, one platform. From stockout detection to contract analysis to demand forecasting — all connected, all live. That's Supply Chain Intelligence on Snowflake and AWS."

---

## Key Demo Differentiators (vs FSI demos)

1. **No Bedrock** — Cortex AI does everything natively. Shows Snowflake can do it alone.
2. **Iceberg export** — ML results flow BACK to the data lake. Unique bidirectional story.
3. **S3 file ingestion** — partner data comes from outside Snowflake.
4. **Supply chain specific** — stockouts, fill rates, lead times, contract penalties.
5. **QuickSight Q**: "Which suppliers missed SLA this month?" / "What's the fill rate by region?"
