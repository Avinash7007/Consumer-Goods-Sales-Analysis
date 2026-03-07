/*
================================================================================

    Consumer Goods Sales Analysis
    ─────────────────────────────────────────────────────────────────────────────
    Author      : Avinash Dubey
    Role        : Data Analyst
    Database    : Microsoft SQL Server (T-SQL)
    Data Period : January 2022 – December 2025 (4 Years)

    ─────────────────────────────────────────────────────────────────────────────
    DATASET OVERVIEW
    ─────────────────────────────────────────────────────────────────────────────
    Fact_Sales      : 1,00,140 rows  — Orders, Revenue, Discount
    Fact_Shipment   :   59,950 rows  — Delivery tracking
    Fact_Returns    :    9,037 rows  — Return reasons, Refund amounts
    Fact_Payments   :   60,079 rows  — Payment method & status
    Dim_Order       :   40,000 rows  — Order channel, status, priority
    Dim_Customer    :    5,000 rows  — Customer master
    Dim_Product     :      500 rows  — Product, Category, Brand, Supplier
    Dim_Region      :        4 rows  — North, South, East, West
    Dim_Supplier    :       50 rows  — 50 suppliers across 44 countries
    Dim_Date        :    1,461 rows  — Full date dimension 2022–2025

    ─────────────────────────────────────────────────────────────────────────────
    KEY METRICS (FROM DATA)
    ─────────────────────────────────────────────────────────────────────────────
    Total Revenue       : Rs 31.38 Crore (2022–2025)
    Average Order Value : Rs 7,844
    Average Discount    : 15%
    Return Rate         : 15%  (6,000 of 40,000 orders returned)
    Cancellation Rate   : 33.5% (13,381 of 40,000 orders cancelled)
    Failed Payments     : 33.5% of all payment transactions
    Revenue at Risk     : Rs 20.96 Cr (Failed + Refunded payments)
    Active Customers    : 4,998  |  Products : 500  |  Suppliers : 50

    ─────────────────────────────────────────────────────────────────────────────
    BUSINESS PROBLEMS ADDRESSED
    ─────────────────────────────────────────────────────────────────────────────
    SECTION 1 — Data Validation & Quality Checks   (always run first)
    SECTION 2 — Revenue Trend Analysis             (flat revenue root cause)
    SECTION 3 — Order Cancellation Analysis        (33.5% cancellation rate)
    SECTION 4 — Customer Churn & Retention         (no early warning system)
    SECTION 5 — Return Analysis                    (15% return rate)
    SECTION 6 — Payment & Revenue Reconciliation   (Rs 20.96 Cr at risk)
    SECTION 7 — Shipment & Delivery Performance    (delays causing returns?)
    SECTION 8 — Product & Supplier Analytics       (what drives revenue?)
    SECTION 9 — Customer Segmentation              (who actually matters?)

================================================================================
*/

USE db1;


/*
================================================================================
  SECTION 1 — DATA VALIDATION & QUALITY CHECKS
  Always run first. Identify data gaps before starting analysis.
================================================================================
*/

-- 1.1  Row counts across all tables
SELECT 'Fact_Sales'    AS table_name, COUNT(*) AS row_count FROM Fact_Sales    UNION ALL
SELECT 'Fact_Shipment',                COUNT(*)             FROM Fact_Shipment  UNION ALL
SELECT 'Fact_Returns',                 COUNT(*)             FROM Fact_Returns   UNION ALL
SELECT 'Fact_Payments',                COUNT(*)             FROM Fact_Payments  UNION ALL
SELECT 'Dim_Order',                    COUNT(*)             FROM Dim_Order      UNION ALL
SELECT 'Dim_Customer',                 COUNT(*)             FROM Dim_Customer   UNION ALL
SELECT 'Dim_Product',                  COUNT(*)             FROM Dim_Product    UNION ALL
SELECT 'Dim_Supplier',                 COUNT(*)             FROM Dim_Supplier   UNION ALL
SELECT 'Dim_Region',                   COUNT(*)             FROM Dim_Region;

-- 1.2  NULL check on critical columns in Fact_Sales
SELECT
    SUM(CASE WHEN Order_ID     IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN Customer_ID  IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN Product_ID   IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN Order_Date   IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN Sales_Amount IS NULL THEN 1 ELSE 0 END) AS null_sales_amount
FROM Fact_Sales;

-- 1.3  Orphan orders — sales records with no matching customer
SELECT COUNT(DISTINCT s.Order_ID) AS orphan_orders
FROM Fact_Sales AS s
WHERE NOT EXISTS (
    SELECT 1 FROM Dim_Customer AS c
    WHERE c.Customer_ID = s.Customer_ID
);

-- 1.4  Orders with no shipment record (fulfillment gap)
SELECT COUNT(DISTINCT s.Order_ID) AS orders_without_shipment
FROM Fact_Sales AS s
WHERE NOT EXISTS (
    SELECT 1 FROM Fact_Shipment AS sh
    WHERE sh.Order_ID = s.Order_ID
);

-- 1.5  Orders with no payment record (reconciliation gap)
SELECT COUNT(DISTINCT s.Order_ID) AS orders_without_payment
FROM Fact_Sales AS s
WHERE NOT EXISTS (
    SELECT 1 FROM Fact_Payments AS p
    WHERE p.Order_ID = s.Order_ID
);

