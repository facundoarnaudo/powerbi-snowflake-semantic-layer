-- =====================================================================
-- 01b - DATE DIMENSION
-- Contiguous calendar generated across the full range of the fact table.
--
-- WHY THIS EXISTS
-- The original Dim_Date was built with SELECT DISTINCT over the order
-- dates, which yields only the days on which orders occurred. A date
-- dimension with gaps breaks DAX time intelligence in the most dangerous
-- way: it does not raise an error, it silently compares non-equivalent
-- periods. A date dimension must be contiguous, must cover complete
-- years, and must be marked as the model's date table.
--
-- FISCAL CALENDAR
-- CPG companies rarely report on the calendar year. A fiscal calendar
-- offset is included so the model can report on either basis. The offset
-- here assumes a fiscal year starting in July; adjust FISCAL_START_MONTH
-- to match the organization's actual convention.
-- =====================================================================

USE DATABASE CPG_ANALYTICS;
USE SCHEMA SALES_MODEL;
USE WAREHOUSE POWERBI_WH;

CREATE OR REPLACE TABLE Dim_Date AS
WITH bounds AS (
    SELECT
        DATE_TRUNC('YEAR', MIN(DateKey)) AS start_date,
        LAST_DAY(MAX(DateKey), 'YEAR')   AS end_date
    FROM Fact_Sales
),
calendar AS (
    SELECT
        DATEADD(DAY, SEQ4(), (SELECT start_date FROM bounds)) AS d
    FROM TABLE (
        GENERATOR (
            ROWCOUNT => 40000   -- upper bound, filtered below
        )
    )
)
SELECT
    d                                   AS DateKey,
    YEAR(d)                             AS Year,
    QUARTER(d)                          AS Quarter,
    'Q' || QUARTER(d)                   AS QuarterName,
    MONTH(d)                            AS MonthNumber,
    MONTHNAME(d)                        AS MonthName,
    TO_CHAR(d, 'YYYY-MM')               AS YearMonth,
    DAY(d)                              AS DayOfMonth,
    DAYOFWEEK(d)                        AS DayOfWeekNumber,
    DAYNAME(d)                          AS DayName,
    WEEKOFYEAR(d)                       AS WeekOfYear,
    CASE WHEN DAYOFWEEK(d) IN (0, 6) THEN TRUE ELSE FALSE END AS IsWeekend,

    -- Fiscal calendar (fiscal year starts in July)
    CASE WHEN MONTH(d) >= 7 THEN YEAR(d) + 1 ELSE YEAR(d) END AS FiscalYear,
    CASE WHEN MONTH(d) >= 7 THEN MONTH(d) - 6 ELSE MONTH(d) + 6 END AS FiscalMonthNumber,
    CASE
        WHEN MONTH(d) BETWEEN 7  AND 9  THEN 1
        WHEN MONTH(d) BETWEEN 10 AND 12 THEN 2
        WHEN MONTH(d) BETWEEN 1  AND 3  THEN 3
        ELSE 4
    END AS FiscalQuarter

FROM calendar
WHERE d <= (SELECT end_date FROM bounds)
ORDER BY d;

-- VALIDATION - the calendar must be contiguous and complete
SELECT
    COUNT(*)                                              AS TotalDays,
    MIN(DateKey)                                          AS FirstDate,
    MAX(DateKey)                                          AS LastDate,
    DATEDIFF(DAY, MIN(DateKey), MAX(DateKey)) + 1         AS ExpectedDays,
    COUNT(*) - (DATEDIFF(DAY, MIN(DateKey), MAX(DateKey)) + 1) AS Gap_Check,
    COUNT(DISTINCT Year)                                  AS YearsCovered
FROM Dim_Date;

-- REFERENTIAL INTEGRITY - every fact date must exist in the dimension
SELECT COUNT(*) AS Orphan_Fact_Dates
FROM Fact_Sales f
LEFT JOIN Dim_Date d ON f.DateKey = d.DateKey
WHERE d.DateKey IS NULL;