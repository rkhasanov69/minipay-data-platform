import os
import random

from dotenv import load_dotenv
from faker import Faker
import psycopg2

load_dotenv()

fake_uz = Faker("uz_UZ")

UZ_CITIES = [
    "Tashkent",
    "Samarkand",
    "Namangan",
    "Andijan",
    "Nukus",
    "Fergana",
    "Bukhara",
    "Qarshi",
    "Kokand",
    "Margilan",
]

STATUSES = ["active", "restricted", "blocked", "deceased"]
STATUS_WEIGHTS = [90, 5, 3, 2]


def clean_phone(raw):
    digits_only = ""
    for ch in raw:
        if ch.isdigit():
            digits_only += ch
    return digits_only


def generate_user():
    gender = random.choice(["male", "female"])
    if gender == "male":
        first_name = fake_uz.first_name_male()
        last_name = fake_uz.last_name_male()
    else:
        first_name = fake_uz.first_name_female()
        last_name = fake_uz.last_name_female()
    return {
        "first_name": first_name,
        "last_name": last_name,
        "phone": clean_phone(fake_uz.phone_number()),
        "city": random.choice(UZ_CITIES),
        "status": random.choices(STATUSES, weights=STATUS_WEIGHTS, k=1)[0],
    }


conn = psycopg2.connect(
    host="localhost",
    port=5432,
    dbname="minipay_oltp",
    user="minipay",
    password=os.getenv("POSTGRES_PASSWORD"),
)
cur = conn.cursor()

users = []
for _ in range(10):
    users.append(generate_user())

for user in users:
    cur.execute(
        """
        INSERT INTO users (first_name, last_name, phone, city, status)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (user["first_name"], user["last_name"], user["phone"], user["city"], user["status"]),
    )

conn.commit()

print(f"Inserted {len(users)} users")

cur.close()
conn.close()