-- 1.6  Sales_Amount sanity — negative or zero values flag
SELECT COUNT(*) AS invalid_sales_records
FROM Fact_Sales
WHERE Sales_Amount <= 0;

-- 1.7  Date range validation
SELECT
    MIN(Order_Date) AS first_order_date,
    MAX(Order_Date) AS last_order_date,
    DATEDIFF(DAY, MIN(Order_Date), MAX(Order_Date)) AS total_days_covered
FROM Fact_Sales;


/*
================================================================================
  SECTION 2 — REVENUE TREND ANALYSIS
  Business Question: Revenue flat for 4 consecutive years — why?
  Finding: Rs 7.85 Cr (2022) → Rs 7.77 Cr (2025). Category mix shift,
           not demand decline. High cancellation rate suppressing net revenue.
================================================================================
*/

-- 2.1  Total revenue summary (baseline KPIs)
SELECT
    ROUND(SUM(Sales_Amount), 2)                                             AS total_revenue,
    COUNT(DISTINCT Order_ID)                                                AS total_orders,
    COUNT(DISTINCT Customer_ID)                                             AS unique_customers,
    ROUND(SUM(Sales_Amount) / NULLIF(COUNT(DISTINCT Order_ID), 0), 2)      AS avg_order_value,
    ROUND(AVG(Discount) * 100, 1)                                           AS avg_discount_pct
FROM Fact_Sales;

-- 2.2  Year-over-Year (YoY) revenue growth
WITH yr_tab AS (
    SELECT
        YEAR(Order_Date)              AS yr,
        ROUND(SUM(Sales_Amount), 2)   AS yearly_revenue
    FROM Fact_Sales
    GROUP BY YEAR(Order_Date)
),
yoy_tab AS (
    SELECT yr, yearly_revenue,
           LAG(yearly_revenue) OVER (ORDER BY yr) AS prev_yr_revenue
    FROM yr_tab
)
SELECT
    yr,
    yearly_revenue,
    prev_yr_revenue,
    ROUND((yearly_revenue - prev_yr_revenue) * 100.0
          / NULLIF(prev_yr_revenue, 0), 2)          AS yoy_pct
FROM yoy_tab
ORDER BY yr;

-- 2.3  Quarter-over-Quarter (QoQ) revenue growth
WITH qoq_tab AS (
    SELECT
        YEAR(Order_Date)                                AS yr,
        DATEPART(QUARTER, Order_Date)                   AS qtr,
        CONCAT(YEAR(Order_Date), '-Q',
               DATEPART(QUARTER, Order_Date))           AS yr_qtr,
        ROUND(SUM(Sales_Amount), 2)                     AS qtr_revenue
    FROM Fact_Sales
    GROUP BY
        YEAR(Order_Date),
        DATEPART(QUARTER, Order_Date),
        CONCAT(YEAR(Order_Date), '-Q', DATEPART(QUARTER, Order_Date))
),
prev_tab AS (
    SELECT *,
           LAG(qtr_revenue) OVER (ORDER BY yr, qtr) AS prev_qtr_revenue
    FROM qoq_tab
)
SELECT
    yr_qtr, qtr_revenue, prev_qtr_revenue,
    ROUND((qtr_revenue - prev_qtr_revenue) * 100.0
          / NULLIF(prev_qtr_revenue, 0), 2)             AS qoq_pct
FROM prev_tab
ORDER BY yr, qtr;

-- 2.4  Month-over-Month (MoM) revenue growth
WITH mom_tab AS (
    SELECT
        DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1) AS yr_month,
        ROUND(SUM(Sales_Amount), 2)                           AS monthly_revenue
    FROM Fact_Sales
    GROUP BY DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1)
),
prev_tab AS (
    SELECT *,
           LAG(monthly_revenue) OVER (ORDER BY yr_month) AS prev_month_revenue
    FROM mom_tab
)
SELECT
    yr_month, monthly_revenue, prev_month_revenue,
    ROUND((monthly_revenue - prev_month_revenue) * 100.0
          / NULLIF(prev_month_revenue, 0), 2)                 AS mom_pct
FROM prev_tab
ORDER BY yr_month;

-- 2.5  Revenue by category with YoY — which category losing share?
WITH cat_yr_tab AS (
    SELECT
        p.Category,
        YEAR(s.Order_Date)            AS yr,
        ROUND(SUM(s.Sales_Amount), 2) AS revenue
    FROM Fact_Sales AS s
    INNER JOIN Dim_Product AS p ON s.Product_ID = p.Product_ID
    GROUP BY p.Category, YEAR(s.Order_Date)
)
SELECT
    Category, yr, revenue,
    LAG(revenue) OVER (PARTITION BY Category ORDER BY yr) AS prev_yr_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (PARTITION BY Category ORDER BY yr))
        * 100.0
        / NULLIF(LAG(revenue) OVER (PARTITION BY Category ORDER BY yr), 0),
    2) AS yoy_pct
FROM cat_yr_tab
ORDER BY Category, yr;

