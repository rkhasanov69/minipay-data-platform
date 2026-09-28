select
    id as user_id,
    first_name,
    last_name,
    phone,
    city,
    status,
    created_at,
    updated_at
from {{ source('raw', 'users') }}
