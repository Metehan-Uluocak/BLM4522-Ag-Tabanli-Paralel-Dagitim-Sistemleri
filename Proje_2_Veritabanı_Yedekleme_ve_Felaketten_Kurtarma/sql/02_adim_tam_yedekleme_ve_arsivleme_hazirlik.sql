-- Adim 2: Tam yedekleme ve WAL arsivleme hazirlik/dogrulama (PostgreSQL)
-- Bu dosyayi Adim 1 scriptinden sonra calistirin.

-- 1) Adim 1 politikasi  
SELECT
    bp.policy_name,
    bp.rpo_minutes,
    bp.rto_minutes,
    bp.full_backup_frequency,
    bp.wal_archiving_enabled,
    bp.updated_at
FROM dr_plan.backup_policy bp
WHERE bp.policy_name = 'BLM4522_DR_POLICY_V1';

-- 2) Adim 2 icin yedek envanteri tablosu
CREATE TABLE IF NOT EXISTS dr_plan.backup_inventory (
    backup_id BIGSERIAL PRIMARY KEY,
    backup_type TEXT NOT NULL CHECK (backup_type IN ('logical_full', 'physical_full')),
    backup_path TEXT NOT NULL,
    backup_size_bytes BIGINT,
    tool_name TEXT NOT NULL,
    checksum_sha256 TEXT,
    started_at TIMESTAMP NOT NULL,
    finished_at TIMESTAMP NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('success', 'failed')),
    note TEXT
);

-- 3) WAL ayarlarini oku (superuser yetkisi gerektirir)
-- Not: current_setting(..., true) ile ayar yoksa NULL doner.
SELECT
    current_setting('archive_mode', true) AS archive_mode,
    current_setting('archive_command', true) AS archive_command,
    current_setting('wal_level', true) AS wal_level,
    current_setting('max_wal_senders', true) AS max_wal_senders,
    current_setting('archive_timeout', true) AS archive_timeout;

-- 4) WAL arsiv istatistikleri (PostgreSQL)
-- Dogru gorunum: pg_stat_archiver
SELECT
    archived_count,
    failed_count,
    last_archived_wal,
    last_archived_time,
    last_failed_wal,
    last_failed_time
FROM pg_stat_archiver;

-- 5) Adim 2 kaniti icin son yedek kayitlari (simdilik bos olabilir)
SELECT
    backup_id,
    backup_type,
    backup_path,
    backup_size_bytes,
    tool_name,
    status,
    started_at,
    finished_at
FROM dr_plan.backup_inventory
ORDER BY backup_id DESC
LIMIT 20;

-- 6) Gercek backup kayitlarini envantere ekle (idempotent)
-- Not: Bu bolum tekrar calistirilsa da ayni backup_path ikinci kez eklenmez.

-- Placeholder test kaydini temizle (varsa)
DELETE FROM dr_plan.backup_inventory
WHERE backup_path LIKE '%YYYYMMDD_HHMMSS%';

-- Logical full backup kaydi
INSERT INTO dr_plan.backup_inventory (
    backup_type,
    backup_path,
    backup_size_bytes,
    tool_name,
    checksum_sha256,
    started_at,
    finished_at,
    status,
    note
)
SELECT
    'logical_full',
    'D:/BLM4522/backups/logical/blm4522_dr_20260405_145753.dump',
    863,
    'pg_dump',
    NULL,
    TIMESTAMP '2026-04-05 14:57:53',
    TIMESTAMP '2026-04-05 14:58:16',
    'success',
    'Adim 2 gercek mantiksal tam yedek'
WHERE NOT EXISTS (
    SELECT 1
    FROM dr_plan.backup_inventory bi
    WHERE bi.backup_path = 'D:/BLM4522/backups/logical/blm4522_dr_20260405_145753.dump'
);

-- Physical full backup kaydi
INSERT INTO dr_plan.backup_inventory (
    backup_type,
    backup_path,
    backup_size_bytes,
    tool_name,
    checksum_sha256,
    started_at,
    finished_at,
    status,
    note
)
SELECT
    'physical_full',
    'D:/BLM4522/backups/physical/basebackup_20260405_145821',
    257572905,
    'pg_basebackup',
    NULL,
    TIMESTAMP '2026-04-05 14:58:21',
    TIMESTAMP '2026-04-05 14:58:28',
    'success',
    'Adim 2 gercek fiziksel tam yedek'
WHERE NOT EXISTS (
    SELECT 1
    FROM dr_plan.backup_inventory bi
    WHERE bi.backup_path = 'D:/BLM4522/backups/physical/basebackup_20260405_145821'
);

-- Son durum
SELECT
    backup_id,
    backup_type,
    backup_path,
    backup_size_bytes,
    tool_name,
    status,
    started_at,
    finished_at,
    note
FROM dr_plan.backup_inventory
ORDER BY backup_id DESC;
