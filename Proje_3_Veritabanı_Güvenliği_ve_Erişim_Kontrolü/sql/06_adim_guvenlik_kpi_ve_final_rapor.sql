-- Adım 6: Guvenlik KPI ve final rapor
-- Amaç: Proje kapanisinda guvenlik metriklerini tek gorunumde toplamak.

SET search_path TO security_demo;

CREATE OR REPLACE VIEW v_security_kpi AS
SELECT 'total_accounts' AS metric_name, COUNT(*)::NUMERIC AS metric_value FROM customer_accounts
UNION ALL
SELECT 'active_accounts', COUNT(*)::NUMERIC FROM customer_accounts WHERE account_status = 'ACTIVE'
UNION ALL
SELECT 'suspended_accounts', COUNT(*)::NUMERIC FROM customer_accounts WHERE account_status = 'SUSPENDED'
UNION ALL
SELECT 'encrypted_national_id_rows', COUNT(*)::NUMERIC FROM customer_accounts WHERE national_id_encrypted IS NOT NULL
UNION ALL
SELECT 'audit_log_rows', COUNT(*)::NUMERIC FROM audit_log
UNION ALL
SELECT 'rls_policy_count', COUNT(*)::NUMERIC
FROM pg_policies
WHERE schemaname = 'security_demo' AND tablename = 'customer_accounts';

CREATE TABLE IF NOT EXISTS security_final_report (
    report_id BIGSERIAL PRIMARY KEY,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC(18,2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO security_final_report (metric_name, metric_value)
SELECT metric_name, metric_value FROM v_security_kpi;

-- Ekran goruntusu icin calistir
SELECT * FROM v_security_kpi ORDER BY metric_name;
SELECT * FROM security_final_report ORDER BY report_id DESC LIMIT 12;
SELECT audit_id, operation, changed_by, changed_at
FROM audit_log
ORDER BY audit_id DESC
LIMIT 10;
