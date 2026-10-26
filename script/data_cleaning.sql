USE blinkit_db

SELECT *

FROM bronze.customers

SELECT TOP 10 * FROM bronze.customers;

--2. Duplicates in the key. If customer_id isn’t unique, joins will multiply rows later.
--COUNT(*) counts every row, while COUNT(DISTINCT ...) counts unique values. 
--If the two numbers match, the column is safe as a primary key

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT customer_id) AS distinct_ids
FROM bronze.customers;

-- checking for duplicates
-- GROUP BY + HAVING: HAVING filters after grouping, which is why it works here and WHERE wouldn’t.
SELECT email, COUNT(*) AS cnt
FROM bronze.customers
GROUP BY email
HAVING COUNT(*) > 1;

-- Blanks and NULLs. A blank string '' is not a NULL, so a good check tests for both.

SELECT
  SUM(CASE WHEN customer_name IS NULL OR LTRIM(RTRIM(customer_name)) = '' THEN 1 ELSE 0 END) AS blank_name,
  SUM(CASE WHEN email         IS NULL OR LTRIM(RTRIM(email))         = '' THEN 1 ELSE 0 END) AS blank_email,
  SUM(CASE WHEN address       IS NULL OR LTRIM(RTRIM(address))       = '' THEN 1 ELSE 0 END) AS blank_address,
  SUM(CASE WHEN area          IS NULL OR LTRIM(RTRIM(area))          = '' THEN 1 ELSE 0 END) AS blank_area
FROM bronze.customers;

--Hidden spaces
--This one has a SQL Server trap: 'Khora ' = 'Khora' returns TRUE, 
--because SQL Server ignores trailing spaces when comparing, and LEN() ignores them too. 
--So we compare DATALENGTH, which counts the real bytes

SELECT area, LEN(area) AS len_shown,
DATALENGTH(area) AS real_bytes
FROM bronze.customers
WHERE DATALENGTH(area) <> DATALENGTH(LTRIM(RTRIM(area)));

--Will the text convert to proper types? TRY_CAST returns NULL when a conversion fails,
--instead of crashing the whole query like CAST does.

