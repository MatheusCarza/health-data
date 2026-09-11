"""Audita o backfill anual do Health Data sem modificar o Oracle."""

from __future__ import annotations

from carregar_competencia_oracle import conectar_oracle


CONTAGENS_MENSAIS = {
    1: 222_849,
    2: 221_117,
    3: 241_806,
    4: 244_842,
    5: 246_414,
    6: 240_552,
    7: 241_470,
    8: 246_085,
    9: 240_093,
    10: 250_130,
    11: 234_425,
    12: 225_756,
}


def main() -> None:
    esperado_anual = sum(CONTAGENS_MENSAIS.values())
    with conectar_oracle() as conexao:
        with conexao.cursor() as cursor:
            cursor.execute(
                """
                SELECT mes_competencia, COUNT(*)
                FROM fato_internacao
                WHERE ano_competencia = 2024
                GROUP BY mes_competencia
                ORDER BY mes_competencia
                """
            )
            meses = {int(mes): int(total) for mes, total in cursor.fetchall()}

            cursor.execute(
                """
                SELECT
                    COUNT(*) AS total,
                    COUNT(
                        DISTINCT ano_competencia || '-' || mes_competencia ||
                        '-' || id_registro_origem
                    ) AS chaves_distintas,
                    SUM(CASE WHEN id_registro_origem IS NULL THEN 1 ELSE 0 END),
                    SUM(
                        CASE
                            WHEN indicador_obito NOT IN (0, 1)
                                 OR indicador_obito IS NULL THEN 1
                            ELSE 0
                        END
                    )
                FROM fato_internacao
                """
            )
            total, chaves, ids_nulos, obitos_invalidos = map(
                int, cursor.fetchone()
            )

            objetos = {}
            for tabela in (
                "dim_municipio",
                "dim_tipo_atendimento",
                "dim_estabelecimento",
                "fato_internacao",
            ):
                cursor.execute(f"SELECT COUNT(*) FROM {tabela}")
                objetos[tabela] = int(cursor.fetchone()[0])

            stagings = {}
            for tabela in (
                "stg_dim_municipio",
                "stg_dim_tipo_atendimento",
                "stg_dim_estabelecimento",
                "stg_fato_internacao",
            ):
                cursor.execute(f"SELECT COUNT(*) FROM {tabela}")
                stagings[tabela] = int(cursor.fetchone()[0])

            cursor.execute(
                """
                SELECT status, COUNT(*)
                FROM etl_execucao
                GROUP BY status
                ORDER BY status
                """
            )
            auditoria = {str(status): int(qtd) for status, qtd in cursor.fetchall()}

            cursor.execute(
                """
                SELECT
                    MIN(ano_competencia * 100 + mes_competencia),
                    MAX(ano_competencia * 100 + mes_competencia),
                    ROUND(SUM(valor_total), 2),
                    SUM(CASE WHEN indicador_obito = 1 THEN 1 ELSE 0 END)
                FROM fato_internacao
                """
            )
            competencia_min, competencia_max, valor_total, total_obitos = (
                cursor.fetchone()
            )

    erros = []
    if meses != CONTAGENS_MENSAIS:
        erros.append("contagens mensais divergentes")
    if total != esperado_anual or chaves != esperado_anual:
        erros.append("total ou unicidade anual divergente")
    if ids_nulos != 0 or obitos_invalidos != 0:
        erros.append("campos obrigatórios inválidos")
    if any(stagings.values()):
        erros.append("staging residual encontrada")
    if int(competencia_min) != 202401 or int(competencia_max) != 202412:
        erros.append("intervalo de competências divergente")
    if auditoria.get("SUCESSO") != 12:
        erros.append("não existem exatamente 12 execuções com sucesso")
    if erros:
        raise RuntimeError("; ".join(erros))

    print(f"Objetos: {objetos}")
    print(f"Competências: {meses}")
    print(f"Total e chaves distintas: {total}")
    print(f"IDs nulos: {ids_nulos}; óbitos inválidos: {obitos_invalidos}")
    print(f"Stagings: {stagings}")
    print(f"Auditoria: {auditoria}")
    print(f"Período: {competencia_min}-{competencia_max}")
    print(f"Valor total: {valor_total}; internações com óbito: {total_obitos}")
    print("AUDITORIA_PÓS_CARGA=APROVADA")


if __name__ == "__main__":
    main()
