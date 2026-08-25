"""Baixa a estimativa oficial da população municipal de 2024 do IBGE,
filtra os municípios do estado de São Paulo e gera o CSV usado pela
external table DIM_MUNICIPIO_EXT no Oracle.

Fonte oficial:
IBGE — Estimativas da População Residente nos Municípios Brasileiros,
data de referência em 1º de julho de 2024.

Saída:
    dados/ibge_populacao_sp_2024.csv

Colunas:
    MUNIC_RES_IBGE
    NOME_MUNICIPIO
    POPULACAO
"""

from pathlib import Path

import pandas as pd
import requests


ANO = 2024
UF = "SP"
TOTAL_ESPERADO_SP = 645

URL_IBGE = (
    "https://ftp.ibge.gov.br/Estimativas_de_Populacao/"
    "Estimativas_2024/estimativa_dou_2024.xls"
)

PASTA_DADOS = Path("dados")
ARQUIVO_XLS = PASTA_DADOS / f"estimativa_dou_{ANO}.xls"
ARQUIVO_CSV = PASTA_DADOS / f"ibge_populacao_sp_{ANO}.csv"


def baixar_xls():
    """Baixa o XLS oficial do IBGE."""
    PASTA_DADOS.mkdir(exist_ok=True)

    print(f"Baixando estimativas oficiais do IBGE para {ANO}...")

    resposta = requests.get(URL_IBGE, timeout=60)
    resposta.raise_for_status()

    ARQUIVO_XLS.write_bytes(resposta.content)

    print(f"Arquivo original salvo em: {ARQUIVO_XLS}")


def preparar_municipios():
    """Lê o XLS, seleciona São Paulo e padroniza as colunas."""

    df = pd.read_excel(
        ARQUIVO_XLS,
        sheet_name="MUNICÍPIOS",
        header=1,
        dtype={
            "UF": str,
            "COD. UF": str,
            "COD. MUNIC": str,
        },
    )

    sp = df[df["UF"].str.strip() == UF].copy()

    # Código IBGE completo de 7 dígitos:
    # COD. UF (2 dígitos) + COD. MUNIC (5 dígitos)
    sp["MUNIC_RES_IBGE"] = (
        sp["COD. UF"].str.strip().str.zfill(2)
        + sp["COD. MUNIC"].str.strip().str.zfill(5)
    )

    sp["NOME_MUNICIPIO"] = (
        sp["NOME DO MUNICÍPIO"]
        .astype("string")
        .str.strip()
    )

    sp["POPULACAO"] = pd.to_numeric(
        sp["POPULAÇÃO ESTIMADA"],
        errors="raise",
    ).astype(int)

    resultado = (
        sp[
            [
                "MUNIC_RES_IBGE",
                "NOME_MUNICIPIO",
                "POPULACAO",
            ]
        ]
        .sort_values("MUNIC_RES_IBGE")
        .reset_index(drop=True)
    )

    return resultado


def validar(df):
    """Valida a integridade básica da dimensão municipal."""

    if len(df) != TOTAL_ESPERADO_SP:
        raise ValueError(
            f"Esperados {TOTAL_ESPERADO_SP} municípios de SP, "
            f"mas foram encontrados {len(df)}."
        )

    if df["MUNIC_RES_IBGE"].duplicated().any():
        raise ValueError("Foram encontrados códigos IBGE duplicados.")

    if df["NOME_MUNICIPIO"].isna().any():
        raise ValueError("Existem municípios sem nome.")

    if (df["NOME_MUNICIPIO"].str.strip() == "").any():
        raise ValueError("Existem municípios com nome vazio.")

    if df["POPULACAO"].isna().any():
        raise ValueError("Existem municípios sem população.")

    print("Validação concluída:")
    print(f"  Municípios: {len(df)}")
    print(f"  Códigos únicos: {df['MUNIC_RES_IBGE'].nunique()}")
    print(f"  Municípios com nome: {df['NOME_MUNICIPIO'].notna().sum()}")


def salvar_csv(df):
    """Salva o arquivo consumido pela external table do Oracle."""

    df.to_csv(
        ARQUIVO_CSV,
        index=False,
        encoding="utf-8",
    )

    print(f"CSV salvo em: {ARQUIVO_CSV}")


if __name__ == "__main__":
    baixar_xls()

    municipios = preparar_municipios()

    validar(municipios)

    salvar_csv(municipios)

    print("\nPrimeiros 10 registros:")
    print(municipios.head(10).to_string(index=False))
