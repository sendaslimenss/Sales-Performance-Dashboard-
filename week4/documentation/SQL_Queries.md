# SQL Queries — Sales Performance Dashboard

## 1. Overview

This document describes all SQL queries used in the Sales Performance Dashboard
project. The script is written for **PostgreSQL** and covers:

- Sales table creation and indexes
- Data validation and data-quality checks
- KPI calculations
- Monthly revenue analysis
- Month-over-Month (MoM) growth
- Revenue by product category and by region
- Grafana panel queries (with `$__timeFilter`)

All analytical queries run against the cleaned `sales` table loaded from
`sales_cleaned.csv`.

---

## 2. Database Structure

### 2.1 Table Creation

The `sales` table contains the main sales information used by the project:

```sql
CREATE TABLE sales (
    order_id         VARCHAR PRIMARY KEY,
    order_date       DATE NOT NULL,
    customer_id      VARCHAR NOT NULL,
    product_category VARCHAR,
    region           VARCHAR,
    quantity         INTEGER,
    unit_price       NUMERIC(10, 2),
    discount         NUMERIC(4, 2),
    payment_method   VARCHAR,
    delivery_days    INTEGER,
    customer_rating  INTEGER,
    revenue          NUMERIC(12, 2)
);
```

- `order_id` is the **primary key**.
- `order_date` and `customer_id` are **NOT NULL**.

### 2.2 Indexes

```sql
CREATE INDEX idx_sales_order_date ON sales(order_date);
CREATE INDEX idx_sales_region     ON sales(region);
```

These support the filtering (`WHERE order_date …`) and grouping
(`GROUP BY region`) operations used across the dashboard.

---

## 3. KPI Queries

These queries produce the main summary metrics shown on the dashboard.
Grafana versions use `$__timeFilter(order_date)` so the KPIs react to the
dashboard's native time-range selector.

### 3.1 Total Revenue

Plain SQL (full dataset):

```sql
SELECT ROUND(SUM(revenue), 2) AS total_revenue
FROM sales;
```

Grafana panel query:

```sql
SELECT COALESCE(SUM(revenue), 0) AS total_revenue
FROM sales
WHERE $__timeFilter(order_date);
```

- **Control total (full dataset):** `5,109,775.74`
- `COALESCE(..., 0)` ensures the KPI shows `0` instead of `NULL` for empty periods.

### 3.2 Total Orders

```sql
SELECT COUNT(DISTINCT order_id) AS total_orders
FROM sales
WHERE $__timeFilter(order_date);
```

- **Control total (full dataset):** `5,000` unique orders

### 3.3 Average Order Value (AOV)

```
AOV = Total Revenue / Number of Unique Orders
```

```sql
SELECT COALESCE(
           SUM(revenue) / NULLIF(COUNT(DISTINCT order_id), 0),
           0
       ) AS average_order_value
FROM sales
WHERE $__timeFilter(order_date);
```

- **Control value (full dataset):** `1,021.96`
- `NULLIF(..., 0)` + `COALESCE(..., 0)` protects against division by zero on empty periods.

---

## 4. Chart Queries

### 4.1 Monthly Revenue — *Revenue Over Time* panel

Uses `DATE_TRUNC()` to group sales by month:

```sql
SELECT
    DATE_TRUNC('month', order_date) AS time,
    SUM(revenue)                    AS monthly_revenue
FROM sales
WHERE $__timeFilter(order_date)
GROUP BY 1
ORDER BY 1;
```

The Grafana time range dynamically determines which months are displayed.

### 4.2 Month-over-Month (MoM) Growth — KPI card / trend panel

Conceptually:

```
MoM Growth = (Current Month Revenue − Previous Month Revenue)
             / Previous Month Revenue × 100
```

Calculated with the `LAG()` window function:

```sql
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(revenue)                    AS revenue
    FROM sales
    GROUP BY 1
),
with_previous AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS previous_revenue
    FROM monthly_revenue
)
SELECT
    month AS time,
    revenue,
    CASE
        WHEN previous_revenue IS NULL OR previous_revenue = 0
        THEN NULL
        ELSE ((revenue - previous_revenue) / previous_revenue) * 100
    END AS mom_growth
FROM with_previous
WHERE $__timeFilter(month)
ORDER BY month;
```

**Important design decision:** the complete monthly history is calculated
**first** (in the CTE), and the dashboard time filter is applied **afterwards**
in the outer query. This guarantees the previous month's revenue remains
available when computing the growth of the first visible month.

- The **first month** has no previous month → its MoM value is `NULL`.
- `NULLIF` / `CASE` guards prevent division by zero.

### 4.3 Revenue by Region

```sql
SELECT
    region,
    SUM(revenue) AS total_revenue
FROM sales
WHERE $__timeFilter(order_date)
GROUP BY region
ORDER BY total_revenue DESC;
```

**Control totals (full dataset):**

