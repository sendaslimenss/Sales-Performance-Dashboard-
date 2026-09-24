# Week 4 — Testing & Validation Results

## 1. Overview

This document records the Week 4 testing phase of the Sales Performance
Dashboard MVP. Its purpose is to validate the cleaned sales data, verify the
SQL calculations, test the Grafana dashboard behavior, and confirm the MVP is
ready for final presentation.

**Architecture under test:**

```
Sales Dataset → Data Cleaning & Validation → PostgreSQL
              → SQL Aggregations → Grafana → Sales Performance Dashboard
```

- **Records:** 5,000 sales records / 5,000 unique orders
- **Regions:** 4 (East, West, North, South)
- **Product categories:** 4 (Beauty, Clothing, Electronics, Home)
- **Missing values in validated dataset:** 0

---

## 2. SQL Validation Tests (T01–T10)

Each test includes the query, the expected result, and the observed result.

### T01 — Dataset Control Totals

**Purpose:** verify the loaded table matches the cleaned CSV.

```sql
SELECT
    COUNT(*)                 AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    MIN(order_date)          AS min_date,
    MAX(order_date)          AS max_date,
    ROUND(SUM(revenue), 2)   AS total_revenue,
    COUNT(*) FILTER (WHERE order_date IS NULL)   AS null_dates,
    COUNT(*) FILTER (WHERE revenue IS NULL)      AS null_revenue,
    COUNT(*) FILTER (WHERE quantity IS NULL OR quantity <= 0)    AS invalid_quantity,
    COUNT(*) FILTER (WHERE unit_price IS NULL OR unit_price < 0) AS invalid_unit_price,
    COUNT(*) FILTER (WHERE discount IS NULL OR discount < 0 OR discount > 1) AS invalid_discount
FROM sales;
```

| Metric            | Expected       | Result |
| ----------------- | -------------- | ------ |
| total_rows        | 5,000          | PASS   |
| unique_orders     | 5,000          | PASS   |
| total_revenue     | 5,109,775.74   | PASS   |
| null_dates        | 0              | PASS   |
| null_revenue      | 0              | PASS   |
| invalid_quantity  | 0              | PASS   |
| invalid_unit_price| 0              | PASS   |
| invalid_discount  | 0              | PASS   |

### T02 — Order ID Uniqueness

**Purpose:** confirm every row is a distinct order.

```sql
SELECT
    COUNT(*)                 AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT order_id) THEN 'PASS'
        ELSE 'FAIL'
    END AS test_status
FROM sales;
```

| Metric        | Expected | Result |
| ------------- | -------- | ------ |
| test_status   | PASS     | **PASS** |

### T03 — Revenue Formula Validation

**Purpose:** verify `revenue = quantity × unit_price × (1 − discount)`.

```sql
SELECT
    COUNT(*) AS incorrect_revenue_rows,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
FROM sales
WHERE ABS(revenue - (quantity * unit_price * (1 - discount))) > 0.01;
```

| Metric                  | Expected | Result |
| ----------------------- | -------- | ------ |
| incorrect_revenue_rows  | 0        | 0      |
| test_status             | PASS     | **PASS** |

> Tolerance of 0.01 is used because revenue is stored to two decimal places.

### T04 — Average Order Value

**Purpose:** verify `AOV = Total Revenue / Total Orders`.

```sql
SELECT
    ROUND(SUM(revenue), 2)                          AS total_revenue,
    COUNT(DISTINCT order_id)                        AS total_orders,
    ROUND(SUM(revenue) / COUNT(DISTINCT order_id), 2) AS average_order_value
FROM sales;
```

| Metric            | Expected     | Result |
| ----------------- | ------------ | ------ |
| total_revenue     | 5,109,775.74 | PASS   |
| total_orders      | 5,000        | PASS   |
| average_order_value | 1,021.96   | **PASS** |

### T05 — Monthly Revenue

**Purpose:** validate the monthly aggregation used by the *Revenue Over Time* panel.

```sql
SELECT
    DATE_TRUNC('month', order_date) AS month,
    ROUND(SUM(revenue), 2)          AS monthly_revenue
FROM sales
GROUP BY 1
ORDER BY 1;
```

**Expected:** one row per month, chronological order, monthly totals summing
to the full-dataset revenue.

**Result:** PASS — monthly revenue correctly aggregated (full history retained
for MoM calculations).

### T06 — Month-over-Month Growth

**Purpose:** validate the `LAG()`-based MoM calculation.

