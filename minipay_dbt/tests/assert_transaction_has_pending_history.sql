select
    t.transaction_id,
    t.status
from {{ ref('stg_transactions') }} t
left join {{ ref('stg_transaction_status_history') }} h
    on t.transaction_id = h.transaction_id
    and h.status = 'pending'
where h.status_history_id is null
