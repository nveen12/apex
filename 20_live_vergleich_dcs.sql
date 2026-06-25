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
.mt-dcs-rule-form{display:flex;gap:8px;align-items:end;flex-wrap:wrap;margin:10px 0 18px}
.mt-dcs-rule-form label{display:flex;flex-direction:column;gap:3px;font-weight:600}
.mt-dcs-rule-form select{min-width:260px;max-width:520px}
.mt-dcs-report .t-Report-report{font-size:.86rem}
.mt-dcs-result-wrap{overflow:auto;max-width:1500px}
.mt-dcs-result-table{border-collapse:separate;border-spacing:0;width:max-content;min-width:1120px}
.mt-dcs-result-table th,.mt-dcs-result-table td{padding:6px 8px;vertical-align:top;white-space:nowrap}
.mt-dcs-result-table td:last-child{white-space:normal;min-width:320px;max-width:520px}
.mt-dcs-status-source-valid-dcs-invalid{color:#b42318;font-weight:700}
.mt-dcs-status-source-invalid-dcs-invalid{color:#7a4b00;font-weight:700}
.mt-dcs-status-source-not-configured{color:#8250df;font-weight:700}
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
  window.mtSaveDcsSourceRule = function(){
    var schema = document.getElementById("MT_DCS_RULE_SCHEMA");
    var link = document.getElementById("MT_DCS_RULE_DBLINK");
    if (!schema || !link || !schema.value || !link.value) {
      apex.message.alert("Bitte DCS-Schema und PROD-Quelle auswaehlen.");
      return;
    }
    apex.item("P12_RULE_SCHEMA").setValue(schema.value);
    apex.item("P12_RULE_DBLINK").setValue(link.value);
    apex.submit("SAVE_DCS_RULE");
  };
})();
</script>~',
        p_attributes            => wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
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
        p_id               => wwv_flow_imp.id(91200000000000014),
        p_name             => 'P12_RULE_SCHEMA',
        p_item_sequence    => 12,
        p_item_plug_id     => wwv_flow_imp.id(l_region_input),
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(91200000000000015),
        p_name             => 'P12_RULE_DBLINK',
        p_item_sequence    => 14,
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
  <button type="button" class="t-Button" onclick="apex.submit('REFRESH_DCS_INVENTORY');">
    <span class="t-Icon fa fa-refresh" aria-hidden="true"></span>
    <span class="t-Button-label">Quellinventar aktualisieren</span>
  </button>
  <button type="button" class="t-Button t-Button--hot" onclick="apex.submit('ANALYZE_DCS');">
    <span class="t-Icon fa fa-search" aria-hidden="true"></span>
    <span class="t-Button-label">DCS Invalide analysieren</span>
  </button>
</div>~',
        p_attributes              => wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
            'expand_shortcuts', 'N',
            'output_as',        'HTML',
            'show_line_breaks', 'N')).to_clob);

    wwv_flow_imp_page.create_page_plug(
        p_id                      => wwv_flow_imp.id(l_region_sum),
        p_plug_name               => 'DCS Analyse Ergebnis',
        p_title                   => 'DCS Analyse Ergebnis',
        p_plug_template           => wwv_flow_imp.id(10818657374759767),
        p_region_css_classes      => 'mt-dcs-report',
        p_region_template_options => '#DEFAULT#:t-Region--scrollBody',
        p_plug_display_sequence   => 20,
        p_plug_display_point      => 'BODY',
        p_plug_source_type        => 'NATIVE_PLSQL',
        p_plug_source             => q'~declare
    l_rows number := 0;

    function esc(p_text in varchar2) return varchar2 is
    begin
        return apex_escape.html(p_text);
    end;

    procedure table_begin(p_title in varchar2, p_head in varchar2) is
    begin
        htp.p('<h3>' || esc(p_title) || '</h3>');
        htp.p('<div class="mt-dcs-result-wrap">');
        htp.p('<table class="t-Report-report mt-dcs-result-table">');
        htp.p('<thead>' || p_head || '</thead><tbody>');
    end;

    procedure table_end is
    begin
        htp.p('</tbody></table></div>');
    end;

    procedure render_inventory_status is
        l_ok_schemas number := 0;
        l_links      number := 0;
        l_errors     number := 0;
        l_refreshed  varchar2(30);
    begin
        select count(distinct case when refresh_status = 'OK' then schema_name end),
               count(distinct case when refresh_status = 'OK' then source_dblink_name end),
               count(case when refresh_status = 'LINK_ERROR' then 1 end),
               to_char(max(refreshed_at), 'DD.MM.YYYY HH24:MI:SS')
        into   l_ok_schemas, l_links, l_errors, l_refreshed
        from   mt_source_schema_inventory;

        if l_refreshed is null then
            htp.p('<div class="t-Alert t-Alert--warning">PROD-Quellinventar ist noch leer. Beim Klick auf <strong>DCS Invalide analysieren</strong> wird es automatisch aktualisiert; alternativ kannst du vorher <strong>Quellinventar aktualisieren</strong> klicken.</div>');
        else
            htp.p('<div class="t-Alert t-Alert--info">PROD-Quellinventar: ' ||
                  l_ok_schemas || ' Schema(s) aus ' || l_links ||
                  ' DB-Link(s), aktualisiert am ' || esc(l_refreshed) ||
                  case when l_errors > 0 then '. Fehlerhafte DB-Links: ' || l_errors else '' end ||
                  '.</div>');
            if l_ok_schemas = 0 then
                htp.p('<div class="t-Alert t-Alert--danger">Inventar wurde aktualisiert, aber keine Anwendungsschemas gefunden. Bitte USER_DB_LINKS und aktive PROD-Quelle-Mappings pruefen.</div>');
            end if;
        end if;
    end;

    procedure render_rule_helper is
        l_missing_count number := 0;
        l_schema_count  number := 0;
        l_link_count    number := 0;
    begin
        select count(distinct parsed_schema)
        into   l_schema_count
        from   mt_dcs_invalid_result
        where  run_id = :P12_RUN_ID;

        if l_schema_count = 0 then
            return;
        end if;

        select count(distinct parsed_schema)
        into   l_missing_count
        from   mt_dcs_invalid_result
        where  run_id = :P12_RUN_ID
        and    result_status in ('SOURCE_NOT_CONFIGURED', 'SOURCE_AMBIGUOUS');

        select count(*)
        into   l_link_count
        from (
            select distinct p.dblink_name
            from   mt_fv_pdb_mapping m
            join   mt_pdb p on p.pdb_id = m.pdb_id
            where  m.mapping_role = 'QUELLE'
            and    nvl(m.aktiv, 'J') = 'J'
            and    nvl(p.tier, '-') = 'PROD'
            and    p.dblink_name is not null
            and    p.dblink_name not like '##%##'
            and    exists (
                       select 1
                       from   user_db_links l
                       where  l.db_link = upper(p.dblink_name)
                       or     l.db_link like upper(p.dblink_name) || '.%'
                   )
        );

        htp.p('<h3>Quellzuordnung pruefen / aendern</h3>');

        if l_missing_count = 0 then
            htp.p('<div class="t-Alert t-Alert--success">Alle DCS-Schemas dieses Laufs sind zugeordnet. Du kannst die Quellregel hier trotzdem pruefen oder aendern.</div>');
        end if;

        table_begin(
            'Aktive manuelle Quellregeln fuer diesen Lauf',
            '<tr><th>DCS Schema</th><th>PROD Quelle</th></tr>');

        for r in (
            select x.parsed_schema,
                   nvl(rule.source_dblink_name, '-') as source_dblink_name
            from (
                select distinct upper(parsed_schema) as parsed_schema
                from   mt_dcs_invalid_result
                where  run_id = :P12_RUN_ID
            ) x
            left join mt_dcs_schema_source_rule rule
                   on rule.dcs_schema = x.parsed_schema
                  and rule.aktiv = 'J'
            order by x.parsed_schema
        ) loop
            htp.p('<tr><td>' || esc(r.parsed_schema) ||
                  '</td><td>' || esc(r.source_dblink_name) || '</td></tr>');
        end loop;

        table_end;

        htp.p('<div class="mt-dcs-rule-form">');
        htp.p('<label>DCS Schema<select id="MT_DCS_RULE_SCHEMA">');
        htp.p('<option value="">- Schema waehlen -</option>');
        for s in (
            select x.parsed_schema,
                   x.anzahl,
                   rule.source_dblink_name
            from (
                select upper(parsed_schema) as parsed_schema,
                       count(*) as anzahl
                from   mt_dcs_invalid_result
                where  run_id = :P12_RUN_ID
                group  by upper(parsed_schema)
            ) x
            left join mt_dcs_schema_source_rule rule
                   on rule.dcs_schema = x.parsed_schema
                  and rule.aktiv = 'J'
            order  by x.parsed_schema
        ) loop
            htp.p('<option value="' || esc(s.parsed_schema) || '">' ||
                  esc(s.parsed_schema) || ' (' || s.anzahl || ' Objekt(e)' ||
                  case when s.source_dblink_name is not null
                       then ', aktuell: ' || esc(s.source_dblink_name)
                       else ', automatisch/ohne manuelle Regel'
                  end || ')</option>');
        end loop;
        htp.p('</select></label>');

        htp.p('<label>PROD Quelle<select id="MT_DCS_RULE_DBLINK">');
        htp.p('<option value="">- PROD-Quelle waehlen -</option>');
        for l in (
            select distinct
                   upper(p.dblink_name) as dblink_name,
                   max(src.hostname || ' / ' || nvl(p.service_name, p.pdb_name)) as label
            from   mt_fv_pdb_mapping m
            join   mt_pdb p      on p.pdb_id = m.pdb_id
            join   mt_cdb c      on c.cdb_id = p.cdb_id
            join   mt_server src on src.server_id = c.server_id
            where  m.mapping_role = 'QUELLE'
            and    nvl(m.aktiv, 'J') = 'J'
            and    nvl(p.tier, '-') = 'PROD'
            and    p.dblink_name is not null
            and    p.dblink_name not like '##%##'
            and    exists (
                       select 1
                       from   user_db_links u
                       where  u.db_link = upper(p.dblink_name)
                       or     u.db_link like upper(p.dblink_name) || '.%'
                   )
            group  by upper(p.dblink_name)
            order  by label
        ) loop
            htp.p('<option value="' || esc(l.dblink_name) || '">' ||
                  esc(l.label) || ' [' || esc(l.dblink_name) || ']</option>');
        end loop;
        htp.p('</select></label>');

        htp.p('<button type="button" class="t-Button t-Button--hot" onclick="mtSaveDcsSourceRule()">Quellregel speichern und neu analysieren</button>');
        htp.p('</div>');

        if l_link_count = 0 then
            htp.p('<div class="t-Alert t-Alert--danger">Keine nutzbaren PROD-DB-Links in USER_DB_LINKS gefunden.</div>');
        end if;
    end;
begin
    render_inventory_status;

    if :P12_RUN_ID is null then
        htp.p('<div class="t-Alert t-Alert--info">Paste DCS invalid-object text and click <strong>DCS Invalide analysieren</strong>.</div>');
        return;
    end if;

    table_begin(
        'DCS Analyse Zusammenfassung',
        '<tr><th>Run</th><th>Erstellt am</th><th>Zeilen</th><th>Geparst</th><th>Ergebnis</th><th>Anzahl</th></tr>');

    for r in (
        select r.run_id,
               to_char(r.created_at, 'DD.MM.YYYY HH24:MI:SS') as erstellt_am,
               r.line_count,
               r.parsed_count,
               x.result_status,
               count(*) as anzahl
        from   mt_dcs_invalid_run r
        join   mt_dcs_invalid_result x on x.run_id = r.run_id
        where  r.run_id = :P12_RUN_ID
        group  by r.run_id, r.created_at, r.line_count, r.parsed_count, x.result_status
        order  by case x.result_status
                    when 'SOURCE_VALID_DCS_INVALID' then 1
                    when 'SOURCE_INVALID_DCS_INVALID' then 2
                    when 'SOURCE_LINK_ERROR' then 3
                    when 'NOT_FOUND_IN_PROD_SOURCE' then 4
                    else 5
                  end
    ) loop
        l_rows := l_rows + 1;
        htp.p('<tr><td>' || r.run_id || '</td><td>' || esc(r.erstellt_am) ||
              '</td><td>' || r.line_count || '</td><td>' || r.parsed_count ||
              '</td><td><strong>' || esc(r.result_status) || '</strong></td><td>' ||
              r.anzahl || '</td></tr>');
    end loop;

    if l_rows = 0 then
        htp.p('<tr><td colspan="6">Keine Ergebniszeilen fuer diesen Lauf gefunden.</td></tr>');
    end if;
    table_end;

    render_rule_helper;

    htp.p('<br>');
    l_rows := 0;
    table_begin(
        'DCS Invalid Vergleich Ergebnis',
        '<tr><th>Zeile</th><th>DCS Schema</th><th>Objekt</th><th>DCS Typ</th><th>Quelle Host</th><th>Quelle Service</th><th>Quelle Typ</th><th>Quelle Status</th><th>Ergebnis</th><th>Hinweis</th></tr>');

    for r in (
        select line_no,
               parsed_schema,
               object_name,
               nvl(parsed_object_type, '-') as parsed_object_type,
               nvl(source_host, '-') as source_host,
               nvl(source_service, '-') as source_service,
               nvl(source_object_type, '-') as source_object_type,
               nvl(source_status, '-') as source_status,
               result_status,
               hinweis
        from   mt_dcs_invalid_result
        where  run_id = :P12_RUN_ID
        and    result_status not in ('SOURCE_NOT_CONFIGURED', 'SOURCE_AMBIGUOUS')
        order  by case result_status
                    when 'SOURCE_VALID_DCS_INVALID' then 1
                    when 'SOURCE_INVALID_DCS_INVALID' then 2
                    when 'SOURCE_LINK_ERROR' then 3
                    when 'NOT_FOUND_IN_PROD_SOURCE' then 4
                    else 5
                  end,
                  parsed_schema, object_name, source_host, source_service
    ) loop
        l_rows := l_rows + 1;
        exit when l_rows > 300;
        htp.p('<tr><td>' || r.line_no ||
              '</td><td>' || esc(r.parsed_schema) ||
              '</td><td>' || esc(r.object_name) ||
              '</td><td>' || esc(r.parsed_object_type) ||
              '</td><td>' || esc(r.source_host) ||
              '</td><td>' || esc(r.source_service) ||
              '</td><td>' || esc(r.source_object_type) ||
              '</td><td>' || esc(r.source_status) ||
              '</td><td><strong>' || esc(r.result_status) ||
              '</strong></td><td>' || esc(r.hinweis) || '</td></tr>');
    end loop;

    if l_rows = 0 then
        htp.p('<tr><td colspan="10">Keine Details gefunden.</td></tr>');
    elsif l_rows > 300 then
        htp.p('<tr><td colspan="10">Ausgabe auf 300 Zeilen begrenzt.</td></tr>');
    end if;
    table_end;
exception
    when others then
        htp.p('<div class="t-Alert t-Alert--danger"><strong>DCS Analyse:</strong> ' ||
              esc(sqlerrm) || '</div>');
end;~',
        p_attributes              => wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
            'expand_shortcuts', 'N',
            'output_as',        'HTML',
            'show_line_breaks', 'N')).to_clob);

    wwv_flow_imp_page.create_page_process(
        p_id                     => wwv_flow_imp.id(91200000000000050),
        p_process_sequence       => 10,
        p_process_point          => 'AFTER_SUBMIT',
        p_process_type           => 'NATIVE_PLSQL',
        p_process_name           => 'DCS Invalid-Liste analysieren',
        p_process_sql_clob       => wwv_flow_string.join(wwv_flow_t_varchar2(
            'begin',
            '    if apex_application.g_request = ''REFRESH_DCS_INVENTORY'' then',
            '        mt_dcs_invalid_pkg.refresh_source_inventory;',
            '    elsif apex_application.g_request = ''SAVE_DCS_RULE'' then',
            '        merge into mt_dcs_schema_source_rule r',
            '        using (select upper(:P12_RULE_SCHEMA) as dcs_schema, upper(:P12_RULE_DBLINK) as source_dblink_name from dual) src',
            '        on (r.dcs_schema = src.dcs_schema and r.source_dblink_name = src.source_dblink_name)',
            '        when matched then update set r.aktiv = ''J'', r.kommentar = ''Manuell in APEX gesetzt''',
            '        when not matched then insert (dcs_schema, source_dblink_name, aktiv, kommentar)',
            '        values (src.dcs_schema, src.source_dblink_name, ''J'', ''Manuell in APEX gesetzt'');',
            '        update mt_dcs_schema_source_rule',
            '        set    aktiv = ''N''',
            '        where  dcs_schema = upper(:P12_RULE_SCHEMA)',
            '        and    source_dblink_name <> upper(:P12_RULE_DBLINK);',
            '        commit;',
            '        :P12_RUN_ID := mt_dcs_invalid_pkg.analyze(',
            '            p_raw_text   => :P12_INVALID_TEXT,',
            '            p_created_by => nvl(v(''APP_USER''), user));',
            '    elsif apex_application.g_request = ''ANALYZE_DCS'' then',
            '        declare',
            '            l_inventory_count number;',
            '        begin',
            '            select count(*) into l_inventory_count from mt_source_schema_inventory;',
            '            if l_inventory_count = 0 then',
            '                mt_dcs_invalid_pkg.refresh_source_inventory;',
            '            end if;',
            '        end;',
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
