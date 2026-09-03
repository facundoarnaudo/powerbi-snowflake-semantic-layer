# Enterprise Analytics Architecture: Power BI & Snowflake Integration

## 📌 Project Overview & Objective
The objective of this repository is to demonstrate an enterprise-grade Analytics Data Architecture. **Please note: The Power BI dashboards included in this repository deliberately feature a basic UI/UX design.** The primary focus of this Proof of Concept (PoC) is the underlying engine: **data architecture, semantic layer development, performance optimization, and data security** required for large-scale enterprise environments (such as CPG or Retail).

This project successfully integrates Snowflake as a Cloud Data Warehouse with Power BI, adhering to industry best practices for data modeling, ETL pushdown, and resource management[cite: 1].

---

## 🗄️ Repository Structure & Project Files

This repository is structured to separate data engineering scripts, core semantic models, and presentation layers. Click on the files below to review the code and models.

* 📁 **`sql_scripts`** (Data Engineering & ETL)
  * [📄 `01_snowflake_data_modeling.sql`](sql_scripts/01_snowflake_data_modeling.sql) - DDL scripts for Star Schema creation.
  * [📄 `02_snowflake_view_agg_ventas.sql`](sql_scripts/02_snowflake_view_agg_ventas.sql) - SQL View for server-side aggregations.
  * [📄 `03_powerbi_query_folding_proof.sql`](sql_scripts/03_powerbi_query_folding_proof.sql) - Exported SQL query proving successful Query Folding from Power BI to Snowflake.
* 📁 **`powerbi_semantic_layer`** (Core Data Models)
  * [📄 `04_PowerBI_Import_Mode.pbix`](powerbi_semantic_layer/04_PowerBI_Import_Mode.pbix) - Initial performance test using 100% In-Memory storage.
  * [📄 `05_PowerBI_DirectQuery.pbix`](powerbi_semantic_layer/05_PowerBI_DirectQuery.pbix) - **The Final Core Semantic Layer** featuring a Composite Model, DAX business logic, and Dynamic RLS.
* 📁 **`powerbi_thin_reports`** (Presentation Layer)
  * [📄 `06_Sales_Analytics_Thin_Reports.pbix`](powerbi_thin_reports/06_Sales_Analytics_Thin_Reports.pbix) - Live-connected report featuring Decomposition Trees.
  * [📄 `07_Discount_Analysis_Thin_Reports.pbix`](powerbi_thin_reports/07_Discount_Analysis_Thin_Reports.pbix) - Live-connected report featuring Waterfall impact analysis.
* 📁 **`images`** - Architectural and configuration documentation.

---

## 🏗️ Architecture Breakdown & Strategic Decisions

### 1. Snowflake Integration & Compute Management
**Decision:** Push ETL transformations down to the Snowflake compute layer rather than relying on Power Query[cite: 1].
**Why:** Power Query relies on the local machine's or Power BI Service's RAM. By executing transformations in Snowflake, we leverage its massively parallel processing (MPP) architecture, ensuring scalability for billions of rows.
* Designed and deployed a robust Star Schema directly in Snowflake using the native `TPCH_SF1` sample dataset, simulating a CPG environment with a `FACT_SALES` table containing over **6 million rows**[cite: 1].
* **Cost Optimization:** Configured a specific Virtual Warehouse (`POWERBI_WH`) with an `AUTO_SUSPEND = 60` policy. If the dashboard is inactive for one minute, the compute cluster suspends itself to prevent unnecessary billing.

![Snowflake Warehouse Configuration](images/01_snowflake_warehouse.png)
*Figure 1: Snowflake Virtual Warehouse configured for optimized Power BI querying.*

### 2. Semantic Layer & Robust Data Modeling
**Decision:** Create a centralized Semantic Layer instead of embedding data models inside individual reports[cite: 1].
**Why:** This ensures a "single source of truth". If a business rule changes, it is updated in one place and instantly reflects across all downstream reports.
* Built a best-practice **Star Schema**.
* Resolved Many-to-Many (`*:*`) relationship ambiguities by properly utilizing Primary Keys (`DATEKEY`, `PRODUCTKEY`).
* Incorporated business logic into a centralized measure table (`_Measures`) using **DAX** (e.g., calculating `Net Sales` and `Total Discounts`)[cite: 1].

