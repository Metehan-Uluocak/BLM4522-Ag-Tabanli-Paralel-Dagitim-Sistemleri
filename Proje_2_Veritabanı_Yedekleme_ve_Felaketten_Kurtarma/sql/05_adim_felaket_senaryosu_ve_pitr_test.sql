-- Adim 5: Kontrollu veri silme + PITR test hazirligi
-- Not: Gercek PITR islemi PostgreSQL servis seviyesi adimlar gerektirir.

-- 1) Olay kayit tablosu
CREATE TABLE IF NOT EXISTS dr_plan.incident_log (
    incident_id BIGSERIAL PRIMARY KEY,
    incident_name TEXT NOT NULL,
    incident_time TIMESTAMP NOT NULL,
    target_recovery_time TIMESTAMP,
    status TEXT NOT NULL CHECK (status IN ('planned', 'executed', 'recovered', 'failed')),
    note TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 2) Test tablosu (gercek veriyi bozmamak icin)
CREATE TABLE IF NOT EXISTS dr_plan.pitr_test_data (
    id BIGSERIAL PRIMARY KEY,
    payload TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 3) Test verisi ekle
INSERT INTO dr_plan.pitr_test_data (payload)
SELECT 'pitr_test_row_' || gs::text
FROM generate_series(1, 20) AS gs;

-- 4) Silme oncesi sayim
SELECT COUNT(*) AS before_delete_count
FROM dr_plan.pitr_test_data;

-- 5) Kontrollu silme olayi kaydi
INSERT INTO dr_plan.incident_log (
    incident_name,
    incident_time,
    target_recovery_time,
    status,
    note
)
VALUES (
    'Adim 5 kontrollu silme',
    NOW(),
    NOW() - INTERVAL '5 second',
    'executed',
    'PITR testi icin dr_plan.pitr_test_data tablosundan kontrollu silme yapilacak'
);

-- 6) Kontrollu silme (ilk 5 kayit)
DELETE FROM dr_plan.pitr_test_data
WHERE id IN (
    SELECT id
    FROM dr_plan.pitr_test_data
    ORDER BY id
    LIMIT 5
);

-- 7) Silme sonrasi sayim
SELECT COUNT(*) AS after_delete_count
FROM dr_plan.pitr_test_data;

-- 8) Son incident durumunu gor
SELECT
    incident_id,
    incident_name,
    incident_time,
    target_recovery_time,
    status,
    note,
    created_at
FROM dr_plan.incident_log
ORDER BY incident_id DESC
LIMIT 10;

-- 9) PITR uygulama notu (manual)
-- - Son fiziksel yedekten geri don.
-- - postgresql.auto.conf veya recovery.signal yapisini kullan.
-- - recovery_target_time = incident_time oncesi bir zaman olarak ayarla.
-- - Servisi baslat, recovery bitince tutarlilik sorgularini calistir.
