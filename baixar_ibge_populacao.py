"""Baixa a estimativa de populacao por municipio do IBGE (via pysus),
filtrada para Sao Paulo, e salva em CSV (Fonte 3 do desafio: "CSV /
External Table" com populacao municipal).

Descoberta validada durante o desenvolvimento em 2026-08-05: o dataset
"ibge" do pysus mistura dois arquivos diferentes
por ano -- PROJUF (projecao por UF, com faixa etaria/sexo, sem
municipio) e POPTBR (populacao total por municipio, o que queremos).
O parametro `group` do pysus.ibge() nao funciona pra separar os dois
(mesmo problema de outros datasets do pysus -- o campo `group` do
catalogo vem sempre None). A forma que funciona: baixar sem filtro de
`group` e separar pelas linhas que tem `MUNIC_RES` preenchido (so
existem no arquivo POPTBR).

Uso:
    python baixar_ibge_populacao.py
"""

import os

import pysus

ANO = 2024
PREFIXO_MUNICIPIO_SP = "35"  # codigo IBGE do estado de Sao Paulo
PASTA_SAIDA = "dados"


def baixar_populacao_municipal(ano: int):
    print(f"Baixando dados de populacao do IBGE para {ano}...")
    df = pysus.ibge(year=ano, as_dataframe=True)

    pop_municipal = df[df["MUNIC_RES"].notna()].copy()
    pop_municipal["MUNIC_RES"] = pop_municipal["MUNIC_RES"].astype(str)

    print(f"Total de municipios no Brasil: {len(pop_municipal)}")
    return pop_municipal[["MUNIC_RES", "POPULACAO"]]


def filtrar_estado(df, prefixo_uf: str):
    return df[df["MUNIC_RES"].str.startswith(prefixo_uf)].reset_index(drop=True)


if __name__ == "__main__":
    pop_brasil = baixar_populacao_municipal(ANO)
    pop_sp = filtrar_estado(pop_brasil, PREFIXO_MUNICIPIO_SP)

    print(f"Municipios de SP: {pop_sp.shape[0]}")
    print(f"Populacao total de SP (soma): {pop_sp['POPULACAO'].astype(int).sum():,}")

    os.makedirs(PASTA_SAIDA, exist_ok=True)
    caminho = f"{PASTA_SAIDA}/ibge_populacao_sp_{ANO}.csv"
    pop_sp.to_csv(caminho, index=False, encoding="utf-8-sig")
    print(f"Salvo em: {caminho}")
