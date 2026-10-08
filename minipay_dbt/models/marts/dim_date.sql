with days as (
    select d::date as date_day
    from generate_series(
        '2026-01-01'::date,
        '2027-12-31'::date,
        interval '1 day'
    ) as d
)

select
    date_day,
    extract(year from date_day)::int    as year,
    extract(quarter from date_day)::int as quarter,
    extract(month from date_day)::int   as month,
    extract(day from date_day)::int     as day_of_month,
    extract(isodow from date_day)::int  as day_of_week,
    trim(to_char(date_day, 'Day'))      as day_name,
    extract(isodow from date_day) in (6, 7) as is_weekend
from days
