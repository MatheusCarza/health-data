prompt --application/pages/page_10010
begin
--   Manifest
--     PAGE: 10010
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
 p_id=>10010
,p_name=>'About'
,p_alias=>'ABOUT'
,p_step_title=>'About'
,p_warn_on_unsaved_changes=>'N'
,p_first_item=>'AUTO_FIRST_ITEM'
,p_autocomplete_on_off=>'OFF'
,p_group_id=>wwv_flow_imp.id(9362554173169319)
,p_step_template=>4073832297226169690
,p_page_template_options=>'#DEFAULT#'
,p_required_patch=>wwv_flow_imp.id(9361695780169311)
,p_protection_level=>'C'
,p_help_text=>'All application help text can be accessed from this page. The links in the "Documentation" region give a much more in-depth explanation of the application''s features and functionality.'
,p_page_component_map=>'11'
,p_created_on=>wwv_flow_imp.dz('20260909152113Z')
,p_last_updated_on=>wwv_flow_imp.dz('20260909152113Z')
,p_created_by=>'MATHEUS'
,p_last_updated_by=>'MATHEUS'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(9372255128169408)
,p_plug_name=>'About Page'
,p_static_id=>'about-page'
,p_region_template_options=>'#DEFAULT#:t-ContentBlock--padded:t-ContentBlock--h1:t-ContentBlock--lightBG'
,p_escape_on_http_output=>'Y'
,p_plug_template=>2323592004483952560
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>'Text about this application can be placed here.'
,p_plug_query_num_rows=>15
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
,p_created_on=>wwv_flow_imp.dz('20260909152113Z')
,p_updated_on=>wwv_flow_imp.dz('20260909152113Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp.component_end;
end;
/
