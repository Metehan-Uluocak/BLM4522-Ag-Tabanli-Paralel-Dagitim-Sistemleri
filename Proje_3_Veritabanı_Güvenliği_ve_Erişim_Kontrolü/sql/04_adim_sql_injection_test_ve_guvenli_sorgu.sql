-- Adım 4: SQL injection test yaklasimi ve guvenli sorgu
-- Amac: Guvensiz ornek ile injection etkisini gostermek, guvenli sorgu ile engellemek.

SET search_path TO security_demo;

CREATE TABLE IF NOT EXISTS security_test_log (
    test_id BIGSERIAL PRIMARY KEY,
    test_name TEXT NOT NULL,
    input_value TEXT NOT NULL,
    test_result TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Guvensiz arama: dinamik SQL ve dogrudan birlestirme (sadece demo amacli)
CREATE OR REPLACE FUNCTION fn_search_accounts_unsafe(p_keyword TEXT)
RETURNS TABLE (
    account_id BIGINT,
    account_no TEXT,
    customer_name TEXT,
    account_status TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT account_id, account_no, customer_name, account_status '
        || 'FROM customer_accounts '
        || 'WHERE customer_name ILIKE ''%' || p_keyword || '%'' '
        || 'OR account_no ILIKE ''%' || p_keyword || '%'' '
        || 'ORDER BY account_id';
END;
$$;

CREATE OR REPLACE FUNCTION fn_search_accounts_safe(p_keyword TEXT)
RETURNS TABLE (
    account_id BIGINT,
    account_no TEXT,
    customer_name TEXT,
    account_status TEXT
)
LANGUAGE sql
AS $$
    SELECT
        c.account_id,
        c.account_no,
        c.customer_name,
        c.account_status
    FROM customer_accounts c
    WHERE c.customer_name ILIKE '%' || p_keyword || '%'
       OR c.account_no ILIKE '%' || p_keyword || '%'
    ORDER BY c.account_id;
$$;

-- Testlerin sonucunu otomatik logla
DO $$
DECLARE
    v_normal_count INT;
    v_injection_unsafe INT;
    v_injection_safe INT;
BEGIN
    SELECT COUNT(*) INTO v_normal_count
    FROM fn_search_accounts_safe('Musteri 1');

    SELECT COUNT(*) INTO v_injection_unsafe
    FROM fn_search_accounts_unsafe(''' OR 1=1 --');

    SELECT COUNT(*) INTO v_injection_safe
    FROM fn_search_accounts_safe(''' OR 1=1 --');

    INSERT INTO security_test_log (test_name, input_value, test_result)
    VALUES
    ('normal_search_safe', 'Musteri 1', 'Satir sayisi: ' || v_normal_count),
    ('injection_unsafe', ''' OR 1=1 --', 'Satir sayisi: ' || v_injection_unsafe),
    ('injection_safe', ''' OR 1=1 --', 'Satir sayisi: ' || v_injection_safe);
END $$;

-- Ekran goruntusu icin calistir (tek ekranda rapor)
SELECT
    (SELECT COUNT(*) FROM fn_search_accounts_safe('Musteri 1')) AS safe_normal_count,
    (SELECT COUNT(*) FROM fn_search_accounts_unsafe(''' OR 1=1 --')) AS unsafe_injection_count,
    (SELECT COUNT(*) FROM fn_search_accounts_safe(''' OR 1=1 --')) AS safe_injection_count,
    (
        SELECT json_agg(t)
        FROM (
            SELECT *
            FROM fn_search_accounts_safe('Musteri 1')
            LIMIT 5
        ) AS t
    ) AS safe_sample_rows,
    (
        SELECT json_agg(t)
        FROM (
            SELECT *
            FROM security_test_log
            ORDER BY test_id DESC
            LIMIT 5
        ) AS t
    ) AS last_test_logs;
