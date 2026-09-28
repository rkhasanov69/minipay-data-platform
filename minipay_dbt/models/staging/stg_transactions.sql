select
    id as transaction_id,
    sender_card_id,
    receiver_card_id,
    merchant_id,
    amount,
    currency,
    operation_type,
    channel,
    status,
    created_at,
    updated_at
from {{ source('raw', 'transactions') }}
