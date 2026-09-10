prompt --application/pages/page_00001
begin
--   Manifest
--     PAGE: 00001
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
 p_id=>1
,p_name=>'Home'
,p_alias=>'HOME'
,p_step_title=>'Health Data'
,p_autocomplete_on_off=>'OFF'
,p_step_template=>4073832297226169690
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'13'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(10154191161401112)
,p_plug_name=>unistr('Concentra\00E7\00E3o geogr\00E1fica das interna\00E7\00F5es')
,p_static_id=>unistr('concentra\00E7\00E3o-geogr\00E1fica-das-interna\00E7\00F5es')
,p_title=>unistr('Concentra\00E7\00E3o geogr\00E1fica das interna\00E7\00F5es no per\00EDodo selecionado')
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_plug_template=>4073835273271169698
,p_plug_display_sequence=>50
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT',
'    e.codigo_cnes,',
'    e.nome_fantasia,',
'    m.nome_municipio,',
'    e.latitude,',
'    e.longitude,',
'    COUNT(*) AS total_internacoes,',
'    ROUND(SUM(f.valor_total), 2) AS valor_total,',
'    SUM(',
'        CASE',
'            WHEN f.indicador_obito = 1 THEN 1',
'            ELSE 0',
'        END',
'    ) AS total_obitos,',
unistr('    e.nome_fantasia || '' \2014 '' ||'),
unistr('        NVL(m.nome_municipio, ''Munic\00EDpio n\00E3o informado'') || '': '' ||'),
'        TO_CHAR(',
'            COUNT(*),',
'            ''FM999G999G990'',',
'            ''NLS_NUMERIC_CHARACTERS='''',.''''''',
unistr('        ) || '' interna\00E7\00F5es'' AS tooltip'),
'FROM admin.fato_internacao f',
'JOIN admin.dim_estabelecimento e',
'    ON e.codigo_cnes = f.codigo_cnes',
'LEFT JOIN admin.dim_municipio m',
'    ON m.cod_municipio = e.cod_municipio',
'WHERE e.latitude BETWEEN -90 AND 90',
'  AND e.longitude BETWEEN -180 AND 180',
'  AND f.ano_competencia * 100 + f.mes_competencia',
'      BETWEEN TO_NUMBER(:P1_COMPETENCIA_INICIO)',
'          AND TO_NUMBER(:P1_COMPETENCIA_FIM)',
'GROUP BY',
'    e.codigo_cnes,',
'    e.nome_fantasia,',
'    m.nome_municipio,',
'    e.latitude,',
'    e.longitude'))
,p_lazy_loading=>true
,p_plug_source_type=>'NATIVE_MAP_REGION'
);
wwv_flow_imp_page.create_map_region(
 p_id=>wwv_flow_imp.id(10154277752401113)
,p_region_id=>wwv_flow_imp.id(10154191161401112)
,p_height=>640
,p_navigation_bar_type=>'FULL'
,p_navigation_bar_position=>'END'
,p_init_position_zoom_type=>'QUERY_RESULTS'
,p_layer_messages_position=>'BELOW'
,p_legend_position=>'END'
,p_features=>'SCALE_BAR:INFINITE_MAP:RECTANGLE_ZOOM'
);
wwv_flow_imp_page.create_map_region_layer(
 p_id=>wwv_flow_imp.id(10154444118401115)
,p_map_region_id=>wwv_flow_imp.id(10154277752401113)
,p_name=>'Detalhes dos estabelecimentos'
,p_static_id=>'detalhes-dos-estabelecimentos'
,p_layer_type=>'POINT'
,p_display_sequence=>20
,p_location=>'REGION_SOURCE'
,p_has_spatial_index=>false
,p_pk_column=>'CODIGO_CNES'
,p_geometry_column_data_type=>'LONLAT_COLUMNS'
,p_longitude_column=>'LONGITUDE'
,p_latitude_column=>'LATITUDE'
,p_point_display_type=>'SVG'
,p_point_svg_shape=>'Default'
,p_feature_clustering=>false
,p_tooltip_adv_formatting=>true
,p_tooltip_html_expr=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<strong>&NOME_FANTASIA!HTML.</strong><br>',
'&NOME_MUNICIPIO!HTML.<br>',
unistr('<strong>&TOTAL_INTERNACOES.</strong> interna\00E7\00F5es')))
,p_info_window_adv_formatting=>true
,p_info_window_html_expr=>wwv_flow_string.join(wwv_flow_t_varchar2(
'<strong>&NOME_FANTASIA!HTML.</strong><br>',
unistr('Munic\00EDpio: &NOME_MUNICIPIO!HTML.<br>'),
unistr('Interna\00E7\00F5es: &TOTAL_INTERNACOES.<br>'),
'Valor total: R$ &VALOR_TOTAL.<br>',
unistr('Interna\00E7\00F5es com \00F3bito: &TOTAL_OBITOS.')))
,p_legend_adv_formatting=>false
,p_allow_hide=>true
);
wwv_flow_imp_page.create_map_region_layer(
 p_id=>wwv_flow_imp.id(10154375848401114)
,p_map_region_id=>wwv_flow_imp.id(10154277752401113)
,p_name=>unistr('Interna\00E7\00F5es por estabelecimento')
,p_static_id=>unistr('interna\00E7\00F5es-por-estabelecimento')
,p_layer_type=>'HEATMAP'
,p_display_sequence=>10
,p_location=>'REGION_SOURCE'
,p_has_spatial_index=>false
,p_pk_column=>'CODIGO_CNES'
,p_geometry_column_data_type=>'LONLAT_COLUMNS'
,p_longitude_column=>'LONGITUDE'
,p_latitude_column=>'LATITUDE'
,p_fill_color_spectr_name=>'Burg'
,p_fill_color_spectr_type=>'SEQUENTIAL'
,p_fill_value_column=>'TOTAL_INTERNACOES'
,p_legend_adv_formatting=>false
,p_allow_hide=>true
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(10153031410401101)
,p_plug_name=>unistr('Distribui\00E7\00E3o por tipo de atendimento')
,p_static_id=>unistr('distribui\00E7\00E3o-por-tipo-de-atendimento')
,p_title=>unistr('Distribui\00E7\00E3o das interna\00E7\00F5es por tipo de atendimento no per\00EDodo selecionado')
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_escape_on_http_output=>'Y'
,p_plug_template=>4073835273271169698
,p_plug_display_sequence=>40
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source_type=>'NATIVE_JET_CHART'
);
wwv_flow_imp_page.create_jet_chart(
 p_id=>wwv_flow_imp.id(10153540397401106)
,p_region_id=>wwv_flow_imp.id(10153031410401101)
,p_chart_type=>'bar'
,p_height=>'400'
,p_animation_on_display=>'auto'
,p_animation_on_data_change=>'auto'
,p_orientation=>'horizontal'
,p_data_cursor=>'auto'
,p_data_cursor_behavior=>'auto'
,p_hide_and_show_behavior=>'withRescale'
,p_hover_behavior=>'dim'
,p_stack=>'off'
,p_connect_nulls=>'Y'
,p_sorting=>'label-asc'
,p_fill_multi_series_gaps=>true
,p_zoom_and_scroll=>'off'
,p_tooltip_rendered=>'Y'
,p_show_series_name=>true
,p_show_group_name=>true
,p_show_value=>true
,p_legend_rendered=>'on'
,p_legend_position=>'auto'
);
wwv_flow_imp_page.create_jet_chart_series(
 p_id=>wwv_flow_imp.id(10153673769401107)
,p_chart_id=>wwv_flow_imp.id(10153540397401106)
,p_static_id=>unistr('interna\00E7\00F5es')
,p_seq=>10
,p_name=>'&P1_ROTULO_PERIODO_ATUAL!RAW.'
,p_data_source_type=>'SQL'
,p_data_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'WITH limites AS (',
'    SELECT',
'        NVL(',
'            TO_NUMBER(:P1_COMPETENCIA_INICIO),',
'            TO_NUMBER(',
'                TO_CHAR(',
'                    ADD_MONTHS(',
'                        TO_DATE(TO_CHAR(MAX(competencia)), ''YYYYMM''),',
'                        -2',
'                    ),',
'                    ''YYYYMM''',
'                )',
'            )',
'        ) AS competencia_inicio,',
'        NVL(',
'            TO_NUMBER(:P1_COMPETENCIA_FIM),',
'            MAX(competencia)',
'        ) AS competencia_fim',
'    FROM vw_escopo_dados',
'),',
'periodos AS (',
'    SELECT',
'        competencia_inicio,',
'        competencia_fim,',
'        TO_NUMBER(',
'            TO_CHAR(',
'                ADD_MONTHS(',
'                    TO_DATE(TO_CHAR(competencia_inicio), ''YYYYMM''),',
'                    -(',
'                        MONTHS_BETWEEN(',
'                            TO_DATE(TO_CHAR(competencia_fim), ''YYYYMM''),',
'                            TO_DATE(TO_CHAR(competencia_inicio), ''YYYYMM'')',
'                        ) + 1',
'                    )',
'                ),',
'                ''YYYYMM''',
'            )',
'        ) AS competencia_anterior_inicio,',
'        TO_NUMBER(',
'            TO_CHAR(',
'                ADD_MONTHS(',
'                    TO_DATE(TO_CHAR(competencia_inicio), ''YYYYMM''),',
'                    -1',
'                ),',
'                ''YYYYMM''',
'            )',
'        ) AS competencia_anterior_fim',
'    FROM limites',
'),',
'dados AS (',
'    SELECT',
unistr('        NVL(t.descricao, ''N\00E3o informado'') AS tipo_atendimento,'),
'',
'        SUM(',
'            CASE',
'                WHEN f.ano_competencia * 100 + f.mes_competencia',
'                     BETWEEN p.competencia_inicio',
'                         AND p.competencia_fim',
'                THEN 1',
'                ELSE 0',
'            END',
'        ) AS total_atual,',
'',
'        SUM(',
'            CASE',
'                WHEN f.ano_competencia * 100 + f.mes_competencia',
'                     BETWEEN p.competencia_anterior_inicio',
'                         AND p.competencia_anterior_fim',
'                THEN 1',
'                ELSE 0',
'            END',
'        ) AS total_anterior',
'',
'    FROM admin.fato_internacao f',
'    JOIN admin.dim_tipo_atendimento t',
'        ON t.codigo_especialidade = f.codigo_especialidade',
'    CROSS JOIN periodos p',
'',
'    WHERE f.ano_competencia * 100 + f.mes_competencia',
'          BETWEEN p.competencia_anterior_inicio',
'              AND p.competencia_fim',
'',
unistr('    GROUP BY NVL(t.descricao, ''N\00E3o informado'')'),
'),',
'ranking AS (',
'    SELECT',
'        tipo_atendimento,',
'        total_atual,',
'        total_anterior,',
'        ROW_NUMBER() OVER (',
'            ORDER BY',
'                total_atual DESC,',
'                tipo_atendimento',
'        ) AS posicao',
'    FROM dados',
'),',
'agrupados AS (',
'    SELECT',
'        CASE',
'            WHEN posicao <= 5 THEN tipo_atendimento',
'            ELSE ''Outros''',
'        END AS tipo_atendimento,',
'',
'        CASE',
'            WHEN posicao <= 5 THEN posicao',
'            ELSE 6',
'        END AS ordem,',
'',
'        SUM(total_atual) AS total_atual,',
'        SUM(total_anterior) AS total_anterior',
'',
'    FROM ranking',
'',
'    GROUP BY',
'        CASE',
'            WHEN posicao <= 5 THEN tipo_atendimento',
'            ELSE ''Outros''',
'        END,',
'        CASE',
'            WHEN posicao <= 5 THEN posicao',
'            ELSE 6',
'        END',
')',
'SELECT',
'    TO_CHAR(ordem, ''FM00'')',
'        || ''. ''',
'        || tipo_atendimento AS tipo_atendimento,',
'    total_atual AS total_internacoes',
'FROM agrupados',
'WHERE total_atual > 0',
'ORDER BY ordem'))
,p_items_value_column_name=>'TOTAL_INTERNACOES'
,p_items_label_column_name=>'TIPO_ATENDIMENTO'
,p_assigned_to_y2=>'off'
,p_items_label_rendered=>true
,p_items_label_position=>'insideBarEdge'
);
wwv_flow_imp_page.create_jet_chart_series(
 p_id=>wwv_flow_imp.id(10155287914401123)
,p_chart_id=>wwv_flow_imp.id(10153540397401106)
,p_static_id=>unistr('per\00EDodo-anterior')
,p_seq=>20
,p_name=>'&P1_ROTULO_PERIODO_ANTERIOR!RAW.'
,p_data_source_type=>'SQL'
,p_data_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'WITH limites AS (',
'    SELECT',
'        NVL(',
'            TO_NUMBER(:P1_COMPETENCIA_INICIO),',
'            TO_NUMBER(',
'                TO_CHAR(',
'                    ADD_MONTHS(',
'                        TO_DATE(TO_CHAR(MAX(competencia)), ''YYYYMM''),',
'                        -2',
'                    ),',
'                    ''YYYYMM''',
'                )',
'            )',
'        ) AS competencia_inicio,',
'        NVL(',
'            TO_NUMBER(:P1_COMPETENCIA_FIM),',
'            MAX(competencia)',
'        ) AS competencia_fim',
'    FROM vw_escopo_dados',
'),',
'periodos AS (',
'    SELECT',
'        competencia_inicio,',
'        competencia_fim,',
'        TO_NUMBER(',
'            TO_CHAR(',
'                ADD_MONTHS(',
'                    TO_DATE(TO_CHAR(competencia_inicio), ''YYYYMM''),',
'                    -(',
'                        MONTHS_BETWEEN(',
'                            TO_DATE(TO_CHAR(competencia_fim), ''YYYYMM''),',
'                            TO_DATE(TO_CHAR(competencia_inicio), ''YYYYMM'')',
'                        ) + 1',
'                    )',
'                ),',
'                ''YYYYMM''',
'            )',
'        ) AS competencia_anterior_inicio,',
'        TO_NUMBER(',
'            TO_CHAR(',
'                ADD_MONTHS(',
'                    TO_DATE(TO_CHAR(competencia_inicio), ''YYYYMM''),',
'                    -1',
'                ),',
'                ''YYYYMM''',
'            )',
'        ) AS competencia_anterior_fim',
'    FROM limites',
'),',
'dados AS (',
'    SELECT',
unistr('        NVL(t.descricao, ''N\00E3o informado'') AS tipo_atendimento,'),
'',
'        SUM(',
'            CASE',
'                WHEN f.ano_competencia * 100 + f.mes_competencia',
'                     BETWEEN p.competencia_inicio',
'                         AND p.competencia_fim',
'                THEN 1',
'                ELSE 0',
'            END',
'        ) AS total_atual,',
'',
'        SUM(',
'            CASE',
'                WHEN f.ano_competencia * 100 + f.mes_competencia',
'                     BETWEEN p.competencia_anterior_inicio',
'                         AND p.competencia_anterior_fim',
'                THEN 1',
'                ELSE 0',
'            END',
'        ) AS total_anterior',
'',
'    FROM admin.fato_internacao f',
'    JOIN admin.dim_tipo_atendimento t',
'        ON t.codigo_especialidade = f.codigo_especialidade',
'    CROSS JOIN periodos p',
'',
'    WHERE f.ano_competencia * 100 + f.mes_competencia',
'          BETWEEN p.competencia_anterior_inicio',
'              AND p.competencia_fim',
'',
unistr('    GROUP BY NVL(t.descricao, ''N\00E3o informado'')'),
'),',
'ranking AS (',
'    SELECT',
'        tipo_atendimento,',
'        total_atual,',
'        total_anterior,',
'        ROW_NUMBER() OVER (',
'            ORDER BY',
'                total_atual DESC,',
'                tipo_atendimento',
'        ) AS posicao',
'    FROM dados',
'),',
'agrupados AS (',
'    SELECT',
'        CASE',
'            WHEN posicao <= 5 THEN tipo_atendimento',
'            ELSE ''Outros''',
'        END AS tipo_atendimento,',
'',
'        CASE',
'            WHEN posicao <= 5 THEN posicao',
'            ELSE 6',
'        END AS ordem,',
'',
'        SUM(total_atual) AS total_atual,',
'        SUM(total_anterior) AS total_anterior',
'',
'    FROM ranking',
'',
'    GROUP BY',
'        CASE',
'            WHEN posicao <= 5 THEN tipo_atendimento',
'            ELSE ''Outros''',
'        END,',
'        CASE',
'            WHEN posicao <= 5 THEN posicao',
'            ELSE 6',
'        END',
')',
'SELECT',
'    TO_CHAR(ordem, ''FM00'')',
'        || ''. ''',
'        || tipo_atendimento AS tipo_atendimento,',
'    total_anterior AS total_internacoes',
'FROM agrupados',
'WHERE total_atual > 0',
'ORDER BY ordem'))
,p_items_value_column_name=>'TOTAL_INTERNACOES'
,p_items_label_column_name=>'TIPO_ATENDIMENTO'
,p_assigned_to_y2=>'off'
,p_items_label_rendered=>true
,p_items_label_position=>'insideBarEdge'
);
wwv_flow_imp_page.create_jet_chart_axis(
 p_id=>wwv_flow_imp.id(10155047859401121)
,p_chart_id=>wwv_flow_imp.id(10153540397401106)
,p_static_id=>'x'
,p_axis=>'x'
,p_is_rendered=>'on'
,p_format_scaling=>'auto'
,p_scaling=>'linear'
,p_baseline_scaling=>'zero'
,p_major_tick_rendered=>'on'
,p_minor_tick_rendered=>'auto'
,p_tick_label_rendered=>'on'
,p_tick_label_rotation=>'auto'
,p_tick_label_position=>'outside'
);
wwv_flow_imp_page.create_jet_chart_axis(
 p_id=>wwv_flow_imp.id(10155191295401122)
,p_chart_id=>wwv_flow_imp.id(10153540397401106)
,p_static_id=>'y'
,p_axis=>'y'
,p_is_rendered=>'on'
,p_format_type=>'decimal'
,p_decimal_places=>0
,p_format_scaling=>'none'
,p_scaling=>'linear'
,p_baseline_scaling=>'zero'
,p_position=>'auto'
,p_major_tick_rendered=>'on'
,p_minor_tick_rendered=>'auto'
,p_tick_label_rendered=>'on'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(10153926858401110)
,p_plug_name=>'Escopo de dados'
,p_static_id=>'escopo-de-dados_1'
,p_title=>'Escopo de dados'
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_plug_template=>4073835273271169698
,p_plug_display_sequence=>60
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source=>'&P1_TEXTO_ESCOPO.'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(9370168580169377)
,p_plug_name=>'Health Data'
,p_static_id=>'health-data'
,p_region_template_options=>'#DEFAULT#'
,p_escape_on_http_output=>'Y'
,p_plug_template=>2675494171183407654
,p_plug_display_sequence=>10
,p_plug_display_point=>'REGION_POSITION_01'
,p_plug_item_display_point=>'ABOVE'
,p_plug_query_num_rows=>15
,p_region_image=>'#APP_FILES#icons/app-icon-512.png'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(9378366965218603)
,p_plug_name=>'Indicadores principais'
,p_static_id=>'indicadores-principais'
,p_title=>unistr('Indicadores do per\00EDodo selecionado')
,p_region_template_options=>'#DEFAULT#:t-CardsRegion--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2074200852440250129
,p_plug_display_sequence=>20
,p_plug_item_display_point=>'ABOVE'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'WITH periodo_disponivel AS (',
'    SELECT',
'        MAX(',
'            ano_competencia * 100 +',
'            mes_competencia',
'        ) AS competencia_maxima',
'    FROM admin.fato_internacao',
'),',
'periodo_selecionado AS (',
'    SELECT',
'        NVL(',
'            TO_NUMBER(:P1_COMPETENCIA_INICIO),',
'            TO_NUMBER(',
'                TO_CHAR(',
'                    ADD_MONTHS(',
'                        TO_DATE(',
'                            TO_CHAR(competencia_maxima),',
'                            ''YYYYMM''',
'                        ),',
'                        -2',
'                    ),',
'                    ''YYYYMM''',
'                )',
'            )',
'        ) AS competencia_inicio,',
'        NVL(',
'            TO_NUMBER(:P1_COMPETENCIA_FIM),',
'            competencia_maxima',
'        ) AS competencia_fim',
'    FROM periodo_disponivel',
'),',
'limites_calculados AS (',
'    SELECT',
'        competencia_inicio,',
'        competencia_fim,',
'        TO_NUMBER(',
'            TO_CHAR(',
'                ADD_MONTHS(',
'                    TO_DATE(',
'                        TO_CHAR(competencia_inicio),',
'                        ''YYYYMM''',
'                    ),',
'                    -(',
'                        MONTHS_BETWEEN(',
'                            TO_DATE(',
'                                TO_CHAR(competencia_fim),',
'                                ''YYYYMM''',
'                            ),',
'                            TO_DATE(',
'                                TO_CHAR(competencia_inicio),',
'                                ''YYYYMM''',
'                            )',
'                        ) + 1',
'                    )',
'                ),',
'                ''YYYYMM''',
'            )',
'        ) AS anterior_inicio,',
'        TO_NUMBER(',
'            TO_CHAR(',
'                ADD_MONTHS(',
'                    TO_DATE(',
'                        TO_CHAR(competencia_inicio),',
'                        ''YYYYMM''',
'                    ),',
'                    -1',
'                ),',
'                ''YYYYMM''',
'            )',
'        ) AS anterior_fim',
'    FROM periodo_selecionado',
'),',
'limites AS (',
'    SELECT',
'        l.*,',
'        TO_CHAR(',
'            TO_DATE(',
'                TO_CHAR(l.anterior_inicio),',
'                ''YYYYMM''',
'            ),',
'            ''MM/YYYY''',
'        ) ||',
unistr('        ''\2013'' ||'),
'        TO_CHAR(',
'            TO_DATE(',
'                TO_CHAR(l.anterior_fim),',
'                ''YYYYMM''',
'            ),',
'            ''MM/YYYY''',
'        ) AS periodo_anterior',
'    FROM limites_calculados l',
'),',
'atual AS (',
'    SELECT',
'        COUNT(*) AS total_internacoes,',
'        COUNT(',
'            DISTINCT f.codigo_cnes',
'        ) AS total_estabelecimentos,',
'        NVL(SUM(f.valor_total), 0) AS valor_total,',
'        NVL(AVG(f.dias_permanencia), 0) AS permanencia_media,',
'        NVL(',
'            SUM(',
'                CASE',
'                    WHEN f.indicador_obito = 1 THEN 1',
'                    ELSE 0',
'                END',
'            ),',
'            0',
'        ) AS total_obitos,',
'        NVL(',
'            100 * AVG(',
'                CASE',
'                    WHEN f.indicador_obito = 1 THEN 1',
'                    ELSE 0',
'                END',
'            ),',
'            0',
'        ) AS taxa_obito_pct',
'    FROM admin.fato_internacao f',
'    CROSS JOIN limites l',
'    WHERE f.ano_competencia * 100 + f.mes_competencia',
'          BETWEEN l.competencia_inicio',
'              AND l.competencia_fim',
'),',
'anterior AS (',
'    SELECT',
'        COUNT(*) AS total_internacoes,',
'        COUNT(',
'            DISTINCT f.codigo_cnes',
'        ) AS total_estabelecimentos,',
'        NVL(SUM(f.valor_total), 0) AS valor_total,',
'        NVL(AVG(f.dias_permanencia), 0) AS permanencia_media,',
'        NVL(',
'            SUM(',
'                CASE',
'                    WHEN f.indicador_obito = 1 THEN 1',
'                    ELSE 0',
'                END',
'            ),',
'            0',
'        ) AS total_obitos,',
'        NVL(',
'            100 * AVG(',
'                CASE',
'                    WHEN f.indicador_obito = 1 THEN 1',
'                    ELSE 0',
'                END',
'            ),',
'            0',
'        ) AS taxa_obito_pct',
'    FROM admin.fato_internacao f',
'    CROSS JOIN limites l',
'    WHERE f.ano_competencia * 100 + f.mes_competencia',
'          BETWEEN l.anterior_inicio',
'              AND l.anterior_fim',
'),',
'cards AS (',
'    SELECT',
'        1 AS ordem,',
unistr('        ''Interna\00E7\00F5es da amostra'' AS titulo,'),
'        TO_CHAR(',
'            a.total_internacoes,',
'            ''FM999G999G990'',',
'            ''NLS_NUMERIC_CHARACTERS='''',.''''''',
'        ) AS valor,',
unistr('        ''Registros de interna\00E7\00E3o analisados (n\00E3o pacientes \00FAnicos)'''),
'            AS descricao_base,',
'        ''fa-database'' AS icone,',
'        a.total_internacoes AS valor_atual,',
'        p.total_internacoes AS valor_anterior,',
'        ''PCT'' AS tipo_comparacao,',
'        CASE',
'            WHEN p.total_internacoes > 0 THEN 1',
'            ELSE 0',
'        END AS tem_anterior',
'    FROM atual a',
'    CROSS JOIN anterior p',
'',
'    UNION ALL',
'',
'    SELECT',
'        2,',
unistr('        ''Valor m\00E9dio por interna\00E7\00E3o'','),
'        ''R$ '' || TO_CHAR(',
'            NVL(',
'                a.valor_total /',
'                NULLIF(a.total_internacoes, 0),',
'                0',
'            ),',
'            ''FM999G999G990D00'',',
'            ''NLS_NUMERIC_CHARACTERS='''',.''''''',
'        ),',
unistr('        ''Valor total dividido pelo n\00FAmero de interna\00E7\00F5es no per\00EDodo'','),
'        ''fa-calculator'',',
'        NVL(',
'            a.valor_total /',
'            NULLIF(a.total_internacoes, 0),',
'            0',
'        ),',
'        NVL(',
'            p.valor_total /',
'            NULLIF(p.total_internacoes, 0),',
'            0',
'        ),',
'        ''PCT'',',
'        CASE',
'            WHEN p.total_internacoes > 0 THEN 1',
'            ELSE 0',
'        END',
'    FROM atual a',
'    CROSS JOIN anterior p',
'',
'    UNION ALL',
'',
'    SELECT',
'        3,',
'        ''Estabelecimentos'',',
'        TO_CHAR(',
'            a.total_estabelecimentos,',
'            ''FM999G999G990'',',
'            ''NLS_NUMERIC_CHARACTERS='''',.''''''',
'        ),',
unistr('        ''Unidades com ao menos uma interna\00E7\00E3o no per\00EDodo'','),
'        ''fa-hospital-o'',',
'        a.total_estabelecimentos,',
'        p.total_estabelecimentos,',
'        ''PCT'',',
'        CASE',
'            WHEN p.total_internacoes > 0 THEN 1',
'            ELSE 0',
'        END',
'    FROM atual a',
'    CROSS JOIN anterior p',
'',
'    UNION ALL',
'',
'    SELECT',
'        4,',
'        ''Valor total'',',
'        ''R$ '' || TO_CHAR(',
'            a.valor_total,',
'            ''FM999G999G999G990D00'',',
'            ''NLS_NUMERIC_CHARACTERS='''',.''''''',
'        ),',
'        ''Soma do valor das '' ||',
'        TO_CHAR(',
'            a.total_internacoes,',
'            ''FM999G999G990'',',
'            ''NLS_NUMERIC_CHARACTERS='''',.''''''',
unistr('        ) || '' interna\00E7\00F5es analisadas'','),
'        ''fa-money'',',
'        a.valor_total,',
'        p.valor_total,',
'        ''PCT'',',
'        CASE',
'            WHEN p.total_internacoes > 0 THEN 1',
'            ELSE 0',
'        END',
'    FROM atual a',
'    CROSS JOIN anterior p',
'',
'    UNION ALL',
'',
'    SELECT',
'        5,',
unistr('        ''Perman\00EAncia m\00E9dia'','),
'        TO_CHAR(',
'            ROUND(a.permanencia_media, 1),',
'            ''FM990D0'',',
'            ''NLS_NUMERIC_CHARACTERS='''',.''''''',
'        ) || '' dias'',',
unistr('        ''M\00E9dia de dias de perman\00EAncia por interna\00E7\00E3o'','),
'        ''fa-clock-o'',',
'        a.permanencia_media,',
'        p.permanencia_media,',
'        ''PCT'',',
'        CASE',
'            WHEN p.total_internacoes > 0 THEN 1',
'            ELSE 0',
'        END',
'    FROM atual a',
'    CROSS JOIN anterior p',
'',
'    UNION ALL',
'',
'    SELECT',
'        6,',
unistr('        ''Interna\00E7\00F5es com \00F3bito'','),
'        TO_CHAR(',
'            a.total_obitos,',
'            ''FM999G999G990'',',
'            ''NLS_NUMERIC_CHARACTERS='''',.''''''',
'        ),',
'        TO_CHAR(',
'            ROUND(a.taxa_obito_pct, 2),',
'            ''FM990D00'',',
'            ''NLS_NUMERIC_CHARACTERS='''',.''''''',
'        ) || ''% de '' ||',
'        TO_CHAR(',
'            a.total_internacoes,',
'            ''FM999G999G990'',',
'            ''NLS_NUMERIC_CHARACTERS='''',.''''''',
unistr('        ) || '' interna\00E7\00F5es registraram \00F3bito'','),
'        ''fa-heartbeat'',',
'        a.taxa_obito_pct,',
'        p.taxa_obito_pct,',
'        ''PP'',',
'        CASE',
'            WHEN p.total_internacoes > 0 THEN 1',
'            ELSE 0',
'        END',
'    FROM atual a',
'    CROSS JOIN anterior p',
')',
'SELECT',
'    c.ordem,',
'    c.titulo,',
'    c.valor,',
'    c.descricao_base ||',
'    CASE',
'        WHEN c.tem_anterior = 0 THEN',
unistr('            '' \2022 Sem dados para compara\00E7\00E3o em '' ||'),
'            l.periodo_anterior',
'',
'        WHEN ROUND(c.valor_atual, 10) =',
'             ROUND(c.valor_anterior, 10) THEN',
unistr('            '' \2022 Sem varia\00E7\00E3o em rela\00E7\00E3o a '' ||'),
'            l.periodo_anterior',
'',
'        WHEN c.tipo_comparacao = ''PCT''',
'             AND c.valor_anterior = 0 THEN',
unistr('            '' \2022 Sem base compar\00E1vel em '' ||'),
'            l.periodo_anterior',
'',
'        WHEN c.tipo_comparacao = ''PCT'' THEN',
unistr('            '' \2022 '' ||'),
'            TO_CHAR(',
'                ABS(',
'                    100 *',
'                    (c.valor_atual - c.valor_anterior) /',
'                    c.valor_anterior',
'                ),',
'                ''FM990D0'',',
'                ''NLS_NUMERIC_CHARACTERS='''',.''''''',
'            ) || ''% '' ||',
'            CASE',
'                WHEN c.valor_atual > c.valor_anterior',
'                THEN ''acima''',
'                ELSE ''abaixo''',
'            END ||',
unistr('            '' em rela\00E7\00E3o a '' ||'),
'            l.periodo_anterior',
'',
'        ELSE',
unistr('            '' \2022 '' ||'),
'            TO_CHAR(',
'                ABS(c.valor_atual - c.valor_anterior),',
'                ''FM990D00'',',
'                ''NLS_NUMERIC_CHARACTERS='''',.''''''',
'            ) || '' p.p. '' ||',
'            CASE',
'                WHEN c.valor_atual > c.valor_anterior',
'                THEN ''acima''',
'                ELSE ''abaixo''',
'            END ||',
unistr('            '' em rela\00E7\00E3o a '' ||'),
'            l.periodo_anterior',
'    END AS descricao,',
'    c.icone',
'FROM cards c',
'CROSS JOIN limites l',
'ORDER BY c.ordem'))
,p_lazy_loading=>false
,p_plug_source_type=>'NATIVE_CARDS'
,p_plug_query_num_rows_type=>'SCROLL'
,p_show_total_row_count=>false
);
wwv_flow_imp_page.create_card(
 p_id=>wwv_flow_imp.id(9378458841218604)
,p_region_id=>wwv_flow_imp.id(9378366965218603)
,p_layout_type=>'GRID'
,p_grid_column_count=>3
,p_title_adv_formatting=>false
,p_title_column_name=>'TITULO'
,p_sub_title_adv_formatting=>false
,p_sub_title_column_name=>'VALOR'
,p_body_adv_formatting=>false
,p_body_column_name=>'DESCRICAO'
,p_second_body_adv_formatting=>false
,p_icon_source_type=>'DYNAMIC_CLASS'
,p_icon_class_column_name=>'ICONE'
,p_icon_position=>'START'
,p_media_adv_formatting=>false
,p_pk1_column_name=>'ORDEM'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(9378584927218605)
,p_plug_name=>unistr('Interna\00E7\00F5es por munic\00EDpio')
,p_static_id=>unistr('interna\00E7\00F5es-por-munic\00EDpio')
,p_title=>unistr('Top 10 munic\00EDpios por interna\00E7\00F5es no per\00EDodo selecionado')
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_escape_on_http_output=>'Y'
,p_plug_template=>4073835273271169698
,p_plug_display_sequence=>30
,p_plug_grid_column_span=>12
,p_plug_item_display_point=>'ABOVE'
,p_location=>null
,p_plug_source_type=>'NATIVE_JET_CHART'
);
wwv_flow_imp_page.create_jet_chart(
 p_id=>wwv_flow_imp.id(9378600964218606)
,p_region_id=>wwv_flow_imp.id(9378584927218605)
,p_chart_type=>'bar'
,p_height=>'400'
,p_animation_on_display=>'auto'
,p_animation_on_data_change=>'auto'
,p_orientation=>'horizontal'
,p_data_cursor=>'auto'
,p_data_cursor_behavior=>'auto'
,p_hide_and_show_behavior=>'withRescale'
,p_hover_behavior=>'dim'
,p_stack=>'off'
,p_connect_nulls=>'Y'
,p_sorting=>'label-asc'
,p_fill_multi_series_gaps=>true
,p_zoom_and_scroll=>'off'
,p_tooltip_rendered=>'Y'
,p_show_series_name=>true
,p_show_group_name=>true
,p_show_value=>true
,p_legend_rendered=>'on'
,p_legend_position=>'auto'
);
wwv_flow_imp_page.create_jet_chart_series(
 p_id=>wwv_flow_imp.id(9378748909218607)
,p_chart_id=>wwv_flow_imp.id(9378600964218606)
,p_static_id=>unistr('interna\00E7\00F5es')
,p_seq=>10
,p_name=>unistr('Interna\00E7\00F5es')
,p_data_source_type=>'SQL'
,p_data_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT',
'    m.nome_municipio,',
'    COUNT(*) AS total_internacoes',
'FROM admin.fato_internacao f',
'JOIN admin.dim_municipio m',
'    ON m.cod_municipio = f.cod_municipio_internacao',
'WHERE f.ano_competencia * 100 + f.mes_competencia',
'      BETWEEN TO_NUMBER(:P1_COMPETENCIA_INICIO)',
'          AND TO_NUMBER(:P1_COMPETENCIA_FIM)',
'GROUP BY',
'    m.nome_municipio',
'ORDER BY',
'    total_internacoes DESC',
'FETCH FIRST 10 ROWS ONLY'))
,p_items_value_column_name=>'TOTAL_INTERNACOES'
,p_items_label_column_name=>'NOME_MUNICIPIO'
,p_assigned_to_y2=>'off'
,p_items_label_rendered=>true
,p_items_label_position=>'auto'
);
wwv_flow_imp_page.create_jet_chart_axis(
 p_id=>wwv_flow_imp.id(9378892138218608)
,p_chart_id=>wwv_flow_imp.id(9378600964218606)
,p_static_id=>'x'
,p_axis=>'x'
,p_is_rendered=>'on'
,p_format_scaling=>'auto'
,p_scaling=>'linear'
,p_baseline_scaling=>'zero'
,p_major_tick_rendered=>'on'
,p_minor_tick_rendered=>'auto'
,p_tick_label_rendered=>'on'
,p_tick_label_rotation=>'auto'
,p_tick_label_position=>'outside'
);
wwv_flow_imp_page.create_jet_chart_axis(
 p_id=>wwv_flow_imp.id(9378978339218609)
,p_chart_id=>wwv_flow_imp.id(9378600964218606)
,p_static_id=>'y'
,p_axis=>'y'
,p_is_rendered=>'on'
,p_format_type=>'decimal'
,p_decimal_places=>0
,p_format_scaling=>'none'
,p_scaling=>'linear'
,p_baseline_scaling=>'zero'
,p_position=>'auto'
,p_major_tick_rendered=>'on'
,p_minor_tick_rendered=>'auto'
,p_tick_label_rendered=>'on'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(10154510667401116)
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
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(10154886007401119)
,p_button_sequence=>30
,p_button_plug_id=>wwv_flow_imp.id(10154510667401116)
,p_button_name=>'BTN_APLICAR_PERIODO'
,p_static_id=>'btn-aplicar-periodo'
,p_show_as_disabled=>false
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4073839297780169708
,p_button_image_alt=>unistr('Aplicar per\00EDodo')
,p_grid_new_row=>'Y'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(10154720873401118)
,p_name=>'P1_COMPETENCIA_FIM'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(10154510667401116)
,p_item_default=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT',
'    MAX(ano_competencia * 100 + mes_competencia)',
'FROM admin.fato_internacao'))
,p_item_default_type=>'SQL_QUERY'
,p_prompt=>unistr('Compet\00EAncia final')
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT',
'    TO_CHAR(',
'        TO_DATE(TO_CHAR(competencia), ''YYYYMM''),',
'        ''MM/YYYY''',
'    ) AS display_value,',
'    competencia AS return_value',
'FROM (',
'    SELECT DISTINCT',
'        ano_competencia * 100 + mes_competencia AS competencia',
'    FROM admin.fato_internacao',
')',
'ORDER BY return_value'))
,p_cHeight=>1
,p_begin_on_new_line=>'N'
,p_colspan=>6
,p_field_template=>1610598304472262251
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'YES'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(10154671211401117)
,p_name=>'P1_COMPETENCIA_INICIO'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(10154510667401116)
,p_item_default=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT',
'    TO_NUMBER(',
'        TO_CHAR(',
'            ADD_MONTHS(',
'                TO_DATE(',
'                    TO_CHAR(MAX(ano_competencia * 100 + mes_competencia)),',
'                    ''YYYYMM''',
'                ),',
'                -2',
'            ),',
'            ''YYYYMM''',
'        )',
'    )',
'FROM admin.fato_internacao'))
,p_item_default_type=>'SQL_QUERY'
,p_prompt=>unistr('Compet\00EAncia inicial')
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_lov=>wwv_flow_string.join(wwv_flow_t_varchar2(
'SELECT',
'    TO_CHAR(',
'        TO_DATE(TO_CHAR(competencia), ''YYYYMM''),',
'        ''MM/YYYY''',
'    ) AS display_value,',
'    competencia AS return_value',
'FROM (',
'    SELECT DISTINCT',
'        ano_competencia * 100 + mes_competencia AS competencia',
'    FROM admin.fato_internacao',
')',
'ORDER BY return_value'))
,p_cHeight=>1
,p_colspan=>6
,p_field_template=>1610598304472262251
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'YES'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(10155405548401125)
,p_name=>'P1_ROTULO_PERIODO_ANTERIOR'
,p_item_sequence=>50
,p_item_plug_id=>wwv_flow_imp.id(10154510667401116)
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(10155346858401124)
,p_name=>'P1_ROTULO_PERIODO_ATUAL'
,p_item_sequence=>40
,p_item_plug_id=>wwv_flow_imp.id(10154510667401116)
,p_source_type=>'ALWAYS_NULL'
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(10154007846401111)
,p_name=>'P1_TEXTO_ESCOPO'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(10153926858401110)
,p_use_cache_before_default=>'NO'
,p_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'WITH limites AS (',
'    SELECT',
'        NVL(',
'            TO_NUMBER(:P1_COMPETENCIA_INICIO),',
'            TO_NUMBER(',
'                TO_CHAR(',
'                    ADD_MONTHS(',
'                        TO_DATE(',
'                            TO_CHAR(MAX(competencia)),',
'                            ''YYYYMM''',
'                        ),',
'                        -2',
'                    ),',
'                    ''YYYYMM''',
'                )',
'            )',
'        ) AS competencia_inicio,',
'        NVL(',
'            TO_NUMBER(:P1_COMPETENCIA_FIM),',
'            MAX(competencia)',
'        ) AS competencia_fim',
'    FROM vw_escopo_dados',
'),',
'dados AS (',
'    SELECT',
'        e.competencia,',
'        e.uf,',
'        e.total_registros',
'    FROM vw_escopo_dados e',
'    CROSS JOIN limites l',
'    WHERE e.competencia',
'          BETWEEN l.competencia_inicio',
'              AND l.competencia_fim',
'),',
'resumo AS (',
'    SELECT',
'        SUM(total_registros) AS total_registros,',
'        MIN(competencia) AS competencia_minima,',
'        MAX(competencia) AS competencia_maxima',
'    FROM dados',
'),',
'ufs AS (',
'    SELECT',
'        COUNT(*) AS total_ufs,',
'        LISTAGG(uf, '', '') WITHIN GROUP (',
'            ORDER BY uf',
'        ) AS lista_ufs',
'    FROM (',
'        SELECT DISTINCT uf',
'        FROM dados',
'        WHERE uf IS NOT NULL',
'    )',
')',
'SELECT',
'    CASE',
'        WHEN NVL(r.total_registros, 0) = 0 THEN',
unistr('            ''Nenhum registro de interna\00E7\00E3o dispon\00EDvel no per\00EDodo selecionado.'''),
'        ELSE',
unistr('            ''Indicadores calculados sobre uma amostra acad\00EAmica de '' ||'),
'            TO_CHAR(',
'                r.total_registros,',
'                ''FM999G999G990'',',
'                ''NLS_NUMERIC_CHARACTERS='''',.''''''',
'            ) ||',
unistr('            '' registros de interna\00E7\00E3o do SIH/SUS, '' ||'),
'            CASE',
'                WHEN u.total_ufs = 0 THEN',
unistr('                    ''com abrang\00EAncia geogr\00E1fica n\00E3o informada'''),
'                WHEN u.total_ufs = 1 THEN',
'                    ''abrangendo 1 unidade federativa ('' ||',
'                    u.lista_ufs || '')''',
'                WHEN u.total_ufs <= 5 THEN',
'                    ''abrangendo '' || u.total_ufs ||',
'                    '' unidades federativas ('' ||',
'                    u.lista_ufs || '')''',
'                ELSE',
'                    ''abrangendo '' || u.total_ufs ||',
'                    '' unidades federativas do Brasil''',
'            END ||',
unistr('            '', referentes \00E0s compet\00EAncias entre '' ||'),
'            TO_CHAR(',
'                TO_DATE(',
'                    TO_CHAR(r.competencia_minima),',
'                    ''YYYYMM''',
'                ),',
'                ''MM/YYYY''',
'            ) ||',
'            '' e '' ||',
'            TO_CHAR(',
'                TO_DATE(',
'                    TO_CHAR(r.competencia_maxima),',
'                    ''YYYYMM''',
'                ),',
'                ''MM/YYYY''',
'            ) ||',
unistr('            ''. Cada registro representa uma interna\00E7\00E3o, n\00E3o um paciente \00FAnico. '' ||'),
unistr('            ''Os resultados refletem exclusivamente os registros dispon\00EDveis na plataforma para o per\00EDodo e a abrang\00EAncia selecionados.'''),
'    END',
'FROM resumo r',
'CROSS JOIN ufs u'))
,p_source_type=>'QUERY'
,p_display_as=>'NATIVE_HIDDEN'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_validation(
 p_id=>wwv_flow_imp.id(10154997118401120)
,p_validation_name=>unistr('Validar intervalo de compet\00EAncias')
,p_static_id=>unistr('validar-intervalo-de-compet\00EAncias')
,p_validation_sequence=>10
,p_validation=>wwv_flow_string.join(wwv_flow_t_varchar2(
'TO_NUMBER(:P1_COMPETENCIA_INICIO) <=',
'TO_NUMBER(:P1_COMPETENCIA_FIM)'))
,p_validation2=>'PLSQL'
,p_validation_type=>'EXPRESSION'
,p_error_message=>unistr('A compet\00EAncia inicial deve ser anterior ou igual \00E0 compet\00EAncia final.')
,p_when_button_pressed=>wwv_flow_imp.id(10154886007401119)
,p_associated_item=>wwv_flow_imp.id(10154720873401118)
,p_error_display_location=>'INLINE_WITH_FIELD_AND_NOTIFICATION'
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(10155534346401126)
,p_process_sequence=>10
,p_process_point=>'BEFORE_HEADER'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>unistr('Definir r\00F3tulos dos per\00EDodos')
,p_static_id=>unistr('definir-r\00F3tulos-dos-per\00EDodos')
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_competencia_maxima NUMBER;',
'    v_competencia_inicio NUMBER;',
'    v_competencia_fim    NUMBER;',
'    v_data_inicio        DATE;',
'    v_data_fim           DATE;',
'    v_quantidade_meses   PLS_INTEGER;',
'BEGIN',
'    SELECT MAX(competencia)',
'      INTO v_competencia_maxima',
'      FROM vw_escopo_dados;',
'',
'    v_competencia_inicio :=',
'        NVL(',
'            TO_NUMBER(:P1_COMPETENCIA_INICIO),',
'            TO_NUMBER(',
'                TO_CHAR(',
'                    ADD_MONTHS(',
'                        TO_DATE(',
'                            TO_CHAR(v_competencia_maxima),',
'                            ''YYYYMM''',
'                        ),',
'                        -2',
'                    ),',
'                    ''YYYYMM''',
'                )',
'            )',
'        );',
'',
'    v_competencia_fim :=',
'        NVL(',
'            TO_NUMBER(:P1_COMPETENCIA_FIM),',
'            v_competencia_maxima',
'        );',
'',
'    v_data_inicio :=',
'        TO_DATE(',
'            TO_CHAR(v_competencia_inicio),',
'            ''YYYYMM''',
'        );',
'',
'    v_data_fim :=',
'        TO_DATE(',
'            TO_CHAR(v_competencia_fim),',
'            ''YYYYMM''',
'        );',
'',
'    v_quantidade_meses :=',
'        MONTHS_BETWEEN(',
'            v_data_fim,',
'            v_data_inicio',
'        ) + 1;',
'',
'    :P1_COMPETENCIA_INICIO := v_competencia_inicio;',
'    :P1_COMPETENCIA_FIM := v_competencia_fim;',
'',
'    :P1_ROTULO_PERIODO_ATUAL :=',
'        ''Selecionado: '' ||',
'        TO_CHAR(v_data_inicio, ''MM/YYYY'') ||',
unistr('        ''\2013'' ||'),
'        TO_CHAR(v_data_fim, ''MM/YYYY'');',
'',
'    :P1_ROTULO_PERIODO_ANTERIOR :=',
'        ''Anterior: '' ||',
'        TO_CHAR(',
'            ADD_MONTHS(',
'                v_data_inicio,',
'                -v_quantidade_meses',
'            ),',
'            ''MM/YYYY''',
'        ) ||',
unistr('        ''\2013'' ||'),
'        TO_CHAR(',
'            ADD_MONTHS(v_data_inicio, -1),',
'            ''MM/YYYY''',
'        );',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>10155534346401126
);
wwv_flow_imp.component_end;
end;
/
