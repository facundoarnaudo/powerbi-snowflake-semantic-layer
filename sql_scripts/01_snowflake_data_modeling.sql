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
    c.c_custkey AS CustomerKey,
    c.c_name AS CustomerName,
    c.c_mktsegment AS MarketSegment,
    n.n_name AS Country
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER c
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION n 
  ON c.c_nationkey = n.n_nationkey;

-- Dim_Product (200,000 rows)
CREATE OR REPLACE TABLE Dim_Product AS
SELECT 
    p_partkey AS ProductKey,
    p_name AS ProductName,
    p_mfgr AS Manufacturer,
    p_brand AS Brand,
    p_type AS ProductType
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PART;

-- Dim_Date (Extracted dynamically from the orders table)
CREATE OR REPLACE TABLE Dim_Date AS
SELECT DISTINCT 
    o_orderdate AS DateKey,
    YEAR(o_orderdate) AS Year,
    MONTH(o_orderdate) AS Month,
    MONTHNAME(o_orderdate) AS MonthName,
    QUARTER(o_orderdate) AS Quarter
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;

-- 4. BUILD FACT TABLE
-- Fact_Sales (6,000,000+ rows combining Orders and Line Items)
CREATE OR REPLACE TABLE Fact_Sales AS
SELECT 
    l.l_orderkey AS OrderKey,
    l.l_partkey AS ProductKey,
    o.o_custkey AS CustomerKey,
    o.o_orderdate AS DateKey,
    l.l_quantity AS Quantity,
    l.l_extendedprice AS SalesAmount,
    l.l_discount AS DiscountAmount
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM l
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS o 
  ON l.l_orderkey = o.o_orderkey;