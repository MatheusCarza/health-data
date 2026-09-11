-- Health Data - correção para retry auditável e Parallel DML.
-- Executar uma vez como ADMIN em instalações que já possuem ETL_EXECUCAO.

ALTER TABLE etl_execucao
    DROP CONSTRAINT uk_etl_execucao_arquivo;

CREATE UNIQUE INDEX uk_etl_execucao_sucesso
    ON etl_execucao (
        CASE WHEN status = 'SUCESSO' THEN uf END,
        CASE WHEN status = 'SUCESSO' THEN ano_competencia END,
        CASE WHEN status = 'SUCESSO' THEN mes_competencia END,
        CASE WHEN status = 'SUCESSO' THEN sha256_sih END
    );
