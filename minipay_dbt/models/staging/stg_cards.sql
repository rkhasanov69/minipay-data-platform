select
    id as card_id,
    user_id,
    last4,
    card_type,
    exp_month,
    exp_year,
    status,
    created_at,
    updated_at
from {{ source('raw', 'cards') }}
