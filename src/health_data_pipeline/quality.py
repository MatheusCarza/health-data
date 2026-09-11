"""Validações de qualidade aplicadas entre as etapas do pipeline."""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import pyarrow.parquet as pq


COLUNAS_SIH = {
    "MUNIC_RES",
    "MUNIC_MOV",
    "CNES",
    "ESPEC",
    "DT_INTER",
    "DT_SAIDA",
    "DIAS_PERM",
    "VAL_TOT",
    "MORTE",
    "ANO_CMPT",
    "MES_CMPT",
    "N_AIH",
    "SEQUENCIA",
}
COLUNAS_CNES = {
    "codigo_cnes",
    "codigo_municipio",
    "nome_fantasia",
}
COLUNAS_IBGE = {
    "MUNIC_RES_IBGE",
    "NOME_MUNICIPIO",
    "POPULACAO",
}


def _validar_existencia(path: Path) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"Arquivo não encontrado: {path}")
    if path.stat().st_size == 0:
        raise ValueError(f"Arquivo vazio: {path}")


def _validar_colunas(encontradas: set[str], esperadas: set[str], origem: str) -> None:
    ausentes = esperadas - encontradas
    if ausentes:
        raise ValueError(
            f"{origem}: colunas obrigatórias ausentes: {', '.join(sorted(ausentes))}"
        )


def validar_arquivo_sih(path: Path, ano: int) -> None:
    """Valida esquema, volume e competências do Parquet do SIH."""
    _validar_existencia(path)
    parquet = pq.ParquetFile(path)
    _validar_colunas(set(parquet.schema.names), COLUNAS_SIH, "SIH")
    if parquet.metadata.num_rows == 0:
        raise ValueError("SIH: o Parquet não contém registros.")

    competencias = pd.read_parquet(path, columns=["ANO_CMPT", "MES_CMPT"])
    anos = set(pd.to_numeric(competencias["ANO_CMPT"], errors="raise").astype(int))
    meses = set(pd.to_numeric(competencias["MES_CMPT"], errors="raise").astype(int))
    if anos != {ano}:
        raise ValueError(f"SIH: anos encontrados {sorted(anos)}; esperado apenas {ano}.")
    if meses != set(range(1, 13)):
        raise ValueError(
            f"SIH: competências encontradas {sorted(meses)}; esperados os 12 meses."
        )


def validar_arquivo_cnes(path: Path) -> None:
    """Valida esquema, presença de dados e unicidade do CNES."""
    _validar_existencia(path)
    parquet = pq.ParquetFile(path)
    _validar_colunas(set(parquet.schema.names), COLUNAS_CNES, "CNES")
    if parquet.metadata.num_rows == 0:
        raise ValueError("CNES: o Parquet não contém estabelecimentos.")

    codigos = pd.read_parquet(path, columns=["codigo_cnes"])["codigo_cnes"]
    normalizados = codigos.astype("string").str.strip().str.zfill(7)
    if normalizados.isna().any() or (normalizados == "").any():
        raise ValueError("CNES: existem estabelecimentos sem código.")
    if normalizados.duplicated().any():
        raise ValueError("CNES: existem códigos de estabelecimento duplicados.")


def validar_arquivo_ibge(path: Path, total_esperado: int) -> None:
    """Valida esquema, contagem, chaves e população do CSV do IBGE."""
    _validar_existencia(path)
    municipios = pd.read_csv(path, dtype={"MUNIC_RES_IBGE": "string"})
    _validar_colunas(set(municipios.columns), COLUNAS_IBGE, "IBGE")
    if len(municipios) != total_esperado:
        raise ValueError(
            f"IBGE: encontrados {len(municipios)} municípios; esperados {total_esperado}."
        )
    if municipios["MUNIC_RES_IBGE"].duplicated().any():
        raise ValueError("IBGE: existem códigos de município duplicados.")
    if municipios[["MUNIC_RES_IBGE", "NOME_MUNICIPIO", "POPULACAO"]].isna().any().any():
        raise ValueError("IBGE: existem campos obrigatórios sem valor.")
    if (pd.to_numeric(municipios["POPULACAO"], errors="raise") <= 0).any():
        raise ValueError("IBGE: existem municípios com população não positiva.")


def validar_script_dml(path: Path) -> None:
    """Confirma que a carga gerada tem transação e as quatro tabelas esperadas."""
    _validar_existencia(path)
    conteudo = path.read_text(encoding="utf-8")
    marcadores = {
        "ALTER SESSION DISABLE PARALLEL DML;",
        "INSERT INTO dim_municipio",
        "INSERT INTO dim_tipo_atendimento",
        "INSERT INTO dim_estabelecimento",
        "INSERT INTO fato_internacao",
        "COMMIT;",
    }
    ausentes = sorted(marcador for marcador in marcadores if marcador not in conteudo)
    if ausentes:
        raise ValueError(
            "DML: marcadores obrigatórios ausentes: " + ", ".join(ausentes)
        )


def validar_script_etl_incremental(path: Path) -> None:
    """Verifica as proteções essenciais do procedimento incremental Oracle."""
    _validar_existencia(path)
    conteudo = path.read_text(encoding="utf-8")
    marcadores = {
        "CREATE TABLE etl_execucao",
        "CREATE UNIQUE INDEX uk_etl_execucao_sucesso",
        "CREATE TABLE stg_fato_internacao",
        "CREATE OR REPLACE PACKAGE pkg_health_data_etl",
        "MERGE INTO dim_municipio",
        "MERGE INTO dim_estabelecimento",
        "DELETE FROM fato_internacao\n        WHERE ano_competencia = v_ano\n          AND mes_competencia = v_mes;",
        "ROLLBACK;",
        "COMMIT;",
        "id_registro_origem",
    }
    ausentes = sorted(marcador for marcador in marcadores if marcador not in conteudo)
    if ausentes:
        raise ValueError(
            "ETL incremental: proteções obrigatórias ausentes: "
            + ", ".join(ausentes)
        )
    if "DELETE FROM fato_internacao;" in conteudo:
        raise ValueError("ETL incremental não pode apagar toda a tabela fato.")
