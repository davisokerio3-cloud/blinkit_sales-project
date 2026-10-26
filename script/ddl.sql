-- 1. DATABASE
IF DB_ID('blinkit_db') IS NULL CREATE DATABASE blinkit_db;
GO
USE blinkit_db;
GO

-- 2. SCHEMAS (bronze = raw, silver = cleaned)
IF SCHEMA_ID('bronze') IS NULL EXEC('CREATE SCHEMA bronze');
IF SCHEMA_ID('silver') IS NULL EXEC('CREATE SCHEMA silver');
DROP SCHEMA IF EXISTS gold;   -- removes the extra schema if you already created it
GO

-- 3. BRONZE TABLES (everything as text so the load never fails)
DROP TABLE IF EXISTS bronze.customers;
CREATE TABLE bronze.customers (
    customer_id       VARCHAR(50),
    customer_name     VARCHAR(255),
    email             VARCHAR(255),
    phone             VARCHAR(50),
    address           VARCHAR(500),
    area              VARCHAR(255),
    pincode           VARCHAR(50),
    registration_date VARCHAR(50),
    customer_segment  VARCHAR(50),
    total_orders      VARCHAR(50),
    avg_order_value   VARCHAR(50)
);

DROP TABLE IF EXISTS bronze.products;
CREATE TABLE bronze.products (
    product_id        VARCHAR(50),
    product_name      VARCHAR(255),
    category          VARCHAR(255),
    brand             VARCHAR(255),
    price             VARCHAR(50),
    mrp               VARCHAR(50),
    margin_percentage VARCHAR(50),
    shelf_life_days   VARCHAR(50),
    min_stock_level   VARCHAR(50),
    max_stock_level   VARCHAR(50)
);

DROP TABLE IF EXISTS bronze.orders;
CREATE TABLE bronze.orders (
    order_id               VARCHAR(50),
    customer_id            VARCHAR(50),
    order_date             VARCHAR(50),
    promised_delivery_time VARCHAR(50),
    actual_delivery_time   VARCHAR(50),
    delivery_status        VARCHAR(50),
    order_total            VARCHAR(50),
    payment_method         VARCHAR(50),
    delivery_partner_id    VARCHAR(50),
    store_id               VARCHAR(50)
);

DROP TABLE IF EXISTS bronze.order_items;
CREATE TABLE bronze.order_items (
    order_id   VARCHAR(50),
    product_id VARCHAR(50),
    quantity   VARCHAR(50),
    unit_price VARCHAR(50)
);

DROP TABLE IF EXISTS bronze.delivery_performance;
CREATE TABLE bronze.delivery_performance (
    order_id              VARCHAR(50),
    delivery_partner_id   VARCHAR(50),
    promised_time         VARCHAR(50),
    actual_time           VARCHAR(50),
    delivery_time_minutes VARCHAR(50),
    distance_km           VARCHAR(50),
    delivery_status       VARCHAR(50),
    reasons_if_delayed    VARCHAR(100)
);

DROP TABLE IF EXISTS bronze.customer_feedback;
CREATE TABLE bronze.customer_feedback (
    feedback_id       VARCHAR(50),
    order_id          VARCHAR(50),
    customer_id       VARCHAR(50),
    rating            VARCHAR(50),
    feedback_text     VARCHAR(255),
    feedback_category VARCHAR(100),
    sentiment         VARCHAR(50),
    feedback_date     VARCHAR(50)
);

DROP TABLE IF EXISTS bronze.inventory;
CREATE TABLE bronze.inventory (
    product_id     VARCHAR(50),
    [date]         VARCHAR(50),   -- dd-mm-yyyy text, converted in silver
    stock_received VARCHAR(50),
    damaged_stock  VARCHAR(50)
);

DROP TABLE IF EXISTS bronze.inventory_new;
CREATE TABLE bronze.inventory_new (
    product_id     VARCHAR(50),
    [date]         VARCHAR(50),   -- month label like 'Mar-23'
    stock_received VARCHAR(50),
    damaged_stock  VARCHAR(50)
);

DROP TABLE IF EXISTS bronze.marketing_performance;
CREATE TABLE bronze.marketing_performance (
    campaign_id       VARCHAR(50),
    campaign_name     VARCHAR(255),
    [date]            VARCHAR(50),
    target_audience   VARCHAR(100),
    channel           VARCHAR(100),
    impressions       VARCHAR(50),
    clicks            VARCHAR(50),
    conversions       VARCHAR(50),
    spend             VARCHAR(50),
    revenue_generated VARCHAR(50),
    roas              VARCHAR(50)
);
GO

-- 4. LOAD (change C:\blinkit\ to your folder)
BULK INSERT bronze.customers FROM 'D:\blinkit_customers.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, ROWTERMINATOR='0x0a', CODEPAGE='65001', TABLOCK);

BULK INSERT bronze.products FROM 'D:\blinkit_products.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, ROWTERMINATOR='0x0a', CODEPAGE='65001', TABLOCK);

BULK INSERT bronze.orders FROM 'D:\blinkit_orders.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, ROWTERMINATOR='0x0a', TABLOCK);

BULK INSERT bronze.order_items FROM 'D:\blinkit_order_items.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, ROWTERMINATOR='0x0a', TABLOCK);

BULK INSERT bronze.delivery_performance FROM 'D:\blinkit_delivery_performance.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, ROWTERMINATOR='0x0a', TABLOCK);

BULK INSERT bronze.customer_feedback FROM 'D:\blinkit_customer_feedback.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, ROWTERMINATOR='0x0a', TABLOCK);

BULK INSERT bronze.inventory FROM 'D:\blinkit_inventory.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, ROWTERMINATOR='0x0a', TABLOCK);

BULK INSERT bronze.inventory_new FROM 'D:\blinkit_inventoryNew.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, ROWTERMINATOR='0x0a', TABLOCK);

BULK INSERT bronze.marketing_performance FROM 'D:\blinkit_marketing_performance.csv'
WITH (FORMAT='CSV', FIELDQUOTE='"', FIRSTROW=2, ROWTERMINATOR='0x0a', TABLOCK);
GO

-- 5. CHECK ROW COUNTS
SELECT 'customers' AS tbl, COUNT(*) AS row_count FROM bronze.customers
UNION ALL SELECT 'products',              COUNT(*) FROM bronze.products
UNION ALL SELECT 'orders',                COUNT(*) FROM bronze.orders
UNION ALL SELECT 'order_items',           COUNT(*) FROM bronze.order_items
UNION ALL SELECT 'delivery_performance',  COUNT(*) FROM bronze.delivery_performance
UNION ALL SELECT 'customer_feedback',     COUNT(*) FROM bronze.customer_feedback
UNION ALL SELECT 'inventory',             COUNT(*) FROM bronze.inventory
UNION ALL SELECT 'inventory_new',         COUNT(*) FROM bronze.inventory_new
UNION ALL SELECT 'marketing_performance', COUNT(*) FROM bronze.marketing_performance;
