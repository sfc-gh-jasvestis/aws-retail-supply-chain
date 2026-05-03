import streamlit as st
import pandas as pd
import json
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.set_page_config(page_title="Supply Chain Intelligence", layout="wide", page_icon="📦")

st.markdown("""
<style>
div[data-testid="stMetric"] {border: 1px solid #e0e0e0; border-radius: 8px; padding: 12px; background: linear-gradient(135deg, #f8f9fa 0%, #ffffff 100%);}
</style>
""", unsafe_allow_html=True)

st.title("Supply Chain Intelligence Hub")
st.caption("Retail/CPG Demo — Snowflake AI Data Cloud + AWS S3 + Glue/Iceberg")

with st.sidebar:
    st.markdown("### Architecture")
    st.code("""
┌──────────────────────────┐
│     Amazon S3 Bucket     │
│  (Partner PO / Demand)   │
└─────────┬────────────────┘
          │ External Stage
          ▼
┌──────────────────────────┐
│      Snowflake           │
│  ┌────────────────────┐  │
│  │ RAW Schema         │  │
│  │ Suppliers, Products│  │
│  │ POs, Inventory,    │  │
│  │ Demand, Contracts  │  │
│  └────────┬───────────┘  │
│           ▼              │
│  ┌────────────────────┐  │
│  │ CURATED (Dynamic)  │  │
│  │ • Inventory Health │  │
│  │ • Supplier Perf.   │  │
│  │ • Demand Trends    │  │
│  └────────┬───────────┘  │
│           ▼              │
│  ┌────────────────────┐  │
│  │ AI + ML + SEARCH   │  │
│  │ • Cortex Search    │  │
│  │ • Semantic View    │  │
│  │ • FORECAST Model   │  │
│  │ • ANOMALY Model    │  │
│  └────────┬───────────┘  │
│           ▼              │
│  ┌────────────────────┐  │
│  │ LAKE (Iceberg)     │  │
│  │ Forecast → S3/Glue │  │
│  └────────────────────┘  │
└───────────┬──────────────┘
            │ Iceberg Export
            ▼
┌──────────────────────────┐
│  AWS Glue Data Catalog   │
│  Athena / QuickSight + Q │
└──────────────────────────┘
""", language=None)
    st.divider()
    region_filter = st.multiselect("Filter by Region", ["ASEAN", "ANZ", "North Asia", "South Asia"], default=["ASEAN", "ANZ", "North Asia", "South Asia"])

region_clause = "','".join(region_filter) if region_filter else "ASEAN','ANZ','North Asia','South Asia"

tab1, tab2, tab3, tab4, tab5 = st.tabs([
    "Inventory Health",
    "Supplier Scorecard",
    "Demand Forecast",
    "Contract Search",
    "Ask Supply Chain"
])

