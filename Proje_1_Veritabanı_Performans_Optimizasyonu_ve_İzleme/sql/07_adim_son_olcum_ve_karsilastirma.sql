-- Adım 7: Final ölçüm ve önce/sonra karşılaştırma
-- Bu dosyayı blm4522_perf veritabanında çalıştır.

-- -----------------------------------------------------
-- A) Final ölçüm tablosu
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS perf_final_measurements (
    id BIGSERIAL PRIMARY KEY,
    query_name TEXT NOT NULL,
    query_id BIGINT,
    calls BIGINT,
    total_exec_time_ms DOUBLE PRECISION,
    mean_exec_time_ms DOUBLE PRECISION,
    rows_returned BIGINT,
    measured_at TIMESTAMP NOT NULL DEFAULT NOW(),
    note TEXT
);

-- Plan maliyeti/süre kıyaslama tablosu
CREATE TABLE IF NOT EXISTS perf_plan_cost_samples (
    id BIGSERIAL PRIMARY KEY,
    query_name TEXT NOT NULL,
    scenario TEXT NOT NULL,
    total_cost NUMERIC(18,4) NOT NULL,
    actual_total_time_ms NUMERIC(18,4) NOT NULL,
    captured_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------
-- B) Aynı kritik sorguları tekrar çalıştır
-- -----------------------------------------------------
SELECT pg_stat_statements_reset();

-- Q1: Kullanıcı bazlı son 30 gün işlem özeti
WITH q1_adim7 AS (
    SELECT
        o.user_id,
        o.quantity,
        o.price
    FROM orders o
    WHERE o.order_time >= NOW() - INTERVAL '30 day'
)
SELECT
    q1.user_id,
    COUNT(*) AS order_count,
    SUM(q1.quantity * q1.price) AS gross_value
FROM q1_adim7 q1
GROUP BY q1.user_id
ORDER BY gross_value DESC
LIMIT 100;

-- Q2: Enstrüman türüne göre son 90 gün hacim
WITH q2_adim7 AS (
    SELECT
        i.instrument_type,
        t.executed_qty,
        t.executed_price
    FROM trades t
    JOIN orders o ON o.order_id = t.order_id
    JOIN instruments i ON i.instrument_id = o.instrument_id
    WHERE t.executed_at >= NOW() - INTERVAL '90 day'
)
SELECT
    q2.instrument_type,
    COUNT(*) AS trade_count,
    SUM(q2.executed_qty * q2.executed_price) AS volume
FROM q2_adim7 q2
GROUP BY q2.instrument_type
ORDER BY volume DESC;

-- Q3: Saatlik yoğunluk analizi (son 7 gün)
WITH q3_bounds_adim7 AS (
    SELECT MAX(order_time) - INTERVAL '7 day' AS cutoff
    FROM orders
),
q3_adim7 AS (
    SELECT
        date_trunc('hour', o.order_time) AS hour_bucket
    FROM orders o
    CROSS JOIN q3_bounds_adim7 b
    WHERE o.order_time >= b.cutoff
)
SELECT
    q3.hour_bucket,
    COUNT(*) AS order_count
FROM q3_adim7 q3
GROUP BY q3.hour_bucket
ORDER BY q3.hour_bucket DESC;

-- -----------------------------------------------------
-- C) pg_stat_statements üzerinden final süre ölçümü
-- -----------------------------------------------------
DELETE FROM perf_final_measurements
WHERE note = 'Adım 7 final ölçümü';

WITH stats AS (
    SELECT
        s.queryid,
        s.calls,
        s.total_exec_time,
        s.mean_exec_time,
        s.rows,
        lower(regexp_replace(s.query, '\\s+', ' ', 'g')) AS q
    FROM pg_stat_statements s
    WHERE s.dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
),
q1 AS (
    SELECT *
    FROM stats
        WHERE q LIKE '%with q1_adim7 as (%'
    ORDER BY total_exec_time DESC
    LIMIT 1
),
q2 AS (
    SELECT *
    FROM stats
        WHERE q LIKE '%with q2_adim7 as (%'
    ORDER BY total_exec_time DESC
    LIMIT 1
),
q3 AS (
    SELECT *
    FROM stats
        WHERE q LIKE '%with q3_bounds_adim7 as (%'
    ORDER BY total_exec_time DESC
    LIMIT 1
)
INSERT INTO perf_final_measurements
(query_name, query_id, calls, total_exec_time_ms, mean_exec_time_ms, rows_returned, note)
SELECT
    'Q1_user_30d_summary' AS query_name,
    q1.queryid,
    q1.calls,
    q1.total_exec_time,
    q1.mean_exec_time,
    q1.rows,
    'Adım 7 final ölçümü'
