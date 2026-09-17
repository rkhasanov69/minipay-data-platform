import os

import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv

load_dotenv()

oltp_conn = psycopg2.connect(
    host="localhost",
    port=5432,
    dbname="minipay_oltp",
    user="minipay",
    password=os.getenv("POSTGRES_PASSWORD"),
)

dwh_conn = psycopg2.connect(
    host="localhost",
    port=5433,
    dbname="minipay_dwh",
    user="minipay",
    password=os.getenv("DWH_POSTGRES_PASSWORD"),
)

oltp_cur = oltp_conn.cursor()
dwh_cur = dwh_conn.cursor()

# --- users: OLTP -> raw.users ---

oltp_cur.execute("""
    SELECT id, first_name, last_name, phone, city, created_at, status, updated_at
    FROM users
""")
rows = oltp_cur.fetchall()

dwh_cur.execute("TRUNCATE raw.users")

execute_values(
    dwh_cur,
    "INSERT INTO raw.users (id, first_name, last_name, phone, city, created_at, status, updated_at) VALUES %s",
    rows
)

dwh_conn.commit()
print(f"users: {len(rows)} rows")

# --- cards: OLTP -> raw.cards ---

oltp_cur.execute("""
    SELECT id, user_id, last4, exp_month, exp_year, created_at, updated_at, status, card_type
    FROM cards
""")
rows = oltp_cur.fetchall()

dwh_cur.execute("TRUNCATE raw.cards")

execute_values(
    dwh_cur,
    "INSERT INTO raw.cards (id, user_id, last4, exp_month, exp_year, created_at, updated_at, status, card_type) VALUES %s",
    rows
)

dwh_conn.commit()
print(f"cards: {len(rows)} rows")

# --- merchants: OLTP -> raw.merchants ---

oltp_cur.execute("""
    SELECT id, legal_name, displayed_name, inn, city, created_at, updated_at, status
    FROM merchants
""")
rows = oltp_cur.fetchall()

dwh_cur.execute("TRUNCATE raw.merchants")

execute_values(
    dwh_cur,
    "INSERT INTO raw.merchants (id, legal_name, displayed_name, inn, city, created_at, updated_at, status) VALUES %s",
    rows
)

dwh_conn.commit()
print(f"merchants: {len(rows)} rows")

# --- transactions: OLTP -> raw.transactions ---

oltp_cur.execute("""
    SELECT id, sender_card_id, receiver_card_id, merchant_id, amount, currency,
           operation_type, channel, status, created_at, updated_at
    FROM transactions
""")
rows = oltp_cur.fetchall()

dwh_cur.execute("TRUNCATE raw.transactions")

execute_values(
    dwh_cur,
    """INSERT INTO raw.transactions
       (id, sender_card_id, receiver_card_id, merchant_id, amount, currency,
        operation_type, channel, status, created_at, updated_at)
       VALUES %s""",
    rows
)

dwh_conn.commit()
print(f"transactions: {len(rows)} rows")

# --- transaction_status_history: OLTP -> raw.transaction_status_history ---

oltp_cur.execute("""
    SELECT id, transaction_id, status, changed_at
    FROM transaction_status_history
""")
rows = oltp_cur.fetchall()

dwh_cur.execute("TRUNCATE raw.transaction_status_history")

execute_values(
    dwh_cur,
    "INSERT INTO raw.transaction_status_history (id, transaction_id, status, changed_at) VALUES %s",
    rows
)

dwh_conn.commit()
print(f"transaction_status_history: {len(rows)} rows")

# --- закрываем соединения ---

oltp_cur.close()
oltp_conn.close()
dwh_cur.close()
dwh_conn.close()

print("Готово: все таблицы скопированы в raw.")
