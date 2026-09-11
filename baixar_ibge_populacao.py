"""Baixa estimativas oficiais anuais da população municipal do IBGE.

O coletor seleciona uma UF ou todo o Brasil e gera o CSV consumido pelo
pipeline incremental do Health Data.

Fonte oficial:
IBGE — Estimativas da População Residente nos Municípios Brasileiros,
data de referência em 1º de julho do ano selecionado.

Saída padrão:
    dados/ibge_populacao_sp_2024.csv

Colunas:
    MUNIC_RES_IBGE
    NOME_MUNICIPIO
    POPULACAO
"""

import argparse
from pathlib import Path
import unicodedata

import pandas as pd
import requests


ANO_PADRAO = 2024
UF_PADRAO = "SP"
UFS_BRASIL = {
    "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT",
    "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO",
    "RR", "SC", "SP", "SE", "TO",
}
TOTAIS_ESPERADOS = {
    ("BR", 2024): 5_570,
    ("SP", 2024): 645,
    ("BR", 2025): 5_571,
    ("SP", 2025): 645,
}

URL_IBGE_2024 = (
    "https://ftp.ibge.gov.br/Estimativas_de_Populacao/"
    "Estimativas_2024/estimativa_dou_2024.xls"
)
URL_IBGE_2025 = (
    "https://ftp.ibge.gov.br/Estimativas_de_Populacao/"
    "Estimativas_2025/POP2025_20260828.xls"
)

URLS_IBGE = {
    2024: URL_IBGE_2024,
    2025: URL_IBGE_2025,
}

PASTA_DADOS = Path("dados")


def resolver_url(ano: int, url: str | None = None) -> str:
    """Resolve a fonte oficial sem presumir o padrão de edições futuras."""
    if url:
        return url
    if ano in URLS_IBGE:
        return URLS_IBGE[ano]
    raise ValueError(
        "Informe --url para uma edição ainda não cadastrada; "
        "o endereço do IBGE pode mudar."
    )


def caminho_xls(ano: int) -> Path:
    """Retorna o caminho local do arquivo bruto anual."""
    return PASTA_DADOS / f"estimativa_dou_{ano}.xls"


def caminho_csv(uf: str, ano: int) -> Path:
    """Retorna o caminho local da dimensão populacional por UF e ano."""
    return PASTA_DADOS / f"ibge_populacao_{uf.strip().lower()}_{ano}.csv"


def baixar_xls(ano: int, url: str, arquivo_xls: Path) -> None:
    """Baixa o XLS oficial do IBGE."""
    PASTA_DADOS.mkdir(parents=True, exist_ok=True)

    print(f"Baixando estimativas oficiais do IBGE para {ano}...")

    resposta = requests.get(url, timeout=60)
    resposta.raise_for_status()

    arquivo_xls.write_bytes(resposta.content)

    print(f"Arquivo original salvo em: {arquivo_xls}")


def localizar_aba_municipios(nomes_abas: list[str]) -> str:
    """Localiza a aba municipal sem depender de caixa ou acentuação."""
    for nome in nomes_abas:
        normalizado = "".join(
            caractere
            for caractere in unicodedata.normalize("NFKD", nome)
            if not unicodedata.combining(caractere)
        ).casefold()
        if normalizado == "municipios":
            return nome
    raise ValueError("IBGE: aba de municípios não encontrada na planilha.")


