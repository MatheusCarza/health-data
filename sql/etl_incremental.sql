-- Health Data - Estruturas e procedimento da carga incremental
-- Executar uma única vez como ADMIN, após sql/ddl_health_data.sql.

ALTER TABLE fato_internacao ADD (
    id_registro_origem VARCHAR2(20)
);

-- A carga histórica não possui id_registro_origem. O índice baseado em função
-- ignora essas linhas (as três expressões ficam nulas) e protege as novas AIHs.
CREATE UNIQUE INDEX uk_fato_internacao_origem
    ON fato_internacao (
        CASE WHEN id_registro_origem IS NOT NULL THEN ano_competencia END,
        CASE WHEN id_registro_origem IS NOT NULL THEN mes_competencia END,
        CASE WHEN id_registro_origem IS NOT NULL THEN id_registro_origem END
    );

COMMENT ON COLUMN fato_internacao.id_registro_origem IS
    'Impressao da chave N_AIH mais SEQUENCIA do SIH/SUS, usada para rastreabilidade e idempotencia sem persistir a chave bruta.';

CREATE TABLE etl_execucao (
    execucao_id          VARCHAR2(36)   NOT NULL,
    pipeline             VARCHAR2(50)   DEFAULT 'health_data_pipeline' NOT NULL,
    uf                   VARCHAR2(2)    NOT NULL,
    ano_competencia      NUMBER(4)      NOT NULL,
    mes_competencia      NUMBER(2)      NOT NULL,
    objeto_sih           VARCHAR2(1000) NOT NULL,
    sha256_sih           VARCHAR2(64)   NOT NULL,
    status               VARCHAR2(20)   DEFAULT 'RECEBIDO' NOT NULL,
    linhas_staging       NUMBER,
    linhas_substituidas  NUMBER,
    iniciado_em          TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    finalizado_em        TIMESTAMP WITH TIME ZONE,
    mensagem_erro        VARCHAR2(4000),
    CONSTRAINT pk_etl_execucao PRIMARY KEY (execucao_id),
    CONSTRAINT ck_etl_execucao_mes CHECK (mes_competencia BETWEEN 1 AND 12),
    CONSTRAINT ck_etl_execucao_status CHECK (
        status IN ('RECEBIDO', 'VALIDADO', 'CARREGANDO', 'SUCESSO', 'FALHA')
    )
);

-- Permite novas tentativas do mesmo arquivo sem apagar a auditoria das falhas,
-- mas garante no máximo uma publicação bem-sucedida por competência e hash.
CREATE UNIQUE INDEX uk_etl_execucao_sucesso
    ON etl_execucao (
        CASE WHEN status = 'SUCESSO' THEN uf END,
        CASE WHEN status = 'SUCESSO' THEN ano_competencia END,
        CASE WHEN status = 'SUCESSO' THEN mes_competencia END,
        CASE WHEN status = 'SUCESSO' THEN sha256_sih END
    );

COMMENT ON TABLE etl_execucao IS
    'Controle auditavel das cargas mensais do pipeline Health Data.';

CREATE TABLE dim_municipio_populacao (
    cod_municipio     NUMBER(6)  NOT NULL,
    ano_referencia    NUMBER(4)  NOT NULL,
    populacao         NUMBER(10) NOT NULL,
    atualizado_em     TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
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
);

COMMENT ON TABLE dim_municipio_populacao IS
    'Historico anual da populacao municipal segundo as estimativas oficiais do IBGE.';

COMMENT ON COLUMN dim_municipio_populacao.ano_referencia IS
    'Ano da estimativa populacional do IBGE; nao representa a competencia mensal do SIH/SUS.';

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
);

CREATE TABLE stg_dim_municipio (
    execucao_id       VARCHAR2(36)  NOT NULL,
    cod_municipio     NUMBER(6)     NOT NULL,
    nome_municipio    VARCHAR2(100),
    uf                VARCHAR2(2)   NOT NULL,
    populacao         NUMBER(10),
    ano_referencia    NUMBER(4)     NOT NULL
);

CREATE INDEX ix_stg_municipio_execucao
    ON stg_dim_municipio (execucao_id, cod_municipio);

