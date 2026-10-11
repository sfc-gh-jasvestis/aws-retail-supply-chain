-- Synthetic supplier observations for a fictional grocery and general
-- merchandise retailer supplying distribution centres in 8 Singapore planning areas.
-- 40 suppliers = 8 planning areas x 5 product categories. Nothing is seeded as a prediction. Randomness is HASH-seeded, so
-- every rebuild is reproducible: per-supplier delivery-miss propensity, drift
-- between periodic supplier performance reviews, skipped reviews,
-- category-weighted exception signals, false-positive exception flags, and two
-- port terminal system outages. Exception checks are demo
-- signals, not supplier audit or compliance verdicts.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.SUPPLIERS AS
WITH suppliers AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS SUPPLIER_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT SUPPLIER_INDEX,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'sg-rsc-program')), 1000000) / 1e6 AS U_PROGRAM,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'sg-rsc-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'sg-rsc-review')), 1000000) / 1e6 AS U_REVIEW,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'sg-rsc-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'sg-rsc-tier')), 1000000) / 1e6 AS U_TIER,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'sg-rsc-size')), 1000000) / 1e6 AS U_SIZE
  FROM suppliers
), suppliers_named AS (
  SELECT *,
         -- Every planning area x product category combination appears exactly once.
         CASE MOD(SUPPLIER_INDEX, 8) WHEN 0 THEN 'Kallang' WHEN 1 THEN 'Pasir Panjang'
              WHEN 2 THEN 'Woodlands' WHEN 3 THEN 'Changi' WHEN 4 THEN 'Jurong East'
              WHEN 5 THEN 'Tuas' WHEN 6 THEN 'Seletar'
              ELSE 'Tampines' END AS REGION,
         CASE FLOOR(SUPPLIER_INDEX / 8) WHEN 0 THEN 'Fresh produce supplier'
              WHEN 1 THEN 'Chilled dairy supplier' WHEN 2 THEN 'Ambient grocery supplier'
              WHEN 3 THEN 'Beverages supplier' ELSE 'Household goods supplier' END AS CATEGORY
  FROM draws
)
SELECT 'SUP-' || LPAD(SUPPLIER_INDEX::VARCHAR, 4, '0') AS ID,
       REGION || ' ' || CATEGORY AS NAME,
       REGION, CATEGORY, SUPPLIER_INDEX,
       1 + FLOOR(U_TIER * 3) AS RISK_TIER,
       ROUND(0.5 + U_PROGRAM * 7.5, 1) AS PROGRAM_YEARS,
       ROUND(0.6 + U_SIZE * 0.8, 3) AS SIZE_FACTOR,
       -- Base daily probability of a confirmed delivery miss, higher for
       -- capacity-constrained categories; ~15% of suppliers are weak links (x3).
       (0.004 + U_RATE * 0.020)
         * CASE CATEGORY WHEN 'Fresh produce supplier' THEN 1.4 WHEN 'Chilled dairy supplier' THEN 1.1
                         WHEN 'Ambient grocery supplier' THEN 0.5 WHEN 'Beverages supplier' THEN 0.8
                         ELSE 1.3 END
         * IFF(U_RATE > 0.85, 3, 1) AS BASE_MISS_RATE,
       7 * (1 + FLOOR(U_REVIEW * 3)) AS REVIEW_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS REVIEW_RETURN_PROB,
       -- Share of shipped cases that typically arrive after the PO commit date.
       CASE CATEGORY WHEN 'Fresh produce supplier' THEN 13 WHEN 'Chilled dairy supplier' THEN 8
                     WHEN 'Ambient grocery supplier' THEN 4 WHEN 'Beverages supplier' THEN 6
                     ELSE 11 END AS BASE_LATE_PCT,
       'Active' AS STATUS
FROM suppliers_named;

