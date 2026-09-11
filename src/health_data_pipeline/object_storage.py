"""Publicação imutável dos arquivos brutos no OCI Object Storage."""

from __future__ import annotations

from configparser import ConfigParser
from dataclasses import dataclass
from datetime import date
import hashlib
from pathlib import Path
from typing import Any


ORIGENS = {"sih", "cnes", "ibge"}


@dataclass(frozen=True)
class ResultadoPublicacao:
    """Comprovante mínimo de uma publicação ou reutilização idempotente."""

    bucket: str
    nome_objeto: str
    sha256: str
    tamanho_bytes: int
    criado: bool


def nome_objeto_bronze(
    origem: str,
    arquivo: Path,
    uf: str,
    *,
    ano: int | None = None,
    mes: int | None = None,
    data_extracao: date | None = None,
) -> str:
    """Monta o prefixo particionado da camada Bronze para cada fonte."""
    origem_normalizada = origem.strip().lower()
    if origem_normalizada not in ORIGENS:
        raise ValueError(f"Origem inválida: {origem!r}.")

    uf_normalizada = uf.strip().upper()
    if len(uf_normalizada) != 2 or not uf_normalizada.isalpha():
        raise ValueError("UF deve conter exatamente duas letras.")
    if not arquivo.name:
        raise ValueError("O arquivo deve possuir um nome.")

    prefixo = f"bronze/{origem_normalizada}/uf={uf_normalizada}"
    if origem_normalizada == "sih":
        if ano is None or mes is None:
            raise ValueError("SIH exige ano e mês da competência.")
        if not 1 <= mes <= 12:
            raise ValueError("Mês da competência deve estar entre 1 e 12.")
        prefixo += f"/ano={ano}/mes={mes:02d}"
    elif origem_normalizada == "ibge":
        if ano is None:
            raise ValueError("IBGE exige o ano de referência.")
        prefixo += f"/ano={ano}"
    else:
        referencia = data_extracao or date.today()
        prefixo += f"/data_extracao={referencia.isoformat()}"

    return f"{prefixo}/{arquivo.name}"


def calcular_sha256(arquivo: Path) -> str:
    """Calcula o hash do arquivo sem carregá-lo inteiro em memória."""
    digest = hashlib.sha256()
    with arquivo.open("rb") as entrada:
        for bloco in iter(lambda: entrada.read(1024 * 1024), b""):
            digest.update(bloco)
    return digest.hexdigest()


def criar_cliente_object_storage(
    modo_autenticacao: str = "instance_principal",
    perfil: str = "DEFAULT",
    arquivo_config: str | None = None,
) -> Any:
    """Cria o cliente OCI sem armazenar credenciais no projeto."""
    import oci

    if modo_autenticacao == "instance_principal":
        signer = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
        return oci.object_storage.ObjectStorageClient({}, signer=signer)
    if modo_autenticacao == "config_file":
        if not arquivo_config:
            configuracao = oci.config.from_file(profile_name=perfil)
        else:
            caminho_config = Path(arquivo_config).expanduser()
            parser = ConfigParser()
            if not parser.read(caminho_config, encoding="utf-8"):
                raise FileNotFoundError(
                    f"Arquivo de configuração OCI não encontrado: {caminho_config}."
                )

            if perfil == "DEFAULT":
                configuracao = dict(parser.defaults())
            elif parser.has_section(perfil):
                configuracao = dict(parser.defaults())
                configuracao.update(dict(parser[perfil]))
            else:
                raise ValueError(
                    f"Perfil OCI {perfil!r} não encontrado em {caminho_config}."
                )

            chave_configurada = configuracao.get("key_file", "")
            caminho_chave = Path(chave_configurada).expanduser()
            if chave_configurada and not caminho_chave.is_file():
                chave_montada = caminho_config.parent / caminho_chave.name
                if chave_montada.is_file():
                    configuracao["key_file"] = str(chave_montada)

            oci.config.validate_config(configuracao)
        return oci.object_storage.ObjectStorageClient(configuracao)
    raise ValueError(
        "OCI_AUTH_MODE deve ser 'instance_principal' ou 'config_file'."
    )


def publicar_arquivo(
    arquivo: Path,
    bucket: str,
    nome_objeto: str,
    *,
    modo_autenticacao: str = "instance_principal",
    perfil: str = "DEFAULT",
    namespace: str | None = None,
    arquivo_config: str | None = None,
) -> ResultadoPublicacao:
    """Publica um objeto Bronze sem substituir conteúdo divergente."""
    import oci

    if not arquivo.is_file() or arquivo.stat().st_size == 0:
        raise ValueError(f"Arquivo ausente ou vazio: {arquivo}.")
    if not bucket.strip():
        raise ValueError("O nome do bucket é obrigatório.")

    sha256 = calcular_sha256(arquivo)
    tamanho = arquivo.stat().st_size
    cliente = criar_cliente_object_storage(
        modo_autenticacao,
        perfil,
        arquivo_config,
    )
    namespace_resolvido = namespace or cliente.get_namespace().data

    try:
        existente = cliente.head_object(
            namespace_resolvido,
            bucket,
            nome_objeto,
        )
    except oci.exceptions.ServiceError as erro:
        if erro.status != 404:
            raise
    else:
        hash_existente = existente.headers.get("opc-meta-sha256")
        tamanho_existente = int(existente.headers.get("content-length", -1))
        if hash_existente == sha256 and tamanho_existente == tamanho:
            return ResultadoPublicacao(
                bucket, nome_objeto, sha256, tamanho, criado=False
            )
        raise RuntimeError(
            "Já existe um objeto Bronze diferente no mesmo caminho: "
            f"{nome_objeto}."
        )

    with arquivo.open("rb") as conteudo:
        cliente.put_object(
            namespace_resolvido,
            bucket,
            nome_objeto,
            conteudo,
            content_length=tamanho,
            opc_meta={"sha256": sha256},
            if_none_match="*",
        )

    return ResultadoPublicacao(bucket, nome_objeto, sha256, tamanho, criado=True)
