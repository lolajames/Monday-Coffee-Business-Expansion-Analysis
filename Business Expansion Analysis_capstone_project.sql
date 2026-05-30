CREATE TABLE city(
      city_id INT PRIMARY KEY,
	  city_name VARCHAR(100),
	  population INT ,
	  estimated_rent INT ,
	  city_rank INT
);
select* from city

CREATE TABLE customers(
      customer_id INT PRIMARY KEY,
	  customer_name VARCHAR(100),
	  city_id INT REFERENCES city(city_id)
);
select* from customers

CREATE TABLE products(
         product_id INT PRIMARY KEY,
		 product_name  VARCHAR(100),
		 price  INT
		 
);
select* from products

CREATE TABLE sales(
      sale_id INT PRIMARY KEY,
	  sale_date DATE,
	  product_id INT REFERENCES products(product_id),
	  customer_id INT REFERENCES customers(customer_id),
	  total DECIMAL(10,2),
	  rating SMALLINT
);
select* from sales

-- -- =======================================================================
--        SQL Questions
-- 	   ================================================================

-- Question 1: Coffee Consumer Estimate
-- Assuming 25% of each city's population drinks coffee, calculate the estimated number of coffee 
-- consumers (in millions) per city. Order results from highest to lowest.
SELECT 
    city_name,
    (population * 0.25) / 1000000 AS coffee_consumers_millions
FROM 
    city
ORDER BY 
    coffee_consumers_millions DESC;

-- Question 2: Total Revenue - Q4 2023
-- What is the total revenue generated from coffee sales across all cities during the last quarter of 
-- 2023 (October-December)? Show results per city, ordered by revenue descending
SELECT
     c.city_name, 
     sum(s.total) as total_revenue
from city c
join customers cust using (city_id)
join sales  s using (customer_id )
where s.sale_date BETWEEN '2023-10-01' and '2023-12-31'
group by  c.city_id, c.city_name
order by total_revenue desc;

-- Question 3: Sales Volume by Product
-- How many units of each coffee product have been sold in total? Rank products from best-selling 
-- to least-selling.

SELECT product_name,
       total_unit_sold,
	   RANK() OVER (ORDER BY total_unit_sold DESC) AS sales_rank
from
(select
  p. product_name,product_id, count(s.sale_id) as total_unit_sold
 from  products p
 join  sales s using (product_id)
 Group by p.product_id,
          p.product_name) as product_sales
 order by
        sales_rank ;

-- Question 4: Average Sales per Customer by City
-- What is the average total sales amount per unique customer in each city? Include total revenue 
-- and customer count alongside the average. Order by total revenue descending.

SELECT 
    city_name,
    SUM(customer_revenue) AS total_revenue,
    COUNT(customer_id) AS unique_customer_count,
    AVG(customer_revenue) AS avg_sales_per_customer
FROM (
    SELECT 
        c.city_id,
        c.city_name,
        cust.customer_id,
        SUM(s.total) AS customer_revenue
    FROM city c
    JOIN customers cust USING (city_id)
    JOIN sales s USING (customer_id)
    GROUP BY c.city_id, c.city_name, cust.customer_id
) AS customer_sales_totals
GROUP BY 
    city_id,
    city_name
ORDER BY 
    total_revenue DESC;

-- Question 5: Current Customers vs. Estimated Coffee Consumers
-- For each city, show both the estimated coffee-drinking population (25% of city population, in 
-- millions) and the actual number of unique customers from the sales data. Use a CTE.

WITH city_estimates AS (
    -- CTE: estimated coffee consumers per city
    SELECT
        city_name,
        ROUND((population * 0.25) / 1000000.0, 2) AS estimated_coffee_consumers_millions
    FROM city
),
actual_customers AS (
    -- CTE: actual unique customers per city from sales
    SELECT
        ci.city_name,
        COUNT(DISTINCT cu.customer_id) AS actual_customers
    FROM customers cu
    JOIN city ci ON cu.city_id = ci.city_id
    JOIN sales s ON cu.customer_id = s.customer_id
    GROUP BY ci.city_name
)
SELECT
    ce.city_name,
    ce.estimated_coffee_consumers_millions,
    ac.actual_customers
FROM city_estimates ce
JOIN actual_customers ac ON ce.city_name = ac.city_name
ORDER BY ce.estimated_coffee_consumers_millions DESC;

-- Question 6: Top 3 Products per City
-- What are the top 3 best-selling coffee products in each city, based on number of orders? Use a 
-- window function to rank products within each city.
SELECT 
    city_name,
    product_name,
    total_orders,
    city_rank
FROM (
    -- Subquery: rank products within each city
    SELECT 
        c.city_name,
        p.product_name,
        COUNT(s.sale_id) AS total_orders,
        RANK() OVER (
            PARTITION BY c.city_id 
            ORDER BY COUNT(s.sale_id) DESC
        ) AS city_rank
    FROM sales s
    JOIN customers cust ON s.customer_id = cust.customer_id
    JOIN city c      ON cust.city_id = c.city_id
    JOIN products p   ON s.product_id = p.product_id
    GROUP BY c.city_id, c.city_name, p.product_id, p.product_name
) AS ranked
WHERE city_rank <= 3
ORDER BY city_name, city_rank;

-- Question 7: Unique Customers per City
-- How many unique customers in each city have made at least one coffee purchase? Order by 
-- customer count descending.


SELECT 
    c.city_name,
    COUNT(DISTINCT s.customer_id) AS unique_customers
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c      ON cust.city_id = c.city_id
GROUP BY c.city_id, c.city_name
ORDER BY unique_customers DESC;

