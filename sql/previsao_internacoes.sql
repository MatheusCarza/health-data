-- Health Data - Projecao estatistica explicavel de internacoes
-- Executar no schema WKSP_HEALTHDATA depois de sql/apex_mvp_views.sql.
--
-- O metodo e uma media movel ponderada de tres competencias:
--   50% da competencia mais recente
--   30% da competencia imediatamente anterior
--   20% da terceira competencia
--
-- A faixa apresentada nao e um intervalo de confianca estatistico. Ela usa o
-- erro absoluto medio observado no backtest mensal do proprio metodo.

CREATE OR REPLACE VIEW vw_internacoes_mensais AS
WITH
limites AS (
    SELECT
        MIN(
            TO_DATE(
                ano_competencia || LPAD(mes_competencia, 2, '0') || '01',
                'YYYYMMDD'
            )
        ) AS competencia_minima,
        MAX(
            TO_DATE(
                ano_competencia || LPAD(mes_competencia, 2, '0') || '01',
                'YYYYMMDD'
            )
        ) AS competencia_maxima
    FROM admin.fato_internacao
),
meses AS (
    SELECT
        ADD_MONTHS(l.competencia_minima, LEVEL - 1) AS competencia_data
    FROM limites l
    CONNECT BY LEVEL <=
        MONTHS_BETWEEN(l.competencia_maxima, l.competencia_minima) + 1
),
categorias AS (
    SELECT
        'TOTAL' AS nivel_analise,
        'TOTAL' AS codigo_categoria,
        'Todas as internacoes' AS categoria
    FROM dual
    UNION ALL
    SELECT
        'TIPO_ATENDIMENTO',
        t.codigo_especialidade,
        t.descricao
    FROM admin.dim_tipo_atendimento t
    WHERE EXISTS (
        SELECT 1
        FROM admin.fato_internacao f
        WHERE f.codigo_especialidade = t.codigo_especialidade
    )
),
agregado AS (
    SELECT
        TO_DATE(
            f.ano_competencia || LPAD(f.mes_competencia, 2, '0') || '01',
            'YYYYMMDD'
        ) AS competencia_data,
        'TOTAL' AS nivel_analise,
        'TOTAL' AS codigo_categoria,
        COUNT(*) AS total_internacoes
    FROM admin.fato_internacao f
    GROUP BY
        f.ano_competencia,
        f.mes_competencia
    UNION ALL
    SELECT
        TO_DATE(
            f.ano_competencia || LPAD(f.mes_competencia, 2, '0') || '01',
            'YYYYMMDD'
        ),
        'TIPO_ATENDIMENTO',
        f.codigo_especialidade,
        COUNT(*)
    FROM admin.fato_internacao f
    GROUP BY
        f.ano_competencia,
        f.mes_competencia,
        f.codigo_especialidade
)
SELECT
    EXTRACT(YEAR FROM m.competencia_data) AS ano_competencia,
    EXTRACT(MONTH FROM m.competencia_data) AS mes_competencia,
    TO_NUMBER(TO_CHAR(m.competencia_data, 'YYYYMM')) AS competencia,
    m.competencia_data,
    c.nivel_analise,
    c.codigo_categoria,
    c.categoria,
    NVL(a.total_internacoes, 0) AS total_internacoes,
    'OBSERVADO' AS natureza_valor
FROM meses m
CROSS JOIN categorias c
LEFT JOIN agregado a
    ON a.competencia_data = m.competencia_data
   AND a.nivel_analise = c.nivel_analise
   AND a.codigo_categoria = c.codigo_categoria;

COMMENT ON TABLE vw_internacoes_mensais IS
    'Serie mensal observada de internacoes, consolidada no total e por tipo de atendimento. Meses sem ocorrencia na categoria sao representados por zero.';
COMMENT ON COLUMN vw_internacoes_mensais.competencia IS
    'Competencia observada no formato numerico YYYYMM.';
COMMENT ON COLUMN vw_internacoes_mensais.nivel_analise IS
    'Granularidade da serie: TOTAL ou TIPO_ATENDIMENTO.';
COMMENT ON COLUMN vw_internacoes_mensais.categoria IS
    'Descricao do total consolidado ou do tipo de atendimento.';
COMMENT ON COLUMN vw_internacoes_mensais.total_internacoes IS
    'Quantidade efetivamente observada de registros de internacao na competencia e categoria.';
COMMENT ON COLUMN vw_internacoes_mensais.natureza_valor IS
    'Identifica o valor como OBSERVADO, nunca como previsao.';

