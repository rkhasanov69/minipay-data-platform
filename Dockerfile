FROM apache/airflow:slim-2.10.5-python3.12

RUN pip install --no-cache-dir \
    apache-airflow==2.10.5 \
    apache-airflow-providers-postgres==6.4.1 \
    psycopg2-binary==2.9.12 \
    python-dotenv==1.2.1

RUN python -m venv /home/airflow/dbt-venv && \
    /home/airflow/dbt-venv/bin/pip install --no-cache-dir \
        dbt-core==1.12.5 \
        dbt-postgres==1.11.0