CREATE TABLE stg_dim_tipo_atendimento (
    execucao_id             VARCHAR2(36)  NOT NULL,
    codigo_especialidade    VARCHAR2(2)   NOT NULL,
    descricao               VARCHAR2(100)
);

CREATE INDEX ix_stg_tipo_execucao
    ON stg_dim_tipo_atendimento (execucao_id, codigo_especialidade);

CREATE TABLE stg_dim_estabelecimento (
    execucao_id                         VARCHAR2(36)  NOT NULL,
    codigo_cnes                         VARCHAR2(7)   NOT NULL,
    nome_fantasia                       VARCHAR2(200),
    razao_social                        VARCHAR2(200),
    cnpj                                VARCHAR2(14),
    cod_municipio                       NUMBER(6),
    bairro                              VARCHAR2(100),
    endereco                            VARCHAR2(200),
    cep                                 VARCHAR2(8),
    telefone                            VARCHAR2(20),
    email                               VARCHAR2(100),
    latitude                            NUMBER(10,7),
    longitude                           NUMBER(10,7),
    esfera_administrativa               VARCHAR2(50),
    natureza_juridica                   VARCHAR2(100),
    possui_centro_cirurgico             CHAR(1),
    possui_centro_obstetrico            CHAR(1),
    possui_centro_neonatal              CHAR(1),
    possui_atendimento_hospitalar       CHAR(1),
    possui_atendimento_ambulatorial     CHAR(1),
    possui_servico_apoio                CHAR(1),
    data_atualizacao                    DATE,
    dados_json                          JSON
);

CREATE INDEX ix_stg_estabelecimento_execucao
    ON stg_dim_estabelecimento (execucao_id, codigo_cnes);

CREATE TABLE stg_fato_internacao (
    execucao_id               VARCHAR2(36) NOT NULL,
    id_registro_origem        VARCHAR2(20) NOT NULL,
    cod_municipio_residencia  NUMBER(6) NOT NULL,
    cod_municipio_internacao  NUMBER(6) NOT NULL,
    codigo_cnes               VARCHAR2(7) NOT NULL,
    codigo_especialidade      VARCHAR2(2) NOT NULL,
    dt_internacao             DATE,
    dt_saida                  DATE,
    dias_permanencia          NUMBER(5),
    idade                     NUMBER(3),
    sexo                      VARCHAR2(1),
    raca_cor                  VARCHAR2(2),
    diag_principal            VARCHAR2(4),
    proc_realizado            VARCHAR2(10),
    valor_total               NUMBER(12,2),
    valor_uti                 NUMBER(12,2),
    indicador_obito           NUMBER(1) NOT NULL,
    ano_competencia           NUMBER(4) NOT NULL,
    mes_competencia           NUMBER(2) NOT NULL,
    CONSTRAINT ck_stg_fato_mes CHECK (mes_competencia BETWEEN 1 AND 12),
    CONSTRAINT ck_stg_fato_obito CHECK (indicador_obito IN (0, 1))
);

CREATE INDEX ix_stg_fato_execucao
    ON stg_fato_internacao (execucao_id, ano_competencia, mes_competencia);

CREATE OR REPLACE PACKAGE pkg_health_data_etl AS
    PROCEDURE iniciar_execucao (
        p_execucao_id       IN VARCHAR2,
        p_uf                IN VARCHAR2,
        p_ano_competencia   IN NUMBER,
        p_mes_competencia   IN NUMBER,
        p_objeto_sih        IN VARCHAR2,
        p_sha256_sih        IN VARCHAR2
    );

    PROCEDURE marcar_validada (
        p_execucao_id IN VARCHAR2
    );

    PROCEDURE carregar_competencia (
        p_execucao_id IN VARCHAR2
    );

    PROCEDURE registrar_falha (
        p_execucao_id IN VARCHAR2,
        p_mensagem    IN VARCHAR2
    );
END pkg_health_data_etl;
/