-- 2.6  Revenue and order count by region per year
SELECT
    r.Region_Name,
    YEAR(s.Order_Date)            AS yr,
    ROUND(SUM(s.Sales_Amount), 2) AS revenue,
    COUNT(DISTINCT s.Order_ID)    AS orders
FROM Fact_Sales    AS s
INNER JOIN Dim_Customer AS c ON s.Customer_ID = c.Customer_ID
INNER JOIN Dim_Region   AS r ON c.Region_ID   = r.Region_ID
GROUP BY r.Region_Name, YEAR(s.Order_Date)
ORDER BY r.Region_Name, yr;

-- 2.7  Rolling 30-day revenue — short-term trend & anomaly detection
WITH daily_sales AS (
    SELECT
        Order_Date,
        ROUND(SUM(Sales_Amount), 2) AS daily_revenue
    FROM Fact_Sales
    GROUP BY Order_Date
)
SELECT
    Order_Date,
    daily_revenue,
    ROUND(AVG(daily_revenue) OVER (
        ORDER BY Order_Date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 2) AS rolling_30d_avg,
    SUM(daily_revenue) OVER (
        ORDER BY Order_Date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)     AS rolling_30d_total
FROM daily_sales
ORDER BY Order_Date;

-- 2.8  Cumulative revenue within each year (progress vs target)
WITH daily_sales AS (
    SELECT
        Order_Date,
        YEAR(Order_Date)            AS yr,
        ROUND(SUM(Sales_Amount), 2) AS daily_revenue
    FROM Fact_Sales
    GROUP BY Order_Date, YEAR(Order_Date)
)
SELECT
    Order_Date, yr, daily_revenue,
    SUM(daily_revenue) OVER (
        PARTITION BY yr
        ORDER BY Order_Date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_revenue_ytd
FROM daily_sales
ORDER BY Order_Date;


/*
================================================================================
  SECTION 3 — ORDER CANCELLATION ANALYSIS
  Business Question: 33.5% orders cancelled — which channel, priority, trend?
  Finding: Cancellations evenly spread across all channels and priorities —
           systemic issue, not channel-specific.
================================================================================
*/

-- 3.1  Order status breakdown — overall
SELECT
    Order_Status,
    COUNT(*)                                                   AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)         AS pct
FROM Dim_Order
GROUP BY Order_Status
ORDER BY order_count DESC;

-- 3.2  Cancellation rate by order channel
SELECT
    Order_Channel,
    COUNT(*)                                                                        AS total_orders,
    SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END)                    AS cancelled,
    ROUND(SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0
          / NULLIF(COUNT(*), 0), 2)                                                 AS cancel_rate_pct
FROM Dim_Order
GROUP BY Order_Channel
ORDER BY cancel_rate_pct DESC;

-- 3.3  Cancellation rate by order priority
SELECT
    Order_Priority,
    COUNT(*)                                                                        AS total_orders,
    SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END)                    AS cancelled,
    ROUND(SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0
          / NULLIF(COUNT(*), 0), 2)                                                 AS cancel_rate_pct
FROM Dim_Order
GROUP BY Order_Priority
ORDER BY cancel_rate_pct DESC;

-- 3.4  Monthly cancellation trend — getting better or worse?
SELECT
    DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1)                          AS yr_month,
    COUNT(*)                                                                        AS total_orders,
    SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END)                    AS cancelled,
    ROUND(SUM(CASE WHEN Order_Status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0
          / NULLIF(COUNT(*), 0), 2)                                                 AS cancel_rate_pct
FROM Dim_Order
GROUP BY DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1)
ORDER BY yr_month;

-- 3.5  Revenue associated with cancelled orders
SELECT
    ROUND(SUM(s.Sales_Amount), 2)    AS revenue_in_cancelled_orders,
    COUNT(DISTINCT s.Order_ID)       AS cancelled_order_count
FROM Fact_Sales    AS s
INNER JOIN Dim_Order AS o ON s.Order_ID = o.Order_ID
WHERE o.Order_Status = 'Cancelled';


/*
================================================================================
  SECTION 4 — CUSTOMER CHURN & RETENTION ANALYSIS
  Business Question: No churn visibility — who is about to leave?
  Finding: 2,389 At-Risk customers, 681 already Churned.
           Returning customer revenue declining YoY.
================================================================================
*/

-- 4.1  Customer activity classification — Active / At Risk / Churned
WITH last_order_tab AS (
    SELECT
        c.Customer_ID, c.Customer_Name,
        MAX(s.Order_Date) AS last_order_date
    FROM Dim_Customer AS c
    INNER JOIN Fact_Sales AS s ON c.Customer_ID = s.Customer_ID
    GROUP BY c.Customer_ID, c.Customer_Name
)
SELECT
    Customer_ID, Customer_Name, last_order_date,
    DATEDIFF(DAY, last_order_date, GETDATE()) AS days_inactive,
    CASE
        WHEN DATEDIFF(DAY, last_order_date, GETDATE()) < 90   THEN 'Active'
        WHEN DATEDIFF(DAY, last_order_date, GETDATE()) <= 365  THEN 'At Risk'
        ELSE 'Churned'
    END AS customer_status
FROM last_order_tab
ORDER BY days_inactive DESC;

