-- Health Data - índices analíticos para a fato anual.
-- Executar como ADMIN após o backfill integral.

CREATE INDEX ix_fato_comp_municipio
    ON fato_internacao (
        ano_competencia * 100 + mes_competencia,
        cod_municipio_internacao
    );

CREATE INDEX ix_fato_comp_tipo
    ON fato_internacao (
        ano_competencia * 100 + mes_competencia,
        codigo_especialidade
    );

CREATE INDEX ix_fato_comp_cnes
    ON fato_internacao (
        ano_competencia * 100 + mes_competencia,
        codigo_cnes
    );

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname          => USER,
        tabname          => 'FATO_INTERNACAO',
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
        cascade          => TRUE
    );
END;
/
