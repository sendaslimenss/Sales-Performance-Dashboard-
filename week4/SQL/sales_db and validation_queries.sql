-- SALES PERFORMANCE DASHBOARD
-- PostgreSQL SQL Script

-- 1. DATABASE TABLE CREATION
CREATE TABLE sales (
    order_id INT PRIMARY key ,
    order_date DATE not null,
    customer_id INT not null,
    product_category VARCHAR(50),
    region VARCHAR(50),
    quantity INT,
    unit_price DECIMAL(10,2),
    discount DECIMAL(3,2),
    payment_method VARCHAR(50),
    delivery_days INT,
    customer_rating DECIMAL(3,1),
    revenue DECIMAL(10,2));

-- 2. INDEXES
SELECT * FROM sales ;
CREATE INDEX idx_sales_order_date ON sales(order_date);
CREATE INDEX idx_sales_region      ON sales(region);

-- 3. DATA VALIDATION

-- View the sales table
SELECT *
FROM sales;

-- Check row count, date range and total revenue
SELECT
    COUNT(*) AS total_rows,
    MIN(order_date) AS min_date,
    MAX(order_date) AS max_date,
    SUM(revenue) AS total_revenue
FROM sales;

-- Check revenue calculation
SELECT order_id, quantity, unit_price, discount, revenue,
       ROUND(quantity * unit_price * (1 - discount), 2) AS calc_revenue
FROM sales
LIMIT 5;

-- Find invalid revenue values
SELECT 
    order_id,
    revenue,
    ROUND(quantity * unit_price * (1 - discount), 2) AS calculated_revenue
FROM sales
WHERE ABS(
    quantity * unit_price * (1 - discount) - revenue
) > 0.01;

-- 4. DATA QUALITY VALIDATION

-- Check for duplicate Order IDs
SELECT
    order_id,
    COUNT(*) AS occurrences
FROM sales
GROUP BY order_id
HAVING COUNT(*) > 1;
-- Check invalid or missing values
SELECT
    COUNT(*) FILTER (WHERE order_date IS NULL) AS null_dates,
    COUNT(*) FILTER (WHERE revenue IS NULL) AS null_revenue,
    COUNT(*) FILTER (
        WHERE quantity IS NULL OR quantity <= 0
    ) AS invalid_quantity,
    COUNT(*) FILTER (
        WHERE unit_price IS NULL OR unit_price < 0
    ) AS invalid_price,
    COUNT(*) FILTER (
        WHERE discount IS NULL OR discount < 0 OR discount > 1
    ) AS invalid_discount,
    COUNT(*) FILTER (
        WHERE region IS NULL OR TRIM(region) = ''
    ) AS missing_region,
    COUNT(*) FILTER (
        WHERE product_category IS NULL
        OR TRIM(product_category) = ''
    ) AS missing_category
FROM sales;

-- 5. KPI QUERIES
--Total Revenue
SELECT 
    SUM(revenue) AS total_revenue
FROM sales;
--Total Orders
SELECT 
    COUNT(DISTINCT order_id) AS total_orders
FROM sales;
--Average Order Value
SELECT 
    SUM(revenue) / COUNT(DISTINCT order_id) AS average_order_value
FROM sales;
--6. Monthly Revenue
SELECT
    DATE_TRUNC('month', order_date) AS month,
    SUM(revenue) AS monthly_revenue
FROM sales
GROUP BY 1
ORDER BY 1;
--7. Revenue by Product Category
SELECT
    product_category,
    SUM(revenue) AS total_revenue
FROM sales
GROUP BY product_category
ORDER BY total_revenue DESC;
--8.Revenue by Region
SELECT
    region,
    SUM(revenue) AS total_revenue
FROM sales
GROUP BY region
ORDER BY total_revenue DESC;
--9.MONTH-OVER-MONTH GROWTH
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(revenue) AS revenue
    FROM sales
    GROUP BY 1
)

SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue,
    ROUND(
        (
            (revenue - LAG(revenue) OVER (ORDER BY month))
            / NULLIF(LAG(revenue) OVER (ORDER BY month), 0)
        ) * 100,
        2
    ) AS mom_growth
FROM monthly_revenue
ORDER BY month;



-- 10. 2034 ANALYSIS

-- Total Revenue — 2034
SELECT SUM(revenue) AS total_revenue
FROM sales
WHERE order_date >= '2034-01-01'
  AND order_date < '2035-01-01';

-- Total Orders — 2034
SELECT COUNT(DISTINCT order_id) AS total_orders
FROM sales
WHERE order_date >= '2034-01-01'
  AND order_date < '2035-01-01';

-- Average Order Value — 2034
SELECT
    SUM(revenue) / NULLIF(COUNT(DISTINCT order_id), 0) AS aov
FROM sales
WHERE order_date >= '2034-01-01'
  AND order_date < '2035-01-01';

-- Monthly Revenue — 2035
SELECT
    DATE_TRUNC('month', order_date) AS month,
    SUM(revenue) AS monthly_revenue
FROM sales
WHERE order_date >= '2034-01-01'
  AND order_date < '2035-01-01'
GROUP BY 1
ORDER BY 1;

-- Revenue by Product Category — 2034
SELECT
    product_category,
    SUM(revenue) AS total_revenue
FROM sales
WHERE order_date >= '2034-01-01'
  AND order_date < '2035-01-01'
GROUP BY product_category
ORDER BY total_revenue DESC;

-- Revenue by Region — 2034
SELECT
    region,
    SUM(revenue) AS total_revenue
FROM sales
WHERE order_date >= '2034-01-01'
  AND order_date < '2035-01-01'
GROUP BY region
ORDER BY total_revenue DESC;

-- MoM Growth — 2035
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(revenue) AS revenue
    FROM sales
    GROUP BY 1
),
calc AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS previous_revenue
    FROM monthly
)
SELECT
    month,
    revenue,
    previous_revenue,
    ROUND(
        ((revenue - previous_revenue)
        / NULLIF(previous_revenue, 0) * 100)::numeric,
        2
    ) AS mom_growth
FROM calc
ORDER BY month DESC
LIMIT 5;

-- 11. TESTING & VALIDATION
/*Purpose:
  1. Validate the cleaned sales table.
  2. Validate KPI calculations.
  3. Validate monthly and MoM calculations.
  4. Validate regional/category aggregations.
  5. Provide test cases for empty results.*/

--TEST 01 - Dataset control totals
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    MIN(order_date) AS min_date,
    MAX(order_date) AS max_date,
    ROUND(SUM(revenue), 2) AS total_revenue,
    COUNT(*) FILTER (WHERE order_date IS NULL) AS null_dates,
    COUNT(*) FILTER (WHERE revenue IS NULL) AS null_revenue,
    COUNT(*) FILTER (WHERE quantity IS NULL OR quantity <= 0) AS invalid_quantity,
    COUNT(*) FILTER (WHERE unit_price IS NULL OR unit_price < 0) AS invalid_unit_price,
    COUNT(*) FILTER (WHERE discount IS NULL OR discount < 0 OR discount > 1) AS invalid_discount
FROM sales;


--TEST 02 - ORDER ID UNIQUENESS
SELECT
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT order_id) THEN 'PASS'
        ELSE 'FAIL'
    END AS result,
    COUNT(*) AS rows_count,
    COUNT(DISTINCT order_id) AS distinct_order_ids
FROM sales;

--TEST 03 - REVENUE FORMULA VALIDATION
/* Expected:
     revenue = quantity * unit_price * (1 - discount)
   Tolerance: 0.01 because revenue is stored to 2 decimals.*/

SELECT
    COUNT(*) AS checked_rows,
    COUNT(*) FILTER (
        WHERE ABS(
            revenue - ROUND(quantity * unit_price * (1 - discount), 2)
        ) > 0.01
    ) AS incorrect_revenue_rows,
    CASE
        WHEN COUNT(*) FILTER (
            WHERE ABS(
                revenue - ROUND(quantity * unit_price * (1 - discount), 2)
            ) > 0.01
        ) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM sales
