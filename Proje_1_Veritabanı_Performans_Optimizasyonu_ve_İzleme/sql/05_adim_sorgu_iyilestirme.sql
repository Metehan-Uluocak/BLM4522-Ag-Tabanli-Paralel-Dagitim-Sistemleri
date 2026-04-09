-- Adım 5: Sorgu iyileştirme (SELECT * azaltma, erken filtre, alt sorgu dönüşümü)
-- Bu dosyayı blm4522_perf veritabanında çalıştır.

CREATE TABLE IF NOT EXISTS perf_query_rewrite_results (
    id BIGSERIAL PRIMARY KEY,
    case_name TEXT NOT NULL,
    version_name TEXT NOT NULL,
    measured_at TIMESTAMP NOT NULL DEFAULT NOW(),
    note TEXT
);

-- -----------------------------------------------------
-- CASE 1: SELECT * yerine gerekli sütunlar
-- -----------------------------------------------------
-- Kötü örnek
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders o
WHERE o.order_time >= NOW() - INTERVAL '30 day'
ORDER BY o.order_time DESC
LIMIT 500;

-- İyileştirilmiş örnek
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    o.order_id,
    o.user_id,
    o.instrument_id,
    o.quantity,
    o.price,
    o.order_time
FROM orders o
WHERE o.order_time >= NOW() - INTERVAL '30 day'
ORDER BY o.order_time DESC
LIMIT 500;

INSERT INTO perf_query_rewrite_results (case_name, version_name, note)
VALUES
('CASE1_select_columns', 'before_select_star', 'SELECT * kullanımı'),
('CASE1_select_columns', 'after_needed_columns', 'Sadece gerekli sütunlar seçildi');

-- -----------------------------------------------------
-- CASE 2: Erken filtreleme
-- -----------------------------------------------------
-- Kötü örnek (önce join, sonra filtre)
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    o.order_id,
    u.username,
    i.symbol,
    t.executed_price,
    t.executed_at
FROM orders o
JOIN users u ON u.user_id = o.user_id
JOIN instruments i ON i.instrument_id = o.instrument_id
JOIN trades t ON t.order_id = o.order_id
WHERE t.executed_at >= NOW() - INTERVAL '90 day'
ORDER BY t.executed_at DESC
LIMIT 1000;

-- İyileştirilmiş örnek (filtreyi öne al)
EXPLAIN (ANALYZE, BUFFERS)
WITH recent_trades AS (
    SELECT order_id, executed_price, executed_at
    FROM trades
    WHERE executed_at >= NOW() - INTERVAL '90 day'
)
SELECT
    o.order_id,
    u.username,
    i.symbol,
    rt.executed_price,
    rt.executed_at
FROM recent_trades rt
JOIN orders o ON o.order_id = rt.order_id
JOIN users u ON u.user_id = o.user_id
JOIN instruments i ON i.instrument_id = o.instrument_id
ORDER BY rt.executed_at DESC
LIMIT 1000;

INSERT INTO perf_query_rewrite_results (case_name, version_name, note)
VALUES
('CASE2_early_filter', 'before_filter_late', 'Filtre geç uygulandı'),
('CASE2_early_filter', 'after_filter_early', 'Filtre join öncesi uygulandı');

-- -----------------------------------------------------
-- CASE 3: Maliyetli alt sorguyu dönüştürme
-- -----------------------------------------------------
-- Kötü örnek (korelasyonlu alt sorgu)
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    o.user_id,
    (
        SELECT COUNT(*)
        FROM orders o2
        WHERE o2.user_id = o.user_id
          AND o2.order_time >= NOW() - INTERVAL '30 day'
    ) AS user_order_count_30d
FROM orders o
GROUP BY o.user_id
LIMIT 500;

-- İyileştirilmiş örnek (tek geçişte toplama)
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    o.user_id,
    COUNT(*) FILTER (WHERE o.order_time >= NOW() - INTERVAL '30 day') AS user_order_count_30d
FROM orders o
GROUP BY o.user_id
LIMIT 500;

INSERT INTO perf_query_rewrite_results (case_name, version_name, note)
VALUES
('CASE3_subquery_rewrite', 'before_correlated_subquery', 'Korelasyonlu alt sorgu'),
('CASE3_subquery_rewrite', 'after_aggregate_filter', 'Aggregate + FILTER ile sadeleştirildi');

-- Sonuç kayıtları
SELECT id, case_name, version_name, measured_at, note
FROM perf_query_rewrite_results
ORDER BY id DESC;
