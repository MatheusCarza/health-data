-- Health Data - restauracao manual da amostra preservada em 2026-09-10.
-- Usar somente se for necessario desfazer o backfill integral.

DELETE FROM fato_internacao;
DELETE FROM dim_estabelecimento;
DELETE FROM dim_tipo_atendimento;
DELETE FROM dim_municipio;

INSERT INTO dim_municipio
SELECT * FROM bkp_dim_municipio_20260910;

INSERT INTO dim_tipo_atendimento
SELECT * FROM bkp_dim_tipo_atend_20260910;

INSERT INTO dim_estabelecimento
SELECT * FROM bkp_dim_estabelec_20260910;

INSERT INTO fato_internacao (
    cod_municipio_residencia,
    cod_municipio_internacao,
    codigo_cnes,
    codigo_especialidade,
    dt_internacao,
    dt_saida,
    dias_permanencia,
    idade,
    sexo,
    raca_cor,
    diag_principal,
    proc_realizado,
    valor_total,
    valor_uti,
    indicador_obito,
    ano_competencia,
    mes_competencia,
    id_registro_origem
)
SELECT
    cod_municipio_residencia,
    cod_municipio_internacao,
    codigo_cnes,
    codigo_especialidade,
    dt_internacao,
    dt_saida,
    dias_permanencia,
    idade,
    sexo,
    raca_cor,
    diag_principal,
    proc_realizado,
    valor_total,
    valor_uti,
    indicador_obito,
    ano_competencia,
    mes_competencia,
    id_registro_origem
FROM bkp_fato_internacao_20260910;

COMMIT;
