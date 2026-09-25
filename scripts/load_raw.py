import os

import psycopg2
from psycopg2.extras import execute_values
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()
LOOKBACK = timedelta(minutes=10)

oltp_conn = psycopg2.connect(
    host=os.getenv("OLTP_HOST", "localhost"),
    port=os.getenv("OLTP_PORT", "5432"),
    dbname="minipay_oltp",
    user="minipay",
    password=os.getenv("POSTGRES_PASSWORD"),
)

dwh_conn = psycopg2.connect(
    host=os.getenv("DWH_HOST", "localhost"),
    port=os.getenv("DWH_PORT", "5433"),
    dbname="minipay_dwh",
    user="minipay",
    password=os.getenv("DWH_POSTGRES_PASSWORD"),
)

oltp_cur = oltp_conn.cursor()
dwh_cur = dwh_conn.cursor()

# --- users: OLTP -> raw.users (инкрементально, по updated_at) ---

dwh_cur.execute("SELECT last_updated_at FROM raw.load_log WHERE table_name = 'users'")
last_updated_at = dwh_cur.fetchone()[0]

if last_updated_at is None:
    oltp_cur.execute("""
        SELECT id, first_name, last_name, phone, city, created_at, status, updated_at
        FROM users
    """)
else:
    oltp_cur.execute("""
        SELECT id, first_name, last_name, phone, city, created_at, status, updated_at
        FROM users
        WHERE updated_at > %s
    """, (last_updated_at - LOOKBACK,))

rows = oltp_cur.fetchall()

if rows:
    ids = [row[0] for row in rows]
    dwh_cur.execute("DELETE FROM raw.users WHERE id = ANY(%s)", (ids,))

    execute_values(
        dwh_cur,
        "INSERT INTO raw.users (id, first_name, last_name, phone, city, created_at, status, updated_at) VALUES %s",
        rows
    )

    max_updated_at = max(row[7] for row in rows)
    dwh_cur.execute(
        "UPDATE raw.load_log SET last_updated_at = %s WHERE table_name = 'users'",
        (max_updated_at,)
    )

dwh_conn.commit()
print(f"users: {len(rows)} rows")

# --- cards: OLTP -> raw.cards (инкрементально, по updated_at) ---

dwh_cur.execute("SELECT last_updated_at FROM raw.load_log WHERE table_name = 'cards'")
last_updated_at = dwh_cur.fetchone()[0]

if last_updated_at is None:
    oltp_cur.execute("""
        SELECT id, user_id, last4, exp_month, exp_year, created_at, updated_at, status, card_type
        FROM cards
    """)
else:
    oltp_cur.execute("""
        SELECT id, user_id, last4, exp_month, exp_year, created_at, updated_at, status, card_type
        FROM cards
        WHERE updated_at > %s
    """, (last_updated_at - LOOKBACK,))

rows = oltp_cur.fetchall()

if rows:
    ids = [row[0] for row in rows]
    dwh_cur.execute("DELETE FROM raw.cards WHERE id = ANY(%s)", (ids,))

    execute_values(
        dwh_cur,
        "INSERT INTO raw.cards (id, user_id, last4, exp_month, exp_year, created_at, updated_at, status, card_type) VALUES %s",
        rows
    )

    max_updated_at = max(row[6] for row in rows)
    dwh_cur.execute(
        "UPDATE raw.load_log SET last_updated_at = %s WHERE table_name = 'cards'",
        (max_updated_at,)
    )

dwh_conn.commit()
print(f"cards: {len(rows)} rows")

# --- merchants: OLTP -> raw.merchants (инкрементально, по updated_at) ---

dwh_cur.execute("SELECT last_updated_at FROM raw.load_log WHERE table_name = 'merchants'")
last_updated_at = dwh_cur.fetchone()[0]

if last_updated_at is None:
    oltp_cur.execute("""
        SELECT id, legal_name, displayed_name, inn, city, created_at, updated_at, status
        FROM merchants
    """)
