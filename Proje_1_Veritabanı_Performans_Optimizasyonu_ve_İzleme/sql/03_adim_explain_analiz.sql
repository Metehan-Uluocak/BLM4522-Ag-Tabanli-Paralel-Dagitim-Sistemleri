-- Adım 3: EXPLAIN (ANALYZE, BUFFERS) ile yavaş sorgu analizi
-- Bu dosyayı blm4522_perf veritabanında çalıştır.

CREATE TABLE IF NOT EXISTS perf_explain_notes (
    id BIGSERIAL PRIMARY KEY,
    query_name TEXT NOT NULL,
    stage TEXT NOT NULL,
    potential_issue TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Önce planları temiz görmek için istatistik güncelle
ANALYZE users;
ANALYZE instruments;
ANALYZE orders;
ANALYZE trades;

-- Q1: Kullanıcı bazlı son 30 gün işlem özeti
EXPLAIN (ANALYZE, BUFFERS)
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
EXPLAIN (ANALYZE, BUFFERS)
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
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    date_trunc('hour', o.order_time) AS hour_bucket,
    COUNT(*) AS order_count
FROM orders o
WHERE o.order_time >= NOW() - INTERVAL '7 day'
GROUP BY hour_bucket
ORDER BY hour_bucket DESC;

-- Q4: Bilinçli olarak maliyetli örnek (fonksiyon + geniş sıralama)
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    o.order_id,
    o.user_id,
    o.instrument_id,
    o.quantity,
    o.price,
    o.order_time
FROM orders o
WHERE date_trunc('day', o.order_time) >= date_trunc('day', NOW() - INTERVAL '120 day')
ORDER BY (o.quantity * o.price) DESC
LIMIT 500;

-- Plan notlarını rapora koymak için başlangıç kayıtları
INSERT INTO perf_explain_notes (query_name, stage, potential_issue, note)
VALUES
('Q1_user_30d_summary', 'before_index', 'Seq Scan / Sort var mı kontrol et', 'EXPLAIN çıktısında node türlerini not et'),
('Q2_type_90d_volume', 'before_index', 'Kötü Join (Hash Join + yüksek cost) var mı kontrol et', 'Join stratejisini rapora yaz'),
('Q3_hourly_7d_density', 'before_index', 'Sort maliyeti yüksek mi kontrol et', 'Buffers ve execution time değerlerini yaz'),
('Q4_costly_function_sort', 'before_index', 'Fonksiyon nedeniyle indeks kullanmama durumu kontrol et', 'date_trunc kullanımının etkisini not et');

-- Adım 3 ekran görüntüsü için not listesi
SELECT id, query_name, stage, potential_issue, note, created_at
FROM perf_explain_notes
ORDER BY id DESC;
