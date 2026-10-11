-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live inbound-shipment alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes validated __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_SHIPMENTS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic supplier delivery-exception SOPs (clearly synthetic, not audit guidance) ----------
CREATE OR REPLACE TABLE SEARCH.DELIVERY_SOP_DOCS AS
WITH signals AS (
  SELECT DISTINCT r.RISK_SIGNAL, s.CATEGORY
  FROM RAW.SUPPLIER_DAILY r JOIN RAW.SUPPLIERS s ON s.ID = r.ENTITY_ID
  WHERE r.CONFIRMED_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, RISK_SIGNAL)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  RISK_SIGNAL,
  CATEGORY || ' - ' || RISK_SIGNAL || ' follow-up' AS TITLE,
  'Synthetic demo SOP for a fictional Singapore retail supply chain; not supplier audit or compliance guidance. Product category: ' || CATEGORY || '. Exception signal: ' || RISK_SIGNAL || '. '
  || 'Step 1: hold the affected pallets in the receiving bay, and notify the replenishment lead and the category buyer within 1 business day. '
  || 'Step 2: ' || CASE
       WHEN RISK_SIGNAL = 'ASN quantity mismatch' THEN 'count the received cases against the advance shipping notice and the packing list, and raise a quantity discrepancy with the supplier.'
       WHEN RISK_SIGNAL = 'Temperature log missing' THEN 'request the reefer temperature log for the trip, and keep the pallets on hold until the log covers the whole journey.'
       WHEN RISK_SIGNAL = 'Cold chain excursion' THEN 'probe a sample of cases from each pallet, and compare the readings with the product temperature band before putting stock away.'
       WHEN RISK_SIGNAL = 'Carrier pickup missed' THEN 'confirm the new pickup slot with the forwarder, and check whether store and DC stock covers the gap until the revised arrival date.'
       WHEN RISK_SIGNAL = 'Capacity allocation cut' THEN 'ask the supplier for the revised weekly allocation in writing, and check whether an approved alternate supplier can cover the shortfall.'
       WHEN RISK_SIGNAL = 'Commit date slipped' THEN 'record the new commit date against the purchase order, and escalate to the supplier account manager if the slip exceeds 3 days.'
       WHEN RISK_SIGNAL = 'Shelf-life window short' THEN 'check the remaining shelf life against the minimum receiving life for the category, and reject pallets that would expire before sale.'
       WHEN RISK_SIGNAL = 'Import permit pending' THEN 'confirm the permit status with the forwarder and the import compliance team, and hold the shipment at the bonded area until the permit is on file.'
       WHEN RISK_SIGNAL = 'Unannounced pack change' THEN 'request the pack change notification and the new case dimensions from the supplier, and keep the pallets out of pick slots until the item master is updated.'
       ELSE 'review the shipment against the purchase order and escalate if unexplained.'
     END
  || ' Step 3: if the ASN variance exceeds 5% or more than a quarter of the cases arrived after the commit date, open a supplier corrective action request. '
  || 'Step 4: record the outcome and the evidence; release held pallets only with sign-off from the DC receiving lead.' AS CONTENT
FROM signals;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.DELIVERY_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, RISK_SIGNAL
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, RISK_SIGNAL, CONTENT FROM SEARCH.DELIVERY_SOP_DOCS);