CREATE OR REPLACE PACKAGE BODY pkg_health_data_etl AS
    PROCEDURE validar_identificador (p_execucao_id IN VARCHAR2) IS
    BEGIN
        IF NOT REGEXP_LIKE(
            p_execucao_id,
            '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
        ) THEN
            RAISE_APPLICATION_ERROR(-20001, 'execucao_id deve ser um UUID.');
        END IF;
    END validar_identificador;

    PROCEDURE iniciar_execucao (
        p_execucao_id       IN VARCHAR2,
        p_uf                IN VARCHAR2,
        p_ano_competencia   IN NUMBER,
        p_mes_competencia   IN NUMBER,
        p_objeto_sih        IN VARCHAR2,
        p_sha256_sih        IN VARCHAR2
    ) IS
    BEGIN
        validar_identificador(p_execucao_id);
        IF NOT REGEXP_LIKE(UPPER(p_uf), '^[A-Z]{2}$') THEN
            RAISE_APPLICATION_ERROR(-20002, 'UF invalida.');
        END IF;
        IF p_mes_competencia NOT BETWEEN 1 AND 12 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Mes de competencia invalido.');
        END IF;
        IF NOT REGEXP_LIKE(LOWER(p_sha256_sih), '^[0-9a-f]{64}$') THEN
            RAISE_APPLICATION_ERROR(-20004, 'SHA-256 invalido.');
        END IF;

        INSERT INTO etl_execucao (
            execucao_id,
            uf,
            ano_competencia,
            mes_competencia,
            objeto_sih,
            sha256_sih,
            status
        ) VALUES (
            p_execucao_id,
            UPPER(p_uf),
            p_ano_competencia,
            p_mes_competencia,
            p_objeto_sih,
            LOWER(p_sha256_sih),
            'RECEBIDO'
        );
        COMMIT;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(
                -20005,
                'Arquivo ou execucao ja registrado para esta competencia.'
            );
    END iniciar_execucao;

    PROCEDURE marcar_validada (p_execucao_id IN VARCHAR2) IS
    BEGIN
        UPDATE etl_execucao
        SET status = 'VALIDADO',
            mensagem_erro = NULL
        WHERE execucao_id = p_execucao_id
          AND status = 'RECEBIDO';

        IF SQL%ROWCOUNT <> 1 THEN
            RAISE_APPLICATION_ERROR(-20006, 'Execucao nao esta em RECEBIDO.');
        END IF;
        COMMIT;
    END marcar_validada;

    PROCEDURE registrar_falha (
        p_execucao_id IN VARCHAR2,
        p_mensagem    IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE etl_execucao
        SET status = 'FALHA',
            finalizado_em = SYSTIMESTAMP,
            mensagem_erro = SUBSTR(p_mensagem, 1, 4000)
        WHERE execucao_id = p_execucao_id;
        COMMIT;
    END registrar_falha;

    PROCEDURE carregar_competencia (p_execucao_id IN VARCHAR2) IS
        v_uf                   etl_execucao.uf%TYPE;
        v_ano                  etl_execucao.ano_competencia%TYPE;
        v_mes                  etl_execucao.mes_competencia%TYPE;
        v_linhas_staging       NUMBER;
        v_linhas_inseridas     NUMBER;
        v_duplicadas           NUMBER;
        v_invalidas            NUMBER;
    BEGIN
        SELECT uf, ano_competencia, mes_competencia
        INTO v_uf, v_ano, v_mes
        FROM etl_execucao
        WHERE execucao_id = p_execucao_id
          AND status = 'VALIDADO'
        FOR UPDATE;

        UPDATE etl_execucao
        SET status = 'CARREGANDO'
        WHERE execucao_id = p_execucao_id;

        SELECT COUNT(*)
        INTO v_linhas_staging
        FROM stg_fato_internacao
        WHERE execucao_id = p_execucao_id;

        IF v_linhas_staging = 0 THEN
            RAISE_APPLICATION_ERROR(-20007, 'Staging da fato esta vazia.');
        END IF;

        SELECT COUNT(*)
        INTO v_invalidas
        FROM stg_fato_internacao
        WHERE execucao_id = p_execucao_id
          AND (ano_competencia <> v_ano OR mes_competencia <> v_mes);

        IF v_invalidas > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20008,
                'Staging contem linhas de outra competencia.'
            );
        END IF;

        SELECT COUNT(*)
        INTO v_duplicadas
        FROM (
            SELECT id_registro_origem
            FROM stg_fato_internacao
            WHERE execucao_id = p_execucao_id
            GROUP BY id_registro_origem
            HAVING COUNT(*) > 1
        );

        IF v_duplicadas > 0 THEN
            RAISE_APPLICATION_ERROR(-20009, 'Staging contem AIHs duplicadas.');
        END IF;

        SELECT COUNT(*)
        INTO v_duplicadas
        FROM (
            SELECT TO_CHAR(cod_municipio) AS chave
            FROM stg_dim_municipio
            WHERE execucao_id = p_execucao_id
            GROUP BY cod_municipio
            HAVING COUNT(*) > 1
            UNION ALL
            SELECT codigo_especialidade
            FROM stg_dim_tipo_atendimento
            WHERE execucao_id = p_execucao_id
            GROUP BY codigo_especialidade
            HAVING COUNT(*) > 1
            UNION ALL
            SELECT codigo_cnes
            FROM stg_dim_estabelecimento
            WHERE execucao_id = p_execucao_id
            GROUP BY codigo_cnes
            HAVING COUNT(*) > 1
        );

        IF v_duplicadas > 0 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Staging contem dimensoes duplicadas.');
        END IF;

        MERGE INTO dim_municipio destino
        USING (
            SELECT
                cod_municipio,
                nome_municipio,
                uf,
                populacao,
                ano_referencia
            FROM stg_dim_municipio
            WHERE execucao_id = p_execucao_id
        ) origem
        ON (destino.cod_municipio = origem.cod_municipio)
        WHEN MATCHED THEN UPDATE SET
            destino.nome_municipio = origem.nome_municipio,
            destino.uf = origem.uf,
            destino.populacao_2024 = CASE
                WHEN origem.ano_referencia = 2024 THEN origem.populacao
                ELSE destino.populacao_2024
            END
        WHEN NOT MATCHED THEN INSERT (
            cod_municipio, nome_municipio, uf, populacao_2024
        ) VALUES (
            origem.cod_municipio,
            origem.nome_municipio,
            origem.uf,
            CASE
                WHEN origem.ano_referencia = 2024 THEN origem.populacao
                ELSE NULL
            END
        );

        MERGE INTO dim_municipio_populacao destino
        USING (
            SELECT
                cod_municipio,
                ano_referencia,
                populacao
            FROM stg_dim_municipio
            WHERE execucao_id = p_execucao_id
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
        );

        MERGE INTO dim_tipo_atendimento destino
        USING (
            SELECT codigo_especialidade, descricao
            FROM stg_dim_tipo_atendimento
            WHERE execucao_id = p_execucao_id
        ) origem
        ON (destino.codigo_especialidade = origem.codigo_especialidade)
        WHEN MATCHED THEN UPDATE SET
            destino.descricao = origem.descricao
        WHEN NOT MATCHED THEN INSERT (
            codigo_especialidade, descricao
        ) VALUES (
            origem.codigo_especialidade,
            origem.descricao
        );

        MERGE INTO dim_estabelecimento destino
        USING (
            SELECT *
            FROM stg_dim_estabelecimento
            WHERE execucao_id = p_execucao_id
        ) origem
        ON (destino.codigo_cnes = origem.codigo_cnes)
        WHEN MATCHED THEN UPDATE SET
            destino.nome_fantasia = origem.nome_fantasia,
            destino.razao_social = origem.razao_social,
            destino.cnpj = origem.cnpj,
            destino.cod_municipio = origem.cod_municipio,
            destino.bairro = origem.bairro,
            destino.endereco = origem.endereco,
            destino.cep = origem.cep,
            destino.telefone = origem.telefone,
            destino.email = origem.email,
            destino.latitude = origem.latitude,
            destino.longitude = origem.longitude,
            destino.esfera_administrativa = origem.esfera_administrativa,
            destino.natureza_juridica = origem.natureza_juridica,
            destino.possui_centro_cirurgico = origem.possui_centro_cirurgico,
            destino.possui_centro_obstetrico = origem.possui_centro_obstetrico,
            destino.possui_centro_neonatal = origem.possui_centro_neonatal,
            destino.possui_atendimento_hospitalar = origem.possui_atendimento_hospitalar,
            destino.possui_atendimento_ambulatorial = origem.possui_atendimento_ambulatorial,
            destino.possui_servico_apoio = origem.possui_servico_apoio,
            destino.data_atualizacao = origem.data_atualizacao,
            destino.dados_json = origem.dados_json
        WHEN NOT MATCHED THEN INSERT (
            codigo_cnes,
            nome_fantasia,
            razao_social,
            cnpj,
            cod_municipio,
            bairro,
            endereco,
            cep,
            telefone,
            email,
            latitude,
            longitude,
            esfera_administrativa,
            natureza_juridica,
            possui_centro_cirurgico,
            possui_centro_obstetrico,
            possui_centro_neonatal,
            possui_atendimento_hospitalar,
            possui_atendimento_ambulatorial,
            possui_servico_apoio,
            data_atualizacao,
            dados_json
        ) VALUES (
            origem.codigo_cnes,
            origem.nome_fantasia,
            origem.razao_social,
            origem.cnpj,
            origem.cod_municipio,
            origem.bairro,
            origem.endereco,
            origem.cep,
            origem.telefone,
            origem.email,
            origem.latitude,
            origem.longitude,
            origem.esfera_administrativa,
            origem.natureza_juridica,
            origem.possui_centro_cirurgico,
            origem.possui_centro_obstetrico,
            origem.possui_centro_neonatal,
            origem.possui_atendimento_hospitalar,
            origem.possui_atendimento_ambulatorial,
            origem.possui_servico_apoio,
            origem.data_atualizacao,
            origem.dados_json
        );

        SELECT COUNT(*)
        INTO v_invalidas
        FROM stg_fato_internacao f
        WHERE f.execucao_id = p_execucao_id
          AND (
              NOT EXISTS (
                  SELECT 1 FROM dim_municipio m
                  WHERE m.cod_municipio = f.cod_municipio_residencia
              )
              OR NOT EXISTS (
                  SELECT 1 FROM dim_municipio m
                  WHERE m.cod_municipio = f.cod_municipio_internacao
              )
              OR NOT EXISTS (
                  SELECT 1 FROM dim_estabelecimento e
                  WHERE e.codigo_cnes = f.codigo_cnes
              )
              OR NOT EXISTS (
                  SELECT 1 FROM dim_tipo_atendimento t
                  WHERE t.codigo_especialidade = f.codigo_especialidade
              )
          );

        IF v_invalidas > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20010,
                'Staging possui chaves sem correspondencia nas dimensoes.'
            );
        END IF;

        DELETE FROM fato_internacao
        WHERE ano_competencia = v_ano
          AND mes_competencia = v_mes;

        INSERT INTO fato_internacao (
            id_registro_origem,
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
            mes_competencia
        )
        SELECT
            id_registro_origem,
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
            mes_competencia
        FROM stg_fato_internacao
        WHERE execucao_id = p_execucao_id;

        v_linhas_inseridas := SQL%ROWCOUNT;
        IF v_linhas_inseridas <> v_linhas_staging THEN
            RAISE_APPLICATION_ERROR(
                -20011,
                'Contagem inserida diverge da staging.'
            );
        END IF;

        DELETE FROM stg_fato_internacao WHERE execucao_id = p_execucao_id;
        DELETE FROM stg_dim_estabelecimento WHERE execucao_id = p_execucao_id;
        DELETE FROM stg_dim_tipo_atendimento WHERE execucao_id = p_execucao_id;
        DELETE FROM stg_dim_municipio WHERE execucao_id = p_execucao_id;

        UPDATE etl_execucao
        SET status = 'SUCESSO',
            linhas_staging = v_linhas_staging,
            linhas_substituidas = v_linhas_inseridas,
            finalizado_em = SYSTIMESTAMP,
            mensagem_erro = NULL
        WHERE execucao_id = p_execucao_id;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            registrar_falha(p_execucao_id, 'Execucao inexistente ou nao validada.');
            RAISE_APPLICATION_ERROR(-20012, 'Execucao inexistente ou nao validada.');
        WHEN OTHERS THEN
            ROLLBACK;
            registrar_falha(p_execucao_id, SQLERRM);
            RAISE;
    END carregar_competencia;
END pkg_health_data_etl;
/
