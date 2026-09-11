"""Prepara e carrega uma competência nas tabelas de staging do Oracle.

O módulo não abre conexão nem lê segredos. O chamador fornece uma conexão
``python-oracledb`` já autenticada. A ativação na DAG será feita somente após
um teste controlado de uma competência no Autonomous Database.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pandas as pd


ESPECIALIDADES = {
    "01": "Clinica cirurgica",
    "02": "Obstetricia",
    "03": "Clinica medica",
    "04": "Cuidados prolongados (cronicos)",
    "05": "Psiquiatria",
    "06": "Pneumologia sanitaria (tisiologia)",
    "07": "Pediatria",
    "08": "Reabilitacao",
    "09": "Clinica cirurgica - hospital-dia",
    "10": "Aids - hospital-dia",
    "12": "Fibrose cistica - hospital-dia",
    "13": "Intercorrencia pos-transplante - hospital-dia",
    "14": "Geriatria - hospital-dia",
    "87": "Saude mental",
}


@dataclass(frozen=True)
class StagingFrames:
    """DataFrames prontos para as quatro tabelas de staging."""

    municipios: pd.DataFrame
    tipos_atendimento: pd.DataFrame
    estabelecimentos: pd.DataFrame
    internacoes: pd.DataFrame
    codigos_cnes_sem_cadastro_atual: tuple[str, ...]


@dataclass(frozen=True)
class ResultadoCarga:
    """Resumo auditável devolvido pela tabela ``etl_execucao``."""

    execucao_id: str
    status: str
    linhas_staging: int
    linhas_substituidas: int


def _texto(valor: Any, largura: int | None = None) -> str | None:
    if pd.isna(valor):
        return None
    resultado = str(valor).strip()
    if not resultado:
        return None
    return resultado[:largura] if largura else resultado


def _numero(valor: Any, inteiro: bool = False) -> int | float | None:
    if pd.isna(valor) or str(valor).strip() == "":
        return None
    numero = pd.to_numeric(valor, errors="raise")
    return int(numero) if inteiro else float(numero)


def _data(valor: Any) -> Any:
    if pd.isna(valor) or str(valor).strip() == "":
        return None
    convertido = pd.to_datetime(str(valor), errors="raise")
    return convertido.to_pydatetime()


def _coluna_data(dados: pd.DataFrame, coluna: str) -> pd.Series:
    """Converte uma coluna inteira do formato SIH YYYYMMDD."""
    if coluna not in dados.columns:
        return pd.Series(None, index=dados.index, dtype="object")
    textos = dados[coluna].astype("string").str.strip().replace("", pd.NA)
    return pd.to_datetime(textos, format="%Y%m%d", errors="raise")


def _flag(valor: Any) -> str | None:
    if pd.isna(valor):
        return None
    normalizado = str(valor).strip().upper()
    if normalizado in {"TRUE", "SIM", "S", "1"}:
        return "S"
    if normalizado in {"FALSE", "NAO", "NÃO", "N", "0"}:
        return "N"
    return normalizado[:1] or None


def _codigo(valor: Any, largura: int) -> str:
    texto = _texto(valor)
    if texto is None:
        raise ValueError("Código obrigatório ausente.")
    if texto.endswith(".0"):
        texto = texto[:-2]
    return texto.zfill(largura)


def identificador_origem(n_aih: Any, sequencia: Any) -> str:
    """Cria impressão de 80 bits sem persistir a chave bruta do SIH."""
    aih = _texto(n_aih)
    ordem = _texto(sequencia)
    if aih is None or ordem is None:
        raise ValueError("SIH: N_AIH e SEQUENCIA são obrigatórios.")
    return hashlib.sha256(f"SIH:{aih}:{ordem}".encode("utf-8")).hexdigest()[:20]


def _registro_json(linha: pd.Series) -> str:
    valores: dict[str, Any] = {}
    for chave, valor in linha.items():
        if pd.isna(valor):
            valores[str(chave)] = None
        elif hasattr(valor, "item"):
            valores[str(chave)] = valor.item()
        else:
            valores[str(chave)] = valor
    return json.dumps(valores, ensure_ascii=False, default=str)


def preparar_staging(
    sih_path: Path,
    cnes_path: Path,
    ibge_path: Path,
    *,
    execucao_id: str,
    uf: str,
    ano: int,
    mes: int,
) -> StagingFrames:
    """Transforma as três fontes em lotes de uma única competência."""
    if not 1 <= mes <= 12:
        raise ValueError("Mês deve estar entre 1 e 12.")

    sih = pd.read_parquet(sih_path)
    obrigatorias = {
        "N_AIH", "SEQUENCIA", "MUNIC_RES", "MUNIC_MOV", "CNES", "ESPEC", "MORTE",
        "ANO_CMPT", "MES_CMPT",
    }
    ausentes = obrigatorias - set(sih.columns)
    if ausentes:
        raise ValueError("SIH: colunas ausentes: " + ", ".join(sorted(ausentes)))

    anos = pd.to_numeric(sih["ANO_CMPT"], errors="raise").astype(int)
    meses = pd.to_numeric(sih["MES_CMPT"], errors="raise").astype(int)
    fato = sih[(anos == ano) & (meses == mes)].copy()
    if fato.empty:
        raise ValueError(f"SIH: nenhuma internação em {mes:02d}/{ano}.")

    fato["codigo_cnes"] = fato["CNES"].map(lambda valor: _codigo(valor, 7))
    fato["codigo_especialidade"] = fato["ESPEC"].map(
        lambda valor: _codigo(valor, 2)
    )
    fato["id_registro_origem"] = [
        identificador_origem(n_aih, sequencia)
        for n_aih, sequencia in zip(fato["N_AIH"], fato["SEQUENCIA"], strict=True)
    ]
    if fato["id_registro_origem"].duplicated().any():
        raise ValueError("SIH: existem chaves N_AIH + SEQUENCIA duplicadas.")

    ibge = pd.read_csv(ibge_path, dtype={"MUNIC_RES_IBGE": "string"})
    ufs_municipios = (
        ibge["UF"].astype("string").str.strip().str.upper()
        if "UF" in ibge.columns
        else pd.Series(uf.upper(), index=ibge.index, dtype="string")
    )
    municipios = pd.DataFrame(
        {
            "execucao_id": execucao_id,
            "cod_municipio": ibge["MUNIC_RES_IBGE"].map(
                lambda valor: int(_codigo(valor, 7)) // 10
            ),
            "nome_municipio": ibge["NOME_MUNICIPIO"].map(
                lambda valor: _texto(valor, 100)
            ),
            "uf": ufs_municipios,
            "populacao": ibge["POPULACAO"].map(lambda valor: _numero(valor, True)),
            "ano_referencia": ano,
        }
    ).drop_duplicates(subset="cod_municipio")

    tipos = pd.DataFrame(
        [
            {
                "execucao_id": execucao_id,
                "codigo_especialidade": codigo,
                "descricao": descricao,
            }
            for codigo, descricao in ESPECIALIDADES.items()
        ]
    )

    cnes = pd.read_parquet(cnes_path).copy()
    cnes["codigo_cnes_normalizado"] = cnes["codigo_cnes"].map(
        lambda valor: _codigo(valor, 7)
    )
    cnes = cnes[
        cnes["codigo_cnes_normalizado"].isin(set(fato["codigo_cnes"]))
    ].drop_duplicates(subset="codigo_cnes_normalizado")

    campos_cnes = {
        "nome_fantasia": ("nome_fantasia", lambda v: _texto(v, 200)),
        "razao_social": ("nome_razao_social", lambda v: _texto(v, 200)),
        "cnpj": ("numero_cnpj", lambda v: _texto(v, 14)),
        "cod_municipio": ("codigo_municipio", lambda v: _numero(v, True)),
        "bairro": ("bairro_estabelecimento", lambda v: _texto(v, 100)),
        "endereco": ("endereco_estabelecimento", lambda v: _texto(v, 200)),
        "cep": ("codigo_cep_estabelecimento", lambda v: _texto(v, 8)),
        "telefone": ("numero_telefone_estabelecimento", lambda v: _texto(v, 20)),
        "email": ("endereco_email_estabelecimento", lambda v: _texto(v, 100)),
        "latitude": ("latitude_estabelecimento_decimo_grau", _numero),
        "longitude": ("longitude_estabelecimento_decimo_grau", _numero),
        "esfera_administrativa": (
            "descricao_esfera_administrativa", lambda v: _texto(v, 50)
        ),
        "natureza_juridica": (
            "descricao_natureza_juridica_estabelecimento", lambda v: _texto(v, 100)
        ),
        "possui_centro_cirurgico": ("estabelecimento_possui_centro_cirurgico", _flag),
        "possui_centro_obstetrico": ("estabelecimento_possui_centro_obstetrico", _flag),
        "possui_centro_neonatal": ("estabelecimento_possui_centro_neonatal", _flag),
        "possui_atendimento_hospitalar": (
            "estabelecimento_possui_atendimento_hospitalar", _flag
        ),
        "possui_atendimento_ambulatorial": (
            "estabelecimento_possui_atendimento_ambulatorial", _flag
        ),
        "possui_servico_apoio": ("estabelecimento_possui_servico_apoio", _flag),
        "data_atualizacao": ("data_atualizacao", _data),
    }
    estabelecimentos = []
    for _, linha in cnes.iterrows():
        registro = {
            "execucao_id": execucao_id,
            "codigo_cnes": linha["codigo_cnes_normalizado"],
        }
        for destino, (origem, conversor) in campos_cnes.items():
            registro[destino] = conversor(linha.get(origem))
        registro["dados_json"] = _registro_json(linha.drop("codigo_cnes_normalizado"))
        estabelecimentos.append(registro)

    fato_destino = pd.DataFrame(
        {
            "execucao_id": execucao_id,
            "id_registro_origem": fato["id_registro_origem"],
            "cod_municipio_residencia": fato["MUNIC_RES"].map(
                lambda valor: _numero(valor, True)
            ),
            "cod_municipio_internacao": fato["MUNIC_MOV"].map(
                lambda valor: _numero(valor, True)
            ),
            "codigo_cnes": fato["codigo_cnes"],
            "codigo_especialidade": fato["codigo_especialidade"],
            "dt_internacao": _coluna_data(fato, "DT_INTER"),
            "dt_saida": _coluna_data(fato, "DT_SAIDA"),
            "dias_permanencia": fato.get("DIAS_PERM", pd.Series(None, index=fato.index)).map(
                lambda valor: _numero(valor, True)
            ),
            "idade": fato.get("IDADE", pd.Series(None, index=fato.index)).map(
                lambda valor: _numero(valor, True)
            ),
            "sexo": fato.get("SEXO", pd.Series(None, index=fato.index)).map(
                lambda valor: _texto(valor, 1)
            ),
            "raca_cor": fato.get("RACA_COR", pd.Series(None, index=fato.index)).map(
                lambda valor: _texto(valor, 2)
            ),
            "diag_principal": fato.get("DIAG_PRINC", pd.Series(None, index=fato.index)).map(
                lambda valor: _texto(valor, 4)
            ),
            "proc_realizado": fato.get("PROC_REA", pd.Series(None, index=fato.index)).map(
                lambda valor: _texto(valor, 10)
            ),
            "valor_total": fato.get("VAL_TOT", pd.Series(None, index=fato.index)).map(_numero),
            "valor_uti": fato.get("VAL_UTI", pd.Series(None, index=fato.index)).map(_numero),
            "indicador_obito": fato["MORTE"].map(lambda valor: _numero(valor, True)),
            "ano_competencia": ano,
            "mes_competencia": mes,
        }
    )

    campos_obrigatorios = [
        "id_registro_origem",
        "cod_municipio_residencia",
        "cod_municipio_internacao",
        "codigo_cnes",
        "codigo_especialidade",
        "indicador_obito",
    ]
    if fato_destino[campos_obrigatorios].isna().any().any():
        raise ValueError("SIH: existem chaves ou indicador de óbito sem valor.")
    obitos_invalidos = set(fato_destino["indicador_obito"]) - {0, 1}
    if obitos_invalidos:
        raise ValueError("SIH: indicador de óbito deve ser 0 ou 1.")

    especialidades_ausentes = set(fato_destino["codigo_especialidade"]) - set(
        ESPECIALIDADES
    )
    if especialidades_ausentes:
        raise ValueError(
            "SIH: especialidades sem descrição: "
            + ", ".join(sorted(especialidades_ausentes))
        )

    municipios_disponiveis = set(municipios["cod_municipio"])
    municipios_necessarios = set(fato_destino["cod_municipio_residencia"]) | set(
        fato_destino["cod_municipio_internacao"]
    )
    municipios_ausentes = municipios_necessarios - municipios_disponiveis
    if municipios_ausentes:
        raise ValueError(
            f"IBGE: {len(municipios_ausentes)} municípios da competência não encontrados."
        )

    cnes_ausentes = set(fato_destino["codigo_cnes"]) - {
        item["codigo_cnes"] for item in estabelecimentos
    }

    return StagingFrames(
        municipios=municipios.reset_index(drop=True),
        tipos_atendimento=tipos,
        estabelecimentos=pd.DataFrame(estabelecimentos),
        internacoes=fato_destino.reset_index(drop=True),
        codigos_cnes_sem_cadastro_atual=tuple(sorted(cnes_ausentes)),
    )


def _inserir_dataframe(
    cursor: Any,
    tabela: str,
    dados: pd.DataFrame,
    *,
    tamanho_lote: int = 5_000,
) -> None:
    if dados.empty:
        return
    if tamanho_lote <= 0:
        raise ValueError("O tamanho do lote deve ser positivo.")
    colunas = list(dados.columns)
    binds = ", ".join(f":{indice}" for indice in range(1, len(colunas) + 1))
    sql = f"INSERT INTO {tabela} ({', '.join(colunas)}) VALUES ({binds})"
    for inicio in range(0, len(dados), tamanho_lote):
        lote = dados.iloc[inicio : inicio + tamanho_lote]
        linhas = [tuple(linha) for linha in lote.itertuples(index=False, name=None)]
        cursor.executemany(sql, linhas, batcherrors=False)


def carregar_staging(conexao: Any, frames: StagingFrames) -> None:
    """Insere os quatro lotes; o chamador controla commit e rollback."""
    with conexao.cursor() as cursor:
        _inserir_dataframe(cursor, "stg_dim_municipio", frames.municipios)
        _inserir_dataframe(cursor, "stg_dim_tipo_atendimento", frames.tipos_atendimento)
        _inserir_dataframe(cursor, "stg_dim_estabelecimento", frames.estabelecimentos)
        _inserir_dataframe(cursor, "stg_fato_internacao", frames.internacoes)


def executar_carga_incremental(
    conexao: Any,
    frames: StagingFrames,
    *,
    execucao_id: str,
    uf: str,
    ano: int,
    mes: int,
    objeto_sih: str,
    sha256_sih: str,
) -> ResultadoCarga:
    """Registra, alimenta e publica uma competência pelo pacote Oracle."""
    # O Autonomous Database pode habilitar Parallel DML para a sessão. O pacote
    # modifica dimensões e fato na mesma transação, fluxo que exige DML serial
    # para não gerar ORA-12839 após o primeiro MERGE.
    with conexao.cursor() as cursor:
        cursor.execute("ALTER SESSION DISABLE PARALLEL DML")

    if frames.codigos_cnes_sem_cadastro_atual:
        with conexao.cursor() as cursor:
            faltantes = []
            for codigo in frames.codigos_cnes_sem_cadastro_atual:
                cursor.execute(
                    """
                    SELECT COUNT(*)
                    FROM dim_estabelecimento
                    WHERE codigo_cnes = :codigo
                    """,
                    codigo=codigo,
                )
                if cursor.fetchone()[0] == 0:
                    faltantes.append(codigo)
        if faltantes:
            raise ValueError(
                "CNES: estabelecimentos ausentes no cadastro atual e no Oracle: "
                + ", ".join(faltantes)
            )

    registrada = False
    pacote_assumiu_falha = False
    try:
        with conexao.cursor() as cursor:
            cursor.execute(
                """
                BEGIN
                    pkg_health_data_etl.iniciar_execucao(
                        :execucao_id, :uf, :ano, :mes, :objeto_sih, :sha256_sih
                    );
                END;
                """,
                execucao_id=execucao_id,
                uf=uf,
                ano=ano,
                mes=mes,
                objeto_sih=objeto_sih,
                sha256_sih=sha256_sih,
            )
        registrada = True

        carregar_staging(conexao, frames)
        conexao.commit()

        with conexao.cursor() as cursor:
            cursor.execute(
                "BEGIN pkg_health_data_etl.marcar_validada(:execucao_id); END;",
                execucao_id=execucao_id,
            )
            pacote_assumiu_falha = True
            cursor.execute(
                "BEGIN pkg_health_data_etl.carregar_competencia(:execucao_id); END;",
                execucao_id=execucao_id,
            )
            cursor.execute(
                """
                SELECT status, linhas_staging, linhas_substituidas
                FROM etl_execucao
                WHERE execucao_id = :execucao_id
                """,
                execucao_id=execucao_id,
            )
            linha = cursor.fetchone()
    except Exception as erro:
        conexao.rollback()
        if registrada and not pacote_assumiu_falha:
            try:
                with conexao.cursor() as cursor:
                    cursor.execute(
                        """
                        BEGIN
                            pkg_health_data_etl.registrar_falha(
                                :execucao_id, :mensagem
                            );
                        END;
                        """,
                        execucao_id=execucao_id,
                        mensagem=str(erro)[:4000],
                    )
            except Exception:
                pass
        raise

    if linha is None:
        raise RuntimeError("Oracle não retornou a auditoria da execução.")
    resultado = ResultadoCarga(
        execucao_id=execucao_id,
        status=str(linha[0]),
        linhas_staging=int(linha[1]),
        linhas_substituidas=int(linha[2]),
    )
    if resultado.status != "SUCESSO":
        raise RuntimeError(f"Carga terminou com status {resultado.status}.")
    return resultado