CREATE OR REPLACE VIEW vw_previsao_backtest AS
WITH defasagens AS (
    SELECT
        s.*,
        LAG(s.total_internacoes, 1) OVER (
            PARTITION BY s.nivel_analise, s.codigo_categoria
            ORDER BY s.competencia_data
        ) AS internacoes_mes_1,
        LAG(s.total_internacoes, 2) OVER (
            PARTITION BY s.nivel_analise, s.codigo_categoria
            ORDER BY s.competencia_data
        ) AS internacoes_mes_2,
        LAG(s.total_internacoes, 3) OVER (
            PARTITION BY s.nivel_analise, s.codigo_categoria
            ORDER BY s.competencia_data
        ) AS internacoes_mes_3
    FROM vw_internacoes_mensais s
),
previsoes AS (
    SELECT
        d.*,
        ROUND(
            0.50 * d.internacoes_mes_1 +
            0.30 * d.internacoes_mes_2 +
            0.20 * d.internacoes_mes_3
        ) AS total_previsto
    FROM defasagens d
    WHERE d.internacoes_mes_3 IS NOT NULL
)
SELECT
    p.ano_competencia,
    p.mes_competencia,
    p.competencia,
    p.competencia_data,
    p.nivel_analise,
    p.codigo_categoria,
    p.categoria,
    p.total_internacoes AS total_observado,
    p.total_previsto,
    ABS(p.total_internacoes - p.total_previsto) AS erro_absoluto,
    ROUND(
        100 * ABS(p.total_internacoes - p.total_previsto) /
        NULLIF(p.total_internacoes, 0),
        2
    ) AS erro_percentual,
    ADD_MONTHS(p.competencia_data, -3) AS periodo_base_inicio,
    ADD_MONTHS(p.competencia_data, -1) AS periodo_base_fim,
    'Media movel ponderada de 3 meses: 50%, 30% e 20%' AS metodo
FROM previsoes p;

COMMENT ON TABLE vw_previsao_backtest IS
    'Backtest mensal da media movel ponderada. Cada previsao usa apenas as tres competencias anteriores ao valor observado.';
COMMENT ON COLUMN vw_previsao_backtest.total_observado IS
    'Quantidade que ocorreu de fato na competencia avaliada.';
COMMENT ON COLUMN vw_previsao_backtest.total_previsto IS
    'Quantidade que o metodo teria projetado usando somente as tres competencias anteriores.';
COMMENT ON COLUMN vw_previsao_backtest.erro_percentual IS
    'Erro absoluto percentual do backtest. Fica nulo quando o total observado e zero.';

