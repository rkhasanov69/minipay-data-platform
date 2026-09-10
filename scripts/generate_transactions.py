import os
import random

from dotenv import load_dotenv
import psycopg2

load_dotenv()

OPERATION_TYPES = ["transfer", "payment"]
OPERATION_TYPE_WEIGHTS = [40, 60]

PAYMENT_CHANNELS = ["in_app", "qr", "terminal"]

TRANSACTION_STATUSES = ["success", "failure", "pending"]
TRANSACTION_STATUS_WEIGHTS = [85, 10, 5]

CURRENCY = "UZS"


def generate_transaction(active_card_ids, active_merchant_ids):
    operation_type = random.choices(OPERATION_TYPES, weights=OPERATION_TYPE_WEIGHTS, k=1)[0]
    sender_card_id = random.choice(active_card_ids)

    if operation_type == "transfer":
        channel = "in_app"
        merchant_id = None
        receiver_card_id = random.choice(active_card_ids)
        while receiver_card_id == sender_card_id:
            receiver_card_id = random.choice(active_card_ids)
    else:
        channel = random.choice(PAYMENT_CHANNELS)
        merchant_id = random.choice(active_merchant_ids)
        receiver_card_id = None

    return {
        "sender_card_id": sender_card_id,
        "receiver_card_id": receiver_card_id,
        "merchant_id": merchant_id,
        "amount": random.randint(10000, 4000000),
        "currency": CURRENCY,
        "operation_type": operation_type,
        "channel": channel,
        "status": random.choices(TRANSACTION_STATUSES, weights=TRANSACTION_STATUS_WEIGHTS, k=1)[0],
    }


conn = psycopg2.connect(
    host="localhost",
    port=5432,
    dbname="minipay_oltp",
    user="minipay",
    password=os.getenv("POSTGRES_PASSWORD"),
)
cur = conn.cursor()

cur.execute("SELECT id FROM cards WHERE status = 'active'")
active_card_ids = []
for row in cur.fetchall():
    active_card_ids.append(row[0])

cur.execute("SELECT id FROM merchants WHERE status = 'active'")
active_merchant_ids = []
for row in cur.fetchall():
    active_merchant_ids.append(row[0])

transactions = []
for _ in range(100):
    transactions.append(generate_transaction(active_card_ids, active_merchant_ids))

for tx in transactions:
    cur.execute(
        """
        INSERT INTO transactions
            (sender_card_id, receiver_card_id, merchant_id, amount, currency, operation_type, channel, status)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            tx["sender_card_id"],
            tx["receiver_card_id"],
            tx["merchant_id"],
            tx["amount"],
            tx["currency"],
            tx["operation_type"],
            tx["channel"],
            tx["status"],
        ),
    )

conn.commit()
print(f"Inserted {len(transactions)} transactions")

cur.close()
conn.close()