-- ---------- ASN quantity variance anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.ASN_VARIANCE_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, ASN_VARIANCE_PCT::FLOAT AS ASN_VARIANCE
FROM RAW.SUPPLIER_DAILY;
CREATE OR REPLACE VIEW ML.ASN_VARIANCE_TRAIN AS
SELECT * FROM ML.ASN_VARIANCE_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.ASN_VARIANCE_SERIES);
CREATE OR REPLACE VIEW ML.ASN_VARIANCE_DETECT AS
SELECT * FROM ML.ASN_VARIANCE_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.ASN_VARIANCE_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.ASN_VARIANCE_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.ASN_VARIANCE_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'ASN_VARIANCE',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.ASN_VARIANCE_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS ASN_VARIANCE, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.ASN_VARIANCE_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.ASN_VARIANCE_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'ASN_VARIANCE'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.SUPPLY_CHAIN_ANALYTICS
  TABLES (
    suppliers AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'suppliers', 'vendors')
      COMMENT = 'One row per supplier (planning area x product category), 90-day totals',
    risk AS ML.DELIVERY_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day probability of a confirmed delivery miss per supplier',
    signals AS CURATED.SIGNAL_SUMMARY PRIMARY KEY (RISK_SIGNAL)
      COMMENT = 'Delivery exception flags, confirmed delivery misses and held pallets by exception signal, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_supplier AS risk (ENTITY_ID) REFERENCES suppliers)
  FACTS (
    suppliers.shipments_f AS SHIPMENT_COUNT,
    suppliers.ontime_f AS ONTIME_KUNITS,
    suppliers.shipped_f AS SHIPPED_KUNITS,
    suppliers.flags_f AS FLAG_COUNT,
    suppliers.confirmed_f AS CONFIRMED_COUNT,
    suppliers.quarantined_f AS QUARANTINED_COUNT,
    suppliers.review_due_f AS REVIEW_DUE,
    suppliers.review_done_f AS REVIEW_DONE,
    risk.miss_prob_f AS MISS_PROB_7D,
    signals.sig_flags_f AS FLAG_COUNT,
    signals.sig_confirmed_f AS CONFIRMED_COUNT,
    signals.sig_quarantined_f AS QUARANTINED_COUNT,
    daily.day_shipments_f AS SHIPMENT_COUNT,
    daily.day_ontime_f AS ONTIME_KUNITS,
    daily.day_shipped_f AS SHIPPED_KUNITS,
    daily.day_flags_f AS FLAG_COUNT
  )
  DIMENSIONS (
    suppliers.supplier_id AS ENTITY_ID WITH SYNONYMS = ('entity', 'supplier', 'supplier id'),
    suppliers.supplier_name AS ENTITY_NAME,
    suppliers.planning_area AS REGION WITH SYNONYMS = ('planning area', 'region', 'supplier location') COMMENT = 'Singapore planning area of the supplier dispatch site',
    suppliers.product_category AS CATEGORY WITH SYNONYMS = ('product category', 'supplier type', 'category'),
    suppliers.risk_tier AS RISK_TIER COMMENT = 'Supply risk tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    signals.risk_signal AS RISK_SIGNAL WITH SYNONYMS = ('signal', 'exception signal', 'delivery exception'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    suppliers.supplier_count AS COUNT(suppliers.supplier_id) WITH SYNONYMS = ('number of entities', 'number of suppliers'),
    suppliers.on_time_quantity_pct AS 100 * SUM(suppliers.ontime_f) / NULLIF(SUM(suppliers.shipped_f), 0)
      COMMENT = 'Cases received by the PO commit date / cases shipped',
    suppliers.total_shipments AS SUM(suppliers.shipments_f) WITH SYNONYMS = ('inbound shipments', 'shipments'),
    suppliers.total_ontime_kunits AS SUM(suppliers.ontime_f) WITH SYNONYMS = ('on-time cases', 'thousand cases on time'),
    suppliers.total_shipped_kunits AS SUM(suppliers.shipped_f) WITH SYNONYMS = ('cases shipped', 'thousand cases shipped'),
    suppliers.total_flags AS SUM(suppliers.flags_f) WITH SYNONYMS = ('delivery exception flags', 'flags'),
    suppliers.total_confirmed AS SUM(suppliers.confirmed_f) WITH SYNONYMS = ('confirmed delivery misses', 'confirmed misses'),
    suppliers.total_quarantined AS SUM(suppliers.quarantined_f) WITH SYNONYMS = ('held pallets', 'pallets held'),
    suppliers.flag_precision_pct AS 100 * SUM(suppliers.confirmed_f) / NULLIF(SUM(suppliers.flags_f), 0)
      COMMENT = 'Confirmed delivery misses / delivery exception flags',
    suppliers.review_rate_pct AS 100 * SUM(suppliers.review_done_f) / NULLIF(SUM(suppliers.review_due_f), 0)
      COMMENT = 'Supplier performance reviews completed / reviews due',
    risk.avg_miss_prob AS AVG(risk.miss_prob_f),
    signals.signal_flags AS SUM(signals.sig_flags_f),
    signals.signal_confirmed AS SUM(signals.sig_confirmed_f),
    signals.signal_quarantined AS SUM(signals.sig_quarantined_f),
    signals.signal_precision_pct AS 100 * SUM(signals.sig_confirmed_f) / NULLIF(SUM(signals.sig_flags_f), 0),
    daily.daily_shipments AS SUM(daily.day_shipments_f),
    daily.daily_shipped_kunits AS SUM(daily.day_shipped_f),
    daily.daily_on_time_pct AS 100 * SUM(daily.day_ontime_f) / NULLIF(SUM(daily.day_shipped_f), 0),
    daily.daily_flags AS SUM(daily.day_flags_f)
  )
  COMMENT = 'Synthetic Singapore retail supplier delivery-risk analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.SUPPLY_CHAIN_AGENT
  COMMENT = 'Supplier delivery-risk assistant over a synthetic Singapore retail supply chain'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic and that delivery exception checks are demo signals, not supplier audit or compliance verdicts. Give supplier IDs and numbers with cases."
  orchestration: "Use supply_analyst for inbound shipments, cases shipped and cases on time, on-time delivery, delivery exception flags, confirmed delivery misses, held pallets, supplier performance reviews, planning areas, product categories, exception signals and delivery-miss risk. Use sop_search for follow-up procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: supply_analyst
      description: "Inbound shipments, cases shipped, on-time delivery, delivery exception flags, confirmed delivery misses, held pallets, flag precision, supplier review completion, exception signals and delivery-miss risk scores by supplier"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic supplier delivery-exception follow-up SOPs by product category and exception signal"
