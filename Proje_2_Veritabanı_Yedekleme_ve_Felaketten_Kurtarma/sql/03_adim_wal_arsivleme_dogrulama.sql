-- Adim 3: WAL arsivleme yapilandirma dogrulamasi (PostgreSQL)
-- Bu dosya, archive_mode/archive_command aktif olduktan sonra calistirilir.

-- 1) Yapilandirma kontrolu
SELECT
    current_setting('archive_mode', true) AS archive_mode,
    current_setting('archive_command', true) AS archive_command,
    current_setting('wal_level', true) AS wal_level,
    current_setting('max_wal_senders', true) AS max_wal_senders,
    current_setting('archive_timeout', true) AS archive_timeout;

-- 2) WAL switch tetikle
SELECT pg_switch_wal() AS switched_wal_lsn;
CHECKPOINT;

-- 3) Archiver istatistikleri
SELECT
    archived_count,
    failed_count,
    last_archived_wal,
    last_archived_time,
    last_failed_wal,
    last_failed_time,
    stats_reset
FROM pg_stat_archiver;

-- 4) Kanit kaydi icin tablo
CREATE TABLE IF NOT EXISTS dr_plan.wal_archive_checks (
    check_id BIGSERIAL PRIMARY KEY,
    archive_mode TEXT,
    archive_command TEXT,
    wal_level TEXT,
    archived_count BIGINT,
    failed_count BIGINT,
    last_archived_wal TEXT,
    last_archived_time TIMESTAMP WITH TIME ZONE,
    measured_at TIMESTAMP NOT NULL DEFAULT NOW(),
    note TEXT
);

-- 5) Son durumu kaydet
INSERT INTO dr_plan.wal_archive_checks (
    archive_mode,
    archive_command,
    wal_level,
    archived_count,
    failed_count,
    last_archived_wal,
    last_archived_time,
    note
)
SELECT
    current_setting('archive_mode', true),
    current_setting('archive_command', true),
    current_setting('wal_level', true),
    s.archived_count,
    s.failed_count,
    s.last_archived_wal,
    s.last_archived_time,
    'Adim 3 WAL arsivleme dogrulamasi'
FROM pg_stat_archiver s;

-- 6) Son kontrol
SELECT
    check_id,
    archive_mode,
    wal_level,
    archived_count,
    failed_count,
    last_archived_wal,
    last_archived_time,
    measured_at
FROM dr_plan.wal_archive_checks
ORDER BY check_id DESC
LIMIT 10;