CREATE TABLE RAW.SUPPLIER_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), outage_events AS (
  -- Two port terminal system outages; every supplier in the planning area gets a flag.
  SELECT * FROM VALUES (23, 'Tuas'), (71, 'Pasir Panjang') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT s.ID AS ENTITY_ID, s.SUPPLIER_INDEX, s.CATEGORY, s.REGION, s.PROGRAM_YEARS,
         s.SIZE_FACTOR, s.BASE_LATE_PCT,
         s.BASE_MISS_RATE, s.REVIEW_INTERVAL_DAYS, s.REVIEW_RETURN_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + s.SUPPLIER_INDEX * 3, s.REVIEW_INTERVAL_DAYS) AS DAYS_SINCE_REVIEW,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-rsc-miss')), 1000000) / 1e6 AS U_MISS,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-rsc-detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-rsc-fp')), 1000000) / 1e6 AS U_FP,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-rsc-signal')), 1000000) / 1e6 AS U_SIG,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-rsc-done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-rsc-ship')), 1000000) / 1e6 AS U_SHIP,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-rsc-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-rsc-hold')), 1000000) / 1e6 AS U_HOLD,
         o.REGION IS NOT NULL AS OUTAGE_EVENT
  FROM RAW.SUPPLIERS s CROSS JOIN days d
  LEFT JOIN outage_events o ON o.DAY_INDEX = d.DAY_INDEX AND o.REGION = s.REGION
), reviews AS (
  SELECT *,
         IFF(DAYS_SINCE_REVIEW = 0, 1, 0) AS REVIEW_DUE,
         IFF(DAYS_SINCE_REVIEW = 0 AND U_DONE < REVIEW_RETURN_PROB, 1, 0) AS REVIEW_DONE,
         -- Delivery drift rises between supplier performance reviews; weak follow-up carries it over.
         DAYS_SINCE_REVIEW / REVIEW_INTERVAL_DAYS + (1 - REVIEW_RETURN_PROB) AS DRIFT
  FROM base
), activity AS (
  SELECT *,
         CASE WHEN U_MISS < LEAST(0.5, BASE_MISS_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PROGRAM_YEARS))) / 4 THEN 2
              WHEN U_MISS < LEAST(0.5, BASE_MISS_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PROGRAM_YEARS))) THEN 1
              ELSE 0 END AS MISS_COUNT
  FROM reviews
), checks AS (
  SELECT *,
         -- Goods-receipt checks confirm about 80% of misses; the rest stays undetected.
         IFF(OUTAGE_EVENT, 0, IFF(U_DETECT < 0.80, MISS_COUNT, 0)) AS CONFIRMED_COUNT,
         -- False-positive flags (cleared on receipt): higher where ASN data is weaker.
         IFF(OUTAGE_EVENT, 1, IFF(U_FP < CASE CATEGORY WHEN 'Ambient grocery supplier' THEN 0.05
                                              WHEN 'Beverages supplier' THEN 0.08
                                              WHEN 'Household goods supplier' THEN 0.13
                                              WHEN 'Chilled dairy supplier' THEN 0.11 ELSE 0.16 END, 1, 0)) AS FALSE_POSITIVE_COUNT
  FROM activity
), measured AS (
  SELECT *,
         CONFIRMED_COUNT + FALSE_POSITIVE_COUNT AS FLAG_COUNT,
         ROUND(CASE CATEGORY WHEN 'Fresh produce supplier' THEN 9 WHEN 'Chilled dairy supplier' THEN 7
                             WHEN 'Ambient grocery supplier' THEN 5 WHEN 'Beverages supplier' THEN 6 ELSE 3 END
               * SIZE_FACTOR * (0.7 + 0.6 * U_SHIP)) AS SHIPMENT_COUNT,
         -- Thousand cases per inbound shipment (a truckload or container of mixed pallets).
         CASE CATEGORY WHEN 'Fresh produce supplier' THEN 1.8 WHEN 'Chilled dairy supplier' THEN 1.4
                       WHEN 'Ambient grocery supplier' THEN 2.6 WHEN 'Beverages supplier' THEN 3.2
                       ELSE 0.9 END
           * (0.9 + 0.2 * U_NOISE) AS AVG_SHIPMENT_KUNITS,
         LEAST(95, BASE_LATE_PCT + 6 * DRIFT + 9 * MISS_COUNT + 2 * U_NOISE) AS LATE_SHARE
  FROM checks
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       SHIPMENT_COUNT,
       ROUND(SHIPMENT_COUNT * AVG_SHIPMENT_KUNITS * (1 - LATE_SHARE / 100), 2) AS ONTIME_KUNITS,
       ROUND(SHIPMENT_COUNT * AVG_SHIPMENT_KUNITS, 2) AS SHIPPED_KUNITS,
       FLAG_COUNT, CONFIRMED_COUNT,
       IFF(CONFIRMED_COUNT > 0 AND U_HOLD < 0.5, 1, 0) AS LOTS_QUARANTINED,
       CASE WHEN FLAG_COUNT = 0 THEN 'None'
            WHEN OUTAGE_EVENT THEN 'Port terminal system outage'
            WHEN CATEGORY = 'Fresh produce supplier' THEN IFF(U_SIG < 0.6, 'ASN quantity mismatch', 'Temperature log missing')
            WHEN CATEGORY = 'Chilled dairy supplier' THEN IFF(U_SIG < 0.55, 'Cold chain excursion', 'Carrier pickup missed')
            WHEN CATEGORY = 'Ambient grocery supplier' THEN IFF(U_SIG < 0.45, 'Capacity allocation cut', IFF(U_SIG < 0.8, 'Commit date slipped', 'ASN quantity mismatch'))
            WHEN CATEGORY = 'Beverages supplier' THEN IFF(U_SIG < 0.55, 'Shelf-life window short', 'Import permit pending')
            ELSE IFF(U_SIG < 0.5, 'Unannounced pack change', 'Commit date slipped') END AS RISK_SIGNAL,
       REVIEW_DUE, REVIEW_DONE,
       ROUND(0.4 + 1.8 * DRIFT + 3.2 * MISS_COUNT + U_NOISE * 0.9, 2) AS ASN_VARIANCE_PCT,
       ROUND(LATE_SHARE, 1) AS LATE_PCT,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- SKU sourcing snapshot per supplier: active SKUs, SKUs with an
-- approved alternate supplier on file, and alternate-supplier approvals in progress.
CREATE TABLE RAW.SKU_SOURCING AS
WITH sized AS (
  SELECT ID, CATEGORY,
         ROUND(CASE CATEGORY WHEN 'Fresh produce supplier' THEN 70 WHEN 'Chilled dairy supplier' THEN 55
                             WHEN 'Ambient grocery supplier' THEN 240 WHEN 'Beverages supplier' THEN 110 ELSE 300 END
               * (0.6 + MOD(ABS(HASH(ID, 'sg-rsc-parts')), 1000000) / 1e6 * 0.8)) AS PARTS,
         CASE CATEGORY WHEN 'Fresh produce supplier' THEN 0.52 WHEN 'Chilled dairy supplier' THEN 0.41
                       WHEN 'Ambient grocery supplier' THEN 0.72 WHEN 'Beverages supplier' THEN 0.63 ELSE 0.35 END
           + MOD(ABS(HASH(ID, 'sg-rsc-second')), 1000000) / 1e6 * 0.25 AS SECOND_SOURCE_SHARE
  FROM RAW.SUPPLIERS
)
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Fresh produce supplier' THEN 'Alternate grower approval'
                     WHEN 'Chilled dairy supplier' THEN 'Alternate dairy approval'
                     WHEN 'Ambient grocery supplier' THEN 'Alternate manufacturer approval'
                     WHEN 'Beverages supplier' THEN 'Alternate bottler approval'
                     ELSE 'Alternate vendor approval' END AS EVIDENCE_TYPE,
       PARTS AS REQUIRED_QTY,
       LEAST(PARTS, ROUND(PARTS * SECOND_SOURCE_SHARE)) AS ON_FILE_QTY,
       ROUND((PARTS - LEAST(PARTS, ROUND(PARTS * SECOND_SOURCE_SHARE))) * MOD(ABS(HASH(ID, 'sg-rsc-pending')), 1000000) / 1e6 * 0.5) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM sized;
