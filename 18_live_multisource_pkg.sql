set echo on
set define off
whenever sqlerror exit sql.sqlcode rollback

--------------------------------------------------------------------------------
-- Migration Tracker - Multi-source Live Vergleich renderer
-- Run as: MIGRATION on rzhs440:1521/opk.entw
--
-- Kept in a compiled package because APEX Dynamic Content region source has a
-- practical size limit. Page 9 calls this package only when a target mapping
-- has more than one active source DB link.
--------------------------------------------------------------------------------

create or replace package mt_live_multisource_pkg authid definer as
    procedure render(
        p_mapping_id in number,
        p_tgt_link   in varchar2,
        p_schema_csv in varchar2
    );
end mt_live_multisource_pkg;
/

create or replace package body mt_live_multisource_pkg as

    function esc(p_text in varchar2) return varchar2 is
    begin
        return apex_escape.html(p_text);
    end;

    procedure print_section(
        p_title in varchar2,
        p_sql   in varchar2,
        p_col1  in varchar2,
        p_col2  in varchar2,
        p_col3  in varchar2,
        p_col4  in varchar2,
        p_col5  in varchar2
    ) is
        l_cursor integer;
        l_result integer;
        l_rows   number := 0;
        l_v1     varchar2(4000);
        l_v2     varchar2(4000);
        l_v3     varchar2(4000);
        l_v4     varchar2(4000);
        l_v5     varchar2(4000);
    begin
        htp.p('<div class="mt-live-section">');
        htp.p('<h3>' || esc(p_title) || '</h3>');
        htp.p('<table class="mt-live-table"><thead><tr>' ||
              '<th>' || esc(p_col1) || '</th>' ||
              '<th>' || esc(p_col2) || '</th>' ||
              '<th>' || esc(p_col3) || '</th>' ||
              '<th>' || esc(p_col4) || '</th>' ||
              '<th>' || esc(p_col5) || '</th>' ||
              '</tr></thead><tbody>');

        l_cursor := dbms_sql.open_cursor;
        dbms_sql.parse(l_cursor, p_sql, dbms_sql.native);
        dbms_sql.define_column(l_cursor, 1, l_v1, 4000);
        dbms_sql.define_column(l_cursor, 2, l_v2, 4000);
        dbms_sql.define_column(l_cursor, 3, l_v3, 4000);
        dbms_sql.define_column(l_cursor, 4, l_v4, 4000);
        dbms_sql.define_column(l_cursor, 5, l_v5, 4000);
        l_result := dbms_sql.execute(l_cursor);

        loop
            exit when dbms_sql.fetch_rows(l_cursor) = 0 or l_rows >= 200;
            dbms_sql.column_value(l_cursor, 1, l_v1);
            dbms_sql.column_value(l_cursor, 2, l_v2);
            dbms_sql.column_value(l_cursor, 3, l_v3);
            dbms_sql.column_value(l_cursor, 4, l_v4);
            dbms_sql.column_value(l_cursor, 5, l_v5);
            l_rows := l_rows + 1;

            htp.p('<tr><td>' || esc(l_v1) || '</td><td>' || esc(l_v2) ||
                  '</td><td>' || esc(l_v3) || '</td><td class="mt-status-' ||
                  lower(replace(nvl(l_v4, 'info'), '_', '-')) || '">' ||
                  esc(l_v4) || '</td><td>' || esc(l_v5) || '</td></tr>');
        end loop;

        dbms_sql.close_cursor(l_cursor);

        if l_rows = 0 then
            htp.p('<tr><td colspan="5" class="mt-muted">Keine Daten gefunden.</td></tr>');
        elsif l_rows >= 200 then
            htp.p('<tr><td colspan="5" class="mt-muted">Ausgabe auf 200 Zeilen begrenzt.</td></tr>');
        end if;

        htp.p('</tbody></table></div>');
    exception
        when others then
            if dbms_sql.is_open(l_cursor) then
                dbms_sql.close_cursor(l_cursor);
            end if;
            apex_debug.error(
                'Multi-source section %s failed: %s',
                p_title,
                sqlerrm);
            htp.p('<div class="t-Alert t-Alert--warning"><strong>' ||
                  esc(p_title) || ':</strong> ' || esc(sqlerrm) || '</div>');
    end;

    procedure append_branch(
        io_sql   in out nocopy varchar2,
        p_branch in varchar2
    ) is
    begin
        if io_sql is not null then
            io_sql := io_sql || ' union all ';
        end if;
        io_sql := io_sql || p_branch;
    end;

    procedure render(
        p_mapping_id in number,
        p_tgt_link   in varchar2,
        p_schema_csv in varchar2
    ) is
        l_tgt_link    varchar2(261);
        l_user_union  varchar2(32767);
        l_obj_union   varchar2(32767);
        l_table_union varchar2(32767);
        l_app_union   varchar2(32767);
        l_sql         varchar2(32767);
        l_link        varchar2(261);
        l_label       varchar2(4000);
    begin
        l_tgt_link := dbms_assert.simple_sql_name(p_tgt_link);

        htp.p('<style>
            .mt-live-section{margin:1rem 0 2rem 0;max-width:1180px}
            .mt-live-section h3{margin:.25rem 0 .65rem 0;font-size:1.15rem}
            .mt-live-table{border-collapse:separate;border-spacing:0;width:100%;
                border:1px solid #d0d7de;border-radius:6px;overflow:hidden;
                background:#fff;font-size:.875rem}
            .mt-live-table th,.mt-live-table td{border-bottom:1px solid #d8dee4;
                padding:6px 9px;vertical-align:top;line-height:1.35}
            .mt-live-table th{background:#f6f8fa;color:#24292f;font-weight:600}
            .mt-live-table tbody tr:nth-child(even){background:#f8fafc}
            .mt-live-table tbody tr:hover{background:#eef6ff}
            .mt-live-table tr:last-child td{border-bottom:0}
            .mt-live-table td:first-child{font-family:Consolas,"Courier New",monospace}
            .mt-invalid-pair .mt-live-table th:nth-child(n+3),
            .mt-invalid-pair .mt-live-table td:nth-child(n+3){display:none}
            .mt-invalid-pair .mt-live-table th,.mt-invalid-pair .mt-live-table td{
                width:50%;overflow-wrap:anywhere}
            .mt-status-ok{color:#166534;font-weight:700}
            .mt-status-diff,.mt-status-invalid,.mt-status-fehler,
            .mt-status-nur-ziel,.mt-status-mehrdeutig{color:#b42318;font-weight:700}
            .mt-status-pruefen,.mt-status-info{color:#475569;font-weight:600}
            .mt-muted{color:#666}
        </style>');

        for r in (
            select distinct p.dblink_name, s.hostname
            from   mt_fv_pdb_mapping tm
            join   mt_pdb tp            on tp.pdb_id = tm.pdb_id
            join   mt_fachverfahren fv  on fv.fv_id = tm.fv_id
            join   mt_fv_pdb_mapping sm on sm.fv_id = tm.fv_id
            join   mt_pdb p             on p.pdb_id = sm.pdb_id
            join   mt_cdb c             on c.cdb_id = p.cdb_id
            join   mt_server s          on s.server_id = c.server_id
            where  tm.mapping_id = p_mapping_id
            and    tm.mapping_role = 'WORKBENCH'
            and    sm.mapping_role = 'QUELLE'
            and    nvl(tm.aktiv, 'J') = 'J'
            and    nvl(sm.aktiv, 'J') = 'J'
            and    (nvl(p.tier, '-') = nvl(tp.tier, '-')
                    or fv.fv_kuerzel in ('GG', 'IT_FALL'))
            and    p.dblink_name is not null
            and    p.dblink_name not like '##%##'
            and    exists (
                       select 1
                       from   user_db_links l
                       where  l.db_link = upper(p.dblink_name)
                       or     l.db_link like upper(p.dblink_name) || '.%'
                   )
            order  by s.hostname, p.dblink_name
        ) loop
            l_link  := dbms_assert.simple_sql_name(r.dblink_name);
            l_label := replace(r.hostname, '''', '''''');

            append_branch(
                l_user_union,
                'select ''' || l_label || ''' source_name, username' ||
                ' from all_users@' || l_link ||
                ' where username in (' || p_schema_csv || ')');

            append_branch(
                l_obj_union,
                'select ''' || l_label || ''' source_name, owner, object_name,' ||
                ' object_type, status, last_ddl_time' ||
                ' from all_objects@' || l_link ||
                ' where owner in (' || p_schema_csv || ')' ||
                ' and object_name not like ''BIN$%''');

            append_branch(
                l_table_union,
                'select ''' || l_label || ''' source_name, owner, tablespace_name' ||
                ' from all_tables@' || l_link ||
                ' where owner in (' || p_schema_csv || ')');

            append_branch(
                l_app_union,
                'select ''' || l_label || ''' source_name, a.application_id,' ||
                ' a.application_name, a.workspace,' ||
                ' (select count(*) from apex_application_pages@' || l_link ||
                ' p where p.application_id = a.application_id) pages' ||
                ' from apex_applications@' || l_link ||
                ' a where upper(a.workspace) not in ' ||
                '(''INTERNAL'',''MIGRATION'',''COM.ORACLE.CUST.REPOSITORY'')');
        end loop;

        if l_user_union is null then
            htp.p('<div class="t-Alert t-Alert--warning">Keine verwendbaren Source-DB-Links gefunden.</div>');
            return;
        end if;

        l_sql :=
            'with src_users as (' || l_user_union || '),' ||
            ' src_map as (' ||
            '   select username,count(*) source_count,' ||
            '          listagg(source_name,'', '') within group(order by source_name) sources' ||
            '   from src_users group by username' ||
            ' ), tgt as (' ||
            '   select username from all_users@' || l_tgt_link ||
            '   where username in (' || p_schema_csv || ')' ||
            ' )' ||
            ' select tgt.username,nvl(src_map.sources,''-''),''Ziel vorhanden'',' ||
            '        case when nvl(src_map.source_count,0)=0 then ''NUR_ZIEL''' ||
            '             when src_map.source_count=1 then ''OK'' else ''MEHRDEUTIG'' end,' ||
            '        case when nvl(src_map.source_count,0)=0 then ''Schema auf keiner Quelle gefunden.''' ||
            '             when src_map.source_count=1 then ''Quelle automatisch zugeordnet.''' ||
            '             else ''Schema auf mehreren Quellen gefunden.'' end' ||
            ' from tgt left join src_map on src_map.username=tgt.username' ||
            ' order by tgt.username';
        print_section(
            'Schema-Zuordnung', l_sql,
            'Zielschema', 'Gefundene Quelle(n)', 'Ziel', 'Status', 'Hinweis');

        l_sql :=
            'with src_raw as (' || l_obj_union || '),' ||
            ' src_map as (select username owner,count(*) source_count from (' ||
            l_user_union || ') group by username),' ||
            ' src as (' ||
            '   select r.owner||''.''||r.object_type element,count(*) cnt,' ||
            '          max(r.source_name) source_name' ||
            '   from src_raw r join src_map m on m.owner=r.owner and m.source_count=1' ||
            '   where r.object_type in (''TABLE'',''VIEW'',''PROCEDURE'',''FUNCTION'',' ||
            '       ''PACKAGE'',''PACKAGE BODY'',''TRIGGER'',''SEQUENCE'',''INDEX'',' ||
            '       ''SYNONYM'',''TYPE'',''TYPE BODY'')' ||
            '   group by r.owner,r.object_type' ||
            ' ), tgt as (' ||
            '   select owner||''.''||object_type element,count(*) cnt' ||
            '   from all_objects@' || l_tgt_link ||
            '   where owner in (' || p_schema_csv || ')' ||
            '   and object_type in (''TABLE'',''VIEW'',''PROCEDURE'',''FUNCTION'',' ||
            '       ''PACKAGE'',''PACKAGE BODY'',''TRIGGER'',''SEQUENCE'',''INDEX'',' ||
            '       ''SYNONYM'',''TYPE'',''TYPE BODY'')' ||
            '   and object_name not like ''BIN$%''' ||
            '   group by owner,object_type' ||
            ' )' ||
            ' select coalesce(src.element,tgt.element),to_char(nvl(src.cnt,0)),' ||
            '        to_char(nvl(tgt.cnt,0)),' ||
            '        case when nvl(src.cnt,0)=nvl(tgt.cnt,0) then ''OK'' else ''DIFF'' end,' ||
            '        src.source_name' ||
            ' from src full outer join tgt on tgt.element=src.element order by 1';
        print_section(
            'Objektanzahl nach Schema und Typ', l_sql,
            'Schema.Objekttyp', 'Quelle Anzahl', 'Ziel Anzahl', 'Ergebnis', 'Quelle');

        l_sql :=
            'with src_raw as (' || l_obj_union || '),' ||
            ' src_map as (select username owner,count(*) source_count from (' ||
            l_user_union || ') group by username),' ||
            ' src as (' ||
            '   select r.* from src_raw r join src_map m on m.owner=r.owner and m.source_count=1' ||
            ' ), tgt as (' ||
            '   select owner,object_name,object_type,status,last_ddl_time' ||
            '   from all_objects@' || l_tgt_link ||
            '   where owner in (' || p_schema_csv || ')' ||
            '   and object_name not like ''BIN$%''' ||
            ' ), err as (' ||
            '   select owner,name,type,' ||
            '          listagg(''Zeile ''||line||'':''||position||'' ''||substr(text,1,250),'' | '')' ||
            '          within group(order by sequence) error_text' ||
            '   from (select e.*,row_number() over(partition by owner,name,type order by sequence) rn' ||
            '         from all_errors@' || l_tgt_link || ' e' ||
            '         where owner in (' || p_schema_csv || '))' ||
            '   where rn<=3 group by owner,name,type' ||
            ' )' ||
            ' select tgt.owner||''.''||tgt.object_name,tgt.object_type,src.status,tgt.status,' ||
            '        src.source_name||'' / ''||nvl(err.error_text,''Keine ALL_ERRORS-Details gefunden.'')' ||
            ' from tgt join src on src.owner=tgt.owner and src.object_name=tgt.object_name' ||
            '  and src.object_type=tgt.object_type' ||
            ' left join err on err.owner=tgt.owner and err.name=tgt.object_name and err.type=tgt.object_type' ||
            ' where src.status=''VALID'' and tgt.status<>''VALID''' ||
            ' order by tgt.owner,tgt.object_type,tgt.object_name';
        print_section(
            'Quelle gueltig, Ziel ungueltig', l_sql,
            'Ziel Objekt', 'Objekttyp', 'Quelle Status', 'Ziel Status',
            'Quelle / Fehlerdetails');

        l_sql :=
            'with src_raw as (' || l_obj_union || '),' ||
            ' src_map as (select username owner,count(*) source_count from (' ||
            l_user_union || ') group by username),' ||
            ' src as (' ||
            '   select r.source_name||'':''||r.owner||''.''||r.object_name||'' (''||r.object_type||'')'' element,' ||
            '          row_number() over(order by r.source_name,r.owner,r.object_type,r.object_name) rn' ||
            '   from src_raw r join src_map m on m.owner=r.owner and m.source_count=1' ||
            '   where r.status<>''VALID''' ||
            ' ), tgt as (' ||
            '   select owner||''.''||object_name||'' (''||object_type||'')'' element,' ||
            '          row_number() over(order by owner,object_type,object_name) rn' ||
            '   from all_objects@' || l_tgt_link ||
            '   where owner in (' || p_schema_csv || ')' ||
            '   and object_name not like ''BIN$%'' and status<>''VALID''' ||
            ' )' ||
            ' select src.element,tgt.element,null,null,null' ||
            ' from src full outer join tgt on tgt.rn=src.rn' ||
            ' order by coalesce(src.rn,tgt.rn)';
        htp.p('<div class="mt-invalid-pair">');
        print_section(
            'Ungueltige Objekte', l_sql,
            'Quelle ungueltig', 'Ziel ungueltig', '', '', '');
        htp.p('</div>');

        l_sql :=
            'with src_raw as (' || l_table_union || '),' ||
            ' src_map as (select username owner,count(*) source_count from (' ||
            l_user_union || ') group by username),' ||
            ' src as (' ||
            '   select nvl(r.tablespace_name,''<NULL>'') element,count(*) cnt' ||
            '   from src_raw r join src_map m on m.owner=r.owner and m.source_count=1' ||
            '   group by nvl(r.tablespace_name,''<NULL>'')' ||
            ' ), tgt as (' ||
            '   select nvl(tablespace_name,''<NULL>'') element,count(*) cnt' ||
            '   from all_tables@' || l_tgt_link ||
            '   where owner in (' || p_schema_csv || ')' ||
            '   group by nvl(tablespace_name,''<NULL>'')' ||
            ' )' ||
            ' select coalesce(src.element,tgt.element),to_char(nvl(src.cnt,0)),' ||
            '        to_char(nvl(tgt.cnt,0)),' ||
            '        case when nvl(src.cnt,0)=nvl(tgt.cnt,0) then ''OK'' else ''DIFF'' end,null' ||
            ' from src full outer join tgt on tgt.element=src.element order by 1';
        print_section(
            'Tablespace-Vergleich', l_sql,
            'Tablespace', 'Tabellen Quelle', 'Tabellen Ziel', 'Ergebnis', 'Hinweis');

        l_sql :=
            'with src_raw as (' || l_app_union || '),' ||
            ' src as (' ||
            '   select application_id,application_name,count(*) source_count,' ||
            '          listagg(source_name,'', '') within group(order by source_name) sources,' ||
            '          max(workspace) workspace,max(pages) pages' ||
            '   from src_raw group by application_id,application_name' ||
            ' ), tgt as (' ||
            '   select a.application_id,a.application_name,a.workspace,' ||
            '          (select count(*) from apex_application_pages@' || l_tgt_link ||
            '           p where p.application_id=a.application_id) pages' ||
            '   from apex_applications@' || l_tgt_link ||
            ' a where upper(a.workspace) not in ' ||
            '(''INTERNAL'',''MIGRATION'',''COM.ORACLE.CUST.REPOSITORY'')' ||
            ' )' ||
            ' select to_char(coalesce(src.application_id,tgt.application_id))||'' ''||' ||
            '        coalesce(src.application_name,tgt.application_name),' ||
            '        src.sources||'' / ''||src.workspace||'' / Seiten ''||src.pages,' ||
            '        tgt.workspace||'' / Seiten ''||tgt.pages,' ||
            '        case when src.application_id is null then ''NUR_ZIEL''' ||
            '             when tgt.application_id is null then ''NUR_QUELLE''' ||
            '             when src.source_count>1 then ''MEHRDEUTIG''' ||
            '             when nvl(src.pages,-1)=nvl(tgt.pages,-1) then ''OK'' else ''DIFF'' end,' ||
            '        case when src.source_count>1 then ''App auf mehreren Quellen gefunden.'' end' ||
            ' from src full outer join tgt on tgt.application_id=src.application_id' ||
            ' and tgt.application_name=src.application_name order by 1';
        print_section(
            'APEX-Anwendungen', l_sql,
            'APEX App', 'Quelle(n) Workspace / Seiten', 'Ziel Workspace / Seiten',
            'Ergebnis', 'Hinweis');

        l_sql :=
            'select ''MULTI_SOURCE'',''VOSTAT.PRD'',''Zielmetadaten'',''PRUEFEN'',' ||
            '''Runtime-, Plugin-, JS/CSS- und fachliche Tests bleiben je Anwendung manuell.'' from dual';
        print_section(
            'APEX Runtime-Risiken', l_sql,
            'Kategorie', 'App / Seite', 'Komponente', 'Risiko', 'Hinweis');
    exception
        when others then
            apex_debug.error(
                'Multi-source renderer failed: %s / %s',
                sqlerrm,
                dbms_utility.format_error_backtrace);
            htp.p('<div class="t-Alert t-Alert--danger"><strong>Multi-source Vergleich:</strong> ' ||
                  esc(sqlerrm) || '<br>' ||
                  esc(dbms_utility.format_error_backtrace) || '</div>');
    end;
end mt_live_multisource_pkg;
/

show errors package mt_live_multisource_pkg
show errors package body mt_live_multisource_pkg

select object_name, object_type, status
from   user_objects
where  object_name = 'MT_LIVE_MULTISOURCE_PKG'
order  by object_type;
