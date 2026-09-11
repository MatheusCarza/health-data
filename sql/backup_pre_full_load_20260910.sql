-- Health Data - snapshot recuperavel antes da migracao para a base integral.
-- Executar uma unica vez como ADMIN antes do backfill completo.

CREATE TABLE bkp_dim_municipio_20260910 AS
SELECT * FROM dim_municipio;

CREATE TABLE bkp_dim_tipo_atend_20260910 AS
SELECT * FROM dim_tipo_atendimento;

CREATE TABLE bkp_dim_estabelec_20260910 AS
SELECT * FROM dim_estabelecimento;

CREATE TABLE bkp_fato_internacao_20260910 AS
SELECT * FROM fato_internacao;

COMMENT ON TABLE bkp_dim_municipio_20260910 IS
    'Snapshot da amostra Health Data anterior ao backfill integral, criado em 2026-09-10.';

COMMENT ON TABLE bkp_dim_tipo_atend_20260910 IS
    'Snapshot da amostra Health Data anterior ao backfill integral, criado em 2026-09-10.';

COMMENT ON TABLE bkp_dim_estabelec_20260910 IS
    'Snapshot da amostra Health Data anterior ao backfill integral, criado em 2026-09-10.';

COMMENT ON TABLE bkp_fato_internacao_20260910 IS
    'Snapshot da amostra Health Data anterior ao backfill integral, criado em 2026-09-10.';

SELECT 'DIM_MUNICIPIO' AS objeto, COUNT(*) AS linhas
FROM bkp_dim_municipio_20260910
UNION ALL
SELECT 'DIM_TIPO_ATENDIMENTO', COUNT(*)
FROM bkp_dim_tipo_atend_20260910
UNION ALL
SELECT 'DIM_ESTABELECIMENTO', COUNT(*)
FROM bkp_dim_estabelec_20260910
UNION ALL
SELECT 'FATO_INTERNACAO', COUNT(*)
FROM bkp_fato_internacao_20260910
ORDER BY objeto;