with tab1:
    st.header("Inventory Health")

    kpi = session.sql(f"""
        SELECT
            COUNT(*) AS TOTAL_ITEMS,
            COUNT_IF(INVENTORY_STATUS = 'STOCKOUT') AS STOCKOUTS,
            COUNT_IF(INVENTORY_STATUS = 'CRITICAL') AS CRITICAL,
            COUNT_IF(INVENTORY_STATUS = 'OVERSTOCK') AS OVERSTOCK,
            ROUND(AVG(DAYS_OF_SUPPLY), 1) AS AVG_DOS,
            ROUND(SUM(INVENTORY_VALUE), 0) AS TOTAL_VALUE
        FROM RETAIL_SUPPLY_CHAIN.CURATED.INVENTORY_HEALTH
        WHERE REGION IN ('{region_clause}')
    """).to_pandas()

    c1, c2, c3, c4, c5, c6 = st.columns(6)
    c1.metric("Total Items", f"{kpi['TOTAL_ITEMS'].iloc[0]:,}")
    c2.metric("Stockouts", f"{kpi['STOCKOUTS'].iloc[0]:,}", delta="Alert", delta_color="inverse")
    c3.metric("Critical", f"{kpi['CRITICAL'].iloc[0]:,}", delta="Warning", delta_color="inverse")
    c4.metric("Overstock", f"{kpi['OVERSTOCK'].iloc[0]:,}")
    c5.metric("Avg Days of Supply", f"{kpi['AVG_DOS'].iloc[0]}")
    c6.metric("Inventory Value", f"${kpi['TOTAL_VALUE'].iloc[0]:,.0f}")

    st.divider()

    col_l, col_r = st.columns(2)
    with col_l:
        st.subheader("Stock Status by Category")
        status_df = session.sql(f"""
            SELECT CATEGORY, INVENTORY_STATUS, COUNT(*) AS CNT
            FROM RETAIL_SUPPLY_CHAIN.CURATED.INVENTORY_HEALTH
            WHERE REGION IN ('{region_clause}')
            GROUP BY CATEGORY, INVENTORY_STATUS
            ORDER BY CATEGORY
        """).to_pandas()
        pivot = status_df.pivot_table(index='CATEGORY', columns='INVENTORY_STATUS', values='CNT', fill_value=0)
        st.bar_chart(pivot)

    with col_r:
        st.subheader("Inventory Value by Warehouse")
        wh_df = session.sql(f"""
            SELECT WAREHOUSE_NAME, ROUND(SUM(INVENTORY_VALUE), 0) AS VALUE
            FROM RETAIL_SUPPLY_CHAIN.CURATED.INVENTORY_HEALTH
            WHERE REGION IN ('{region_clause}')
            GROUP BY WAREHOUSE_NAME ORDER BY VALUE DESC
        """).to_pandas()
        st.bar_chart(wh_df.set_index("WAREHOUSE_NAME")["VALUE"])

    st.divider()
    st.subheader("Stockout & Critical Items")
    alert_df = session.sql(f"""
        SELECT PRODUCT_NAME, CATEGORY, WAREHOUSE_NAME, REGION, QUANTITY_ON_HAND, REORDER_POINT,
               DAYS_OF_SUPPLY, INVENTORY_STATUS, ALERT_SEVERITY, SUPPLIER_NAME
        FROM RETAIL_SUPPLY_CHAIN.CURATED.INVENTORY_HEALTH
        WHERE INVENTORY_STATUS IN ('STOCKOUT', 'CRITICAL')
          AND REGION IN ('{region_clause}')
        ORDER BY CASE INVENTORY_STATUS WHEN 'STOCKOUT' THEN 1 ELSE 2 END, DAYS_OF_SUPPLY ASC
        LIMIT 50
    """).to_pandas()
    if alert_df.empty:
        st.success("No stockouts or critical items.")
    else:
        st.dataframe(alert_df, use_container_width=True)


with tab2:
    st.header("Supplier Scorecard")

    sup_df = session.sql("""
        SELECT SUPPLIER_NAME, COUNTRY, CATEGORY, PERFORMANCE_GRADE,
               ON_TIME_DELIVERY_PCT, AVG_ACTUAL_LEAD_TIME, CONTRACTED_LEAD_TIME,
               TOTAL_POS, DELIVERED, DELAYED, CANCELLED,
               ROUND(TOTAL_SPEND, 0) AS TOTAL_SPEND, RELIABILITY_SCORE
        FROM RETAIL_SUPPLY_CHAIN.CURATED.SUPPLIER_PERFORMANCE
        ORDER BY PERFORMANCE_GRADE ASC, ON_TIME_DELIVERY_PCT DESC
    """).to_pandas()

    grade_counts = sup_df["PERFORMANCE_GRADE"].value_counts()
    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("Total Suppliers", len(sup_df))
    c2.metric("Grade A", grade_counts.get("A", 0))
    c3.metric("Grade B", grade_counts.get("B", 0))
    c4.metric("Grade C", grade_counts.get("C", 0))
    c5.metric("Grade D", grade_counts.get("D", 0))

    st.divider()

    col_l, col_r = st.columns(2)
    with col_l:
        st.subheader("On-Time Delivery % by Supplier")
        otd = sup_df[["SUPPLIER_NAME", "ON_TIME_DELIVERY_PCT"]].dropna().head(20)
        st.bar_chart(otd.set_index("SUPPLIER_NAME")["ON_TIME_DELIVERY_PCT"])

    with col_r:
        st.subheader("Spend by Supplier")
        spend = sup_df[["SUPPLIER_NAME", "TOTAL_SPEND"]].head(15)
        st.bar_chart(spend.set_index("SUPPLIER_NAME")["TOTAL_SPEND"])

    st.divider()
    st.subheader("Full Supplier Table")
    sup_df["TOTAL_SPEND"] = sup_df["TOTAL_SPEND"].apply(lambda x: f"${float(x):,.0f}")
    st.dataframe(sup_df, use_container_width=True)


