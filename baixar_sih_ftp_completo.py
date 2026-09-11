"""Baixa o SIH/SUS (AIH Reduzida - RD) direto do FTP oficial do DATASUS.

O intervalo pode abranger um ano completo ou uma faixa mensal do mesmo ano. Os
arquivos .dbc são convertidos para .dbf e consolidados em um único Parquet.

Criado em 2026-08-05 depois de descobrir que o mirror consultado pela
biblioteca pysus so tinha 4 dos 12 meses de 2024 para SP. A verificacao
direta no FTP oficial (ftp.datasus.gov.br) confirmou que o DATASUS publica
os 12 meses -- a limitacao estava apenas no mirror.

Uso:
    python baixar_sih_ftp_completo.py
    python baixar_sih_ftp_completo.py --uf SP --ano 2024 --mes-inicio 10 --mes-fim 12
"""

import argparse
import ftplib
import os
from pathlib import Path

import pandas as pd
from dbfread import DBF
from pyreaddbc.readdbc import dbc2dbf

FTP_HOST = "ftp.datasus.gov.br"
FTP_DIR = "/dissemin/publicos/SIHSUS/200801_/Dados"

ESTADO_PADRAO = "SP"
ANO_PADRAO = 2024  # os 2 digitos finais (ex.: 2024 -> "24") entram no nome do arquivo

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


def validar_parametros(estado: str, ano: int, mes_inicio: int, mes_fim: int) -> None:
    """Valida o recorte solicitado antes de abrir a conexão com o FTP."""
    if len(estado) != 2 or not estado.isalpha():
        raise ValueError("UF deve conter exatamente duas letras.")
    if not 2008 <= ano <= 9999:
        raise ValueError("Ano deve ser igual ou posterior a 2008.")
    if not 1 <= mes_inicio <= 12 or not 1 <= mes_fim <= 12:
        raise ValueError("Os meses devem estar entre 1 e 12.")
    if mes_inicio > mes_fim:
        raise ValueError("Mês inicial não pode ser posterior ao mês final.")


def baixar_periodo(
    estado: str,
    ano: int,
    mes_inicio: int = 1,
    mes_fim: int = 12,
) -> pd.DataFrame:
    """Baixa e consolida todas as competências solicitadas."""
    estado = estado.upper()
    validar_parametros(estado, ano, mes_inicio, mes_fim)
    os.makedirs(PASTA_TMP, exist_ok=True)

    ftp = ftplib.FTP(FTP_HOST, timeout=60)
    dfs: list[pd.DataFrame] = []
    ausentes: list[int] = []
    try:
        ftp.login()
        ftp.cwd(FTP_DIR)

        print(
            f"Baixando SIH/SUS (RD) {estado} {ano}, "
            f"meses {mes_inicio:02d} a {mes_fim:02d}, direto do FTP do DATASUS..."
        )
        for mes in range(mes_inicio, mes_fim + 1):
            try:
                dfs.append(baixar_mes(ftp, estado, ano, mes))
            except ftplib.error_perm as erro:
                ausentes.append(mes)
                print(f"  Mes {mes:02d} nao encontrado no FTP ({erro}).")
    finally:
        try:
            ftp.quit()
        except (EOFError, OSError, ftplib.Error):
            ftp.close()

    if ausentes:
        lista = ", ".join(f"{mes:02d}/{ano}" for mes in ausentes)
        raise RuntimeError(f"Competencias solicitadas ausentes no FTP: {lista}.")
    if not dfs:
        raise RuntimeError("Nenhuma competência do SIH foi baixada.")

    df = pd.concat(dfs, ignore_index=True)
    print(f"Total do período: {df.shape[0]} linhas, {df.shape[1]} colunas.")
    return df


def baixar_ano(estado: str, ano: int) -> pd.DataFrame:
    """Mantém a interface histórica para a coleta dos doze meses."""
    return baixar_periodo(estado, ano)


