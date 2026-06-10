set echo on
set define off
whenever sqlerror exit sql.sqlcode rollback

-- =============================================================================
-- Migration Tracker - Page 10: Live Vergleich
-- Anwendung: 114  Workspace: MIGRATION  Schema: migration
-- Ziel: Standalone launcher for Page 9 source-vs-target comparison.
-- =============================================================================

declare
    l_workspace_id number;
    l_app_id       number;
    l_region_id    number := 91000000000000010;
    l_action_region_id number := 91000000000000015;
    l_button_id    number := 91000000000000020;
    l_nav_list_id  number;
begin
    select workspace_id
    into   l_workspace_id
    from   apex_workspaces
    where  workspace = 'MIGRATION';

    apex_util.set_security_group_id(l_workspace_id);

    select application_id
    into   l_app_id
    from (
        select application_id
        from   apex_applications
        where  workspace = 'MIGRATION'
        and    application_name = 'Migration_Tracker'
        order  by application_id
    )
    where rownum = 1;

    select list_id
    into   l_nav_list_id
    from   apex_application_lists
    where  application_id = l_app_id
    and    list_name = 'Navigation Menu';

    wwv_flow_imp.import_begin(
        p_version_yyyy_mm_dd     => '2024.05.31',
        p_release                => '24.1.0',
        p_default_workspace_id   => l_workspace_id,
        p_default_application_id => l_app_id,
        p_default_id_offset      => 0,
        p_default_owner          => 'MIGRATION');

    wwv_flow_imp_page.remove_page(p_flow_id => l_app_id, p_page_id => 10);

    wwv_flow_imp_page.create_page(
        p_id                    => 10,
        p_name                  => 'Live Vergleich',
        p_alias                 => 'LIVE-VERGLEICH',
        p_step_title            => 'Live Vergleich',
        p_autocomplete_on_off   => 'OFF',
        p_page_template_options => '#DEFAULT#',
        p_protection_level      => 'C',
        p_page_component_map    => '03');

    wwv_flow_imp_page.create_page_plug(
        p_id                      => wwv_flow_imp.id(l_region_id),
        p_plug_name               => 'Live Vergleich starten',
        p_region_template_options => '#DEFAULT#:t-Region--scrollBody',
        p_plug_template           => wwv_flow_imp.id(10818657374759767),
        p_plug_display_sequence   => 10,
        p_plug_display_point      => 'BODY',
        p_attributes              => wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
            'expand_shortcuts', 'N',
            'output_as',        'TEXT',
            'show_line_breaks', 'Y')).to_clob);

    wwv_flow_imp_page.create_page_item(
        p_id                    => wwv_flow_imp.id(91000000000000011),
        p_name                  => 'P10_MAPPING_ID',
        p_item_sequence         => 10,
        p_item_plug_id          => wwv_flow_imp.id(l_region_id),
        p_prompt                => 'Vergleich',
        p_display_as            => 'NATIVE_SELECT_LIST',
        p_lov                   => wwv_flow_string.join(wwv_flow_t_varchar2(
            'select src.hostname || ''_'' || sc.cdb_name || ''_'' || nvl(sp.service_name, sp.pdb_name)',
            '       || '' --> '' ||',
            '       tgt.hostname || ''_'' || tc.cdb_name || ''_'' || nvl(tp.service_name, tp.pdb_name) as display_value,',
            '       tm.mapping_id as return_value',
            'from   mt_fachverfahren fv',
            'join   mt_fv_pdb_mapping tm on tm.fv_id = fv.fv_id',
            'join   mt_pdb tp            on tp.pdb_id = tm.pdb_id',
            'join   mt_cdb tc            on tc.cdb_id = tp.cdb_id',
            'join   mt_server tgt        on tgt.server_id = tc.server_id',
            'join   mt_fv_pdb_mapping sm on sm.fv_id = fv.fv_id',
            'join   mt_pdb sp            on sp.pdb_id = sm.pdb_id',
            'join   mt_cdb sc            on sc.cdb_id = sp.cdb_id',
            'join   mt_server src        on src.server_id = sc.server_id',
            'where  tm.mapping_role = ''WORKBENCH''',
            'and    sm.mapping_role = ''QUELLE''',
            'and    nvl(tm.aktiv, ''J'') = ''J''',
            'and    nvl(sm.aktiv, ''J'') = ''J''',
            'and    (nvl(sp.tier, ''-'') = nvl(tp.tier, ''-'')',
            '        or fv.fv_kuerzel in (''GG'', ''IT_FALL''))',
            'and    sp.dblink_name is not null',
            'and    tp.dblink_name is not null',
            'and    sp.dblink_name not like ''##%##''',
            'and    tp.dblink_name not like ''##%##''',
            'order  by fv.fv_name, tp.service_name')),
        p_lov_display_null      => 'YES',
        p_lov_null_text         => '- Vergleich waehlen -',
        p_csize                 => 110,
        p_item_template_options => '#DEFAULT#',
        p_protection_level      => 'S',
        p_attribute_01          => 'NONE',
        p_attribute_02          => 'N');

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(91000000000000012),
        p_name             => 'P10_FV_ID',
        p_item_sequence    => 20,
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(91000000000000013),
        p_name             => 'P10_SCHEMA_NAME',
        p_item_sequence    => 30,
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_button(
        p_id                      => wwv_flow_imp.id(l_button_id),
        p_button_sequence         => 20,
        p_button_plug_id          => wwv_flow_imp.id(l_region_id),
        p_button_name             => 'OPEN_LIVE_VERGLEICH',
        p_button_action           => 'SUBMIT',
        p_button_template_id      => wwv_flow_imp.id(10892289891759782),
        p_button_template_options => '#DEFAULT#',
        p_button_is_hot           => 'Y',
        p_button_image_alt        => 'Live Vergleich oeffnen',
        p_button_position         => 'BELOW_BOX',
        p_button_alignment        => 'LEFT',
        p_icon_css_classes        => 'fa-search');

    -- Some imported Universal Theme/template combinations do not visibly render
    -- the region button slot. This static fallback button is intentionally plain
    -- HTML and submits the same request used by the page process.
    wwv_flow_imp_page.create_page_plug(
        p_id                      => wwv_flow_imp.id(l_action_region_id),
        p_plug_name               => 'Live Vergleich Aktion',
        p_region_template_options => '#DEFAULT#',
        p_plug_template           => wwv_flow_imp.id(10818657374759767),
        p_plug_display_sequence   => 20,
        p_plug_display_point      => 'BODY',
        p_plug_source             => q'~<style>.t-Body-nav,.t-TreeNav{visibility:hidden}</style>
<script>
(function(){
  function hideOldNavEntries(){
    var hiddenTexts = {
      "Home": true,
      "Fachverfahren": true,
      "Caesar Orders": true,
      "Checkliste": true,
      "Service Name Audit": true,
      "Server Inventory": true
    };
    document.querySelectorAll(".t-TreeNav a, .t-Body-nav a, nav a").forEach(function(anchor){
      var text = (anchor.textContent || "").replace(/\s+/g, " ").trim();
      var href = anchor.getAttribute("href") || "";
      if (hiddenTexts[text] || /[:.]([2-8])[:.]/.test(href)) {
        var row = anchor.closest("li");
        if (row) {
          row.style.display = "none";
        } else {
          anchor.style.display = "none";
        }
      }
    });
    document.querySelectorAll(".t-Body-nav,.t-TreeNav,nav").forEach(function(nav){
      nav.style.visibility = "visible";
    });
  }
  hideOldNavEntries();
  document.addEventListener("apexreadyend", hideOldNavEntries);
  window.setTimeout(hideOldNavEntries, 300);
})();
</script>
<button type="button" class="t-Button t-Button--hot" onclick="apex.submit('OPEN_LIVE_VERGLEICH');"><span class="t-Icon fa fa-search" aria-hidden="true"></span><span class="t-Button-label">Live Vergleich oeffnen</span></button>~',
        p_attributes              => wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
            'expand_shortcuts', 'N',
            'output_as',        'HTML',
            'show_line_breaks', 'N')).to_clob);

    wwv_flow_imp_page.create_page_process(
        p_id                     => wwv_flow_imp.id(91000000000000030),
        p_process_sequence       => 10,
        p_process_point          => 'AFTER_SUBMIT',
        p_process_type           => 'NATIVE_PLSQL',
        p_process_name           => 'Fachverfahren und Schema ableiten',
        p_process_sql_clob       => wwv_flow_string.join(wwv_flow_t_varchar2(
            'begin',
            '    -- Default for migration tracking: compare all custom schemas from target.',
            '    -- Page 9 derives schema names from target ALL_USERS.ORACLE_MAINTAINED = N',
            '    -- and compares those same schema names on source. Source may be older than 19c.',
            '    select fv.fv_id, ''__ALL_APP_SCHEMAS__''',
            '    into   :P10_FV_ID, :P10_SCHEMA_NAME',
            '    from   mt_fv_pdb_mapping m',
            '    join   mt_fachverfahren fv on fv.fv_id = m.fv_id',
            '    where  m.mapping_id = :P10_MAPPING_ID;',
            '',
            '    apex_util.redirect_url(',
            '        apex_page.get_url(',
            '            p_page        => 9,',
            '            p_clear_cache => ''9'',',
            '            p_items       => ''P9_MAPPING_ID,P9_FV_ID,P9_SCHEMA_NAME'',',
            '            p_values      => :P10_MAPPING_ID || '','' || :P10_FV_ID || '','' || :P10_SCHEMA_NAME));',
            '',
            '    apex_application.stop_apex_engine;',
            'exception',
            '    when no_data_found then',
            '        :P10_FV_ID := null;',
            '        :P10_SCHEMA_NAME := null;',
            'end;')),
        p_error_display_location => 'INLINE_IN_NOTIFICATION',
        p_internal_uid           => 91000000000000030);

    begin
        wwv_flow_imp_shared.create_list_item(
            p_id                          => wwv_flow_imp.id(91000000000000050),
            p_list_id                     => l_nav_list_id,
            p_list_item_type              => 'LINK',
            p_list_item_status            => 'PUBLIC',
            p_item_displayed              => 'Y',
            p_list_item_display_sequence  => 70,
            p_list_item_link_text         => 'Live Vergleich',
            p_list_item_link_target       => 'f?p=&APP_ID.:10:&APP_SESSION.::&DEBUG.:::',
            p_list_item_icon              => 'fa-search',
            p_list_item_current_type      => 'TARGET_PAGE',
            p_list_item_current_for_pages => '10');
    exception
        when others then
            wwv_flow_imp_shared.set_list_item_sequence(
                p_id            => wwv_flow_imp.id(91000000000000050),
                p_item_sequence => 70);
            wwv_flow_imp_shared.set_list_item_link_text(
                p_id        => wwv_flow_imp.id(91000000000000050),
                p_link_text => 'Live Vergleich');
            wwv_flow_imp_shared.set_list_item_link_target(
                p_id          => wwv_flow_imp.id(91000000000000050),
                p_link_target => 'f?p=&APP_ID.:10:&APP_SESSION.::&DEBUG.:::');
    end;

    wwv_flow_imp.import_end(p_auto_install_sup_obj => false);
    commit;
end;
/

select page_id, page_name
from   apex_application_pages
where  application_id = (
           select min(application_id)
           from   apex_applications
           where  workspace = 'MIGRATION'
           and    application_name = 'Migration_Tracker'
       )
and    page_id in (9, 10)
order  by page_id;
