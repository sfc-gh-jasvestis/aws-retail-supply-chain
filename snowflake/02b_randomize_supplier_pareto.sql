-- Apply Pareto supplier spend: top 10% strategic suppliers (12x), bottom 40% small (0.3x).
-- Recreates RAW.PURCHASE_ORDERS with hash-based per-supplier multiplier.

USE SCHEMA RETAIL_SUPPLY_CHAIN.RAW;

CREATE OR REPLACE TABLE PURCHASE_ORDERS AS
WITH sup_tier AS (
  SELECT SUPPLIER_ID, ROW_NUMBER() OVER (ORDER BY ABS(HASH(SUPPLIER_ID,'rk'))) AS rk FROM SUPPLIERS
), tiered AS (
  SELECT SUPPLIER_ID,
    CASE WHEN rk <= 5  THEN 12.0   -- top 10%
         WHEN rk <= 15 THEN 4.0
         WHEN rk <= 30 THEN 1.5
         ELSE 0.3                   -- bottom 40%
    END AS spend_mult
  FROM sup_tier
)
SELECT po.PO_ID, po.SUPPLIER_ID, po.PRODUCT_ID, po.WAREHOUSE_ID, po.ORDER_DATE, po.EXPECTED_DATE, po.ACTUAL_DATE,
  ROUND(po.QUANTITY * t.spend_mult * (60 + ABS(HASH(po.PO_ID,'qj'))%81)/100.0)::NUMBER AS QUANTITY,
  po.UNIT_COST,
  (ROUND(po.QUANTITY * t.spend_mult * (60 + ABS(HASH(po.PO_ID,'qj'))%81)/100.0) * po.UNIT_COST)::NUMBER(12,2) AS TOTAL_COST,
  po.STATUS, po.DELAY_REASON, po.LOADED_AT
FROM PURCHASE_ORDERS po JOIN tiered t ON po.SUPPLIER_ID = t.SUPPLIER_ID;