![Data Model](images/03_data_model.png)
*Figure 2: The core Star Schema in Power BI, including the hidden Aggregation and Security tables.*

### 3. Performance Optimization: Composite Models & Aggregations
**Decision:** Transition from the initial Import Mode test (`04_PowerBI_Import_Mode.pbix`) to a Hybrid Composite Model (`05_PowerBI_DirectQuery.pbix`)[cite: 1].
**Why:** Storing 6 million rows in RAM is inefficient and hits dataset size limits. However, querying Snowflake for every single click causes latency. The Composite Model offers the best of both worlds.
* **Import Mode (Aggregations):** High-level queries hit `AGG_VENTAS` (a pre-aggregated table stored in Power BI's RAM) for instant response times.
* **DirectQuery (Detail):** Deep drill-downs route directly to the 6M row `FACT_SALES` table in Snowflake.
* **Dual Mode Dimensions:** Dimension tables (`DIM_PRODUCT`, `DIM_DATE`) were set to Dual storage mode. This crucial configuration allows them to act as In-Memory tables when filtering the Aggregation table, and as DirectQuery tables when filtering the Fact table, preventing model errors.

![Manage Aggregations](images/04_manage_aggregations.png)
*Figure 3: Configuring Aggregations in Power BI to route queries automatically between RAM and Snowflake.*

### 4. Query Folding Proof
**Decision:** Audit the SQL code generated by Power BI.
**Why:** To guarantee that performance optimization techniques are actually working[cite: 1]. By utilizing native Snowflake connectors and writing clean DAX, Power BI successfully achieves **Query Folding**. 
* Clicks on the Power BI dashboard are translated into highly optimized SQL queries (using `LEFT OUTER JOIN` and `GROUP BY`) pushed directly to the Snowflake engine. 
* *See [`03_powerbi_query_folding_proof.sql`](sql_scripts/03_powerbi_query_folding_proof.sql) for the exact SQL generated during a DirectQuery drill-down.*

![Query Folding](images/02_query_folding.png)
*Figure 4: Snowflake Query History showing perfect Query Folding generated by Power BI.*

### 5. Data Security: Dynamic Row-Level Security (RLS)
**Decision:** Implement Dynamic RLS using an authorization table instead of Static Roles[cite: 1].
**Why:** Static roles require manual maintenance for every employee change. Dynamic RLS scales automatically for enterprise deployments.
* A hidden `Security_Users` table was incorporated into the model and mapped to `DIM_CUSTOMER`.
* The relationship was explicitly configured to **"Apply security filter in both directions"** to ensure authorization propagates across the Star Schema.
* Using the DAX function `USERPRINCIPALNAME()`, the Semantic Layer reads the viewer's active session email and dynamically filters the `MARKETSEGMENT` they are authorized to see. 
* **Enterprise Scalability:** This architecture is designed to scale seamlessly by feeding the `Security_Users` table directly from an ERP or HR system (e.g., SAP / SAP HANA) via a daily scheduled refresh[cite: 1].

![Dynamic RLS](images/06_dynamic_rls.png)
*Figure 5: Testing Dynamic RLS in Power BI Desktop to ensure accurate data masking based on the user's active session.*

### 6. Hub-and-Spoke Deployment (Thin Reports)
**Decision:** Deploy visualization layers as independent "Thin Reports".
**Why:** Decoupling the frontend from the backend allows multiple analysts to build dashboards simultaneously without duplicating datasets or overriding each other's data modeling work.
* **Promoted Shared Dataset:** The centralized Semantic Layer (`05_PowerBI_DirectQuery.pbix`) was published to Power BI Service and marked as "Promoted" to establish governance and data trust.
* **Thin Reports:** [`06_Sales_Analytics_Thin_Reports.pbix`](powerbi_thin_reports/06_Sales_Analytics_Thin_Reports.pbix) and [`07_Discount_Analysis_Thin_Reports.pbix`](powerbi_thin_reports/07_Discount_Analysis_Thin_Reports.pbix) contain zero data. They connect live to the cloud dataset, ensuring minimal file sizes (under 20 KB) and single-source truth alignment.

![Lineage View](images/05_lineage_view.png)
*Figure 6: Power BI Service Lineage View demonstrating the Hub-and-Spoke architecture.*