tool_resources:
  supply_analyst:
    semantic_view: __DEMO_DB__.APP.SUPPLY_CHAIN_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.DELIVERY_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live inbound-shipment alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), SUPPLIER_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, SHIPMENT_KUNITS FLOAT, ASN_VARIANCE_PCT FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION SG_RETAIL_SUPPLY_CHAIN_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_FLAGS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (SUPPLIER_ID, EVENT_TS, SHIPMENT_KUNITS, ASN_VARIANCE_PCT, SOP_HINT)
    SELECT c.SUPPLIER_ID, c.EVENT_TS, c.SHIPMENT_KUNITS, c.ASN_VARIANCE_PCT,
           'Check ' || m.CATEGORY || ' delivery SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_SHIPMENTS c
    JOIN RAW.SUPPLIERS m ON m.ID = c.SUPPLIER_ID
    LEFT JOIN ML.DELIVERY_RISK_SCORES r ON r.ENTITY_ID = c.SUPPLIER_ID
    WHERE c.STATUS = 'FLAG'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SUPPLIER_ID = c.SUPPLIER_ID AND l.EVENT_TS = c.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('SG_RETAIL_SUPPLY_CHAIN_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Inbound shipment exception alert',
      'New flagged live inbound shipments logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_SHIPMENT_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_SHIPMENTS c
    WHERE c.STATUS = 'FLAG'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SUPPLIER_ID = c.SUPPLIER_ID AND l.EVENT_TS = c.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_FLAGS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.SIGNAL_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.DELIVERY_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.DELIVERY_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.DELIVERY_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'RISK_TIER', RISK_TIER, 'PROGRAM_YEARS', PROGRAM_YEARS,
             'ASN_VARIANCE_PCT', ASN_VARIANCE_PCT, 'LATE_PCT', LATE_PCT,
             'ASN_VARIANCE_7D', ASN_VARIANCE_7D, 'CONFIRMED_30D', CONFIRMED_30D,
           'DAYS_SINCE_REVIEW', DAYS_SINCE_REVIEW, 'REVIEW_RATE_30D', REVIEW_RATE_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:MISS::FLOAT, 4) AS MISS_PROB_7D,
         CASE WHEN PRED:probability:MISS::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:MISS::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
