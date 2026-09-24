# Sales Performance Dashboard — Final README

An end-to-end analytics MVP that turns raw e-commerce sales data into an
interactive **Grafana dashboard** backed by **PostgreSQL**. The project covers
the full pipeline: data cleaning and validation in Python, database loading,
SQL-based KPI/chart calculations, and dashboard testing.

---

## 1. Project Overview

| Item              | Detail                                                        |
| ----------------- | ------------------------------------------------------------- |
| Dataset           | 5,000 sales records / 5,000 unique orders                     |
| Regions           | 4 — East, West, North, South                                  |
| Product categories| 4 — Beauty, Clothing, Electronics, Home                       |
| Data quality      | 0 missing values, 0 duplicates, 0 revenue mismatches          |
| Total revenue     | 5,109,775.74 TND (control total)                              |
| Avg. order value  | 1,021.96 TND (control value)                                  |
| Currency          | TND (Tunisian Dinar)                                          |

**Pipeline:**

```
Raw Dataset (ecommerce_sales_analytics_5000.csv)
        ↓
Python / Jupyter — Cleaning & Validation
        ↓
sales_cleaned.csv (5,000 rows × 12 columns)
        ↓
PostgreSQL — sales table + indexes
        ↓
SQL — KPI & aggregation queries
        ↓
Grafana — Sales Performance Dashboard
```

---

## 2. Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Source CSV     │────▶│  Data Preparation │────▶│  sales_cleaned  │
│  (5,000 rows)   │     │  (Pandas/Jupyter) │     │     .csv        │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                              ┌───────────────────────────▼───────────┐
                              │            PostgreSQL                  │
                              │  Database : sales_db                   │
                              │  Table    : sales  (PK: order_id)      │
                              │  Indexes  : order_date, region         │
                              └───────────────────────────┬───────────┘
                                                          │ SQL queries
                              ┌───────────────────────────▼───────────┐
                              │  Grafana (PostgreSQL data source)      │
                              │  • KPI stat cards                      │
                              │  • Monthly revenue time series         │
                              │  • Category & region bar charts        │
                              │  • Region / Category filter variables  │
                              └────────────────────────────────────────┘
```

**Design principles:**

- All dashboard values are computed **dynamically by SQL** — nothing is
  hard-coded.
- Empty time periods are handled gracefully (`COALESCE`, `NULLIF`, Grafana
  "No data" states) — no SQL errors.
- The full monthly history is computed in a CTE **before** applying the
  dashboard time filter, so Month-over-Month growth stays correct for the
  first visible month.

---

## 3. Dataset Schema

`sales` table (one row per order, `order_id` is the primary key):

| Column             | Type          | Description                     |
| ------------------ | ------------- | ------------------------------- |
| `order_id`         | VARCHAR (PK)  | Unique order identifier         |
| `order_date`       | DATE (NOT NULL)| Date of the order              |
| `customer_id`      | VARCHAR (NOT NULL) | Customer identifier       |
| `product_category` | VARCHAR       | Product category                |
| `region`           | VARCHAR       | Sales region                    |
| `quantity`         | INTEGER       | Quantity purchased              |
| `unit_price`       | NUMERIC(10,2) | Unit price                      |
| `discount`         | NUMERIC(4,2)  | Discount applied (0–1)          |
| `payment_method`   | VARCHAR       | Payment method                  |
| `delivery_days`    | INTEGER       | Delivery duration               |
| `customer_rating`  | INTEGER       | Customer rating (1–5)           |
| `revenue`          | NUMERIC(12,2) | Revenue = qty × price × (1−disc)|

**Known data limitation:** the source dataset has **no `product_name`/`product_id`
field**. A genuine *Top 5 Products* analysis therefore cannot be calculated
without inventing data. The dashboard uses **Revenue by Product Category**
instead — a documented decision; no artificial data was introduced.

---

## 4. Installation & Usage

### 4.1 Prerequisites

- **Python 3.x** with `pandas` and `jupyter` (for the optional cleaning step)
- **PostgreSQL** (tested on a local instance)
- **Grafana** (tested on v13.2.1) with the **PostgreSQL data source plugin**

### 4.2 Prepare the Data (Python)

```bash
jupyter notebook notebooks/sales.ipynb
```

The notebook loads `ecommerce_sales_analytics_5000.csv`, performs cleaning and
validation (see `Data_Preparation.md`), and exports `sales_cleaned.csv`.

### 4.3 Create the Database and Load the CSV

```sql
CREATE DATABASE sales_db;

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

CREATE INDEX idx_sales_order_date ON sales(order_date);
CREATE INDEX idx_sales_region     ON sales(region);