| Region | Revenue      |
| ------ | ------------:|
| West   | 1,345,582.16 |
| North  | 1,281,508.45 |
| South  | 1,246,640.90 |
| East   | 1,236,044.23 |

### 4.4 Revenue by Product Category

> Because `product_name` is not available in the dataset (see §7), revenue is
> aggregated by `product_category`.

```sql
SELECT
    product_category,
    SUM(revenue) AS total_revenue
FROM sales
WHERE $__timeFilter(order_date)
GROUP BY product_category
ORDER BY total_revenue DESC;
```

**Control totals (full dataset):**

| Product Category | Revenue      |
| ---------------- | ------------:|
| Electronics      | 1,829,899.22 |
| Clothing         | 1,531,931.72 |
| Home             |   982,083.92 |
| Beauty           |   765,860.88 |

---

## 5. Optional Region Filter (Grafana Variable)

A dashboard variable allows filtering all panels by region.

**Configuration:**

| Setting           | Value                                                    |
| ----------------- | -------------------------------------------------------- |
| Variable name     | `region`                                                 |
| Label             | Region                                                   |
| Include All option| Enabled (custom All value: `All`)                        |

**Variable query:**

```sql
SELECT DISTINCT region
FROM sales
ORDER BY region;
```

**Panel queries then add the region condition:**

```sql
SELECT
    SUM(revenue) AS total_revenue
FROM sales
WHERE $__timeFilter(order_date)
  AND ('${region}' = 'All'
       OR region IN (${region:sqlstring}));
```

---

## 6. Validation Queries

These queries are used to verify data quality before and after loading.

### 6.1 Dataset Control Information

```sql
SELECT
    COUNT(*)                 AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    MIN(order_date)          AS min_date,
    MAX(order_date)          AS max_date,
    ROUND(SUM(revenue), 2)   AS total_revenue,
    COUNT(*) FILTER (WHERE order_date IS NULL)              AS null_dates,
    COUNT(*) FILTER (WHERE revenue IS NULL)                 AS null_revenue,
    COUNT(*) FILTER (WHERE quantity IS NULL OR quantity <= 0)   AS invalid_quantity,
    COUNT(*) FILTER (WHERE unit_price IS NULL OR unit_price < 0) AS invalid_unit_price,
    COUNT(*) FILTER (WHERE discount IS NULL OR discount < 0 OR discount > 1) AS invalid_discount
FROM sales;
```

### 6.2 Revenue Calculation Check

```sql
SELECT
    order_id,
    revenue,
    quantity * unit_price * (1 - discount) AS calculated_revenue,
    ABS(revenue - (quantity * unit_price * (1 - discount))) AS difference
FROM sales
WHERE ABS(revenue - (quantity * unit_price * (1 - discount))) > 0.01;
```

An **empty result** means no significant revenue errors (tolerance = 0.01,
because revenue is stored with two decimals).

### 6.3 Duplicate Order IDs

```sql
SELECT order_id, COUNT(*) AS occurrences
FROM sales
GROUP BY order_id
HAVING COUNT(*) > 1;
```

An empty result confirms uniqueness (also enforced by the primary key).

### 6.4 Missing / Invalid Value Summary

```sql
SELECT
    COUNT(*) FILTER (WHERE order_date IS NULL)                    AS missing_order_dates,
    COUNT(*) FILTER (WHERE revenue IS NULL)                       AS missing_revenue,
    COUNT(*) FILTER (WHERE quantity IS NULL OR quantity <= 0)     AS invalid_quantity,
    COUNT(*) FILTER (WHERE unit_price IS NULL OR unit_price < 0)  AS invalid_unit_price,
    COUNT(*) FILTER (WHERE discount IS NULL OR discount < 0 OR discount > 1) AS invalid_discount,
    COUNT(*) FILTER (WHERE region IS NULL OR TRIM(region) = '')   AS missing_region,
    COUNT(*) FILTER (WHERE product_category IS NULL OR TRIM(product_category) = '') AS missing_product_category
FROM sales;
```

---

## 7. Project Scope — Product-Level Analysis

The dataset contains **no `product_name` field**. Product-level analysis such as
**Top 5 Products** therefore cannot be calculated directly from the raw data
without inventing information. The project uses **Revenue by Product Category**
with the available categories:

- Electronics
- Clothing
- Home
- Beauty

This keeps the dashboard consistent with the source data.

---

## 8. SQL → Grafana Workflow

```
Cleaned Sales Dataset (sales_cleaned.csv)
        ↓
PostgreSQL (sales table + indexes)
        ↓
SQL Validation & KPI/Chart Queries
        ↓
Grafana PostgreSQL Data Source
        ↓
Dashboard Panels
  ├── KPI cards: Total Revenue | Total Orders | AOV | MoM Growth
  ├── Revenue Over Time (monthly time series)
  ├── Revenue by Product Category
  └── Revenue by Region
```

All main dashboard metrics are calculated **dynamically from SQL** — no
important dashboard value is hard-coded.
