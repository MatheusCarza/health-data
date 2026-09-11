FROM apache/airflow:3.3.1-python3.12

COPY requirements.txt /tmp/health-data-requirements.txt
COPY airflow/requirements.txt /tmp/airflow-requirements.txt

RUN pip install --no-cache-dir \
    -r /tmp/health-data-requirements.txt \
    -r /tmp/airflow-requirements.txt

ENV PYTHONPATH=/opt/health-data/src
