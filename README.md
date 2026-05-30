# Monday Coffee — SQL Market Analysis



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


### Q1 — Coffee Consumer Estimate


<img width="152" height="182" alt="image" src="https://github.com/user-attachments/assets/45e16e65-64f9-47bb-af3b-e7dcd30e9f1f" />



### Q2 — Total Revenue Q4 2023


<img width="143" height="188" alt="image" src="https://github.com/user-attachments/assets/9c1c43da-5e2c-4c6a-8642-dd13023234ed" />



### Q3 — Sales Volume by Product


<img width="181" height="158" alt="image" src="https://github.com/user-attachments/assets/0bbe134f-55d2-4524-a5af-0a12668f980d" />
<img width="188" height="191" alt="image" src="https://github.com/user-attachments/assets/00534442-d1b5-4ba6-9a93-15619e4285ae" />


### Q4 — Avg Sales per Customer by City


<img width="260" height="188" alt="image" src="https://github.com/user-attachments/assets/d4feacc7-3683-4184-9f67-f912a230b5ac" />



### Q5 —  Current Customers vs. Estimated Coffee Consumers


<img width="239" height="191" alt="image" src="https://github.com/user-attachments/assets/8ec24c07-6841-4e81-8b6f-803a772326a5" />



### Q6 — Top 3 Products per City


<img width="239" height="182" alt="image" src="https://github.com/user-attachments/assets/a22bdbba-1b4a-4afe-817c-4c2940993673" />
<img width="262" height="191" alt="image" src="https://github.com/user-attachments/assets/f7c3b29d-17de-4170-b78a-c89e8e9391f0" />
<img width="269" height="188" alt="image" src="https://github.com/user-attachments/assets/df7ab7c4-69cf-4288-aa1b-7c83428e911e" />
<img width="234" height="31" alt="image" src="https://github.com/user-attachments/assets/f037a148-e3ad-4a44-97f2-fb3a78e5042b" />


### Q7 — Unique Customers per City


<img width="159" height="187" alt="image" src="https://github.com/user-attachments/assets/dda2fbc0-e102-4a77-ae23-06e0a1029388" />



### Q8 — Avg Sale vs. Avg Rent


<img width="227" height="188" alt="image" src="https://github.com/user-attachments/assets/fb2e4271-2425-4ab8-97fa-b99c2f4a4b89" />



### Q9 — Month-on-Month Growth


<img width="256" height="192" alt="image" src="https://github.com/user-attachments/assets/96f12705-7895-4044-9123-06dd907dd893" />
<img width="248" height="185" alt="image" src="https://github.com/user-attachments/assets/cb9f0ad8-acf0-44f6-89d8-fbb252837cb7" />
<img width="263" height="197" alt="image" src="https://github.com/user-attachments/assets/4c622f10-77f9-4fbf-bda6-c5af694e249a" />
<img width="251" height="197" alt="image" src="https://github.com/user-attachments/assets/e3d66def-9b87-48ce-99cb-a70ff351ffbf" />
<img width="254" height="194" alt="image" src="https://github.com/user-attachments/assets/c9b840fa-4f40-4385-9234-0dba234eaf9e" />
<img width="271" height="193" alt="image" src="https://github.com/user-attachments/assets/bed70085-242b-4292-be6d-26867a56dd53" />
<img width="292" height="197" alt="image" src="https://github.com/user-attachments/assets/8028b222-2600-44e7-8715-cdbc8163920b" />
<img width="254" height="196" alt="image" src="https://github.com/user-attachments/assets/2d4dd9f7-4e87-41a4-b164-c7ac6f04162b" />
<img width="250" height="197" alt="image" src="https://github.com/user-attachments/assets/990f3032-aea2-4a49-9191-82da4930f233" />
<img width="248" height="195" alt="image" src="https://github.com/user-attachments/assets/600cb38f-ee3d-477c-9c4d-c7add6c56ac4" />
<img width="264" height="198" alt="image" src="https://github.com/user-attachments/assets/101e2f6d-4b7d-4b1b-a144-08b3e2bcde03" />
<img width="245" height="197" alt="image" src="https://github.com/user-attachments/assets/c8e51017-2cae-477e-bdc5-55374ad6a266" />
<img width="239" height="196" alt="image" src="https://github.com/user-attachments/assets/adf50221-b8d1-4d34-8013-e5cf76cccad1" />
<img width="285" height="473" alt="image" src="https://github.com/user-attachments/assets/d113344b-82a7-47c1-a3da-ed14cc2849f3" />
<img width="320" height="470" alt="image" src="https://github.com/user-attachments/assets/0a696add-a78a-4af9-93c3-fca35efa9965" />
<img width="256" height="173" alt="image" src="https://github.com/user-attachments/assets/ab44fa81-ea39-43aa-b890-ca5bb215ba80" />