-- 4.2  Status bucket summary
WITH last_order_tab AS (
    SELECT Customer_ID, MAX(Order_Date) AS last_order_date
    FROM Fact_Sales
    GROUP BY Customer_ID
),
status_tab AS (
    SELECT
        CASE
            WHEN DATEDIFF(DAY, last_order_date, GETDATE()) < 90   THEN 'Active'
            WHEN DATEDIFF(DAY, last_order_date, GETDATE()) <= 365  THEN 'At Risk'
            ELSE 'Churned'
        END AS customer_status
    FROM last_order_tab
)
SELECT
    customer_status,
    COUNT(*)                                                   AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)         AS pct
FROM status_tab
GROUP BY customer_status;

-- 4.3  Churn rate % and retention rate % (12-month window)
WITH last_order_tab AS (
    SELECT Customer_ID, MAX(Order_Date) AS last_order_date
    FROM Fact_Sales
    GROUP BY Customer_ID
),
calc_tab AS (
    SELECT
        COUNT(DISTINCT Customer_ID)                                               AS total_customers,
        SUM(CASE WHEN last_order_date < DATEADD(MONTH, -12, GETDATE()) THEN 1
                 ELSE 0 END)                                                      AS churned
    FROM last_order_tab
)
SELECT
    total_customers,
    churned                                                                        AS churned_customers,
    ROUND(churned * 100.0 / NULLIF(total_customers, 0), 2)                        AS churn_rate_pct,
    total_customers - churned                                                      AS retained_customers,
    ROUND((total_customers - churned) * 100.0 / NULLIF(total_customers, 0), 2)    AS retention_rate_pct
FROM calc_tab;

-- 4.4  Monthly churn trend
WITH last_order_tab AS (
    SELECT Customer_ID, MAX(Order_Date) AS last_order_date
    FROM Fact_Sales
    GROUP BY Customer_ID
)
SELECT
    DATEFROMPARTS(YEAR(last_order_date), MONTH(last_order_date), 1) AS churn_month,
    COUNT(DISTINCT Customer_ID)                                      AS churned_customers
FROM last_order_tab
WHERE last_order_date <= DATEADD(DAY, -90, GETDATE())
GROUP BY DATEFROMPARTS(YEAR(last_order_date), MONTH(last_order_date), 1)
ORDER BY churn_month;

-- 4.5  Repeat purchase rate
WITH order_cnt AS (
    SELECT Customer_ID, COUNT(DISTINCT Order_ID) AS total_orders
    FROM Fact_Sales
    GROUP BY Customer_ID
),
calc AS (
    SELECT
        COUNT(*)                                               AS total_customers,
        SUM(CASE WHEN total_orders >= 2 THEN 1 ELSE 0 END)    AS repeat_customers
    FROM order_cnt
)
SELECT
    total_customers, repeat_customers,
    ROUND(repeat_customers * 100.0 / NULLIF(total_customers, 0), 2) AS repeat_purchase_rate_pct
FROM calc;

-- 4.6  New vs Returning customer revenue by month
WITH first_order_tab AS (
    SELECT Customer_ID, MIN(Order_Date) AS first_order_date
    FROM Fact_Sales
    GROUP BY Customer_ID
),
flagged AS (
    SELECT
        s.Customer_ID,
        DATEFROMPARTS(YEAR(s.Order_Date),        MONTH(s.Order_Date),        1) AS order_month,
        DATEFROMPARTS(YEAR(f.first_order_date),  MONTH(f.first_order_date),  1) AS first_order_month,
        s.Sales_Amount
    FROM Fact_Sales AS s
    INNER JOIN first_order_tab AS f ON s.Customer_ID = f.Customer_ID
)
SELECT
    order_month,
    ROUND(SUM(CASE WHEN order_month = first_order_month THEN Sales_Amount ELSE 0 END), 2) AS new_customer_revenue,
    ROUND(SUM(CASE WHEN order_month > first_order_month  THEN Sales_Amount ELSE 0 END), 2) AS returning_customer_revenue
FROM flagged
GROUP BY order_month
ORDER BY order_month;

-- 4.7  Customer Lifetime Value with segmentation
SELECT
    c.Customer_ID, c.Customer_Name,
    r.Region_Name,
    ROUND(ISNULL(SUM(s.Sales_Amount), 0), 2)          AS clv,
    COUNT(DISTINCT s.Order_ID)                         AS total_orders,
    MIN(s.Order_Date)                                  AS first_order,
    MAX(s.Order_Date)                                  AS last_order,
    DATEDIFF(DAY, MIN(s.Order_Date), MAX(s.Order_Date)) AS customer_age_days,
    CASE
        WHEN ISNULL(SUM(s.Sales_Amount), 0) >= 100000 THEN 'Platinum'
        WHEN ISNULL(SUM(s.Sales_Amount), 0) >= 50000  THEN 'Gold'
        WHEN ISNULL(SUM(s.Sales_Amount), 0) >= 20000  THEN 'Silver'
        ELSE 'Regular'
    END AS segment
FROM Dim_Customer AS c
LEFT JOIN Fact_Sales  AS s ON c.Customer_ID = s.Customer_ID
LEFT JOIN Dim_Region  AS r ON c.Region_ID   = r.Region_ID
GROUP BY c.Customer_ID, c.Customer_Name, r.Region_Name
ORDER BY clv DESC;

