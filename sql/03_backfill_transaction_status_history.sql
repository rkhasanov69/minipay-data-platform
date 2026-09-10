\set ON_ERROR_STOP on
BEGIN;

-- Для каждой транзакции без истории — записать "pending" (любая транзакция
-- начинает жизнь именно с этого статуса, ещё до того, как разрешится).
INSERT INTO transaction_status_history (transaction_id, status, changed_at)
SELECT id, 'pending', created_at
FROM transactions t
WHERE NOT EXISTS (
    SELECT 1 FROM transaction_status_history h WHERE h.transaction_id = t.id
);

-- Для каждой транзакции с финальным статусом не "pending", у которой ещё
-- нет строки именно с этим статусом — записать и его тоже.
INSERT INTO transaction_status_history (transaction_id, status, changed_at)
SELECT id, status, updated_at
FROM transactions t
WHERE status != 'pending'
  AND NOT EXISTS (
      SELECT 1 FROM transaction_status_history h
      WHERE h.transaction_id = t.id AND h.status = t.status
  );

COMMIT;
