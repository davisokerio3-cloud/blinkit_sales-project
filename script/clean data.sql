--Part A: create the typed silver table

USE blinkit_db;
GO

DROP TABLE IF EXISTS silver.customers;
CREATE TABLE silver.customers (
    customer_id       BIGINT        NOT NULL PRIMARY KEY,
    customer_name     VARCHAR(100)  NOT NULL,
    email             VARCHAR(150),
    phone             VARCHAR(15),
    address           VARCHAR(500),
    area              VARCHAR(100),
    pincode           VARCHAR(6),
    registration_date DATE,
    customer_segment  VARCHAR(20),
    total_orders      INT,
    avg_order_value   DECIMAL(10,2)
);

--Part B: clean and load from bronze

INSERT INTO silver.customers
    (customer_id, customer_name, email, phone, address, area,
     pincode, registration_date, customer_segment, total_orders, avg_order_value)
SELECT
    TRY_CAST(customer_id AS BIGINT),
    TRIM(customer_name),
    LOWER(TRIM(email)),
    TRIM(phone),
    REPLACE(REPLACE(TRIM(address), CHAR(13), ''), CHAR(10), ', '),
    TRIM(area),
    TRIM(pincode),
    TRY_CAST(registration_date AS DATE),
    TRIM(customer_segment),
    TRY_CAST(total_orders AS INT),
    TRY_CAST(avg_order_value AS DECIMAL(10,2))
FROM bronze.customers;

--Part C: validate. Never trust a load until you’ve checked it.

-- 1. row count: expect 2500
SELECT COUNT(*) AS silver_rows FROM silver.customers;

-- 2. anti-join: bronze rows that did NOT make it to silver, expect 0
SELECT COUNT(*) AS lost_rows
FROM bronze.customers b
LEFT JOIN silver.customers s
       ON TRY_CAST(b.customer_id AS BIGINT) = s.customer_id
WHERE s.customer_id IS NULL;

-- 3. leftover trailing spaces in area, expect 0
SELECT COUNT(*) AS untrimmed_area
FROM silver.customers
WHERE DATALENGTH(area) <> DATALENGTH(LTRIM(RTRIM(area)));

-- 4. leftover line breaks in address, expect 0
SELECT COUNT(*) AS line_breaks_left
FROM silver.customers
WHERE address LIKE '%' + CHAR(10) + '%' OR address LIKE '%' + CHAR(13) + '%';

-- 5. confirm the data types
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'silver' AND TABLE_NAME = 'customers'
ORDER BY ORDINAL_POSITION;

-------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------
-- create silver product tables
DROP TABLE IF EXISTS silver.products;
CREATE TABLE silver.products (
    product_id        BIGINT        NOT NULL PRIMARY KEY,
    product_name      VARCHAR(100)  NOT NULL,
    category          VARCHAR(50)   NOT NULL,
    brand             VARCHAR(100),
    price             DECIMAL(10,2) NOT NULL,
    mrp               DECIMAL(10,2) NOT NULL,
    margin_percentage DECIMAL(5,2),
    shelf_life_days   INT,
    min_stock_level   INT,
    max_stock_level   INT,
    CONSTRAINT chk_products_price_mrp CHECK (price <= mrp),
    CONSTRAINT chk_products_stock     CHECK (min_stock_level < max_stock_level)
);

--loading the cleaned data into silver tables
INSERT INTO silver.products
    (product_id, product_name, category, brand, price, mrp,
     margin_percentage, shelf_life_days, min_stock_level, max_stock_level)
SELECT
    TRY_CAST(product_id AS BIGINT),
    TRIM(product_name),
    TRIM(category),
    TRIM(brand),
    TRY_CAST(price AS DECIMAL(10,2)),
    TRY_CAST(mrp AS DECIMAL(10,2)),
    TRY_CAST(margin_percentage AS DECIMAL(5,2)),
    TRY_CAST(shelf_life_days AS INT),
    TRY_CAST(min_stock_level AS INT),
    TRY_CAST(max_stock_level AS INT)
FROM bronze.products;

--validate the data to determine if it loaded correctly

-- rows in silver: expect 268
SELECT COUNT(*) AS silver_rows FROM silver.products;

-- bronze rows missing from silver: expect 0
SELECT COUNT(*) AS lost_rows
FROM bronze.products b
LEFT JOIN silver.products s ON TRY_CAST(b.product_id AS BIGINT) = s.product_id
WHERE s.product_id IS NULL;

-- check the types
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'silver' AND TABLE_NAME = 'products'
ORDER BY ORDINAL_POSITION;

------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------

--creating silve.orders