-- 4.8  Pareto — top 20% customers driving 80% revenue
WITH clv_tab AS (
    SELECT Customer_ID, ROUND(SUM(Sales_Amount), 2) AS total_revenue
    FROM Fact_Sales
    GROUP BY Customer_ID
),
running_tab AS (
    SELECT *,
           SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS running_revenue,
           SUM(total_revenue) OVER ()                            AS grand_total
    FROM clv_tab
)
SELECT
    Customer_ID, total_revenue,
    ROUND(running_revenue * 100.0 / NULLIF(grand_total, 0), 2) AS cumulative_pct,
    CASE
        WHEN running_revenue * 100.0 / NULLIF(grand_total, 0) <= 80 THEN 'Top 20% — Pareto'
        ELSE 'Remaining 80%'
    END AS pareto_bucket
FROM running_tab
ORDER BY total_revenue DESC;

-- 4.9  Average days between purchases per customer (purchase cycle baseline)
WITH order_gap AS (
    SELECT
        Customer_ID, Order_Date,
        LAG(Order_Date) OVER (PARTITION BY Customer_ID ORDER BY Order_Date) AS prev_order_date
    FROM Fact_Sales
)
SELECT
    Customer_ID,
    ROUND(AVG(DATEDIFF(DAY, prev_order_date, Order_Date) * 1.0), 1) AS avg_days_between_orders
FROM order_gap
WHERE prev_order_date IS NOT NULL
GROUP BY Customer_ID
ORDER BY avg_days_between_orders;


/*
================================================================================
  SECTION 5 — RETURN ANALYSIS
  Business Question: 15% return rate — what is the root cause?
  Finding: Late Delivery = top return reason — logistics problem, not product.
           Return rate evenly spread across all 4 reasons (~25% each).
================================================================================
*/

-- 5.1  Overall return rate
SELECT
    COUNT(DISTINCT s.Order_ID)                                              AS total_orders,
    COUNT(DISTINCT r.Order_ID)                                              AS returned_orders,
    ROUND(COUNT(DISTINCT r.Order_ID) * 100.0
          / NULLIF(COUNT(DISTINCT s.Order_ID), 0), 2)                      AS return_rate_pct,
    ROUND(SUM(r.Refund_Amount), 2)                                          AS total_refund_amount
FROM Fact_Sales  AS s
LEFT JOIN Fact_Returns AS r ON s.Order_ID = r.Order_ID;

-- 5.2  Return reason breakdown
SELECT
    Return_Reason,
    COUNT(*)                                                                AS return_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)                     AS pct,
    ROUND(SUM(Refund_Amount), 2)                                            AS total_refund_amount
FROM Fact_Returns
GROUP BY Return_Reason
ORDER BY return_count DESC;

-- 5.3  Return rate by region
SELECT
    r.Region_Name,
    COUNT(DISTINCT s.Order_ID)                                              AS total_orders,
    COUNT(DISTINCT ret.Order_ID)                                            AS returned_orders,
    ROUND(COUNT(DISTINCT ret.Order_ID) * 100.0
          / NULLIF(COUNT(DISTINCT s.Order_ID), 0), 2)                      AS return_rate_pct
FROM Fact_Sales   AS s
INNER JOIN Dim_Customer AS c   ON s.Customer_ID = c.Customer_ID
INNER JOIN Dim_Region   AS r   ON c.Region_ID   = r.Region_ID
LEFT JOIN  Fact_Returns AS ret ON s.Order_ID    = ret.Order_ID
GROUP BY r.Region_Name
ORDER BY return_rate_pct DESC;

-- 5.4  Return rate by product category
SELECT
    p.Category,
    COUNT(DISTINCT s.Order_ID)                                              AS total_orders,
    COUNT(DISTINCT r.Order_ID)                                              AS returned_orders,
    ROUND(COUNT(DISTINCT r.Order_ID) * 100.0
          / NULLIF(COUNT(DISTINCT s.Order_ID), 0), 2)                      AS return_rate_pct,
    ROUND(SUM(r.Refund_Amount), 2)                                          AS total_refund_amount
FROM Fact_Sales  AS s
INNER JOIN Dim_Product  AS p ON s.Product_ID = p.Product_ID
LEFT JOIN  Fact_Returns AS r ON s.Order_ID   = r.Order_ID
GROUP BY p.Category
ORDER BY return_rate_pct DESC;

-- 5.5  Delivery status linked to return rate (key root cause query)
SELECT
    sh.Delivery_Status,
    COUNT(DISTINCT s.Order_ID)                                              AS total_orders,
    COUNT(DISTINCT r.Order_ID)                                              AS returned_orders,
    ROUND(COUNT(DISTINCT r.Order_ID) * 100.0
          / NULLIF(COUNT(DISTINCT s.Order_ID), 0), 2)                      AS return_rate_pct
FROM Fact_Sales    AS s
INNER JOIN Fact_Shipment AS sh ON s.Order_ID = sh.Order_ID
LEFT JOIN  Fact_Returns  AS r  ON s.Order_ID = r.Order_ID
GROUP BY sh.Delivery_Status
ORDER BY return_rate_pct DESC;

