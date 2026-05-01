-- Adım 2: Rol ve erişim kontrolü
-- Amaç: En az yetki ilkesi, rol tabanlı erişim ve satır düzeyi güvenlik kurmak.

SET search_path TO security_demo;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_security_admin') THEN
        CREATE ROLE role_security_admin NOINHERIT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_security_auditor') THEN
        CREATE ROLE role_security_auditor NOINHERIT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_app_reader') THEN
        CREATE ROLE role_app_reader NOINHERIT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_app_writer') THEN
        CREATE ROLE role_app_writer NOINHERIT;
    END IF;
END $$;

REVOKE ALL ON SCHEMA security_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA security_demo TO role_security_admin, role_security_auditor, role_app_reader, role_app_writer;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA security_demo TO role_security_admin;
GRANT SELECT ON departments, app_users, customer_accounts TO role_security_auditor;
GRANT SELECT ON departments TO role_app_reader;
GRANT SELECT ON customer_accounts TO role_app_reader;
GRANT INSERT, UPDATE ON customer_accounts TO role_app_writer;

ALTER TABLE customer_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS customer_accounts_owner_policy ON customer_accounts;
CREATE POLICY customer_accounts_owner_policy
ON customer_accounts
USING (owner_user_id::text = current_setting('app.user_id', true))
WITH CHECK (owner_user_id::text = current_setting('app.user_id', true));

CREATE OR REPLACE VIEW v_customer_accounts_masked AS
SELECT
    account_id,
    owner_user_id,
    account_no,
    customer_name,
    left(email, 2) || '***' || split_part(email, '@', 2) AS masked_email,
    left(phone, 4) || '***' || right(phone, 2) AS masked_phone,
    left(national_id, 3) || '*******' || right(national_id, 2) AS masked_national_id,
    salary,
    account_status,
    created_at
FROM customer_accounts;

GRANT SELECT ON v_customer_accounts_masked TO role_security_auditor, role_app_reader;

SELECT 'Rol ve policy yapisi hazir' AS durum;
