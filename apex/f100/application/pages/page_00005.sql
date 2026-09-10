prompt --application/pages/page_00005
begin
--   Manifest
--     PAGE: 00005
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.4'
,p_default_workspace_id=>9348757358068450
,p_default_application_id=>100
,p_default_id_offset=>0
,p_default_owner=>'WKSP_HEALTHDATA'
);
wwv_flow_imp_page.create_page(
 p_id=>5
,p_name=>'Assistente IA'
,p_alias=>'ASSISTENTE-IA'
,p_step_title=>'Assistente IA'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4073832297226169690
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'17'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(9406306354458042)
,p_plug_name=>'Breadcrumb'
,p_static_id=>'breadcrumb'
,p_region_template_options=>'#DEFAULT#:t-BreadcrumbRegion--useBreadcrumbTitle'
,p_component_template_options=>'#DEFAULT#'
,p_plug_template=>2532939663579242476
,p_plug_display_sequence=>10
,p_plug_display_point=>'REGION_POSITION_01'
,p_plug_item_display_point=>'ABOVE'
,p_menu_id=>wwv_flow_imp.id(9357275359169170)
,p_plug_source_type=>'NATIVE_BREADCRUMB'
,p_menu_template_id=>4073839682315169711
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(9379005333218610)
,p_plug_name=>'Pergunte ao Health Data'
,p_static_id=>'new'
,p_title=>'Pergunte ao Health Data'
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_plug_template=>4073835273271169698
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(9379340651218613)
,p_button_sequence=>30
,p_button_plug_id=>wwv_flow_imp.id(9379005333218610)
,p_button_name=>'ANALISAR'
,p_static_id=>'analisar'
,p_show_as_disabled=>false
,p_button_action=>'DEFINED_BY_DA'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4073839297780169708
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Analisar'
,p_button_position=>'CREATE'
,p_warn_on_unsaved_changes=>null
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(9379171863218611)
,p_name=>'P5_PERGUNTA'
,p_is_required=>true
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(9379005333218610)
,p_prompt=>unistr('O que voc\00EA quer saber?')
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_TEXTAREA'
,p_cSize=>30
,p_cHeight=>5
,p_field_template=>1610598304472262251
,p_item_template_options=>'#DEFAULT#'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(9379272978218612)
,p_name=>'P5_RESPOSTA'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(9379005333218610)
,p_prompt=>'Resposta do Health Data'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_TEXTAREA'
,p_cSize=>30
,p_cHeight=>10
,p_read_only_when_type=>'ALWAYS'
,p_field_template=>1610598304472262251
,p_item_template_options=>'#DEFAULT#'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(9549946929981603)
,p_name=>'Consultar Select AI AJAX'
,p_static_id=>'consultar-select-ai-ajax'
,p_event_sequence=>10
,p_triggering_element_type=>'BUTTON'
,p_triggering_button_id=>wwv_flow_imp.id(9379340651218613)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'click'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(9772725502510901)
,p_event_id=>wwv_flow_imp.id(9549946929981603)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_static_id=>'native-disable'
,p_action=>'NATIVE_DISABLE'
,p_affected_elements_type=>'BUTTON'
,p_affected_button_id=>wwv_flow_imp.id(9379340651218613)
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(9772860045510902)
,p_event_id=>wwv_flow_imp.id(9549946929981603)
,p_event_result=>'TRUE'
,p_action_sequence=>40
,p_execute_on_page_init=>'N'
,p_static_id=>'native-enable'
,p_action=>'NATIVE_ENABLE'
,p_affected_elements_type=>'BUTTON'
,p_affected_button_id=>wwv_flow_imp.id(9379340651218613)
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(9550035821981604)
,p_event_id=>wwv_flow_imp.id(9549946929981603)
,p_event_result=>'TRUE'
,p_action_sequence=>30
,p_execute_on_page_init=>'N'
,p_static_id=>'native-execute-plsql-code'
,p_action=>'NATIVE_EXECUTE_PLSQL_CODE'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'items_to_return', 'P5_RESPOSTA',
  'items_to_submit', 'P5_PERGUNTA',
  'language', 'PLSQL',
  'plsql_code', wwv_flow_string.join(wwv_flow_t_varchar2(
    'DECLARE',
    '    l_resposta CLOB;',
    'BEGIN',
    '    l_resposta := ADMIN.HEALTH_DATA_SELECT_AI(',
    '        p_prompt => :P5_PERGUNTA,',
    '        p_action => ''narrate''',
    '    );',
    '',
    '    :P5_RESPOSTA := DBMS_LOB.SUBSTR(',
    '        l_resposta,',
    '        32767,',
    '        1',
    '    );',
    'EXCEPTION',
    '    WHEN OTHERS THEN',
    '        :P5_RESPOSTA :=',
    unistr('            ''N\00E3o foi poss\00EDvel concluir a consulta agora. Aguarde um momento e tente novamente.'';'),
    'END;')),
  'show_processing', 'Y',
  'suppress_change_event', 'N')).to_clob
,p_stop_execution_on_error=>'N'
,p_wait_for_result=>'Y'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(9772956302510903)
,p_event_id=>wwv_flow_imp.id(9549946929981603)
,p_event_result=>'TRUE'
,p_action_sequence=>20
,p_execute_on_page_init=>'N'
,p_static_id=>'native-set-value'
,p_action=>'NATIVE_SET_VALUE'
,p_affected_elements_type=>'ITEM'
,p_affected_elements=>'P5_RESPOSTA'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'suppress_change_event', 'N',
  'type', 'STATIC_ASSIGNMENT',
  'value', 'Consultando os dados...')).to_clob
,p_wait_for_result=>'Y'
);
wwv_flow_imp.component_end;
end;
/
