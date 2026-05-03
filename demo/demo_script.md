# Demo Script: Supply Chain Intelligence Hub
## ~3-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Pre-requisites**: Data loaded, Streamlit deployed

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Supply Chain Analyst** | Day-to-day operations | Streamlit in Snowflake | Stockouts, supplier performance, demand forecasts, contract terms |
| **VP Supply Chain** | Executive oversight | Streamlit / Snowflake Intelligence | Inventory KPIs, supplier risk, NL queries |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **Ingest** | Snowflake RAW | Supplier PO files, demand feeds, contract documents |
| **RAW** | 7 tables | SUPPLIERS (50), PRODUCTS (500), WAREHOUSES (10), INVENTORY_SNAPSHOTS (50K), PURCHASE_ORDERS (10K), DEMAND_SIGNALS (100K), SUPPLIER_CONTRACTS (100) |
| **CURATED** | 3 Dynamic Tables | INVENTORY_HEALTH, SUPPLIER_PERFORMANCE, DEMAND_TRENDS |
| **AI** | Cortex Search + Semantic View | Contract search (100 docs), Agent (11 dims, 9 metrics) |
| **ML** | FORECAST + ANOMALY | 14-period demand forecast (7K predictions across 500 products), inventory anomaly detection |
| **Consumption** | Streamlit | 5-tab Supply Chain Hub |

> For optional AWS integration (S3 ingestion, Iceberg export to Glue, Athena, QuickSight), see `aws/README.md`.

---

## Pre-Recording Checklist

- [ ] Verify Dynamic Tables: `SHOW DYNAMIC TABLES IN DATABASE RETAIL_SUPPLY_CHAIN` (all ACTIVE)
- [ ] Open Streamlit: `RETAIL_SUPPLY_CHAIN.APP.SUPPLY_CHAIN_HUB_APP`
- [ ] Confirm stockouts exist (Tab 1 — expect 31 stockouts, 10 in Singapore Hub, 3 in Fresh Produce)
- [ ] Confirm supplier grades: A(8), B(16), C(14), D(12) — check Tab 2
- [ ] Test Cortex Search: Tab 4, click "What are the late delivery penalties?" — confirm results
- [ ] Test Forecast: Tab 3, select a product — confirm chart renders
- [ ] Audio: quiet room, external mic
- [ ] Resolution: 1920x1080

---

## Script

### [0:00–0:20] THE PROBLEM & ARCHITECTURE

**Show**: Architecture sidebar in Streamlit app

> "Imagine you're managing a supply chain across 50 suppliers in 12 APJ countries. Snowflake handles everything — **Dynamic Tables** that refresh every 5 minutes, **ML Forecast** for demand prediction, **Cortex Search** over 100 supplier contracts, and a **Semantic View** so anyone can ask questions in plain English. Let me show you."

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

### [2:25–2:35] CLOSE

> "**Dynamic Tables**, **Cortex Search**, **ML Forecast**, **Anomaly Detection**, and **Semantic Views** — five Snowflake capabilities, one platform. From stockout detection to contract analysis to demand forecasting — all connected, all live. That's Supply Chain Intelligence on Snowflake."

---

## Key Demo Differentiators

1. **Pure Snowflake** — Cortex AI, Dynamic Tables, ML, Search, Semantic Views — no external services needed.
2. **Optional AWS integration** — S3 ingestion + Iceberg export to Glue/Athena (see `aws/README.md`).
3. **Supply chain specific** — stockouts, fill rates, lead times, contract penalties.
4. **Connected narrative** — stockout → supplier root cause → contract terms → forecast.
