-- Adım 6: Release kontrolu ve rollback dogrulama
-- Amaç: v1.2.0 sonrasi test ve geri donus dogrulamasini tamamlamak.

SET search_path TO version_demo;

CREATE TABLE IF NOT EXISTS app_orders_backup_before_v120 AS
SELECT * FROM app_orders WHERE 1 = 0;

TRUNCATE TABLE app_orders_backup_before_v120;
INSERT INTO app_orders_backup_before_v120
SELECT * FROM app_orders;

BEGIN;

UPDATE app_orders
SET discount_rate = 10
WHERE order_id = 1;

SELECT order_id, amount, discount_rate, net_amount
FROM app_orders
WHERE order_id = 1;

ROLLBACK;

CREATE OR REPLACE VIEW v_release_checklist AS
SELECT
    'has_version_v1_2_0' AS check_name,
    CASE WHEN EXISTS (SELECT 1 FROM schema_versions WHERE version_tag = 'v1.2.0') THEN 'PASS' ELSE 'FAIL' END AS check_result
UNION ALL
SELECT
    'backup_row_count_matches',
    CASE
        WHEN (SELECT COUNT(*) FROM app_orders_backup_before_v120) = (SELECT COUNT(*) FROM app_orders)
        THEN 'PASS' ELSE 'FAIL'
    END
UNION ALL
SELECT
    'ddl_audit_has_rows',
    CASE WHEN (SELECT COUNT(*) FROM ddl_change_log) > 0 THEN 'PASS' ELSE 'FAIL' END;

-- Ekran goruntusu icin calistir
SELECT COUNT(*) AS backup_rows FROM app_orders_backup_before_v120;
SELECT * FROM v_release_checklist;
SELECT order_id, amount, discount_rate, net_amount FROM app_orders ORDER BY order_id;
