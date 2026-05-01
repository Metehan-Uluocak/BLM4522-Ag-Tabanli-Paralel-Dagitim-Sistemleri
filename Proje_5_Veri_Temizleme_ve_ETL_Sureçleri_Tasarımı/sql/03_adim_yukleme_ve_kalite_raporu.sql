-- Adım 3: Hedef tabloya yükleme ve kalite raporu
-- Amaç: Temiz veriyi hedefe aktarmak, özet kalite raporu üretmek.

SET search_path TO etl_demo;

CREATE TABLE IF NOT EXISTS dim_customer (
    customer_id BIGSERIAL PRIMARY KEY,
    customer_name TEXT NOT NULL UNIQUE,
    city TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS fact_orders (
    fact_id BIGSERIAL PRIMARY KEY,
    order_code TEXT NOT NULL UNIQUE,
    customer_id BIGINT NOT NULL REFERENCES dim_customer(customer_id),
    product_name TEXT NOT NULL,
    quantity NUMERIC(12,2) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    order_date DATE NOT NULL,
    source_system TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO dim_customer (customer_name, city)
SELECT DISTINCT customer_name, city
FROM stg_orders
WHERE customer_name IS NOT NULL AND city IS NOT NULL
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
JOIN dim_customer c
  ON c.customer_name = s.customer_name;

CREATE TABLE IF NOT EXISTS etl_quality_report (
    report_id BIGSERIAL PRIMARY KEY,
    report_name TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC(18,2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO etl_quality_report (report_name, metric_name, metric_value)
SELECT 'raw_to_staging', 'raw_rows', COUNT(*)::numeric FROM raw_orders;

INSERT INTO etl_quality_report (report_name, metric_name, metric_value)
SELECT 'raw_to_staging', 'staged_rows', COUNT(*)::numeric FROM stg_orders;

INSERT INTO etl_quality_report (report_name, metric_name, metric_value)
SELECT 'raw_to_staging', 'rejected_rows', COUNT(*)::numeric FROM stg_orders_rejected;

INSERT INTO etl_quality_report (report_name, metric_name, metric_value)
SELECT 'target_load', 'fact_orders_rows', COUNT(*)::numeric FROM fact_orders;

SELECT * FROM etl_quality_report ORDER BY report_id;
SELECT * FROM fact_orders ORDER BY fact_id;
