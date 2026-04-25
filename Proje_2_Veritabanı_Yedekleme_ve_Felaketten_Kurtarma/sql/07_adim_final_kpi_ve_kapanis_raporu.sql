-- Adim 7: Final KPI ve proje kapanis raporu
-- Amac: RPO/RTO, alarm ve tatbikat sonuclarini tek yerde degerlendirmek.

-- -----------------------------------------------------
-- A) Final degerlendirme tablosu
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS dr_plan.final_dr_assessment (
    assessment_id BIGSERIAL PRIMARY KEY,
    policy_name TEXT NOT NULL,
    rpo_target_minutes INTEGER NOT NULL,
    rto_target_minutes INTEGER NOT NULL,
    latest_logical_backup_age_minutes NUMERIC(12,2),
    latest_wal_archive_lag_minutes NUMERIC(12,2),
    latest_drill_actual_rto_minutes NUMERIC(12,2),
    open_alert_count INTEGER NOT NULL,
    rpo_status TEXT NOT NULL CHECK (rpo_status IN ('pass', 'fail', 'unknown')),
    rto_status TEXT NOT NULL CHECK (rto_status IN ('pass', 'fail', 'unknown')),
    wal_status TEXT NOT NULL CHECK (wal_status IN ('pass', 'fail', 'unknown')),
    alert_status TEXT NOT NULL CHECK (alert_status IN ('pass', 'fail')),
    overall_status TEXT NOT NULL CHECK (overall_status IN ('pass', 'fail')),
    measured_at TIMESTAMP NOT NULL DEFAULT NOW(),
    note TEXT
);

-- -----------------------------------------------------
-- B) Anlik KPI olcumu ve kayit
-- -----------------------------------------------------
WITH p AS (
    SELECT
        policy_name,
        rpo_minutes,
        rto_minutes
    FROM dr_plan.backup_policy
    WHERE policy_name = 'BLM4522_DR_POLICY_V1'
), logical_age AS (
    SELECT
        EXTRACT(EPOCH FROM (NOW() - finished_at)) / 60.0 AS age_minutes
    FROM dr_plan.backup_inventory
    WHERE backup_type = 'logical_full'
      AND status = 'success'
    ORDER BY finished_at DESC
    LIMIT 1
), wal_lag AS (
    SELECT
        EXTRACT(EPOCH FROM (NOW() - last_archived_time)) / 60.0 AS lag_minutes,
        failed_count
    FROM dr_plan.wal_archive_checks
    ORDER BY check_id DESC
    LIMIT 1
), drill AS (
    SELECT
        actual_rto_minutes,
        status
    FROM dr_plan.recovery_drill_runs
    ORDER BY run_id DESC
    LIMIT 1
), alerts AS (
    SELECT COUNT(*)::int AS open_alert_count
    FROM dr_plan.backup_alerts
    WHERE is_acknowledged = FALSE
), eval AS (
    SELECT
        p.policy_name,
        p.rpo_minutes,
        p.rto_minutes,
        la.age_minutes AS latest_logical_backup_age_minutes,
        wl.lag_minutes AS latest_wal_archive_lag_minutes,
        d.actual_rto_minutes AS latest_drill_actual_rto_minutes,
        a.open_alert_count,
        CASE
            WHEN la.age_minutes IS NULL THEN 'unknown'
            WHEN la.age_minutes <= p.rpo_minutes THEN 'pass'
            ELSE 'fail'
        END AS rpo_status,
        CASE
            WHEN d.actual_rto_minutes IS NULL THEN 'unknown'
            WHEN d.actual_rto_minutes <= p.rto_minutes AND d.status = 'success' THEN 'pass'
            ELSE 'fail'
        END AS rto_status,
        CASE
            WHEN wl.lag_minutes IS NULL THEN 'unknown'
            WHEN wl.failed_count = 0 THEN 'pass'
            ELSE 'fail'
        END AS wal_status,
        CASE WHEN a.open_alert_count = 0 THEN 'pass' ELSE 'fail' END AS alert_status
    FROM p
    LEFT JOIN logical_age la ON TRUE
    LEFT JOIN wal_lag wl ON TRUE
    LEFT JOIN drill d ON TRUE
    CROSS JOIN alerts a
)
INSERT INTO dr_plan.final_dr_assessment (
    policy_name,
    rpo_target_minutes,
    rto_target_minutes,
    latest_logical_backup_age_minutes,
    latest_wal_archive_lag_minutes,
    latest_drill_actual_rto_minutes,
    open_alert_count,
    rpo_status,
    rto_status,
    wal_status,
    alert_status,
    overall_status,
    note
)
SELECT
    e.policy_name,
    e.rpo_minutes,
    e.rto_minutes,
    e.latest_logical_backup_age_minutes,
    e.latest_wal_archive_lag_minutes,
    e.latest_drill_actual_rto_minutes,
    e.open_alert_count,
    e.rpo_status,
    e.rto_status,
    e.wal_status,
    e.alert_status,
    CASE
        WHEN e.rpo_status = 'pass'
         AND e.rto_status = 'pass'
         AND e.wal_status = 'pass'
         AND e.alert_status = 'pass'
        THEN 'pass' ELSE 'fail'
    END AS overall_status,
    'Adim 7 final KPI degerlendirmesi'