DROP TABLE IF EXISTS silver.orders;
CREATE TABLE silver.orders (
    order_id               BIGINT         NOT NULL PRIMARY KEY,
    customer_id            BIGINT         NOT NULL,
    order_date             DATETIME2(0)   NOT NULL,
    promised_delivery_time DATETIME2(0),
    actual_delivery_time   DATETIME2(0),
    delivery_status        VARCHAR(30),
    order_total            DECIMAL(10,2),
    payment_method         VARCHAR(20),
    delivery_partner_id    BIGINT,
    store_id               BIGINT,
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES silver.customers(customer_id)
);

---The new idea is the FOREIGN KEY. It tells SQL Server that every customer_id in orders must exist in customers. 
--If you ever try to insert an order for a customer that doesn’t exist, it’s rejected. 
--This is also why we load tables in parent-to-child order: customers had to be in silver before orders could be.

---loading it to silver layer

INSERT INTO silver.orders
    (order_id, customer_id, order_date, promised_delivery_time, actual_delivery_time,
     delivery_status, order_total, payment_method, delivery_partner_id, store_id)
SELECT
    TRY_CAST(order_id AS BIGINT),
    TRY_CAST(customer_id AS BIGINT),
    TRY_CAST(order_date AS DATETIME2(0)),
    TRY_CAST(promised_delivery_time AS DATETIME2(0)),
    TRY_CAST(actual_delivery_time AS DATETIME2(0)),
    TRIM(delivery_status),
    TRY_CAST(order_total AS DECIMAL(10,2)),
    TRIM(payment_method),
    TRY_CAST(delivery_partner_id AS BIGINT),
    TRY_CAST(store_id AS BIGINT)
FROM bronze.orders;

-- validating the data to ensure it loaded correctly

-- expect 5000
SELECT COUNT(*) AS silver_rows FROM silver.orders;

-- bronze rows that didn't reach silver: expect 0
SELECT COUNT(*) AS lost_rows
FROM bronze.orders b
LEFT JOIN silver.orders s ON TRY_CAST(b.order_id AS BIGINT) = s.order_id
WHERE s.order_id IS NULL;

-- totals must match between the two layers: both numbers should be identical
SELECT (SELECT SUM(TRY_CAST(order_total AS DECIMAL(12,2))) FROM bronze.orders) AS bronze_total,
       (SELECT SUM(order_total) FROM silver.orders)                            AS silver_total;

-- date range sanity check: expect 2023-03-16 to 2024-11-04
SELECT MIN(order_date) AS first_order, MAX(order_date) AS last_order FROM silver.orders;


--------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------

--loading orde_items

DROP TABLE IF EXISTS silver.order_items;
CREATE TABLE silver.order_items (
    order_id   BIGINT        NOT NULL,
    product_id BIGINT        NOT NULL,
    quantity   INT           NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    line_total AS (quantity * unit_price) PERSISTED,
    CONSTRAINT pk_order_items PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_oi_order    FOREIGN KEY (order_id)   REFERENCES silver.orders(order_id),
    CONSTRAINT fk_oi_product  FOREIGN KEY (product_id) REFERENCES silver.products(product_id),
    CONSTRAINT chk_oi_qty     CHECK (quantity > 0),
    CONSTRAINT chk_oi_price   CHECK (unit_price > 0)
);

-- loading the cleaned data
INSERT INTO silver.order_items (order_id, product_id, quantity, unit_price)
SELECT
    TRY_CAST(order_id   AS BIGINT),
    TRY_CAST(product_id AS BIGINT),
    TRY_CAST(quantity   AS INT),
    TRY_CAST(unit_price AS DECIMAL(10,2))
FROM bronze.order_items;

-- validating the loaded data todetermine if it has mistakes

-- expect 5000
SELECT COUNT(*) AS silver_rows FROM silver.order_items;

-- bronze rows that didn't reach silver: expect 0
SELECT COUNT(*) AS lost_rows
FROM bronze.order_items b
LEFT JOIN silver.order_items s
       ON TRY_CAST(b.order_id AS BIGINT)   = s.order_id
      AND TRY_CAST(b.product_id AS BIGINT) = s.product_id
WHERE s.order_id IS NULL;

-- control totals: each pair of numbers must be identical
SELECT (SELECT SUM(TRY_CAST(quantity   AS INT))            FROM bronze.order_items) AS bronze_qty,
       (SELECT SUM(quantity)                               FROM silver.order_items) AS silver_qty,
       (SELECT SUM(TRY_CAST(unit_price AS DECIMAL(12,2)))  FROM bronze.order_items) AS bronze_price,
       (SELECT SUM(unit_price)                             FROM silver.order_items) AS silver_price;