def baixar_competencias_separadas(
    estado: str,
    ano: int,
    mes_inicio: int = 1,
    mes_fim: int = 12,
    *,
    pular_existentes: bool = False,
) -> list[Path]:
    """Baixa cada mês para um Parquet próprio sem acumular o ano na memória."""
    estado = estado.upper()
    validar_parametros(estado, ano, mes_inicio, mes_fim)
    os.makedirs(PASTA_TMP, exist_ok=True)
    os.makedirs(PASTA_SAIDA, exist_ok=True)

    ftp = ftplib.FTP(FTP_HOST, timeout=60)
    caminhos: list[Path] = []
    ausentes: list[int] = []
    try:
        ftp.login()
        ftp.cwd(FTP_DIR)
        for mes in range(mes_inicio, mes_fim + 1):
            destino = caminho_saida(estado, ano, mes, mes)
            if pular_existentes and destino.is_file():
                print(f"  {mes:02d}/{ano}: reutilizando {destino}")
                caminhos.append(destino)
                continue
            try:
                mensal = baixar_mes(ftp, estado, ano, mes)
                caminhos.append(salvar(mensal, estado, ano, mes, mes))
            except ftplib.error_perm as erro:
                ausentes.append(mes)
                print(f"  Mes {mes:02d} nao encontrado no FTP ({erro}).")
    finally:
        try:
            ftp.quit()
        except (EOFError, OSError, ftplib.Error):
            ftp.close()

    if ausentes:
        lista = ", ".join(f"{mes:02d}/{ano}" for mes in ausentes)
        raise RuntimeError(f"Competencias solicitadas ausentes no FTP: {lista}.")
    return caminhos


def caminho_saida(estado: str, ano: int, mes_inicio: int, mes_fim: int) -> Path:
    """Retorna um nome determinístico para o Parquet do recorte."""
    estado_normalizado = estado.lower()
    if mes_inicio == 1 and mes_fim == 12:
        nome = f"sih_{estado_normalizado}_{ano}_completo.parquet"
    else:
        nome = (
            f"sih_{estado_normalizado}_{ano}_"
            f"{mes_inicio:02d}_{mes_fim:02d}.parquet"
        )
    return Path(PASTA_SAIDA) / nome


def salvar(
    df: pd.DataFrame,
    estado: str,
    ano: int,
    mes_inicio: int = 1,
    mes_fim: int = 12,
) -> Path:
    """Persiste o período consolidado em Parquet."""
    os.makedirs(PASTA_SAIDA, exist_ok=True)
    caminho_parquet = caminho_saida(estado, ano, mes_inicio, mes_fim)
    df.to_parquet(caminho_parquet, index=False)
    print(f"Salvo em: {caminho_parquet}")
    print(
        "(CSV nao gerado de proposito -- o dataset do ano inteiro fica grande "
        "demais em CSV; usar o parquet, ou gerar um CSV so de uma amostra se precisar.)"
    )
    return caminho_parquet


def criar_parser() -> argparse.ArgumentParser:
    """Cria a interface de linha de comando usada localmente e pelo Airflow."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--uf", default=ESTADO_PADRAO, help="Sigla da UF, como SP.")
    parser.add_argument("--ano", type=int, default=ANO_PADRAO)
    parser.add_argument("--mes-inicio", type=int, default=1)
    parser.add_argument("--mes-fim", type=int, default=12)
    parser.add_argument(
        "--arquivos-mensais",
        action="store_true",
        help="Salva um Parquet por competência para limitar o uso de memória.",
    )
    parser.add_argument(
        "--pular-existentes",
        action="store_true",
        help="Com --arquivos-mensais, reutiliza competências já baixadas.",
    )
    return parser


if __name__ == "__main__":
    args = criar_parser().parse_args()
    uf = args.uf.upper()
    validar_parametros(uf, args.ano, args.mes_inicio, args.mes_fim)
    if args.arquivos_mensais:
        baixar_competencias_separadas(
            uf,
            args.ano,
            args.mes_inicio,
            args.mes_fim,
            pular_existentes=args.pular_existentes,
        )
    else:
        df = baixar_periodo(uf, args.ano, args.mes_inicio, args.mes_fim)
        salvar(df, uf, args.ano, args.mes_inicio, args.mes_fim)
