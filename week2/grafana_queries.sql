
-- Week2 - Grafana SQL Queries
-- Sales Performance Dashboard



-- 1. Total Revenue
SELECT
    SUM(revenue) AS total_revenue
FROM sales;


-- 2. Total Orders
SELECT
    COUNT(DISTINCT order_id) AS total_orders
FROM sales;


-- 3. Average Order Value
SELECT
    ROUND(
        SUM(revenue) / NULLIF(COUNT(DISTINCT order_id), 0),
        2
    ) AS average_order_value
FROM sales;


-- 4. Monthly Revenue
SELECT
    DATE_TRUNC('month', order_date) AS time,
    SUM(revenue) AS monthly_revenue
FROM sales
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY time;


-- 5. Top 5 Product Categories
SELECT
    product_category,
    SUM(revenue) AS total_revenue
FROM sales
GROUP BY product_category
ORDER BY total_revenue DESC
LIMIT 5;


-- 6. Revenue by Region
SELECT
    region,
    SUM(revenue) AS total_revenue
FROM sales
GROUP BY region
ORDER BY total_revenue DESC;


-- 7. Month-over-Month Growth
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(revenue) AS revenue
    FROM sales
    GROUP BY DATE_TRUNC('month', order_date)
),
monthly_with_previous AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS previous_revenue
    FROM monthly_revenue
)
SELECT
    month,
    revenue,
    previous_revenue,
    ROUND(
        (
            (revenue - previous_revenue)
            / NULLIF(previous_revenue, 0)
        ) * 100,
        2
    ) AS mom_growth
FROM monthly_with_previous
ORDER BY month;
