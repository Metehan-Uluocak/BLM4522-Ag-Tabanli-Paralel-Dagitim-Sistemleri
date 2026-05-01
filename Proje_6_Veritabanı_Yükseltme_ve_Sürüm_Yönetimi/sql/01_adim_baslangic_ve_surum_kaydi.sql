-- Adım 1: Başlangıç yapısı ve sürüm kaydı
-- Amaç: İlk şemayı kurmak ve sürüm takibini başlatmak.

DROP SCHEMA IF EXISTS version_demo CASCADE;
CREATE SCHEMA version_demo;
SET search_path TO version_demo;

CREATE TABLE schema_versions (
    version_id BIGSERIAL PRIMARY KEY,
    version_tag TEXT NOT NULL UNIQUE,
    applied_at TIMESTAMP NOT NULL DEFAULT NOW(),
    applied_by TEXT NOT NULL DEFAULT CURRENT_USER,
    description TEXT NOT NULL
);

CREATE TABLE app_orders (
    order_id BIGSERIAL PRIMARY KEY,
    customer_name TEXT NOT NULL,
    product_name TEXT NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO app_orders (customer_name, product_name, amount)
VALUES
('Ali Yilmaz', 'Laptop', 28500.00),
('Ayse Demir', 'Monitor', 8500.00),
('Mehmet Kaya', 'Keyboard', 1200.00);

INSERT INTO schema_versions (version_tag, description)
VALUES ('v1.0.0', 'Ilk baz surum ve temel siparis tablosu');

SELECT * FROM schema_versions ORDER BY version_id;
SELECT * FROM app_orders ORDER BY order_id;
