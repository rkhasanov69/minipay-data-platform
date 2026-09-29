select
    t.transaction_id,
    t.operation_type,
    t.channel,
    t.status,
    t.amount,
    t.created_at,
    t.created_at at time zone 'Asia/Tashkent' as created_at_local,

    sender_card.user_id as sender_user_id,
    sender_user.city as sender_city,
    sender_card.card_type as sender_card_type,

    receiver_card.user_id as receiver_user_id,
    receiver_user.city as receiver_city,
    receiver_card.card_type as receiver_card_type,

    m.merchant_id,
    m.displayed_name as merchant_name,
    m.city as merchant_city

from {{ ref('stg_transactions') }} t
left join {{ ref('stg_cards') }} sender_card
    on t.sender_card_id = sender_card.card_id
left join {{ ref('stg_users') }} sender_user
    on sender_card.user_id = sender_user.user_id
left join {{ ref('stg_cards') }} receiver_card
    on t.receiver_card_id = receiver_card.card_id
left join {{ ref('stg_users') }} receiver_user
    on receiver_card.user_id = receiver_user.user_id
left join {{ ref('stg_merchants') }} m
    on t.merchant_id = m.merchant_id
