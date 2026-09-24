# Data Preparation — Sales Performance Dashboard

## 1. Overview

This document describes the data preparation stage performed in **Python/Jupyter**
before the dataset is loaded into **PostgreSQL** and consumed by **Grafana**.

**Pipeline:**

```
ecommerce_sales_analytics_5000.csv
        ↓
Python / Pandas (Jupyter Notebook)
        ↓
Inspection & Validation
        ↓
Cleaning & Standardization
        ↓
Missing-Value / Duplicate Checks
        ↓
Revenue Validation
        ↓
Numeric Validation & Outlier Processing
        ↓
sales_cleaned.csv
        ↓
PostgreSQL
        ↓
SQL Analysis → Grafana Dashboard
```

**Source file:** `ecommerce_sales_analytics_5000.csv`
**Output file:** `sales_cleaned.csv`
**Notebook:** `notebooks/sales_cleaned_professional.ipynb`

---

## 2. Initial Data Inspection

The dataset was loaded with Pandas:

```python
import pandas as pd
sales = pd.read_csv("ecommerce_sales_analytics_5000.csv")
```

The initial inspection checked:

- Number of rows and dataset shape
- Column data types
- First and last records
- Missing values
- Fully duplicated rows
- Duplicate order IDs
- Descriptive statistics
- Categorical distributions
- Customer information
- Revenue calculation consistency
- Numeric-field validity

### 2.1 Initial Dataset Size

- **5,000 rows**
- 14 columns were visible during inspection because two **temporary validation
  columns** were present:
  - `order_date_parsed`
  - `calculated_revenue`
- These two columns are **not** part of the final exported dataset.

---

## 3. Data Cleaning Steps

### 3.1 Column Name Standardization

```python
sales.columns = (
    sales.columns
    .str.strip()
    .str.lower()
    .str.replace(" ", "_")
    .str.replace("-", "_")
)
```

This guarantees column names that are:

- Lowercase
- Free of leading/trailing whitespace
- Consistent
- Compatible with SQL/database naming conventions

### 3.2 Categorical Text Cleaning

**Whitespace removal:**

```python
for col in text_cols:
    sales[col] = sales[col].str.strip()
```

**Case standardization (title case):**

```python
for col in text_cols:
    sales[col] = sales[col].str.title()
```

Applied to categorical fields such as:

- `product_category`
- `region`
- `payment_method`

### 3.3 Data Type Conversion and Standardization

**Order date** — converted to datetime; invalid values become `NaT` so they can
be detected during validation:

```python
sales["order_date"] = pd.to_datetime(
    sales["order_date"],
    format="%m/%d/%Y",
    errors="coerce"
)
```

**Identifier columns** — explicitly converted to strings:

```python
sales["order_id"] = sales["order_id"].astype(str)
sales["customer_id"] = sales["customer_id"].astype(str)
```

**Whole-number numeric columns** — floating-point columns whose non-null values
are all whole numbers were converted to nullable integers.

---

## 4. Validation Checks

### 4.1 Missing Values

```python
missing = sales.isnull().sum()
```

- Missing values in notebook: **0**
- Missing values in final CSV: **0**

### 4.2 Duplicates

| Check                         | Method                                   | Result |
| ----------------------------- | ---------------------------------------- | ------ |
| Fully duplicated rows         | `sales.duplicated().sum()`               | 0      |
| Duplicate order IDs           | `sales["order_id"].duplicated().sum()`   | 0      |

No duplicate rows and no duplicate order IDs exist in the prepared dataset.

### 4.3 Revenue Validation

The stored `revenue` field was validated against the business formula:

```
Revenue = Quantity × Unit Price × (1 − Discount)
```

```python
expected_revenue = (
    sales["quantity"] * sales["unit_price"] * (1 - sales["discount"])
).round(2)
```

- **Tolerance:** 0.01 (revenue is stored with two decimal places)
- **Revenue mismatches: 0**

The temporary `calculated_revenue` column was used for validation only and was
**not** exported.

### 4.4 Numeric Field Validation (Business Rules)

| Field            | Rule                                   | Status |
| ---------------- | -------------------------------------- | ------ |
| `quantity`       | `> 0`                                  | PASS   |
| `unit_price`     | `> 0`                                  | PASS   |
| `discount`       | between `0` and `1`                    | PASS   |
| `customer_rating`| between `1` and `5`                    | PASS   |
| `delivery_days`  | `>= 0`                                 | PASS   |

### 4.5 Outlier Detection and Removal (IQR Method)

