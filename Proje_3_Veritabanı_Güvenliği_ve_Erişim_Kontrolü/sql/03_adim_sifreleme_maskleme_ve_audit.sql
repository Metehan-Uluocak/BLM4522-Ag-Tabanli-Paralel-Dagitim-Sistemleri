-- Adım 3: Şifreleme, maskeleme ve audit
-- Amaç: Hassas alanları şifrelemek, güvenli görünüm üretmek ve değişiklikleri loglamak.

SET search_path TO security_demo;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE customer_accounts
    ADD COLUMN IF NOT EXISTS national_id_encrypted bytea;

UPDATE customer_accounts
SET national_id_encrypted = pgp_sym_encrypt(national_id, 'BLM4522_DEMO_KEY')
WHERE national_id_encrypted IS NULL;

CREATE TABLE IF NOT EXISTS audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    row_data JSONB,
    changed_by TEXT NOT NULL DEFAULT CURRENT_USER,
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION log_customer_account_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, row_data, changed_by)
        VALUES ('customer_accounts', TG_OP, to_jsonb(NEW), CURRENT_USER);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, operation, row_data, changed_by)
        VALUES ('customer_accounts', TG_OP, to_jsonb(NEW), CURRENT_USER);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, row_data, changed_by)
        VALUES ('customer_accounts', TG_OP, to_jsonb(OLD), CURRENT_USER);
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_customer_accounts_audit ON customer_accounts;
CREATE TRIGGER trg_customer_accounts_audit
AFTER INSERT OR UPDATE OR DELETE ON customer_accounts
FOR EACH ROW
EXECUTE FUNCTION log_customer_account_changes();

CREATE OR REPLACE VIEW v_customer_accounts_secure AS
SELECT
    account_id,
    owner_user_id,
    account_no,
    customer_name,
    email,
    phone,
    pgp_sym_decrypt(national_id_encrypted, 'BLM4522_DEMO_KEY')::text AS decrypted_national_id,
    salary,
    account_status,
    created_at
FROM customer_accounts;

SELECT COUNT(*) AS audit_count FROM audit_log;
SELECT * FROM v_customer_accounts_secure ORDER BY account_id LIMIT 5;
