from pathlib import Path

import pandas as pd
import pytest

from health_data_pipeline.quality import (
    validar_arquivo_ibge,
    validar_script_dml,
    validar_script_etl_incremental,
)
from baixar_sih_ftp_completo import caminho_saida, validar_parametros
from baixar_cnes_api import caminho_saida as caminho_saida_cnes, codigo_uf
from baixar_ibge_populacao import (
    caminho_csv,
    localizar_aba_municipios,
    preparar_municipios,
    resolver_url,
)
from health_data_pipeline.object_storage import calcular_sha256, nome_objeto_bronze
from health_data_pipeline.oracle_staging import (
    identificador_origem,
    preparar_staging,
)
from health_data_pipeline.scheduling import (
    competencia_seguinte,
    decompor_competencia,
    numero_competencia,
    proxima_competencia_permitida,
)
from publicar_bronze_ano import localizar_arquivos_sih, montar_plano
from carregar_ano_oracle import token_confirmacao
from migrar_populacao_historica_oracle import (
    extrair_package_body,
    extrair_statements_migracao,
    token_confirmacao as token_confirmacao_populacao,
)


def test_validar_arquivo_ibge_aceita_dataset_valido(tmp_path: Path) -> None:
    arquivo = tmp_path / "ibge.csv"
    pd.DataFrame(
        {
            "MUNIC_RES_IBGE": ["3500105", "3500204"],
            "NOME_MUNICIPIO": ["Adamantina", "Adolfo"],
            "POPULACAO": [35000, 4000],
        }
    ).to_csv(arquivo, index=False)

    validar_arquivo_ibge(arquivo, total_esperado=2)


def test_validar_arquivo_ibge_rejeita_codigo_duplicado(tmp_path: Path) -> None:
    arquivo = tmp_path / "ibge.csv"
    pd.DataFrame(
        {
            "MUNIC_RES_IBGE": ["3500105", "3500105"],
            "NOME_MUNICIPIO": ["Adamantina", "Adamantina"],
            "POPULACAO": [35000, 35000],
        }
    ).to_csv(arquivo, index=False)

    with pytest.raises(ValueError, match="duplicados"):
        validar_arquivo_ibge(arquivo, total_esperado=2)


def test_validar_script_dml_rejeita_carga_incompleta(tmp_path: Path) -> None:
    arquivo = tmp_path / "carga.sql"
    arquivo.write_text("COMMIT;", encoding="utf-8")

    with pytest.raises(ValueError, match="marcadores obrigatórios ausentes"):
        validar_script_dml(arquivo)


def test_caminho_saida_sih_preserva_nome_do_ano_completo() -> None:
    assert str(caminho_saida("SP", 2024, 1, 12)) == (
        "dados/sih_sp_2024_completo.parquet"
    )


def test_caminho_saida_sih_identifica_intervalo_mensal() -> None:
    assert str(caminho_saida("SP", 2024, 10, 12)) == (
        "dados/sih_sp_2024_10_12.parquet"
    )


def test_validar_parametros_sih_rejeita_intervalo_invertido() -> None:
    with pytest.raises(ValueError, match="inicial"):
        validar_parametros("SP", 2024, 12, 10)


def test_codigo_uf_cnes_converte_sigla_sem_diferenciar_caixa() -> None:
    assert codigo_uf("sp") == 35
    assert codigo_uf("AM") == 13


def test_codigo_uf_cnes_rejeita_sigla_invalida() -> None:
    with pytest.raises(ValueError, match="UF inválida"):
        codigo_uf("XX")


def test_caminho_saida_cnes_identifica_uf() -> None:
    assert str(caminho_saida_cnes("MG")) == "dados/cnes_mg.parquet"


def test_caminho_csv_ibge_identifica_uf_e_ano() -> None:
    assert str(caminho_csv("MG", 2025)) == "dados/ibge_populacao_mg_2025.csv"


