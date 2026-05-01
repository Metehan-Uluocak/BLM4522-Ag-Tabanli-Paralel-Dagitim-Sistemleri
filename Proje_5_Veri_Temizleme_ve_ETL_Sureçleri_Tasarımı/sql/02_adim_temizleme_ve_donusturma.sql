-- Adım 2: Temizleme ve dönüştürme
-- Amaç: Kirli alanları standardize etmek ve hatalı kayıtları ayırmak.

SET search_path TO etl_demo;

CREATE TABLE IF NOT EXISTS stg_orders_rejected (
    reject_id BIGSERIAL PRIMARY KEY,
    raw_id BIGINT,
    order_code TEXT,
    reject_reason TEXT,
    rejected_at TIMESTAMP NOT NULL DEFAULT NOW()
);

TRUNCATE TABLE stg_orders;
TRUNCATE TABLE stg_orders_rejected;

WITH normalized AS (
    SELECT
        raw_id,
        upper(trim(order_code)) AS order_code_clean,
        initcap(trim(customer_name)) AS customer_name_clean,
        initcap(trim(city)) AS city_clean,
        initcap(trim(product_name)) AS product_name_clean,
        CASE
            WHEN quantity_text ~ '^\d+(\.\d+)?$' THEN quantity_text::numeric(12,2)
            ELSE NULL
        END AS quantity_clean,
        CASE
            WHEN replace(unit_price_text, ',', '.') ~ '^\d+(\.\d+)?$' THEN replace(unit_price_text, ',', '.')::numeric(12,2)
            ELSE NULL
        END AS unit_price_clean,
        CASE
            WHEN order_date_text ~ '^\d{4}-\d{2}-\d{2}$' THEN order_date_text::date
            WHEN order_date_text ~ '^\d{4}/\d{2}/\d{2}$' THEN to_date(order_date_text, 'YYYY/MM/DD')
            ELSE NULL
        END AS order_date_clean,
        source_system
    FROM raw_orders
)
INSERT INTO stg_orders (
    order_code,
    customer_name,
    city,
    product_name,
    quantity,
    unit_price,
    order_date,
    source_system
)
SELECT
    order_code_clean,
    NULLIF(customer_name_clean, ''),
    NULLIF(city_clean, ''),
    NULLIF(product_name_clean, ''),
    quantity_clean,
    unit_price_clean,
    order_date_clean,
    source_system
FROM normalized
WHERE order_code_clean IS NOT NULL
  AND NULLIF(customer_name_clean, '') IS NOT NULL
  AND quantity_clean IS NOT NULL
  AND unit_price_clean IS NOT NULL
  AND order_date_clean IS NOT NULL;

INSERT INTO stg_orders_rejected (raw_id, order_code, reject_reason)
SELECT
    raw_id,
    order_code,
    CASE
        WHEN trim(COALESCE(customer_name, '')) = '' THEN 'customer_name boş'
        WHEN quantity_text IS NULL OR quantity_text !~ '^\d+(\.\d+)?$' THEN 'quantity geçersiz'
        WHEN replace(COALESCE(unit_price_text, ''), ',', '.') !~ '^\d+(\.\d+)?$' THEN 'unit_price geçersiz'
        WHEN order_date_text IS NULL OR (order_date_text !~ '^\d{4}-\d{2}-\d{2}$' AND order_date_text !~ '^\d{4}/\d{2}/\d{2}$') THEN 'order_date geçersiz'
        ELSE 'diğer'
    END
FROM raw_orders r
WHERE NOT EXISTS (
    SELECT 1
    FROM stg_orders s
    WHERE s.order_code = upper(trim(r.order_code))
);

SELECT COUNT(*) AS staged_rows FROM stg_orders;
SELECT COUNT(*) AS rejected_rows FROM stg_orders_rejected;
SELECT * FROM stg_orders ORDER BY stg_id;
SELECT * FROM stg_orders_rejected ORDER BY reject_id;
