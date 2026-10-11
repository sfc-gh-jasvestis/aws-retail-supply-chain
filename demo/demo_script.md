# Retail Supplier Delivery Risk

**Singapore - Grocery and general-merchandise retail supply chain**
Use case: On-time delivery and delivery-miss risk for suppliers feeding the Singapore distribution centres of Lantern Bay Grocers, a fictional retailer

> A fictional Singapore retail supply chain, 40 suppliers dispatching from Tuas and Pasir Panjang in the west to Changi and Tampines in the east, tracked from supplier dispatch to DC receiving: dynamic tables for on-time delivery, a holdout-evaluated delivery-miss classifier, an inbound shipment forecast and grounded AI answers. Exception checks are demo signals, not supplier audit or compliance verdicts.

## Why Snowflake

- **Dynamic tables** reconcile inbound shipments, on-time delivery, exception flags, confirmed delivery misses and supplier review completion from RAW supplier data, with checks in `run_core.py`
- **Delivery-miss classification** gives a holdout-evaluated next-7-day probability per supplier
- **Shipment forecast** projects 14 days of network-wide inbound shipments with prediction intervals, for receiving dock planning
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live shipments**: a native shipment simulator (Snowflake only) or Amazon Data Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.SUPPLIERS` (40 rows) |
| Fact table | `RAW.SUPPLIER_DAILY` (3,600 supplier-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `SIGNAL_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.DELIVERY_RISK_SCORES`, `ML.DELIVERY_RISK_HOLDOUT_METRICS`, `ML.SHIPMENT_FORECAST`, `ML.ASN_VARIANCE_ANOMALIES` |

Planning areas (supplier dispatch sites): Kallang, Pasir Panjang, Woodlands, Changi, Jurong East, Tuas, Seletar, Tampines.
Personas (fictional): Farah Iskandar, Head of Supplier Management; Marcus Teo, Inbound Replenishment Lead.
Product categories: Fresh produce supplier, Chilled dairy supplier, Ambient grocery supplier, Beverages supplier, Household goods supplier.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| On-Time Delivery (cases) | 86.3% |
| Inbound Shipments | 21,488 |
| Cases Shipped (millions) | 43 |
| Delivery Exception Flags | 519 |
| Confirmed Delivery Misses | 125 |
| Flag Precision | 24.1% |
| Pallets Held at Receiving | 51 |
| Supplier Review Completion | 76.6% |
| Suppliers Monitored | 40 |
| Alternate-Supplier Coverage | 65.6% |
| Approvals Pending | 464 |
| Active SKUs | 5,993 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily inbound shipments against exception flags, flags and confirmed delivery misses by exception signal, supplier table
2. Predictive: holdout metrics, risk bands, 14-day inbound shipment forecast, ASN quantity variance anomalies
3. Supplier Reviews: review completion, alternate-supplier coverage and pending alternate-supplier approvals, review completion against confirmed misses, then generate the action memo
4. Live Shipments: run `CALL APP.SIMULATE_SHIPMENTS(20)` (Snowflake only) or `python aws/publish_shipments.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_SHIPMENT_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- About one exception flag in four is confirmed as a delivery miss (24.1%). The rest are false positives, and that is where the inbound replenishment team loses its week.
- "Unannounced pack change" produces the most confirmed misses (31 of 73 flags); "Commit date slipped" raises the most flags (78). Port terminal system outage flags (Tuas and Pasir Panjang) hit every supplier in the planning area at once and are never confirmed.
- SUP-0033 (Pasir Panjang household goods supplier) has the most confirmed misses (18), and fresh produce suppliers have the lowest on-time delivery (81.1%).
- The risk model is evaluated on a time-based holdout: precision 0.47 and recall 0.27 at 0.5, against a 0.20 base rate. Use it to order supplier calls, not as a verdict. Forecast and anomaly figures can shift slightly with the build day.
- Port terminal outage days are excluded from model training, because the supplier did not cause them.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
