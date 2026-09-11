"""Prepara ou executa uma carga mensal incremental no Autonomous Database.

Por segurança, o comportamento padrão apenas transforma e resume os dados.
Para escrever no Oracle é necessário informar explicitamente ``--executar``.
As credenciais e a wallet são lidas somente de variáveis de ambiente.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from uuid import uuid4

PROJECT_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(PROJECT_ROOT / "src"))

from health_data_pipeline.object_storage import calcular_sha256
from health_data_pipeline.oracle_staging import (
    executar_carga_incremental,
    preparar_staging,
)


def _variavel_obrigatoria(nome: str) -> str:
    valor = os.environ.get(nome, "").strip()
    if not valor:
        raise RuntimeError(f"Variável de ambiente obrigatória ausente: {nome}.")
    return valor


def _carregar_env_local() -> None:
    """Carrega o `.env` ignorado pelo Git sem imprimir valores sensíveis."""
    arquivo = PROJECT_ROOT / ".env"
    if not arquivo.is_file():
        return
    for numero_linha, linha in enumerate(
        arquivo.read_text(encoding="utf-8").splitlines(), start=1
    ):
        linha = linha.strip()
        if not linha or linha.startswith("#"):
            continue
        if "=" not in linha:
            raise RuntimeError(f".env inválido na linha {numero_linha}.")
        nome, valor = linha.split("=", 1)
        os.environ.setdefault(nome.strip(), valor.strip())


def conectar_oracle():
    """Abre conexão Thin usando uma wallet previamente descompactada."""
    import oracledb

    _carregar_env_local()
    wallet_dir = Path(_variavel_obrigatoria("ORACLE_WALLET_DIR")).expanduser()
    obrigatorios = [wallet_dir / "tnsnames.ora", wallet_dir / "ewallet.pem"]
    ausentes = [arquivo.name for arquivo in obrigatorios if not arquivo.is_file()]
    if ausentes:
        raise RuntimeError(
            "Wallet descompactada incompleta; ausentes: " + ", ".join(ausentes)
        )

    parametros = {
        "user": _variavel_obrigatoria("ORACLE_USER"),
        "password": _variavel_obrigatoria("ORACLE_PASSWORD"),
        "dsn": _variavel_obrigatoria("ORACLE_DSN"),
        "config_dir": str(wallet_dir),
        "wallet_location": str(wallet_dir),
    }
    wallet_password = os.environ.get("ORACLE_WALLET_PASSWORD", "").strip()
    if wallet_password:
        parametros["wallet_password"] = wallet_password
    return oracledb.connect(**parametros)


def criar_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sih", type=Path, required=True)
    parser.add_argument("--cnes", type=Path, required=True)
    parser.add_argument("--ibge", type=Path, required=True)
    parser.add_argument("--uf", default="SP")
    parser.add_argument("--ano", type=int, required=True)
    parser.add_argument("--mes", type=int, required=True)
    parser.add_argument(
        "--objeto-sih",
        help="Nome completo do objeto SIH na camada Bronze.",
    )
    parser.add_argument(
        "--executar",
        action="store_true",
        help="Confirma a escrita nas tabelas de staging e a publicação mensal.",
    )
    return parser


def main() -> None:
    args = criar_parser().parse_args()
    execucao_id = str(uuid4())
    frames = preparar_staging(
        args.sih,
        args.cnes,
        args.ibge,
        execucao_id=execucao_id,
        uf=args.uf,
        ano=args.ano,
        mes=args.mes,
    )
    print(f"Execução preparada: {execucao_id}")
    print(f"Municípios: {len(frames.municipios)}")
    print(f"Tipos de atendimento: {len(frames.tipos_atendimento)}")
    print(f"Estabelecimentos: {len(frames.estabelecimentos)}")
    print(f"Internações em {args.mes:02d}/{args.ano}: {len(frames.internacoes)}")
    if frames.codigos_cnes_sem_cadastro_atual:
        print(
            "CNES ausentes no cadastro atual, a validar na dimensão Oracle: "
            f"{len(frames.codigos_cnes_sem_cadastro_atual)}"
        )

    if not args.executar:
        print("Validação local concluída; nenhuma escrita foi feita no Oracle.")
        return
    if not args.objeto_sih:
        raise RuntimeError("--objeto-sih é obrigatório com --executar.")

    with conectar_oracle() as conexao:
        resultado = executar_carga_incremental(
            conexao,
            frames,
            execucao_id=execucao_id,
            uf=args.uf,
            ano=args.ano,
            mes=args.mes,
            objeto_sih=args.objeto_sih,
            sha256_sih=calcular_sha256(args.sih),
        )
    print(
        f"Carga {resultado.status}: {resultado.linhas_substituidas} linhas "
        f"publicadas (staging: {resultado.linhas_staging})."
    )


if __name__ == "__main__":
    main()