FROM q1
UNION ALL
SELECT
    'Q2_type_90d_volume',
    q2.queryid,
    q2.calls,
    q2.total_exec_time,
    q2.mean_exec_time,
    q2.rows,
    'Adım 7 final ölçümü'
FROM q2
UNION ALL
SELECT
    'Q3_hourly_7d_density',
    q3.queryid,
    q3.calls,
    q3.total_exec_time,
    q3.mean_exec_time,
    q3.rows,
    'Adım 7 final ölçümü'
FROM q3;

-- -----------------------------------------------------
-- D) Plan maliyeti ölçümü (simüle önce / optimize sonra)
-- -----------------------------------------------------
DELETE FROM perf_plan_cost_samples
WHERE captured_at::date = CURRENT_DATE;

DO $$
DECLARE
    plan_json JSONB;
BEGIN
    -- Q1
    PERFORM set_config('enable_indexscan', 'off', true);
    PERFORM set_config('enable_bitmapscan', 'off', true);
    PERFORM set_config('enable_indexonlyscan', 'off', true);
    EXECUTE $Q$
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        WITH q1_adim7 AS (
            SELECT
                o.user_id,
                o.quantity,
                o.price
            FROM orders o
            WHERE o.order_time >= NOW() - INTERVAL '30 day'
        )
        SELECT
            q1.user_id,
            COUNT(*) AS order_count,
            SUM(q1.quantity * q1.price) AS gross_value
        FROM q1_adim7 q1
        GROUP BY q1.user_id
        ORDER BY gross_value DESC
        LIMIT 100
    $Q$
    INTO plan_json;

    INSERT INTO perf_plan_cost_samples (query_name, scenario, total_cost, actual_total_time_ms)
    VALUES (
        'Q1_user_30d_summary',
        'before_simulated',
        (plan_json -> 0 -> 'Plan' ->> 'Total Cost')::numeric,
        (plan_json -> 0 -> 'Plan' ->> 'Actual Total Time')::numeric
    );

    PERFORM set_config('enable_indexscan', 'on', true);
    PERFORM set_config('enable_bitmapscan', 'on', true);
    PERFORM set_config('enable_indexonlyscan', 'on', true);
    EXECUTE $Q$
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        WITH q1_adim7 AS (
            SELECT
                o.user_id,
                o.quantity,
                o.price
            FROM orders o
            WHERE o.order_time >= NOW() - INTERVAL '30 day'
        )
        SELECT
            q1.user_id,
            COUNT(*) AS order_count,
            SUM(q1.quantity * q1.price) AS gross_value
        FROM q1_adim7 q1
        GROUP BY q1.user_id
        ORDER BY gross_value DESC
        LIMIT 100
    $Q$
    INTO plan_json;

    INSERT INTO perf_plan_cost_samples (query_name, scenario, total_cost, actual_total_time_ms)
    VALUES (
        'Q1_user_30d_summary',
        'after_optimized',
        (plan_json -> 0 -> 'Plan' ->> 'Total Cost')::numeric,
        (plan_json -> 0 -> 'Plan' ->> 'Actual Total Time')::numeric
    );

    -- Q2
    PERFORM set_config('enable_indexscan', 'off', true);
    PERFORM set_config('enable_bitmapscan', 'off', true);
    PERFORM set_config('enable_indexonlyscan', 'off', true);
    EXECUTE $Q$
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        WITH q2_adim7 AS (
            SELECT
                i.instrument_type,
                t.executed_qty,
                t.executed_price
            FROM trades t
            JOIN orders o ON o.order_id = t.order_id
            JOIN instruments i ON i.instrument_id = o.instrument_id
            WHERE t.executed_at >= NOW() - INTERVAL '90 day'
        )
        SELECT
            q2.instrument_type,
            COUNT(*) AS trade_count,
            SUM(q2.executed_qty * q2.executed_price) AS volume
        FROM q2_adim7 q2
        GROUP BY q2.instrument_type
        ORDER BY volume DESC
    $Q$
    INTO plan_json;

    INSERT INTO perf_plan_cost_samples (query_name, scenario, total_cost, actual_total_time_ms)
    VALUES (
        'Q2_type_90d_volume',
        'before_simulated',
        (plan_json -> 0 -> 'Plan' ->> 'Total Cost')::numeric,
        (plan_json -> 0 -> 'Plan' ->> 'Actual Total Time')::numeric
    );

    PERFORM set_config('enable_indexscan', 'on', true);
    PERFORM set_config('enable_bitmapscan', 'on', true);
    PERFORM set_config('enable_indexonlyscan', 'on', true);
    EXECUTE $Q$
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        WITH q2_adim7 AS (
            SELECT
                i.instrument_type,
                t.executed_qty,
                t.executed_price
            FROM trades t
            JOIN orders o ON o.order_id = t.order_id
            JOIN instruments i ON i.instrument_id = o.instrument_id
            WHERE t.executed_at >= NOW() - INTERVAL '90 day'
        )
        SELECT
            q2.instrument_type,
            COUNT(*) AS trade_count,
            SUM(q2.executed_qty * q2.executed_price) AS volume
        FROM q2_adim7 q2
        GROUP BY q2.instrument_type
        ORDER BY volume DESC
    $Q$
    INTO plan_json;

    INSERT INTO perf_plan_cost_samples (query_name, scenario, total_cost, actual_total_time_ms)
    VALUES (
        'Q2_type_90d_volume',
        'after_optimized',
        (plan_json -> 0 -> 'Plan' ->> 'Total Cost')::numeric,
        (plan_json -> 0 -> 'Plan' ->> 'Actual Total Time')::numeric
    );

    -- Q3
    PERFORM set_config('enable_indexscan', 'off', true);
    PERFORM set_config('enable_bitmapscan', 'off', true);
    PERFORM set_config('enable_indexonlyscan', 'off', true);
    EXECUTE $Q$
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        WITH q3_bounds_adim7 AS (
            SELECT MAX(order_time) - INTERVAL '7 day' AS cutoff
            FROM orders
        ),
        q3_adim7 AS (
            SELECT
                date_trunc('hour', o.order_time) AS hour_bucket
            FROM orders o
            CROSS JOIN q3_bounds_adim7 b
            WHERE o.order_time >= b.cutoff
        )
        SELECT
            q3.hour_bucket,
            COUNT(*) AS order_count
        FROM q3_adim7 q3
        GROUP BY q3.hour_bucket
        ORDER BY q3.hour_bucket DESC
    $Q$
    INTO plan_json;

    INSERT INTO perf_plan_cost_samples (query_name, scenario, total_cost, actual_total_time_ms)
    VALUES (
        'Q3_hourly_7d_density',
        'before_simulated',
        (plan_json -> 0 -> 'Plan' ->> 'Total Cost')::numeric,
        (plan_json -> 0 -> 'Plan' ->> 'Actual Total Time')::numeric
    );

    PERFORM set_config('enable_indexscan', 'on', true);
    PERFORM set_config('enable_bitmapscan', 'on', true);
    PERFORM set_config('enable_indexonlyscan', 'on', true);
    EXECUTE $Q$
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        WITH q3_bounds_adim7 AS (
            SELECT MAX(order_time) - INTERVAL '7 day' AS cutoff
            FROM orders
        ),
        q3_adim7 AS (
            SELECT
                date_trunc('hour', o.order_time) AS hour_bucket
            FROM orders o
            CROSS JOIN q3_bounds_adim7 b
            WHERE o.order_time >= b.cutoff
        )
        SELECT
            q3.hour_bucket,
            COUNT(*) AS order_count
        FROM q3_adim7 q3
        GROUP BY q3.hour_bucket
        ORDER BY q3.hour_bucket DESC
    $Q$
    INTO plan_json;

    INSERT INTO perf_plan_cost_samples (query_name, scenario, total_cost, actual_total_time_ms)
    VALUES (
        'Q3_hourly_7d_density',
        'after_optimized',
        (plan_json -> 0 -> 'Plan' ->> 'Total Cost')::numeric,
        (plan_json -> 0 -> 'Plan' ->> 'Actual Total Time')::numeric
    );
