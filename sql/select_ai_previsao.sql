-- Health Data - Inclusao segura da view preditiva no Select AI
-- Executar como ADMIN depois de validar sql/previsao_internacoes.sql.
-- O comando altera somente o object_list do profile existente.

BEGIN
    DBMS_CLOUD_AI.SET_ATTRIBUTE(
        profile_name   => 'HEALTH_DATA_OPENROUTER',
        attribute_name => 'object_list',
        attribute_value => q'~[
            {"owner":"WKSP_HEALTHDATA","name":"VW_RESUMO_GERAL"},
            {"owner":"WKSP_HEALTHDATA","name":"VW_MUNICIPIO_INDICADORES"},
            {"owner":"WKSP_HEALTHDATA","name":"VW_TIPO_ATENDIMENTO_INDICADORES"},
            {"owner":"WKSP_HEALTHDATA","name":"VW_ESTABELECIMENTO_INDICADORES"},
            {"owner":"WKSP_HEALTHDATA","name":"VW_INTERNACOES_MENSAIS"},
            {"owner":"WKSP_HEALTHDATA","name":"VW_PREVISAO_INTERNACOES"}
        ]~'
    );
END;
/

BEGIN
    DBMS_CLOUD_AI.SET_ATTRIBUTE(
        profile_name   => 'HEALTH_DATA_OPENROUTER',
        attribute_name => 'additional_instructions',
        attribute_value => q'~Ao responder perguntas sobre previsao ou projecao de internacoes, use WKSP_HEALTHDATA.VW_PREVISAO_INTERNACOES. Quando a pergunta pedir o total geral ou consolidado, filtre NIVEL_ANALISE = 'TOTAL'. Quando pedir resultados por tipo de atendimento, filtre NIVEL_ANALISE = 'TIPO_ATENDIMENTO'. Nunca some a linha TOTAL com as linhas por tipo, pois representam duas granularidades da mesma populacao. Trate TOTAL_PREVISTO como projecao estatistica experimental, nunca como valor observado, previsao clinica ou resultado de machine learning. Informe a competencia prevista, o periodo base, o metodo, a faixa indicativa e o erro percentual medio quando forem relevantes. Explique que os limites sao indicativos e baseados no erro absoluto medio do backtest, nao um intervalo de confianca. Para perguntas historicas por mes ou competencia, use WKSP_HEALTHDATA.VW_INTERNACOES_MENSAIS e filtre NATUREZA_VALOR = 'OBSERVADO'. Para totais mensais gerais, inclusive maior ou menor mes, filtre tambem NIVEL_ANALISE = 'TOTAL'; para analises mensais por tipo, filtre NIVEL_ANALISE = 'TIPO_ATENDIMENTO'. Nunca some a linha TOTAL com as linhas por tipo. Formate a competencia YYYYMM como MM/YYYY ao responder. Para outros recortes historicos, use as demais views observadas e nao a view de previsao.~'
    );
END;
/

SELECT
    profile_name,
    attribute_name,
    attribute_value
FROM user_cloud_ai_profile_attributes
WHERE profile_name = 'HEALTH_DATA_OPENROUTER'
  AND attribute_name IN ('object_list', 'additional_instructions')
ORDER BY attribute_name;
