-- Health Data - Visões analíticas do MVP Oracle APEX
-- Executar no schema WKSP_HEALTHDATA após as permissões concedidas por ADMIN.

CREATE OR REPLACE VIEW vw_resumo_geral AS
SELECT
    COUNT(*) AS total_internacoes,
    COUNT(DISTINCT cod_municipio_internacao) AS total_municipios,
    COUNT(DISTINCT codigo_cnes) AS total_estabelecimentos,
    ROUND(SUM(valor_total), 2) AS valor_total,
    ROUND(AVG(dias_permanencia), 1) AS permanencia_media,
    SUM(CASE WHEN indicador_obito = 1 THEN 1 ELSE 0 END) AS total_obitos,
    ROUND(
        100 * AVG(CASE WHEN indicador_obito = 1 THEN 1 ELSE 0 END),
        2
    ) AS taxa_obito_pct
FROM admin.fato_internacao;

CREATE OR REPLACE VIEW vw_kpi_cards AS
SELECT
    1 AS ordem,
    'Internações' AS titulo,
    TO_CHAR(total_internacoes, 'FM999G999G990') AS valor,
    'Registros da amostra SIH/SUS' AS descricao,
    'fa-database' AS icone
FROM vw_resumo_geral
UNION ALL
SELECT
    2,
    'Municípios',
    TO_CHAR(total_municipios, 'FM999G999G990'),
    'Municípios com internações na amostra',
    'fa-map-marker'
FROM vw_resumo_geral
UNION ALL
SELECT
    3,
    'Estabelecimentos',
    TO_CHAR(total_estabelecimentos, 'FM999G999G990'),
    'Unidades de saúde analisadas',
    'fa-hospital-o'
FROM vw_resumo_geral
UNION ALL
SELECT
    4,
    'Valor das internações',
    'R$ ' || TO_CHAR(
        valor_total,
        'FM999G999G999G990D00',
        'NLS_NUMERIC_CHARACTERS='',.'''
    ),
    'Valor total da amostra de 2024',
    'fa-money'
FROM vw_resumo_geral;

CREATE OR REPLACE VIEW vw_municipio_indicadores AS
SELECT
    m.cod_municipio,
    m.nome_municipio,
    m.populacao_2024,
    COUNT(*) AS total_internacoes,
    ROUND(SUM(f.valor_total), 2) AS valor_total,
    ROUND(AVG(f.dias_permanencia), 1) AS permanencia_media,
    SUM(CASE WHEN f.indicador_obito = 1 THEN 1 ELSE 0 END) AS total_obitos,
    ROUND(100000 * COUNT(*) / NULLIF(m.populacao_2024, 0), 2) AS internacoes_100_mil
FROM admin.fato_internacao f
JOIN admin.dim_municipio m
    ON m.cod_municipio = f.cod_municipio_internacao
GROUP BY
    m.cod_municipio,
    m.nome_municipio,
    m.populacao_2024;

CREATE OR REPLACE VIEW vw_tipo_atendimento_indicadores AS
SELECT
    t.codigo_especialidade,
    t.descricao,
    COUNT(*) AS total_internacoes,
    ROUND(SUM(f.valor_total), 2) AS valor_total,
    ROUND(AVG(f.dias_permanencia), 1) AS permanencia_media,
    SUM(CASE WHEN f.indicador_obito = 1 THEN 1 ELSE 0 END) AS total_obitos
FROM admin.fato_internacao f
JOIN admin.dim_tipo_atendimento t
    ON t.codigo_especialidade = f.codigo_especialidade
GROUP BY
    t.codigo_especialidade,
    t.descricao;

CREATE OR REPLACE VIEW vw_estabelecimento_indicadores AS
SELECT
    e.codigo_cnes,
    e.nome_fantasia,
    m.nome_municipio,
    e.esfera_administrativa,
    COUNT(*) AS total_internacoes,
    ROUND(SUM(f.valor_total), 2) AS valor_total,
    ROUND(AVG(f.dias_permanencia), 1) AS permanencia_media,
    SUM(CASE WHEN f.indicador_obito = 1 THEN 1 ELSE 0 END) AS total_obitos
FROM admin.fato_internacao f
JOIN admin.dim_estabelecimento e
    ON e.codigo_cnes = f.codigo_cnes
LEFT JOIN admin.dim_municipio m
    ON m.cod_municipio = e.cod_municipio
GROUP BY
    e.codigo_cnes,
    e.nome_fantasia,
    m.nome_municipio,
    e.esfera_administrativa;
