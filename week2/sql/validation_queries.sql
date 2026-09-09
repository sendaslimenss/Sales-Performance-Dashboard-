
-- Week 2 - Data Validation Queries
-- Sales Performance Dashboard
-- 1. Check total rows, date range and total revenue
SELECT
    COUNT(*) AS total_rows,
    MIN(order_date) AS min_date,
    MAX(order_date) AS max_date,
    SUM(revenue) AS total_revenue
FROM sales;


-- 2. Verify revenue calculation
SELECT
    order_id,
    quantity,
    unit_price,
    discount,
    revenue,
    ROUND(
        quantity * unit_price * (1 - discount),
        2
    ) AS calculated_revenue
FROM sales
LIMIT 5;


-- 3. Check monthly revenue
SELECT
    DATE_TRUNC('month', order_date) AS month,
    SUM(revenue) AS monthly_revenue
FROM sales
GROUP BY 1
ORDER BY 1;


-- 4. General sanity check
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    MIN(order_date) AS min_date,
    MAX(order_date) AS max_date,
    SUM(
        CASE
            WHEN revenue IS NULL THEN 1
            ELSE 0
        END
    ) AS null_revenue,
    SUM(
        CASE
            WHEN order_date IS NULL THEN 1
            ELSE 0
        END
    ) AS null_dates,
    SUM(
        CASE
            WHEN ABS(
                quantity * unit_price * (1 - discount) - revenue
            ) > 0.01
            THEN 1
            ELSE 0
        END
    ) AS invalid_revenue
FROM sales;