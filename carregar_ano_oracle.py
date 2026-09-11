"""Planeja ou executa o backfill anual validado no Autonomous Database.

O modo padrão é somente leitura. Antes de qualquer escrita, o comando valida os
12 arquivos locais, os objetos Bronze, o snapshot de recuperação, as stagings e
as dependências históricas. A execução exige uma confirmação textual explícita.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from uuid import uuid4


PROJECT_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(PROJECT_ROOT / "src"))

from carregar_competencia_oracle import conectar_oracle  # noqa: E402
from health_data_pipeline.object_storage import (  # noqa: E402
    calcular_sha256,
    criar_cliente_object_storage,
)
from health_data_pipeline.oracle_staging import (  # noqa: E402
    executar_carga_incremental,
    preparar_staging,
)
from publicar_bronze_ano import montar_plano  # noqa: E402


CONTAGENS_BACKUP = {
    "dim_municipio": 645,
    "dim_tipo_atend": 14,
    "dim_estabelec": 233,
    "fato_internacao": 5_925,
}
TABELAS_STAGING = (
    "stg_dim_municipio",
    "stg_dim_tipo_atendimento",
    "stg_dim_estabelecimento",
    "stg_fato_internacao",
)


@dataclass(frozen=True)
class CompetenciaPlanejada:
    """Manifesto local e Bronze de uma competência validada."""

    mes: int
    arquivo: Path
    objeto_bronze: str
    sha256: str
    total_internacoes: int
    cnes_historicos: tuple[str, ...]


def token_confirmacao(uf: str, ano: int, total: int) -> str:
    """Gera a confirmação humana exigida para iniciar o backfill."""
    return f"{uf.upper()}-{ano}-{total}"


def _validar_sufixo_backup(sufixo: str) -> str:
    if not re.fullmatch(r"\d{8}", sufixo):
        raise ValueError("O sufixo do backup deve possuir oito dígitos.")
    return sufixo


def preparar_manifesto(
    diretorio_sih: Path,
    cnes: Path,
    ibge: Path,
    *,
    uf: str,
    ano: int,
    data_extracao_cnes: date,
) -> tuple[list[CompetenciaPlanejada], list[tuple[Path, str]]]:
    """Valida todas as competências antes da primeira transação de escrita."""
    itens_bronze = montar_plano(
        diretorio_sih,
        cnes,
        ibge,
        uf=uf,
        ano=ano,
        data_extracao_cnes=data_extracao_cnes,
    )
    por_arquivo = {item.arquivo: item.nome_objeto for item in itens_bronze}
    competencias: list[CompetenciaPlanejada] = []
    for mes in range(1, 13):
        arquivo = itens_bronze[mes - 1].arquivo
        frames = preparar_staging(
            arquivo,
            cnes,
            ibge,
            execucao_id=str(uuid4()),
            uf=uf,
            ano=ano,
            mes=mes,
        )
        competencias.append(
            CompetenciaPlanejada(
                mes=mes,
                arquivo=arquivo,
                objeto_bronze=por_arquivo[arquivo],
                sha256=calcular_sha256(arquivo),
                total_internacoes=len(frames.internacoes),
                cnes_historicos=frames.codigos_cnes_sem_cadastro_atual,
            )
        )
    fontes = [(item.arquivo, item.nome_objeto) for item in itens_bronze]
    return competencias, fontes


def validar_objetos_bronze(
    fontes: list[tuple[Path, str]],
    *,
    bucket: str,
    modo_autenticacao: str,
    perfil: str,
) -> None:
    """Confirma presença, tamanho e hash das fontes sem criar objetos."""
    cliente = criar_cliente_object_storage(modo_autenticacao, perfil)
    namespace = cliente.get_namespace().data
    for arquivo, nome_objeto in fontes:
        resposta = cliente.head_object(namespace, bucket, nome_objeto)
        tamanho_remoto = int(resposta.headers.get("content-length", -1))
        hash_remoto = resposta.headers.get("opc-meta-sha256")
        hash_local = calcular_sha256(arquivo)
        if tamanho_remoto != arquivo.stat().st_size or hash_remoto != hash_local:
            raise RuntimeError(f"Objeto Bronze divergente: {nome_objeto}.")


def validar_oracle(
    conexao,
    competencias: list[CompetenciaPlanejada],
    *,
    sufixo_backup: str,
) -> None:
    """Confirma snapshot, staging vazia e CNES históricos necessários."""
    sufixo = _validar_sufixo_backup(sufixo_backup)
    with conexao.cursor() as cursor:
        for nome, esperado in CONTAGENS_BACKUP.items():
            cursor.execute(f"SELECT COUNT(*) FROM bkp_{nome}_{sufixo}")
            encontrado = int(cursor.fetchone()[0])
            if encontrado != esperado:
                raise RuntimeError(
                    f"Backup bkp_{nome}_{sufixo}: {encontrado}; esperado {esperado}."
                )

        for tabela in TABELAS_STAGING:
            cursor.execute(f"SELECT COUNT(*) FROM {tabela}")
            if int(cursor.fetchone()[0]) != 0:
                raise RuntimeError(f"A tabela {tabela} não está vazia.")

        cursor.execute("SELECT COUNT(*) FROM fato_internacao")
        total_atual = int(cursor.fetchone()[0])
        if total_atual != CONTAGENS_BACKUP["fato_internacao"]:
            raise RuntimeError(
                "A fato atual não corresponde ao snapshot inicial; "
                f"encontradas {total_atual} linhas."
            )

        historicos = sorted(
            {codigo for item in competencias for codigo in item.cnes_historicos}
        )
        for codigo in historicos:
            cursor.execute(
                "SELECT COUNT(*) FROM dim_estabelecimento WHERE codigo_cnes = :codigo",
                codigo=codigo,
            )
            if int(cursor.fetchone()[0]) != 1:
                raise RuntimeError(f"CNES histórico ausente no Oracle: {codigo}.")


def criar_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--uf", default="SP")
    parser.add_argument("--ano", type=int, default=2024)
    parser.add_argument("--diretorio-sih", type=Path, default=Path("dados"))
    parser.add_argument("--cnes", type=Path, default=Path("dados/cnes_sp.parquet"))
    parser.add_argument(
        "--ibge", type=Path, default=Path("dados/ibge_populacao_br_2024.csv")
    )
    parser.add_argument("--data-extracao-cnes", type=date.fromisoformat, required=True)
    parser.add_argument("--sufixo-backup", default="20260910")
    parser.add_argument(
        "--modo-autenticacao",
        choices=("config_file", "instance_principal"),
        default="config_file",
    )
    parser.add_argument("--perfil", default="DEFAULT")
    parser.add_argument("--executar", action="store_true")
    parser.add_argument(
        "--confirmar",
        help="Token exibido pelo planejamento e obrigatório com --executar.",
    )
    return parser


def main() -> None:
    args = criar_parser().parse_args()
    competencias, fontes = preparar_manifesto(
        args.diretorio_sih,
        args.cnes,
        args.ibge,
        uf=args.uf,
        ano=args.ano,
        data_extracao_cnes=args.data_extracao_cnes,
    )
    total = sum(item.total_internacoes for item in competencias)
    validar_objetos_bronze(
        fontes,
        bucket=args.bucket,
        modo_autenticacao=args.modo_autenticacao,
        perfil=args.perfil,
    )
    with conectar_oracle() as conexao:
        validar_oracle(
            conexao,
            competencias,
            sufixo_backup=args.sufixo_backup,
        )

    print("Planejamento anual validado:")
    for item in competencias:
        print(f"- {item.mes:02d}/{args.ano}: {item.total_internacoes} internações")
    print(f"Total: {total} internações; Bronze, backup e staging conferidos.")

    confirmacao = token_confirmacao(args.uf, args.ano, total)
    if not args.executar:
        print("Nenhuma escrita foi feita no Oracle.")
        print(f"Token para execução controlada: {confirmacao}")
        return
    if args.confirmar != confirmacao:
        raise RuntimeError(f"Confirmação inválida; esperado: {confirmacao}")

    for item in competencias:
        execucao_id = str(uuid4())
        frames = preparar_staging(
            item.arquivo,
            args.cnes,
            args.ibge,
            execucao_id=execucao_id,
            uf=args.uf,
            ano=args.ano,
            mes=item.mes,
        )
        with conectar_oracle() as conexao:
            resultado = executar_carga_incremental(
                conexao,
                frames,
                execucao_id=execucao_id,
                uf=args.uf,
                ano=args.ano,
                mes=item.mes,
                objeto_sih=item.objeto_bronze,
                sha256_sih=item.sha256,
            )
            with conexao.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT COUNT(*)
                    FROM fato_internacao
                    WHERE ano_competencia = :ano AND mes_competencia = :mes
                    """,
                    ano=args.ano,
                    mes=item.mes,
                )
                publicado = int(cursor.fetchone()[0])
        if publicado != item.total_internacoes:
            raise RuntimeError(
                f"Reconciliação falhou em {item.mes:02d}/{args.ano}: "
                f"{publicado} publicados; esperado {item.total_internacoes}. "
                "Interrompa o uso do dashboard e execute o script de restauração."
            )
        print(
            f"{item.mes:02d}/{args.ano}: {resultado.status}, "
            f"{publicado} linhas reconciliadas."
        )

    with conectar_oracle() as conexao:
        with conexao.cursor() as cursor:
            cursor.execute(
                "SELECT COUNT(*) FROM fato_internacao WHERE ano_competencia = :ano",
                ano=args.ano,
            )
            total_publicado = int(cursor.fetchone()[0])
    if total_publicado != total:
        raise RuntimeError(
            f"Reconciliação anual falhou: {total_publicado}; esperado {total}."
        )
    print(f"Backfill concluído e reconciliado: {total_publicado} internações.")


if __name__ == "__main__":
    main()
