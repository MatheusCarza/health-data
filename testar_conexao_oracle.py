"""Testa a conexão e os objetos do ETL sem escrever no banco."""

from __future__ import annotations

from carregar_competencia_oracle import conectar_oracle


OBJETOS_ESPERADOS = {
    "ETL_EXECUCAO",
    "PKG_HEALTH_DATA_ETL",
    "STG_DIM_ESTABELECIMENTO",
    "STG_DIM_MUNICIPIO",
    "STG_DIM_TIPO_ATENDIMENTO",
    "STG_FATO_INTERNACAO",
    "UK_FATO_INTERNACAO_ORIGEM",
}


def main() -> None:
    with conectar_oracle() as conexao:
        with conexao.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
                    SYS_CONTEXT('USERENV', 'DB_NAME')
                FROM dual
                """
            )
            schema, banco = cursor.fetchone()
            cursor.execute(
                """
                SELECT object_name, object_type, status
                FROM user_objects
                WHERE object_name IN (
                    'ETL_EXECUCAO',
                    'PKG_HEALTH_DATA_ETL',
                    'STG_DIM_ESTABELECIMENTO',
                    'STG_DIM_MUNICIPIO',
                    'STG_DIM_TIPO_ATENDIMENTO',
                    'STG_FATO_INTERNACAO',
                    'UK_FATO_INTERNACAO_ORIGEM'
                )
                ORDER BY object_type, object_name
                """
            )
            objetos = cursor.fetchall()

    encontrados = {linha[0] for linha in objetos if linha[2] == "VALID"}
    ausentes = OBJETOS_ESPERADOS - encontrados
    if ausentes:
        raise RuntimeError(
            "Conexão realizada, mas faltam objetos válidos: "
            + ", ".join(sorted(ausentes))
        )

    print(f"Conexão válida: banco={banco}, schema={schema}")
    print(f"Objetos do ETL válidos: {len(encontrados)}")
    print("Teste somente leitura concluído; nenhuma tabela foi alterada.")


if __name__ == "__main__":
    main()
