prompt --application/shared_components/navigation/lists/navigation_menu
begin
--   Manifest
--     LIST: Navigation Menu
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.4'
,p_default_workspace_id=>9348757358068450
,p_default_application_id=>100
,p_default_id_offset=>0
,p_default_owner=>'WKSP_HEALTHDATA'
);
wwv_flow_imp_shared.create_list(
 p_id=>wwv_flow_imp.id(9357708166169178)
,p_name=>'Navigation Menu'
,p_static_id=>'navigation-menu'
,p_version_scn=>'SH256:6fmJbmbLPaPe5N_dnEvGDPQzPft6tF_6VJTHny7cajc'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(9405987616458040)
,p_list_item_display_sequence=>50
,p_list_item_link_text=>'Assistente IA'
,p_static_id=>'assistente-ia'
,p_list_item_link_target=>'f?p=&APP_ID.:5:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-comments-o'
,p_list_item_current_type=>'COLON_DELIMITED_PAGE_LIST'
,p_list_item_current_for_pages=>'5'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(9393912879395890)
,p_list_item_display_sequence=>30
,p_list_item_link_text=>'Estabelecimentos'
,p_static_id=>'estabelecimentos'
,p_list_item_link_target=>'f?p=&APP_ID.:3:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-hospital-o'
,p_list_item_current_type=>'COLON_DELIMITED_PAGE_LIST'
,p_list_item_current_for_pages=>'3'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(9369219896169369)
,p_list_item_display_sequence=>10
,p_list_item_link_text=>'Home'
,p_static_id=>'home'
,p_list_item_link_target=>'f?p=&APP_ID.:1:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-home'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(9387548850362739)
,p_list_item_display_sequence=>20
,p_list_item_link_text=>unistr('Munic\00EDpios')
,p_static_id=>unistr('munic\00EDpios')
,p_list_item_link_target=>'f?p=&APP_ID.:2:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-map-marker'
,p_list_item_current_type=>'COLON_DELIMITED_PAGE_LIST'
,p_list_item_current_for_pages=>'2'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(9400314940432250)
,p_list_item_display_sequence=>40
,p_list_item_link_text=>'Tipos de atendimento'
,p_static_id=>'tipos-de-atendimento'
,p_list_item_link_target=>'f?p=&APP_ID.:4:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-stethoscope'
,p_list_item_current_type=>'COLON_DELIMITED_PAGE_LIST'
,p_list_item_current_for_pages=>'4'
);
wwv_flow_imp.component_end;
end;
/
