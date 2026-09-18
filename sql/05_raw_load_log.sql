\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS raw.load_log (
    table_name      TEXT PRIMARY KEY,
    last_updated_at TIMESTAMP WITH TIME ZONE,
    last_id         INTEGER
);

-- Засеиваем по одной строке на каждую отслеживаемую таблицу.
-- ON CONFLICT DO NOTHING — чтобы повторный прогон файла не падал и не дублировал строки.
INSERT INTO raw.load_log (table_name, last_updated_at, last_id) VALUES
    ('users', NULL, NULL),
    ('cards', NULL, NULL),
    ('merchants', NULL, NULL),
    ('transactions', NULL, NULL),
    ('transaction_status_history', NULL, NULL)
ON CONFLICT (table_name) DO NOTHING;

COMMIT;