END
$$;

-- -----------------------------------------------------
-- E) Süre farkı tablosu (Adım 2 vs Adım 7)
-- -----------------------------------------------------
WITH baseline AS (
    SELECT DISTINCT ON (query_name)
        query_name,
        mean_exec_time_ms,
        total_exec_time_ms,
        measured_at
    FROM perf_baseline_measurements
    WHERE note = 'Adım 2 başlangıç ölçümü'
    ORDER BY query_name, measured_at DESC
),
final AS (
    SELECT DISTINCT ON (query_name)
        query_name,
        mean_exec_time_ms,
        total_exec_time_ms,
        measured_at
    FROM perf_final_measurements
    WHERE note = 'Adım 7 final ölçümü'
    ORDER BY query_name, measured_at DESC
)
SELECT
    b.query_name,
    ROUND(b.mean_exec_time_ms::numeric, 3) AS before_mean_ms,
    ROUND(f.mean_exec_time_ms::numeric, 3) AS after_mean_ms,
    ROUND((b.mean_exec_time_ms - f.mean_exec_time_ms)::numeric, 3) AS mean_ms_gain,
    ROUND((100.0 * (b.mean_exec_time_ms - f.mean_exec_time_ms) / NULLIF(b.mean_exec_time_ms, 0))::numeric, 2) AS mean_gain_pct,
    ROUND(b.total_exec_time_ms::numeric, 3) AS before_total_ms,
    ROUND(f.total_exec_time_ms::numeric, 3) AS after_total_ms,
    b.measured_at AS before_measured_at,
    f.measured_at AS after_measured_at
