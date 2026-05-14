-- Adım 4: DDL trigger ile surum izleme
-- Amaç: Semadaki DDL degisikliklerini otomatik loglamak.

SET search_path TO version_demo;

CREATE TABLE IF NOT EXISTS ddl_change_log (
    log_id BIGSERIAL PRIMARY KEY,
    command_tag TEXT NOT NULL,
    object_type TEXT,
    schema_name TEXT,
    object_identity TEXT,
    changed_by TEXT NOT NULL DEFAULT SESSION_USER,
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION fn_log_ddl_changes()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
DECLARE
    cmd RECORD;
BEGIN
    FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
    LOOP
        INSERT INTO ddl_change_log (
            command_tag,
            object_type,
            schema_name,
            object_identity,
            changed_by,
            changed_at
        )
        VALUES (
            TG_TAG,
            cmd.object_type,
            cmd.schema_name,
            cmd.object_identity,
            SESSION_USER,
            NOW()
        );
    END LOOP;
END;
$$;

DROP EVENT TRIGGER IF EXISTS trg_log_ddl_changes;
CREATE EVENT TRIGGER trg_log_ddl_changes
ON ddl_command_end
EXECUTE FUNCTION fn_log_ddl_changes();

-- Test DDL
CREATE TABLE IF NOT EXISTS migration_test_table (
    test_id INT PRIMARY KEY,
    note TEXT
);

-- Ekran goruntusu icin calistir
SELECT log_id, command_tag, object_type, schema_name, object_identity, changed_by, changed_at
FROM ddl_change_log
ORDER BY log_id DESC
LIMIT 20;
