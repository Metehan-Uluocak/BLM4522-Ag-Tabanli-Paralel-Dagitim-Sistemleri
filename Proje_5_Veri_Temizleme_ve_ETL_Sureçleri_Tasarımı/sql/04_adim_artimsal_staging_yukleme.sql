-- Adım 4: Artimsal staging yukleme
-- Amaç: Yeni gelen ham veriyi duplicate etmeden staging alana eklemek.

SET search_path TO etl_demo;

INSERT INTO raw_orders (
    order_code,
    customer_name,
    city,
    product_name,
    quantity_text,
    unit_price_text,
    order_date_text,
    source_system
)
VALUES
('ORD-008', 'Selin A.', 'istanbul', 'Tablet', '2', '12500', '2026-04-08', 'api'),
('ORD-009', 'Murat B.', 'ankara', 'Laptop', '1', '31500.75', '2026/04/09', 'csv_import'),
('ORD-010', 'Derya C.', 'izmir', 'Mouse', '2', 'invalid_price', '2026-04-10', 'excel_import'),
('ORD-011', 'Emre D.', 'bursa', 'Monitor', '1', '9200', '2026-04-11', 'api')
ON CONFLICT DO NOTHING;

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
    FROM raw_orders r
    WHERE NOT EXISTS (
        SELECT 1 FROM stg_orders s WHERE s.order_code = upper(trim(r.order_code))
    )
      AND NOT EXISTS (
        SELECT 1 FROM stg_orders_rejected rej WHERE upper(trim(rej.order_code)) = upper(trim(r.order_code))
    )
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
    r.raw_id,
    r.order_code,
    CASE
        WHEN trim(COALESCE(r.customer_name, '')) = '' THEN 'customer_name bos'
        WHEN r.quantity_text IS NULL OR r.quantity_text !~ '^\d+(\.\d+)?$' THEN 'quantity gecersiz'
        WHEN replace(COALESCE(r.unit_price_text, ''), ',', '.') !~ '^\d+(\.\d+)?$' THEN 'unit_price gecersiz'
        WHEN r.order_date_text IS NULL OR (r.order_date_text !~ '^\d{4}-\d{2}-\d{2}$' AND r.order_date_text !~ '^\d{4}/\d{2}/\d{2}$') THEN 'order_date gecersiz'
        ELSE 'diger'
    END
FROM raw_orders r
WHERE upper(trim(r.order_code)) IN ('ORD-008','ORD-009','ORD-010','ORD-011')
  AND NOT EXISTS (
        SELECT 1 FROM stg_orders s WHERE s.order_code = upper(trim(r.order_code))
  )
  AND NOT EXISTS (
        SELECT 1 FROM stg_orders_rejected rej WHERE upper(trim(rej.order_code)) = upper(trim(r.order_code))
  );

-- Ekran goruntusu icin calistir
SELECT * FROM stg_orders WHERE order_code IN ('ORD-008','ORD-009','ORD-010','ORD-011') ORDER BY stg_id;
SELECT * FROM stg_orders_rejected WHERE order_code IN ('ORD-008','ORD-009','ORD-010','ORD-011') ORDER BY reject_id;
