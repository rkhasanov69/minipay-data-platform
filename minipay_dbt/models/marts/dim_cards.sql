select
    c.card_id,
    c.user_id,
    c.card_type,
    c.exp_month,
    c.exp_year,
    c.status as card_status,
    c.created_at as card_created_at,
    u.city as user_city,
    u.status as user_status,
    u.created_at as user_created_at
from {{ ref('stg_cards') }} c
join {{ ref('stg_users') }} u on c.user_id = u.user_id