-- 5.6  Top 10 products by return count
SELECT TOP 10
    p.Product_ID, p.Product_Name, p.Category, p.Brand,
    COUNT(r.Return_ID)              AS return_count,
    ROUND(SUM(r.Refund_Amount), 2)  AS total_refund_amount
FROM Fact_Returns AS r
INNER JOIN Dim_Product AS p ON r.Product_ID = p.Product_ID
GROUP BY p.Product_ID, p.Product_Name, p.Category, p.Brand
ORDER BY return_count DESC;

-- 5.7  Loyal customers — purchased but never returned
SELECT DISTINCT c.Customer_ID, c.Customer_Name
FROM Dim_Customer AS c
WHERE EXISTS     (SELECT 1 FROM Fact_Sales    AS s WHERE s.Customer_ID = c.Customer_ID)
  AND NOT EXISTS (SELECT 1 FROM Fact_Returns  AS r WHERE r.Customer_ID = c.Customer_ID)
ORDER BY c.Customer_ID;


/*
================================================================================
  SECTION 6 — PAYMENT & REVENUE RECONCILIATION
  Business Question: Rs 20.96 Cr revenue at risk — which channels failing?
  Finding: All 4 channels have equal failure rate (~33%) — systemic issue.
           Only Rs 10.42 Cr of Rs 31.38 Cr actually realised.
================================================================================
*/

-- 6.1  Payment status breakdown
SELECT
    Payment_Status,
    COUNT(*)                                                                AS transaction_count,
    ROUND(SUM(Payment_Amount), 2)                                           AS total_amount,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)                     AS pct_of_transactions
FROM Fact_Payments
GROUP BY Payment_Status
ORDER BY transaction_count DESC;

-- 6.2  Payment failure rate by method
SELECT
    Payment_Method,
    COUNT(*)                                                                AS total_transactions,
    SUM(CASE WHEN Payment_Status = 'Completed' THEN 1 ELSE 0 END)          AS completed,
    SUM(CASE WHEN Payment_Status = 'Failed'    THEN 1 ELSE 0 END)          AS failed,
    SUM(CASE WHEN Payment_Status = 'Refunded'  THEN 1 ELSE 0 END)          AS refunded,
    ROUND(SUM(CASE WHEN Payment_Status = 'Failed' THEN 1 ELSE 0 END)
          * 100.0 / NULLIF(COUNT(*), 0), 2)                                 AS failure_rate_pct
FROM Fact_Payments
GROUP BY Payment_Method
ORDER BY failure_rate_pct DESC;

-- 6.3  Revenue realisation gap (gross vs net)
SELECT
    ROUND(SUM(Payment_Amount), 2)                                           AS gross_revenue,
    ROUND(SUM(CASE WHEN Payment_Status = 'Completed'
                   THEN Payment_Amount ELSE 0 END), 2)                     AS realised_revenue,
    ROUND(SUM(CASE WHEN Payment_Status = 'Failed'
                   THEN Payment_Amount ELSE 0 END), 2)                     AS failed_revenue,
    ROUND(SUM(CASE WHEN Payment_Status = 'Refunded'
                   THEN Payment_Amount ELSE 0 END), 2)                     AS refunded_revenue,
    ROUND(SUM(CASE WHEN Payment_Status = 'Completed'
                   THEN Payment_Amount ELSE 0 END)
          * 100.0 / NULLIF(SUM(Payment_Amount), 0), 2)                     AS realisation_pct
FROM Fact_Payments;

-- 6.4  Monthly failed payment trend
SELECT
    DATEFROMPARTS(YEAR(Payment_Date), MONTH(Payment_Date), 1)              AS yr_month,
    COUNT(*)                                                                AS total_transactions,
    SUM(CASE WHEN Payment_Status = 'Failed' THEN 1 ELSE 0 END)             AS failed_count,
    ROUND(SUM(CASE WHEN Payment_Status = 'Failed'
                   THEN Payment_Amount ELSE 0 END), 2)                     AS failed_amount
FROM Fact_Payments
GROUP BY DATEFROMPARTS(YEAR(Payment_Date), MONTH(Payment_Date), 1)
ORDER BY yr_month;

-- 6.5  Customers with repeated payment failures (priority follow-up list)
SELECT TOP 20
    c.Customer_ID, c.Customer_Name,
    COUNT(p.Payment_ID)                                                     AS total_transactions,
    SUM(CASE WHEN p.Payment_Status = 'Failed' THEN 1 ELSE 0 END)           AS failed_count,
    ROUND(SUM(CASE WHEN p.Payment_Status = 'Failed'
                   THEN p.Payment_Amount ELSE 0 END), 2)                    AS failed_amount
FROM Fact_Payments AS p
INNER JOIN Dim_Customer AS c ON p.Customer_ID = c.Customer_ID
GROUP BY c.Customer_ID, c.Customer_Name
HAVING SUM(CASE WHEN p.Payment_Status = 'Failed' THEN 1 ELSE 0 END) > 3
ORDER BY failed_amount DESC;


/*
================================================================================
  SECTION 7 — SHIPMENT & DELIVERY PERFORMANCE
  Business Question: Are delays directly causing returns?
  Finding: All ship modes have same avg delivery time (6.5 days) —
           delay issue is not mode-specific.
================================================================================
*/

