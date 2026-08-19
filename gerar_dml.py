"""Gera o script DML (dados de exemplo) pro schema principal do Health Data.

Estrategia de amostragem: os 15 municipios de maior volume de internacao
(45%+ do dataset), com uma fracao proporcional (0.5%) das internacoes
deles - preserva o sinal real de sazonalidade/tendencia por municipio,
ao contrario de uma amostra aleatoria espalhada por todo o estado (que
ficaria rala demais pra consultas de tendencia fazerem sentido).

So entram no dim_estabelecimento os hospitais que de fato aparecem na
amostra de internacoes (join por CNES) - garante integridade referencial
sem inventar nada.
"""
import json
import pandas as pd

TOP_N_MUNICIPIOS = 15
SAMPLE_FRAC = 0.005
RANDOM_SEED = 42

def esc(v):
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return "NULL"
    return "'" + str(v).replace("'", "''") + "'"

def esc_num(v):
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return "NULL"
    return str(v)

def esc_date(v):
    """Datas do SIH vem como string 'YYYYMMDD' (ex.: DT_INTER, DT_SAIDA)."""
    if v is None or (isinstance(v, float) and pd.isna(v)) or str(v).strip() == "":
        return "NULL"
    return f"TO_DATE('{v}', 'YYYYMMDD')"

def esc_date_iso(v):
    """Datas do CNES vem como string 'YYYY-MM-DD' (ex.: data_atualizacao)."""
    if v is None or (isinstance(v, float) and pd.isna(v)) or str(v).strip() == "":
        return "NULL"
    return f"TO_DATE('{v}', 'YYYY-MM-DD')"

print("Lendo datasets...")
sih = pd.read_parquet(
    "dados/sih_sp_2024_completo.parquet",
    columns=["MUNIC_RES", "MUNIC_MOV", "CNES", "ESPEC", "DT_INTER",
             "DT_SAIDA", "DIAS_PERM", "IDADE", "SEXO", "RACA_COR",
             "DIAG_PRINC", "PROC_REA", "VAL_TOT", "VAL_UTI", "MORTE",
             "ANO_CMPT", "MES_CMPT"],
)
cnes = pd.read_parquet("dados/cnes_sp.parquet")

# CNES do SIH e string sem zero-padding; codigo_cnes do CNES e int64 (perde
# zeros a esquerda). Normaliza os dois pro mesmo formato (string, 7 digitos)
# antes de comparar - sem isso o join da zero por mismatch de tipo/formato.
sih["CNES"] = sih["CNES"].astype(str).str.strip().str.zfill(7)
cnes["codigo_cnes"] = cnes["codigo_cnes"].astype(str).str.strip().str.zfill(7)

top_munic = sih["MUNIC_RES"].value_counts().head(TOP_N_MUNICIPIOS).index.tolist()
print(f"Top {TOP_N_MUNICIPIOS} municipios: {top_munic}")

sih_sub = sih[sih["MUNIC_RES"].isin(top_munic)]
sample = sih_sub.sample(frac=SAMPLE_FRAC, random_state=RANDOM_SEED)
print(f"Amostra bruta: {len(sample)} linhas")

# garante integridade referencial: so mantem internacoes cujo CNES existe no cadastro
sample = sample[sample["CNES"].isin(cnes["codigo_cnes"])]
print(f"Amostra apos garantir FK com CNES: {len(sample)} linhas")

cnes_codes = sample["CNES"].unique().tolist()
cnes_sample = cnes[cnes["codigo_cnes"].isin(cnes_codes)].drop_duplicates(subset="codigo_cnes")
print(f"Estabelecimentos distintos na amostra: {len(cnes_sample)}")

