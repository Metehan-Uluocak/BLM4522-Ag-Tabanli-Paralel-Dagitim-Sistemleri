-- Adım 5: Hedefe artimsal upsert
-- Amaç: Yeni staging verilerini hedef tablolara duplicate olusturmadan islemek.

SET search_path TO etl_demo;

INSERT INTO dim_customer (customer_name, city)
SELECT DISTINCT s.customer_name, s.city
FROM stg_orders s
WHERE s.customer_name IS NOT NULL
  AND s.city IS NOT NULL
ON CONFLICT (customer_name) DO UPDATE
SET city = EXCLUDED.city;

INSERT INTO fact_orders (
    order_code,
    customer_id,
    product_name,
    quantity,
    unit_price,
    order_date,
    source_system
)
SELECT
    s.order_code,
    c.customer_id,
    s.product_name,
    s.quantity,
    s.unit_price,
    s.order_date,
    s.source_system
FROM stg_orders s
JOIN dim_customer c ON c.customer_name = s.customer_name
ON CONFLICT (order_code) DO UPDATE
SET
    customer_id = EXCLUDED.customer_id,
    product_name = EXCLUDED.product_name,
    quantity = EXCLUDED.quantity,
    unit_price = EXCLUDED.unit_price,
    order_date = EXCLUDED.order_date,
    source_system = EXCLUDED.source_system;

CREATE OR REPLACE VIEW v_etl_reconciliation AS
SELECT
    source_system,
    COUNT(*) FILTER (WHERE layer_name = 'staging') AS staging_count,
    COUNT(*) FILTER (WHERE layer_name = 'fact') AS fact_count
FROM (
    SELECT source_system, 'staging' AS layer_name FROM stg_orders
    UNION ALL
    SELECT source_system, 'fact' AS layer_name FROM fact_orders
) x
GROUP BY source_system
ORDER BY source_system;

-- Ekran goruntusu icin calistir
SELECT * FROM fact_orders ORDER BY fact_id;
SELECT * FROM v_etl_reconciliation;
