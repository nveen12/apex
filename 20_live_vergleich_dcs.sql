set echo on
set define off
whenever sqlerror exit sql.sqlcode rollback

--------------------------------------------------------------------------------
-- Migration Tracker - Page 12: Live Vergleich DCS
-- Run as: MIGRATION on rzhs440:1521/opk.entw
--
-- Depends on:
--   19_dcs_invalid_compare.sql
--------------------------------------------------------------------------------

declare
    l_workspace_id number;
    l_app_id       number;
    l_nav_list_id  number;
    l_region_input number := 91200000000000010;
    l_region_help  number := 91200000000000020;
    l_region_sum   number := 91200000000000030;
    l_region_detail number := 91200000000000040;
    l_region_action number := 91200000000000045;
    l_nav_found    boolean := false;
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

    wwv_flow_imp_page.remove_page(p_flow_id => l_app_id, p_page_id => 12);

    wwv_flow_imp_page.create_page(
        p_id                    => 12,
        p_name                  => 'Live Vergleich DCS',
        p_alias                 => 'LIVE-VERGLEICH-DCS',
        p_step_title            => 'Live Vergleich DCS',
        p_autocomplete_on_off   => 'OFF',
        p_page_template_options => '#DEFAULT#',
        p_protection_level      => 'C',
        p_page_component_map    => '03');

    wwv_flow_imp_page.create_page_plug(
        p_id                    => wwv_flow_imp.id(91200000000000001),
        p_plug_name             => 'DCS Layout Cleanup',
        p_plug_display_sequence => 1,
        p_plug_display_point    => 'BODY',
        p_plug_source_type      => 'NATIVE_STATIC',
        p_plug_source           => q'~<style>
.t-Body-nav,.t-TreeNav{visibility:hidden}
.mt-dcs-help{max-width:1120px;background:#f6f8fa;border:1px solid #d0d7de;border-radius:6px;padding:10px 12px;margin-bottom:12px}
.mt-dcs-help strong{display:block;margin-bottom:4px}
.mt-dcs-actions{display:flex;gap:8px;margin-top:8px}
.mt-dcs-actions .t-Button{min-width:120px}
.mt-dcs-report .t-Report-report{font-size:.86rem}
.mt-dcs-status-source-valid-dcs-invalid{color:#b42318;font-weight:700}
.mt-dcs-status-source-invalid-dcs-invalid{color:#7a4b00;font-weight:700}
.mt-dcs-status-not-found-in-prod-source,
.mt-dcs-status-source-link-error,
.mt-dcs-status-parse-fehler{color:#b42318;font-weight:700}
</style>
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
        if (row) { row.style.display = "none"; } else { anchor.style.display = "none"; }
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
</script>~',
        p_attributes            => wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
            'expand_shortcuts', 'N',
            'output_as',        'HTML',
            'show_line_breaks', 'N')).to_clob);

    wwv_flow_imp_page.create_page_plug(
        p_id                      => wwv_flow_imp.id(l_region_help),
        p_plug_name               => 'Hinweis',
        p_region_template_options => '#DEFAULT#',
        p_plug_template           => wwv_flow_imp.id(10818657374759767),
        p_plug_display_sequence   => 5,
        p_plug_display_point      => 'BODY',
        p_plug_source             => q'~<div class="mt-dcs-help">
<strong>DCS Invalid-Objekte analysieren</strong>
Paste die Dataport/DCS-Liste mit invaliden Objekten hier hinein. Erkannt wird SQL*Plus-Ausgabe mit <code>OWNER OBJECT_TYPE OBJECT_NAME</code> sowie einfache Zeilen mit <code>SCHEMA.OBJECT_NAME</code>. Die App sucht diese Objekte in allen aktiven PROD-Quellen und zeigt, ob sie dort gueltig, ungueltig oder nicht vorhanden sind.
</div>~',
        p_attributes              => wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
            'expand_shortcuts', 'N',
            'output_as',        'HTML',
            'show_line_breaks', 'N')).to_clob);

    wwv_flow_imp_page.create_page_plug(
        p_id                      => wwv_flow_imp.id(l_region_input),
        p_plug_name               => 'DCS Invalid-Liste',
        p_title                   => 'DCS Invalid-Liste',
        p_plug_template           => wwv_flow_imp.id(10818657374759767),
        p_region_template_options => '#DEFAULT#:t-Region--scrollBody',
        p_plug_display_sequence   => 10,
        p_plug_display_point      => 'BODY',
        p_plug_source_type        => 'NATIVE_STATIC',
        p_attributes              => wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
            'expand_shortcuts', 'N',
            'output_as',        'HTML',
            'show_line_breaks', 'N')).to_clob);

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(91200000000000011),
        p_name             => 'P12_RUN_ID',
        p_item_sequence    => 10,
        p_item_plug_id     => wwv_flow_imp.id(l_region_input),
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_item(
        p_id            => wwv_flow_imp.id(91200000000000012),
        p_name          => 'P12_INVALID_TEXT',
        p_item_sequence => 20,
        p_item_plug_id  => wwv_flow_imp.id(l_region_input),
        p_prompt        => 'DCS invalid objects',
        p_display_as    => 'NATIVE_TEXTAREA',
        p_csize         => 120,
        p_cheight       => 14,
        p_cmaxlength    => 32000);

    wwv_flow_imp_page.create_page_button(
        p_id                      => wwv_flow_imp.id(91200000000000013),
        p_button_sequence         => 30,
        p_button_plug_id          => wwv_flow_imp.id(l_region_input),
        p_button_name             => 'ANALYZE_DCS',
        p_button_action           => 'SUBMIT',
        p_button_template_id      => wwv_flow_imp.id(10892289891759782),
        p_button_template_options => '#DEFAULT#',
        p_button_is_hot           => 'Y',
        p_button_image_alt        => 'DCS Invalide analysieren',
        p_button_position         => 'BELOW_BOX',
        p_button_alignment        => 'LEFT',
        p_icon_css_classes        => 'fa-search');

    -- Fallback action button. Some imported Universal Theme/template
    -- combinations do not visibly render the normal region button slot.
    wwv_flow_imp_page.create_page_plug(
        p_id                      => wwv_flow_imp.id(l_region_action),
        p_plug_name               => 'DCS Analyse Aktion',
        p_region_template_options => '#DEFAULT#',
        p_plug_template           => wwv_flow_imp.id(10818657374759767),
        p_plug_display_sequence   => 15,
        p_plug_display_point      => 'BODY',
        p_plug_source             => q'~<div class="mt-dcs-actions">
  <button type="button" class="t-Button t-Button--hot" onclick="apex.submit('ANALYZE_DCS');">
    <span class="t-Icon fa fa-search" aria-hidden="true"></span>
    <span class="t-Button-label">DCS Invalide analysieren</span>
  </button>
</div>~',
        p_attributes              => wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
            'expand_shortcuts', 'N',
            'output_as',        'HTML',
            'show_line_breaks', 'N')).to_clob);

    wwv_flow_imp_page.create_report_region(
        p_id                         => wwv_flow_imp.id(l_region_sum),
        p_name                       => 'DCS Analyse Zusammenfassung',
        p_title                      => 'DCS Analyse Zusammenfassung',
        p_template                   => wwv_flow_imp.id(10818657374759767),
        p_display_sequence           => 20,
        p_display_point              => 'BODY',
        p_region_css_classes         => 'mt-dcs-report',
        p_region_template_options    => '#DEFAULT#:t-Region--scrollBody',
        p_component_template_options => '#DEFAULT#:t-Report--altRowsDefault:t-Report--rowHighlight',
        p_display_condition_type     => 'ITEM_IS_NOT_NULL',
        p_display_when_condition     => 'P12_RUN_ID',
        p_source_type                => 'NATIVE_SQL_REPORT',
        p_query_type                 => 'SQL',
        p_source                     => wwv_flow_string.join(wwv_flow_t_varchar2(
            'select r.run_id,',
            '       to_char(r.created_at, ''DD.MM.YYYY HH24:MI:SS'') as erstellt_am,',
            '       r.line_count,',
            '       r.parsed_count,',
            '       x.result_status,',
            '       count(*) as anzahl',
            'from   mt_dcs_invalid_run r',
            'join   mt_dcs_invalid_result x on x.run_id = r.run_id',
            'where  r.run_id = :P12_RUN_ID',
            'group  by r.run_id, r.created_at, r.line_count, r.parsed_count, x.result_status',
            'order  by case x.result_status',
            '            when ''SOURCE_VALID_DCS_INVALID'' then 1',
            '            when ''SOURCE_INVALID_DCS_INVALID'' then 2',
            '            when ''SOURCE_LINK_ERROR'' then 3',
            '            when ''NOT_FOUND_IN_PROD_SOURCE'' then 4',
            '            else 5',
            '          end')),
        p_query_num_rows             => 20,
        p_query_options              => 'DERIVED_REPORT_COLUMNS');

    wwv_flow_imp_page.create_report_region(
        p_id                         => wwv_flow_imp.id(l_region_detail),
        p_name                       => 'DCS Invalid Vergleich Ergebnis',
        p_title                      => 'DCS Invalid Vergleich Ergebnis',
        p_template                   => wwv_flow_imp.id(10818657374759767),
        p_display_sequence           => 30,
        p_display_point              => 'BODY',
        p_region_css_classes         => 'mt-dcs-report',
        p_region_template_options    => '#DEFAULT#:t-Region--scrollBody',
        p_component_template_options => '#DEFAULT#:t-Report--altRowsDefault:t-Report--rowHighlight',
        p_display_condition_type     => 'ITEM_IS_NOT_NULL',
        p_display_when_condition     => 'P12_RUN_ID',
        p_source_type                => 'NATIVE_SQL_REPORT',
        p_query_type                 => 'SQL',
        p_source                     => wwv_flow_string.join(wwv_flow_t_varchar2(
            'select line_no                         as "Zeile",',
            '       parsed_schema                   as "DCS Schema",',
            '       object_name                     as "Objekt",',
            '       nvl(parsed_object_type, ''-'')  as "DCS Typ",',
            '       nvl(source_host, ''-'')         as "Quelle Host",',
            '       nvl(source_service, ''-'')      as "Quelle Service",',
            '       nvl(source_object_type, ''-'')  as "Quelle Typ",',
            '       nvl(source_status, ''-'')       as "Quelle Status",',
            '       result_status                   as "Ergebnis",',
            '       hinweis                         as "Hinweis"',
            'from   mt_dcs_invalid_result',
            'where  run_id = :P12_RUN_ID',
            'order  by case result_status',
            '            when ''SOURCE_VALID_DCS_INVALID'' then 1',
            '            when ''SOURCE_INVALID_DCS_INVALID'' then 2',
            '            when ''SOURCE_LINK_ERROR'' then 3',
            '            when ''NOT_FOUND_IN_PROD_SOURCE'' then 4',
            '            else 5',
            '          end,',
            '          parsed_schema, object_name, source_host, source_service')),
        p_query_num_rows             => 100,
        p_query_options              => 'DERIVED_REPORT_COLUMNS');

    wwv_flow_imp_page.create_page_process(
        p_id                     => wwv_flow_imp.id(91200000000000050),
        p_process_sequence       => 10,
        p_process_point          => 'AFTER_SUBMIT',
        p_process_type           => 'NATIVE_PLSQL',
        p_process_name           => 'DCS Invalid-Liste analysieren',
        p_process_sql_clob       => wwv_flow_string.join(wwv_flow_t_varchar2(
            'begin',
            '    if apex_application.g_request = ''ANALYZE_DCS'' then',
            '        :P12_RUN_ID := mt_dcs_invalid_pkg.analyze(',
            '            p_raw_text   => :P12_INVALID_TEXT,',
            '            p_created_by => nvl(v(''APP_USER''), user));',
            '    end if;',
            'end;')),
        p_error_display_location => 'INLINE_IN_NOTIFICATION',
        p_internal_uid           => 91200000000000050);

    for r in (
        select list_entry_id
        from   apex_application_list_entries
        where  application_id = l_app_id
        and    list_name = 'Navigation Menu'
        and    entry_text = 'Live Vergleich DCS'
    ) loop
        l_nav_found := true;
        wwv_flow_imp_shared.set_list_item_sequence(
            p_id            => r.list_entry_id,
            p_item_sequence => 30);
        wwv_flow_imp_shared.set_list_item_link_target(
            p_id          => r.list_entry_id,
            p_link_target => 'f?p=&APP_ID.:12:&APP_SESSION.::&DEBUG.:::');
    end loop;

    if not l_nav_found then
        wwv_flow_imp_shared.create_list_item(
            p_id                          => wwv_flow_imp.id(91200000000000070),
            p_list_id                     => l_nav_list_id,
            p_list_item_type              => 'LINK',
            p_list_item_status            => 'PUBLIC',
            p_list_item_display_sequence  => 30,
            p_list_item_link_text         => 'Live Vergleich DCS',
            p_list_item_link_target       => 'f?p=&APP_ID.:12:&APP_SESSION.::&DEBUG.:::',
            p_list_item_icon              => 'fa-search',
            p_list_item_current_type      => 'TARGET_PAGE',
            p_list_item_current_for_pages => '12');
    end if;

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
and    page_id in (1, 10, 12)
order  by page_id;
