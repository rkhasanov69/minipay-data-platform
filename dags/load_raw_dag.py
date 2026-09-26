from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    dag_id="load_raw",
    schedule="25 * * * *",
    start_date=datetime(2026, 9, 26),
    catchup=False,
) as dag:
    load_raw_task = BashOperator(
    task_id="load_raw",
    bash_command="python3 /opt/airflow/scripts/load_raw.py",
    )
