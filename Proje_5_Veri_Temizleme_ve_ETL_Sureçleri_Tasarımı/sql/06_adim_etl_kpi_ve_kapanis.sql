-- Adım 6: ETL KPI ve kapanis raporu
-- Amaç: Tum ETL surecini metriklerle ozetlemek.

SET search_path TO etl_demo;

CREATE OR REPLACE VIEW v_etl_quality_dashboard AS
SELECT 'raw_rows' AS metric_name, COUNT(*)::NUMERIC AS metric_value FROM raw_orders
UNION ALL
SELECT 'staged_rows', COUNT(*)::NUMERIC FROM stg_orders
UNION ALL
SELECT 'rejected_rows', COUNT(*)::NUMERIC FROM stg_orders_rejected
UNION ALL
SELECT 'fact_rows', COUNT(*)::NUMERIC FROM fact_orders
UNION ALL
SELECT
    'rejection_rate_percent',
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND((SELECT COUNT(*)::NUMERIC FROM stg_orders_rejected) * 100 / COUNT(*), 2)
    END
FROM raw_orders;

CREATE OR REPLACE VIEW v_reject_reason_breakdown AS
SELECT reject_reason, COUNT(*) AS reject_count
FROM stg_orders_rejected
GROUP BY reject_reason
ORDER BY reject_count DESC, reject_reason;

CREATE TABLE IF NOT EXISTS etl_final_snapshot (
    snapshot_id BIGSERIAL PRIMARY KEY,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC(18,2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO etl_final_snapshot (metric_name, metric_value)
SELECT metric_name, metric_value FROM v_etl_quality_dashboard;

-- Ekran goruntusu icin calistir
SELECT * FROM v_etl_quality_dashboard ORDER BY metric_name;
SELECT * FROM v_reject_reason_breakdown;
SELECT * FROM etl_final_snapshot ORDER BY snapshot_id DESC LIMIT 20;
