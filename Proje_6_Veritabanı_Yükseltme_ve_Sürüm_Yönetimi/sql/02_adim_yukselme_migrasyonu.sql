-- Adım 2: Yükseltme migrasyonu
-- Amaç: Şemayı kontrollü şekilde yeni sürüme taşımak.

SET search_path TO version_demo;

ALTER TABLE app_orders
    ADD COLUMN IF NOT EXISTS order_status TEXT NOT NULL DEFAULT 'NEW';

ALTER TABLE app_orders
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_app_orders_status_created_at
ON app_orders (order_status, created_at DESC);

UPDATE schema_versions
SET version_tag = 'v1.1.0',
    applied_at = NOW(),
    description = 'order_status ve updated_at alanlari eklendi, indeks olusturuldu'
WHERE version_tag = 'v1.0.0';

SELECT version_tag, description, applied_at FROM schema_versions ORDER BY version_id;
SELECT * FROM app_orders ORDER BY order_id;