-----------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------

--create silver.delivery_performance

DROP TABLE IF EXISTS silver.delivery_performance;
CREATE TABLE silver.delivery_performance (
    order_id              BIGINT        NOT NULL PRIMARY KEY,
    delivery_partner_id   BIGINT,
    promised_time         DATETIME2(0),
    actual_time           DATETIME2(0),
    delivery_time_minutes DECIMAL(5,1),   -- actual minus promised: negative = early
    distance_km           DECIMAL(4,2),
    delivery_status       VARCHAR(30),
    reasons_if_delayed    VARCHAR(50),    -- NULL when no reason recorded
    CONSTRAINT fk_dp_order   FOREIGN KEY (order_id) REFERENCES silver.orders(order_id),
    CONSTRAINT chk_dp_km     CHECK (distance_km > 0) --Because order_id is both the primary key and a foreign key, SQL Server enforces the one-to-one rule: 
    --one delivery row per order, no more.
);

--loading deliver_performance into silver schema.

INSERT INTO silver.delivery_performance
    (order_id, delivery_partner_id, promised_time, actual_time,
     delivery_time_minutes, distance_km, delivery_status, reasons_if_delayed)
SELECT
    TRY_CAST(order_id AS BIGINT),
    TRY_CAST(delivery_partner_id AS BIGINT),
    TRY_CAST(promised_time AS DATETIME2(0)),
    TRY_CAST(actual_time AS DATETIME2(0)),
    TRY_CAST(delivery_time_minutes AS DECIMAL(5,1)),
    TRY_CAST(distance_km AS DECIMAL(4,2)),
    TRIM(delivery_status),
    NULLIF(TRIM(reasons_if_delayed), '')
FROM bronze.delivery_performance;

--validating the loaded data

-- expect 5000
SELECT COUNT(*) AS silver_rows FROM silver.delivery_performance;

-- lost rows: expect 0
SELECT COUNT(*) AS lost_rows
FROM bronze.delivery_performance b
LEFT JOIN silver.delivery_performance s ON TRY_CAST(b.order_id AS BIGINT) = s.order_id
WHERE s.order_id IS NULL;

-- reasons: expect 1902 NULLs and 0 blank strings left
SELECT
  SUM(CASE WHEN reasons_if_delayed IS NULL THEN 1 ELSE 0 END) AS null_reasons,
  SUM(CASE WHEN reasons_if_delayed = '' THEN 1 ELSE 0 END)    AS blank_reasons
FROM silver.delivery_performance;

-- control total: both numbers must be identical
SELECT (SELECT SUM(TRY_CAST(distance_km AS DECIMAL(10,2))) FROM bronze.delivery_performance) AS bronze_km,
       (SELECT SUM(distance_km) FROM silver.delivery_performance)                            AS silver_km;

       ----------------------------------------------------------------------------------------------------------------------------------------
       --------------------------------------------------------------------------------------------------------------------------------------
       --------------------------------------------------------------------------------------------------------------------------------------


       --create silver.customer_feedback

       DROP TABLE IF EXISTS silver.customer_feedback;
CREATE TABLE silver.customer_feedback (
    feedback_id       BIGINT       NOT NULL PRIMARY KEY,
    order_id          BIGINT       NOT NULL,
    customer_id       BIGINT       NOT NULL,
    rating            TINYINT      NOT NULL,
    feedback_text     VARCHAR(100),
    feedback_category VARCHAR(30),
    sentiment         VARCHAR(10),
    feedback_date     DATE,
    CONSTRAINT fk_fb_order    FOREIGN KEY (order_id)    REFERENCES silver.orders(order_id),
    CONSTRAINT fk_fb_customer FOREIGN KEY (customer_id) REFERENCES silver.customers(customer_id),
    CONSTRAINT chk_fb_rating  CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_fb_sent    CHECK (sentiment IN ('Positive', 'Neutral', 'Negative'))
);

--  loading it into the silver schema

INSERT INTO silver.customer_feedback
    (feedback_id, order_id, customer_id, rating,
     feedback_text, feedback_category, sentiment, feedback_date)
SELECT
    TRY_CAST(feedback_id AS BIGINT),
    TRY_CAST(order_id    AS BIGINT),
    TRY_CAST(customer_id AS BIGINT),
    TRY_CAST(rating      AS TINYINT),
    TRIM(feedback_text),
    TRIM(feedback_category),
    TRIM(sentiment),
    TRY_CAST(feedback_date AS DATE)
FROM bronze.customer_feedback;

--- validating the data to ensure it loaded correctly