```python
def remove_outliers_iqr(sales, column, factor=1.5):
    Q1 = sales[column].quantile(0.25)
    Q3 = sales[column].quantile(0.75)
    IQR = Q3 - Q1
    lower = Q1 - factor * IQR
    upper = Q3 + factor * IQR
    return sales[
        (sales[column] >= lower) &
        (sales[column] <= upper)
    ]
```

Applied to: `quantity`, `unit_price`, `discount`, `customer_rating`, `delivery_days`.

**Result — no rows were removed by IQR filtering:**

| Stage           | Rows  |
| --------------- | ----: |
| Before cleaning | 5,000 |
| After cleaning  | 5,000 |

---

## 5. Final Data Quality Summary

| Validation                | Result |
| ------------------------- | ------ |
| Rows before cleaning      | 5,000  |
| Rows after cleaning       | 5,000  |
| Missing revenue           | 0      |
| Missing product category  | 0      |
| Duplicate orders          | 0      |
| Invalid dates             | 0      |
| Invalid quantities        | 0      |
| Invalid unit prices       | 0      |
| Revenue mismatches        | 0      |
| Unique regions            | 4      |

**Regions found:** South, East, West, North

---

## 6. Final Cleaned Dataset

Exported with:

```python
sales.to_csv("sales_cleaned.csv", index=False)
```

- **5,000 rows × 12 columns**

### Final Columns

| Column             | Description              |
| ------------------ | ------------------------ |
| `order_id`         | Unique order identifier  |
| `order_date`       | Date of the order        |
| `customer_id`      | Customer identifier      |
| `product_category` | Product category         |
| `region`           | Sales region             |
| `quantity`         | Quantity purchased       |
| `unit_price`       | Unit price               |
| `discount`         | Discount applied         |
| `payment_method`   | Payment method           |
| `delivery_days`    | Delivery duration        |
| `customer_rating`  | Customer rating          |
| `revenue`          | Calculated sales revenue |

> The temporary validation columns (`order_date_parsed`, `calculated_revenue`)
> are **not** present in the final CSV.

### 6.1 Distribution by Product Category

| Product Category | Rows  |
| ---------------- | ----: |
| Electronics      | 1,777 |
| Clothing         | 1,531 |
| Home             |   969 |
| Beauty           |   723 |

### 6.2 Distribution by Region

| Region | Rows  |
| ------ | ----: |
| West   | 1,289 |
| North  | 1,276 |
| East   | 1,227 |
| South  | 1,208 |

---

## 7. CSV → PostgreSQL Loading

The cleaned CSV is loaded into a PostgreSQL table named `sales`.

### 7.1 Table Schema

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

**Key design decisions:**

- `order_id` is the **primary key** — duplicate order IDs cannot be inserted.
- `order_date` and `customer_id` are **NOT NULL**.
- Monetary fields use `NUMERIC` to preserve two-decimal precision.

### 7.2 Indexes

Created to support the filtering and grouping used by the dashboard:

```sql
CREATE INDEX idx_sales_order_date ON sales(order_date);
CREATE INDEX idx_sales_region     ON sales(region);
```

### 7.3 Loading the CSV

The CSV can be loaded with the PostgreSQL `COPY` command:

```sql
COPY sales FROM '/path/to/sales_cleaned.csv'
DELIMITER ',' CSV HEADER;
```

(Alternatively, use the `\copy` meta-command from psql, or the import tool in
pgAdmin.)

### 7.4 Post-Load Verification

After loading, run the control-total query to confirm the load was complete
(see `Week4_Testing.md`, Test T01):

- Total rows = **5,000**
- Unique orders = **5,000**
- Total revenue = **5,109,775.74**

---

## 8. Known Data Limitation

The original MVP specification includes a **Top 5 Products** requirement.
However, the source dataset contains **no `product_name` or `product_id`
field** — only `product_category`.

Therefore, a genuine Top 5 Products analysis **cannot be calculated** without
inventing product-level information. The MVP uses **Revenue by Product
Category** as the available product-level breakdown instead. This is a
**documented data limitation**; no artificial product information was
introduced.

---

## 9. Relation to the Dashboard

The prepared dataset is the foundation for the PostgreSQL and Grafana stages.
The cleaned fields feed:

- Total Revenue
- Total Orders
- Average Order Value
- Monthly Revenue
- Revenue by Product Category
- Revenue by Region
- Month-over-Month Growth

The preparation stage therefore guarantees that the data entering PostgreSQL
and Grafana has been inspected, standardized, and validated before analysis.
