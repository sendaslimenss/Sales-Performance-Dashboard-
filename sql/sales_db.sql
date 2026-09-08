create table sales (
    order_id INT primary key ,
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
    revenue DECIMAL(10,2)
);
select * from  sales ;
create index idx_sales_order_date ON sales(order_date);
create index idx_sales_region      ON sales(region);
 validation queries (run manually to verify numbers)
-- ====================

-- Check row count & date range
select count(*) as total_rows,
       min(order_date) as min_date,
       max(order_date) as max_date,
       sum(revenue) as total_revenue
from sales;

-- Verify revenue formula
select order_id, quantity, unit_price, discount, revenue,
       ROUND(quantity * unit_price * (1 - discount), 2) as calc_revenue
from sales
limit 5;

-- Verify monthly totals (spot-check)
select DATE_TRUNC('month', order_date) as month,
       sum(revenue) as monthly_revenue
from sales
group by 1
order by  1;

--Validation / Sanity Check

select
    count(*)                                            AS total_rows,
    count(DISTINCT order_id)                            AS unique_orders,
    min(order_date)                                     AS min_date,
    max(order_date)                                     AS max_date,
    sum(case when revenue is null then 1 ELSE 0 END)  AS null_revenue,
    sum(case when order_date is null then  1 ELSE 0 END) AS null_dates,
    sum(case when abs(quantity * unit_price * (1 - discount) - revenue) > 0.01
             then 1 else 0 end)                        AS invalid_revenue
FROM sales;
