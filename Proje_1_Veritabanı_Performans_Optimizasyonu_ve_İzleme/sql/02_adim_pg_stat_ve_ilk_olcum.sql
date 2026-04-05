-- Adım 2: pg_stat_statements etkinleştirme + kritik sorgu ölçümü + ilk ölçüm tablosu
-- Bu dosyayı blm4522_perf veritabanında çalıştır.

-- =====================================================
-- A) pg_stat_statements hazır mı kontrol et
-- =====================================================
SHOW shared_preload_libraries;


CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

SELECT extname AS extension_name, extversion
FROM pg_extension
WHERE extname = 'pg_stat_statements';

-- =====================================================
-- B) İlk ölçüm tablosu
-- =====================================================
CREATE TABLE IF NOT EXISTS perf_baseline_measurements (
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

-- Ölçüm öncesi mevcut pg_stat istatistiklerini sıfırla
SELECT pg_stat_statements_reset();

-- =====================================================
-- C) Kritik sorguları çalıştır (baseline)
-- =====================================================
-- Q1: Kullanıcı bazlı son 30 gün işlem özeti
SELECT
    o.user_id,
    COUNT(*) AS order_count,
    SUM(o.quantity * o.price) AS gross_value
FROM orders o
WHERE o.order_time >= NOW() - INTERVAL '30 day'
GROUP BY o.user_id
ORDER BY gross_value DESC
LIMIT 100;

-- Q2: Enstrüman türüne göre son 90 gün hacim
SELECT
    i.instrument_type,
    COUNT(*) AS trade_count,
    SUM(t.executed_qty * t.executed_price) AS volume
FROM trades t
JOIN orders o ON o.order_id = t.order_id
JOIN instruments i ON i.instrument_id = o.instrument_id
WHERE t.executed_at >= NOW() - INTERVAL '90 day'
GROUP BY i.instrument_type
ORDER BY volume DESC;

-- Q3: Saatlik yoğunluk analizi (son 7 gün)
SELECT
    date_trunc('hour', o.order_time) AS hour_bucket,
    COUNT(*) AS order_count
FROM orders o
WHERE o.order_time >= NOW() - INTERVAL '7 day'
GROUP BY hour_bucket
ORDER BY hour_bucket DESC;

-- =====================================================
-- D) pg_stat_statements üzerinden ilk ölçümü kaydet
-- =====================================================
DELETE FROM perf_baseline_measurements
WHERE note = 'Adım 2 başlangıç ölçümü';

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
    WHERE q LIKE '%from orders o%'
      AND q LIKE '%group by o.user_id%'
      AND q LIKE '%sum(o.quantity * o.price)%'
    ORDER BY total_exec_time DESC
    LIMIT 1
),
q2 AS (
    SELECT *
    FROM stats
    WHERE q LIKE '%from trades t%'
      AND q LIKE '%join orders o on o.order_id = t.order_id%'
      AND q LIKE '%join instruments i on i.instrument_id = o.instrument_id%'
      AND q LIKE '%group by i.instrument_type%'
    ORDER BY total_exec_time DESC
    LIMIT 1
),
q3 AS (
    SELECT *
    FROM stats
    WHERE q LIKE '%date_trunc(''hour'', o.order_time)%'
      AND q LIKE '%from orders o%'
      AND q LIKE '%group by hour_bucket%'
    ORDER BY total_exec_time DESC
    LIMIT 1
)
INSERT INTO perf_baseline_measurements
(query_name, query_id, calls, total_exec_time_ms, mean_exec_time_ms, rows_returned, note)
SELECT
    'Q1_user_30d_summary' AS query_name,
    q1.queryid,
    q1.calls,
    q1.total_exec_time,
    q1.mean_exec_time,
    q1.rows,
    'Adım 2 başlangıç ölçümü'
FROM q1
UNION ALL
SELECT
    'Q2_type_90d_volume',
    q2.queryid,
    q2.calls,
    q2.total_exec_time,
    q2.mean_exec_time,
    q2.rows,
    'Adım 2 başlangıç ölçümü'
FROM q2
UNION ALL
SELECT
    'Q3_hourly_7d_density',
    q3.queryid,
    q3.calls,
    q3.total_exec_time,
    q3.mean_exec_time,
    q3.rows,
    'Adım 2 başlangıç ölçümü'
FROM q3;

-- =====================================================
-- E) Sonuçları göster 
-- =====================================================
SELECT
    id,
    query_name,
    calls,
    ROUND(total_exec_time_ms::numeric, 3) AS total_ms,
    ROUND(mean_exec_time_ms::numeric, 3) AS mean_ms,
    rows_returned,
    measured_at
FROM perf_baseline_measurements
ORDER BY id DESC;

