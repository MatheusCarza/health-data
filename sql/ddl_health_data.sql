-- ============================================================================

-- DROP TABLE fato_internacao PURGE;
-- DROP TABLE dim_estabelecimento PURGE;
-- DROP TABLE dim_tipo_atendimento PURGE;
-- DROP TABLE dim_municipio PURGE;
-- DROP TABLE dim_municipio_ext;
-- BEGIN DBMS_CLOUD.DROP_EXTERNAL_TABLE(table_name => 'DIM_MUNICIPIO_EXT'); END;
-- /

-- ============================================================================
-- 0. dim_municipio_ext — EXTERNAL TABLE, Fonte 3 (IBGE, CSV), camada Bronze
-- ============================================================================
-- Pre-requisito (feito uma vez, fora deste script, via Console OCI):
--   1. Criar um bucket no Object Storage (ex.: "health-data-challenge").
--   2. Fazer upload de dados/ibge_populacao_sp_2024.csv pro bucket.
--   3. Gerar uma Pre-Authenticated Request (PAR) de leitura pro objeto
--      (Object Storage > bucket > objeto > "Create Pre-Authenticated Request").
--   4. Colar a URL gerada no lugar de <PAR_URL_AQUI> abaixo.
-- A PAR ja e auto-autenticada (URL de leitura publica temporaria/permanente),
-- por isso credential_name fica NULL - nao precisa DBMS_CLOUD.CREATE_CREDENTIAL.

BEGIN
    DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
        table_name      => 'DIM_MUNICIPIO_EXT',
        credential_name => NULL,
        file_uri_list   => '<PAR_URL_AQUI>',
        format          => JSON_OBJECT('type' VALUE 'csv', 'skipheaders' VALUE '1', 'delimiter' VALUE ','),
        column_list     => 'MUNIC_RES_IBGE NUMBER(7), NOME_MUNICIPIO VARCHAR2(100), POPULACAO NUMBER(10)'
    );
END;
/

-- COMMENT ON TABLE nao e suportado em tabelas externas pelo Oracle
-- (ORA-30657: "operation not supported on external organized table").
-- Documentacao do proposito desta tabela fica so no comentario SQL acima.

-- ============================================================================
-- 1. dim_municipio — dados geograficos (municipios de SP), camada Prata
-- ============================================================================
CREATE TABLE dim_municipio (
    cod_municipio       NUMBER(6)       NOT NULL,
    nome_municipio      VARCHAR2(100),
    uf                  VARCHAR2(2)     DEFAULT 'SP' NOT NULL,
    populacao_2024      NUMBER(10),
    CONSTRAINT pk_dim_municipio PRIMARY KEY (cod_municipio)
);

COMMENT ON TABLE dim_municipio IS 'Dimensao geografica: municipios do estado de Sao Paulo. Codigo no padrao DATASUS (6 digitos, sem digito verificador). Populada a partir de dim_municipio_ext (camada Bronze -> Prata), convertendo o codigo IBGE de 7 para 6 digitos.';
COMMENT ON COLUMN dim_municipio.cod_municipio IS 'Codigo do municipio no padrao IBGE/DATASUS de 6 digitos (mesmo formato usado em SIH.MUNIC_RES e CNES.codigo_municipio).';
COMMENT ON COLUMN dim_municipio.nome_municipio IS 'Nome oficial do municipio conforme a tabela de Estimativas da Populacao 2024 do IBGE.';
COMMENT ON COLUMN dim_municipio.uf IS 'Sigla da unidade federativa do municipio. No recorte atual do Health Data, o valor esperado e SP.';
COMMENT ON COLUMN dim_municipio.populacao_2024 IS 'Populacao estimada 2024, Fonte 3 (IBGE), via dim_municipio_ext.';

-- ============================================================================
-- 2. dim_tipo_atendimento — especialidade do leito (perfis/categorias de atendimento)
-- ============================================================================
CREATE TABLE dim_tipo_atendimento (
    codigo_especialidade   VARCHAR2(2)     NOT NULL,
    descricao               VARCHAR2(100),
    CONSTRAINT pk_dim_tipo_atendimento PRIMARY KEY (codigo_especialidade)
);

COMMENT ON TABLE dim_tipo_atendimento IS 'Dimensao de tipo/perfil de atendimento: especialidade do leito (campo ESPEC do SIH/SUS).';
COMMENT ON COLUMN dim_tipo_atendimento.codigo_especialidade IS 'Codigo da especialidade do leito conforme tabela oficial SIGTAP/SIH (campo ESPEC). Valores encontrados no dataset: 01,02,03,04,05,06,07,08,09,10,12,13,14,87.';
COMMENT ON COLUMN dim_tipo_atendimento.descricao IS 'Descricao da especialidade - CONFERIR e preencher com a tabela oficial de especialidades do SIH/SIGTAP antes da carga (nao inventar descricao sem checar a fonte oficial).';

