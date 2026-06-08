set echo off
set define off
set serveroutput on size unlimited
set pagesize 200
set linesize 240
whenever sqlerror continue

--------------------------------------------------------------------------------
-- Migration Tracker - Live Vergleich DB-Link Diagnose
-- Run as: MIGRATION on rzhs440/opk.entw
--
-- Purpose:
--   1. Test every private DB link used by the Live Vergleich mappings.
--   2. Show exactly where a link/query fails.
--   3. Run the same metadata checks Page 9 depends on:
--        dual, sys_context, all_users, all_objects, all_tables,
--        apex_applications, apex_application_pages
--
-- This script does not change data.
--------------------------------------------------------------------------------

declare
    l_dummy       number;
    l_text        varchar2(4000);
    l_cnt         number;
    l_sql         varchar2(32767);
    l_owner_count number;
    l_required_tables number;

    procedure line(p_text in varchar2) is
    begin
        dbms_output.put_line(p_text);
    end;

    procedure test_sql(
        p_label in varchar2,
        p_sql   in varchar2
    ) is
        l_num number;
    begin
        execute immediate p_sql into l_num;
        line('    OK     ' || rpad(p_label, 32) || ' => ' || l_num);
    exception
        when others then
            line('    FEHLER ' || rpad(p_label, 32) || ' => ' || sqlerrm);
    end;

    procedure test_text_sql(
        p_label in varchar2,
        p_sql   in varchar2
    ) is
        l_value varchar2(4000);
    begin
        execute immediate p_sql into l_value;
        line('    OK     ' || rpad(p_label, 32) || ' => ' || nvl(l_value, '<NULL>'));
    exception
        when others then
            line('    FEHLER ' || rpad(p_label, 32) || ' => ' || sqlerrm);
    end;

    procedure close_link(p_link in varchar2) is
    begin
        commit;
        execute immediate 'alter session close database link ' ||
            dbms_assert.qualified_sql_name(p_link);
        line('    CLOSED ' || p_link);
    exception
        when others then
            -- ORA-02080/02081 means the link is not open in this session; harmless here.
            if sqlcode not in (-2080, -2081) then
                line('    WARN   close ' || p_link || ' => ' || sqlerrm);
            end if;
    end;

    procedure test_link(p_link in varchar2) is
        l_link varchar2(261) := dbms_assert.qualified_sql_name(p_link);
    begin
        line(chr(10) || 'DB LINK: ' || p_link);

        test_sql(
            'dual',
            'select count(*) from dual@' || l_link);

        test_text_sql(
            'remote db/service',
            'select sys_context(''USERENV'',''DB_NAME'') || '' / '' || ' ||
            '       sys_context(''USERENV'',''SERVICE_NAME'') from dual@' || l_link);

        test_text_sql(
            'remote current user',
            'select sys_context(''USERENV'',''CURRENT_USER'') from dual@' || l_link);

        test_sql(
            'non-system users',
            'select count(*) from all_users@' || l_link ||
            ' where username not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',' ||
            '                       ''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',' ||
            '                       ''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',' ||
            '                       ''APEX_240100'',''APEX_PUBLIC_USER'',''ORDS_PUBLIC_USER'')');

        test_sql(
            'all_objects app scope',
            'select count(*) from all_objects@' || l_link ||
            ' where owner not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',' ||
            '                     ''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',' ||
            '                     ''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',' ||
            '                     ''APEX_240100'',''APEX_PUBLIC_USER'',''ORDS_PUBLIC_USER'')' ||
            ' and object_name not like ''BIN$%''');

        test_sql(
            'all_tables app scope',
            'select count(*) from all_tables@' || l_link ||
            ' where owner not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',' ||
            '                     ''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',' ||
            '                     ''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',' ||
            '                     ''APEX_240100'',''APEX_PUBLIC_USER'',''ORDS_PUBLIC_USER'')');

        test_sql(
            'apex_applications',
            'select count(*) from apex_applications@' || l_link ||
            ' where upper(workspace) <> ''INTERNAL''');

        test_sql(
            'apex_application_pages',
            'select count(*) from apex_application_pages@' || l_link);

        line('    Top owners by object count:');
        l_sql :=
            'select owner || '':'' || cnt from (' ||
            '  select owner, count(*) cnt' ||
            '  from all_objects@' || l_link ||
            '  where owner not in (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APPQOSSYS'',''XDB'',' ||
            '                      ''WMSYS'',''CTXSYS'',''ORDSYS'',''ORDDATA'',''MDSYS'',''LBACSYS'',' ||
            '                      ''GSMADMIN_INTERNAL'',''OJVMSYS'',''AUDSYS'',''DVSYS'',''DVF'',' ||
            '                      ''APEX_240100'',''APEX_PUBLIC_USER'',''ORDS_PUBLIC_USER'')' ||
            '  and object_name not like ''BIN$%''' ||
            '  group by owner' ||
            '  order by count(*) desc, owner' ||
            ') where rownum <= 10';

        begin
            l_owner_count := 0;
            for r in (
                select column_value as owner_info
                from   table(sys.odcivarchar2list())
            ) loop
                null;
            end loop;

            -- Dynamic cursor loop without creating helper objects.
            declare
                c integer;
                rc integer;
                v varchar2(4000);
            begin
                c := dbms_sql.open_cursor;
                dbms_sql.parse(c, l_sql, dbms_sql.native);
                dbms_sql.define_column(c, 1, v, 4000);
                rc := dbms_sql.execute(c);
                loop
                    exit when dbms_sql.fetch_rows(c) = 0;
                    dbms_sql.column_value(c, 1, v);
                    l_owner_count := l_owner_count + 1;
                    line('      ' || v);
                end loop;
                dbms_sql.close_cursor(c);
            exception
                when others then
                    if dbms_sql.is_open(c) then
                        dbms_sql.close_cursor(c);
                    end if;
                    line('      FEHLER owner listing => ' || sqlerrm);
            end;

            if l_owner_count = 0 then
                line('      <keine sichtbaren Anwendungsobjekte>');
            end if;
        end;

        close_link(p_link);
    end;