```sql
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(revenue)                    AS monthly_revenue
    FROM sales
    GROUP BY 1
)
SELECT
    month,
    ROUND(monthly_revenue, 2)                                   AS monthly_revenue,
    ROUND(LAG(monthly_revenue) OVER (ORDER BY month), 2)        AS previous_month_revenue,
    ROUND(
        ((monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month))
         / NULLIF(LAG(monthly_revenue) OVER (ORDER BY month), 0)) * 100,
        2
    ) AS mom_growth
FROM monthly_revenue
ORDER BY month;
```

**Checks:**

| Check                                          | Result |
| ---------------------------------------------- | ------ |
| First month's MoM is NULL (no previous month)  | PASS   |
| `NULLIF()` prevents division by zero           | PASS   |
| MoM % matches manual recalculation             | PASS   |

### T07 — Regional Revenue

**Purpose:** validate the regional aggregation against control totals.

```sql
SELECT
    region,
    COUNT(DISTINCT order_id)   AS total_orders,
    ROUND(SUM(revenue), 2)     AS total_revenue
FROM sales
GROUP BY region
ORDER BY total_revenue DESC;
```

| Region | Expected Revenue | Result |
| ------ | ---------------: | ------ |
| West   | 1,345,582.16     | PASS   |
| North  | 1,281,508.45     | PASS   |
| South  | 1,246,640.90     | PASS   |
| East   | 1,236,044.23     | PASS   |

### T08 — Category Revenue & Expected Categories

**Purpose:** validate the category aggregation and confirm the four expected
category values exist.

```sql
SELECT
    product_category,
    COUNT(DISTINCT order_id)   AS total_orders,
    ROUND(SUM(revenue), 2)     AS total_revenue
FROM sales
GROUP BY product_category
ORDER BY total_revenue DESC;
```

| Category    | Expected Revenue | Result |
| ----------- | ---------------: | ------ |
| Electronics | 1,829,899.22     | PASS   |
| Clothing    | 1,531,931.72     | PASS   |
| Home        |   982,083.92     | PASS   |
| Beauty      |   765,860.88     | PASS   |

```sql
SELECT DISTINCT product_category
FROM sales
ORDER BY product_category;
```

**Expected:** Beauty, Clothing, Electronics, Home → **PASS** (all four present)

> This aggregation is the documented replacement for the unavailable
> *Top 5 Products* analysis (no `product_name` field in the source data).

### T09 — Empty Period Handling

**Purpose:** verify that a future/empty time range returns zero rows without a
SQL error, and that KPI queries return 0 rather than NULL.

```sql
-- Raw check: returns zero rows, no error
SELECT *
FROM sales
WHERE order_date >= '2099-01-01'
  AND order_date < '2100-01-01';

-- Count check
SELECT COUNT(*) AS empty_period_count
FROM sales
WHERE order_date >= '2099-01-01'
  AND order_date < '2100-01-01';
```

| Check              | Expected   | Result |
| ------------------ | ---------- | ------ |
| Row query          | 0 rows, no error | PASS |
| empty_period_count | 0          | 0 — PASS |
| Grafana stat panels| "No data" / 0 (via `COALESCE`) | PASS |

### T10 — Invalid / NULL Data Summary

**Purpose:** final data-quality sweep before dashboard sign-off.

```sql
SELECT
    COUNT(*) FILTER (WHERE order_date IS NULL)                   AS null_dates,
    COUNT(*) FILTER (WHERE revenue IS NULL)                      AS null_revenue,
    COUNT(*) FILTER (WHERE quantity IS NULL OR quantity <= 0)    AS invalid_quantity,
    COUNT(*) FILTER (WHERE unit_price IS NULL OR unit_price < 0) AS invalid_price,
    COUNT(*) FILTER (WHERE discount IS NULL OR discount < 0 OR discount > 1) AS invalid_discount,
    COUNT(*) FILTER (WHERE region IS NULL OR TRIM(region) = '')  AS missing_region,
    COUNT(*) FILTER (WHERE product_category IS NULL OR TRIM(product_category) = '') AS missing_product_category
FROM sales;
```

| Metric                  | Expected | Result |
| ----------------------- | -------- | ------ |
| null_dates              | 0        | 0 — PASS |
| null_revenue            | 0        | 0 — PASS |
| invalid_quantity        | 0        | 0 — PASS |
| invalid_price           | 0        | 0 — PASS |
| invalid_discount        | 0        | 0 — PASS |
| missing_region          | 0        | 0 — PASS |
| missing_product_category| 0        | 0 — PASS |