-- ============================================================================
-- 3. dim_estabelecimento — hospitais / unidades de saude / capacidade (Fonte 2: CNES)
-- ============================================================================
CREATE TABLE dim_estabelecimento (
    codigo_cnes                        VARCHAR2(7)     NOT NULL,
    nome_fantasia                      VARCHAR2(200),
    razao_social                       VARCHAR2(200),
    cnpj                                VARCHAR2(14),
    cod_municipio                      NUMBER(6),
    bairro                              VARCHAR2(100),
    endereco                            VARCHAR2(200),
    cep                                  VARCHAR2(8),
    telefone                            VARCHAR2(20),
    email                                VARCHAR2(100),
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
    dados_json                          JSON,
    CONSTRAINT pk_dim_estabelecimento PRIMARY KEY (codigo_cnes),
    CONSTRAINT fk_estabelecimento_municipio FOREIGN KEY (cod_municipio)
        REFERENCES dim_municipio (cod_municipio)
);

COMMENT ON TABLE dim_estabelecimento IS 'Dimensao de hospitais/unidades de saude e capacidade instalada, Fonte 2 (CNES, JSON via API apidadosabertos.saude.gov.br).';
COMMENT ON COLUMN dim_estabelecimento.codigo_cnes IS 'Codigo CNES do estabelecimento (chave natural, tambem referenciada no campo CNES do SIH).';
COMMENT ON COLUMN dim_estabelecimento.nome_fantasia IS 'Nome pelo qual o estabelecimento de saude e conhecido publicamente, conforme o CNES.';
COMMENT ON COLUMN dim_estabelecimento.razao_social IS 'Razao social da entidade responsavel pelo estabelecimento, conforme o CNES.';
COMMENT ON COLUMN dim_estabelecimento.cnpj IS 'CNPJ da entidade responsavel pelo estabelecimento, quando informado pelo CNES.';
COMMENT ON COLUMN dim_estabelecimento.cod_municipio IS 'Municipio do estabelecimento (FK dim_municipio), codigo DATASUS 6 digitos - mesmo formato ja usado pelo CNES, sem conversao necessaria.';
COMMENT ON COLUMN dim_estabelecimento.bairro IS 'Bairro do endereco do estabelecimento de saude, conforme o CNES.';
COMMENT ON COLUMN dim_estabelecimento.endereco IS 'Logradouro do estabelecimento de saude, conforme o CNES.';
COMMENT ON COLUMN dim_estabelecimento.cep IS 'CEP do estabelecimento de saude, conforme o CNES.';
COMMENT ON COLUMN dim_estabelecimento.telefone IS 'Telefone institucional do estabelecimento de saude, quando informado pelo CNES.';
COMMENT ON COLUMN dim_estabelecimento.email IS 'Endereco de email institucional do estabelecimento de saude, quando informado pelo CNES.';
COMMENT ON COLUMN dim_estabelecimento.latitude IS 'Latitude geografica do estabelecimento, usada em mapas e analises territoriais.';
COMMENT ON COLUMN dim_estabelecimento.longitude IS 'Longitude geografica do estabelecimento, usada em mapas e analises territoriais.';
COMMENT ON COLUMN dim_estabelecimento.esfera_administrativa IS 'Esfera administrativa responsavel pelo estabelecimento de saude, conforme classificacao do CNES.';
COMMENT ON COLUMN dim_estabelecimento.natureza_juridica IS 'Natureza juridica da entidade responsavel pelo estabelecimento, conforme o CNES.';
COMMENT ON COLUMN dim_estabelecimento.possui_centro_cirurgico IS 'Indicador de capacidade hospitalar (S/N) - origem: estabelecimento_possui_centro_cirurgico do CNES.';
COMMENT ON COLUMN dim_estabelecimento.possui_centro_obstetrico IS 'Indicador de existencia de centro obstetrico no estabelecimento (S/N), conforme o CNES.';
COMMENT ON COLUMN dim_estabelecimento.possui_centro_neonatal IS 'Indicador de existencia de centro neonatal no estabelecimento (S/N), conforme o CNES.';
COMMENT ON COLUMN dim_estabelecimento.possui_atendimento_hospitalar IS 'Indicador de capacidade hospitalar (S/N) - origem: estabelecimento_possui_atendimento_hospitalar do CNES.';
COMMENT ON COLUMN dim_estabelecimento.possui_atendimento_ambulatorial IS 'Indicador de oferta de atendimento ambulatorial pelo estabelecimento (S/N), conforme o CNES.';
COMMENT ON COLUMN dim_estabelecimento.possui_servico_apoio IS 'Indicador de existencia de servicos de apoio no estabelecimento (S/N), conforme o CNES.';
COMMENT ON COLUMN dim_estabelecimento.data_atualizacao IS 'Data da ultima atualizacao do registro do estabelecimento informada pelo CNES.';
COMMENT ON COLUMN dim_estabelecimento.dados_json IS 'Registro completo do estabelecimento em formato JSON nativo (tipo JSON do Oracle), preservando o dado semiestruturado original da API do CNES - alem das colunas relacionais ja extraidas acima, usadas para FK/filtros/analises.';

