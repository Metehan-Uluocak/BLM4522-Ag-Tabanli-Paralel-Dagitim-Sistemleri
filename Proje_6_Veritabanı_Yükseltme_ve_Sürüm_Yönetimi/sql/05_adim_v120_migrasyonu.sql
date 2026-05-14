-- Adım 5: v1.2.0 migrasyonu
-- Amaç: Siparis tablosuna indirim ve net tutar alanlari eklemek.

SET search_path TO version_demo;

ALTER TABLE app_orders
    ADD COLUMN IF NOT EXISTS discount_rate NUMERIC(5,2) NOT NULL DEFAULT 0;

ALTER TABLE app_orders
    ADD COLUMN IF NOT EXISTS net_amount NUMERIC(12,2);

UPDATE app_orders
SET net_amount = ROUND(amount * (1 - discount_rate / 100), 2)
WHERE net_amount IS NULL;

CREATE OR REPLACE FUNCTION fn_recalc_net_amount()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.net_amount := ROUND(NEW.amount * (1 - NEW.discount_rate / 100), 2);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_recalc_net_amount ON app_orders;
CREATE TRIGGER trg_recalc_net_amount
BEFORE INSERT OR UPDATE OF amount, discount_rate ON app_orders
FOR EACH ROW
EXECUTE FUNCTION fn_recalc_net_amount();

ALTER TABLE app_orders
    DROP CONSTRAINT IF EXISTS chk_discount_rate_range;

ALTER TABLE app_orders
    ADD CONSTRAINT chk_discount_rate_range
    CHECK (discount_rate >= 0 AND discount_rate <= 50);

INSERT INTO schema_versions (version_tag, description)
VALUES ('v1.2.0', 'discount_rate ve net_amount alanlari eklendi, trigger ile otomatik hesaplama kuruldu')
ON CONFLICT (version_tag) DO NOTHING;

-- Ekran goruntusu icin calistir
SELECT version_id, version_tag, description, applied_at
FROM schema_versions
ORDER BY version_id;

SELECT order_id, customer_name, amount, discount_rate, net_amount, order_status, updated_at
FROM app_orders
ORDER BY order_id;