out = []
out.append("-- ============================================================================")
out.append("-- Health Data (Challenge FIAP + Oracle) -- Script DML (dados de exemplo)")
out.append("-- Turma 1TSCPW | Grupo: HealthData")
out.append("-- Integrantes (ordem alfabetica):")
out.append("--   Lucas Leal das Chagas       RM571567")
out.append("--   Matheus Carvalho de Souza   RM568785")
out.append("--   Vinicius de Assis Araujo    RM570900")
out.append("--")
out.append("-- Dados de EXEMPLO (nao representam o dataset completo). A amostra usa os")
out.append("-- top 15 municipios por volume de internacao e uma fracao proporcional de")
out.append("-- 0.5% das internacoes, preservando o escopo academico e a reproducibilidade.")
out.append("-- Esse recorte preserva o sinal real de sazonalidade/tendencia por municipio e mes.")
out.append("--")
out.append(f"-- Gerado por gerar_dml.py em 2026-08-06. Linhas: fato_internacao={len(sample)},")
out.append(f"-- dim_estabelecimento={len(cnes_sample)}, dim_municipio=645 (via external table),")
out.append("-- dim_tipo_atendimento=14 (tabela oficial SIGTAP/SIH, fonte: tabnet.datasus.gov.br/cgi/sih/sxdescr.htm)")
out.append("-- ============================================================================")
out.append("")
out.append("-- Autonomous Database faz DML paralelo por padrao, o que pode causar deadlock")
out.append("-- entre os proprios INSERTs sequenciais deste script (ORA-12860, ja visto na")
out.append("-- pratica com dim_estabelecimento). Desliga pra essa sessao.")
out.append("ALTER SESSION DISABLE PARALLEL DML;")
out.append("")
out.append("-- Reset idempotente: permite rodar o script de novo sem duplicar PK caso uma")
out.append("-- execucao anterior tenha inserido parte dos dados. Ordem respeita as FKs")
out.append("-- (tabela filha antes das tabelas mae).")
out.append("DELETE FROM fato_internacao;")
out.append("DELETE FROM dim_estabelecimento;")
out.append("DELETE FROM dim_tipo_atendimento;")
out.append("DELETE FROM dim_municipio;")
out.append("")
out.append("-- ----------------------------------------------------------------------------")
out.append("-- 1. dim_municipio -- carga a partir da external table (Bronze -> Prata)")
out.append("-- ----------------------------------------------------------------------------")
out.append("INSERT INTO dim_municipio (cod_municipio, uf, populacao_2024)")
out.append("SELECT TRUNC(munic_res_ibge / 10), 'SP', populacao FROM dim_municipio_ext;")
out.append("")
out.append("-- ----------------------------------------------------------------------------")
out.append("-- 2. dim_tipo_atendimento -- tabela oficial de especialidade do leito (SIGTAP/SIH)")
out.append("-- Fonte: http://tabnet.datasus.gov.br/cgi/sih/sxdescr.htm (conferido em 2026-08-06)")
out.append("-- ----------------------------------------------------------------------------")
especialidades = {
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
for cod, desc in especialidades.items():
    out.append(f"INSERT INTO dim_tipo_atendimento (codigo_especialidade, descricao) VALUES ({esc(cod)}, {esc(desc)});")
out.append("")

out.append("-- ----------------------------------------------------------------------------")
out.append(f"-- 3. dim_estabelecimento -- {len(cnes_sample)} hospitais/unidades (amostra real, Fonte 2 CNES)")
out.append("-- ----------------------------------------------------------------------------")
bool_map = {True: "S", False: "N", "SIM": "S", "NAO": "N", 1: "S", 0: "N"}
for _, row in cnes_sample.iterrows():
    def flag(col):
        v = row.get(col)
        if pd.isna(v):
            return "NULL"
        return esc(bool_map.get(v, str(v)[:1].upper()))

    json_payload = {k: (None if pd.isna(v) else (v.item() if hasattr(v, "item") else v)) for k, v in row.items()}
    json_str = json.dumps(json_payload, ensure_ascii=False, default=str)

    cols = ("codigo_cnes, nome_fantasia, razao_social, cnpj, cod_municipio, bairro, "
            "endereco, cep, telefone, email, latitude, longitude, esfera_administrativa, "
            "natureza_juridica, possui_centro_cirurgico, possui_centro_obstetrico, "
            "possui_centro_neonatal, possui_atendimento_hospitalar, "
            "possui_atendimento_ambulatorial, possui_servico_apoio, data_atualizacao, dados_json")
    vals = ", ".join([
        esc(row.get("codigo_cnes")),
        esc(row.get("nome_fantasia")),
        esc(row.get("nome_razao_social")),
        esc(row.get("numero_cnpj")),
        esc_num(row.get("codigo_municipio")),
        esc(row.get("bairro_estabelecimento")),
        esc(row.get("endereco_estabelecimento")),
        esc(row.get("codigo_cep_estabelecimento")),
        esc(row.get("numero_telefone_estabelecimento")),
        esc(row.get("endereco_email_estabelecimento")),
        esc_num(row.get("latitude_estabelecimento_decimo_grau")),
        esc_num(row.get("longitude_estabelecimento_decimo_grau")),
        esc(row.get("descricao_esfera_administrativa")),
        esc(row.get("descricao_natureza_juridica_estabelecimento")),
        flag("estabelecimento_possui_centro_cirurgico"),
        flag("estabelecimento_possui_centro_obstetrico"),
        flag("estabelecimento_possui_centro_neonatal"),
        flag("estabelecimento_possui_atendimento_hospitalar"),
        flag("estabelecimento_possui_atendimento_ambulatorial"),
        flag("estabelecimento_possui_servico_apoio"),
        esc_date_iso(row.get("data_atualizacao")),
        "'" + json_str.replace("'", "''") + "'",
    ])
    out.append(f"INSERT INTO dim_estabelecimento ({cols}) VALUES ({vals});")
out.append("")

out.append("-- ----------------------------------------------------------------------------")
out.append(f"-- 4. fato_internacao -- {len(sample)} internacoes (amostra real, Fonte 1 SIH)")
out.append("-- ----------------------------------------------------------------------------")
cols_fato = ("cod_municipio_residencia, cod_municipio_internacao, codigo_cnes, "
             "codigo_especialidade, dt_internacao, dt_saida, dias_permanencia, idade, sexo, "
             "raca_cor, diag_principal, proc_realizado, valor_total, valor_uti, "
             "indicador_obito, ano_competencia, mes_competencia")
for _, row in sample.iterrows():
    vals = ", ".join([
        esc_num(int(row["MUNIC_RES"])) if pd.notna(row["MUNIC_RES"]) else "NULL",
        esc_num(int(row["MUNIC_MOV"])) if pd.notna(row["MUNIC_MOV"]) else "NULL",
        esc(row["CNES"]),
        esc(row["ESPEC"]),
        esc_date(row["DT_INTER"]),
        esc_date(row["DT_SAIDA"]),
        esc_num(row["DIAS_PERM"]),
        esc_num(row["IDADE"]),
        esc(row["SEXO"]),
        esc(row["RACA_COR"]),
        esc(row["DIAG_PRINC"]),
        esc(row["PROC_REA"]),
        esc_num(row["VAL_TOT"]),
        esc_num(row["VAL_UTI"]),
        esc_num(row["MORTE"]),
        esc_num(row["ANO_CMPT"]),
        esc_num(row["MES_CMPT"]),
    ])
    out.append(f"INSERT INTO fato_internacao ({cols_fato}) VALUES ({vals});")

out.append("")
out.append("COMMIT;")

with open("sql/dml_health_data.sql", "w", encoding="utf-8") as f:
    f.write("\n".join(out))

print(f"Escrito sql/dml_health_data.sql com {len(out)} linhas.")