-- expect 5000
SELECT COUNT(*) AS silver_rows FROM silver.customer_feedback;

-- lost rows: expect 0
SELECT COUNT(*) AS lost_rows
FROM bronze.customer_feedback b
LEFT JOIN silver.customer_feedback s ON TRY_CAST(b.feedback_id AS BIGINT) = s.feedback_id
WHERE s.feedback_id IS NULL;

-- control total: sum of all ratings, expect 16722 in both
SELECT (SELECT SUM(TRY_CAST(rating AS INT)) FROM bronze.customer_feedback) AS bronze_sum,
       (SELECT SUM(CAST(rating AS INT))     FROM silver.customer_feedback) AS silver_sum;

-- average rating: the first one has a trap, run both
SELECT AVG(rating)                      AS wrong_avg,
       AVG(CAST(rating AS DECIMAL(5,2))) AS right_avg
FROM silver.customer_feedback;

--------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------

--Step 3: create silver.inventory

DROP TABLE IF EXISTS silver.inventory;
CREATE TABLE silver.inventory (
    product_id     BIGINT NOT NULL,
    inventory_date DATE   NOT NULL,
    stock_received INT    NOT NULL,
    damaged_stock  INT    NOT NULL,
    CONSTRAINT pk_inventory PRIMARY KEY (product_id, inventory_date),
    CONSTRAINT fk_inv_product FOREIGN KEY (product_id) REFERENCES silver.products(product_id),
    CONSTRAINT chk_inv_received CHECK (stock_received >= 0),
    CONSTRAINT chk_inv_damaged  CHECK (damaged_stock  >= 0)
);

-- loading the table

INSERT INTO silver.inventory (product_id, inventory_date, stock_received, damaged_stock)
SELECT
    TRY_CAST(product_id AS BIGINT),
    TRY_CONVERT(DATE, [date], 105),
    TRY_CAST(stock_received AS INT),
    TRY_CAST(damaged_stock  AS INT)
FROM bronze.inventory;

-- validating the table

-- expect 75172
SELECT COUNT(*) AS silver_rows FROM silver.inventory;

-- lost rows: expect 0
SELECT COUNT(*) AS lost_rows
FROM bronze.inventory b
LEFT JOIN silver.inventory s
       ON TRY_CAST(b.product_id AS BIGINT) = s.product_id
      AND TRY_CONVERT(DATE, b.[date], 105) = s.inventory_date
WHERE s.product_id IS NULL;

-- control totals: each pair must match
SELECT (SELECT SUM(TRY_CAST(stock_received AS INT)) FROM bronze.inventory) AS bronze_received,
       (SELECT SUM(stock_received)                  FROM silver.inventory) AS silver_received,
       (SELECT SUM(TRY_CAST(damaged_stock AS INT))  FROM bronze.inventory) AS bronze_damaged,
       (SELECT SUM(damaged_stock)                   FROM silver.inventory) AS silver_damaged;

-- date check: a day-first date must have been read correctly. Expect 2023-03-17 and 2024-11-05
SELECT MIN(inventory_date) AS first_day, MAX(inventory_date) AS last_day FROM silver.inventory;

---------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------

--loading silver.inventory_new

DROP TABLE IF EXISTS silver.inventory_new;
CREATE TABLE silver.inventory_new (
    inventory_new_id INT IDENTITY(1,1) PRIMARY KEY,
    product_id       BIGINT NOT NULL,
    month_start      DATE   NOT NULL,   -- first day of the month, e.g. 2023-03-01
    stock_received   INT    NOT NULL,
    damaged_stock    INT    NOT NULL,
    CONSTRAINT fk_invnew_product FOREIGN KEY (product_id) REFERENCES silver.products(product_id),
    CONSTRAINT chk_invnew_received CHECK (stock_received >= 0),
    CONSTRAINT chk_invnew_damaged  CHECK (damaged_stock  >= 0)
);


--Step 4: load it, keeping one copy of each

WITH numbered AS (
    SELECT
        TRY_CAST(product_id AS BIGINT) AS product_id,
        TRY_CONVERT(DATE, '01 ' + LEFT([date], 3) + ' 20' + RIGHT([date], 2), 106) AS month_start,
        TRY_CAST(stock_received AS INT) AS stock_received,
        TRY_CAST(damaged_stock  AS INT) AS damaged_stock,
        ROW_NUMBER() OVER (
            PARTITION BY product_id, [date], stock_received, damaged_stock
            ORDER BY (SELECT NULL)
        ) AS copy_no
    FROM bronze.inventory_new
)
INSERT INTO silver.inventory_new (product_id, month_start, stock_received, damaged_stock)
SELECT product_id, month_start, stock_received, damaged_stock
FROM numbered
WHERE copy_no = 1;

