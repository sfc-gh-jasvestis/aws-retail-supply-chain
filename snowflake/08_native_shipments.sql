-- ============================================================================
-- 08_native_shipments.sql - Snowflake-only build: live inbound-shipment feed without AWS.
-- Creates RAW.LIVE_SHIPMENTS (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_SHIPMENTS(N), which inserts synthetic
-- supplier inbound-shipment events with the same value ranges and ~10% FLAG
-- rate (shipment whose ASN quantity variance is out of tolerance) as aws/publish_shipments.py.
-- Rows are inserted directly; this simulates a supplier shipment feed and is not
-- Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_SHIPMENTS).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_SHIPMENTS (
  SUPPLIER_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, SHIPMENT_KUNITS FLOAT, ASN_VARIANCE_PCT FLOAT,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_SHIPMENTS(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_SHIPMENTS (SUPPLIER_ID, EVENT_TS, SHIPMENT_KUNITS, ASN_VARIANCE_PCT, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'SUP-' || LPAD(UNIFORM(0, 39, RANDOM())::VARCHAR, 4, '0') AS SUPPLIER_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.1 AS IS_FLAG,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs a constant mean, so the flag offset is added outside it.
    SELECT SUPPLIER_ID, TS,
           ROUND(IFF(IS_FLAG, 1.6, 2.2) * EXP(NORMAL(0, 0.15, RANDOM())), 2),
           ROUND(GREATEST(0, IFF(IS_FLAG, 7.6, 1.2) + NORMAL(0, 0.9, RANDOM())), 2),
           IFF(IS_FLAG, 'FLAG', 'OK'), TS, 'APP.SIMULATE_SHIPMENTS'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_SHIPMENTS
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_SHIPMENTS(5);