def preparar_municipios(arquivo_xls: Path, uf: str) -> pd.DataFrame:
    """Lê o XLS e seleciona uma UF ou todo o Brasil com ``BR``."""

    aba_municipios = localizar_aba_municipios(
        list(pd.ExcelFile(arquivo_xls).sheet_names)
    )

    df = pd.read_excel(
        arquivo_xls,
        sheet_name=aba_municipios,
        header=1,
        dtype={
            "UF": str,
            "COD. UF": str,
            "COD. MUNIC": str,
        },
    )

    uf_normalizada = uf.strip().upper()
    if uf_normalizada == "BR":
        selecionados = df[df["UF"].str.strip().isin(UFS_BRASIL)].copy()
    else:
        selecionados = df[df["UF"].str.strip() == uf_normalizada].copy()
    if selecionados.empty:
        raise ValueError(f"IBGE: nenhum município encontrado para a UF {uf_normalizada}.")

    # Código IBGE completo de 7 dígitos:
    # COD. UF (2 dígitos) + COD. MUNIC (5 dígitos)
    selecionados["MUNIC_RES_IBGE"] = (
        selecionados["COD. UF"].str.strip().str.zfill(2)
        + selecionados["COD. MUNIC"].str.strip().str.zfill(5)
    )

    selecionados["NOME_MUNICIPIO"] = (
        selecionados["NOME DO MUNICÍPIO"]
        .astype("string")
        .str.strip()
    )

    selecionados["POPULACAO"] = pd.to_numeric(
        selecionados["POPULAÇÃO ESTIMADA"],
        errors="raise",
    ).astype(int)

    colunas = ["MUNIC_RES_IBGE", "NOME_MUNICIPIO", "POPULACAO"]
    if uf_normalizada == "BR":
        selecionados["UF"] = selecionados["UF"].str.strip()
        colunas.append("UF")

    resultado = (
        selecionados[colunas]
        .sort_values("MUNIC_RES_IBGE")
        .reset_index(drop=True)
    )

    return resultado


def validar(df: pd.DataFrame, total_esperado: int | None = None) -> None:
    """Valida a integridade básica da dimensão municipal."""

    if df.empty:
        raise ValueError("Nenhum município foi encontrado.")

    if total_esperado is not None and len(df) != total_esperado:
        raise ValueError(
            f"Esperados {total_esperado} municípios, "
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


def salvar_csv(df: pd.DataFrame, arquivo_csv: Path) -> None:
    """Salva o arquivo consumido pela external table do Oracle."""

    df.to_csv(
        arquivo_csv,
        index=False,
        encoding="utf-8",
    )

    print(f"CSV salvo em: {arquivo_csv}")


def coletar(
    uf: str = UF_PADRAO,
    ano: int = ANO_PADRAO,
    url: str | None = None,
) -> Path:
    """Executa a coleta populacional de uma UF e devolve o CSV gerado."""
    uf_normalizada = uf.strip().upper()
    if uf_normalizada != "BR" and uf_normalizada not in UFS_BRASIL:
        raise ValueError("UF deve conter exatamente duas letras ou BR.")
    if ano < 2000:
        raise ValueError("Ano inválido para a estimativa populacional.")

    fonte = resolver_url(ano, url)
    arquivo_xls = caminho_xls(ano)
    arquivo_csv = caminho_csv(uf_normalizada, ano)
    baixar_xls(ano, fonte, arquivo_xls)
    municipios = preparar_municipios(arquivo_xls, uf_normalizada)
    total_esperado = TOTAIS_ESPERADOS.get((uf_normalizada, ano))
    validar(municipios, total_esperado=total_esperado)
    salvar_csv(municipios, arquivo_csv)

    print("\nPrimeiros 10 registros:")
    print(municipios.head(10).to_string(index=False))
    return arquivo_csv


def criar_parser() -> argparse.ArgumentParser:
    """Cria a interface de linha de comando usada localmente e pelo Airflow."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--uf",
        default=UF_PADRAO,
        help="Sigla da UF, como SP, ou BR para todos os municípios.",
    )
    parser.add_argument("--ano", type=int, default=ANO_PADRAO)
    parser.add_argument(
        "--url",
        help="URL oficial do XLS; obrigatória quando o ano não for 2024.",
    )
    return parser


if __name__ == "__main__":
    argumentos = criar_parser().parse_args()
    coletar(argumentos.uf, argumentos.ano, argumentos.url)
