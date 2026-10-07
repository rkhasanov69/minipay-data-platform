select
    merchant_id,
    displayed_name,
    legal_name,
    inn,
    city,
    status,
    created_at as merchant_created_at
from {{ ref('stg_merchants') }}
