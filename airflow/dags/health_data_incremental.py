"""Orquestra uma competência incremental mensal do Health Data.

Disparos manuais usam os Params informados na interface. Disparos agendados
selecionam o mês seguinte à última carga bem-sucedida, respeitando um limite de
competência configurado para impedir expansão acidental do escopo do MVP.
"""

from __future__ import annotations

import os
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path
from uuid import uuid4

import pendulum
from airflow.exceptions import AirflowSkipException
from airflow.sdk import Param, dag, get_current_context, task


PROJECT_ROOT = Path(os.environ.get("HEALTH_DATA_PROJECT_ROOT", "/opt/health-data"))
sys.path.insert(0, str(PROJECT_ROOT))

from carregar_competencia_oracle import conectar_oracle
from health_data_pipeline.object_storage import (
    calcular_sha256,
    nome_objeto_bronze,
    publicar_arquivo,
)
from health_data_pipeline.oracle_staging import (
    executar_carga_incremental,
    preparar_staging,
)
from health_data_pipeline.scheduling import (
    competencia_seguinte,
    proxima_competencia_permitida,
)


DATA_DIR = PROJECT_ROOT / "dados"


def executar_script(nome: str, *argumentos: str) -> None:
    """Executa um coletor versionado e propaga qualquer falha à tarefa."""
    subprocess.run(
        ["python", str(PROJECT_ROOT / nome), *argumentos],
        cwd=PROJECT_ROOT,
        check=True,
    )


def parametros_execucao() -> dict[str, int | str]:
    """Resolve Params manuais ou a próxima competência agendada permitida."""
    contexto = get_current_context()
    parametros = contexto["params"]
    uf = str(parametros["uf"]).upper()
    run_id = str(contexto["run_id"])
    if not run_id.startswith("scheduled__"):
        return {
            "uf": uf,
            "ano": int(parametros["ano"]),
            "mes": int(parametros["mes"]),
            "modo": "manual",
        }

    with conectar_oracle() as conexao:
        with conexao.cursor() as cursor:
            cursor.execute(
                """
                SELECT MAX(ano_competencia * 100 + mes_competencia)
                FROM etl_execucao
                WHERE uf = :uf
                  AND status = 'SUCESSO'
                """,
                uf=uf,
            )
            ultima_competencia = cursor.fetchone()[0]
    if ultima_competencia is None:
        raise RuntimeError(
            f"Nenhuma competência bem-sucedida encontrada para {uf}; "
            "faça primeiro uma carga manual controlada."
        )

    limite = int(os.environ.get("HEALTH_DATA_AUTO_MAX_COMPETENCIA", "202412"))
    proxima = proxima_competencia_permitida(int(ultima_competencia), limite)
    if proxima is None:
        ano, mes = competencia_seguinte(int(ultima_competencia))
        raise AirflowSkipException(
            f"Próxima competência {mes:02d}/{ano} ultrapassa o limite "
            f"automático configurado ({limite})."
        )
    ano, mes = proxima
    return {"uf": uf, "ano": ano, "mes": mes, "modo": "agendado"}