WHERE revenue IS NOT NULL
  AND quantity IS NOT NULL
  AND unit_price IS NOT NULL
  AND discount IS NOT NULL;

--TEST 04 - AVERAGE ORDER VALUE
/*Formula:
     AOV = Total Revenue / Number of Orders*/
SELECT
    ROUND(SUM(revenue), 2) AS total_revenue,
    COUNT(DISTINCT order_id) AS order_count,
    ROUND(
        SUM(revenue) / NULLIF(COUNT(DISTINCT order_id), 0),
        2
    ) AS average_order_value
FROM sales;

--TEST 05 - MONTHLY REVENUE
SELECT
    DATE_TRUNC('month', order_date) AS month,
    ROUND(SUM(revenue), 2) AS monthly_revenue
FROM sales
GROUP BY 1
ORDER BY 1;

--TEST 06 - MONTH-OVER-MONTH GROWTH
/*The first month has no previous month, therefore MoM is NULL.*/
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(revenue) AS revenue
    FROM sales
    GROUP BY 1
), growth AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue
    FROM monthly
)
SELECT
    month,
    ROUND(revenue, 2) AS current_month_revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND(
        ((revenue - previous_month_revenue)
         / NULLIF(previous_month_revenue, 0)) * 100,
        2
    ) AS mom_growth_percent
FROM growth
ORDER BY month;

--TEST 07 - REGIONAL REVENUE
 SELECT
    COALESCE(region, 'Unknown') AS region,
    COUNT(DISTINCT order_id) AS order_count,
    ROUND(SUM(revenue), 2) AS total_revenue
FROM sales
GROUP BY 1
ORDER BY total_revenue DESC;

   TEST 08 - CATEGORY REVENUE
/*This is the valid replacement for "Top 5 Products" because
   the current dataset contains product_category, not product_name.*/
SELECT
    product_category,
    COUNT(DISTINCT order_id) AS order_count,
    ROUND(SUM(revenue), 2) AS total_revenue
FROM sales
GROUP BY product_category
ORDER BY total_revenue DESC;

--TEST 09 - EXPECTED FOUR CATEGORIES
  /* Current project scope: Electronics, Clothing, Home, Beauty.
   This does not invent product-level information.*/
SELECT
    COUNT(DISTINCT product_category) AS category_count,
    ARRAY_AGG(DISTINCT product_category ORDER BY product_category) AS categories
FROM sales;
 
--TEST 10 - EMPTY RESULT CASE
  /* This should return 0 rows and must not produce a SQL error.*/ */
SELECT
    order_id,
    order_date,
    revenue
FROM sales
WHERE order_date >= DATE '2099-01-01'
  AND order_date < DATE '2100-01-01';
--TEST 11 - EMPTY RESULT COUNT
  /* Expected result: 0*/
SELECT COUNT(*) AS rows_returned
FROM sales
WHERE order_date >= DATE '2099-01-01'
  AND order_date < DATE '2100-01-01';

--TEST 12 - INVALID / NULL DATA SUMMARY
 
SELECT
    COUNT(*) FILTER (WHERE order_date IS NULL) AS null_dates,
    COUNT(*) FILTER (WHERE revenue IS NULL) AS null_revenue,
    COUNT(*) FILTER (WHERE quantity IS NULL OR quantity <= 0) AS invalid_quantity,
    COUNT(*) FILTER (WHERE unit_price IS NULL OR unit_price < 0) AS invalid_price,
    COUNT(*) FILTER (WHERE discount IS NULL OR discount < 0 OR discount > 1) AS invalid_discount,
    COUNT(*) FILTER (WHERE region IS NULL OR TRIM(region) = '') AS missing_region,
    COUNT(*) FILTER (WHERE product_category IS NULL OR TRIM(product_category) = '') AS missing_category
FROM sales;