-- 7.1  Delivery status breakdown
SELECT
    Delivery_Status,
    COUNT(*)                                                                AS shipment_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)                     AS pct
FROM Fact_Shipment
GROUP BY Delivery_Status;

-- 7.2  Average delivery time and cost by ship mode
SELECT
    Ship_Mode,
    COUNT(*)                                                                AS total_shipments,
    ROUND(AVG(DATEDIFF(DAY, Ship_Date, Actual_Delivery_Date)), 1)          AS avg_delivery_days,
    ROUND(AVG(DATEDIFF(DAY, Expected_Delivery_Date,
                       Actual_Delivery_Date)), 1)                          AS avg_days_late,
    ROUND(AVG(Ship_Cost), 2)                                               AS avg_ship_cost
FROM Fact_Shipment
WHERE Actual_Delivery_Date IS NOT NULL
GROUP BY Ship_Mode
ORDER BY avg_delivery_days;

-- 7.3  Delayed shipments by region
SELECT
    r.Region_Name,
    COUNT(sh.Shipment_ID)                                                   AS total_shipments,
    SUM(CASE WHEN sh.Delivery_Status = 'Delayed' THEN 1 ELSE 0 END)        AS delayed,
    ROUND(SUM(CASE WHEN sh.Delivery_Status = 'Delayed' THEN 1 ELSE 0 END)
          * 100.0 / NULLIF(COUNT(sh.Shipment_ID), 0), 2)                   AS delay_rate_pct
FROM Fact_Shipment AS sh
INNER JOIN Fact_Sales   AS s ON sh.Order_ID   = s.Order_ID
INNER JOIN Dim_Customer AS c ON s.Customer_ID = c.Customer_ID
INNER JOIN Dim_Region   AS r ON c.Region_ID   = r.Region_ID
GROUP BY r.Region_Name
ORDER BY delay_rate_pct DESC;

-- 7.4  Delayed orders that were also returned (causality check)
SELECT
    sh.Delivery_Status,
    COUNT(DISTINCT sh.Order_ID)                                             AS total_shipments,
    COUNT(DISTINCT r.Order_ID)                                              AS also_returned,
    ROUND(COUNT(DISTINCT r.Order_ID) * 100.0
          / NULLIF(COUNT(DISTINCT sh.Order_ID), 0), 2)                     AS return_pct
FROM Fact_Shipment AS sh
LEFT JOIN Fact_Returns AS r ON sh.Order_ID = r.Order_ID
GROUP BY sh.Delivery_Status
ORDER BY return_pct DESC;


/*
================================================================================
  SECTION 8 — PRODUCT & SUPPLIER ANALYTICS
  Business Question: Which products and suppliers drive revenue?
================================================================================
*/

-- 8.1  Revenue by category with order count
WITH cat_rev_tab AS (
    SELECT
        p.Category,
        ROUND(SUM(s.Sales_Amount), 2)   AS total_revenue,
        COUNT(DISTINCT s.Order_ID)      AS total_orders,
        ROUND(AVG(s.Sales_Amount), 2)   AS avg_order_value
    FROM Fact_Sales AS s
    INNER JOIN Dim_Product AS p ON s.Product_ID = p.Product_ID
    GROUP BY p.Category
)
SELECT *,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM cat_rev_tab
ORDER BY total_revenue DESC;

-- 8.2  Top 10 products by revenue
WITH prod_rev_tab AS (
    SELECT
        p.Product_ID, p.Product_Name, p.Category, p.Brand,
        ROUND(SUM(s.Sales_Amount), 2)   AS total_revenue,
        COUNT(DISTINCT s.Order_ID)      AS total_orders
    FROM Fact_Sales AS s
    INNER JOIN Dim_Product AS p ON s.Product_ID = p.Product_ID
    GROUP BY p.Product_ID, p.Product_Name, p.Category, p.Brand
),
ranked AS (
    SELECT *,
        DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
    FROM prod_rev_tab
)
SELECT TOP 10 *
FROM ranked
ORDER BY revenue_rank;

-- 8.3  Top 5 products per category
WITH cat_prod_tab AS (
    SELECT
        p.Category, p.Product_ID, p.Product_Name, p.Brand,
        ROUND(SUM(s.Sales_Amount), 2)   AS revenue,
        COUNT(DISTINCT s.Order_ID)      AS orders,
        DENSE_RANK() OVER (
            PARTITION BY p.Category
            ORDER BY SUM(s.Sales_Amount) DESC) AS rnk
    FROM Fact_Sales AS s
    INNER JOIN Dim_Product AS p ON s.Product_ID = p.Product_ID
    GROUP BY p.Category, p.Product_ID, p.Product_Name, p.Brand
)
SELECT Category, Product_ID, Product_Name, Brand, revenue, orders
FROM cat_prod_tab
WHERE rnk <= 5
ORDER BY Category, rnk;