else:
    oltp_cur.execute("""
        SELECT id, legal_name, displayed_name, inn, city, created_at, updated_at, status
        FROM merchants
        WHERE updated_at > %s
    """, (last_updated_at - LOOKBACK,))

rows = oltp_cur.fetchall()

if rows:
    ids = [row[0] for row in rows]
    dwh_cur.execute("DELETE FROM raw.merchants WHERE id = ANY(%s)", (ids,))

    execute_values(
        dwh_cur,
        "INSERT INTO raw.merchants (id, legal_name, displayed_name, inn, city, created_at, updated_at, status) VALUES %s",
        rows
    )

    max_updated_at = max(row[6] for row in rows)
    dwh_cur.execute(
        "UPDATE raw.load_log SET last_updated_at = %s WHERE table_name = 'merchants'",
        (max_updated_at,)
    )

dwh_conn.commit()
print(f"merchants: {len(rows)} rows")

# --- transactions: OLTP -> raw.transactions (инкрементально, по updated_at) ---

dwh_cur.execute("SELECT last_updated_at FROM raw.load_log WHERE table_name = 'transactions'")
last_updated_at = dwh_cur.fetchone()[0]

if last_updated_at is None:
    oltp_cur.execute("""
        SELECT id, sender_card_id, receiver_card_id, merchant_id, amount, currency,
               operation_type, channel, status, created_at, updated_at
        FROM transactions
    """)
else:
    oltp_cur.execute("""
        SELECT id, sender_card_id, receiver_card_id, merchant_id, amount, currency,
               operation_type, channel, status, created_at, updated_at
        FROM transactions
        WHERE updated_at > %s
    """, (last_updated_at - LOOKBACK,))

rows = oltp_cur.fetchall()

if rows:
    ids = [row[0] for row in rows]
    dwh_cur.execute("DELETE FROM raw.transactions WHERE id = ANY(%s)", (ids,))

    execute_values(
        dwh_cur,
        """INSERT INTO raw.transactions
           (id, sender_card_id, receiver_card_id, merchant_id, amount, currency,
            operation_type, channel, status, created_at, updated_at)
           VALUES %s""",
        rows
    )

    max_updated_at = max(row[10] for row in rows)
    dwh_cur.execute(
        "UPDATE raw.load_log SET last_updated_at = %s WHERE table_name = 'transactions'",
        (max_updated_at,)
    )

dwh_conn.commit()
print(f"transactions: {len(rows)} rows")

# --- transaction_status_history: OLTP -> raw.transaction_status_history (инкрементально, по changed_at, append-only) ---

dwh_cur.execute("SELECT last_updated_at FROM raw.load_log WHERE table_name = 'transaction_status_history'")
last_updated_at = dwh_cur.fetchone()[0]

if last_updated_at is None:
    oltp_cur.execute("""
        SELECT id, transaction_id, status, changed_at
        FROM transaction_status_history
    """)
else:
    oltp_cur.execute("""
        SELECT id, transaction_id, status, changed_at
        FROM transaction_status_history
        WHERE changed_at > %s
    """, (last_updated_at - LOOKBACK,))

rows = oltp_cur.fetchall()

if rows:
    ids = [row[0] for row in rows]
    dwh_cur.execute("DELETE FROM raw.transaction_status_history WHERE id = ANY(%s)", (ids,))

    execute_values(
        dwh_cur,
        "INSERT INTO raw.transaction_status_history (id, transaction_id, status, changed_at) VALUES %s",
        rows
    )

    max_updated_at = max(row[3] for row in rows)
    dwh_cur.execute(
        "UPDATE raw.load_log SET last_updated_at = %s WHERE table_name = 'transaction_status_history'",
        (max_updated_at,)
    )

dwh_conn.commit()
print(f"transaction_status_history: {len(rows)} rows")

# --- закрываем соединения ---

oltp_cur.close()
oltp_conn.close()
dwh_cur.close()
dwh_conn.close()

print("Готово: инкрементальная загрузка в raw завершена.")
