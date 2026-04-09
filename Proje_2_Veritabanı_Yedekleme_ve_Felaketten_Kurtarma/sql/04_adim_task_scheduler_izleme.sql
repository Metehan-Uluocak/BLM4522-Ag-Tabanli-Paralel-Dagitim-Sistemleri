-- Adim 4: Zamanlayici backup izleme tablolari

CREATE TABLE IF NOT EXISTS dr_plan.backup_job_runs (
    run_id BIGSERIAL PRIMARY KEY,
    job_name TEXT NOT NULL,
    backup_type TEXT NOT NULL CHECK (backup_type IN ('logical_full', 'physical_full')),
    started_at TIMESTAMP NOT NULL,
    finished_at TIMESTAMP NOT NULL,
    is_success BOOLEAN NOT NULL,
    backup_path TEXT,
    log_path TEXT,
    details TEXT
);

CREATE TABLE IF NOT EXISTS dr_plan.backup_alerts (
    alert_id BIGSERIAL PRIMARY KEY,
    alert_level TEXT NOT NULL CHECK (alert_level IN ('info', 'warning', 'critical')),
    source_job TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_acknowledged BOOLEAN NOT NULL DEFAULT FALSE
);

-- Son 20 job calisma sonucu
SELECT
    run_id,
    job_name,
    backup_type,
    started_at,
    finished_at,
    is_success,
    backup_path,
    log_path
FROM dr_plan.backup_job_runs
ORDER BY run_id DESC
LIMIT 20;

-- Ack edilmemis alarmlar
SELECT
    alert_id,
    alert_level,
    source_job,
    message,
    created_at,
    is_acknowledged
FROM dr_plan.backup_alerts
WHERE is_acknowledged = FALSE
ORDER BY alert_id DESC;
