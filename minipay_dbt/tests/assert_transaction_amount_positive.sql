select
    transaction_id,
    sender_card_id,
    receiver_card_id,
    amount,
    status
from {{ ref('stg_transactions') }}
where amount <= 0
