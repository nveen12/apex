set echo on
set define off
whenever sqlerror exit sql.sqlcode rollback

-- =============================================================================
-- Migration Tracker - Page 9: FV Detail / Live Vergleich
-- Anwendung: 114  Workspace: MIGRATION  Schema: migration
-- Zielserver: rzhs440.ofd-h.de  (nicht verbinden; nur lokal ausfuehren)
--
-- Abhaengig von:
--   02_migration_tracker_ddl.sql  (Basistabellen)
--   05_schema_object_tracking.sql (mt_server.dblink_name)
--
-- TODO DBA: DB Links (RZHS184_LINK usw.) muessen auf rzhs440 vorhanden
-- sein, bevor die fuenf Vergleichs-Regionen Daten liefern koennen.
-- Solange Source- oder Target-DB-Link fehlt/nicht erreichbar ist, bleiben die
-- Regionen verborgen (Condition: P9_COMPARE_OK IS NOT NULL).
-- =============================================================================

declare
    l_workspace_id number;
    l_app_id       number;
begin
    select workspace_id
    into   l_workspace_id
    from   apex_workspaces
    where  workspace = 'MIGRATION';

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

    apex_util.set_security_group_id(l_workspace_id);

    wwv_flow_imp.import_begin(
        p_version_yyyy_mm_dd     => '2024.05.31',
        p_release                => '24.1.0',
        p_default_workspace_id   => l_workspace_id,
        p_default_application_id => l_app_id,
        p_default_id_offset      => 0,
        p_default_owner          => 'MIGRATION');

    -- Seite sauber neu erstellen (idempotent)
    wwv_flow_imp_page.remove_page(p_flow_id => l_app_id, p_page_id => 9);

    -- -------------------------------------------------------------------------
    -- Seite
    -- -------------------------------------------------------------------------
    wwv_flow_imp_page.create_page(
        p_id                    => 9,
        p_name                  => 'FV Detail / Live Vergleich',
        p_alias                 => 'FV-DETAIL-LIVE-VERGLEICH',
        p_step_title            => 'FV Detail / Live Vergleich',
        p_autocomplete_on_off   => 'OFF',
        p_page_template_options => '#DEFAULT#',
        p_protection_level      => 'C',
        p_page_component_map    => '03');

    -- -------------------------------------------------------------------------
    -- Schaltflaechen-Region (Dialog Footer)
    -- -------------------------------------------------------------------------
    wwv_flow_imp_page.create_page_plug(
        p_id                      => wwv_flow_imp.id(90000000000000090),
        p_plug_name               => 'Schaltflaechen',
        p_region_template_options => '#DEFAULT#',
        p_plug_template           => wwv_flow_imp.id(10774978406759760),
        p_plug_display_sequence   => 5,
        p_plug_display_point      => 'REGION_POSITION_03',
        p_attributes              => wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
            'expand_shortcuts', 'N',
            'output_as',        'TEXT',
            'show_line_breaks', 'Y')).to_clob);

    -- Abbrechen-Schaltflaeche
    wwv_flow_imp_page.create_page_button(
        p_id                      => wwv_flow_imp.id(90000000000000091),
        p_button_sequence         => 10,
        p_button_plug_id          => wwv_flow_imp.id(90000000000000090),
        p_button_name             => 'CANCEL',
        p_button_action           => 'DEFINED_BY_DA',
        p_button_template_options => '#DEFAULT#',
        p_button_template_id      => wwv_flow_imp.id(10892289891759782),
        p_button_image_alt        => 'Abbrechen',
        p_button_position         => 'CLOSE',
        p_button_alignment        => 'RIGHT');

    -- Dynamic Action: Dialog schliessen
    wwv_flow_imp_page.create_page_da_event(
        p_id                      => wwv_flow_imp.id(90000000000000092),
        p_name                    => 'Dialog schliessen',
        p_event_sequence          => 10,
        p_triggering_element_type => 'BUTTON',
        p_triggering_button_id    => wwv_flow_imp.id(90000000000000091),
        p_bind_type               => 'bind',
        p_execution_type          => 'IMMEDIATE',
        p_bind_event_type         => 'click');

    wwv_flow_imp_page.create_page_da_action(
        p_id                   => wwv_flow_imp.id(90000000000000093),
        p_event_id             => wwv_flow_imp.id(90000000000000092),
        p_event_result         => 'TRUE',
        p_action_sequence      => 10,
        p_execute_on_page_init => 'N',
        p_action               => 'NATIVE_DIALOG_CANCEL');

    -- -------------------------------------------------------------------------
    -- Verborgene Seitenelemente
    -- -------------------------------------------------------------------------
    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(90000000000000002),
        p_name             => 'P9_MAPPING_ID',
        p_item_sequence    => 5,
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(90000000000000012),
        p_name             => 'P9_FV_ID',
        p_item_sequence    => 10,
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(90000000000000003),
        p_name             => 'P9_SCHEMA_NAME',
        p_item_sequence    => 20,
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(90000000000000004),
        p_name             => 'P9_SRC_DBLINK_NAME',
        p_item_sequence    => 30,
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(90000000000000005),
        p_name             => 'P9_TGT_DBLINK_NAME',
        p_item_sequence    => 35,
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(90000000000000008),
        p_name             => 'P9_COMPARE_OK',
        p_item_sequence    => 38,
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(90000000000000013),
        p_name             => 'P9_MIGRATION_DATE',
        p_item_sequence    => 40,
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(90000000000000014),
        p_name             => 'P9_STATUS_TEXT',
        p_item_sequence    => 45,
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_item(
        p_id               => wwv_flow_imp.id(90000000000000016),
        p_name             => 'P9_CLASSIC_REPORTS_DISABLED',
        p_item_sequence    => 50,
        p_display_as       => 'NATIVE_HIDDEN',
        p_protection_level => 'S',
        p_attribute_01     => 'Y');

    wwv_flow_imp_page.create_page_plug(
        p_id                      => wwv_flow_imp.id(90000000000000015),
        p_plug_name               => 'Live Vergleich Status',
        p_title                   => 'Live Vergleich Status',
        p_plug_template           => wwv_flow_imp.id(10818657374759767),
        p_region_template_options => '#DEFAULT#',
        p_plug_display_sequence   => 8,
        p_plug_display_point      => 'BODY',
        p_plug_source             => '<strong>Status:</strong> &P9_STATUS_TEXT.',
        p_attributes              => wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
            'expand_shortcuts', 'N',
            'output_as',        'HTML',
            'show_line_breaks', 'N')).to_clob);

    wwv_flow_imp_page.create_page_plug(
        p_id                      => wwv_flow_imp.id(90000000000000017),
        p_plug_name               => 'Live Vergleich Ergebnisse',
        p_title                   => 'Live Vergleich Ergebnisse',
        p_plug_template           => wwv_flow_imp.id(10818657374759767),
        p_region_template_options => '#DEFAULT#:t-Region--scrollBody',
        p_plug_display_sequence   => 9,
        p_plug_display_point      => 'BODY',
        p_plug_source_type        => 'NATIVE_PLSQL',
        p_plug_source             => q'~declare
    l_src_link varchar2(261);
    l_tgt_link varchar2(261);
    l_filter   varchar2(32767);
    l_sql      varchar2(32767);

    function esc(p_text in varchar2) return varchar2 is
    begin
        return apex_escape.html(p_text);
    end;

    procedure print_section(
        p_title in varchar2,
        p_sql   in varchar2
    ) is
        c       integer;
        rc      integer;
        l_rows  number := 0;
        v1      varchar2(4000);
        v2      varchar2(4000);
        v3      varchar2(4000);
        v4      varchar2(4000);
        v5      varchar2(4000);
    begin
        htp.p('<h3>' || esc(p_title) || '</h3>');
        htp.p('<table class="t-Report-report"><thead><tr>' ||
              '<th>Element</th><th>Quelle</th><th>Ziel</th><th>Status</th><th>Info</th>' ||
              '</tr></thead><tbody>');

        c := dbms_sql.open_cursor;
        dbms_sql.parse(c, p_sql, dbms_sql.native);
        dbms_sql.define_column(c, 1, v1, 4000);
        dbms_sql.define_column(c, 2, v2, 4000);
        dbms_sql.define_column(c, 3, v3, 4000);
        dbms_sql.define_column(c, 4, v4, 4000);
        dbms_sql.define_column(c, 5, v5, 4000);
        rc := dbms_sql.execute(c);

        loop
            exit when dbms_sql.fetch_rows(c) = 0 or l_rows >= 200;
            dbms_sql.column_value(c, 1, v1);
            dbms_sql.column_value(c, 2, v2);
            dbms_sql.column_value(c, 3, v3);
            dbms_sql.column_value(c, 4, v4);
            dbms_sql.column_value(c, 5, v5);
            l_rows := l_rows + 1;

            htp.p('<tr><td>' || esc(v1) || '</td><td>' || esc(v2) ||
                  '</td><td>' || esc(v3) || '</td><td>' || esc(v4) ||
                  '</td><td>' || esc(v5) || '</td></tr>');
        end loop;

        dbms_sql.close_cursor(c);

        if l_rows = 0 then
            htp.p('<tr><td colspan="5">Keine Daten gefunden.</td></tr>');
        elsif l_rows >= 200 then
            htp.p('<tr><td colspan="5">Ausgabe auf 200 Zeilen begrenzt.</td></tr>');
        end if;

        htp.p('</tbody></table>');
    exception
        when others then
            if dbms_sql.is_open(c) then
                dbms_sql.close_cursor(c);
            end if;
            htp.p('<div class="t-Alert t-Alert--warning"><strong>' ||
                  esc(p_title) || ':</strong> ' || esc(sqlerrm) || '</div>');
    end;
begin
    if :P9_COMPARE_OK is null then
        htp.p('<div class="t-Alert t-Alert--warning">Kein Vergleich moeglich: ' ||
              esc(:P9_STATUS_TEXT) || '</div>');
        return;
    end if;

    l_src_link := dbms_assert.simple_sql_name(:P9_SRC_DBLINK_NAME);
    l_tgt_link := dbms_assert.simple_sql_name(:P9_TGT_DBLINK_NAME);

    if :P9_SCHEMA_NAME = '__ALL_APP_SCHEMAS__' then
        l_filter := 'owner not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',' ||
                    '''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',' ||
                    '''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',' ||
                    '''PUBLIC'',''APEX_PUBLIC_USER'',''APEX_LISTENER'',''ORDS_PUBLIC_USER'',' ||
                    '''ORDS_METADATA'',''FLOWS_FILES'',''REMOTE_SCHEDULER_AGENT'',''DBSFWUSER'',' ||
                    '''ORACLE_OCM'',''OLAPSYS'',''SI_INFORMTN_SCHEMA'',''MDDATA'',''ANONYMOUS'',' ||
                    '''MIGRATION'')' ||
                    ' and owner not like ''APEX\_%'' escape ''\''';
    else
        l_filter := 'owner = ''' || replace(upper(:P9_SCHEMA_NAME), '''', '''''') || '''';
    end if;

    l_sql :=
        'with src as (' ||
        '  select owner||''.''||object_type element, count(*) cnt' ||
        '  from all_objects@' || l_src_link ||
        '  where ' || l_filter ||
        '  and object_type in (''TABLE'',''VIEW'',''PROCEDURE'',''FUNCTION'',' ||
        '                      ''PACKAGE'',''PACKAGE BODY'',''TRIGGER'',''SEQUENCE'',' ||
        '                      ''INDEX'',''SYNONYM'',''TYPE'',''TYPE BODY'')' ||
        '  and object_name not like ''BIN$%''' ||
        '  group by owner, object_type' ||
        '), tgt as (' ||
        '  select owner||''.''||object_type element, count(*) cnt' ||
        '  from all_objects@' || l_tgt_link ||
        '  where ' || l_filter ||
        '  and object_type in (''TABLE'',''VIEW'',''PROCEDURE'',''FUNCTION'',' ||
        '                      ''PACKAGE'',''PACKAGE BODY'',''TRIGGER'',''SEQUENCE'',' ||
        '                      ''INDEX'',''SYNONYM'',''TYPE'',''TYPE BODY'')' ||
        '  and object_name not like ''BIN$%''' ||
        '  group by owner, object_type' ||
        ') select coalesce(src.element,tgt.element),' ||
        '         to_char(nvl(src.cnt,0)), to_char(nvl(tgt.cnt,0)),' ||
        '         case when nvl(src.cnt,0)=nvl(tgt.cnt,0) then ''OK'' else ''DIFF'' end,' ||
        '         null' ||
        '  from src full outer join tgt on tgt.element=src.element' ||
        '  order by 1';
    print_section('Objektanzahl nach Schema und Typ', l_sql);

    l_sql :=
        'select ''QUELLE: ''||owner||''.''||object_name, object_type, status,' ||
        '       to_char(last_ddl_time,''DD.MM.YYYY HH24:MI''), null' ||
        '  from all_objects@' || l_src_link ||
        ' where ' || l_filter || ' and status <> ''VALID'' and object_name not like ''BIN$%''' ||
        ' union all ' ||
        'select ''ZIEL: ''||owner||''.''||object_name, object_type, status,' ||
        '       to_char(last_ddl_time,''DD.MM.YYYY HH24:MI''), null' ||
        '  from all_objects@' || l_tgt_link ||
        ' where ' || l_filter || ' and status <> ''VALID'' and object_name not like ''BIN$%''' ||
        ' order by 1';
    print_section('Ungueltige Objekte', l_sql);

    l_sql :=
        'select owner||''.''||object_name, object_type, status,' ||
        '       to_char(last_ddl_time,''DD.MM.YYYY HH24:MI''), ''Quelle nach Referenzdatum geaendert''' ||
        '  from all_objects@' || l_src_link ||
        ' where ' || l_filter ||
        '   and last_ddl_time > to_date(''' || :P9_MIGRATION_DATE || ''',''YYYY-MM-DD'')' ||
        '   and object_name not like ''BIN$%''' ||
        ' order by last_ddl_time desc';
    print_section('Forward Changes auf Quelle', l_sql);

    l_sql :=
        'with src as (' ||
        '  select nvl(tablespace_name,''<NULL>'') element, count(*) cnt' ||
        '  from all_tables@' || l_src_link || ' where ' || l_filter ||
        '  group by nvl(tablespace_name,''<NULL>'')' ||
        '), tgt as (' ||
        '  select nvl(tablespace_name,''<NULL>'') element, count(*) cnt' ||
        '  from all_tables@' || l_tgt_link || ' where ' || l_filter ||
        '  group by nvl(tablespace_name,''<NULL>'')' ||
        ') select coalesce(src.element,tgt.element),' ||
        '         to_char(nvl(src.cnt,0)), to_char(nvl(tgt.cnt,0)),' ||
        '         case when nvl(src.cnt,0)=nvl(tgt.cnt,0) then ''OK'' else ''DIFF'' end,' ||
        '         null' ||
        '  from src full outer join tgt on tgt.element=src.element' ||
        '  order by 1';
    print_section('Tablespace-Vergleich', l_sql);

    l_sql :=
        'with src as (' ||
        '  select application_id, application_name, workspace,' ||
        '         (select count(*) from apex_application_pages@' || l_src_link ||
        '           p where p.application_id = a.application_id) pages' ||
        '    from apex_applications@' || l_src_link ||
        '         a where upper(workspace) not in (''INTERNAL'',''MIGRATION'',''COM.ORACLE.CUST.REPOSITORY'')' ||
        '), tgt as (' ||
        '  select application_id, application_name, workspace,' ||
        '         (select count(*) from apex_application_pages@' || l_tgt_link ||
        '           p where p.application_id = a.application_id) pages' ||
        '    from apex_applications@' || l_tgt_link ||
        '         a where upper(workspace) not in (''INTERNAL'',''MIGRATION'',''COM.ORACLE.CUST.REPOSITORY'')' ||
        ') select to_char(coalesce(src.application_id,tgt.application_id))||'' ''||' ||
        '         coalesce(src.application_name,tgt.application_name),' ||
        '         src.workspace||'' / Seiten ''||src.pages,' ||
        '         tgt.workspace||'' / Seiten ''||tgt.pages,' ||
        '         case when src.application_id is null then ''NUR_ZIEL''' ||
        '              when tgt.application_id is null then ''NUR_QUELLE''' ||
        '              when nvl(src.pages,-1)=nvl(tgt.pages,-1) then ''OK'' else ''DIFF'' end,' ||
        '         null' ||
        '  from src full outer join tgt on tgt.application_id=src.application_id' ||
        '                            and tgt.application_name=src.application_name' ||
        '  order by 1';
    print_section('APEX-Anwendungen', l_sql);
end;~',
        p_plug_display_condition_type => 'ITEM_IS_NOT_NULL',
        p_plug_display_when_condition => 'P9_COMPARE_OK');

    -- -------------------------------------------------------------------------
    -- Before Header 1: Source/Target DB Links aus gewaehltem Mapping ableiten
    -- -------------------------------------------------------------------------
    wwv_flow_imp_page.create_page_process(
        p_id                     => wwv_flow_imp.id(90000000000000006),
        p_process_sequence       => 10,
        p_process_point          => 'BEFORE_HEADER',
        p_process_type           => 'NATIVE_PLSQL',
        p_process_name           => 'Source und Target DB Links ableiten',
        p_process_sql_clob       => wwv_flow_string.join(wwv_flow_t_varchar2(
            'begin',
            '    :P9_SRC_DBLINK_NAME := null;',
            '    :P9_TGT_DBLINK_NAME := null;',
            '    :P9_STATUS_TEXT := null;',
            '',
            '    select src_dblink_name, tgt_dblink_name',
            '    into   :P9_SRC_DBLINK_NAME, :P9_TGT_DBLINK_NAME',
            '    from (',
            '        select sp.dblink_name as src_dblink_name,',
            '               tp.dblink_name as tgt_dblink_name,',
            '               row_number() over (order by case',
            '                   when nvl(sp.tier, ''-'') = nvl(tp.tier, ''-'') then 0',
            '                   else 1',
            '               end, sp.pdb_id) rn',
            '        from   mt_fv_pdb_mapping tm',
            '        join   mt_pdb tp on tp.pdb_id = tm.pdb_id',
            '        join   mt_fv_pdb_mapping sm on sm.fv_id = tm.fv_id',
            '        join   mt_pdb sp on sp.pdb_id = sm.pdb_id',
            '        where  tm.mapping_id = :P9_MAPPING_ID',
            '        and    tm.mapping_role = ''WORKBENCH''',
            '        and    sm.mapping_role = ''QUELLE''',
            '        and    nvl(tm.aktiv, ''J'') = ''J''',
            '        and    nvl(sm.aktiv, ''J'') = ''J''',
            '    )',
            '    where rn = 1;',
            '',
            '    :P9_STATUS_TEXT := ''Quelle: '' || nvl(:P9_SRC_DBLINK_NAME, ''kein SRC-Link'')',
            '        || '' / Ziel: '' || nvl(:P9_TGT_DBLINK_NAME, ''kein TGT-Link'')',
            '        || case when :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__''',
            '                then '' / Scope: alle Anwendungsschemas im Service''',
            '                else '' / Scope: Schema '' || upper(:P9_SCHEMA_NAME)',
            '           end;',
            'exception',
            '    when no_data_found then',
            '        :P9_SRC_DBLINK_NAME := null;',
            '        :P9_TGT_DBLINK_NAME := null;',
            '        :P9_STATUS_TEXT := ''Kein Source/Target-Mapping fuer diese Auswahl gefunden.'';',
            'end;')),
        p_error_display_location => 'INLINE_IN_NOTIFICATION',
        p_internal_uid           => 90000000000000006);

    -- -------------------------------------------------------------------------
    -- Before Header 2: Migrationsdatum aus mt_migration_checklist ableiten
    -- -------------------------------------------------------------------------
    wwv_flow_imp_page.create_page_process(
        p_id                     => wwv_flow_imp.id(90000000000000007),
        p_process_sequence       => 20,
        p_process_point          => 'BEFORE_HEADER',
        p_process_type           => 'NATIVE_PLSQL',
        p_process_name           => 'Migrationsdatum ableiten',
        p_process_sql_clob       => wwv_flow_string.join(wwv_flow_t_varchar2(
            'begin',
            '    -- Letztes Go-Live-Datum als Referenz; Fallback: SYSDATE - 90',
            '    select to_char(nvl(max(golive_datum), sysdate - 90), ''YYYY-MM-DD'')',
            '    into   :P9_MIGRATION_DATE',
            '    from   mt_migration_checklist',
            '    where  fv_id = :P9_FV_ID;',
            'exception',
            '    when no_data_found then',
            '        :P9_MIGRATION_DATE := to_char(sysdate - 90, ''YYYY-MM-DD'');',
            'end;')),
        p_error_display_location => 'INLINE_IN_NOTIFICATION',
        p_internal_uid           => 90000000000000007);

    -- -------------------------------------------------------------------------
    -- Before Header 3: Source/Target DB Links testen
    -- -------------------------------------------------------------------------
    wwv_flow_imp_page.create_page_process(
        p_id                     => wwv_flow_imp.id(90000000000000009),
        p_process_sequence       => 30,
        p_process_point          => 'BEFORE_HEADER',
        p_process_type           => 'NATIVE_PLSQL',
        p_process_name           => 'Source und Target DB Links testen',
        p_process_sql_clob       => wwv_flow_string.join(wwv_flow_t_varchar2(
            'declare',
            '    l_dummy number;',
            'begin',
            '    :P9_COMPARE_OK := null;',
            '    if :P9_SRC_DBLINK_NAME is null or :P9_TGT_DBLINK_NAME is null then',
            '        :P9_STATUS_TEXT := nvl(:P9_STATUS_TEXT, ''DB-Link fehlt.'') || '' Vergleich nicht moeglich.'';',
            '    elsif :P9_SRC_DBLINK_NAME like ''##%##'' or :P9_TGT_DBLINK_NAME like ''##%##'' then',
            '        :P9_STATUS_TEXT := :P9_STATUS_TEXT || '' / TODO: Platzhalter-DB-Link ersetzen.'';',
            '    else',
            '        execute immediate',
            '            ''select 1 from dual@'' || dbms_assert.simple_sql_name(:P9_SRC_DBLINK_NAME)',
            '            into l_dummy;',
            '        execute immediate',
            '            ''select 1 from dual@'' || dbms_assert.simple_sql_name(:P9_TGT_DBLINK_NAME)',
            '            into l_dummy;',
            '        :P9_COMPARE_OK := ''J'';',
            '        :P9_STATUS_TEXT := :P9_STATUS_TEXT || '' / DB-Links erreichbar. Vergleich wird ausgefuehrt.'';',
            '    end if;',
            'exception',
            '    when others then',
            '        :P9_COMPARE_OK := null;',
            '        :P9_STATUS_TEXT := nvl(:P9_STATUS_TEXT, ''DB-Link-Test'') || '' / Fehler: '' || sqlerrm;',
            'end;')),
        p_error_display_location => 'INLINE_IN_NOTIFICATION',
        p_internal_uid           => 90000000000000009);

    -- =========================================================================
    -- Vergleichs-Regionen A-E
    -- Alle Regionen: Condition = P9_COMPARE_OK IS NOT NULL
    -- =========================================================================

    -- -------------------------------------------------------------------------
    -- Region A: Objektanzahl nach Typ — Quelle vs. Ziel
    -- Quelle: all_objects@<source dblink> / Ziel: all_objects@<target dblink>
    -- -------------------------------------------------------------------------
    wwv_flow_imp_page.create_report_region(
        p_id                         => wwv_flow_imp.id(90000000000000010),
        p_name                       => 'Objektanzahl nach Typ: Quelle vs. Ziel',
        p_title                      => 'Objektanzahl nach Typ: Quelle vs. Ziel',
        p_template                   => wwv_flow_imp.id(10818657374759767),
        p_display_sequence           => 10,
        p_region_template_options    => '#DEFAULT#:t-Region--scrollBody',
        p_component_template_options => '#DEFAULT#:t-Report--altRowsDefault:t-Report--rowHighlight',
        p_source_type                => 'NATIVE_SQL_REPORT',
        p_query_type                 => 'SQL',
        p_source                     => wwv_flow_string.join(wwv_flow_t_varchar2(
            'with data as (',
            '    select coalesce(src.object_type, tgt.object_type) as typ,',
            '           nvl(src.object_count, 0)                   as quelle,',
            '           nvl(tgt.object_count, 0)                   as ziel,',
            '           case',
            '               when nvl(src.object_count, 0) = nvl(tgt.object_count, 0) then ''OK''',
            '               else ''DIFF''',
            '           end                                        as diff',
            '    from (',
            '        select owner || ''.'' || object_type object_type, count(*) object_count',
            '        from   all_objects@&P9_SRC_DBLINK_NAME.',
            '        where  (',
            '                   owner = upper(:P9_SCHEMA_NAME)',
            '                   or (',
            '                       :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__''',
            '                       and owner not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',',
            '                                         ''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',',
            '                                         ''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',',
            '                                         ''APEX_240100'',''APEX_PUBLIC_USER'',''ORDS_PUBLIC_USER'')',
            '                   )',
            '               )',
            '        and    object_type in (''TABLE'',''VIEW'',''PROCEDURE'',''FUNCTION'',',
            '                               ''PACKAGE'',''PACKAGE BODY'',''TRIGGER'',''SEQUENCE'',',
            '                               ''INDEX'',''SYNONYM'',''TYPE'',''TYPE BODY'')',
            '        and    object_name not like ''BIN$%''',
            '        group  by owner, object_type',
            '    ) src',
            '    full outer join (',
            '        select owner || ''.'' || object_type object_type, count(*) object_count',
            '        from   all_objects@&P9_TGT_DBLINK_NAME.',
            '        where  (',
            '                   owner = upper(:P9_SCHEMA_NAME)',
            '                   or (',
            '                       :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__''',
            '                       and owner not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',',
            '                                         ''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',',
            '                                         ''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',',
            '                                         ''APEX_240100'',''APEX_PUBLIC_USER'',''ORDS_PUBLIC_USER'')',
            '                   )',
            '               )',
            '        and    object_type in (''TABLE'',''VIEW'',''PROCEDURE'',''FUNCTION'',',
            '                               ''PACKAGE'',''PACKAGE BODY'',''TRIGGER'',''SEQUENCE'',',
            '                               ''INDEX'',''SYNONYM'',''TYPE'',''TYPE BODY'')',
            '        and    object_name not like ''BIN$%''',
            '        group  by owner, object_type',
            '    ) tgt on tgt.object_type = src.object_type',
            ')',
            'select typ as "Typ", quelle as "Quelle", ziel as "Ziel", diff as "Diff"',
            'from   data',
            'union all',
            'select case when :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__''',
            '            then ''Keine Anwendungsobjekte gefunden''',
            '            else ''Keine Objekte fuer Schema '' || upper(:P9_SCHEMA_NAME)',
            '       end, 0, 0, ''INFO''',
            'from   dual',
            'where  not exists (select 1 from data)',
            'order by 1')),
        p_display_when_condition      => 'P9_CLASSIC_REPORTS_DISABLED',
        p_display_condition_type      => 'ITEM_IS_NOT_NULL',
        p_ajax_enabled                => 'Y',
        p_lazy_loading                => false,
        p_query_row_template          => wwv_flow_imp.id(10845430908759771),
        p_query_num_rows              => 20,
        p_query_options               => 'DERIVED_REPORT_COLUMNS',
        p_query_num_rows_type         => 'NEXT_PREVIOUS_LINKS',
        p_pagination_display_position => 'BOTTOM_RIGHT',
        p_csv_output                  => 'N',
        p_prn_output                  => 'N',
        p_sort_null                   => 'L',
        p_plug_query_strip_html       => 'N');

    -- -------------------------------------------------------------------------
    -- Region B: Ungueltige Objekte — Quelle und Ziel
    -- -------------------------------------------------------------------------
    wwv_flow_imp_page.create_report_region(
        p_id                         => wwv_flow_imp.id(90000000000000020),
        p_name                       => unistr('Ung\00FCltige Objekte'),
        p_title                      => unistr('Ung\00FCltige Objekte'),
        p_template                   => wwv_flow_imp.id(10818657374759767),
        p_display_sequence           => 20,
        p_region_template_options    => '#DEFAULT#:t-Region--scrollBody',
        p_component_template_options => '#DEFAULT#:t-Report--altRowsDefault:t-Report--rowHighlight',
        p_source_type                => 'NATIVE_SQL_REPORT',
        p_query_type                 => 'SQL',
        p_source                     => wwv_flow_string.join(wwv_flow_t_varchar2(
            'with data as (',
            '    select ''QUELLE''      as seite,',
            '           owner || ''.'' || object_name as objekt,',
            '           object_type    as typ,',
            '           status         as status,',
            '           to_char(last_ddl_time, ''DD.MM.YYYY HH24:MI'') as letzte_aenderung',
            '    from   all_objects@&P9_SRC_DBLINK_NAME.',
            '    where  (',
            '               owner = upper(:P9_SCHEMA_NAME)',
            '               or (',
            '                   :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__''',
            '                   and owner not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',',
            '                                     ''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',',
            '                                     ''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',',
            '                                     ''APEX_240100'',''APEX_PUBLIC_USER'',''ORDS_PUBLIC_USER'')',
            '               )',
            '           )',
            '    and    status <> ''VALID''',
            '    and    object_name not like ''BIN$%''',
            '    union all',
            '    select ''ZIEL'',',
            '           owner || ''.'' || object_name,',
            '           object_type,',
            '           status,',
            '           to_char(last_ddl_time, ''DD.MM.YYYY HH24:MI'')',
            '    from   all_objects@&P9_TGT_DBLINK_NAME.',
            '    where  (',
            '               owner = upper(:P9_SCHEMA_NAME)',
            '               or (',
            '                   :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__''',
            '                   and owner not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',',
            '                                     ''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',',
            '                                     ''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',',
            '                                     ''APEX_240100'',''APEX_PUBLIC_USER'',''ORDS_PUBLIC_USER'')',
            '               )',
            '           )',
            '    and    status <> ''VALID''',
            '    and    object_name not like ''BIN$%''',
            ')',
            'select seite as "Seite", objekt as "Objekt", typ as "Typ",',
            '       status as "Status", letzte_aenderung as "Letzte Aenderung"',
            'from   data',
            'union all',
            'select ''INFO'', ''Keine ungueltigen Objekte'', ''-'', ''OK'', null',
            'from   dual',
            'where  not exists (select 1 from data)',
            'order by 1, 3, 2')),
        p_display_when_condition      => 'P9_CLASSIC_REPORTS_DISABLED',
        p_display_condition_type      => 'ITEM_IS_NOT_NULL',
        p_ajax_enabled                => 'Y',
        p_lazy_loading                => false,
        p_query_row_template          => wwv_flow_imp.id(10845430908759771),
        p_query_num_rows              => 20,
        p_query_options               => 'DERIVED_REPORT_COLUMNS',
        p_query_num_rows_type         => 'NEXT_PREVIOUS_LINKS',
        p_pagination_display_position => 'BOTTOM_RIGHT',
        p_csv_output                  => 'N',
        p_prn_output                  => 'N',
        p_sort_null                   => 'L',
        p_plug_query_strip_html       => 'N');

    -- -------------------------------------------------------------------------
    -- Region C: Forward Changes auf Quelle nach Migrationsdatum
    -- -------------------------------------------------------------------------
    wwv_flow_imp_page.create_report_region(
        p_id                         => wwv_flow_imp.id(90000000000000030),
        p_name                       => 'Forward Changes auf Quelle',
        p_title                      => 'Forward Changes auf Quelle',
        p_template                   => wwv_flow_imp.id(10818657374759767),
        p_display_sequence           => 30,
        p_region_template_options    => '#DEFAULT#:t-Region--scrollBody',
        p_component_template_options => '#DEFAULT#:t-Report--altRowsDefault:t-Report--rowHighlight',
        p_source_type                => 'NATIVE_SQL_REPORT',
        p_query_type                 => 'SQL',
        p_source                     => wwv_flow_string.join(wwv_flow_t_varchar2(
            'with data as (',
            '    select owner || ''.'' || object_name as objekt,',
            '           object_type  as typ,',
            '           status       as status,',
            '           last_ddl_time,',
            '           to_char(last_ddl_time, ''DD.MM.YYYY HH24:MI'') as geaendert_am',
            '    from   all_objects@&P9_SRC_DBLINK_NAME.',
            '    where  (',
            '               owner = upper(:P9_SCHEMA_NAME)',
            '               or (',
            '                   :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__''',
            '                   and owner not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',',
            '                                     ''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',',
            '                                     ''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',',
            '                                     ''APEX_240100'',''APEX_PUBLIC_USER'',''ORDS_PUBLIC_USER'')',
            '               )',
            '           )',
            '    and    last_ddl_time > to_date(:P9_MIGRATION_DATE, ''YYYY-MM-DD'')',
            '    and    object_name not like ''BIN$%''',
            ')',
            'select objekt as "Objekt", typ as "Typ", status as "Status",',
            '       geaendert_am as "Geaendert am"',
            'from   data',
            'union all',
            'select ''Keine Forward Changes seit '' || to_char(to_date(:P9_MIGRATION_DATE, ''YYYY-MM-DD''), ''DD.MM.YYYY''),',
            '       ''-'', ''OK'', null',
            'from   dual',
            'where  not exists (select 1 from data)',
            'order by 4 desc nulls last, 2, 1')),
        p_display_when_condition      => 'P9_CLASSIC_REPORTS_DISABLED',
        p_display_condition_type      => 'ITEM_IS_NOT_NULL',
        p_ajax_enabled                => 'Y',
        p_lazy_loading                => false,
        p_query_row_template          => wwv_flow_imp.id(10845430908759771),
        p_query_num_rows              => 20,
        p_query_options               => 'DERIVED_REPORT_COLUMNS',
        p_query_num_rows_type         => 'NEXT_PREVIOUS_LINKS',
        p_pagination_display_position => 'BOTTOM_RIGHT',
        p_csv_output                  => 'N',
        p_prn_output                  => 'N',
        p_sort_null                   => 'L',
        p_plug_query_strip_html       => 'N');

    -- -------------------------------------------------------------------------
    -- Region D: Tablespace-Vergleich
    -- -------------------------------------------------------------------------
    wwv_flow_imp_page.create_report_region(
        p_id                         => wwv_flow_imp.id(90000000000000040),
        p_name                       => 'Tablespace-Vergleich',
        p_title                      => 'Tablespace-Vergleich',
        p_template                   => wwv_flow_imp.id(10818657374759767),
        p_display_sequence           => 40,
        p_region_template_options    => '#DEFAULT#:t-Region--scrollBody',
        p_component_template_options => '#DEFAULT#:t-Report--altRowsDefault:t-Report--rowHighlight',
        p_source_type                => 'NATIVE_SQL_REPORT',
        p_query_type                 => 'SQL',
        p_source                     => wwv_flow_string.join(wwv_flow_t_varchar2(
            'with data as (',
            '    select coalesce(src.tablespace_name, tgt.tablespace_name) as tablespace_name,',
            '           nvl(src.table_count, 0)                            as tabellen_quelle,',
            '           nvl(tgt.table_count, 0)                            as tabellen_ziel,',
            '           case',
            '               when src.tablespace_name is null              then ''NUR_ZIEL''',
            '               when tgt.tablespace_name is null              then ''NUR_QUELLE''',
            '               when src.table_count = tgt.table_count        then ''OK''',
            '               else ''DIFF''',
            '           end                                               as status',
            '    from (',
            '        select nvl(tablespace_name, ''<NULL>'') tablespace_name,',
            '               count(*) table_count',
            '        from   all_tables@&P9_SRC_DBLINK_NAME.',
            '        where  (',
            '                   owner = upper(:P9_SCHEMA_NAME)',
            '                   or (',
            '                       :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__''',
            '                       and owner not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',',
            '                                         ''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',',
            '                                         ''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',',
            '                                         ''APEX_240100'',''APEX_PUBLIC_USER'',''ORDS_PUBLIC_USER'')',
            '                   )',
            '               )',
            '        group  by nvl(tablespace_name, ''<NULL>'')',
            '    ) src',
            '    full outer join (',
            '        select nvl(tablespace_name, ''<NULL>'') tablespace_name,',
            '               count(*) table_count',
            '        from   all_tables@&P9_TGT_DBLINK_NAME.',
            '        where  (',
            '                   owner = upper(:P9_SCHEMA_NAME)',
            '                   or (',
            '                       :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__''',
            '                       and owner not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',',
            '                                         ''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',',
            '                                         ''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',',
            '                                         ''APEX_240100'',''APEX_PUBLIC_USER'',''ORDS_PUBLIC_USER'')',
            '                   )',
            '               )',
            '        group  by nvl(tablespace_name, ''<NULL>'')',
            '    ) tgt on tgt.tablespace_name = src.tablespace_name',
            ')',
            'select tablespace_name as "Tablespace", tabellen_quelle as "Tabellen Quelle",',
            '       tabellen_ziel as "Tabellen Ziel", status as "Status"',
            'from   data',
            'union all',
            'select case when :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__''',
            '            then ''Keine Anwendungstabellen gefunden''',
            '            else ''Keine Tabellen fuer Schema '' || upper(:P9_SCHEMA_NAME)',
            '       end, 0, 0, ''INFO''',
            'from   dual',
            'where  not exists (select 1 from data)',
            'order by 1')),
        p_display_when_condition      => 'P9_CLASSIC_REPORTS_DISABLED',
        p_display_condition_type      => 'ITEM_IS_NOT_NULL',
        p_ajax_enabled                => 'Y',
        p_lazy_loading                => false,
        p_query_row_template          => wwv_flow_imp.id(10845430908759771),
        p_query_num_rows              => 20,
        p_query_options               => 'DERIVED_REPORT_COLUMNS',
        p_query_num_rows_type         => 'NEXT_PREVIOUS_LINKS',
        p_pagination_display_position => 'BOTTOM_RIGHT',
        p_csv_output                  => 'N',
        p_prn_output                  => 'N',
        p_sort_null                   => 'L',
        p_plug_query_strip_html       => 'N');

    -- -------------------------------------------------------------------------
    -- Region E: APEX-Anwendungen Vergleich
    --
    -- TODO DBA/APEX: Bestaetigen ob workspace_name = schema_name gilt fuer
    -- jedes Fachverfahren. Falls nicht: eigenes Bind-Item / Tabellenspalte
    -- hinzufuegen.
    -- -------------------------------------------------------------------------
    wwv_flow_imp_page.create_report_region(
        p_id                         => wwv_flow_imp.id(90000000000000050),
        p_name                       => 'APEX-Anwendungen Vergleich',
        p_title                      => 'APEX-Anwendungen Vergleich',
        p_template                   => wwv_flow_imp.id(10818657374759767),
        p_display_sequence           => 50,
        p_region_template_options    => '#DEFAULT#:t-Region--scrollBody',
        p_component_template_options => '#DEFAULT#:t-Report--altRowsDefault:t-Report--rowHighlight',
        p_source_type                => 'NATIVE_SQL_REPORT',
        p_query_type                 => 'SQL',
        p_source                     => wwv_flow_string.join(wwv_flow_t_varchar2(
            'with data as (',
            '    select coalesce(src.application_id,   tgt.application_id)   as application_id,',
            '           coalesce(src.application_name, tgt.application_name) as application_name,',
            '           src.workspace   as workspace_quelle,',
            '           tgt.workspace   as workspace_ziel,',
            '           src.page_count  as seiten_quelle,',
            '           tgt.page_count  as seiten_ziel,',
            '           to_char(src.last_updated_on, ''DD.MM.YYYY'') as stand_quelle,',
            '           to_char(tgt.last_updated_on, ''DD.MM.YYYY'') as stand_ziel,',
            '           case',
            '               when src.application_id is null                           then ''NUR_ZIEL''',
            '               when tgt.application_id is null                           then ''NUR_QUELLE''',
            '               when nvl(src.page_count, -1) = nvl(tgt.page_count, -1)   then ''OK''',
            '               else ''DIFF''',
            '           end                                                           as status',
            '    from (',
            '        select a.application_id,',
            '               a.application_name,',
            '               a.workspace,',
            '               (select count(*)',
            '                from   apex_application_pages@&P9_SRC_DBLINK_NAME. p',
            '                where  p.application_id = a.application_id) as page_count,',
            '               a.last_updated_on',
            '        from   apex_applications@&P9_SRC_DBLINK_NAME. a',
            '        where  (upper(a.workspace) = upper(:P9_SCHEMA_NAME)',
            '                or :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__'')',
            '        and    upper(a.workspace) not in (''INTERNAL'')',
            '    ) src',
            '    full outer join (',
            '        select a.application_id,',
            '               a.application_name,',
            '               a.workspace,',
            '               (select count(*)',
            '                from   apex_application_pages@&P9_TGT_DBLINK_NAME. p',
            '                where  p.application_id = a.application_id) as page_count,',
            '               a.last_updated_on',
            '        from   apex_applications@&P9_TGT_DBLINK_NAME. a',
            '        where  (upper(a.workspace) = upper(:P9_SCHEMA_NAME)',
            '                or :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__'')',
            '        and    upper(a.workspace) not in (''INTERNAL'')',
            '    ) tgt on tgt.application_id = src.application_id',
            ')',
            'select application_id as "App-ID", application_name as "Name",',
            '       workspace_quelle as "Workspace Quelle", workspace_ziel as "Workspace Ziel",',
            '       seiten_quelle as "Seiten Quelle", seiten_ziel as "Seiten Ziel",',
            '       stand_quelle as "Stand Quelle", stand_ziel as "Stand Ziel", status as "Status"',
            'from   data',
            'union all',
            'select null, case when :P9_SCHEMA_NAME = ''__ALL_APP_SCHEMAS__''',
            '                  then ''Keine APEX-Anwendungen gefunden''',
            '                  else ''Keine APEX-Anwendung fuer Workspace/Schema '' || upper(:P9_SCHEMA_NAME)',
            '             end,',
            '       null, null, null, null, null, null, ''INFO''',
            'from   dual',
            'where  not exists (select 1 from data)',
            'order by 1')),
        p_display_when_condition      => 'P9_CLASSIC_REPORTS_DISABLED',
        p_display_condition_type      => 'ITEM_IS_NOT_NULL',
        p_ajax_enabled                => 'Y',
        p_lazy_loading                => false,
        p_query_row_template          => wwv_flow_imp.id(10845430908759771),
        p_query_num_rows              => 20,
        p_query_options               => 'DERIVED_REPORT_COLUMNS',
        p_query_num_rows_type         => 'NEXT_PREVIOUS_LINKS',
        p_pagination_display_position => 'BOTTOM_RIGHT',
        p_csv_output                  => 'N',
        p_prn_output                  => 'N',
        p_sort_null                   => 'L',
        p_plug_query_strip_html       => 'N');

    wwv_flow_imp.import_end(p_auto_install_sup_obj => false);
    commit;
end;
/

-- Verifikation
select item_name, display_sequence
from   apex_application_page_items
where  application_id = (
           select min(application_id)
           from   apex_applications
           where  workspace = 'MIGRATION'
           and    application_name = 'Migration_Tracker'
       )
and    page_id        = 9
order  by display_sequence;

select region_name, display_sequence, condition_type
from   apex_application_page_regions
where  application_id = (
           select min(application_id)
           from   apex_applications
           where  workspace = 'MIGRATION'
           and    application_name = 'Migration_Tracker'
       )
and    page_id        = 9
order  by display_sequence;