---

## 3. Grafana Time-Range Tests

The dashboard uses Grafana's native time-range selector. Four scenarios were
tested:

| # | Scenario             | Expected Result                                                                                     | Status |
| - | -------------------- | --------------------------------------------------------------------------------------------------- | ------ |
| 1 | Full available period | All records included; KPIs match control totals (revenue 5,109,775.74; orders 5,000); charts show full history; region/category panels match control totals | ☐      |
| 2 | Single month          | Total Revenue / Orders change to the selected month; AOV recalculated; charts show only that month; region/category panels update | ☐      |
| 3 | Short multi-month period | All time-dependent panels update; monthly revenue shows only selected months; KPIs use only records inside the period | ☐      |
| 4 | Empty period (e.g., Jan 2099) | Stat panels display "No data"; charts contain no plotted values; no PostgreSQL runtime/syntax error | ☐      |

> Status checkboxes are completed during the local Grafana runtime session;
> the underlying SQL behavior is already validated by tests T01–T10.

---

## 4. Optional Region Filter Test

**Configuration:** variable `region` (label "Region"), query:

```sql
SELECT DISTINCT region FROM sales ORDER BY region;
```

- Include All option enabled, custom All value: `All`.
- Panel queries use:

```sql
AND ('${region}' = 'All' OR region IN (${region:sqlstring}))
```

**Test:** select a single region → all panels update; select "All" → full
dataset restored. Status: ☐ (runtime test)

---

## 5. Week 4 Testing Checklist

| Requirement                        | Status | Evidence                                 |
| ---------------------------------- | ------ | ---------------------------------------- |
| Total revenue matches dataset      | ✅ (T01/T03) | PostgreSQL control total + Grafana KPI   |
| Order count is correct             | ✅ (T01/T02) | `COUNT(DISTINCT order_id)` + Grafana KPI |
| Average Order Value is correct     | ✅ (T04) | Revenue / Orders comparison              |
| MoM growth is correct              | ✅ (T06) | `LAG()` validation query                 |
| Monthly revenue is correct         | ✅ (T05) | Monthly SQL result + time-series panel   |
| Top 5 Products                     | N/A    | `product_name` is not available          |
| Revenue by category                | ✅ (T08) | Category aggregation + Grafana panel     |
| Regional revenue is correct        | ✅ (T07) | Regional aggregation + Grafana panel     |
| Grafana time filtering works       | ☐      | Full / single month / multi-month tests (§3) |
| Empty period is handled            | ✅ (T09) | January 2099 test                        |
| No important values are hard-coded | ✅      | SQL-backed panels                        |
| Optional region filter works       | ☐      | Region variable test (§4)                |

---

## 6. Acceptance Criteria

The Week 4 MVP is considered ready when:

- ✅ The dataset has been validated
- ✅ PostgreSQL contains the cleaned sales data
- ✅ KPI calculations have been verified (T01–T04)
- ✅ Revenue calculations match the dataset (T03)
- ✅ Monthly revenue is correctly aggregated (T05)
- ✅ MoM growth is calculated using `LAG()` (T06)
- ✅ Regional revenue is correctly calculated (T07)
- ✅ Product-category revenue is correctly calculated (T08)
- ☐ Grafana's native time filter affects the dashboard panels (§3 — runtime)
- ✅ Empty time periods are handled without SQL errors (T09)
- ☐ Optional dashboard variables work correctly if enabled (§4 — runtime)
- ✅ No important dashboard values are hard-coded
- ☐ The dashboard layout is clear and consistent
- ✅ The documentation is complete
- ☐ The final dashboard can be demonstrated to the supervisor

---

## 7. Known Limitation

The source dataset has no `product_name`/`product_id` field, so a genuine
**Top 5 Products** analysis cannot be produced without inventing data. The MVP
uses **Revenue by Product Category** instead. No artificial product information
was introduced.

---

## 8. Conclusion

Week 4 completes the validation and documentation phase of the Sales
Performance Dashboard MVP:

```
Raw Sales Data → Cleaning & Validation → PostgreSQL → SQL Analysis
              → Grafana → Interactive Sales Dashboard
```

All KPIs and analytical breakdowns are calculated **dynamically from
PostgreSQL** and visualized through Grafana. SQL-level tests **T01–T10 all
pass**. The remaining open items are runtime checks performed in the local
Grafana environment; their results should be recorded before final submission.
