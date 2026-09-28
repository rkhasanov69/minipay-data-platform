select
    transaction_id,
    operation_type,
    channel
from {{ ref('stg_transactions') }}
where operation_type = 'transfer'
  and channel <> 'in_app'
