-- Adım 1: Ham veri ve staging hazırlığı
-- Amaç: Kirli veri içeren kaynak tabloyu ve staging yapısını kurmak.

DROP SCHEMA IF EXISTS etl_demo CASCADE;
CREATE SCHEMA etl_demo;
SET search_path TO etl_demo;

CREATE TABLE raw_orders (
    raw_id BIGSERIAL PRIMARY KEY,
    order_code TEXT,
    customer_name TEXT,
    city TEXT,
    product_name TEXT,
    quantity_text TEXT,
    unit_price_text TEXT,
    order_date_text TEXT,
    source_system TEXT DEFAULT 'csv_import'
);

CREATE TABLE stg_orders (
    stg_id BIGSERIAL PRIMARY KEY,
    order_code TEXT,
    customer_name TEXT,
    city TEXT,
    product_name TEXT,
    quantity NUMERIC(12,2),
    unit_price NUMERIC(12,2),
    order_date DATE,
    source_system TEXT,
    load_time TIMESTAMP NOT NULL DEFAULT NOW()
);

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
(' ord-001 ', ' ali veli ', ' istanbul ', ' laptop ', '2', '28500,50', '2026-04-01', 'csv_import'),
('ORD-002', 'Ayse Demir', 'ankara', 'Monitor', '1', '8500.00', '2026/04/02', 'excel_import'),
('ord-003', 'Mehmet Yilmaz', 'izmir', 'Mouse', '3', '350', '2026-04-03', 'api'),
('ORD-004', '  ', 'bursa', 'Keyboard', '2', '1200', '2026-04-04', 'csv_import'),
('ORD-005', 'Fatma K.', 'istanbul', 'Dock', NULL, '4200', '2026-04-05', 'csv_import'),
('ORD-006', 'Can A.', 'ankara', 'Laptop', '1', 'bad_price', '2026-04-06', 'api'),
('ORD-007', 'Zeynep T.', 'izmir', 'Headset', '5', '780', '2026-04-07', 'csv_import');

SELECT COUNT(*) AS raw_row_count FROM raw_orders;
SELECT * FROM raw_orders ORDER BY raw_id;
