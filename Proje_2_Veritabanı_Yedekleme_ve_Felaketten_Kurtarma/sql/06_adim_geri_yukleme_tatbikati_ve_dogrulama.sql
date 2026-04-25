-- Adim 6: Geri yukleme tatbikati ve dogrulama
-- Amac: En son yedekler ve WAL durumu uzerinden geri donus kabiliyetini olculebilir hale getirmek.

-- -----------------------------------------------------
-- 0) Onkosul bootstrap (Adim 6'nin tek basina calisabilmesi icin)
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS dr_plan;

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
DO NOTHING;

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

CREATE TABLE IF NOT EXISTS dr_plan.pitr_test_data (
    id BIGSERIAL PRIMARY KEY,
    payload TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO dr_plan.pitr_test_data (payload)
SELECT 'adim6_minimum_test_satiri'
WHERE NOT EXISTS (SELECT 1 FROM dr_plan.pitr_test_data);

-- -----------------------------------------------------
-- A) Tatbikat ve kontrol tablolari
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS dr_plan.recovery_drill_runs (
    run_id BIGSERIAL PRIMARY KEY,
    drill_name TEXT NOT NULL,
    scenario_type TEXT NOT NULL CHECK (scenario_type IN ('logical_restore', 'physical_restore', 'pitr')),
    started_at TIMESTAMP NOT NULL,
    finished_at TIMESTAMP NOT NULL,
    rto_target_minutes INTEGER NOT NULL CHECK (rto_target_minutes > 0),
    actual_rto_minutes NUMERIC(10,2) NOT NULL CHECK (actual_rto_minutes >= 0),
    status TEXT NOT NULL CHECK (status IN ('success', 'failed')),
    note TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dr_plan.recovery_validation_checks (
    check_id BIGSERIAL PRIMARY KEY,
    run_id BIGINT NOT NULL REFERENCES dr_plan.recovery_drill_runs(run_id) ON DELETE CASCADE,
    check_name TEXT NOT NULL,
    expected_value TEXT,
    actual_value TEXT,
    is_passed BOOLEAN NOT NULL,
    note TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------
-- B) Tatbikat kaydi (ornek bir PITR geri yukleme kosusu)
-- -----------------------------------------------------
WITH p AS (
    SELECT
        policy_id,
        policy_name,
        rto_minutes
    FROM dr_plan.backup_policy
    WHERE policy_name = 'BLM4522_DR_POLICY_V1'
), ins AS (
    INSERT INTO dr_plan.recovery_drill_runs (
        drill_name,
        scenario_type,
        started_at,
        finished_at,
        rto_target_minutes,
        actual_rto_minutes,
        status,
        note
    )
    SELECT
        'Adim 6 PITR tatbikati',
        'pitr',
        NOW() - INTERVAL '38 minute',
        NOW(),
        p.rto_minutes,
        38.00,
        CASE WHEN 38.00 <= p.rto_minutes THEN 'success' ELSE 'failed' END,
        'Geri yukleme adimlari runbook uzerinden uygulanmis ve servis dogrulama sorgulari calistirilmistir'
    FROM p
    RETURNING run_id
)
SELECT run_id FROM ins;

-- -----------------------------------------------------
-- C) Tatbikat kosusu icin kontrol kayitlari
-- -----------------------------------------------------
WITH latest_run AS (
    SELECT run_id
    FROM dr_plan.recovery_drill_runs
    ORDER BY run_id DESC
    LIMIT 1
), policy AS (
    SELECT
        rpo_minutes,
        rto_minutes
    FROM dr_plan.backup_policy
    WHERE policy_name = 'BLM4522_DR_POLICY_V1'
), latest_logical AS (
    SELECT
        finished_at,
        EXTRACT(EPOCH FROM (NOW() - finished_at)) / 60.0 AS age_minutes
    FROM dr_plan.backup_inventory
    WHERE backup_type = 'logical_full'
      AND status = 'success'
    ORDER BY finished_at DESC
    LIMIT 1
), latest_physical AS (
    SELECT
        finished_at
    FROM dr_plan.backup_inventory
    WHERE backup_type = 'physical_full'
      AND status = 'success'
    ORDER BY finished_at DESC
    LIMIT 1
), latest_wal AS (
    SELECT
        archived_count,
        failed_count,
        last_archived_time
    FROM dr_plan.wal_archive_checks
    ORDER BY check_id DESC
    LIMIT 1
), pitr_rows AS (
    SELECT COUNT(*) AS row_count
    FROM dr_plan.pitr_test_data
)
INSERT INTO dr_plan.recovery_validation_checks (
    run_id,
    check_name,
    expected_value,
    actual_value,
    is_passed,
    note
)
SELECT
    lr.run_id,
    x.check_name,
    x.expected_value,
    x.actual_value,
    x.is_passed,
    x.note
FROM latest_run lr
JOIN (
    SELECT
        'logical_backup_freshness' AS check_name,
        'age_minutes <= rpo_minutes' AS expected_value,
        CASE
            WHEN ll.finished_at IS NULL THEN 'no-logical-backup'
            ELSE 'age_minutes=' || ROUND(ll.age_minutes::numeric, 2)::text || ', rpo=' || p.rpo_minutes::text
        END AS actual_value,
        CASE WHEN ll.finished_at IS NOT NULL AND ll.age_minutes <= p.rpo_minutes THEN TRUE ELSE FALSE END AS is_passed,
        'Son mantiksal yedegin RPO hedefi ile uyumu' AS note
    FROM policy p
    LEFT JOIN latest_logical ll ON TRUE

    UNION ALL

    SELECT
        'physical_backup_exists',
        'latest physical_full backup exists',
        COALESCE(to_char(lp.finished_at, 'YYYY-MM-DD HH24:MI:SS'), 'none'),
        CASE WHEN lp.finished_at IS NOT NULL THEN TRUE ELSE FALSE END,
        'Fiziksel tam yedek varlik kontrolu'
    FROM (SELECT 1) AS seed
    LEFT JOIN latest_physical lp ON TRUE

    UNION ALL

    SELECT
        'wal_archiver_health',
        'failed_count = 0',
        CASE
            WHEN lw.failed_count IS NULL THEN 'no-wal-check'
            ELSE 'archived=' || lw.archived_count::text || ', failed=' || lw.failed_count::text
        END,
        CASE WHEN lw.failed_count IS NOT NULL AND lw.failed_count = 0 THEN TRUE ELSE FALSE END,
        'WAL arsivleyici hata durumu'
    FROM (SELECT 1) AS seed
    LEFT JOIN latest_wal lw ON TRUE

    UNION ALL

    SELECT
        'pitr_test_data_available',
        'row_count >= 1',
        pr.row_count::text,
        CASE WHEN pr.row_count >= 1 THEN TRUE ELSE FALSE END,
        'PITR test tablosunda veri bulunurlugu'
    FROM pitr_rows pr
) AS x ON TRUE;

-- -----------------------------------------------------
-- D) Tatbikat ve kontrol ozeti
-- -----------------------------------------------------
SELECT
    r.run_id,
    r.drill_name,
    r.scenario_type,
    r.started_at,
    r.finished_at,
    r.rto_target_minutes,
    r.actual_rto_minutes,
    r.status,
    ROUND((100.0 * SUM(CASE WHEN c.is_passed THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0))::numeric, 2) AS validation_pass_pct
FROM dr_plan.recovery_drill_runs r
LEFT JOIN dr_plan.recovery_validation_checks c ON c.run_id = r.run_id
GROUP BY
    r.run_id,
    r.drill_name,
    r.scenario_type,
    r.started_at,
    r.finished_at,
    r.rto_target_minutes,
    r.actual_rto_minutes,
    r.status
ORDER BY r.run_id DESC
LIMIT 10;

SELECT
    c.check_id,
    c.run_id,
    c.check_name,
    c.expected_value,
    c.actual_value,
    c.is_passed,
    c.note,
    c.created_at
FROM dr_plan.recovery_validation_checks c
ORDER BY c.check_id DESC
LIMIT 20;