-- The WITH numbered AS (...) part is a CTE: a named temporary result. We number the rows first, then keep only the first copy of each.

--validate

-- expect 10746
SELECT COUNT(*) AS silver_rows FROM silver.inventory_new;

-- row accounting: expect 7359 removed
SELECT (SELECT COUNT(*) FROM bronze.inventory_new) - (SELECT COUNT(*) FROM silver.inventory_new) AS rows_removed;

-- exact duplicates left: expect 0
SELECT COUNT(*) AS duplicate_groups_left
FROM (SELECT product_id, month_start, stock_received, damaged_stock
      FROM silver.inventory_new
      GROUP BY product_id, month_start, stock_received, damaged_stock
      HAVING COUNT(*) > 1) AS x;

-- control totals after dedup: expect received 18485, damaged 1022
SELECT SUM(stock_received) AS silver_received, SUM(damaged_stock) AS silver_damaged
FROM silver.inventory_new;

-- month range: expect 2023-03-01 to 2024-11-01
SELECT MIN(month_start) AS first_month, MAX(month_start) AS last_month FROM silver.inventory_new;

-----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------

-- loading silver.marketing_performance

DROP TABLE IF EXISTS silver.marketing_performance;
CREATE TABLE silver.marketing_performance (
    campaign_id       BIGINT        NOT NULL PRIMARY KEY,
    campaign_name     VARCHAR(50)   NOT NULL,
    campaign_date     DATE          NOT NULL,
    target_audience   VARCHAR(20),
    channel           VARCHAR(20),
    impressions       INT,
    clicks            INT,
    conversions       INT,
    spend             DECIMAL(12,2),
    revenue_generated DECIMAL(12,2),
    roas_reported     DECIMAL(4,2),
    roas_calculated   AS CAST(revenue_generated / NULLIF(spend, 0) AS DECIMAL(6,2)) PERSISTED,
    CONSTRAINT chk_mkt_funnel1 CHECK (clicks <= impressions),
    CONSTRAINT chk_mkt_funnel2 CHECK (conversions <= clicks),
    CONSTRAINT chk_mkt_spend   CHECK (spend > 0)
);
-- Notice NULLIF(spend, 0) again: if spend were ever 0, it becomes NULL and the division returns NULL instead of crashing with a divide-by-zero error. 
--We also renamed date to campaign_date and roas to roas_reported, so the names say exactly what they are.

--loading it
INSERT INTO silver.marketing_performance
    (campaign_id, campaign_name, campaign_date, target_audience, channel,
     impressions, clicks, conversions, spend, revenue_generated, roas_reported)
SELECT
    TRY_CAST(campaign_id AS BIGINT),
    TRIM(campaign_name),
    TRY_CONVERT(DATE, [date], 23),
    TRIM(target_audience),
    TRIM(channel),
    TRY_CAST(impressions AS INT),
    TRY_CAST(clicks AS INT),
    TRY_CAST(conversions AS INT),
    TRY_CAST(spend AS DECIMAL(12,2)),
    TRY_CAST(revenue_generated AS DECIMAL(12,2)),
    TRY_CAST(roas AS DECIMAL(4,2))
FROM bronze.marketing_performance;

-- validating

-- expect 5400
SELECT COUNT(*) AS silver_rows FROM silver.marketing_performance;

-- lost rows: expect 0
SELECT COUNT(*) AS lost_rows
FROM bronze.marketing_performance b
LEFT JOIN silver.marketing_performance s ON TRY_CAST(b.campaign_id AS BIGINT) = s.campaign_id
WHERE s.campaign_id IS NULL;

-- control totals: each pair must match
SELECT (SELECT SUM(TRY_CAST(spend AS DECIMAL(14,2)))             FROM bronze.marketing_performance) AS bronze_spend,
       (SELECT SUM(spend)                                         FROM silver.marketing_performance) AS silver_spend,
       (SELECT SUM(TRY_CAST(revenue_generated AS DECIMAL(14,2))) FROM bronze.marketing_performance) AS bronze_revenue,
       (SELECT SUM(revenue_generated)                             FROM silver.marketing_performance) AS silver_revenue;

-- bonus: three ways to get "overall ROAS", compare the results
SELECT AVG(roas_reported)                       AS average_of_reported,
       AVG(roas_calculated)                     AS average_of_calculated,
       SUM(revenue_generated) / SUM(spend)      AS overall_revenue_over_spend
FROM silver.marketing_performance;

