select
    id as merchant_id,
    legal_name,
    displayed_name,
    inn,
    city,
    status,
    created_at,
    updated_at
from {{ source('raw', 'merchants') }}
