"""Aplica a política de retry e limpa a staging de uma execução com falha."""

from __future__ import annotations

import argparse
import re

from carregar_competencia_oracle import conectar_oracle


TABELAS_STAGING = (
    "stg_fato_internacao",
    "stg_dim_estabelecimento",
    "stg_dim_tipo_atendimento",
    "stg_dim_municipio",
)


def validar_uuid(valor: str) -> str:
    if not re.fullmatch(
        r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
        r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}",
        valor,
    ):
        raise argparse.ArgumentTypeError("execucao-id deve ser um UUID.")
    return valor


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execucao-id", type=validar_uuid, required=True)
    parser.add_argument("--executar", action="store_true")
    args = parser.parse_args()
    if not args.executar:
        print("Nenhuma alteração realizada; informe --executar para confirmar.")
        return

    with conectar_oracle() as conexao:
        with conexao.cursor() as cursor:
            cursor.execute(
                """
                SELECT COUNT(*)
                FROM etl_execucao
                WHERE execucao_id = :execucao_id
                  AND status = 'FALHA'
                """,
                execucao_id=args.execucao_id,
            )
            if cursor.fetchone()[0] != 1:
                raise RuntimeError("A execução alvo não está registrada como FALHA.")

            cursor.execute(
                """
                SELECT COUNT(*)
                FROM (
                    SELECT uf, ano_competencia, mes_competencia, sha256_sih
                    FROM etl_execucao
                    WHERE status = 'SUCESSO'
                    GROUP BY uf, ano_competencia, mes_competencia, sha256_sih
                    HAVING COUNT(*) > 1
                )
                """
            )
            if cursor.fetchone()[0] != 0:
                raise RuntimeError("Existem sucessos duplicados; correção cancelada.")

            cursor.execute(
                """
                SELECT COUNT(*)
                FROM user_constraints
                WHERE constraint_name = 'UK_ETL_EXECUCAO_ARQUIVO'
                """
            )
            if cursor.fetchone()[0] == 1:
                cursor.execute(
                    """
                    ALTER TABLE etl_execucao
                    DROP CONSTRAINT uk_etl_execucao_arquivo
                    """
                )

            cursor.execute(
                """
                SELECT COUNT(*)
                FROM user_indexes
                WHERE index_name = 'UK_ETL_EXECUCAO_SUCESSO'
                """
            )
            if cursor.fetchone()[0] == 0:
                cursor.execute(
                    """
                    CREATE UNIQUE INDEX uk_etl_execucao_sucesso
                        ON etl_execucao (
                            CASE WHEN status = 'SUCESSO' THEN uf END,
                            CASE WHEN status = 'SUCESSO' THEN ano_competencia END,
                            CASE WHEN status = 'SUCESSO' THEN mes_competencia END,
                            CASE WHEN status = 'SUCESSO' THEN sha256_sih END
                        )
                    """
                )

            removidas: list[tuple[str, int]] = []
            for tabela in TABELAS_STAGING:
                cursor.execute(
                    f"DELETE FROM {tabela} WHERE execucao_id = :execucao_id",
                    execucao_id=args.execucao_id,
                )
                removidas.append((tabela, cursor.rowcount))
            conexao.commit()

            cursor.execute("SELECT COUNT(*) FROM fato_internacao")
            total_fato = int(cursor.fetchone()[0])
            cursor.execute(
                """
                SELECT COUNT(*)
                FROM user_indexes
                WHERE index_name = 'UK_ETL_EXECUCAO_SUCESSO'
                  AND status = 'VALID'
                """
            )
            indice_valido = cursor.fetchone()[0] == 1

    print(f"Índice de retry válido: {indice_valido}")
    print(f"Staging removida: {removidas}")
    print(f"Fato preservada: {total_fato}")


if __name__ == "__main__":
    main()
