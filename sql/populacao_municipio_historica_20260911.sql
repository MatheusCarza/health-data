-- Health Data - Migração idempotente para histórico populacional municipal
-- Executar como ADMIN antes de publicar competências posteriores a 2024.

-- BEGIN MIGRATION
DECLARE
    v_total NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_total
    FROM user_tables
    WHERE table_name = 'DIM_MUNICIPIO_POPULACAO';

    IF v_total = 0 THEN
        EXECUTE IMMEDIATE q'~
            CREATE TABLE dim_municipio_populacao (
                cod_municipio     NUMBER(6)  NOT NULL,
                ano_referencia    NUMBER(4)  NOT NULL,
                populacao         NUMBER(10) NOT NULL,
                atualizado_em     TIMESTAMP WITH TIME ZONE
                    DEFAULT SYSTIMESTAMP NOT NULL,
                CONSTRAINT pk_dim_municipio_populacao PRIMARY KEY (
                    cod_municipio,
                    ano_referencia
                ),
                CONSTRAINT fk_dim_municipio_populacao_municipio FOREIGN KEY (
                    cod_municipio
                ) REFERENCES dim_municipio (cod_municipio),
                CONSTRAINT ck_dim_municipio_populacao_ano CHECK (
                    ano_referencia >= 2000
                ),
                CONSTRAINT ck_dim_municipio_populacao_valor CHECK (
                    populacao >= 0
                )
            )
        ~';
    END IF;
END;
/

COMMENT ON TABLE dim_municipio_populacao IS
    'Historico anual da populacao municipal segundo as estimativas oficiais do IBGE.'
/

COMMENT ON COLUMN dim_municipio_populacao.ano_referencia IS
    'Ano da estimativa populacional do IBGE; nao representa a competencia mensal do SIH/SUS.'
/

MERGE INTO dim_municipio_populacao destino
USING (
    SELECT cod_municipio, 2024 AS ano_referencia, populacao_2024 AS populacao
    FROM dim_municipio
    WHERE populacao_2024 IS NOT NULL
) origem
ON (
    destino.cod_municipio = origem.cod_municipio
    AND destino.ano_referencia = origem.ano_referencia
)
WHEN MATCHED THEN UPDATE SET
    destino.populacao = origem.populacao,
    destino.atualizado_em = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (
    cod_municipio,
    ano_referencia,
    populacao
) VALUES (
    origem.cod_municipio,
    origem.ano_referencia,
    origem.populacao
)
/

COMMIT
/
-- END MIGRATION

SELECT ano_referencia, COUNT(*) AS municipios
FROM dim_municipio_populacao
GROUP BY ano_referencia
ORDER BY ano_referencia;

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name IN (
    'DIM_MUNICIPIO_POPULACAO',
    'PKG_HEALTH_DATA_ETL'
)
ORDER BY object_name, object_type;
