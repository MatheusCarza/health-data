"""Orquestra o pipeline reprodutível atual do MVP Health Data.

Esta primeira versão permanece sem agenda automática e sem escrita no Oracle.
Ela automatiza a coleta, as validações e a geração do DML já existentes. A
ativação mensal ocorrerá depois que a carga incremental e idempotente estiver
implementada.
"""

from __future__ import annotations

import os
import subprocess
from datetime import timedelta
from pathlib import Path

import pendulum
from airflow.sdk import dag, task

from health_data_pipeline.quality import (
    validar_arquivo_cnes,
    validar_arquivo_ibge,
    validar_arquivo_sih,
    validar_script_dml,
)


PROJECT_ROOT = Path(os.environ.get("HEALTH_DATA_PROJECT_ROOT", "/opt/health-data"))
DATA_DIR = PROJECT_ROOT / "dados"


def executar_script(nome: str) -> None:
    """Executa um coletor versionado e encerra a tarefa em caso de falha."""
    subprocess.run(
        ["python", str(PROJECT_ROOT / nome)],
        cwd=PROJECT_ROOT,
        check=True,
    )


@dag(
    dag_id="health_data_pipeline",
    description="Coleta, valida e prepara a carga reprodutível do Health Data.",
    schedule=None,
    start_date=pendulum.datetime(2026, 1, 1, tz="America/Sao_Paulo"),
    catchup=False,
    max_active_runs=1,
    default_args={
        "owner": "health-data",
        "retries": 2,
        "retry_delay": timedelta(minutes=5),
    },
    tags=["health-data", "etl", "mvp"],
)
def health_data_pipeline():
    """Define a primeira DAG do pipeline, ainda acionada manualmente."""

    @task
    def validar_ambiente() -> None:
        obrigatorios = [
            "baixar_sih_ftp_completo.py",
            "baixar_cnes_api.py",
            "baixar_ibge_populacao.py",
            "gerar_dml.py",
        ]
        ausentes = [nome for nome in obrigatorios if not (PROJECT_ROOT / nome).is_file()]
        if ausentes:
            raise FileNotFoundError(
                "Arquivos obrigatórios ausentes: " + ", ".join(ausentes)
            )
        DATA_DIR.mkdir(parents=True, exist_ok=True)

    @task(execution_timeout=timedelta(hours=3))
    def extrair_sih() -> str:
        executar_script("baixar_sih_ftp_completo.py")
        return str(DATA_DIR / "sih_sp_2024_completo.parquet")

    @task(execution_timeout=timedelta(hours=3))
    def extrair_cnes() -> str:
        executar_script("baixar_cnes_api.py")
        return str(DATA_DIR / "cnes_sp.parquet")

    @task(execution_timeout=timedelta(minutes=30))
    def extrair_ibge() -> str:
        executar_script("baixar_ibge_populacao.py")
        return str(DATA_DIR / "ibge_populacao_sp_2024.csv")

    @task
    def validar_fontes(sih_path: str, cnes_path: str, ibge_path: str) -> None:
        validar_arquivo_sih(Path(sih_path), ano=2024)
        validar_arquivo_cnes(Path(cnes_path))
        validar_arquivo_ibge(Path(ibge_path), total_esperado=645)

    @task(execution_timeout=timedelta(minutes=30))
    def gerar_dml() -> str:
        executar_script("gerar_dml.py")
        return str(PROJECT_ROOT / "sql" / "dml_health_data.sql")

    @task
    def validar_dml(dml_path: str) -> None:
        validar_script_dml(Path(dml_path))

    ambiente = validar_ambiente()
    sih = extrair_sih()
    cnes = extrair_cnes()
    ibge = extrair_ibge()

    ambiente >> [sih, cnes, ibge]
    fontes_validas = validar_fontes(sih, cnes, ibge)
    dml = gerar_dml()
    fontes_validas >> dml
    validar_dml(dml)


health_data_pipeline()
