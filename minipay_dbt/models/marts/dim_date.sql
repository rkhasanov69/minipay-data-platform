with days as (
    select d::date as date_day
    from generate_series(
        '2026-01-01'::date,
        '2027-12-31'::date,
        interval '1 day'
    ) as d
),

holidays as (
    select date_day, holiday_name, day_type
    from {{ ref('uz_holidays') }}
)

select
    days.date_day,
    extract(year from days.date_day)::int    as year,
    extract(quarter from days.date_day)::int as quarter,
    extract(month from days.date_day)::int   as month,
    extract(day from days.date_day)::int     as day_of_month,
    extract(isodow from days.date_day)::int  as day_of_week,
    trim(to_char(days.date_day, 'Day'))      as day_name,
    extract(isodow from days.date_day) in (6, 7) as is_weekend,
    coalesce(h.day_type = 'holiday', false)  as is_holiday,
    h.holiday_name,
    case
        when h.day_type in ('holiday', 'day_off') then true
        when h.day_type = 'workday' then false
        else extract(isodow from days.date_day) in (6, 7)
    end as is_day_off
from days
left join holidays h on days.date_day = h.date_day
