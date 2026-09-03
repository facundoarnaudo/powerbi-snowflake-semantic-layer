-- =====================================================================
-- 02 - AGGREGATION VIEW
-- Pre-aggregated at the grain (DateKey, ProductKey) to serve high-level
-- queries from Power BI's in-memory cache instead of hitting the 6M-row
-- fact table in Snowflake on every interaction.
--
-- Note: the discount RATE is deliberately excluded. Rates are not
-- additive, so they cannot be pre-aggregated. The weighted discount
-- percentage is derived in the semantic layer as Discounts / Gross Sales.
-- =====================================================================

CREATE OR REPLACE VIEW CPG_ANALYTICS.SALES_MODEL.AGG_VENTAS AS
SELECT 
    DATEKEY,
    PRODUCTKEY,
    SUM(SALESAMOUNT)    AS Suma_Ventas,
    SUM(DISCOUNTAMOUNT) AS Suma_Descuentos,
    SUM(QUANTITY)       AS Suma_Cantidad
FROM CPG_ANALYTICS.SALES_MODEL.FACT_SALES
GROUP BY DATEKEY, PRODUCTKEY;