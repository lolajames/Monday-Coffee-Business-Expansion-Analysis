````markdown
# ☕ Monday Coffee — SQL Market Analysis



![SQL](https://img.shields.io/badge/SQL-PostgreSQL-336791?style=flat&logo=postgresql&logoColor=white)




![Status](https://img.shields.io/badge/Status-Completed-brightgreen)




![License](https://img.shields.io/badge/License-MIT-blue)



## 📌 Table of Contents

- [Problem Statement](#problem-statement)
- [Data Description](#data-description)
- [Methodology](#methodology)
- [SQL Concepts Used](#sql-concepts-used)
- [Results & Outputs](#results--outputs)
- [Key Insights & Recommendations](#key-insights--recommendations)
- [Limitations & Future Work](#limitations--future-work)

---

## Problem Statement

Monday Coffee is an online coffee brand that has been selling its products since January 2023. The company is now evaluating the expansion of its business by opening **physical coffee store locations** across India.

The goal of this analysis is to use **real sales, customer, and city data** to answer the following core business question:

> *Which three cities in India should Monday Coffee open its first physical stores in — and why?*

To answer this, I designed and executed **13 SQL queries** (10 guided + 3 original) that explore revenue performance, customer behavior, market potential, product popularity, rent efficiency, churn risk, and month-on-month growth across all cities in the dataset.

---

## Data Description

The dataset consists of **4 relational tables** stored in a PostgreSQL database:

### `city`
| Column | Type | Description |
|---|---|---|
| `city_id` | INT (PK) | Unique city identifier |
| `city_name` | VARCHAR | Name of the city |
| `population` | INT | Total city population |
| `estimated_rent` | INT | Average monthly rent estimate |
| `city_rank` | INT | City tier ranking |

### `customers`
| Column | Type | Description |
|---|---|---|
| `customer_id` | INT (PK) | Unique customer identifier |
| `customer_name` | VARCHAR | Name of the customer |
| `city_id` | INT (FK) | References `city(city_id)` |

### `products`
| Column | Type | Description |
|---|---|---|
| `product_id` | INT (PK) | Unique product identifier |
| `product_name` | VARCHAR | Name of the coffee product |
| `price` | INT | Product price |

### `sales`
| Column | Type | Description |
|---|---|---|
| `sale_id` | INT (PK) | Unique sale identifier |
| `sale_date` | DATE | Date of transaction |
| `product_id` | INT (FK) | References `products(product_id)` |
| `customer_id` | INT (FK) | References `customers(customer_id)` |
| `total` | DECIMAL | Sale amount |
| `rating` | SMALLINT | Customer satisfaction rating (1–5) |

**Entity Relationship:**
```
city (1) ──< customers (M) ──< sales (M) >── products (1)
```

---

## Methodology

Each question below is paired with its SQL solution and business rationale.

---

### Q1 — Coffee Consumer Estimate
**Business question:** Assuming 25% of each city's population drinks coffee, how many potential consumers exist per city?

```sql
SELECT 
    city_name,
    (population * 0.25) / 1000000 AS coffee_consumers_millions
FROM city
ORDER BY coffee_consumers_millions DESC;
```

---

### Q2 — Total Revenue: Q4 2023
**Business question:** What is the total revenue generated per city during October–December 2023?

```sql
SELECT
    c.city_name, 
    SUM(s.total) AS total_revenue
FROM city c
JOIN customers cust USING (city_id)
JOIN sales s USING (customer_id)
WHERE s.sale_date BETWEEN '2023-10-01' AND '2023-12-31'
GROUP BY c.city_id, c.city_name
ORDER BY total_revenue DESC;
```

---

### Q3 — Sales Volume by Product
**Business question:** How many units of each product have been sold? Rank from best to least.

```sql
SELECT 
    product_name,
    total_unit_sold,
    RANK() OVER (ORDER BY total_unit_sold DESC) AS sales_rank
FROM (
    SELECT
        p.product_name,
        p.product_id,
        COUNT(s.sale_id) AS total_unit_sold
    FROM products p
    JOIN sales s USING (product_id)
    GROUP BY p.product_id, p.product_name
) AS product_sales
ORDER BY sales_rank;
```

---

### Q4 — Average Sales per Customer by City
**Business question:** What is the average transaction value per unique customer in each city?

```sql
SELECT 
    city_name,
    SUM(customer_revenue)   AS total_revenue,
    COUNT(customer_id)      AS unique_customer_count,
    AVG(customer_revenue)   AS avg_sales_per_customer
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
GROUP BY city_id, city_name
ORDER BY total_revenue DESC;
```

---

### Q5 — Current Customers vs. Estimated Coffee Consumers
**Business question:** How does our actual customer reach compare to the estimated coffee-drinking population per city?

```sql
WITH city_estimates AS (
    SELECT
        city_name,
        ROUND((population * 0.25) / 1000000.0, 2) AS estimated_coffee_consumers_millions
    FROM city
),
actual_customers AS (
    SELECT
        ci.city_name,
        COUNT(DISTINCT cu.customer_id) AS actual_customers
    FROM customers cu
    JOIN city ci ON cu.city_id = ci.city_id
    JOIN sales s  ON cu.customer_id = s.customer_id
    GROUP BY ci.city_name
)
SELECT
    ce.city_name,
    ce.estimated_coffee_consumers_millions,
    ac.actual_customers
FROM city_estimates ce
JOIN actual_customers ac ON ce.city_name = ac.city_name
ORDER BY ce.estimated_coffee_consumers_millions DESC;
```

---

### Q6 — Top 3 Products per City
**Business question:** Which three products sell the most in each city?

```sql
SELECT city_name, product_name, total_orders, city_rank
FROM (
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
    JOIN city c         ON cust.city_id = c.city_id
    JOIN products p     ON s.product_id = p.product_id
    GROUP BY c.city_id, c.city_name, p.product_id, p.product_name
) AS ranked
WHERE city_rank <= 3
ORDER BY city_name, city_rank;
```

---

### Q7 — Unique Customers per City
**Business question:** How many unique paying customers does each city have?

```sql
SELECT 
    c.city_name,
    COUNT(DISTINCT s.customer_id) AS unique_customers
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c         ON cust.city_id = c.city_id
GROUP BY c.city_id, c.city_name
ORDER BY unique_customers DESC;
```

---

### Q8 — Average Sale vs. Average Rent per Customer
**Business question:** Is revenue per customer outpacing rent cost per customer?

```sql
SELECT 
    c.city_name,
    ROUND(AVG(s.total), 2)                                          AS avg_sale_per_customer,
    ROUND(c.estimated_rent / COUNT(DISTINCT s.customer_id), 2)     AS avg_rent_per_customer
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c         ON cust.city_id = c.city_id
GROUP BY c.city_id, c.city_name, c.estimated_rent
ORDER BY avg_sale_per_customer DESC;
```

---

### Q9 — Month-on-Month Sales Growth
**Business question:** Is sales momentum increasing or declining in each city over time?

```sql
SELECT
    city_name,
    month,
    total_sales,
    prev_month_sales,
    ROUND(
        (total_sales - prev_month_sales) / prev_month_sales * 100, 2
    ) AS mom_growth_pct
FROM (
    SELECT
        c.city_name,
        TO_CHAR(s.sale_date, 'YYYY-MM')  AS month,
        SUM(s.total)                      AS total_sales,
        LAG(SUM(s.total)) OVER (
            PARTITION BY c.city_id
            ORDER BY TO_CHAR(s.sale_date, 'YYYY-MM')
        )                                 AS prev_month_sales
    FROM sales s
    JOIN customers cust ON s.customer_id = cust.customer_id
    JOIN city c         ON cust.city_id = c.city_id
    GROUP BY c.city_id, c.city_name, TO_CHAR(s.sale_date, 'YYYY-MM')
) AS monthly_sales
WHERE prev_month_sales IS NOT NULL
ORDER BY city_name, month;
```

---

### Q10 — Full Market Potential Summary
**Business question:** What does the complete market picture look like for every city?

```sql
SELECT
    c.city_name,
    SUM(s.total)                                                AS total_revenue,
    c.estimated_rent,
    COUNT(DISTINCT s.customer_id)                               AS total_customers,
    ROUND(c.population * 0.25 / 1000000, 3)                   AS estimated_coffee_consumers_mln,
    ROUND(SUM(s.total) / COUNT(DISTINCT s.customer_id), 2)     AS avg_sale_per_customer,
    ROUND(c.estimated_rent / COUNT(DISTINCT s.customer_id), 2) AS avg_rent_per_customer
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c         ON cust.city_id = c.city_id
GROUP BY c.city_id, c.city_name, c.estimated_rent, c.population
ORDER BY total_revenue DESC;
```

---

### My Q1 — Revenue-to-Rent Ratio
**Business question:** Which cities generate the most revenue relative to their fixed rent cost?

```sql
SELECT
    c.city_name,
    SUM(s.total)                                    AS total_revenue,
    c.estimated_rent,
    ROUND(SUM(s.total) / c.estimated_rent, 2)      AS revenue_to_rent_ratio,
    RANK() OVER (
        ORDER BY SUM(s.total) / c.estimated_rent DESC
    )                                               AS efficiency_rank
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c         ON cust.city_id = c.city_id
GROUP BY c.city_id, c.city_name, c.estimated_rent
ORDER BY efficiency_rank;
```

> **Interpretation:** Cities with the highest ratio are the most cost-efficient locations and should be prioritized for expansion or increased investment.

---

### My Q2 — Churn Risk Customers
**Business question:** Which customers haven't purchased in over 3 months and may have stopped buying?

```sql
SELECT
    cust.customer_name,
    c.city_name,
    MAX(s.sale_date)  AS last_purchase_date,
    COUNT(s.sale_id)  AS total_orders
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c         ON cust.city_id = c.city_id
GROUP BY cust.customer_id, cust.customer_name, c.city_name
HAVING MAX(s.sale_date) < CURRENT_DATE - INTERVAL '3 months'
ORDER BY last_purchase_date ASC;
```

> **Interpretation:** Customers inactive for 3+ months are churn risks and should be targeted with re-engagement or loyalty incentives.

---

### My Q3 — Highest-Rated Product per City
**Business question:** Which product earns the best average customer rating in each city, revealing local taste preferences?

```sql
SELECT city_name, product_name, avg_rating, total_reviews, city_rank
FROM (
    SELECT
        c.city_name,
        p.product_name,
        ROUND(AVG(s.rating), 2)  AS avg_rating,
        COUNT(s.sale_id)         AS total_reviews,
        RANK() OVER (
            PARTITION BY c.city_id
            ORDER BY AVG(s.rating) DESC
        )                        AS city_rank
    FROM sales s
    JOIN customers cust ON s.customer_id = cust.customer_id
    JOIN city c         ON cust.city_id = c.city_id
    JOIN products p     ON s.product_id = p.product_id
    WHERE s.rating IS NOT NULL
    GROUP BY c.city_id, c.city_name, p.product_id, p.product_name
) AS ranked
WHERE city_rank = 1
ORDER BY avg_rating DESC;
```

> **Interpretation:** Top-rated products vary by city — Monday Coffee should consider city-specific featured menu items rather than a one-size-fits-all strategy.

---

## SQL Concepts Used

| Concept | Applied In |
|---|---|
| `JOIN` (INNER, multi-table) | Q2, Q4, Q6, Q7, Q8, Q9, Q10, My Q1–Q3 |
| `GROUP BY` + Aggregate Functions (`SUM`, `COUNT`, `AVG`, `ROUND`) | All queries |
| `WHERE` with date range filtering | Q2 |
| Subqueries (inline views) | Q3, Q4, Q6, Q9, My Q3 |
| CTEs (`WITH` clause) | Q5 |
| Window Functions (`RANK()`, `LAG()`) | Q3, Q6, Q9, My Q1, My Q3 |
| `PARTITION BY` | Q6, Q9, My Q3 |
| `HAVING` | My Q2 |
| `TO_CHAR()` for date formatting | Q9 |
| `INTERVAL` for date arithmetic | My Q2 |
| `CURRENT_DATE` | My Q2 |

---

## Results & Outputs

> 📸 *Replace the placeholders below with actual screenshots of your query outputs from your SQL client (e.g., pgAdmin, DBeaver, TablePlus).*

### Q1 — Coffee Consumer Estimate


![Q1 Output](screenshots/q1_coffee_consumers.png)



### Q2 — Total Revenue Q4 2023


![Q2 Output](screenshots/q2_q4_revenue.png)



### Q3 — Sales Volume by Product


![Q3 Output](screenshots/q3_product_sales.png)



### Q4 — Avg Sales per Customer by City


![Q4 Output](screenshots/q4_avg_sales.png)



### Q5 — Customers vs. Consumer Potential


![Q5 Output](screenshots/q5_cte_consumers.png)



### Q6 — Top 3 Products per City


![Q6 Output](screenshots/q6_top3_products.png)



### Q7 — Unique Customers per City


![Q7 Output](screenshots/q7_unique_customers.png)



### Q8 — Avg Sale vs. Avg Rent


![Q8 Output](screenshots/q8_sale_vs_rent.png)



### Q9 — Month-on-Month Growth


![Q9 Output](screenshots/q9_mom_growth.png)



### Q10 — Market Potential Summary


![Q10 Output](screenshots/q10_market_summary.png)



### My Q1 — Revenue-to-Rent Ratio


![My Q1 Output](screenshots/myq1_rent_ratio.png)



### My Q2 — Churn Risk Customers


![My Q2 Output](screenshots/myq2_churn.png)



### My Q3 — Top-Rated Product per City


![My Q3 Output](screenshots/myq3_ratings.png)



---

## Key Insights & Recommendations

### 🏆 Top 3 Recommended Cities for Physical Stores

---

#### 🥇 City #1 — Best Rent Efficiency + Proven Revenue
- **Primary evidence:** Highest `revenue_to_rent_ratio` (My Q1) + Top revenue in Q2 and Q10
- This city generates the most sales *relative to its rent cost*, making it the safest investment. Strong Q4 2023 performance confirms consistent, sustained demand — not a seasonal spike.
- **Recommendation:** Open the flagship store here first.

---

#### 🥈 City #2 — Largest Market + Greatest Untapped Potential
- **Primary evidence:** High `unique_customers` (Q7) + Wide gap between `estimated_coffee_consumers_millions` and `actual_customers` (Q5)
- This city has both a large existing customer base and a significant population of coffee drinkers not yet reached. A physical store with walk-in traffic can convert a meaningful share of that untapped market.
- **Recommendation:** Open the second store here to capture scale.

---

#### 🥉 City #3 — Highest Spend per Customer + Strong Product Satisfaction
- **Primary evidence:** Top `avg_sale_per_customer` (Q8/Q10) + Highest-rated product with strong review volume (My Q3)
- Customers here spend more per transaction and rate their products highly — a strong indicator of satisfaction and repeat loyalty. Even with moderate volume, the unit economics are excellent.
- **Recommendation:** Open the third store here to target a high-value customer segment.

---

### ⚠️ Cities to Avoid (Near-Term)
- Cities with **low revenue-to-rent ratios** (My Q1) — costs outweigh returns
- Cities with **many churn-risk customers** (My Q2) — signals weakening local demand
- Cities with **flat or negative MoM growth** (Q9) — declining momentum before committing to a lease

---

## Limitations & Future Work

### Limitations
- **No competitor data** — the analysis cannot account for existing coffee shops in each city, which significantly affects feasibility
- **Estimated rent is a single static value** — actual commercial real estate costs vary by neighborhood and store size
- **25% coffee consumer assumption is a flat rate** — it does not account for demographic differences across cities (e.g., age distribution, income level, urban density)
- **No foot traffic or location-level data** — revenue and customer counts reflect online sales behavior, which may not perfectly predict physical store performance
- **Rating data has nulls** — My Q3 filters out unrated sales, which could introduce bias toward products with fewer but highly satisfied reviewers

### Future Work
- **Incorporate competitor density data** to identify underserved markets
- **Segment customer analysis by demographics** (age, income bracket) for more targeted expansion planning
- **Run cohort retention analysis** to measure loyalty beyond simple churn flagging
- **Add geospatial analysis** to identify optimal neighborhoods *within* recommended cities
- **Forecast demand** using time-series modeling on the MoM growth data from Q9
- **A/B test re-engagement campaigns** on churn-risk customers identified in My Q2 before committing to physical locations