@dag(
    dag_id="health_data_incremental",
    description="Coleta, publica e carrega uma competência do Health Data.",
    schedule="0 6 15 * *",
    start_date=pendulum.datetime(2026, 1, 1, tz="America/Sao_Paulo"),
    catchup=False,
    max_active_runs=1,
    params={
        "uf": Param("SP", type="string", pattern="^[A-Za-z]{2}$"),
        "ano": Param(2024, type="integer", minimum=2008, maximum=2100),
        "mes": Param(12, type="integer", minimum=1, maximum=12),
    },
    default_args={
        "owner": "health-data",
        "retries": 1,
        "retry_delay": timedelta(minutes=5),
    },
    tags=["health-data", "etl", "incremental", "oracle"],
)
def health_data_incremental():
    """Define o fluxo mensal completo com acionamento manual ou agendado."""

    @task
    def validar_ambiente() -> dict[str, int | str]:
        parametros = parametros_execucao()
        obrigatorios = (
            "baixar_sih_ftp_completo.py",
            "baixar_cnes_api.py",
            "baixar_ibge_populacao.py",
            "carregar_competencia_oracle.py",
        )
        ausentes = [
            nome for nome in obrigatorios if not (PROJECT_ROOT / nome).is_file()
        ]
        if ausentes:
            raise FileNotFoundError(
                "Arquivos obrigatórios ausentes: " + ", ".join(ausentes)
            )
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        return parametros

    @task(execution_timeout=timedelta(hours=3))
    def extrair_sih(parametros: dict[str, int | str]) -> str:
        uf = str(parametros["uf"])
        ano = int(parametros["ano"])
        mes = int(parametros["mes"])
        executar_script(
            "baixar_sih_ftp_completo.py",
            "--uf",
            uf,
            "--ano",
            str(ano),
            "--mes-inicio",
            str(mes),
            "--mes-fim",
            str(mes),
            "--arquivos-mensais",
            "--pular-existentes",
        )
        return str(
            DATA_DIR / f"sih_{uf.lower()}_{ano}_{mes:02d}_{mes:02d}.parquet"
        )

    @task(execution_timeout=timedelta(hours=3))
    def extrair_cnes(parametros: dict[str, int | str]) -> dict[str, str]:
        uf = str(parametros["uf"])
        executar_script("baixar_cnes_api.py", "--uf", uf)
        return {
            "arquivo": str(DATA_DIR / f"cnes_{uf.lower()}.parquet"),
            "data_extracao": date.today().isoformat(),
        }

    @task(execution_timeout=timedelta(minutes=30))
    def extrair_ibge(parametros: dict[str, int | str]) -> str:
        ano = int(parametros["ano"])
        executar_script(
            "baixar_ibge_populacao.py",
            "--uf",
            "BR",
            "--ano",
            str(ano),
        )
        return str(DATA_DIR / f"ibge_populacao_br_{ano}.csv")

    @task(execution_timeout=timedelta(hours=1))
    def validar_e_publicar(
        parametros: dict[str, int | str],
        sih_path: str,
        cnes_info: dict[str, str],
        ibge_path: str,
    ) -> dict[str, int | str]:
        uf = str(parametros["uf"])
        ano = int(parametros["ano"])
        mes = int(parametros["mes"])
        sih = Path(sih_path)
        cnes = Path(cnes_info["arquivo"])
        ibge = Path(ibge_path)
        frames = preparar_staging(
            sih,
            cnes,
            ibge,
            execucao_id=str(uuid4()),
            uf=uf,
            ano=ano,
            mes=mes,
        )

        auth_mode = os.environ.get("OCI_AUTH_MODE", "instance_principal")
        perfil = os.environ.get("OCI_CONFIG_PROFILE", "DEFAULT")
        arquivo_config = os.environ.get("OCI_CONFIG_FILE") or None
        data_cnes = date.fromisoformat(cnes_info["data_extracao"])
        destinos = (
            (sih, nome_objeto_bronze("sih", sih, uf, ano=ano, mes=mes)),
            (
                cnes,
                nome_objeto_bronze(
                    "cnes", cnes, uf, data_extracao=data_cnes
                ),
            ),
            (ibge, nome_objeto_bronze("ibge", ibge, "BR", ano=ano)),
        )
        for arquivo, nome_objeto in destinos:
            publicar_arquivo(
                arquivo,
                os.environ["OCI_BUCKET_NAME"],
                nome_objeto,
                modo_autenticacao=auth_mode,
                perfil=perfil,
                arquivo_config=arquivo_config,
            )

        return {
            **parametros,
            "sih_path": str(sih),
            "cnes_path": str(cnes),
            "ibge_path": str(ibge),
            "objeto_sih": destinos[0][1],
            "sha256_sih": calcular_sha256(sih),
            "total_internacoes": len(frames.internacoes),
        }

    @task(execution_timeout=timedelta(hours=2))
    def carregar_oracle(manifesto: dict[str, int | str]) -> dict[str, int | str]:
        uf = str(manifesto["uf"])
        ano = int(manifesto["ano"])
        mes = int(manifesto["mes"])
        total = int(manifesto["total_internacoes"])
        sha256 = str(manifesto["sha256_sih"])

        with conectar_oracle() as conexao:
            with conexao.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT execucao_id, linhas_substituidas
                    FROM etl_execucao
                    WHERE uf = :uf
                      AND ano_competencia = :ano
                      AND mes_competencia = :mes
                      AND sha256_sih = :sha256
                      AND status = 'SUCESSO'
                    """,
                    uf=uf,
                    ano=ano,
                    mes=mes,
                    sha256=sha256,
                )
                existente = cursor.fetchone()
                if existente:
                    cursor.execute(
                        """
                        SELECT COUNT(*)
                        FROM fato_internacao
                        WHERE ano_competencia = :ano
                          AND mes_competencia = :mes
                        """,
                        ano=ano,
                        mes=mes,
                    )
                    publicado = int(cursor.fetchone()[0])
                    if publicado != total or int(existente[1]) != total:
                        raise RuntimeError(
                            "Carga existente diverge da fonte mensal atual."
                        )
                    return {
                        **manifesto,
                        "execucao_id": str(existente[0]),
                        "status": "REUTILIZADO",
                    }

        execucao_id = str(uuid4())
        frames = preparar_staging(
            Path(str(manifesto["sih_path"])),
            Path(str(manifesto["cnes_path"])),
            Path(str(manifesto["ibge_path"])),
            execucao_id=execucao_id,
            uf=uf,
            ano=ano,
            mes=mes,
        )
        with conectar_oracle() as conexao:
            resultado = executar_carga_incremental(
                conexao,
                frames,
                execucao_id=execucao_id,
                uf=uf,
                ano=ano,
                mes=mes,
                objeto_sih=str(manifesto["objeto_sih"]),
                sha256_sih=sha256,
            )
        return {
            **manifesto,
            "execucao_id": resultado.execucao_id,
            "status": resultado.status,
        }

    @task
    def reconciliar(resultado: dict[str, int | str]) -> None:
        ano = int(resultado["ano"])
        mes = int(resultado["mes"])
        esperado = int(resultado["total_internacoes"])
        with conectar_oracle() as conexao:
            with conexao.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT COUNT(*)
                    FROM fato_internacao
                    WHERE ano_competencia = :ano
                      AND mes_competencia = :mes
                    """,
                    ano=ano,
                    mes=mes,
                )
                encontrado = int(cursor.fetchone()[0])
        if encontrado != esperado:
            raise RuntimeError(
                f"Reconciliação divergente: {encontrado}; esperado {esperado}."
            )
        print(
            f"{mes:02d}/{ano}: {resultado['status']}, "
            f"{encontrado} internações reconciliadas."
        )

    ambiente = validar_ambiente()
    sih = extrair_sih(ambiente)
    cnes = extrair_cnes(ambiente)
    ibge = extrair_ibge(ambiente)
    manifesto = validar_e_publicar(ambiente, sih, cnes, ibge)
    reconciliar(carregar_oracle(manifesto))


health_data_incremental()