FROM eval e;

-- -----------------------------------------------------
-- C) Proje adim tamamlama kontrol listesi
-- -----------------------------------------------------
WITH checks AS (
    SELECT 'Adim 1 - strateji' AS step_name,
           EXISTS (SELECT 1 FROM dr_plan.backup_policy WHERE policy_name = 'BLM4522_DR_POLICY_V1') AS is_done
    UNION ALL
    SELECT 'Adim 2 - tam yedek envanteri',
           EXISTS (SELECT 1 FROM dr_plan.backup_inventory)
    UNION ALL
    SELECT 'Adim 3 - WAL arsiv dogrulamasi',
           EXISTS (SELECT 1 FROM dr_plan.wal_archive_checks)
    UNION ALL
    SELECT 'Adim 4 - scheduler izleme',
           EXISTS (SELECT 1 FROM dr_plan.backup_job_runs) OR EXISTS (SELECT 1 FROM dr_plan.backup_alerts)
    UNION ALL
    SELECT 'Adim 5 - felaket/PITR hazirlik',
           EXISTS (SELECT 1 FROM dr_plan.incident_log) AND EXISTS (SELECT 1 FROM dr_plan.pitr_test_data)
    UNION ALL
    SELECT 'Adim 6 - geri yukleme tatbikati',
           EXISTS (SELECT 1 FROM dr_plan.recovery_drill_runs) AND EXISTS (SELECT 1 FROM dr_plan.recovery_validation_checks)
    UNION ALL
    SELECT 'Adim 7 - final KPI kapanis',
           EXISTS (SELECT 1 FROM dr_plan.final_dr_assessment)
)
SELECT
    step_name,
    CASE WHEN is_done THEN 'DONE' ELSE 'MISSING' END AS status
FROM checks;

-- -----------------------------------------------------
-- D) Son final ozet ve metinsel grafik
-- -----------------------------------------------------
SELECT
    assessment_id,
    policy_name,
    rpo_target_minutes,
    rto_target_minutes,
    ROUND(latest_logical_backup_age_minutes::numeric, 2) AS latest_logical_age_min,
    ROUND(latest_wal_archive_lag_minutes::numeric, 2) AS latest_wal_lag_min,
    ROUND(latest_drill_actual_rto_minutes::numeric, 2) AS latest_drill_rto_min,
    open_alert_count,
    rpo_status,
    rto_status,
    wal_status,
    alert_status,
    overall_status,
    measured_at
FROM dr_plan.final_dr_assessment
ORDER BY assessment_id DESC
LIMIT 10;

WITH last_assessment AS (
    SELECT *
    FROM dr_plan.final_dr_assessment
    ORDER BY assessment_id DESC
    LIMIT 1
)
SELECT
    'RPO(age/target)' AS metric,
    COALESCE(ROUND(100.0 * latest_logical_backup_age_minutes / NULLIF(rpo_target_minutes, 0), 1), 0) AS pct_of_target,
    repeat('#', GREATEST(1, LEAST(40, COALESCE(ROUND(40.0 * latest_logical_backup_age_minutes / NULLIF(rpo_target_minutes, 0))::int, 1)))) AS bar
FROM last_assessment
UNION ALL
SELECT
    'RTO(actual/target)',
    COALESCE(ROUND(100.0 * latest_drill_actual_rto_minutes / NULLIF(rto_target_minutes, 0), 1), 0),
    repeat('#', GREATEST(1, LEAST(40, COALESCE(ROUND(40.0 * latest_drill_actual_rto_minutes / NULLIF(rto_target_minutes, 0))::int, 1))))
FROM last_assessment;
