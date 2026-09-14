prompt --application/shared_components/security/authentications/acesso_público
begin
--   Manifest
--     AUTHENTICATION: Acesso público
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.4'
,p_default_workspace_id=>9348757358068450
,p_default_application_id=>100
,p_default_id_offset=>0
,p_default_owner=>'WKSP_HEALTHDATA'
);
wwv_flow_imp_shared.create_authentication(
 p_id=>wwv_flow_imp.id(11349905431712557)
,p_name=>unistr('Acesso p\00FAblico')
,p_static_id=>unistr('acesso-p\00FAblico')
,p_scheme_type=>'NATIVE_DAD'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'username', 'nobody')).to_clob
,p_use_secure_cookie_yn=>'N'
,p_ras_mode=>0
,p_version_scn=>'SH256:TVE1not1inJWFIIDoispREqxdti5QhosJjZ-Vy9mOd0'
,p_created_on=>wwv_flow_imp.dz('20260913233824Z')
,p_updated_on=>wwv_flow_imp.dz('20260913233840Z')
,p_created_by=>'MATHEUS'
,p_updated_by=>'MATHEUS'
);
wwv_flow_imp.component_end;
end;
/
