select
    transaction_id,
    operation_type,
    receiver_card_id,
    merchant_id
from {{ ref('stg_transactions') }}
where (
        operation_type = 'transfer'
        and (receiver_card_id is null or merchant_id is not null)
      )
   or (
        operation_type = 'payment'
        and (merchant_id is null or receiver_card_id is not null)
      )