FROM baseline b
JOIN final f USING (query_name)
ORDER BY mean_gain_pct DESC NULLS LAST;

-- -----------------------------------------------------
-- F) Maliyet farkı tablosu
-- -----------------------------------------------------
WITH last_samples AS (
    SELECT
        query_name,
        scenario,
        total_cost,
        actual_total_time_ms,
        ROW_NUMBER() OVER (PARTITION BY query_name, scenario ORDER BY captured_at DESC, id DESC) AS rn
    FROM perf_plan_cost_samples
),
p AS (
    SELECT
        query_name,
        MAX(CASE WHEN scenario = 'before_simulated' AND rn = 1 THEN total_cost END) AS before_cost,
        MAX(CASE WHEN scenario = 'after_optimized'  AND rn = 1 THEN total_cost END) AS after_cost,
        MAX(CASE WHEN scenario = 'before_simulated' AND rn = 1 THEN actual_total_time_ms END) AS before_actual_ms,
        MAX(CASE WHEN scenario = 'after_optimized'  AND rn = 1 THEN actual_total_time_ms END) AS after_actual_ms
    FROM last_samples
    GROUP BY query_name
)
SELECT
    query_name,
    ROUND(before_cost, 3) AS before_cost,
    ROUND(after_cost, 3) AS after_cost,
    ROUND(before_cost - after_cost, 3) AS cost_gain,
    ROUND((100.0 * (before_cost - after_cost) / NULLIF(before_cost, 0)), 2) AS cost_gain_pct,
    ROUND(before_actual_ms, 3) AS before_actual_ms,
    ROUND(after_actual_ms, 3) AS after_actual_ms
FROM p
ORDER BY cost_gain_pct DESC NULLS LAST;

-- -----------------------------------------------------
-- G) Metinsel grafik (bar) - süre karşılaştırması
-- -----------------------------------------------------
WITH baseline AS (
    SELECT DISTINCT ON (query_name)
        query_name,
        mean_exec_time_ms AS before_mean_ms
    FROM perf_baseline_measurements
    WHERE note = 'Adım 2 başlangıç ölçümü'
    ORDER BY query_name, measured_at DESC
),
final AS (
    SELECT DISTINCT ON (query_name)
        query_name,
        mean_exec_time_ms AS after_mean_ms
    FROM perf_final_measurements
    WHERE note = 'Adım 7 final ölçümü'
    ORDER BY query_name, measured_at DESC
),
d AS (
    SELECT
        b.query_name,
        b.before_mean_ms,
        f.after_mean_ms
    FROM baseline b
    JOIN final f USING (query_name)
),
m AS (
    SELECT MAX(GREATEST(before_mean_ms, after_mean_ms)) AS max_ms
    FROM d
)
SELECT
    d.query_name,
    ROUND(d.before_mean_ms::numeric, 3) AS before_ms,
    ROUND(d.after_mean_ms::numeric, 3) AS after_ms,
    repeat('#', GREATEST(1, ROUND((40.0 * d.before_mean_ms / NULLIF(m.max_ms, 0)))::int)) AS before_bar,
    repeat('#', GREATEST(1, ROUND((40.0 * d.after_mean_ms / NULLIF(m.max_ms, 0)))::int)) AS after_bar
FROM d
CROSS JOIN m
ORDER BY d.query_name;
