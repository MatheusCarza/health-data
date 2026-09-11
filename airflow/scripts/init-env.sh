#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
airflow_dir="$(cd "${script_dir}/.." && pwd)"
env_path="${airflow_dir}/.env"

if [[ -e "${env_path}" ]]; then
    echo "O arquivo ${env_path} já existe; nenhuma alteração foi feita."
    exit 1
fi

umask 077

if [[ "$(uname -s)" == "Darwin" ]]; then
    airflow_uid="50000"
else
    airflow_uid="$(id -u)"
fi

fernet_key="$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')"
jwt_secret="$(openssl rand -hex 32)"
postgres_password="$(openssl rand -base64 36 | tr -d '\n')"
admin_password="$(openssl rand -base64 24 | tr -d '\n')"

{
    printf 'AIRFLOW_UID=%s\n' "${airflow_uid}"
    printf 'AIRFLOW_PORT=8080\n'
    printf 'AIRFLOW_ADMIN_USERNAME=airflow\n'
    printf 'AIRFLOW_ADMIN_PASSWORD=%s\n' "${admin_password}"
    printf 'AIRFLOW_FERNET_KEY=%s\n' "${fernet_key}"
    printf 'AIRFLOW_JWT_SECRET=%s\n' "${jwt_secret}"
    printf 'POSTGRES_PASSWORD=%s\n' "${postgres_password}"
} > "${env_path}"

echo "Arquivo local criado em ${env_path}."
echo "Ele contém segredos e está ignorado pelo Git."