with tab3:
    st.header("Demand Forecast")
    st.markdown("**Snowflake ML FORECAST** — 14-day demand prediction per product. No Python, no SageMaker, no infrastructure.")
    st.divider()

    forecast_df = session.sql("""
        SELECT SERIES AS PRODUCT_ID, TS AS FORECAST_DATE,
               ROUND(FORECAST, 0) AS FORECAST_UNITS,
               ROUND(LOWER_BOUND, 0) AS LOWER_BOUND,
               ROUND(UPPER_BOUND, 0) AS UPPER_BOUND
        FROM RETAIL_SUPPLY_CHAIN.ML.DEMAND_FORECAST_RESULTS
        ORDER BY SERIES, TS
        LIMIT 500
    """).to_pandas()

    products = forecast_df["PRODUCT_ID"].unique().tolist()[:20]
    selected_product = st.selectbox("Select Product", products)

    prod_forecast = forecast_df[forecast_df["PRODUCT_ID"] == selected_product]
    if not prod_forecast.empty:
        st.line_chart(prod_forecast.set_index("FORECAST_DATE")[["FORECAST_UNITS", "LOWER_BOUND", "UPPER_BOUND"]])

    st.divider()
    st.subheader("Inventory Anomalies")
    anom_df = session.sql("""
        SELECT SERIES AS WAREHOUSE_ID, TS AS ANOMALY_DATE, Y AS ACTUAL_INVENTORY,
               FORECAST, IS_ANOMALY, PERCENTILE, DISTANCE
        FROM RETAIL_SUPPLY_CHAIN.ML.INVENTORY_ANOMALY_RESULTS
        ORDER BY IS_ANOMALY DESC, TS DESC
    """).to_pandas()
    if anom_df.empty:
        st.info("No anomaly data available.")
    else:
        anomalies = anom_df[anom_df["IS_ANOMALY"] == True]
        if not anomalies.empty:
            st.warning(f"**{len(anomalies)} inventory anomalies detected!**")
            st.dataframe(anomalies, use_container_width=True)
        else:
            st.success("No anomalies detected in recent inventory levels.")
        with st.expander("All Anomaly Detection Results"):
            st.dataframe(anom_df, use_container_width=True)

    st.divider()
    st.subheader("Iceberg Export Status")
    ice_count = session.sql("SELECT COUNT(*) AS CNT FROM RETAIL_SUPPLY_CHAIN.LAKE.DEMAND_FORECAST_ICEBERG").to_pandas()
    st.info(f"**{ice_count['CNT'].iloc[0]:,}** forecast rows exported to Iceberg table → AWS Glue catalog. Queryable from Athena, QuickSight, or any Iceberg-compatible engine.")


with tab4:
    st.header("Contract Search")
    st.markdown("Search across **100 supplier contracts** using **Snowflake Cortex Search** — semantic RAG for instant supply chain answers.")
    st.divider()

    samples = [
        "What are the late delivery penalties?",
        "Cold chain temperature requirements for frozen goods",
        "Force majeure and supply disruption clauses",
        "Organic certification compliance requirements",
        "Emergency stock replenishment terms",
        "Sustainability and ethical sourcing commitments",
    ]
    cols = st.columns(3)
    selected = None
    for i, s in enumerate(samples):
        with cols[i % 3]:
            if st.button(s, key=f"search_{i}", use_container_width=True):
                selected = s

    st.divider()
    search_input = st.text_input("Or type your own search:", placeholder="e.g., What is the penalty for late delivery?")
    query = selected or search_input

    if query:
        st.markdown(f"**Search:** {query}")
        with st.spinner("Searching supplier contracts..."):
            try:
                safe_q = query.replace('"', '\\"').replace("'", "''")
                raw = session.sql(f"""
                    SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                        'RETAIL_SUPPLY_CHAIN.SEARCH.SUPPLY_CHAIN_SEARCH_SERVICE',
                        '{{"query": "{safe_q}", "columns": ["CONTRACT_TEXT", "TITLE", "SUPPLIER_NAME", "SUPPLIER_COUNTRY"], "limit": 5}}'
                    ) AS RESULTS
                """).collect()[0][0]

                results = json.loads(raw) if isinstance(raw, str) else raw
                hits = results.get("results", [])

                if not hits:
                    st.warning("No matching contracts found.")
                else:
                    st.markdown(f"**{len(hits)} matching contracts:**")
                    for idx, hit in enumerate(hits):
                        title = hit.get("TITLE", "Unknown")
                        supplier = hit.get("SUPPLIER_NAME", "")
                        country = hit.get("SUPPLIER_COUNTRY", "")
                        content = hit.get("CONTRACT_TEXT", "")

                        with st.expander(f"{idx+1}. {title} — {supplier} ({country})"):
                            st.markdown(content[:600] + ("..." if len(content) > 600 else ""))

                    st.divider()
                    st.markdown("**AI Summary**")
                    with st.spinner("Generating answer with Cortex AI..."):
                        context_parts = [f"[{h.get('TITLE', '')}]\n{h.get('CONTRACT_TEXT', '')}" for h in hits]
                        context = "\n\n".join(context_parts)
                        safe_ctx = context.replace("'", "''").replace("\\", "\\\\")[:4000]
                        safe_query = query.replace("'", "''")
                        summary = session.sql(f"""
                            SELECT SNOWFLAKE.CORTEX.COMPLETE('claude-4-sonnet',
                                'You are a supply chain contract expert. Answer the question based ONLY on the contracts below. Be specific about terms, penalties, and thresholds. Write dollar amounts as plain text.

                                QUESTION: {safe_query}

                                CONTRACTS:
                                {safe_ctx}')
                        """).collect()[0][0]
                        answer = str(summary).strip()
                        if answer.startswith('"') and answer.endswith('"'):
                            answer = answer[1:-1]
                        answer = answer.replace("\\n", "\n").replace('$', '\\$')
                        st.markdown(answer)
            except Exception as e:
                st.error(f"Search error: {e}")


