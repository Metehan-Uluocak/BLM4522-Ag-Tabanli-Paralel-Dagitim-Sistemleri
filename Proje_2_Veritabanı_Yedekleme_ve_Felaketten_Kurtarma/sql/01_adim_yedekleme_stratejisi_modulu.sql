-- Adım 1: Yedekleme stratejisi modülü (PostgreSQL)
-- Bu dosyayı proje veritabanınızda çalıştırın.

-- 1) Şema
CREATE SCHEMA IF NOT EXISTS dr_plan;

-- 2) Politika üst bilgisi
CREATE TABLE IF NOT EXISTS dr_plan.backup_policy (
    policy_id BIGSERIAL PRIMARY KEY,
    policy_name TEXT NOT NULL UNIQUE,
    rpo_minutes INTEGER NOT NULL CHECK (rpo_minutes > 0),
    rto_minutes INTEGER NOT NULL CHECK (rto_minutes > 0),
    full_backup_frequency TEXT NOT NULL,
    wal_archiving_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 3) Saklama kuralları
CREATE TABLE IF NOT EXISTS dr_plan.retention_rules (
    rule_id BIGSERIAL PRIMARY KEY,
    policy_id BIGINT NOT NULL REFERENCES dr_plan.backup_policy(policy_id) ON DELETE CASCADE,
    artifact_type TEXT NOT NULL,
    retention_days INTEGER NOT NULL CHECK (retention_days > 0),
    note TEXT,
    UNIQUE (policy_id, artifact_type)
);

-- 4) Kritik varlık sınıflandırması
CREATE TABLE IF NOT EXISTS dr_plan.critical_data_assets (
    asset_id BIGSERIAL PRIMARY KEY,
    policy_id BIGINT NOT NULL REFERENCES dr_plan.backup_policy(policy_id) ON DELETE CASCADE,
    table_name TEXT NOT NULL,
    criticality_level TEXT NOT NULL CHECK (criticality_level IN ('Tier-1', 'Tier-2', 'Tier-3')),
    recovery_priority INTEGER NOT NULL CHECK (recovery_priority BETWEEN 1 AND 10),
    rationale TEXT,
    UNIQUE (policy_id, table_name)
);

-- 5) Adım 1 politika kaydı (idempotent)
INSERT INTO dr_plan.backup_policy (
    policy_name,
    rpo_minutes,
    rto_minutes,
    full_backup_frequency,
    wal_archiving_enabled
)
VALUES (
    'BLM4522_DR_POLICY_V1',
    15,
    60,
    'Haftalik fiziksel + gunluk mantiksal tam yedek',
    TRUE
)
ON CONFLICT (policy_name)
DO UPDATE SET
    rpo_minutes = EXCLUDED.rpo_minutes,
    rto_minutes = EXCLUDED.rto_minutes,
    full_backup_frequency = EXCLUDED.full_backup_frequency,
    wal_archiving_enabled = EXCLUDED.wal_archiving_enabled,
    updated_at = NOW();

-- 6) Saklama kurallarını ekle/guncelle
WITH p AS (
    SELECT policy_id
    FROM dr_plan.backup_policy
    WHERE policy_name = 'BLM4522_DR_POLICY_V1'
)
INSERT INTO dr_plan.retention_rules (policy_id, artifact_type, retention_days, note)
SELECT p.policy_id, x.artifact_type, x.retention_days, x.note
FROM p
JOIN (
    VALUES
        ('full_backup', 35, 'Haftalik tam yedekler en az 5 hafta saklanir'),
        ('wal_archive', 7, 'PITR icin WAL dosyalari saklanir'),
        ('backup_log', 90, 'Denetim ve izleme amacli log saklama suresi')
) AS x(artifact_type, retention_days, note)
ON TRUE
ON CONFLICT (policy_id, artifact_type)
DO UPDATE SET
    retention_days = EXCLUDED.retention_days,
    note = EXCLUDED.note;

-- 7) Kritik tabloları ekle/guncelle
WITH p AS (
    SELECT policy_id
    FROM dr_plan.backup_policy
    WHERE policy_name = 'BLM4522_DR_POLICY_V1'
)
INSERT INTO dr_plan.critical_data_assets (
    policy_id,
    table_name,
    criticality_level,
    recovery_priority,
    rationale
)
SELECT
    p.policy_id,
    x.table_name,
    x.criticality_level,
    x.recovery_priority,
    x.rationale
FROM p
JOIN (
    VALUES
        ('orders', 'Tier-1', 10, 'Islem devamliligi icin en kritik islem tablosu'),
        ('trades', 'Tier-1', 10, 'Finansal gerceklesme kayitlari, kritik denetim verisi'),
        ('users', 'Tier-2', 7, 'Kullanici kimlik ve iliski verileri'),
        ('instruments', 'Tier-3', 5, 'Referans enstruman sozlugu')
) AS x(table_name, criticality_level, recovery_priority, rationale)
ON TRUE
ON CONFLICT (policy_id, table_name)
DO UPDATE SET
    criticality_level = EXCLUDED.criticality_level,
    recovery_priority = EXCLUDED.recovery_priority,
    rationale = EXCLUDED.rationale;

-- 8) Dogrulama sorguları
SELECT
    bp.policy_name,
    bp.rpo_minutes,
    bp.rto_minutes,
    bp.full_backup_frequency,
    bp.wal_archiving_enabled,
    bp.updated_at
FROM dr_plan.backup_policy bp
WHERE bp.policy_name = 'BLM4522_DR_POLICY_V1';

SELECT
    rr.artifact_type,
    rr.retention_days,
    rr.note
FROM dr_plan.retention_rules rr
JOIN dr_plan.backup_policy bp ON bp.policy_id = rr.policy_id
WHERE bp.policy_name = 'BLM4522_DR_POLICY_V1'
ORDER BY rr.artifact_type;

SELECT
    cda.table_name,
    cda.criticality_level,
    cda.recovery_priority,
    cda.rationale
FROM dr_plan.critical_data_assets cda
JOIN dr_plan.backup_policy bp ON bp.policy_id = cda.policy_id
WHERE bp.policy_name = 'BLM4522_DR_POLICY_V1'
ORDER BY cda.recovery_priority DESC, cda.table_name;