-- Question 8: Average Sale vs. Average Rent per Customer
-- For each city, compare the average sale amount per customer against the average rent cost per 
-- customer (estimated_rent divided by number of customers). This helps evaluate cost efficiency.

SELECT 
    c.city_name,
    ROUND(AVG(s.total), 2)                          AS avg_sale_per_customer,
    ROUND(c.estimated_rent / COUNT(DISTINCT s.customer_id), 2) AS avg_rent_per_customer
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c      ON cust.city_id = c.city_id
GROUP BY c.city_id, c.city_name, c.estimated_rent
ORDER BY avg_sale_per_customer DESC;

-- Question 9: Month-on-Month Sales Growth
-- Calculate the month-on-month percentage change in total sales for each city. Use a window 
-- function (LAG) to compare each month's sales to the previous month. Show only rows where a 
-- prior month exists. 

SELECT
    city_name,
    month,
    total_sales,
    prev_month_sales,
    ROUND(
        (total_sales - prev_month_sales) / prev_month_sales * 100, 2
    ) AS mom_growth_pct
FROM (
    -- Subquery: aggregate monthly sales + LAG for previous month
    SELECT
        c.city_name,
        TO_CHAR(s.sale_date, 'YYYY-MM')         AS month,
        SUM(s.total)                             AS total_sales,
        LAG(SUM(s.total)) OVER (
            PARTITION BY c.city_id
            ORDER BY TO_CHAR(s.sale_date, 'YYYY-MM')
        )                                        AS prev_month_sales
    FROM sales s
    JOIN customers cust ON s.customer_id = cust.customer_id
    JOIN city c      ON cust.city_id = c.city_id
    GROUP BY c.city_id, c.city_name, TO_CHAR(s.sale_date, 'YYYY-MM')
) AS monthly_sales
WHERE prev_month_sales IS NOT NULL        -- excludes first month (no prior month exists)
ORDER BY city_name, month;


--   Question 10: Market Potential Summary
-- Produce a full market potential table for each city, showing: total revenue, estimated rent, total 
-- customers, estimated coffee consumers (millions), average sale per customer, and average rent 
-- per customer. Order by total revenue descending

SELECT
    c.city_name,
    SUM(s.total)                                            AS total_revenue,
    c.estimated_rent,
    COUNT(DISTINCT s.customer_id)                           AS total_customers,
    ROUND(c.population * 0.25 / 1000000, 3)               AS estimated_coffee_consumers_mln,
    ROUND(SUM(s.total) / COUNT(DISTINCT s.customer_id), 2)  AS avg_sale_per_customer,
    ROUND(c.estimated_rent / COUNT(DISTINCT s.customer_id), 2) AS avg_rent_per_customer
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c      ON cust.city_id = c.city_id
GROUP BY c.city_id, c.city_name, c.estimated_rent, c.population
ORDER BY total_revenue DESC;

-- ==============================================================================================
--                            MY QUESTIONS
-- ==============================================================================================

-- Q1: Which cities have the highest revenue-to-rent ratio?
-- Business question: Which cities generate the most revenue relative to their rent cost — i.e. where is Monday Coffee getting the best return on its fixed costs?

SELECT
    c.city_name,
    SUM(s.total)                                   AS total_revenue,
    c.estimated_rent,
    ROUND(SUM(s.total) / c.estimated_rent, 2)     AS revenue_to_rent_ratio,
    RANK() OVER (
        ORDER BY SUM(s.total) / c.estimated_rent DESC
    )                                              AS efficiency_rank
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c      ON cust.city_id = c.city_id
GROUP BY c.city_id, c.city_name, c.estimated_rent
ORDER BY efficiency_rank;


-- Interpretation: Cities with the highest ratio are Monday Coffee's most cost-efficient locations and should be prioritized for expansion or increased investment.



--  Q2: Which customers are at risk of churning?
-- Business question: Which customers made purchases early in the dataset but have had no orders in the last 3 months — suggesting they may have stopped buying?

SELECT
    cust.customer_name,
    c.city_name,
    MAX(s.sale_date)            AS last_purchase_date,
    COUNT(s.sale_id)            AS total_orders
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c      ON cust.city_id = c.city_id
GROUP BY cust.customer_id, cust.customer_name, c.city_name
HAVING MAX(s.sale_date) < CURRENT_DATE - INTERVAL '3 months'
ORDER BY last_purchase_date ASC;


-- Interpretation: Customers who haven't purchased in over 3 months are churn risks and should be targeted with re-engagement offers or loyalty incentives.



--  Q3: Which product has the highest average rating per city?
-- Business question: Which coffee product consistently receives the best customer ratings in each city — revealing local taste preferences Monday Coffee can use to tailor its menu?


SELECT
    city_name,
    product_name,
    avg_rating,
    total_reviews,
    city_rank
FROM (
    SELECT
        c.city_name,
        p.product_name,
        ROUND(AVG(s.rating), 2)      AS avg_rating,
        COUNT(s.sale_id)             AS total_reviews,
        RANK() OVER (
            PARTITION BY c.city_id
            ORDER BY AVG(s.rating) DESC
        )                            AS city_rank
    FROM sales s
    JOIN customers cust ON s.customer_id =cust.customer_id
    JOIN city c      ON cust.city_id = c.city_id
    JOIN products p   ON s.product_id = p.product_id
    WHERE s.rating IS NOT NULL
    GROUP BY c.city_id, c.city_name, p.product_id, p.product_name
) AS ranked
WHERE city_rank = 1
ORDER BY avg_rating DESC;


-- Interpretation: The top-rated product varies by city, meaning Monday Coffee should consider city-specific featured items rather than a one-size-fits-all menu strategy.