### Q10 — Market Potential Summary


<img width="455" height="196" alt="image" src="https://github.com/user-attachments/assets/c6634012-b641-46f4-9907-64a57d0b49cc" />



### My Q1 — Revenue-to-Rent Ratio


<img width="305" height="197" alt="image" src="https://github.com/user-attachments/assets/547b012b-a934-4d44-8bc0-328a583e7d45" />



### My Q2 — Churn Risk Customers


<img width="290" height="476" alt="image" src="https://github.com/user-attachments/assets/059a71f7-3635-4aca-8a23-42a2fcb6c440" />
<img width="323" height="479" alt="image" src="https://github.com/user-attachments/assets/3d0c9a77-bd68-4954-980e-522f2f678ed0" />
<img width="302" height="475" alt="image" src="https://github.com/user-attachments/assets/d85a8d7a-6e77-4c4e-afa4-eb1a63e516e1" />
<img width="317" height="470" alt="image" src="https://github.com/user-attachments/assets/c4407568-f927-4f04-9be9-21bd5b96d432" />
<img width="244" height="431" alt="image" src="https://github.com/user-attachments/assets/daf6ebf2-bbae-4373-8c1c-688195ccf655" />
<img width="255" height="436" alt="image" src="https://github.com/user-attachments/assets/b1729dbd-4dd7-45f0-b6ff-cad78fc3a410" />
<img width="240" height="437" alt="image" src="https://github.com/user-attachments/assets/fef1ebca-fd18-4274-bf8c-cf45d64b5113" />
<img width="261" height="430" alt="image" src="https://github.com/user-attachments/assets/16ce8830-7516-4421-8e83-175c78c043a0" />
<img width="255" height="438" alt="image" src="https://github.com/user-attachments/assets/9877aacb-689f-4134-996e-4883611761dd" />
<img width="250" height="436" alt="image" src="https://github.com/user-attachments/assets/e6a5b1b6-50fe-4f74-b6e4-558553e80a90" />
<img width="248" height="436" alt="image" src="https://github.com/user-attachments/assets/1011687b-9c6b-4a9e-b06a-56f8cae86d73" />
<img width="266" height="436" alt="image" src="https://github.com/user-attachments/assets/fc98ceee-a7a8-4726-8a6f-0a3704519876" />
<img width="260" height="434" alt="image" src="https://github.com/user-attachments/assets/9fb55e19-1129-4aa3-9e55-81d6bdeab48d" />
<img width="260" height="94" alt="image" src="https://github.com/user-attachments/assets/5773613e-0fea-4eab-988c-220e9d31c07e" />



### My Q3 — Top-Rated Product per City


<img width="320" height="274" alt="image" src="https://github.com/user-attachments/assets/13248790-673d-4141-a9a6-7269c74de992" />



---

## Key Insights & Recommendations

### Top 3 Recommended Cities for Physical Stores

---

#### City #1 — Best Rent Efficiency + Proven Revenue
- **Primary evidence:** Highest `revenue_to_rent_ratio` (My Q1) + Top revenue in Q2 and Q10
- This city generates the most sales *relative to its rent cost*, making it the safest investment. Strong Q4 2023 performance confirms consistent, sustained demand — not a seasonal spike.
- **Recommendation:** Open the flagship store here first.

---

#### City #2 — Largest Market + Greatest Untapped Potential
- **Primary evidence:** High `unique_customers` (Q7) + Wide gap between `estimated_coffee_consumers_millions` and `actual_customers` (Q5)
- This city has both a large existing customer base and a significant population of coffee drinkers not yet reached. A physical store with walk-in traffic can convert a meaningful share of that untapped market.
- **Recommendation:** Open the second store here to capture scale.

---

#### City #3 — Highest Spend per Customer + Strong Product Satisfaction
- **Primary evidence:** Top `avg_sale_per_customer` (Q8/Q10) + Highest-rated product with strong review volume (My Q3)
- Customers here spend more per transaction and rate their products highly — a strong indicator of satisfaction and repeat loyalty. Even with moderate volume, the unit economics are excellent.
- **Recommendation:** Open the third store here to target a high-value customer segment.

---

### Cities to Avoid (Near-Term)
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
