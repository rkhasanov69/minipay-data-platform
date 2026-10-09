select
    d.date_day,
    d.day_name,
    d.is_day_off,
    count(f.transaction_id) filter (where f.operation_type = 'payment')            as payments_count,
    coalesce(sum(f.amount) filter (where f.operation_type = 'payment'), 0)  as payments_turnover,
    count(f.transaction_id) filter (where f.operation_type = 'transfer')           as transfers_count,
    coalesce(sum(f.amount) filter (where f.operation_type = 'transfer'), 0) as transfers_turnover
from {{ ref('dim_date') }} d
left join {{ ref('fct_transactions') }} f
    on f.transaction_date = d.date_day
    and f.status = 'success'
where d.date_day between (select min(transaction_date) from {{ ref('fct_transactions') }})
                     and (now() at time zone 'Asia/Tashkent')::date
group by d.date_day, d.day_name, d.is_day_off
