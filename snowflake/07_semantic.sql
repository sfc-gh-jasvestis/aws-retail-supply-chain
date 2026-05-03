USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE WAREHOUSE WH_SUPPLY_CHAIN;

CREATE OR REPLACE SEMANTIC VIEW RETAIL_SUPPLY_CHAIN.AI.SUPPLY_CHAIN_SEMANTIC_VIEW

  TABLES (
    inventory AS RETAIL_SUPPLY_CHAIN.CURATED.INVENTORY_HEALTH,
    suppliers AS RETAIL_SUPPLY_CHAIN.CURATED.SUPPLIER_PERFORMANCE,
    demand AS RETAIL_SUPPLY_CHAIN.CURATED.DEMAND_TRENDS
  )

  DIMENSIONS (
    inventory.dim_product_name AS PRODUCT_NAME,
    inventory.dim_category AS CATEGORY,
    inventory.dim_warehouse AS WAREHOUSE_NAME,
    inventory.dim_region AS REGION,
    inventory.dim_status AS INVENTORY_STATUS,
    inventory.dim_date AS SNAPSHOT_DATE,
    suppliers.dim_name AS SUPPLIER_NAME,
    suppliers.dim_country AS COUNTRY,
    suppliers.dim_grade AS PERFORMANCE_GRADE,
    demand.dim_signal_date AS SIGNAL_DATE,
    demand.dim_channel AS CHANNEL
  )

  METRICS (
    inventory.total_inventory_value AS SUM(INVENTORY_VALUE),
    inventory.avg_days_of_supply AS AVG(DAYS_OF_SUPPLY),
    inventory.stockout_count AS COUNT_IF(INVENTORY_STATUS = 'STOCKOUT'),
    inventory.item_count AS COUNT(SNAPSHOT_ID),
    suppliers.avg_on_time_pct AS AVG(ON_TIME_DELIVERY_PCT),
    suppliers.total_spend AS SUM(TOTAL_SPEND),
    suppliers.num_suppliers AS COUNT(SUPPLIER_ID),
    demand.total_units_sold AS SUM(UNITS_SOLD),
    demand.avg_daily_7d AS AVG(AVG_DAILY_7D)
  )

  COMMENT = 'Supply Chain Intelligence semantic view for Cortex Agent and Snowflake Intelligence'

  AI_SQL_GENERATION 'When asked about inventory health or stock levels, query the inventory table. When asked about suppliers or delivery performance, query the suppliers table. When asked about demand or sales, query the demand table. Round numeric values to 1 decimal.';
