select
    id as status_history_id,
    transaction_id,
    status,
    changed_at
from {{ source('raw', 'transaction_status_history') }}