-- ============================================================================
-- 4. fato_internacao — internacoes hospitalares (Fonte 1: SIH/SUS)
-- ============================================================================
CREATE TABLE fato_internacao (
    id_internacao           NUMBER          GENERATED ALWAYS AS IDENTITY,
    cod_municipio_residencia NUMBER(6),
    cod_municipio_internacao NUMBER(6),
    codigo_cnes              VARCHAR2(7),
    codigo_especialidade     VARCHAR2(2),
    dt_internacao             DATE,
    dt_saida                  DATE,
    dias_permanencia          NUMBER(5),
    idade                      NUMBER(3),
    sexo                       VARCHAR2(1),
    raca_cor                   VARCHAR2(2),
    diag_principal             VARCHAR2(4),
    proc_realizado             VARCHAR2(10),
    valor_total                NUMBER(12,2),
    valor_uti                  NUMBER(12,2),
    indicador_obito            NUMBER(1),
    ano_competencia            NUMBER(4),
    mes_competencia            NUMBER(2),
    CONSTRAINT pk_fato_internacao PRIMARY KEY (id_internacao),
    CONSTRAINT fk_internacao_munic_res FOREIGN KEY (cod_municipio_residencia)
        REFERENCES dim_municipio (cod_municipio),
    CONSTRAINT fk_internacao_munic_int FOREIGN KEY (cod_municipio_internacao)
        REFERENCES dim_municipio (cod_municipio),
    CONSTRAINT fk_internacao_estabelecimento FOREIGN KEY (codigo_cnes)
        REFERENCES dim_estabelecimento (codigo_cnes),
    CONSTRAINT fk_internacao_especialidade FOREIGN KEY (codigo_especialidade)
        REFERENCES dim_tipo_atendimento (codigo_especialidade)
);

COMMENT ON TABLE fato_internacao IS 'Fato: internacoes hospitalares do estado de Sao Paulo, ano 2024, Fonte 1 (SIH/SUS, AIH Reduzida). 2.855.539 registros originais.';
COMMENT ON COLUMN fato_internacao.id_internacao IS 'Chave substituta (surrogate key) gerada pelo Oracle para identificar cada linha da tabela fato.';
COMMENT ON COLUMN fato_internacao.cod_municipio_residencia IS 'Municipio de residencia do paciente (origem: SIH.MUNIC_RES).';
COMMENT ON COLUMN fato_internacao.cod_municipio_internacao IS 'Municipio onde ocorreu a internacao (origem: SIH.MUNIC_MOV).';
COMMENT ON COLUMN fato_internacao.codigo_cnes IS 'Estabelecimento de saude onde ocorreu a internacao, identificado pelo codigo CNES.';
COMMENT ON COLUMN fato_internacao.codigo_especialidade IS 'Tipo de atendimento ou especialidade do leito da internacao, conforme o campo ESPEC do SIH/SUS.';
COMMENT ON COLUMN fato_internacao.dt_internacao IS 'Data de inicio da internacao hospitalar, origem SIH/DT_INTER.';
COMMENT ON COLUMN fato_internacao.dt_saida IS 'Data de encerramento ou saida da internacao hospitalar, origem SIH/DT_SAIDA.';
COMMENT ON COLUMN fato_internacao.dias_permanencia IS 'Dias de permanencia (origem: SIH.DIAS_PERM) - indicador chave de capacidade/pressao hospitalar.';
COMMENT ON COLUMN fato_internacao.idade IS 'Idade do paciente em anos na internacao, usada somente de forma agregada nas analises.';
COMMENT ON COLUMN fato_internacao.sexo IS 'Sexo registrado no SIH/SUS para caracterizacao agregada do perfil das internacoes.';
COMMENT ON COLUMN fato_internacao.raca_cor IS 'Codigo de raca ou cor registrado no SIH/SUS para analises agregadas de equidade assistencial.';
COMMENT ON COLUMN fato_internacao.diag_principal IS 'Codigo CID-10 do diagnostico principal (origem: SIH.DIAG_PRINC). Sem tabela de dominio propria neste escopo - nao ha dataset de descricoes de CID baixado ainda.';
COMMENT ON COLUMN fato_internacao.proc_realizado IS 'Codigo do procedimento principal realizado durante a internacao, conforme o SIH/SUS.';
COMMENT ON COLUMN fato_internacao.valor_total IS 'Valor total pago pela internacao (origem: SIH.VAL_TOT).';
COMMENT ON COLUMN fato_internacao.valor_uti IS 'Valor associado ao uso de unidade de terapia intensiva na internacao, conforme o SIH/SUS.';
COMMENT ON COLUMN fato_internacao.indicador_obito IS 'Indicador de obito (origem: SIH.MORTE) - 0 ou 1.';
COMMENT ON COLUMN fato_internacao.ano_competencia IS 'Ano da competencia de processamento da internacao no SIH/SUS.';
COMMENT ON COLUMN fato_internacao.mes_competencia IS 'Mes da competencia de processamento da internacao no SIH/SUS, de 1 a 12.';
