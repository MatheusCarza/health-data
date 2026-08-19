"""Baixa o SIH/SUS (AIH Reduzida - RD) direto do FTP oficial do DATASUS,
para um estado e ano completos (12 meses), convertendo .dbc -> .dbf -> DataFrame.

Criado em 2026-08-05 depois de descobrir que o mirror consultado pela
biblioteca pysus so tinha 4 dos 12 meses de 2024 para SP. A verificacao
direta no FTP oficial (ftp.datasus.gov.br) confirmou que o DATASUS publica
os 12 meses -- a limitacao estava apenas no mirror.

Uso:
    python baixar_sih_ftp_completo.py
"""

import ftplib
import os

import pandas as pd
from dbfread import DBF
from pyreaddbc.readdbc import dbc2dbf

FTP_HOST = "ftp.datasus.gov.br"
FTP_DIR = "/dissemin/publicos/SIHSUS/200801_/Dados"

ESTADO = "SP"
ANO = 2024  # os 2 digitos finais (ex.: 2024 -> "24") entram no nome do arquivo

PASTA_TMP = "dados/tmp"
PASTA_SAIDA = "dados"


def nome_arquivo(estado: str, ano: int, mes: int) -> str:
    aa = str(ano)[-2:]
    return f"RD{estado}{aa}{mes:02d}"


def baixar_mes(ftp: ftplib.FTP, estado: str, ano: int, mes: int) -> pd.DataFrame:
    base = nome_arquivo(estado, ano, mes)
    caminho_dbc = f"{PASTA_TMP}/{base}.dbc"
    caminho_dbf = f"{PASTA_TMP}/{base}.dbf"

    with open(caminho_dbc, "wb") as f:
        ftp.retrbinary(f"RETR {base}.dbc", f.write)

    dbc2dbf(caminho_dbc, caminho_dbf)

    tabela = DBF(caminho_dbf, encoding="iso-8859-1")
    df_mes = pd.DataFrame(iter(tabela))
    print(f"  {base}: {df_mes.shape[0]} linhas")

    # limpa os arquivos intermediarios (dbc/dbf) -- ja temos os dados em memoria
    os.remove(caminho_dbc)
    os.remove(caminho_dbf)

    return df_mes


def baixar_ano(estado: str, ano: int) -> pd.DataFrame:
    os.makedirs(PASTA_TMP, exist_ok=True)

    ftp = ftplib.FTP(FTP_HOST, timeout=60)
    ftp.login()
    ftp.cwd(FTP_DIR)

    print(f"Baixando SIH/SUS (RD) {estado} {ano}, 12 meses, direto do FTP do DATASUS...")
    dfs = []
    for mes in range(1, 13):
        try:
            dfs.append(baixar_mes(ftp, estado, ano, mes))
        except ftplib.error_perm as e:
            print(f"  Mes {mes:02d} nao encontrado no FTP ({e}) -- pulando.")

    ftp.quit()

    df = pd.concat(dfs, ignore_index=True)
    print(f"Total do ano: {df.shape[0]} linhas, {df.shape[1]} colunas.")
    return df


def salvar(df: pd.DataFrame, estado: str, ano: int):
    os.makedirs(PASTA_SAIDA, exist_ok=True)
    caminho_parquet = f"{PASTA_SAIDA}/sih_{estado.lower()}_{ano}_completo.parquet"
    df.to_parquet(caminho_parquet, index=False)
    print(f"Salvo em: {caminho_parquet}")
    print(
        "(CSV nao gerado de proposito -- o dataset do ano inteiro fica grande "
        "demais em CSV; usar o parquet, ou gerar um CSV so de uma amostra se precisar.)"
    )


if __name__ == "__main__":
    df = baixar_ano(ESTADO, ANO)
    salvar(df, ESTADO, ANO)
