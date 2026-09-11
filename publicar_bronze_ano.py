"""Publica um conjunto anual validado na camada Bronze do Object Storage.

O comportamento padrão somente apresenta o plano. A escrita exige ``--executar``.
Objetos já existentes são reutilizados apenas quando tamanho e SHA-256 coincidem.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(PROJECT_ROOT / "src"))

from health_data_pipeline.object_storage import (  # noqa: E402
    nome_objeto_bronze,
    publicar_arquivo,
)


@dataclass(frozen=True)
class ItemBronze:
    """Arquivo local e destino imutável correspondente."""

    arquivo: Path
    nome_objeto: str


def localizar_arquivos_sih(diretorio: Path, uf: str, ano: int) -> list[Path]:
    """Localiza exatamente um arquivo mensal para cada competência do ano."""
    arquivos: list[Path] = []
    for mes in range(1, 13):
        encontrados = sorted(
            diretorio.glob(f"sih_{uf.lower()}_{ano}_{mes:02d}_*.parquet")
        )
        if len(encontrados) != 1:
            raise ValueError(
                f"Esperado um arquivo SIH para {mes:02d}/{ano}; "
                f"encontrados: {len(encontrados)}."
            )
        arquivos.append(encontrados[0])
    return arquivos


def montar_plano(
    diretorio_sih: Path,
    cnes: Path,
    ibge: Path,
    *,
    uf: str,
    ano: int,
    data_extracao_cnes: date,
) -> list[ItemBronze]:
    """Monta os destinos Bronze das fontes necessárias ao backfill anual."""
    itens: list[ItemBronze] = []
    for mes, arquivo in enumerate(
        localizar_arquivos_sih(diretorio_sih, uf, ano), start=1
    ):
        itens.append(
            ItemBronze(
                arquivo,
                nome_objeto_bronze("sih", arquivo, uf, ano=ano, mes=mes),
            )
        )
    itens.append(
        ItemBronze(
            cnes,
            nome_objeto_bronze(
                "cnes", cnes, uf, data_extracao=data_extracao_cnes
            ),
        )
    )
    itens.append(
        ItemBronze(
            ibge,
            nome_objeto_bronze("ibge", ibge, "BR", ano=ano),
        )
    )
    ausentes = [str(item.arquivo) for item in itens if not item.arquivo.is_file()]
    if ausentes:
        raise FileNotFoundError("Arquivos ausentes: " + ", ".join(ausentes))
    return itens


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
    parser.add_argument(
        "--modo-autenticacao",
        choices=("config_file", "instance_principal"),
        default="config_file",
    )
    parser.add_argument("--perfil", default="DEFAULT")
    parser.add_argument(
        "--executar",
        action="store_true",
        help="Confirma a publicação dos objetos no bucket.",
    )
    return parser


def main() -> None:
    args = criar_parser().parse_args()
    plano = montar_plano(
        args.diretorio_sih,
        args.cnes,
        args.ibge,
        uf=args.uf,
        ano=args.ano,
        data_extracao_cnes=args.data_extracao_cnes,
    )
    volume = sum(item.arquivo.stat().st_size for item in plano)
    print(f"Plano Bronze: {len(plano)} objetos, {volume / 1024**2:.1f} MiB.")
    for item in plano:
        print(f"- {item.arquivo} -> {item.nome_objeto}")

    if not args.executar:
        print("Planejamento concluído; nenhum objeto foi enviado.")
        return

    for item in plano:
        resultado = publicar_arquivo(
            item.arquivo,
            args.bucket,
            item.nome_objeto,
            modo_autenticacao=args.modo_autenticacao,
            perfil=args.perfil,
        )
        estado = "criado" if resultado.criado else "reutilizado"
        print(f"{estado}: {resultado.nome_objeto}")

    print(f"Publicação Bronze concluída: {len(plano)} objetos validados.")


if __name__ == "__main__":
    main()
