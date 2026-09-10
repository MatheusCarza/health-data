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
    'Internações da amostra' AS titulo,
    TO_CHAR(total_internacoes, 'FM999G999G990') AS valor,
    'Registros de internação analisados (não pacientes únicos)' AS descricao,
    'fa-database' AS icone
FROM vw_resumo_geral
UNION ALL
SELECT
    2,
    'Municípios de internação',
    TO_CHAR(total_municipios, 'FM999G999G990'),
    'Municípios onde ocorreram internações na amostra',
    'fa-map-marker'
FROM vw_resumo_geral
UNION ALL
SELECT
    3,
    'Estabelecimentos',
    TO_CHAR(total_estabelecimentos, 'FM999G999G990'),
    'Unidades com ao menos uma internação na amostra',
    'fa-hospital-o'
FROM vw_resumo_geral
UNION ALL
SELECT
    4,
    'Valor total',
    'R$ ' || TO_CHAR(
        valor_total,
        'FM999G999G999G990D00',
        'NLS_NUMERIC_CHARACTERS='',.'''
    ),
    'Soma do valor das ' || TO_CHAR(
        total_internacoes,
        'FM999G999G990',
        'NLS_NUMERIC_CHARACTERS='',.'''
    ) || ' internações analisadas',
    'fa-money'
FROM vw_resumo_geral
UNION ALL
SELECT
    5,
    'Permanência média',
    TO_CHAR(
        permanencia_media,
        'FM990D0',
        'NLS_NUMERIC_CHARACTERS='',.'''
    ) || ' dias',
    'Média de dias de permanência por internação',
    'fa-clock-o'
FROM vw_resumo_geral
UNION ALL
SELECT
    6,
    'Internações com óbito',
    TO_CHAR(
        total_obitos,
        'FM999G999G990',
        'NLS_NUMERIC_CHARACTERS='',.'''
    ),
    TO_CHAR(
        taxa_obito_pct,
        'FM990D00',
        'NLS_NUMERIC_CHARACTERS='',.'''
    ) || '% de ' || TO_CHAR(
        total_internacoes,
        'FM999G999G990',
        'NLS_NUMERIC_CHARACTERS='',.'''
    ) || ' internações registraram óbito',
    'fa-heartbeat'
FROM vw_resumo_geral;

CREATE OR REPLACE VIEW vw_escopo_dados AS
SELECT
    f.ano_competencia,
    f.mes_competencia,
    f.ano_competencia * 100 + f.mes_competencia AS competencia,
    m.uf,
    COUNT(*) AS total_registros
FROM admin.fato_internacao f
LEFT JOIN admin.dim_municipio m
    ON m.cod_municipio = f.cod_municipio_internacao
GROUP BY
    f.ano_competencia,
    f.mes_competencia,
    m.uf;

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

CREATE OR REPLACE VIEW vw_mapa_internacoes AS
SELECT
    e.codigo_cnes,
    e.nome_fantasia,
    m.nome_municipio,
    e.latitude,
    e.longitude,
    COUNT(*) AS total_internacoes,
    ROUND(SUM(f.valor_total), 2) AS valor_total,
    SUM(CASE WHEN f.indicador_obito = 1 THEN 1 ELSE 0 END) AS total_obitos,
    e.nome_fantasia || ' — ' ||
        NVL(m.nome_municipio, 'Município não informado') || ': ' ||
        TO_CHAR(
            COUNT(*),
            'FM999G999G990',
            'NLS_NUMERIC_CHARACTERS='',.'''
        ) || ' internações' AS tooltip
FROM admin.fato_internacao f
JOIN admin.dim_estabelecimento e
    ON e.codigo_cnes = f.codigo_cnes
LEFT JOIN admin.dim_municipio m
    ON m.cod_municipio = e.cod_municipio
WHERE e.latitude BETWEEN -90 AND 90
  AND e.longitude BETWEEN -180 AND 180
GROUP BY
    e.codigo_cnes,
    e.nome_fantasia,
    m.nome_municipio,
    e.latitude,
    e.longitude;
