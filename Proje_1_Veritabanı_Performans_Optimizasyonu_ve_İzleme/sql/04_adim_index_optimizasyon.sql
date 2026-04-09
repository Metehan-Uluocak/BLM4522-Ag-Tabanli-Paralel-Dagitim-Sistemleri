-- Adım 4: İndeks yönetimi ve tekrar ölçüm
-- Bu dosyayı blm4522_perf veritabanında çalıştır.

CREATE TABLE IF NOT EXISTS perf_index_actions (
    id BIGSERIAL PRIMARY KEY,
    action_type TEXT NOT NULL,
    index_name TEXT NOT NULL,
    target_table TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- WHERE ve JOIN alanları için uygun indeksler
CREATE INDEX IF NOT EXISTS idx_orders_order_time ON orders(order_time);
CREATE INDEX IF NOT EXISTS idx_orders_user_time ON orders(user_id, order_time);
CREATE INDEX IF NOT EXISTS idx_orders_instrument_id ON orders(instrument_id);
CREATE INDEX IF NOT EXISTS idx_trades_order_id ON trades(order_id);
CREATE INDEX IF NOT EXISTS idx_trades_executed_at ON trades(executed_at);

-- Bilinçli sorgular için composite indeks
CREATE INDEX IF NOT EXISTS idx_trades_executed_at_order_id ON trades(executed_at, order_id);

INSERT INTO perf_index_actions (action_type, index_name, target_table, note)
VALUES
('CREATE', 'idx_orders_order_time', 'orders', 'Zaman filtresi için'),
('CREATE', 'idx_orders_user_time', 'orders', 'Kullanıcı + zaman filtre/grup için'),
('CREATE', 'idx_orders_instrument_id', 'orders', 'instruments join için'),
('CREATE', 'idx_trades_order_id', 'trades', 'orders join için'),
('CREATE', 'idx_trades_executed_at', 'trades', 'zaman filtresi için'),
('CREATE', 'idx_trades_executed_at_order_id', 'trades', 'farklı join+filter desenleri için');

ANALYZE users;
ANALYZE instruments;
ANALYZE orders;
ANALYZE trades;

-- Adım 3 sorgularını tekrar planla ve farkı kıyasla
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

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    date_trunc('hour', o.order_time) AS hour_bucket,
    COUNT(*) AS order_count
FROM orders o
WHERE o.order_time >= NOW() - INTERVAL '7 day'
GROUP BY hour_bucket
ORDER BY hour_bucket DESC;

-- İndeks kullanımını izle
SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE relname IN ('orders', 'trades')
ORDER BY idx_scan DESC, relname, indexrelname;

-- Kullanılmayan indeks kontrolü
SELECT
    s.schemaname,
    s.relname AS table_name,
    s.indexrelname AS index_name,
    s.idx_scan,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size
FROM pg_stat_user_indexes s
WHERE s.relname IN ('orders', 'trades')
  AND s.idx_scan = 0
ORDER BY pg_relation_size(s.indexrelid) DESC;

-- Gereksiz indeks silme örneği (hemen çalıştırma, önce kanıt topla)
-- DROP INDEX IF EXISTS idx_trades_executed_at_order_id;

SELECT id, action_type, index_name, target_table, note, created_at
FROM perf_index_actions
ORDER BY id DESC;