SELECT
  SUM(CASE WHEN TRY_CAST(customer_id        AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_id,
  SUM(CASE WHEN TRY_CAST(registration_date  AS DATE)          IS NULL THEN 1 ELSE 0 END) AS bad_date,
  SUM(CASE WHEN TRY_CAST(total_orders       AS INT)           IS NULL THEN 1 ELSE 0 END) AS bad_orders,
  SUM(CASE WHEN TRY_CAST(avg_order_value    AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS bad_aov,
  SUM(CASE WHEN TRY_CAST(pincode            AS INT)           IS NULL THEN 1 ELSE 0 END) AS bad_pincode
FROM bronze.customers;
-------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-- bronze.products

--USE blinkit_db;
GO

-- 1. Key check: expect 268 and 268
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT product_id) AS distinct_ids
FROM bronze.products;

-- 2. Will it convert? expect all zeros
SELECT
  SUM(CASE WHEN TRY_CAST(product_id        AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_id,
  SUM(CASE WHEN TRY_CAST(price             AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS bad_price,
  SUM(CASE WHEN TRY_CAST(mrp               AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS bad_mrp,
  SUM(CASE WHEN TRY_CAST(margin_percentage AS DECIMAL(5,2))  IS NULL THEN 1 ELSE 0 END) AS bad_margin,
  SUM(CASE WHEN TRY_CAST(shelf_life_days   AS INT)           IS NULL THEN 1 ELSE 0 END) AS bad_shelf,
  SUM(CASE WHEN TRY_CAST(min_stock_level   AS INT)           IS NULL THEN 1 ELSE 0 END) AS bad_min,
  SUM(CASE WHEN TRY_CAST(max_stock_level   AS INT)           IS NULL THEN 1 ELSE 0 END) AS bad_max
FROM bronze.products;

-- 3. Hidden spaces in text columns: expect zeros
SELECT
  SUM(CASE WHEN DATALENGTH(product_name) <> DATALENGTH(LTRIM(RTRIM(product_name))) THEN 1 ELSE 0 END) AS sp_name,
  SUM(CASE WHEN DATALENGTH(category)     <> DATALENGTH(LTRIM(RTRIM(category)))     THEN 1 ELSE 0 END) AS sp_category,
  SUM(CASE WHEN DATALENGTH(brand)        <> DATALENGTH(LTRIM(RTRIM(brand)))        THEN 1 ELSE 0 END) AS sp_brand
FROM bronze.products;

-- 4. Business rules: expect zeros
SELECT
  SUM(CASE WHEN TRY_CAST(price AS DECIMAL(10,2)) > TRY_CAST(mrp AS DECIMAL(10,2)) THEN 1 ELSE 0 END) AS price_above_mrp,
  SUM(CASE WHEN TRY_CAST(min_stock_level AS INT) >= TRY_CAST(max_stock_level AS INT) THEN 1 ELSE 0 END) AS min_not_below_max,
  SUM(CASE WHEN TRY_CAST(price AS DECIMAL(10,2)) <= 0 THEN 1 ELSE 0 END) AS price_not_positive
FROM bronze.products;

-- 5. Does margin_percentage agree with (mrp - price) / mrp ? expect 0 mismatches
SELECT COUNT(*) AS margin_mismatches
FROM bronze.products
WHERE ABS( (TRY_CAST(mrp AS DECIMAL(10,2)) - TRY_CAST(price AS DECIMAL(10,2)))
           / TRY_CAST(mrp AS DECIMAL(10,2)) * 100
           - TRY_CAST(margin_percentage AS DECIMAL(5,2)) ) > 0.5;

-- 6. Categories: expect 11
SELECT category, COUNT(*) AS products
FROM bronze.products
GROUP BY category
ORDER BY products DESC;



----------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--  cleaning the orders table

select*
from bronze.orders

USE blinkit_db;
GO

-- 1. Key check: expect 5000 and 5000
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS distinct_ids
FROM bronze.orders;

-- 2. Will everything convert? expect all zeros
SELECT
  SUM(CASE WHEN TRY_CAST(order_id               AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_order_id,
  SUM(CASE WHEN TRY_CAST(customer_id            AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_customer_id,
  SUM(CASE WHEN TRY_CAST(order_date             AS DATETIME2(0))  IS NULL THEN 1 ELSE 0 END) AS bad_order_date,
  SUM(CASE WHEN TRY_CAST(promised_delivery_time AS DATETIME2(0))  IS NULL THEN 1 ELSE 0 END) AS bad_promised,
  SUM(CASE WHEN TRY_CAST(actual_delivery_time   AS DATETIME2(0))  IS NULL THEN 1 ELSE 0 END) AS bad_actual,
  SUM(CASE WHEN TRY_CAST(order_total            AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS bad_total,
  SUM(CASE WHEN TRY_CAST(delivery_partner_id    AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_partner,
  SUM(CASE WHEN TRY_CAST(store_id               AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_store
FROM bronze.orders;

-- 3. Date logic: a delivery can't be promised or made before the order. Expect 0 and 0
SELECT
  SUM(CASE WHEN TRY_CAST(promised_delivery_time AS DATETIME2(0)) < TRY_CAST(order_date AS DATETIME2(0)) THEN 1 ELSE 0 END) AS promised_before_order,
  SUM(CASE WHEN TRY_CAST(actual_delivery_time   AS DATETIME2(0)) < TRY_CAST(order_date AS DATETIME2(0)) THEN 1 ELSE 0 END) AS delivered_before_order
FROM bronze.orders;

-- 4. Does delivery_status agree with the actual minutes late?
SELECT delivery_status,
       MIN(DATEDIFF(MINUTE, TRY_CAST(promised_delivery_time AS DATETIME2(0)),
                            TRY_CAST(actual_delivery_time   AS DATETIME2(0)))) AS min_minutes_late,
       MAX(DATEDIFF(MINUTE, TRY_CAST(promised_delivery_time AS DATETIME2(0)),
                            TRY_CAST(actual_delivery_time   AS DATETIME2(0)))) AS max_minutes_late,
       COUNT(*) AS orders
FROM bronze.orders
GROUP BY delivery_status;

-- 5. Orphans: orders whose customer doesn't exist in silver. Expect 0
SELECT COUNT(*) AS orphan_orders
FROM bronze.orders o
LEFT JOIN silver.customers c ON TRY_CAST(o.customer_id AS BIGINT) = c.customer_id
WHERE c.customer_id IS NULL;

-- 6. The reverse: customers who never ordered
SELECT COUNT(*) AS customers_without_orders
FROM silver.customers c
LEFT JOIN bronze.orders o ON c.customer_id = TRY_CAST(o.customer_id AS BIGINT)
WHERE o.order_id IS NULL;

-- 7. Category values
SELECT payment_method, COUNT(*) AS orders 
FROM bronze.orders 
GROUP BY payment_method 
ORDER BY orders DESC;

----------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------

--cleaning bronze_order

--cleaning bronze.order_items

-- 1. Rows vs unique (order, product) pairs: expect 5000 and 5000
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT CONCAT(order_id, '-', product_id)) AS distinct_pairs
FROM bronze.order_items;

-- 2. Will it convert? expect all zeros
SELECT
  SUM(CASE WHEN TRY_CAST(order_id   AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_order_id,
  SUM(CASE WHEN TRY_CAST(product_id AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_product_id,
  SUM(CASE WHEN TRY_CAST(quantity   AS INT)           IS NULL THEN 1 ELSE 0 END) AS bad_quantity,
  SUM(CASE WHEN TRY_CAST(unit_price AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS bad_price
FROM bronze.order_items;

-- 3. Value ranges: expect quantity 1 to 3, price 12.32 to 995.98
SELECT MIN(TRY_CAST(quantity AS INT))           AS min_qty,   
    MAX(TRY_CAST(quantity AS INT))           AS max_qty,
       MIN(TRY_CAST(unit_price AS DECIMAL(10,2))) AS min_price,
       MAX(TRY_CAST(unit_price AS DECIMAL(10,2))) AS max_price
FROM bronze.order_items;

-- 4a. Items whose order doesn't exist: expect 0
SELECT COUNT(*) AS orphan_items_no_order
FROM bronze.order_items i
LEFT JOIN silver.orders o ON TRY_CAST(i.order_id AS BIGINT) = o.order_id
WHERE o.order_id IS NULL;

-- 4b. Items whose product doesn't exist: expect 0
SELECT COUNT(*) AS orphan_items_no_product
FROM bronze.order_items i
LEFT JOIN silver.products p ON TRY_CAST(i.product_id AS BIGINT) = p.product_id
WHERE p.product_id IS NULL;

-- 4c. Orders with no items at all: expect 0
SELECT COUNT(*) AS orders_without_items
FROM silver.orders o
LEFT JOIN bronze.order_items i ON o.order_id = TRY_CAST(i.order_id AS BIGINT)
WHERE i.order_id IS NULL;

-- 5. Does unit_price equal the product's catalog price? expect 0 mismatches
SELECT COUNT(*) AS price_mismatches
FROM bronze.order_items i
INNER JOIN silver.products p ON TRY_CAST(i.product_id AS BIGINT) = p.product_id
WHERE TRY_CAST(i.unit_price AS DECIMAL(10,2)) <> p.price;

-- 6a. Look at it yourself: order_total vs what the items add up to
SELECT TOP 10 o.order_id, o.order_total,
       TRY_CAST(i.quantity AS INT) * TRY_CAST(i.unit_price AS DECIMAL(10,2)) AS items_total
FROM silver.orders o
INNER JOIN bronze.order_items i ON o.order_id = TRY_CAST(i.order_id AS BIGINT);

-- 6b. How many orders have order_total equal to the items total?
SELECT COUNT(*) AS totals_that_match
FROM silver.orders o
INNER JOIN bronze.order_items i ON o.order_id = TRY_CAST(i.order_id AS BIGINT)
WHERE ABS(o.order_total - TRY_CAST(i.quantity AS INT) * TRY_CAST(i.unit_price AS DECIMAL(10,2))) < 0.01;

----------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------

--cleaning bronze.delivery_performance

USE blinkit_db;
GO

-- 1. Key check: expect 5000 and 5000
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS distinct_orders
FROM bronze.delivery_performance;

-- 2. Will it convert? expect all zeros
SELECT
  SUM(CASE WHEN TRY_CAST(order_id              AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_order_id,
  SUM(CASE WHEN TRY_CAST(delivery_partner_id   AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_partner,
  SUM(CASE WHEN TRY_CAST(promised_time         AS DATETIME2(0))  IS NULL THEN 1 ELSE 0 END) AS bad_promised,
  SUM(CASE WHEN TRY_CAST(actual_time           AS DATETIME2(0))  IS NULL THEN 1 ELSE 0 END) AS bad_actual,
  SUM(CASE WHEN TRY_CAST(delivery_time_minutes AS DECIMAL(5,1))  IS NULL THEN 1 ELSE 0 END) AS bad_minutes,
  SUM(CASE WHEN TRY_CAST(distance_km           AS DECIMAL(4,2))  IS NULL THEN 1 ELSE 0 END) AS bad_km
FROM bronze.delivery_performance;

-- 3. Real NULLs vs blank strings in reasons_if_delayed
SELECT
  SUM(CASE WHEN reasons_if_delayed IS NULL THEN 1 ELSE 0 END) AS true_nulls,
  SUM(CASE WHEN reasons_if_delayed IS NOT NULL AND LTRIM(RTRIM(reasons_if_delayed)) = '' THEN 1 ELSE 0 END) AS blank_strings
FROM bronze.delivery_performance;

-- 4. Reasons by delivery status
SELECT delivery_status, 
ISNULL(NULLIF(LTRIM(RTRIM(reasons_if_delayed)), ''), '(none)') AS reason,
COUNT(*) AS deliveries
FROM bronze.delivery_performance
GROUP BY delivery_status, 
ISNULL(NULLIF(LTRIM(RTRIM(reasons_if_delayed)), ''), '(none)')
ORDER BY delivery_status, reason;

-- 5. Does it repeat what's already in orders? expect all zeros
SELECT
  SUM(CASE WHEN TRY_CAST(d.delivery_partner_id AS BIGINT)       <> o.delivery_partner_id   THEN 1 ELSE 0 END) AS partner_differs,
  SUM(CASE WHEN TRY_CAST(d.promised_time AS DATETIME2(0))       <> o.promised_delivery_time THEN 1 ELSE 0 END) AS promised_differs,
  SUM(CASE WHEN TRY_CAST(d.actual_time   AS DATETIME2(0))       <> o.actual_delivery_time   THEN 1 ELSE 0 END) AS actual_differs,
  SUM(CASE WHEN TRIM(d.delivery_status)                         <> o.delivery_status        THEN 1 ELSE 0 END) AS status_differs
FROM bronze.delivery_performance d
INNER JOIN silver.orders o ON TRY_CAST(d.order_id AS BIGINT) = o.order_id;

-- 6. What does delivery_time_minutes really measure? expect 0 mismatches
SELECT COUNT(*) AS minutes_mismatch
FROM bronze.delivery_performance
WHERE ABS( TRY_CAST(delivery_time_minutes AS DECIMAL(5,1))
         - DATEDIFF(MINUTE, TRY_CAST(promised_time AS DATETIME2(0)),
                            TRY_CAST(actual_time   AS DATETIME2(0))) ) > 0.5;

-- 7. Orphans in both directions: expect 0 and 0
SELECT
 (SELECT COUNT(*) FROM bronze.delivery_performance d
  LEFT JOIN silver.orders o ON TRY_CAST(d.order_id AS BIGINT) = o.order_id
  WHERE o.order_id IS NULL) AS deliveries_without_order,
 (SELECT COUNT(*) FROM silver.orders o
  LEFT JOIN bronze.delivery_performance d ON o.order_id = TRY_CAST(d.order_id AS BIGINT)
  WHERE d.order_id IS NULL) AS orders_without_delivery;

-- 8. Ranges: expect minutes -5 to 30, distance 0.50 to 5.00
SELECT MIN(TRY_CAST(delivery_time_minutes AS DECIMAL(5,1))) AS min_minutes, 
        MAX(TRY_CAST(delivery_time_minutes AS DECIMAL(5,1))) AS max_minutes,
       MIN(TRY_CAST(distance_km AS DECIMAL(4,2))) AS min_km,              
       MAX(TRY_CAST(distance_km AS DECIMAL(4,2))) AS max_km
FROM bronze.delivery_performance;
------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------

-- cleaning bronze.customer_feedback

USE blinkit_db;
GO

-- 1. Keys: expect 5000, 5000, 5000
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT feedback_id) AS distinct_feedback,
       COUNT(DISTINCT order_id)    AS distinct_orders
FROM bronze.customer_feedback;

-- 2. Will it convert? expect all zeros
SELECT
  SUM(CASE WHEN TRY_CAST(feedback_id   AS BIGINT) IS NULL THEN 1 ELSE 0 END) AS bad_feedback_id,
  SUM(CASE WHEN TRY_CAST(order_id      AS BIGINT) IS NULL THEN 1 ELSE 0 END) AS bad_order_id,
  SUM(CASE WHEN TRY_CAST(customer_id   AS BIGINT) IS NULL THEN 1 ELSE 0 END) AS bad_customer_id,
  SUM(CASE WHEN TRY_CAST(rating        AS INT)    IS NULL THEN 1 ELSE 0 END) AS bad_rating,
  SUM(CASE WHEN TRY_CAST(feedback_date AS DATE)   IS NULL THEN 1 ELSE 0 END) AS bad_date
FROM bronze.customer_feedback;

-- 3. Blank or untrimmed text: expect all zeros
SELECT
  SUM(CASE WHEN LTRIM(RTRIM(feedback_text))     = '' OR DATALENGTH(feedback_text)     <> DATALENGTH(LTRIM(RTRIM(feedback_text)))     THEN 1 ELSE 0 END) AS bad_text,
  SUM(CASE WHEN LTRIM(RTRIM(feedback_category)) = '' OR DATALENGTH(feedback_category) <> DATALENGTH(LTRIM(RTRIM(feedback_category))) THEN 1 ELSE 0 END) AS bad_category,
  SUM(CASE WHEN LTRIM(RTRIM(sentiment))         = '' OR DATALENGTH(sentiment)         <> DATALENGTH(LTRIM(RTRIM(sentiment)))         THEN 1 ELSE 0 END) AS bad_sentiment
FROM bronze.customer_feedback;

-- 4. Rating distribution: expect 1:540, 2:538, 3:1398, 4:1708, 5:816
SELECT rating, COUNT(*) AS feedbacks
FROM bronze.customer_feedback
GROUP BY rating
ORDER BY rating;

-- 5. Do rating and sentiment agree?
SELECT rating, sentiment, COUNT(*) AS feedbacks
FROM bronze.customer_feedback
GROUP BY rating, sentiment
ORDER BY rating, sentiment;

-- 6. The text column: how many different comments exist?
SELECT feedback_text, COUNT(*) AS times_used
FROM bronze.customer_feedback
GROUP BY feedback_text
ORDER BY times_used DESC;

-- 7. Categories and sentiments
SELECT feedback_category, COUNT(*) AS feedbacks
FROM bronze.customer_feedback
GROUP BY feedback_category
ORDER BY feedbacks DESC;

-- 8. Links: expect 0, 0, 0
SELECT
 (SELECT COUNT(*) FROM bronze.customer_feedback f
  LEFT JOIN silver.orders o ON TRY_CAST(f.order_id AS BIGINT) = o.order_id
  WHERE o.order_id IS NULL) AS feedback_without_order,
 (SELECT COUNT(*) FROM bronze.customer_feedback f
  LEFT JOIN silver.customers c ON TRY_CAST(f.customer_id AS BIGINT) = c.customer_id
  WHERE c.customer_id IS NULL) AS feedback_without_customer,
 (SELECT COUNT(*) FROM silver.orders o
  LEFT JOIN bronze.customer_feedback f ON o.order_id = TRY_CAST(f.order_id AS BIGINT)
  WHERE f.order_id IS NULL) AS orders_without_feedback;

-- 9. Is the customer on the feedback the same as the customer on the order? expect 0
SELECT COUNT(*) AS customer_mismatch
FROM bronze.customer_feedback f
INNER JOIN silver.orders o ON TRY_CAST(f.order_id AS BIGINT) = o.order_id
WHERE TRY_CAST(f.customer_id AS BIGINT) <> o.customer_id;

-- 10. How many days after the order was the feedback given?
SELECT DATEDIFF(DAY, CAST(o.order_date AS DATE), TRY_CAST(f.feedback_date AS DATE)) AS days_after_order,
       COUNT(*) AS feedbacks
FROM bronze.customer_feedback f
INNER JOIN silver.orders o ON TRY_CAST(f.order_id AS BIGINT) = o.order_id
GROUP BY DATEDIFF(DAY, CAST(o.order_date AS DATE), TRY_CAST(f.feedback_date AS DATE))
ORDER BY days_after_order;
----------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------

--- cleaning bronze.inventory

-- 1. Rows vs unique (product, date) pairs: expect 75172 and 75172
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT CONCAT(product_id, '|', [date])) AS distinct_pairs
FROM bronze.inventory;

-- 2. Will it convert (with the explicit date format)? expect all zeros
SELECT
  SUM(CASE WHEN TRY_CAST(product_id     AS BIGINT)       IS NULL THEN 1 ELSE 0 END) AS bad_product_id,
  SUM(CASE WHEN TRY_CONVERT(DATE, [date], 105)           IS NULL THEN 1 ELSE 0 END) AS bad_date,
  SUM(CASE WHEN TRY_CAST(stock_received AS INT)          IS NULL THEN 1 ELSE 0 END) AS bad_received,
  SUM(CASE WHEN TRY_CAST(damaged_stock  AS INT)          IS NULL THEN 1 ELSE 0 END) AS bad_damaged
FROM bronze.inventory;

-- 3. Date range: expect 2023-03-17 to 2024-11-05, with 600 distinct days
SELECT MIN(TRY_CONVERT(DATE, [date], 105)) AS first_day,
       MAX(TRY_CONVERT(DATE, [date], 105)) AS last_day,
       COUNT(DISTINCT TRY_CONVERT(DATE, [date], 105)) AS distinct_days
FROM bronze.inventory;

-- 4. Value ranges: expect received 0 to 4, damaged 0 to 2, no negatives
SELECT MIN(TRY_CAST(stock_received AS INT)) AS min_received, 
MAX(TRY_CAST(stock_received AS INT)) AS max_received,
       MIN(TRY_CAST(damaged_stock  AS INT)) AS min_damaged,  
       MAX(TRY_CAST(damaged_stock  AS INT)) AS max_damaged
FROM bronze.inventory;

-- 5. Logic check: damaged more than received?
SELECT COUNT(*) AS damaged_more_than_received,
       CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM bronze.inventory) AS DECIMAL(5,1)) AS pct_of_rows
FROM bronze.inventory
WHERE TRY_CAST(damaged_stock AS INT) > TRY_CAST(stock_received AS INT);

-- 6. Links: expect 0 and 0
SELECT
 (SELECT COUNT(*) FROM bronze.inventory i
  LEFT JOIN silver.products p ON TRY_CAST(i.product_id AS BIGINT) = p.product_id
  WHERE p.product_id IS NULL) AS inventory_without_product,
 (SELECT COUNT(*) FROM silver.products p
  LEFT JOIN bronze.inventory i ON p.product_id = TRY_CAST(i.product_id AS BIGINT)
  WHERE i.product_id IS NULL) AS products_without_inventory;

-- 7. Coverage: how many days of records does each product have?
SELECT MIN(days) AS fewest_days, 
MAX(days) AS most_days
FROM (
    SELECT product_id, COUNT(*) AS days
    FROM bronze.inventory
    GROUP BY product_id
) AS per_product;
---------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------


-- cleaning inentory_new

USE blinkit_db;
GO

-- 1. Total rows vs distinct rows: expect 18105 and 10746
SELECT COUNT(*) AS total_rows,
       (SELECT COUNT(*) FROM (SELECT DISTINCT product_id, [date], stock_received, damaged_stock
                              FROM bronze.inventory_new) AS d) AS distinct_rows
FROM bronze.inventory_new;

-- 2. Will it convert? expect all zeros. The 'date' is a month label like 'Mar-23'
SELECT
  SUM(CASE WHEN TRY_CAST(product_id AS BIGINT) IS NULL THEN 1 ELSE 0 END) AS bad_product_id,
  SUM(CASE WHEN TRY_CONVERT(DATE, '01 ' + LEFT([date], 3) + ' 20' + RIGHT([date], 2), 106) IS NULL THEN 1 ELSE 0 END) AS bad_month,
  SUM(CASE WHEN TRY_CAST(stock_received AS INT) IS NULL THEN 1 ELSE 0 END) AS bad_received,
  SUM(CASE WHEN TRY_CAST(damaged_stock  AS INT) IS NULL THEN 1 ELSE 0 END) AS bad_damaged
FROM bronze.inventory_new;

-- 3. Ranges: expect received 1 to 4, damaged 0 to 7
SELECT MIN(TRY_CAST(stock_received AS INT)) AS min_received, 
MAX(TRY_CAST(stock_received AS INT)) AS max_received,
       MIN(TRY_CAST(damaged_stock  AS INT)) AS min_damaged,  
       MAX(TRY_CAST(damaged_stock  AS INT)) AS max_damaged,
       COUNT(DISTINCT [date]) AS distinct_months
FROM bronze.inventory_new;

-- 4. How many copies do the duplicated rows have? (expect 2:3946, 3:864, 4:399, 5:92, 6:24)
SELECT copies, COUNT(*) AS duplicate_groups
FROM (
    SELECT product_id, [date], stock_received, damaged_stock, COUNT(*) AS copies
    FROM bronze.inventory_new
    GROUP BY product_id, [date], stock_received, damaged_stock
    HAVING COUNT(*) > 1
) AS g
GROUP BY copies
ORDER BY copies;

-- 5. After removing exact duplicates, is (product, month) unique? expect 4040 keys with several rows
SELECT COUNT(*) AS keys_with_several_rows
FROM (
    SELECT product_id, [date]
    FROM (SELECT DISTINCT product_id, [date], stock_received, damaged_stock
          FROM bronze.inventory_new) AS d
    GROUP BY product_id, [date]
    HAVING COUNT(*) > 1
) AS k;

-- 6. Links to products: expect 0 and 0
SELECT
 (SELECT COUNT(*) FROM bronze.inventory_new i
  LEFT JOIN silver.products p ON TRY_CAST(i.product_id AS BIGINT) = p.product_id
  WHERE p.product_id IS NULL) AS rows_without_product,
 (SELECT COUNT(*) FROM silver.products p
  LEFT JOIN bronze.inventory_new i ON p.product_id = TRY_CAST(i.product_id AS BIGINT)
  WHERE i.product_id IS NULL) AS products_without_rows;

-- 7. Does it agree with the daily inventory table?
SELECT (SELECT SUM(received) FROM (SELECT SUM(stock_received) AS received FROM silver.inventory) a) AS daily_received,
       (SELECT SUM(damaged_stock) FROM silver.inventory)                                            AS daily_damaged,
       (SELECT SUM(TRY_CAST(stock_received AS INT)) FROM bronze.inventory_new)                      AS new_received,
 (SELECT SUM(TRY_CAST(damaged_stock  AS INT)) FROM bronze.inventory_new)                      AS new_damaged;
 ---------------------------------------------------------------------------------------------------------------------------
 -------------------------------------------------------------------------------------------------------------------------
 ------------------------------------------------------------------------------------------------------------------------


 -- cleaning marketing_performance

 USE blinkit_db;
GO

-- 1. Keys: expect 5400, 5400 and 9 campaign names
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT campaign_id)   AS distinct_ids,
       COUNT(DISTINCT campaign_name) AS distinct_names
FROM bronze.marketing_performance;

-- 2. Will it convert? expect all zeros (date style 23 = yyyy-mm-dd)
SELECT
  SUM(CASE WHEN TRY_CAST(campaign_id        AS BIGINT)        IS NULL THEN 1 ELSE 0 END) AS bad_id,
  SUM(CASE WHEN TRY_CONVERT(DATE, [date], 23)                 IS NULL THEN 1 ELSE 0 END) AS bad_date,
  SUM(CASE WHEN TRY_CAST(impressions        AS INT)           IS NULL THEN 1 ELSE 0 END) AS bad_impressions,
  SUM(CASE WHEN TRY_CAST(clicks             AS INT)           IS NULL THEN 1 ELSE 0 END) AS bad_clicks,
  SUM(CASE WHEN TRY_CAST(conversions        AS INT)           IS NULL THEN 1 ELSE 0 END) AS bad_conversions,
  SUM(CASE WHEN TRY_CAST(spend              AS DECIMAL(12,2)) IS NULL THEN 1 ELSE 0 END) AS bad_spend,
  SUM(CASE WHEN TRY_CAST(revenue_generated  AS DECIMAL(12,2)) IS NULL THEN 1 ELSE 0 END) AS bad_revenue,
  SUM(CASE WHEN TRY_CAST(roas               AS DECIMAL(4,2))  IS NULL THEN 1 ELSE 0 END) AS bad_roas
FROM bronze.marketing_performance;

-- 3. Blank or untrimmed text: expect zeros
SELECT
  SUM(CASE WHEN LTRIM(RTRIM(campaign_name))   = '' OR DATALENGTH(campaign_name)   <> DATALENGTH(LTRIM(RTRIM(campaign_name)))   THEN 1 ELSE 0 END) AS bad_name,
  SUM(CASE WHEN LTRIM(RTRIM(target_audience)) = '' OR DATALENGTH(target_audience) <> DATALENGTH(LTRIM(RTRIM(target_audience))) THEN 1 ELSE 0 END) AS bad_audience,
  SUM(CASE WHEN LTRIM(RTRIM(channel))         = '' OR DATALENGTH(channel)         <> DATALENGTH(LTRIM(RTRIM(channel)))         THEN 1 ELSE 0 END) AS bad_channel
FROM bronze.marketing_performance;

-- 4. Ranges
SELECT 
        MIN(TRY_CAST(impressions AS INT)) AS min_impr, 
        MAX(TRY_CAST(impressions AS INT)) AS max_impr,
               MIN(TRY_CAST(spend AS DECIMAL(12,2)))             AS min_spend, 
               MAX(TRY_CAST(spend AS DECIMAL(12,2)))             AS max_spend,
               MIN(TRY_CAST(revenue_generated AS DECIMAL(12,2))) AS min_rev,  
               MAX(TRY_CAST(revenue_generated AS DECIMAL(12,2))) AS max_rev,
               MIN(TRY_CAST(roas AS DECIMAL(4,2)))               AS min_roas,  
               MAX(TRY_CAST(roas AS DECIMAL(4,2)))               AS max_roas
FROM bronze.marketing_performance;

-- 5. Funnel logic: you can't have more clicks than impressions, or more conversions than clicks. Expect 0 and 0
SELECT
  SUM(CASE WHEN TRY_CAST(clicks      AS INT) > TRY_CAST(impressions AS INT) THEN 1 ELSE 0 END) AS clicks_over_impressions,
  SUM(CASE WHEN TRY_CAST(conversions AS INT) > TRY_CAST(clicks      AS INT) THEN 1 ELSE 0 END) AS conversions_over_clicks
FROM bronze.marketing_performance;

-- 6a. Does roas equal revenue / spend?
SELECT COUNT(*) AS roas_mismatches
FROM bronze.marketing_performance
WHERE ABS( TRY_CAST(roas AS DECIMAL(6,2))
         - TRY_CAST(revenue_generated AS DECIMAL(12,2)) / TRY_CAST(spend AS DECIMAL(12,2)) ) > 0.01;

-- 6b. Look at it yourself
SELECT TOP 5 spend, revenue_generated, roas AS stored_roas,
       TRY_CAST(revenue_generated AS DECIMAL(12,2)) / TRY_CAST(spend AS DECIMAL(12,2)) AS calculated_roas
FROM bronze.marketing_performance;

-- 7. Categories
SELECT campaign_name, 
COUNT(*) AS rows_count FROM bronze.marketing_performance
GROUP BY campaign_name ORDER BY campaign_name;
SELECT channel,      
COUNT(*) AS rows_count FROM bronze.marketing_performance 
GROUP BY channel
ORDER BY rows_count DESC;

-- 8. Date coverage: expect 2023-03-17 to 2024-11-05, 600 days
SELECT MIN(TRY_CONVERT(DATE, [date], 23)) AS first_day,
       MAX(TRY_CONVERT(DATE, [date], 23)) AS last_day,
       COUNT(DISTINCT [date]) AS distinct_days
FROM bronze.marketing_performance;