CREATE OR REPLACE VIEW vw_previsao_internacoes AS
WITH ordenado AS (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY s.nivel_analise, s.codigo_categoria
            ORDER BY s.competencia_data DESC
        ) AS ordem_recente
    FROM vw_internacoes_mensais s
),
base AS (
    SELECT
        o.nivel_analise,
        o.codigo_categoria,
        MAX(o.categoria) AS categoria,
        MAX(CASE WHEN o.ordem_recente = 1 THEN o.competencia_data END)
            AS ultima_competencia_observada,
        MIN(CASE WHEN o.ordem_recente BETWEEN 1 AND 3 THEN o.competencia_data END)
            AS periodo_base_inicio,
        MAX(CASE WHEN o.ordem_recente BETWEEN 1 AND 3 THEN o.competencia_data END)
            AS periodo_base_fim,
        MAX(CASE WHEN o.ordem_recente = 1 THEN o.total_internacoes END)
            AS internacoes_mes_1,
        MAX(CASE WHEN o.ordem_recente = 2 THEN o.total_internacoes END)
            AS internacoes_mes_2,
        MAX(CASE WHEN o.ordem_recente = 3 THEN o.total_internacoes END)
            AS internacoes_mes_3,
        COUNT(CASE WHEN o.ordem_recente BETWEEN 1 AND 3 THEN 1 END)
            AS meses_utilizados
    FROM ordenado o
    GROUP BY
        o.nivel_analise,
        o.codigo_categoria
),
avaliacao AS (
    SELECT
        b.nivel_analise,
        b.codigo_categoria,
        COUNT(*) AS observacoes_backtest,
        ROUND(AVG(b.erro_absoluto), 2) AS erro_absoluto_medio,
        ROUND(AVG(b.erro_percentual), 2) AS erro_percentual_medio
    FROM vw_previsao_backtest b
    GROUP BY
        b.nivel_analise,
        b.codigo_categoria
),
calculado AS (
    SELECT
        b.*,
        ROUND(
            0.50 * b.internacoes_mes_1 +
            0.30 * b.internacoes_mes_2 +
            0.20 * b.internacoes_mes_3
        ) AS total_previsto
    FROM base b
    WHERE b.meses_utilizados = 3
)
SELECT
    ADD_MONTHS(c.ultima_competencia_observada, 1) AS competencia_prevista_data,
    TO_NUMBER(
        TO_CHAR(ADD_MONTHS(c.ultima_competencia_observada, 1), 'YYYYMM')
    ) AS competencia_prevista,
    c.nivel_analise,
    c.codigo_categoria,
    c.categoria,
    c.total_previsto,
    GREATEST(
        0,
        ROUND(c.total_previsto - NVL(a.erro_absoluto_medio, 0))
    ) AS limite_inferior_indicativo,
    ROUND(
        c.total_previsto + NVL(a.erro_absoluto_medio, 0)
    ) AS limite_superior_indicativo,
    c.internacoes_mes_1,
    c.internacoes_mes_2,
    c.internacoes_mes_3,
    CASE
        WHEN c.internacoes_mes_1 > c.internacoes_mes_2 * 1.02 THEN 'ALTA'
        WHEN c.internacoes_mes_1 < c.internacoes_mes_2 * 0.98 THEN 'QUEDA'
        ELSE 'ESTAVEL'
    END AS tendencia_recente,
    c.periodo_base_inicio,
    c.periodo_base_fim,
    c.meses_utilizados,
    NVL(a.observacoes_backtest, 0) AS observacoes_backtest,
    a.erro_absoluto_medio,
    a.erro_percentual_medio,
    CASE
        WHEN NVL(a.observacoes_backtest, 0) < 6 THEN
            'HISTORICO_INSUFICIENTE'
        WHEN a.erro_percentual_medio <= 10 THEN
            'MAIOR_ESTABILIDADE_RETROSPECTIVA'
        WHEN a.erro_percentual_medio <= 20 THEN
            'ESTABILIDADE_MODERADA'
        ELSE
            'ALTA_VARIABILIDADE'
    END AS avaliacao_estabilidade,
    1 AS horizonte_meses,
    'PROJECAO' AS natureza_valor,
    'Media movel ponderada de 3 meses: 50%, 30% e 20%' AS metodo,
    'Faixa indicativa baseada no erro absoluto medio do backtest; nao e intervalo de confianca.'
        AS ressalva
FROM calculado c
LEFT JOIN avaliacao a
    ON a.nivel_analise = c.nivel_analise
   AND a.codigo_categoria = c.codigo_categoria;

COMMENT ON TABLE vw_previsao_internacoes IS
    'Projecao explicavel de internacoes para a competencia seguinte, no total e por tipo de atendimento, acompanhada de backtest e ressalvas.';
COMMENT ON COLUMN vw_previsao_internacoes.total_previsto IS
    'Projecao para a competencia seguinte calculada por media movel ponderada das tres competencias mais recentes.';
COMMENT ON COLUMN vw_previsao_internacoes.limite_inferior_indicativo IS
    'Limite indicativo igual a projecao menos o erro absoluto medio retrospectivo, nunca inferior a zero.';
COMMENT ON COLUMN vw_previsao_internacoes.limite_superior_indicativo IS
    'Limite indicativo igual a projecao mais o erro absoluto medio retrospectivo.';
COMMENT ON COLUMN vw_previsao_internacoes.erro_percentual_medio IS
    'Media dos erros percentuais absolutos observados no backtest mensal; nao mede causalidade nem garante desempenho futuro.';
COMMENT ON COLUMN vw_previsao_internacoes.avaliacao_estabilidade IS
    'Leitura descritiva da estabilidade retrospectiva do metodo, sem equivaler a confianca estatistica.';
COMMENT ON COLUMN vw_previsao_internacoes.natureza_valor IS
    'Identifica explicitamente cada linha como PROJECAO, e nao como valor observado.';
COMMENT ON COLUMN vw_previsao_internacoes.ressalva IS
    'Limite interpretativo obrigatorio para o uso da faixa projetada.';

-- Validacao minima apos a criacao:
SELECT
    competencia_prevista,
    nivel_analise,
    codigo_categoria,
    categoria,
    total_previsto,
    limite_inferior_indicativo,
    limite_superior_indicativo,
    erro_percentual_medio,
    avaliacao_estabilidade
FROM vw_previsao_internacoes
ORDER BY
    CASE WHEN nivel_analise = 'TOTAL' THEN 0 ELSE 1 END,
    total_previsto DESC;
