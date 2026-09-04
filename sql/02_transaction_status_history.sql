\set ON_ERROR_STOP on

-- MiniPay OLTP schema — transaction status history (event log)
-- Дополняет 01_oltp_schema.sql: журнал изменений статуса транзакции.

BEGIN;

CREATE TABLE IF NOT EXISTS transaction_status_history (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id  INTEGER NOT NULL REFERENCES transactions(id),
    status          TEXT NOT NULL CHECK (status IN ('pending', 'success', 'failure')),
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMIT;
