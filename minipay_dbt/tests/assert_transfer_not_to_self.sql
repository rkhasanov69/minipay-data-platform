select
    transaction_id,
    sender_card_id,
    receiver_card_id
from {{ ref('stg_transactions') }}
where sender_card_id = receiver_card_id
