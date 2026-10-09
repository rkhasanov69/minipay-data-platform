select
    transaction_id,
    sender_card_id,
    receiver_card_id,
    merchant_id,
    created_at_local::date as transaction_date,
    status,
    operation_type,
    channel,
    created_at,
    created_at_local,
    amount
from {{ ref('int_transactions_enriched') }}
