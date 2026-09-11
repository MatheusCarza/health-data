prompt --application/pages/page_00002
begin
--   Manifest
--     PAGE: 00002
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
 p_id=>2
,p_name=>unistr('Munic\00EDpios')
,p_alias=>unistr('MUNIC\00CDPIOS')
,p_step_title=>unistr('Munic\00EDpios')
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4073832297226169690
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'18'
,p_created_on=>wwv_flow_imp.dz('20260909155326Z')
,p_last_updated_on=>wwv_flow_imp.dz('20260911151444Z')
,p_created_by=>'MATHEUS'
,p_last_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(9387963023362746)
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
,p_created_on=>wwv_flow_imp.dz('20260909155326Z')
,p_updated_on=>wwv_flow_imp.dz('20260909155326Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(9388709517362885)
,p_plug_name=>unistr('Munic\00EDpios')
,p_static_id=>unistr('munic\00EDpios')
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2102002977963900996
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT',
'    ano_competencia,',
'    cod_municipio,',
'    nome_municipio,',
'    uf,',
'    ano_populacao,',
'    populacao_referencia,',
'    populacao_2024,',
'    total_internacoes,',
'    valor_total,',
'    permanencia_media,',
'    total_obitos,',
'    internacoes_100_mil',
'FROM vw_municipio_indicadores',
'WHERE ano_competencia = :P2_ANO'))
,p_plug_source_type=>'NATIVE_IR'
,p_ajax_items_to_submit=>'P2_ANO'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'INCHES'
,p_prn_paper_size=>'LETTER'
,p_prn_width=>11
,p_prn_height=>8.5
,p_prn_orientation=>'HORIZONTAL'
,p_prn_page_header_font_color=>'#000000'
,p_prn_page_header_font_family=>'Helvetica'
,p_prn_page_header_font_weight=>'normal'
,p_prn_page_header_font_size=>'12'
,p_prn_page_footer_font_color=>'#000000'
,p_prn_page_footer_font_family=>'Helvetica'
,p_prn_page_footer_font_weight=>'normal'
,p_prn_page_footer_font_size=>'12'
,p_prn_header_bg_color=>'#EEEEEE'
,p_prn_header_font_color=>'#000000'
,p_prn_header_font_family=>'Helvetica'
,p_prn_header_font_weight=>'bold'
,p_prn_header_font_size=>'10'
,p_prn_body_bg_color=>'#FFFFFF'
,p_prn_body_font_color=>'#000000'
,p_prn_body_font_family=>'Helvetica'
,p_prn_body_font_weight=>'normal'
,p_prn_body_font_size=>'10'
,p_prn_border_width=>.5
,p_prn_page_header_alignment=>'CENTER'
,p_prn_page_footer_alignment=>'CENTER'
,p_prn_border_color=>'#666666'
,p_ai_enabled=>false
,p_created_on=>wwv_flow_imp.dz('20260909155330Z')
,p_updated_on=>wwv_flow_imp.dz('20260911151444Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(9388800290362885)
,p_max_row_count_message=>'The maximum row count for this report is #MAX_ROW_COUNT# rows.  Please apply a filter to reduce the number of records in your query.'
,p_no_data_found_message=>'No data found.'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_internal_uid=>9388800290362885
,p_created_on=>wwv_flow_imp.dz('20260909155330Z')
,p_updated_on=>wwv_flow_imp.dz('20260911142934Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(10549621357046401)
,p_db_column_name=>'ANO_COMPETENCIA'
,p_display_order=>18
,p_column_identifier=>'I'
,p_column_label=>unistr('Ano das interna\00E7\00F5es')
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260911141532Z')
,p_updated_on=>wwv_flow_imp.dz('20260911142324Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(10549821942046403)
,p_db_column_name=>'ANO_POPULACAO'
,p_display_order=>38
,p_column_identifier=>'K'
,p_column_label=>unistr('Ano da popula\00E7\00E3o')
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260911141532Z')
,p_updated_on=>wwv_flow_imp.dz('20260911141648Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(9390097885363151)
,p_db_column_name=>'COD_MUNICIPIO'
,p_display_order=>1
,p_column_identifier=>'A'
,p_column_label=>'Cod Municipio'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260909155330Z')
,p_updated_on=>wwv_flow_imp.dz('20260909155330Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(9392899715363169)
,p_db_column_name=>'INTERNACOES_100_MIL'
,p_display_order=>8
,p_column_identifier=>'H'
,p_column_label=>'Internacoes 100 Mil'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260909155330Z')
,p_updated_on=>wwv_flow_imp.dz('20260909155330Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(9390479095363159)
,p_db_column_name=>'NOME_MUNICIPIO'
,p_display_order=>2
,p_column_identifier=>'B'
,p_column_label=>'Nome Municipio'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260909155330Z')
,p_updated_on=>wwv_flow_imp.dz('20260909155330Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(9392004471363166)
,p_db_column_name=>'PERMANENCIA_MEDIA'
,p_display_order=>6
,p_column_identifier=>'F'
,p_column_label=>'Permanencia Media'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260909155330Z')
,p_updated_on=>wwv_flow_imp.dz('20260909155330Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(9390822933363162)
,p_db_column_name=>'POPULACAO_2024'
,p_display_order=>3
,p_column_identifier=>'C'
,p_column_label=>unistr('Popula\00E7\00E3o de refer\00EAncia')
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260909155330Z')
,p_updated_on=>wwv_flow_imp.dz('20260911141330Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(10549953886046404)
,p_db_column_name=>'POPULACAO_REFERENCIA'
,p_display_order=>48
,p_column_identifier=>'L'
,p_column_label=>'Populacao Referencia'
,p_column_type=>'NUMBER'
,p_display_text_as=>'HIDDEN_ESCAPE_SC'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260911141532Z')
,p_updated_on=>wwv_flow_imp.dz('20260911141925Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(9391203160363163)
,p_db_column_name=>'TOTAL_INTERNACOES'
,p_display_order=>4
,p_column_identifier=>'D'
,p_column_label=>'Total Internacoes'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260909155330Z')
,p_updated_on=>wwv_flow_imp.dz('20260909155330Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(9392480735363168)
,p_db_column_name=>'TOTAL_OBITOS'
,p_display_order=>7
,p_column_identifier=>'G'
,p_column_label=>'Total Obitos'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260909155330Z')
,p_updated_on=>wwv_flow_imp.dz('20260909155330Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(10549739141046402)
,p_db_column_name=>'UF'
,p_display_order=>28
,p_column_identifier=>'J'
,p_column_label=>'Uf'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260911141532Z')
,p_updated_on=>wwv_flow_imp.dz('20260911141532Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(9391610436363165)
,p_db_column_name=>'VALOR_TOTAL'
,p_display_order=>5
,p_column_identifier=>'E'
,p_column_label=>'Valor Total'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
,p_available_clientside=>'N'
,p_created_on=>wwv_flow_imp.dz('20260909155330Z')
,p_updated_on=>wwv_flow_imp.dz('20260909155330Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(9393229336363967)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'primary'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'COD_MUNICIPIO:NOME_MUNICIPIO:POPULACAO_2024:TOTAL_INTERNACOES:VALOR_TOTAL:PERMANENCIA_MEDIA:TOTAL_OBITOS:INTERNACOES_100_MIL:ANO_COMPETENCIA:ANO_POPULACAO:UF'
,p_created_on=>wwv_flow_imp.dz('20260909155338Z')
,p_updated_on=>wwv_flow_imp.dz('20260911142934Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(10550058437046405)
,p_plug_name=>unistr('Per\00EDodo analisado')
,p_static_id=>unistr('per\00EDodo-analisado')
,p_title=>unistr('Per\00EDodo analisado')
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_plug_template=>4073835273271169698
,p_plug_display_sequence=>10
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
,p_created_on=>wwv_flow_imp.dz('20260911150508Z')
,p_updated_on=>wwv_flow_imp.dz('20260911150508Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(10550164741046406)
,p_name=>'P2_ANO'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(10550058437046405)
,p_item_default=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT MAX(ano_competencia)',
'FROM vw_municipio_indicadores'))
,p_item_default_type=>'SQL_QUERY'
,p_prompt=>'Ano analisado'
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT DISTINCT',
'       ano_competencia AS display_value,',
'       ano_competencia AS return_value',
'FROM vw_municipio_indicadores',
'ORDER BY ano_competencia DESC'))
,p_cHeight=>1
,p_field_template=>1610598304472262251
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'YES'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
,p_created_on=>wwv_flow_imp.dz('20260911150917Z')
,p_updated_on=>wwv_flow_imp.dz('20260911151009Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(10550262384046407)
,p_name=>unistr('Atualizar munic\00EDpios por ano')
,p_static_id=>unistr('atualizar-munic\00EDpios-por-ano')
,p_event_sequence=>10
,p_triggering_element_type=>'ITEM'
,p_triggering_element=>'P2_ANO'
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'change'
,p_created_on=>wwv_flow_imp.dz('20260911151356Z')
,p_updated_on=>wwv_flow_imp.dz('20260911151356Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(10550309283046408)
,p_event_id=>wwv_flow_imp.id(10550262384046407)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_static_id=>'native-refresh'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(9388709517362885)
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'maintain_pagination', 'N')).to_clob
,p_created_on=>wwv_flow_imp.dz('20260911151356Z')
,p_updated_on=>wwv_flow_imp.dz('20260911151356Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp.component_end;
end;
/
