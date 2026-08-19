"""Baixa o cadastro de estabelecimentos do CNES via API REST (JSON) do
Ministerio da Saude, para um estado (Fonte 2 do desafio: "JSON via API").

Descobertas validadas durante o desenvolvimento em 2026-08-05:
- Filtro de estado: usar `codigo_uf` (codigo IBGE, ex.: SP=35). O
  parametro `uf` (sigla) e' aceito sem erro mas e' silenciosamente
  ignorado -- nao filtra nada.
- Paginacao: parametro `offset` (baseado em registro, nao em pagina) +
  `limit`. Pedir `limit` >= 20 sempre retorna exatamente 20 (parece
  ser o teto). **Atencao**: se `limit` nao for enviado, o padrao e' 5,
  nao 20 -- um bug na primeira versao deste script (esquecemos de
  mandar `limit`) fez cada "pagina de 20" virar silenciosamente uma
  pagina de 5, sem erro nenhum (a API so retorna menos registros, nao
  avisa). Sempre mandar `limit` explicitamente.
- A API nao valida parametros desconhecidos (retorna 200 e ignora),
  entao um nome de parametro errado falha silenciosamente, nao com
  erro -- checar sempre o resultado, nao so o status code.
- Nao existem sub-recursos separados por tipo (leitos, hospitais, etc),
  so `/cnes/estabelecimentos` -- o cadastro completo, com o tipo do
  estabelecimento na coluna `codigo_tipo_unidade`. Filtragem por tipo
  (hospital vs. posto de saude vs. consultorio) fica pra camada Prata
  do pipeline, nao pra este download.

Uso:
    python baixar_cnes_api.py
"""

import concurrent.futures
import time

import pandas as pd
import requests

BASE_URL = "https://apidadosabertos.saude.gov.br/cnes/estabelecimentos"
CODIGO_UF_SP = 35
TAMANHO_PAGINA = 20  # fixo pela API, nao configuravel
MAX_WORKERS = 15

PASTA_SAIDA = "dados"


def buscar_pagina(
    offset: int, estado_codigo_uf: int, tentativas: int = 3
) -> list[dict]:
    for tentativa in range(tentativas):
        try:
            r = requests.get(
                BASE_URL,
                params={
                    "codigo_uf": estado_codigo_uf,
                    "offset": offset,
                    "limit": TAMANHO_PAGINA,
                },
                timeout=30,
            )
            r.raise_for_status()
            return r.json().get("estabelecimentos", [])
        except requests.RequestException:
            if tentativa == tentativas - 1:
                raise
            time.sleep(1.5 * (tentativa + 1))
    return []


def descobrir_total(estado_codigo_uf: int) -> int:
    """Busca binaria pra achar o offset onde os resultados acabam."""
    lo, hi = 0, 20
    while buscar_pagina(hi, estado_codigo_uf):
        lo = hi
        hi *= 2
    while hi - lo > TAMANHO_PAGINA:
        mid = (lo + hi) // 2 // TAMANHO_PAGINA * TAMANHO_PAGINA
        if buscar_pagina(mid, estado_codigo_uf):
            lo = mid
        else:
            hi = mid
    return lo + TAMANHO_PAGINA


def baixar_tudo(total_estimado: int, estado_codigo_uf: int) -> pd.DataFrame:
    offsets = list(range(0, total_estimado, TAMANHO_PAGINA))
    print(f"Baixando {len(offsets)} paginas ({total_estimado} registros estimados)...")

    registros = []
    concluidas = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futuros = {
            executor.submit(buscar_pagina, off, estado_codigo_uf): off
            for off in offsets
        }
        for futuro in concurrent.futures.as_completed(futuros):
            registros.extend(futuro.result())
            concluidas += 1
            if concluidas % 500 == 0:
                print(f"  {concluidas}/{len(offsets)} paginas baixadas...")

    return pd.DataFrame(registros)


if __name__ == "__main__":
    print("Descobrindo o total de estabelecimentos de SP no CNES...")
    total = descobrir_total(CODIGO_UF_SP)
    print(f"Total estimado: {total}")

    df = baixar_tudo(total, CODIGO_UF_SP)
    df = df.drop_duplicates(subset="codigo_cnes")
    print(f"Total baixado (sem duplicatas): {df.shape[0]} linhas, {df.shape[1]} colunas.")

    import os

    os.makedirs(PASTA_SAIDA, exist_ok=True)
    caminho = f"{PASTA_SAIDA}/cnes_sp.parquet"
    df.to_parquet(caminho, index=False)
    print(f"Salvo em: {caminho}")