begin
    line('=== LIVE VERGLEICH DB-LINK DIAGNOSE ===');
    line('Current schema: ' || sys_context('USERENV', 'CURRENT_SCHEMA'));
    line('Current user  : ' || sys_context('USERENV', 'CURRENT_USER'));
    line('Service       : ' || sys_context('USERENV', 'SERVICE_NAME'));

    select count(*)
    into   l_required_tables
    from   all_tables
    where  owner = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    table_name in ('MT_FV_PDB_MAPPING', 'MT_PDB', 'MT_FACHVERFAHREN');

    if l_required_tables < 3 then
        raise_application_error(
            -20020,
            'Run this script as MIGRATION schema. Required tables are not visible in current schema.');
    end if;

    line(chr(10) || '=== PRIVATE DB LINKS IN MIGRATION ===');
    for r in (
        select db_link, username, host
        from   user_db_links
        order  by db_link
    ) loop
        line(rpad(r.db_link, 40) || ' user=' || r.username || ' host=' || r.host);
    end loop;

    line(chr(10) || '=== LINKS USED BY ACTIVE LIVE VERGLEICH MAPPINGS ===');
    for r in (
        select distinct sp.dblink_name as link_name
        from   mt_fv_pdb_mapping tm
        join   mt_pdb tp on tp.pdb_id = tm.pdb_id
        join   mt_fv_pdb_mapping sm on sm.fv_id = tm.fv_id
        join   mt_pdb sp on sp.pdb_id = sm.pdb_id
        where  tm.mapping_role = 'WORKBENCH'
        and    sm.mapping_role = 'QUELLE'
        and    sp.dblink_name is not null
        and    sp.dblink_name not like '##%##'
        union
        select distinct tp.dblink_name
        from   mt_fv_pdb_mapping tm
        join   mt_pdb tp on tp.pdb_id = tm.pdb_id
        join   mt_fv_pdb_mapping sm on sm.fv_id = tm.fv_id
        join   mt_pdb sp on sp.pdb_id = sm.pdb_id
        where  tm.mapping_role = 'WORKBENCH'
        and    sm.mapping_role = 'QUELLE'
        and    tp.dblink_name is not null
        and    tp.dblink_name not like '##%##'
        order  by 1
    ) loop
        test_link(r.link_name);
    end loop;

    line(chr(10) || '=== ACTIVE MAPPING SUMMARY ===');
    for r in (
        select fv.fv_name,
               tp.service_name,
               sp.dblink_name src_link,
               tp.dblink_name tgt_link
        from   mt_fachverfahren fv
        join   mt_fv_pdb_mapping tm on tm.fv_id = fv.fv_id and tm.mapping_role = 'WORKBENCH'
        join   mt_pdb tp            on tp.pdb_id = tm.pdb_id
        join   mt_fv_pdb_mapping sm on sm.fv_id = fv.fv_id and sm.mapping_role = 'QUELLE'
        join   mt_pdb sp            on sp.pdb_id = sm.pdb_id
        where  (nvl(sp.tier, '-') = nvl(tp.tier, '-') or fv.fv_kuerzel in ('GG', 'IT_FALL'))
        order  by fv.fv_name, tp.service_name
    ) loop
        line(rpad(r.fv_name, 35) || ' service=' || rpad(nvl(r.service_name, '-'), 25) ||
             ' src=' || nvl(r.src_link, '<NULL>') || ' tgt=' || nvl(r.tgt_link, '<NULL>'));
    end loop;

    line(chr(10) || '=== DIAGNOSE COMPLETE ===');
end;
/
