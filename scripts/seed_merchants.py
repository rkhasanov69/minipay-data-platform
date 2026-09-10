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

UZ_MERCHANTS = [
    "Korzinka", "Havas", "Makro", "bi1", "Magnum", "Baraka",
    "Beeline", "Ucell", "Uzmobile", "UMS",
    "Uzum Market", "OZON", "Wildberries", "Yandex Market",
    "Evos", "KFC", "Burger King", "Street Burger", "Mazzali",
    "Apteka.uz", "OXYMED", "Davo", "Vitaminka", "Shoxfarm", "Grandpharm",
    "Carvon", "Uzbekneftegaz", "Mustang", "Tatneft", "Lukoil",
    "LC Waikiki", "Zara", "Bershka", "Pull&Bear", "Massimo Dutti",
    "Texnomart", "MediaPark",
    "Express24", "Yandex Eda", "Uzum Tezkor",
    "Caffelito", "Costa Coffee", "Starbucks",
]


def generate_merchant(name):
    return {
        "legal_name": f"{name} MCHJ",
        "displayed_name": name,
        "inn": fake_uz.numerify(text="#########"),
        "city": random.choice(UZ_CITIES),
        "status": "active",
    }


conn = psycopg2.connect(
    host="localhost",
    port=5432,
    dbname="minipay_oltp",
    user="minipay",
    password=os.getenv("POSTGRES_PASSWORD"),
)
cur = conn.cursor()

merchants = []
for name in UZ_MERCHANTS:
    merchants.append(generate_merchant(name))

for merchant in merchants:
    cur.execute(
        """
        INSERT INTO merchants (legal_name, displayed_name, inn, city, status)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            merchant["legal_name"],
            merchant["displayed_name"],
            merchant["inn"],
            merchant["city"],
            merchant["status"],
        ),
    )

conn.commit()

print(f"Inserted {len(merchants)} merchants")

cur.close()
conn.close()