with tab5:
    st.header("Ask Supply Chain")
    st.markdown("Ask questions in **natural language** — powered by **Snowflake Cortex Agent** via Semantic View.")
    st.divider()

    sample_questions = [
        "Which warehouses have the most stockouts?",
        "What is the average on-time delivery by supplier grade?",
        "Which product categories have the highest demand in the last 30 days?",
        "Show me suppliers with performance grade D",
        "What is the total inventory value by region?",
    ]

    st.markdown("**Try one of these:**")
    q_cols = st.columns(3)
    selected_q = None
    for i, q in enumerate(sample_questions):
        with q_cols[i % 3]:
            if st.button(q, key=f"agent_{i}", use_container_width=True):
                selected_q = q

    agent_input = st.text_input("Or ask your own question:", placeholder="e.g., Which suppliers are at risk?", key="agent_input")
    agent_query = selected_q or agent_input

    if agent_query:
        st.markdown(f"**Question:** {agent_query}")
        with st.spinner("Querying Semantic View..."):
            try:
                safe_aq = agent_query.replace("'", "''")
                result = session.sql(f"""
                    SELECT SNOWFLAKE.CORTEX.COMPLETE('claude-4-sonnet',
                        'You are a supply chain analyst. Generate a SQL query to answer the question below.

Use these tables from RETAIL_SUPPLY_CHAIN.CURATED:

INVENTORY_HEALTH columns: PRODUCT_NAME, CATEGORY, WAREHOUSE_NAME, REGION, INVENTORY_STATUS (STOCKOUT/CRITICAL/LOW/HEALTHY/OVERSTOCK), QUANTITY_ON_HAND, REORDER_POINT, DAYS_OF_SUPPLY, INVENTORY_VALUE, SUPPLIER_NAME, SNAPSHOT_DATE

SUPPLIER_PERFORMANCE columns: SUPPLIER_NAME, COUNTRY, CATEGORY, PERFORMANCE_GRADE (A/B/C/D), ON_TIME_DELIVERY_PCT, AVG_ACTUAL_LEAD_TIME, CONTRACTED_LEAD_TIME, TOTAL_POS, DELIVERED, DELAYED, CANCELLED, TOTAL_SPEND, RELIABILITY_SCORE

DEMAND_TRENDS columns: PRODUCT_NAME, CATEGORY, WAREHOUSE_NAME, REGION, SIGNAL_DATE, CHANNEL, UNITS_SOLD, ROLLING_7D_UNITS, ROLLING_30D_UNITS, AVG_DAILY_7D, AVG_DAILY_30D

Return ONLY the SQL, no explanation.

Question: {safe_aq}')
                """).collect()[0][0]
                sql_text = str(result).strip()
                if sql_text.startswith('"'):
                    sql_text = sql_text[1:-1]
                sql_text = sql_text.replace("\\n", "\n")
                if "```sql" in sql_text:
                    sql_text = sql_text.split("```sql")[1].split("```")[0].strip()
                elif "```" in sql_text:
                    sql_text = sql_text.split("```")[1].split("```")[0].strip()

                with st.expander("Generated SQL", expanded=False):
                    st.code(sql_text, language="sql")

                try:
                    answer_df = session.sql(sql_text).to_pandas()
                    st.dataframe(answer_df, use_container_width=True)
                except Exception as sql_err:
                    st.warning(f"Could not execute generated SQL: {sql_err}")
            except Exception as e:
                st.error(f"Agent error: {e}")
