-- =====================================================================
-- 01 - SNOWFLAKE DATA MODELING
-- Star Schema for a simulated CPG sales environment (source: TPCH_SF1)
-- =====================================================================

-- 1. CREATE THE VIRTUAL WAREHOUSE
-- This cluster will process all Power BI queries
CREATE OR REPLACE WAREHOUSE POWERBI_WH 
WITH WAREHOUSE_SIZE = 'X-SMALL' 
AUTO_SUSPEND = 60 
AUTO_RESUME = TRUE 
INITIALLY_SUSPENDED = TRUE;

-- 2. CREATE DATABASE AND SCHEMA FOR THE SEMANTIC LAYER
CREATE OR REPLACE DATABASE CPG_ANALYTICS;
CREATE OR REPLACE SCHEMA SALES_MODEL;

USE DATABASE CPG_ANALYTICS;
USE SCHEMA SALES_MODEL;
USE WAREHOUSE POWERBI_WH;

-- 3. BUILD DIMENSION TABLES FROM SNOWFLAKE SAMPLE DATA
-- Dim_Customer (150,000 rows joined with Geography)
CREATE OR REPLACE TABLE Dim_Customer AS
SELECT 
    c.c_custkey     AS CustomerKey,
    c.c_name        AS CustomerName,
    c.c_mktsegment  AS MarketSegment,
    n.n_name        AS Country
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER c
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION n 
  ON c.c_nationkey = n.n_nationkey;

-- Dim_Product (200,000 rows)
CREATE OR REPLACE TABLE Dim_Product AS
SELECT 
    p_partkey  AS ProductKey,
    p_name     AS ProductName,
    p_mfgr     AS Manufacturer,
    p_brand    AS Brand,
    p_type     AS ProductType
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PART;

-- Dim_Date (Extracted dynamically from the orders table)
-- NOTE: rebuilt as a contiguous calendar in script 01b.
-- Dim_Date is built separately in 01b_snowflake_dim_date.sql.
-- It must be created AFTER Fact_Sales, since the calendar range is
-- derived from the fact table's own date bounds.

-- 4. BUILD FACT TABLE
-- Fact_Sales (6,000,000+ rows combining Orders and Line Items)
--
-- GROSS-TO-NET MODELING NOTE
-- In the TPCH source, L_DISCOUNT is a RATE (a decimal between 0 and 0.10),
-- not a monetary amount. Loading it directly as an amount would make any
-- discount aggregation meaningless: summing rates does not produce money.
-- The rate is therefore converted into an amount at load time, and the raw
-- rate is retained separately for auditability.
--
--   Gross Sales    = l_extendedprice
--   Discount Amt   = l_extendedprice * l_discount
--   Net Sales      = l_extendedprice * (1 - l_discount)
--
-- PRECISION NOTE
-- These amounts are stored at full arithmetic precision and are NOT rounded
-- at load time. Rounding each derived amount independently breaks the
-- additive identity Gross = Discount + Net on ties, and the error compounds
-- across millions of rows. Rounding belongs in the presentation layer.
--
CREATE OR REPLACE TABLE Fact_Sales AS
SELECT 
    l.l_orderkey   AS OrderKey,
    l.l_partkey    AS ProductKey,
    o.o_custkey    AS CustomerKey,
    o.o_orderdate  AS DateKey,
    l.l_quantity   AS Quantity,

    -- Gross revenue, before any deduction
    l.l_extendedprice AS SalesAmount,

    -- Raw discount rate, kept for auditability. NEVER aggregate this
    -- column directly: an unweighted average of rates is misleading.
    l.l_discount AS DiscountRate,

    -- Discount expressed in currency, additive and safe to aggregate
    l.l_extendedprice * l.l_discount AS DiscountAmount,

    -- Materialized net revenue, used as an independent reconciliation
    -- check against the measure cascade defined in the semantic layer
    l.l_extendedprice * (1 - l.l_discount) AS NetSalesAmount

FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM l
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS o 
  ON l.l_orderkey = o.o_orderkey;

-- 5. VALIDATION - the cascade must reconcile to exactly zero
SELECT
    COUNT(*)                                AS RowCount,
    SUM(SalesAmount)                        AS GrossSales,
    SUM(DiscountAmount)                     AS Discounts,
    SUM(NetSalesAmount)                     AS NetSales_Materialized,
    SUM(SalesAmount) - SUM(DiscountAmount)  AS NetSales_Cascade,
    SUM(SalesAmount) - SUM(DiscountAmount) - SUM(NetSalesAmount) AS Reconciliation_Delta
FROM Fact_Sales;