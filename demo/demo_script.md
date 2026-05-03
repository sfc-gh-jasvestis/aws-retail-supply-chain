# Demo Script: Supply Chain Intelligence Hub
## 3-Minute Recorded Walkthrough
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
| **ML** | FORECAST + ANOMALY | 14-day demand forecast (7K predictions), inventory anomaly detection |
| **LAKE** | Iceberg → Glue | Forecast results as Iceberg table on S3, registered in AWS Glue catalog |
| **Consumption** | Streamlit | 5-tab Supply Chain Hub |
| | QuickSight | 2 datasets + Q Topic |

---

## Pre-Recording Checklist

- [ ] Verify Dynamic Tables: `SHOW DYNAMIC TABLES IN DATABASE RETAIL_SUPPLY_CHAIN` (all ACTIVE)
- [ ] Open Streamlit: `RETAIL_SUPPLY_CHAIN.APP.SUPPLY_CHAIN_HUB_APP`
- [ ] Confirm stockouts exist (Tab 1 — check red metrics)
- [ ] Test Cortex Search: Tab 4, click "What are the late delivery penalties?" — confirm results
- [ ] Test Forecast: Tab 3, select a product — confirm chart renders
- [ ] Open QuickSight: https://us-west-2.quicksight.aws.amazon.com/
- [ ] Audio: quiet room, external mic
- [ ] Resolution: 1920x1080

---

## Script

### [0:00–0:30] THE PROBLEM & ARCHITECTURE

**Show**: Architecture slide or sidebar

> "Your supply chain runs on data from 50 suppliers across 12 APJ countries. Partner files land in Amazon S3. Snowflake ingests them, transforms with Dynamic Tables that refresh every 5 minutes, runs ML forecasts, and — here's the kicker — writes results back to your data lake as Iceberg tables. Your Athena users see them instantly. Zero migration, zero ETL."

### [0:30–1:00] TAB 1: INVENTORY HEALTH

**Show**: Click Inventory Health tab

> "Let's look at inventory. Six KPIs across 10 warehouses. We've got [X] stockouts and [X] critical items right now. The Dynamic Tables flagged these automatically."

**Action**: Scroll to stockout table

> "These products hit their reorder point. The Singapore Hub has 3 stockouts in Fresh Produce. Let's find out why — check the supplier."

### [1:00–1:30] TAB 2: SUPPLIER SCORECARD

**Show**: Click Supplier Scorecard tab

> "50 suppliers graded A through D based on on-time delivery. [Name] is Grade D — only [X]% on-time. Their contracted lead time is 14 days but they're averaging [X]. That's your stockout root cause."

### [1:30–2:00] TAB 4: CONTRACT SEARCH

**Show**: Click Contract Search tab, click "What are the late delivery penalties?"

> "What does their contract say about late deliveries? Cortex Search finds it instantly across 100 contracts. The AI summary says: 1% per day late, capped at 15%, with automatic price reduction after 3 late deliveries in 30 days."

### [2:00–2:30] TAB 3: DEMAND FORECAST

**Show**: Click Demand Forecast tab, select a product

> "Snowflake ML FORECAST — 14-day ahead, per product, per warehouse. No Python, no SageMaker, no infrastructure. These forecast results? Already in your Glue catalog as an Iceberg table. Open Athena — same data, zero copy."

**Show**: Point to Iceberg export status at bottom

### [2:30–2:50] TAB 5: ASK SUPPLY CHAIN

**Show**: Click Ask Supply Chain tab

> "And for the questions you haven't thought of yet — natural language. 'Which warehouses have the lowest fill rate this week?' The Semantic View powers it."

**Action**: Type or click the sample question, show results

### [2:50–3:00] CLOSE

> "One platform. Partner files from S3, ML forecasts back to the data lake, and a VP who asks questions in plain English. That's Supply Chain Intelligence on Snowflake."

---

## Key Demo Differentiators (vs FSI demos)

1. **No Bedrock** — Cortex AI does everything natively. Shows Snowflake can do it alone.
2. **Iceberg export** — ML results flow BACK to the data lake. Unique bidirectional story.
3. **S3 file ingestion** — partner data comes from outside Snowflake.
4. **Supply chain specific** — stockouts, fill rates, lead times, contract penalties.
5. **QuickSight Q**: "Which suppliers missed SLA this month?" / "What's the fill rate by region?"
