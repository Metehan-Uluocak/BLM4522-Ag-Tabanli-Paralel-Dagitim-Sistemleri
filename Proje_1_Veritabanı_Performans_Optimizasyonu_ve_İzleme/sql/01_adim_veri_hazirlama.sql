-- Adım 1: Veri seti hazırlama ve ilk kontroller (PostgreSQL + pgAdmin)
--
-- =========================
-- A) SADECE "postgres" VERİTABANINDA ÇALIŞTIR
-- =========================

-- 1) Önce var mı kontrol et
SELECT datname FROM pg_database WHERE datname = 'blm4522_perf';

-- 2) Sonuç boşsa aşağıdaki komutu tek başına çalıştır
CREATE DATABASE blm4522_perf;

-- =========================
-- B) SADECE "blm4522_perf" VERİTABANINDA ÇALIŞTIR
-- =========================

CREATE TABLE IF NOT EXISTS users (
    user_id BIGINT PRIMARY KEY,
    username TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS instruments (
    instrument_id BIGINT PRIMARY KEY,
    symbol TEXT NOT NULL,
    instrument_type TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
    order_id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    instrument_id BIGINT NOT NULL,
    side TEXT NOT NULL,
    quantity NUMERIC(18,4) NOT NULL,
    price NUMERIC(18,4) NOT NULL,
    order_time TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (instrument_id) REFERENCES instruments(instrument_id)
);

CREATE TABLE IF NOT EXISTS trades (
    trade_id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL,
    executed_qty NUMERIC(18,4) NOT NULL,
    executed_price NUMERIC(18,4) NOT NULL,
    executed_at TIMESTAMP NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- =========================
-- C) ÖRNEK VERİ ÜRETİMİ (1M+ SATIR)
-- =========================

-- Kullanıcılar (10.000)
INSERT INTO users (user_id, username, created_at)
SELECT gs, 'user_' || gs, NOW() - (gs % 365) * INTERVAL '1 day'
FROM generate_series(1, 10000) AS gs
ON CONFLICT (user_id) DO NOTHING;

-- Enstrümanlar (200)
INSERT INTO instruments (instrument_id, symbol, instrument_type)
SELECT gs,
       'SYM' || gs,
       CASE
           WHEN gs % 3 = 0 THEN 'Hisse'
           WHEN gs % 3 = 1 THEN 'ETF'
           ELSE 'Altın'
       END
FROM generate_series(1, 200) AS gs
ON CONFLICT (instrument_id) DO NOTHING;

-- Emirler (1.000.000)
INSERT INTO orders (order_id, user_id, instrument_id, side, quantity, price, order_time)
SELECT gs,
       (1 + (random() * 9999)::int),
       (1 + (random() * 199)::int),
       CASE WHEN random() < 0.5 THEN 'BUY' ELSE 'SELL' END,
       round((1 + random() * 100)::numeric, 4),
       round((5 + random() * 500)::numeric, 4),
       NOW()
         - ((random() * 365)::int * INTERVAL '1 day')
         - ((random() * 86400)::int * INTERVAL '1 second')
FROM generate_series(1, 1000000) AS gs
ON CONFLICT (order_id) DO NOTHING;

-- İşlemler (1.000.000, orders ile 1-1)
INSERT INTO trades (trade_id, order_id, executed_qty, executed_price, executed_at)
SELECT o.order_id,
       o.order_id,
       o.quantity,
       o.price + round((random() * 2 - 1)::numeric, 4),
       o.order_time + ((random() * 600)::int * INTERVAL '1 second')
FROM orders o
ON CONFLICT (trade_id) DO NOTHING;

-- Veri kalite kontrolleri
SELECT COUNT(*) AS total_orders FROM orders;
SELECT COUNT(*) AS null_user_id FROM orders WHERE user_id IS NULL;
SELECT COUNT(*) AS null_order_time FROM orders WHERE order_time IS NULL;

-- Yinelenen kayıt kontrolü
SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Veri yoğunluğu (günlük)
SELECT date_trunc('day', order_time) AS gun, COUNT(*) AS kayit_sayisi
FROM orders
GROUP BY 1
ORDER BY 1 DESC
LIMIT 14;

-- Disk alanı başlangıç ölçümü
SELECT pg_size_pretty(pg_database_size('blm4522_perf')) AS db_size;
SELECT relname AS table_name, pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
