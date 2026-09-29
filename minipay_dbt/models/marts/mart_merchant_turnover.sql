select
    merchant_id,
    merchant_name,
    merchant_city,
    count(*) as payments_count,
    sum(amount) as turnover,
    round(avg(amount), 2) as avg_cheque
from {{ ref('int_transactions_enriched') }}
where operation_type = 'payment'
  and status = 'success'
group by
    merchant_id,
    merchant_name,
    merchant_city
