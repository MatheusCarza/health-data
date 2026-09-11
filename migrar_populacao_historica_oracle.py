"""Instala o histórico populacional e recompila o pacote incremental Oracle."""

from __future__ import annotations

import argparse
from pathlib import Path

from carregar_competencia_oracle import conectar_oracle


PROJECT_ROOT = Path(__file__).resolve().parent
ARQUIVO_MIGRACAO = (
    PROJECT_ROOT / "sql" / "populacao_municipio_historica_20260911.sql"
)
ARQUIVO_ETL = PROJECT_ROOT / "sql" / "etl_incremental.sql"


def token_confirmacao(total_populacoes_2024: int) -> str:
    """Retorna o token que explicita o volume histórico a preservar."""
    return f"POP-HIST-2024-{total_populacoes_2024}"


def extrair_statements_migracao(texto: str) -> list[str]:
    """Extrai apenas a seção executável delimitada por barras isoladas."""
    inicio = texto.index("-- BEGIN MIGRATION")
    fim = texto.index("-- END MIGRATION")
    trecho = texto[inicio:fim].splitlines()[1:]
    statements: list[str] = []
    atual: list[str] = []
    for linha in trecho:
        if linha.strip() == "/":
            statement = "\n".join(atual).strip()
            if statement:
                if not statement.upper().startswith(("BEGIN", "DECLARE")):
                    statement = statement.removesuffix(";").rstrip()
                statements.append(statement)
            atual = []
        else:
            atual.append(linha)
    if any(linha.strip() for linha in atual):
        raise ValueError("Migração possui statement sem delimitador '/'.")
    return statements


def extrair_package_body(texto: str) -> str:
    """Extrai o package body completo, sem o separador do cliente SQL."""
    marcador = "CREATE OR REPLACE PACKAGE BODY pkg_health_data_etl AS"
    inicio = texto.index(marcador)
    corpo = texto[inicio:].rstrip()
    if not corpo.endswith("/"):
        raise ValueError("Package body sem terminador '/'.")
    return corpo[:-1].rstrip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executar", action="store_true")
    parser.add_argument("--confirmar")
    args = parser.parse_args()

    with conectar_oracle() as conexao:
        with conexao.cursor() as cursor:
            cursor.execute(
                "SELECT COUNT(*) FROM dim_municipio "
                "WHERE populacao_2024 IS NOT NULL"
            )
            total_2024 = int(cursor.fetchone()[0])
            cursor.execute(
                """
                SELECT SUM(total)
                FROM (
                    SELECT COUNT(*) AS total FROM stg_dim_municipio
                    UNION ALL SELECT COUNT(*) FROM stg_dim_tipo_atendimento
                    UNION ALL SELECT COUNT(*) FROM stg_dim_estabelecimento
                    UNION ALL SELECT COUNT(*) FROM stg_fato_internacao
                )
                """
            )
            total_staging = int(cursor.fetchone()[0])

        token = token_confirmacao(total_2024)
        print(f"Populações 2024 a preservar: {total_2024}")
        print(f"Linhas atualmente nas stagings: {total_staging}")
        print(f"Token de confirmação: {token}")

        if total_staging != 0:
            raise RuntimeError("As stagings precisam estar vazias antes da migração.")
        if not args.executar:
            print("Planejamento concluído; nenhuma alteração foi feita no Oracle.")
            return
        if args.confirmar != token:
            raise RuntimeError("Token de confirmação ausente ou divergente.")

        statements = extrair_statements_migracao(
            ARQUIVO_MIGRACAO.read_text(encoding="utf-8")
        )
        package_body = extrair_package_body(
            ARQUIVO_ETL.read_text(encoding="utf-8")
        )
        with conexao.cursor() as cursor:
            for statement in statements:
                cursor.execute(statement)
            cursor.execute(package_body)
            conexao.commit()

            cursor.execute(
                """
                SELECT COUNT(*)
                FROM dim_municipio_populacao
                WHERE ano_referencia = 2024
                """
            )
            historico_2024 = int(cursor.fetchone()[0])
            cursor.execute(
                """
                SELECT COUNT(*)
                FROM user_objects
                WHERE object_name = 'PKG_HEALTH_DATA_ETL'
                  AND object_type IN ('PACKAGE', 'PACKAGE BODY')
                  AND status = 'VALID'
                """
            )
            objetos_validos = int(cursor.fetchone()[0])
            cursor.execute(
                """
                SELECT COUNT(*)
                FROM user_errors
                WHERE name = 'PKG_HEALTH_DATA_ETL'
                """
            )
            erros_pacote = int(cursor.fetchone()[0])

    if historico_2024 != total_2024:
        raise RuntimeError("Histórico de 2024 diverge da dimensão legada.")
    if objetos_validos != 2 or erros_pacote != 0:
        raise RuntimeError("O pacote incremental não ficou totalmente válido.")
    print(f"Histórico 2024 migrado: {historico_2024}")
    print("PKG_HEALTH_DATA_ETL: PACKAGE e PACKAGE BODY válidos")
    print("MIGRAÇÃO_POPULAÇÃO_HISTÓRICA=APROVADA")


if __name__ == "__main__":
    main()
