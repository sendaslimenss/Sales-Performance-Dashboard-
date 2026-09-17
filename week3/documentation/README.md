# Week 3 – Advanced Grafana Dashboard

## Objective

The objective of Week 3 was to develop and improve an interactive Sales Performance Dashboard using Grafana and PostgreSQL.

## Dataset Limitation & Adaptation

The provided raw sales dataset does not contain a Product Name field. It only provides Product Category, with four available categories: Electronics, Clothing, Home, and Beauty.

Therefore, the "Top 5 Products" visualization specified in the original MVP could not be implemented without inventing or deriving unavailable product-level information.

To remain consistent with the available data, the visualization was replaced by **Revenue by Product Category**, allowing revenue performance to be compared across the four product categories provided by the dataset.

This adaptation ensures that all visualizations are based on actual available data and avoids introducing unsupported assumptions.
tree
## Work Completed

### 1. Interactive Filters

Added dashboard variables allowing users to filter the data by:

- Region
- Product Category
- Time range

The panels update according to the selected filters.

### 2. KPI Panels

Implemented four main Sales Performance KPIs:

- Total Revenue
- Total Orders
- Average Order Value
- Month-over-Month (MoM) Growth

### 3. Thresholds

Added basic threshold configurations to the KPI panels to provide visual indications according to the values.

### 4. Monthly Revenue Analysis

Created a time-series visualization showing the evolution of revenue over time.

### 5. Revenue by Product Category

Added a visualization comparing revenue across product categories.

### 6. Revenue by Region

Added a visualization comparing revenue across different regions.

### 7. Dashboard Design

Improved the dashboard layout and organization to provide:

- Clear KPI visibility
- Consistent panel organization
- Interactive filtering
- Easy comparison between categories and regions
- A consistent dark Grafana interface

## Technologies

- Grafana
- PostgreSQL
- SQL
- Grafana Dashboard Variables
- Grafana Thresholds

## Deliverables

The Grafana dashboard configuration is available in:

`../grafana/sales-performances-dash.json`

## Repository Structure

```text
week3/
├── documentation/
│   └── README.md
├── grafana/
│   └── sales-performances-dash.json
└── sql/