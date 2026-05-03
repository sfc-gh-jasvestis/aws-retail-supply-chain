USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_SUPPLY_CHAIN;
USE SCHEMA RAW;
USE WAREHOUSE WH_SUPPLY_CHAIN;

CREATE OR REPLACE TABLE SUPPLIERS (
    SUPPLIER_ID STRING NOT NULL,
    NAME STRING,
    COUNTRY STRING,
    CITY STRING,
    CATEGORY STRING,
    RELIABILITY_SCORE NUMBER(3,2),
    LEAD_TIME_DAYS NUMBER(5,0),
    PAYMENT_TERMS STRING,
    CONTACT_EMAIL STRING,
    ONBOARDED_DATE DATE,
    LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE PRODUCTS (
    PRODUCT_ID STRING NOT NULL,
    SKU STRING,
    NAME STRING,
    CATEGORY STRING,
    SUB_CATEGORY STRING,
    UNIT_COST NUMBER(10,2),
    UNIT_PRICE NUMBER(10,2),
    SUPPLIER_ID STRING,
    WEIGHT_KG NUMBER(6,2),
    SHELF_LIFE_DAYS NUMBER(5,0),
    LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE WAREHOUSES (
    WAREHOUSE_ID STRING NOT NULL,
    NAME STRING,
    REGION STRING,
    CITY STRING,
    COUNTRY STRING,
    CAPACITY_UNITS NUMBER(10,0),
    MANAGER_NAME STRING,
    LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE INVENTORY_SNAPSHOTS (
    SNAPSHOT_ID STRING NOT NULL,
    PRODUCT_ID STRING,
    WAREHOUSE_ID STRING,
    SNAPSHOT_DATE DATE,
    QUANTITY_ON_HAND NUMBER(10,0),
    REORDER_POINT NUMBER(10,0),
    SAFETY_STOCK NUMBER(10,0),
    DAYS_OF_SUPPLY NUMBER(5,1),
    LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE PURCHASE_ORDERS (
    PO_ID STRING NOT NULL,
    SUPPLIER_ID STRING,
    PRODUCT_ID STRING,
    WAREHOUSE_ID STRING,
    ORDER_DATE DATE,
    EXPECTED_DATE DATE,
    ACTUAL_DATE DATE,
    QUANTITY NUMBER(10,0),
    UNIT_COST NUMBER(10,2),
    TOTAL_COST NUMBER(12,2),
    STATUS STRING,
    DELAY_REASON STRING,
    LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE DEMAND_SIGNALS (
    SIGNAL_ID STRING NOT NULL,
    PRODUCT_ID STRING,
    WAREHOUSE_ID STRING,
    SIGNAL_DATE DATE,
    UNITS_SOLD NUMBER(10,0),
    CHANNEL STRING,
    LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE SUPPLIER_CONTRACTS (
    CONTRACT_ID STRING NOT NULL,
    SUPPLIER_ID STRING,
    TITLE STRING,
    CONTRACT_TEXT STRING,
    START_DATE DATE,
    END_DATE DATE,
    ANNUAL_VALUE NUMBER(12,2),
    LOADED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO SUPPLIERS
SELECT
    'SUP-' || LPAD(SEQ4()::STRING, 4, '0'),
    CASE MOD(SEQ4(), 50)
        WHEN 0 THEN 'Pacific Fresh Foods' WHEN 1 THEN 'Dragon Logistics Corp' WHEN 2 THEN 'Nippon Ingredients Co'
        WHEN 3 THEN 'Thai Spice Traders' WHEN 4 THEN 'Melbourne Packaging' WHEN 5 THEN 'Seoul Beverages Ltd'
        WHEN 6 THEN 'Manila Dry Goods' WHEN 7 THEN 'Jakarta Palm Oil' WHEN 8 THEN 'Vietnam Coffee Roasters'
        WHEN 9 THEN 'Shanghai Frozen Foods' WHEN 10 THEN 'Bangalore Spices Intl' WHEN 11 THEN 'Wellington Dairy Co'
        WHEN 12 THEN 'Kuala Lumpur Snacks' WHEN 13 THEN 'Taipei Tea Masters' WHEN 14 THEN 'Osaka Seafood Direct'
        WHEN 15 THEN 'Perth Grain Supplies' WHEN 16 THEN 'Hanoi Rice Mills' WHEN 17 THEN 'Cebu Coconut Products'
        WHEN 18 THEN 'Chiang Mai Organics' WHEN 19 THEN 'Auckland Meats Ltd' WHEN 20 THEN 'Surabaya Palm Oils'
        WHEN 21 THEN 'Busan Kimchi Co' WHEN 22 THEN 'Dhaka Textiles Pkg' WHEN 23 THEN 'Colombo Tea Exports'
        WHEN 24 THEN 'Hong Kong Cold Chain' WHEN 25 THEN 'Penang Noodle Works' WHEN 26 THEN 'Sapporo Brewery Supply'
        WHEN 27 THEN 'Brisbane Bakery Inputs' WHEN 28 THEN 'Shenzhen Electronics Pkg' WHEN 29 THEN 'Mumbai Masala Corp'
        WHEN 30 THEN 'Phnom Penh Rice Co' WHEN 31 THEN 'Vientiane Herbs Ltd' WHEN 32 THEN 'Yangon Seafood Fresh'
        WHEN 33 THEN 'Christchurch Lamb Exports' WHEN 34 THEN 'Davao Fruit Traders' WHEN 35 THEN 'Bandung Coffee Beans'
        WHEN 36 THEN 'Kaohsiung Canned Goods' WHEN 37 THEN 'Nagoya Auto Parts Pkg' WHEN 38 THEN 'Hyderabad Bulk Foods'
        WHEN 39 THEN 'Johor Bahru Plastics' WHEN 40 THEN 'Incheon Frozen Logistics' WHEN 41 THEN 'Adelaide Wine Supplies'
        WHEN 42 THEN 'Kunming Mushroom Farm' WHEN 43 THEN 'Chittagong Jute Packaging' WHEN 44 THEN 'Kandy Cinnamon Exports'
        WHEN 45 THEN 'Macau Distribution Co' WHEN 46 THEN 'Phuket Seafood Direct' WHEN 47 THEN 'Gold Coast Organics'
        WHEN 48 THEN 'Dalian Soybean Products' WHEN 49 THEN 'Kathmandu Honey Co'
    END,
    CASE MOD(SEQ4(), 12) WHEN 0 THEN 'Australia' WHEN 1 THEN 'China' WHEN 2 THEN 'Japan' WHEN 3 THEN 'Thailand'
        WHEN 4 THEN 'Vietnam' WHEN 5 THEN 'South Korea' WHEN 6 THEN 'Philippines' WHEN 7 THEN 'Indonesia'
        WHEN 8 THEN 'India' WHEN 9 THEN 'New Zealand' WHEN 10 THEN 'Malaysia' WHEN 11 THEN 'Singapore' END,
    CASE MOD(SEQ4(), 12) WHEN 0 THEN 'Melbourne' WHEN 1 THEN 'Shanghai' WHEN 2 THEN 'Tokyo' WHEN 3 THEN 'Bangkok'
        WHEN 4 THEN 'Ho Chi Minh City' WHEN 5 THEN 'Seoul' WHEN 6 THEN 'Manila' WHEN 7 THEN 'Jakarta'
        WHEN 8 THEN 'Mumbai' WHEN 9 THEN 'Auckland' WHEN 10 THEN 'Kuala Lumpur' WHEN 11 THEN 'Singapore' END,
    CASE MOD(SEQ4(), 8) WHEN 0 THEN 'Fresh Produce' WHEN 1 THEN 'Beverages' WHEN 2 THEN 'Frozen Foods'
        WHEN 3 THEN 'Dry Goods' WHEN 4 THEN 'Dairy' WHEN 5 THEN 'Packaging' WHEN 6 THEN 'Spices & Condiments'
        WHEN 7 THEN 'Seafood' END,
    ROUND(0.60 + RANDOM() / POW(2, 63) * 0.40, 2),
    CASE MOD(SEQ4(), 5) WHEN 0 THEN 3 WHEN 1 THEN 7 WHEN 2 THEN 14 WHEN 3 THEN 21 WHEN 4 THEN 30 END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Net 30' WHEN 1 THEN 'Net 60' WHEN 2 THEN 'Net 90' END,
    LOWER(REPLACE(CASE MOD(SEQ4(), 50)
        WHEN 0 THEN 'Pacific Fresh Foods' WHEN 1 THEN 'Dragon Logistics Corp' ELSE 'supplier' || SEQ4()::STRING END, ' ', '.')) || '@supplier.com',
    DATEADD('day', -FLOOR(RANDOM() / POW(2, 63) * 1800 + 365)::INT, CURRENT_DATE())
FROM TABLE(GENERATOR(ROWCOUNT => 50));

INSERT INTO WAREHOUSES VALUES
    ('WH-001', 'Singapore Hub', 'ASEAN', 'Singapore', 'Singapore', 500000, 'Rachel Lim', CURRENT_TIMESTAMP()),
    ('WH-002', 'Sydney DC', 'ANZ', 'Sydney', 'Australia', 350000, 'James Mitchell', CURRENT_TIMESTAMP()),
    ('WH-003', 'Tokyo Central', 'North Asia', 'Tokyo', 'Japan', 400000, 'Yuki Tanaka', CURRENT_TIMESTAMP()),
    ('WH-004', 'Bangkok Hub', 'ASEAN', 'Bangkok', 'Thailand', 250000, 'Somchai Patel', CURRENT_TIMESTAMP()),
    ('WH-005', 'Mumbai DC', 'South Asia', 'Mumbai', 'India', 300000, 'Priya Sharma', CURRENT_TIMESTAMP()),
    ('WH-006', 'Shanghai Hub', 'North Asia', 'Shanghai', 'China', 450000, 'Wei Chen', CURRENT_TIMESTAMP()),
    ('WH-007', 'Jakarta DC', 'ASEAN', 'Jakarta', 'Indonesia', 200000, 'Budi Santoso', CURRENT_TIMESTAMP()),
    ('WH-008', 'Seoul DC', 'North Asia', 'Seoul', 'South Korea', 280000, 'Min-Jun Park', CURRENT_TIMESTAMP()),
    ('WH-009', 'Auckland DC', 'ANZ', 'Auckland', 'New Zealand', 180000, 'Sarah Thompson', CURRENT_TIMESTAMP()),
    ('WH-010', 'KL Hub', 'ASEAN', 'Kuala Lumpur', 'Malaysia', 220000, 'Ahmad Ibrahim', CURRENT_TIMESTAMP());

INSERT INTO PRODUCTS
SELECT
    'PRD-' || LPAD(SEQ4()::STRING, 5, '0'),
    'SKU-' || LPAD(FLOOR(RANDOM() / POW(2, 63) * 90000 + 10000)::STRING, 5, '0'),
    CASE MOD(SEQ4(), 50)
        WHEN 0 THEN 'Organic Basmati Rice 5kg' WHEN 1 THEN 'Thai Jasmine Rice 10kg' WHEN 2 THEN 'Japanese Soy Sauce 1L'
        WHEN 3 THEN 'Vietnamese Coffee Beans 500g' WHEN 4 THEN 'Australian Wagyu Beef 1kg' WHEN 5 THEN 'Korean Kimchi 500g'
        WHEN 6 THEN 'Filipino Coconut Milk 400ml' WHEN 7 THEN 'Indonesian Palm Oil 5L' WHEN 8 THEN 'Indian Turmeric Powder 250g'
        WHEN 9 THEN 'NZ Cheddar Cheese 500g' WHEN 10 THEN 'Green Tea Matcha 100g' WHEN 11 THEN 'Frozen Prawns 1kg'
        WHEN 12 THEN 'Mango Chutney 350g' WHEN 13 THEN 'Sriracha Hot Sauce 500ml' WHEN 14 THEN 'Pandan Extract 250ml'
        WHEN 15 THEN 'Dried Shiitake 200g' WHEN 16 THEN 'Coconut Water 1L' WHEN 17 THEN 'Fish Sauce 500ml'
        WHEN 18 THEN 'Ramen Noodles 5pk' WHEN 19 THEN 'Lamb Cutlets Frozen 1kg' WHEN 20 THEN 'Sambal Oelek 250g'
        WHEN 21 THEN 'Miso Paste White 500g' WHEN 22 THEN 'Rice Paper Rolls 200g' WHEN 23 THEN 'Ceylon Tea 100 bags'
        WHEN 24 THEN 'Char Siu Sauce 400ml' WHEN 25 THEN 'Laksa Paste 250g' WHEN 26 THEN 'Sake Cooking 750ml'
        WHEN 27 THEN 'Sourdough Flour 2kg' WHEN 28 THEN 'Eco Packaging Wrap 100m' WHEN 29 THEN 'Garam Masala 200g'
        WHEN 30 THEN 'Palm Sugar 500g' WHEN 31 THEN 'Lemongrass Stems Fresh' WHEN 32 THEN 'Barramundi Fillets 500g'
        WHEN 33 THEN 'Lamb Shanks NZ 1kg' WHEN 34 THEN 'Dried Mango 250g' WHEN 35 THEN 'Arabica Beans Premium 1kg'
        WHEN 36 THEN 'Canned Lychee 400g' WHEN 37 THEN 'Biodegradable Containers 50pk' WHEN 38 THEN 'Cardamom Pods 100g'
        WHEN 39 THEN 'Nasi Lemak Kit 4 Serve' WHEN 40 THEN 'Frozen Gyoza 20pk' WHEN 41 THEN 'Shiraz Wine Case 6x750ml'
        WHEN 42 THEN 'Wild Mushroom Mix 200g' WHEN 43 THEN 'Jute Shopping Bags 10pk' WHEN 44 THEN 'Cinnamon Sticks 100g'
        WHEN 45 THEN 'Dim Sum Frozen Assort 24pk' WHEN 46 THEN 'Tom Yum Paste 250g' WHEN 47 THEN 'Organic Avocados 6pk'
        WHEN 48 THEN 'Edamame Frozen 500g' WHEN 49 THEN 'Manuka Honey 250g'
    END,
    CASE MOD(SEQ4(), 8) WHEN 0 THEN 'Fresh Produce' WHEN 1 THEN 'Beverages' WHEN 2 THEN 'Frozen Foods'
        WHEN 3 THEN 'Dry Goods' WHEN 4 THEN 'Dairy' WHEN 5 THEN 'Packaging' WHEN 6 THEN 'Spices & Condiments'
        WHEN 7 THEN 'Seafood' END,
    CASE MOD(SEQ4(), 10) WHEN 0 THEN 'Rice & Grains' WHEN 1 THEN 'Tea & Coffee' WHEN 2 THEN 'Sauces' WHEN 3 THEN 'Beans & Pulses'
        WHEN 4 THEN 'Cheese' WHEN 5 THEN 'Wraps & Containers' WHEN 6 THEN 'Ground Spices' WHEN 7 THEN 'Prawns'
        WHEN 8 THEN 'Noodles & Pasta' WHEN 9 THEN 'Meat' END,
    ROUND(2.50 + RANDOM() / POW(2, 63) * 47.50, 2),
    ROUND(5.00 + RANDOM() / POW(2, 63) * 95.00, 2),
    'SUP-' || LPAD(FLOOR(RANDOM() / POW(2, 63) * 50)::STRING, 4, '0'),
    ROUND(0.10 + RANDOM() / POW(2, 63) * 9.90, 2),
    CASE MOD(SEQ4(), 5) WHEN 0 THEN 7 WHEN 1 THEN 30 WHEN 2 THEN 90 WHEN 3 THEN 365 WHEN 4 THEN 730 END,
    CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 500));

INSERT INTO INVENTORY_SNAPSHOTS
SELECT
    'INV-' || LPAD(SEQ4()::STRING, 7, '0'),
    'PRD-' || LPAD(FLOOR(RANDOM() / POW(2, 63) * 500)::STRING, 5, '0'),
    'WH-' || LPAD((MOD(SEQ4(), 10) + 1)::STRING, 3, '0'),
    DATEADD('day', -MOD(SEQ4(), 90), CURRENT_DATE()),
    GREATEST(0, FLOOR(50 + RANDOM() / POW(2, 63) * 950)::INT),
    FLOOR(100 + RANDOM() / POW(2, 63) * 200)::INT,
    FLOOR(30 + RANDOM() / POW(2, 63) * 70)::INT,
    ROUND(1.0 + RANDOM() / POW(2, 63) * 29.0, 1),
    CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 50000));

INSERT INTO PURCHASE_ORDERS
SELECT
    'PO-' || LPAD(SEQ4()::STRING, 6, '0'),
    'SUP-' || LPAD(FLOOR(RANDOM() / POW(2, 63) * 50)::STRING, 4, '0'),
    'PRD-' || LPAD(FLOOR(RANDOM() / POW(2, 63) * 500)::STRING, 5, '0'),
    'WH-' || LPAD((MOD(SEQ4(), 10) + 1)::STRING, 3, '0'),
    DATEADD('day', -FLOOR(RANDOM() / POW(2, 63) * 180)::INT, CURRENT_DATE()),
    DATEADD('day', -FLOOR(RANDOM() / POW(2, 63) * 160)::INT + 14, CURRENT_DATE()),
    CASE WHEN MOD(SEQ4(), 5) < 4
        THEN DATEADD('day', -FLOOR(RANDOM() / POW(2, 63) * 150)::INT + 14 + CASE WHEN MOD(SEQ4(), 7) = 0 THEN FLOOR(RANDOM() / POW(2, 63) * 10)::INT ELSE 0 END, CURRENT_DATE())
        ELSE NULL END,
    FLOOR(50 + RANDOM() / POW(2, 63) * 950)::INT,
    ROUND(3.00 + RANDOM() / POW(2, 63) * 47.00, 2),
    NULL,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'PENDING' WHEN 1 THEN 'PENDING' WHEN 2 THEN 'IN_TRANSIT' WHEN 3 THEN 'IN_TRANSIT'
        WHEN 4 THEN 'DELIVERED' WHEN 5 THEN 'DELIVERED' WHEN 6 THEN 'DELIVERED' WHEN 7 THEN 'DELIVERED'
        WHEN 8 THEN 'DELAYED' WHEN 9 THEN 'CANCELLED' END,
    CASE WHEN MOD(SEQ4(), 10) = 8 THEN
        CASE MOD(SEQ4(), 6)
            WHEN 0 THEN 'Port congestion at origin' WHEN 1 THEN 'Customs clearance delay'
            WHEN 2 THEN 'Quality inspection failed' WHEN 3 THEN 'Weather disruption (typhoon)'
            WHEN 4 THEN 'Supplier production backlog' WHEN 5 THEN 'Shipping vessel rescheduled'
        END ELSE NULL END,
    CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

UPDATE PURCHASE_ORDERS SET TOTAL_COST = QUANTITY * UNIT_COST;

INSERT INTO DEMAND_SIGNALS
SELECT
    'DEM-' || LPAD(SEQ4()::STRING, 8, '0'),
    'PRD-' || LPAD(FLOOR(RANDOM() / POW(2, 63) * 500)::STRING, 5, '0'),
    'WH-' || LPAD((MOD(SEQ4(), 10) + 1)::STRING, 3, '0'),
    DATEADD('day', -MOD(SEQ4(), 180), CURRENT_DATE()),
    GREATEST(1, FLOOR(5 + RANDOM() / POW(2, 63) * 95)::INT),
    CASE MOD(SEQ4(), 5) WHEN 0 THEN 'In-Store' WHEN 1 THEN 'Online' WHEN 2 THEN 'Marketplace'
        WHEN 3 THEN 'Wholesale' WHEN 4 THEN 'Mobile App' END,
    CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 100000));

INSERT INTO SUPPLIER_CONTRACTS
SELECT
    'CON-' || LPAD(SEQ4()::STRING, 4, '0'),
    'SUP-' || LPAD(FLOOR(SEQ4() * 50.0 / 100)::STRING, 4, '0'),
    CASE MOD(SEQ4(), 20)
        WHEN 0 THEN 'Fresh Produce Supply Agreement - APJ Region'
        WHEN 1 THEN 'Beverage Distribution Master Agreement'
        WHEN 2 THEN 'Frozen Goods Cold Chain SLA'
        WHEN 3 THEN 'Dry Goods Bulk Purchase Contract'
        WHEN 4 THEN 'Dairy Products Quality & Freshness Guarantee'
        WHEN 5 THEN 'Packaging Materials Sustainability Agreement'
        WHEN 6 THEN 'Spice & Condiment Origin Certification Contract'
        WHEN 7 THEN 'Seafood Traceability & Sustainability Agreement'
        WHEN 8 THEN 'Emergency Stock Replenishment Agreement'
        WHEN 9 THEN 'Seasonal Demand Flexibility Contract'
        WHEN 10 THEN 'Cross-Border Logistics Partnership Agreement'
        WHEN 11 THEN 'Quality Inspection and Returns Policy'
        WHEN 12 THEN 'Volume Discount Tier Agreement'
        WHEN 13 THEN 'Exclusive Distribution Rights - ASEAN'
        WHEN 14 THEN 'Cold Chain Temperature Compliance SLA'
        WHEN 15 THEN 'Organic Certification Compliance Contract'
        WHEN 16 THEN 'Late Delivery Penalty and Compensation Terms'
        WHEN 17 THEN 'Force Majeure and Supply Disruption Protocol'
        WHEN 18 THEN 'Annual Price Review and Adjustment Framework'
        WHEN 19 THEN 'Ethical Sourcing and Labor Standards Agreement'
    END,
    CASE MOD(SEQ4(), 20)
        WHEN 0 THEN 'This agreement governs the supply of fresh produce across the Asia-Pacific region. Supplier commits to daily delivery schedules with a maximum 4-hour cold chain break tolerance. Penalties for spoilage exceeding 2% of shipment value: 150% credit of affected goods. Force majeure excludes typhoon seasons (Jun-Nov) with 48-hour advance notification required. Minimum order quantities: 500 units per SKU per delivery. Quality inspection at receiving dock with 30-minute acceptance window.'
        WHEN 1 THEN 'Master agreement for beverage distribution covering carbonated, non-carbonated, and alcoholic beverages. Temperature control mandatory: 2-8C for dairy-based, 15-25C for shelf-stable. Delivery windows: Mon-Fri 0600-1400 local time. Pallet standards: CHEP or LOSCAM only. Recall procedure: 24-hour containment with full batch traceability. Volume commitments reviewed quarterly with 5% variance tolerance.'
        WHEN 2 THEN 'Cold chain service level agreement for frozen goods transport and storage. Temperature must be maintained at -18C or below throughout transit. GPS and temperature monitoring data must be provided within 2 hours of delivery. Any temperature excursion above -15C for more than 30 minutes triggers automatic rejection and full credit. Insurance coverage minimum: USD 500,000 per shipment.'
        WHEN 3 THEN 'Bulk purchase contract for dry goods including rice, flour, sugar, and pulses. Payment terms: Net 60 from delivery confirmation. Price adjustments: linked to CBOT commodity indices, reviewed monthly, capped at +/- 8% per quarter. Minimum annual commitment: 10,000 metric tonnes. Warehouse storage standards: humidity below 65%, pest control certification required quarterly.'
        WHEN 4 THEN 'Quality and freshness guarantee for all dairy products. Shelf life at delivery must exceed 70% of total shelf life. Microbiological testing results must accompany each shipment. Supplier bears full cost of any product recall due to contamination. Temperature data loggers required on every pallet. Delivery rejection rate above 3% triggers automatic supply review.'
        WHEN 5 THEN 'Agreement covering supply of packaging materials with sustainability commitments. All packaging must be FSC-certified or made from minimum 80% recycled content by 2026. Single-use plastic elimination timeline: 100% by December 2026. Carbon footprint reporting required quarterly. Price premium for sustainable materials capped at 12% above conventional alternatives.'
        WHEN 6 THEN 'Contract for supply of spices and condiments with origin certification requirements. All products must have verifiable chain of custody documentation. Heavy metal testing (lead, cadmium, arsenic) required per batch. Organic certification must be maintained through USDA, EU Organic, or JAS standards. Irradiation treatment must be declared. Minimum 18-month shelf life at delivery.'
        WHEN 7 THEN 'Seafood traceability and sustainability agreement aligned with MSC and ASC certification standards. Catch documentation scheme compliance mandatory. IUU fishing declaration required per shipment. Mercury and histamine testing for all tuna and mackerel products. Supplier must participate in annual sustainability audit. Endangered species list compliance with automatic contract termination for violations.'
        WHEN 8 THEN 'Emergency replenishment protocol for critical stock situations. Supplier guarantees 48-hour emergency delivery for top 50 SKUs. Premium pricing: maximum 25% above standard contract price for emergency orders. Minimum safety stock maintained at supplier warehouse: 2 weeks of average demand. Quarterly emergency drill testing required.'
        WHEN 9 THEN 'Seasonal demand flexibility contract allowing +/- 30% volume adjustment during peak periods (Chinese New Year, Diwali, Christmas). Lead time reduction to 5 days during peak season with pre-positioned inventory arrangement. Supplier commits to 95% fill rate during seasonal peaks. Additional storage cost sharing: 60% buyer, 40% supplier for pre-positioned stock.'
        WHEN 10 THEN 'Cross-border logistics partnership covering customs clearance, documentation, and multi-modal transport. Incoterms: DDP for ASEAN, CIF for all others. Customs broker must be AEO-certified. Transit time SLAs: ASEAN 3-5 days, North Asia 5-7 days, ANZ 7-10 days, South Asia 7-14 days. Demurrage and detention costs: supplier responsibility for first 5 free days, shared thereafter.'
        WHEN 11 THEN 'Quality inspection and returns policy. Incoming inspection sampling rate: AQL 2.5 for critical defects, AQL 4.0 for major defects. Returns processing: credit note within 7 business days of confirmed rejection. Supplier corrective action plan required within 14 days of quality incident. Three quality failures in 12 months triggers supplier performance review and potential contract termination.'
        WHEN 12 THEN 'Volume discount tier agreement with progressive pricing. Tier 1 (0-1000 units): standard price. Tier 2 (1001-5000): 5% discount. Tier 3 (5001-10000): 10% discount. Tier 4 (10000+): 15% discount. Retrospective rebate: calculated quarterly on total volume. Payment of rebate within 30 days of quarter end. Volume commitments are non-binding forecasts.'
        WHEN 13 THEN 'Exclusive distribution rights for the ASEAN region covering Singapore, Malaysia, Thailand, Indonesia, Philippines, and Vietnam. Exclusivity period: 3 years from execution. Performance benchmarks: minimum 80% of agreed annual volume. Territory expansion rights if performance exceeds 120% of target. Non-compete clause: 12 months post-termination within ASEAN markets.'
        WHEN 14 THEN 'Cold chain temperature compliance SLA with real-time monitoring requirements. IoT sensor data must be transmitted every 5 minutes during transit. Dashboard access must be provided to buyer logistics team. Temperature excursion protocol: immediate notification within 15 minutes. Product disposition decision within 4 hours of excursion notification. Annual compliance audit with third-party certification.'
        WHEN 15 THEN 'Organic certification compliance contract requiring maintenance of organic status throughout supply chain. Annual recertification documentation due by January 31. Segregation protocols must prevent cross-contamination with conventional products. Traceability from farm to warehouse within 24-hour query response time. Premium pricing maintained only while organic certification is active.'
        WHEN 16 THEN 'Late delivery penalty framework. Grace period: 24 hours for domestic, 48 hours for international. Penalty structure: 1% of PO value per day late, capped at 15%. Chronic lateness (>3 late deliveries in 30 days): automatic 5% price reduction for next quarter. Dispute resolution: independent logistics auditor appointed within 5 business days.'
        WHEN 17 THEN 'Force majeure and supply disruption protocol. Qualifying events: natural disasters, pandemics, government actions, war, port closures. Notification requirement: within 24 hours of event occurrence. Mitigation plan required within 72 hours. Alternative sourcing rights activated after 7 days of disruption. Contract obligations suspended for duration of qualifying event plus 30-day recovery period.'
        WHEN 18 THEN 'Annual price review and adjustment framework. Review dates: April 1 and October 1. Input factors: raw material indices, energy costs, labor costs, currency exchange rates. Maximum annual increase: CPI + 3%. Decrease pass-through: mandatory within 30 days when input costs decline >5%. Independent cost auditor engaged if parties cannot agree within 14 days.'
        WHEN 19 THEN 'Ethical sourcing and labor standards agreement aligned with ILO conventions. No child labor, forced labor, or excessive working hours. Fair wage standards: above local minimum wage by at least 10%. Annual third-party social audit required. Corrective action timeline: 90 days for critical findings, 180 days for major findings. Buyer reserves right to unannounced facility inspections.'
    END,
    DATEADD('month', -FLOOR(RANDOM() / POW(2, 63) * 24)::INT, CURRENT_DATE()),
    DATEADD('month', FLOOR(RANDOM() / POW(2, 63) * 36 + 6)::INT, CURRENT_DATE()),
    ROUND(50000 + RANDOM() / POW(2, 63) * 950000, 2),
    CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 100));