def test_preparar_municipios_aceita_brasil(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    arquivo = tmp_path / "ibge.xls"
    bruto = pd.DataFrame(
        {
            "UF": ["SP", "RJ"],
            "COD. UF": ["35", "33"],
            "COD. MUNIC": ["50308", "04557"],
            "NOME DO MUNICÍPIO": ["São Paulo", "Rio de Janeiro"],
            "POPULAÇÃO ESTIMADA": [11_000_000, 6_000_000],
        }
    )
    class PlanilhaTeste:
        sheet_names = ["Municípios"]

    monkeypatch.setattr(pd, "ExcelFile", lambda *args, **kwargs: PlanilhaTeste())
    monkeypatch.setattr(pd, "read_excel", lambda *args, **kwargs: bruto.copy())

    resultado = preparar_municipios(arquivo, "BR")

    assert len(resultado) == 2
    assert set(resultado["UF"]) == {"SP", "RJ"}


def test_localizar_aba_municipios_ignora_caixa_e_acentuacao() -> None:
    assert localizar_aba_municipios(["BRASIL E UFs", "Municípios"]) == (
        "Municípios"
    )


def test_resolver_url_ibge_exige_fonte_para_edicao_desconhecida() -> None:
    with pytest.raises(ValueError, match="--url"):
        resolver_url(2026)


def test_resolver_url_ibge_reconhece_edicao_2025() -> None:
    assert resolver_url(2025).endswith("/POP2025_20260828.xls")


def test_resolver_url_ibge_aceita_fonte_explicita() -> None:
    assert resolver_url(2025, "https://example.test/ibge.xls") == (
        "https://example.test/ibge.xls"
    )


def test_nome_objeto_bronze_sih_particiona_competencia() -> None:
    assert nome_objeto_bronze(
        "sih",
        Path("sih_sp_2024_10.parquet"),
        "sp",
        ano=2024,
        mes=10,
    ) == "bronze/sih/uf=SP/ano=2024/mes=10/sih_sp_2024_10.parquet"


def test_nome_objeto_bronze_cnes_registra_data_extracao() -> None:
    from datetime import date

    assert nome_objeto_bronze(
        "cnes",
        Path("cnes_sp.parquet"),
        "SP",
        data_extracao=date(2026, 9, 10),
    ) == "bronze/cnes/uf=SP/data_extracao=2026-09-10/cnes_sp.parquet"


def test_nome_objeto_bronze_ibge_particiona_ano() -> None:
    assert nome_objeto_bronze(
        "ibge",
        Path("ibge_populacao_sp_2024.csv"),
        "SP",
        ano=2024,
    ) == "bronze/ibge/uf=SP/ano=2024/ibge_populacao_sp_2024.csv"


def test_calcular_sha256_le_arquivo_em_blocos(tmp_path: Path) -> None:
    arquivo = tmp_path / "fonte.csv"
    arquivo.write_bytes(b"health-data\n")

    assert calcular_sha256(arquivo) == (
        "faa01665b7e44c7f9c6734f89ea297796c0ce82d0efd2032c7e784d0aea0492f"
    )


def test_montar_plano_bronze_anual_inclui_14_objetos(tmp_path: Path) -> None:
    from datetime import date

    for mes in range(1, 13):
        (tmp_path / f"sih_sp_2024_{mes:02d}_{mes:02d}.parquet").write_bytes(b"sih")
    cnes = tmp_path / "cnes_sp.parquet"
    ibge = tmp_path / "ibge_populacao_br_2024.csv"
    cnes.write_bytes(b"cnes")
    ibge.write_bytes(b"ibge")

    plano = montar_plano(
        tmp_path,
        cnes,
        ibge,
        uf="SP",
        ano=2024,
        data_extracao_cnes=date(2026, 9, 10),
    )

    assert len(plano) == 14
    assert plano[0].nome_objeto.startswith("bronze/sih/uf=SP/ano=2024/mes=01/")
    assert plano[-1].nome_objeto.startswith("bronze/ibge/uf=BR/ano=2024/")


def test_localizar_arquivos_sih_rejeita_mes_duplicado(tmp_path: Path) -> None:
    for mes in range(1, 13):
        (tmp_path / f"sih_sp_2024_{mes:02d}_{mes:02d}.parquet").write_bytes(b"sih")
    (tmp_path / "sih_sp_2024_01_12.parquet").write_bytes(b"duplicado")

    with pytest.raises(ValueError, match="01/2024"):
        localizar_arquivos_sih(tmp_path, "SP", 2024)


def test_token_confirmacao_backfill_explicita_escopo_e_volume() -> None:
    assert token_confirmacao("sp", 2024, 2_855_539) == "SP-2024-2855539"


def test_validar_script_etl_incremental_aceita_script_versionado() -> None:
    validar_script_etl_incremental(Path("sql/etl_incremental.sql"))


def test_validar_script_etl_incremental_rejeita_delete_total(tmp_path: Path) -> None:
    original = Path("sql/etl_incremental.sql").read_text(encoding="utf-8")
    arquivo = tmp_path / "etl_inseguro.sql"
    arquivo.write_text(original + "\nDELETE FROM fato_internacao;\n", encoding="utf-8")

    with pytest.raises(ValueError, match="apagar toda"):
        validar_script_etl_incremental(arquivo)


def test_identificador_origem_e_estavel_sem_expor_aih() -> None:
    primeiro = identificador_origem("1234567890123", 1)

    assert primeiro == identificador_origem("1234567890123", 1)
    assert primeiro != identificador_origem("1234567890123", 2)
    assert len(primeiro) == 20
    assert "1234567890123" not in primeiro


def test_preparar_staging_filtra_uma_competencia(tmp_path: Path) -> None:
    sih_path = tmp_path / "sih.parquet"
    cnes_path = tmp_path / "cnes.parquet"
    ibge_path = tmp_path / "ibge.csv"
    pd.DataFrame(
        {
            "N_AIH": ["A1", "A2"],
            "SEQUENCIA": [1, 2],
            "MUNIC_RES": [355030, 355030],
            "MUNIC_MOV": [355030, 355030],
            "CNES": [123, 123],
            "ESPEC": [3, 3],
            "MORTE": [0, 1],
            "ANO_CMPT": [2024, 2024],
            "MES_CMPT": [10, 11],
            "DT_INTER": ["20241001", "20241101"],
            "DT_SAIDA": ["20241003", "20241103"],
            "DIAS_PERM": [2, 2],
            "IDADE": [40, 50],
            "SEXO": ["1", "2"],
            "RACA_COR": ["01", "02"],
            "DIAG_PRINC": ["A000", "B000"],
            "PROC_REA": ["1234567890", "1234567890"],
            "VAL_TOT": [100.5, 200.5],
            "VAL_UTI": [0, 10],
        }
    ).to_parquet(sih_path, index=False)
    pd.DataFrame(
        {
            "codigo_cnes": [123],
            "codigo_municipio": [355030],
            "nome_fantasia": ["Hospital Teste"],
        }
    ).to_parquet(cnes_path, index=False)
    pd.DataFrame(
        {
            "MUNIC_RES_IBGE": ["3550308"],
            "NOME_MUNICIPIO": ["São Paulo"],
            "POPULACAO": [11_000_000],
        }
    ).to_csv(ibge_path, index=False)

    frames = preparar_staging(
        sih_path,
        cnes_path,
        ibge_path,
        execucao_id="00000000-0000-4000-8000-000000000001",
        uf="sp",
        ano=2024,
        mes=10,
    )

    assert len(frames.internacoes) == 1
    assert frames.internacoes.loc[0, "codigo_cnes"] == "0000123"
    assert frames.internacoes.loc[0, "codigo_especialidade"] == "03"
    assert frames.municipios.loc[0, "cod_municipio"] == 355030
    assert frames.estabelecimentos.loc[0, "nome_fantasia"] == "Hospital Teste"
    assert len(frames.tipos_atendimento) == 14


def test_competencia_seguinte_avanca_mes() -> None:
    assert competencia_seguinte(202410) == (2024, 11)


def test_competencia_seguinte_avanca_ano() -> None:
    assert competencia_seguinte("202412") == (2025, 1)


def test_competencia_rejeita_mes_invalido() -> None:
    with pytest.raises(ValueError, match="intervalo"):
        decompor_competencia(202413)


def test_numero_competencia_formata_ano_e_mes() -> None:
    assert numero_competencia(2024, 9) == 202409


def test_agenda_para_no_limite_temporal() -> None:
    assert proxima_competencia_permitida(202412, 202412) is None


def test_agenda_avanca_sem_pular_mes_dentro_do_limite() -> None:
    assert proxima_competencia_permitida(202411, 202412) == (2024, 12)


def test_token_confirmacao_populacao_explicita_ano_e_volume() -> None:
    assert token_confirmacao_populacao(5_570) == "POP-HIST-2024-5570"


def test_migracao_populacao_possui_statements_executaveis() -> None:
    texto = Path("sql/populacao_municipio_historica_20260911.sql").read_text(
        encoding="utf-8"
    )
    statements = extrair_statements_migracao(texto)

    assert len(statements) == 5
    assert statements[0].startswith("DECLARE")
    assert statements[-1] == "COMMIT"


def test_package_body_incremental_e_extraivel() -> None:
    texto = Path("sql/etl_incremental.sql").read_text(encoding="utf-8")
    corpo = extrair_package_body(texto)

    assert corpo.startswith("CREATE OR REPLACE PACKAGE BODY")
    assert "MERGE INTO dim_municipio_populacao" in corpo


def test_preparar_staging_rejeita_municipio_sem_cadastro_ibge(
    tmp_path: Path,
) -> None:
    sih_path = tmp_path / "sih.parquet"
    cnes_path = tmp_path / "cnes.parquet"
    ibge_path = tmp_path / "ibge.csv"
    pd.DataFrame(
        {
            "N_AIH": ["A1"],
            "SEQUENCIA": [1],
            "MUNIC_RES": [330455],
            "MUNIC_MOV": [355030],
            "CNES": [123],
            "ESPEC": [3],
            "MORTE": [0],
            "ANO_CMPT": [2024],
            "MES_CMPT": [10],
        }
    ).to_parquet(sih_path, index=False)
    pd.DataFrame(
        {
            "codigo_cnes": [123],
            "codigo_municipio": [355030],
            "nome_fantasia": ["Hospital Teste"],
        }
    ).to_parquet(cnes_path, index=False)
    pd.DataFrame(
        {
            "MUNIC_RES_IBGE": ["3550308"],
            "NOME_MUNICIPIO": ["São Paulo"],
            "POPULACAO": [11_000_000],
        }
    ).to_csv(ibge_path, index=False)

    with pytest.raises(ValueError, match="municípios da competência"):
        preparar_staging(
            sih_path,
            cnes_path,
            ibge_path,
            execucao_id="00000000-0000-4000-8000-000000000001",
            uf="SP",
            ano=2024,
            mes=10,
        )
