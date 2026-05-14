-- Adım 5: RLS senaryo testleri
-- Amaç: Farkli app.user_id degerlerinde satir gorunurlugunu test etmek.

SET search_path TO security_demo;

CREATE TABLE IF NOT EXISTS rls_test_results (
    result_id BIGSERIAL PRIMARY KEY,
    test_user_id INT NOT NULL,
    visible_row_count INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

DELETE FROM rls_test_results;

SET app.user_id = '1';
INSERT INTO rls_test_results (test_user_id, visible_row_count)
SELECT 1, COUNT(*)::INT FROM customer_accounts;

SET app.user_id = '2';
INSERT INTO rls_test_results (test_user_id, visible_row_count)
SELECT 2, COUNT(*)::INT FROM customer_accounts;

RESET app.user_id;

CREATE OR REPLACE VIEW v_role_grants_summary AS
SELECT
    grantee,
    table_name,
    string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.role_table_grants
WHERE table_schema = 'security_demo'
  AND grantee IN ('role_security_admin', 'role_security_auditor', 'role_app_reader', 'role_app_writer')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

-- Ekran goruntusu icin calistir
SELECT * FROM rls_test_results ORDER BY result_id;
SELECT * FROM v_role_grants_summary;