COPY sales FROM '/path/to/sales_cleaned.csv'
DELIMITER ',' CSV HEADER;
```

Verify the load (expected: 5,000 rows / 5,000 unique orders /
5,109,775.74 total revenue):

```sql
SELECT COUNT(*), COUNT(DISTINCT order_id), ROUND(SUM(revenue), 2)
FROM sales;
```

### 4.4 Connect Grafana

1. **Configuration → Data sources → Add data source → PostgreSQL**
2. Set host, database (`sales_db`), user/password.
3. **Save & test** — the connection should be green.

### 4.5 Import the Dashboard

1. **Dashboards → New → Import** → upload
   `Sales Performance-*.json` (or paste its contents).
2. Select the PostgreSQL data source created in 4.4.
3. Open the dashboard — KPI cards should immediately show the control totals.

---

## 5. Dashboard Guide

**Title:** Sales Performance · **Currency:** TND · **Time range:** native
Grafana time picker (default covers the full dataset).

### 5.1 Layout

| Section | Panels | Type |
| ------- | ------ | ---- |
| **KPI row** | Total Revenue · Total Orders · Average Order Value · MoM Growth | Stat cards |
| **Trend** | Monthly Revenue | Time series (full width) |
| **Breakdowns** | Revenue by Product Category · Revenue by Region | Bar charts |

### 5.2 Panels

| # | Panel | What it shows | Query logic |
| - | ----- | ------------- | ----------- |
| 1 | **Total Revenue** | Sum of `revenue` in TND | `COALESCE(SUM(revenue), 0)` with `$__timeFilter` |
| 2 | **Total Orders** | Number of orders | `COUNT(*)` on filtered rows |
| 3 | **Average Order Value** | Revenue ÷ orders, in TND | `SUM(revenue) / NULLIF(COUNT(*), 0)` |
| 4 | **MoM Growth** | Latest month's growth vs previous month, % | `LAG()` over monthly revenue; returns the most recent month's growth |
| 5 | **Monthly Revenue** | Revenue per month (line + fill) | `DATE_TRUNC('month', order_date)` grouped time series |
| 6 | **Revenue by Product Category** | Bar per category, value labels | `GROUP BY product_category ORDER BY SUM(revenue) DESC` |
| 7 | **Revenue by Region** | Bar per region, value labels | `GROUP BY region ORDER BY SUM(revenue) DESC` |

### 5.3 Filters

Two multi-select dashboard variables (with an **All** option) refresh on
dashboard load:

| Variable           | Label    | Query                                                        |
| ------------------ | -------- | ------------------------------------------------------------ |
| `region`           | Region   | `SELECT DISTINCT region FROM sales ORDER BY region;`         |
| `product_category` | Category | `SELECT DISTINCT product_category FROM sales ORDER BY product_category;` |

Every panel applies them, e.g.:

```sql
WHERE $__timeFilter(order_date)
  AND region IN (${region:sqlstring})
  AND product_category IN (${product_category:sqlstring});
```

> Note on the MoM panel: it uses `order_date <= $__timeTo()` instead of
> `$__timeFilter` so the "previous month" is always available even when the
> time picker starts mid-dataset.

### 5.4 Quick Sanity Check

With the full period selected and filters on **All**:

- Total Revenue = **5,109,775.74 TND**
- Total Orders = **5,000**
- AOV = **1,021.96 TND**
- Top region = **West** · Top category = **Electronics**

---

## 6. Testing & Documentation

| File | Content |
| ---- | ------- |
| `Data_Preparation.md` | Cleaning steps, validation checks, CSV → PostgreSQL loading |
| `SQL_Queries.md`      | All KPI/chart/validation queries with control totals |
| `Week4_Testing.md`    | Tests T01–T10 with queries, expected results, and PASS evidence, plus Grafana time-range and filter tests |

All SQL-level tests **T01–T10 pass** (record count, order-ID uniqueness,
revenue formula, AOV, monthly revenue, MoM growth, regional and category
totals, empty-period handling, and the invalid/NULL data sweep).

---

## 7. Project Structure
SALES-PERFORMANCE-DASHBOARD\ WEEK4
│   dashboard.png
│   README.md
│   
├───data
│       ecommerce_sales_analytics_5000.csv
│       sales_cleaned.csv
│       
├───documentation
│       Data_Preparation.md
│       SQL_Queries.md
│       Week4_Testing.md
│       
├───grafana
│       Sales Performance.json
│       
├───notebooks
│       sales.ipynb
│       
└───SQL
        sales_db and validation_queries.csv

---

## 8. Acceptance Summary

- ✅ Dataset validated (no missing values, duplicates, or revenue mismatches)
- ✅ Cleaned data loaded into PostgreSQL with control totals verified
- ✅ KPIs (revenue, orders, AOV) verified against dataset
- ✅ Monthly revenue and MoM growth (`LAG()`) verified
- ✅ Regional and category aggregations verified
- ✅ Empty periods handled without SQL errors
- ✅ Time picker and filter variables drive all panels dynamically
- ☐ Final runtime demo to supervisor (local Grafana session)
