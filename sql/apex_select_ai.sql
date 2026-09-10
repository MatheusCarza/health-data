-- Health Data - Integração do Oracle APEX com o Select AI
-- Executar como ADMIN no Autonomous AI Database.

CREATE OR REPLACE FUNCTION health_data_select_ai (
    p_prompt IN VARCHAR2,
    p_action IN VARCHAR2 DEFAULT 'narrate'
) RETURN CLOB
AUTHID DEFINER
AS
    l_action VARCHAR2(20) := LOWER(TRIM(p_action));
BEGIN
    IF p_prompt IS NULL OR LENGTH(TRIM(p_prompt)) < 5 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Informe uma pergunta com pelo menos cinco caracteres.'
        );
    END IF;

    IF l_action NOT IN ('narrate', 'showsql', 'runsql') THEN
        RAISE_APPLICATION_ERROR(-20002, 'Ação Select AI não permitida.');
    END IF;

    RETURN DBMS_CLOUD_AI.GENERATE(
        prompt       => TRIM(p_prompt),
        profile_name => 'HEALTH_DATA_OPENROUTER',
        action       => l_action
    );
END;
/

GRANT EXECUTE ON health_data_select_ai TO wksp_healthdata;
