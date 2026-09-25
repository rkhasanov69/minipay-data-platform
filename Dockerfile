FROM apache/airflow:slim-2.10.5-python3.9

RUN pip install --no-cache-dir \
    apache-airflow-providers-postgres \
    psycopg2-binary==2.9.12 \
    python-dotenv==1.2.1
