prompt --application/shared_components/logic/build_options
begin
--   Manifest
--     BUILD OPTIONS: 100
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.4'
,p_default_workspace_id=>9348757358068450
,p_default_application_id=>100
,p_default_id_offset=>0
,p_default_owner=>'WKSP_HEALTHDATA'
);
wwv_flow_imp_shared.create_build_option(
 p_id=>wwv_flow_imp.id(9356549550169150)
,p_build_option_name=>'Commented Out'
,p_static_id=>'commented-out'
,p_build_option_status=>'EXCLUDE'
,p_version_scn=>'SH256:1lQI3DW9n-0ZEGoDXUirkaB0JWCIATVWpJZCTCkODmI'
,p_created_on=>wwv_flow_imp.dz('20260909152110Z')
,p_updated_on=>wwv_flow_imp.dz('20260909152110Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp_shared.create_build_option(
 p_id=>wwv_flow_imp.id(9361695780169311)
,p_build_option_name=>'Feature: About Page'
,p_static_id=>'feature-about-page'
,p_build_option_status=>'INCLUDE'
,p_version_scn=>'SH256:XJT0LyDPwECBH8IlgFn2KNvjd0rsRDXoOWkE0Llo7dI'
,p_feature_identifier=>'APPLICATION_ABOUT_PAGE'
,p_build_option_comment=>'About this application page.'
,p_created_on=>wwv_flow_imp.dz('20260909152112Z')
,p_updated_on=>wwv_flow_imp.dz('20260909152112Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp.component_end;
end;
/
