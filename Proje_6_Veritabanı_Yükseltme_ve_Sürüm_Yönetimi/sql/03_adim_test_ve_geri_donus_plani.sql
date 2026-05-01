-- Adım 3: Test ve geri dönüş planı
-- Amaç: Yeni sürümü test etmek, doğrulamak ve gerekirse geri dönebilmek.

SET search_path TO version_demo;

CREATE TABLE IF NOT EXISTS app_orders_backup_before_test AS
SELECT * FROM app_orders WHERE 1 = 0;

TRUNCATE TABLE app_orders_backup_before_test;
INSERT INTO app_orders_backup_before_test
SELECT * FROM app_orders;

BEGIN;

ALTER TABLE app_orders
    ADD COLUMN IF NOT EXISTS review_note TEXT;

UPDATE app_orders
SET review_note = 'Test migration ok';

SELECT
    COUNT(*) AS total_rows,
    COUNT(review_note) AS note_rows,
    COUNT(*) FILTER (WHERE order_status = 'NEW') AS new_status_rows
FROM app_orders;

ROLLBACK;

SELECT
    COUNT(*) AS backup_rows
FROM app_orders_backup_before_test;

-- Geri donus gerekiyorsa:
-- 1) Yeni yapida sorun varsa migration geri alinabilir.
-- 2) Backup tablo geri yukleme icin referans olarak kullanilir.
-- 3) Gerekirse asagidaki adimlar calistirilir:
-- DROP TABLE IF EXISTS app_orders;
-- ALTER TABLE app_orders_backup_before_test RENAME TO app_orders;

SELECT 'Test ve geri donus senaryosu hazir' AS durum;