-- 8.4  Supplier-wise revenue and order contribution
WITH sup_rev_tab AS (
    SELECT
        sup.Supplier_ID, sup.Supplier_Name, sup.Country,
        COUNT(DISTINCT p.Product_ID)    AS product_count,
        ROUND(SUM(s.Sales_Amount), 2)   AS total_revenue,
        COUNT(DISTINCT s.Order_ID)      AS total_orders
    FROM Fact_Sales    AS s
    INNER JOIN Dim_Product  AS p   ON s.Product_ID  = p.Product_ID
    INNER JOIN Dim_Supplier AS sup ON p.Supplier_ID = sup.Supplier_ID
    GROUP BY sup.Supplier_ID, sup.Supplier_Name, sup.Country
)
SELECT *,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM sup_rev_tab
ORDER BY total_revenue DESC;

-- 8.5  Outlier orders — abnormally high or low transaction values (IQR method)
WITH pct_tab AS (
    SELECT
        Order_ID, Sales_Amount,
        PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY Sales_Amount) OVER() AS q1,
        PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY Sales_Amount) OVER() AS q3
    FROM Fact_Sales
),
iqr_tab AS (
    SELECT *,
           q3 - q1                  AS iqr,
           q1 - 1.5 * (q3 - q1)    AS lower_bound,
           q3 + 1.5 * (q3 - q1)    AS upper_bound
    FROM pct_tab
)
SELECT
    Order_ID, Sales_Amount, lower_bound, upper_bound,
    CASE
        WHEN Sales_Amount < lower_bound THEN 'Low Outlier'
        WHEN Sales_Amount > upper_bound THEN 'High Outlier'
    END AS outlier_flag
FROM iqr_tab
WHERE Sales_Amount < lower_bound
   OR Sales_Amount > upper_bound
ORDER BY Sales_Amount DESC;


/*
================================================================================
  SECTION 9 — CUSTOMER SEGMENTATION
  Business Question: Which customers actually drive revenue?
================================================================================
*/

-- 9.1  Full customer segmentation — Platinum / Gold / Silver / Regular
WITH clv_tab AS (
    SELECT
        c.Customer_ID, c.Customer_Name,
        r.Region_Name,
        ISNULL(ROUND(SUM(s.Sales_Amount), 2), 0) AS total_revenue,
        COUNT(DISTINCT s.Order_ID)               AS total_orders
    FROM Dim_Customer AS c
    LEFT JOIN Fact_Sales  AS s ON c.Customer_ID = s.Customer_ID
    LEFT JOIN Dim_Region  AS r ON c.Region_ID   = r.Region_ID
    GROUP BY c.Customer_ID, c.Customer_Name, r.Region_Name
)
SELECT *,
    CASE
        WHEN total_revenue >= 100000 THEN 'Platinum'
        WHEN total_revenue >= 50000  THEN 'Gold'
        WHEN total_revenue >= 20000  THEN 'Silver'
        ELSE 'Regular'
    END AS segment
FROM clv_tab
ORDER BY total_revenue DESC;

-- 9.2  Segment summary — revenue and customer count per tier
WITH seg_tab AS (
    SELECT
        c.Customer_ID,
        ISNULL(SUM(s.Sales_Amount), 0) AS total_revenue
    FROM Dim_Customer AS c
    LEFT JOIN Fact_Sales AS s ON c.Customer_ID = s.Customer_ID
    GROUP BY c.Customer_ID
),
labelled AS (
    SELECT *,
        CASE
            WHEN total_revenue >= 100000 THEN 'Platinum'
            WHEN total_revenue >= 50000  THEN 'Gold'
            WHEN total_revenue >= 20000  THEN 'Silver'
            ELSE 'Regular'
        END AS segment
    FROM seg_tab
)
SELECT
    segment,
    COUNT(*)                                                                AS customer_count,
    ROUND(SUM(total_revenue), 2)                                            AS segment_revenue,
    ROUND(AVG(total_revenue), 2)                                            AS avg_revenue_per_customer,
    ROUND(SUM(total_revenue) * 100.0 / SUM(SUM(total_revenue)) OVER(), 2)  AS revenue_contribution_pct
FROM labelled
GROUP BY segment
ORDER BY segment_revenue DESC;

-- 9.3  High-value customers — above 90th percentile in revenue
WITH clv_tab AS (
    SELECT Customer_ID, ROUND(SUM(Sales_Amount), 2) AS total_revenue
    FROM Fact_Sales
    GROUP BY Customer_ID
),
pct_tab AS (
    SELECT *,
        PERCENTILE_DISC(0.90) WITHIN GROUP (ORDER BY total_revenue) OVER() AS p90_threshold
    FROM clv_tab
)
SELECT Customer_ID, total_revenue, p90_threshold
FROM pct_tab
WHERE total_revenue > p90_threshold
ORDER BY total_revenue DESC;

-- 9.4  Most loyal customers — ordered in all 4 quarters of each year
SELECT
    YEAR(s.Order_Date)                                 AS yr,
    c.Customer_ID, c.Customer_Name,
    COUNT(DISTINCT DATEPART(QUARTER, s.Order_Date))    AS active_quarters
FROM Dim_Customer AS c
INNER JOIN Fact_Sales AS s ON c.Customer_ID = s.Customer_ID
GROUP BY YEAR(s.Order_Date), c.Customer_ID, c.Customer_Name
HAVING COUNT(DISTINCT DATEPART(QUARTER, s.Order_Date)) = 4
ORDER BY yr, c.Customer_ID;
