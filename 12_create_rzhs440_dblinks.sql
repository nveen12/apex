set echo off
set define on
set serveroutput on
whenever sqlerror exit sql.sqlcode rollback

--------------------------------------------------------------------------------
-- Migration Tracker - Create DB Links for Live Vergleich
-- Run as: MIGRATION on rzhs440:1521/opk.entw
--
-- Source of values: user-provided dblinks list on 2026-06-08.
-- These are PRIVATE database links in the MIGRATION schema.
--
-- Temporary shortcut: links connect as SYSTEM. Replace with read-only users
-- when available.
--
-- Password is requested interactively and must not be committed to Git.
--------------------------------------------------------------------------------

accept dblink_system_password char prompt 'SYSTEM password for DB links: ' hide
accept recreate_existing_links char default 'Y' prompt 'Drop/recreate existing MIGRATION private DB links? [Y/n]: '

declare
    l_password varchar2(4000) := replace('&&dblink_system_password', '"', '""');
    l_recreate varchar2(1) := upper(substr(nvl('&&recreate_existing_links', 'Y'), 1, 1));

    procedure ensure_link(
        p_name    in varchar2,
        p_host    in varchar2,
        p_service in varchar2
    ) is
        l_count number;
        l_sql   varchar2(4000);
    begin
        select count(*)
        into   l_count
        from   user_db_links
        where  db_link = upper(p_name)
        or     db_link like upper(p_name) || '.%';

        if l_count > 0 and l_recreate = 'Y' then
            for r in (
                select db_link
                from   user_db_links
                where  db_link = upper(p_name)
                or     db_link like upper(p_name) || '.%'
            ) loop
                execute immediate 'drop database link ' || dbms_assert.qualified_sql_name(r.db_link);
                dbms_output.put_line('DROPPED ' || r.db_link);
            end loop;

            select count(*)
            into   l_count
            from   user_db_links
            where  db_link = upper(p_name)
            or     db_link like upper(p_name) || '.%';
        end if;

        if l_count = 0 then
            l_sql :=
                'create database link ' || dbms_assert.simple_sql_name(p_name) ||
                ' connect to system identified by "' || l_password || '" using ' ||
                '''(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=' || p_host ||
                ')(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=' || p_service ||
                ')))''';
            execute immediate l_sql;
            dbms_output.put_line('CREATED ' || p_name);
        else
            dbms_output.put_line('EXISTS  ' || p_name || ' (not recreated)');
        end if;
    exception
        when others then
            if sqlcode = -2011 then
                raise_application_error(
                    -20012,
                    'Duplicate DB link while creating ' || p_name ||
                    '. Check USER_DB_LINKS/DBA_DB_LINKS for private or public links with this name. Original error: ' ||
                    sqlerrm);
            else
                raise;
            end if;
    end;
begin
    ensure_link('rzhs184_seminar_int',          'rzhs184', 'seminar.int');
    ensure_link('rzhs440_seminar_int',          'rzhs440', 'seminar.int');
    ensure_link('rzhs184_seminar_test',         'rzhs184', 'seminar.test');
    ensure_link('rzhs440_seminar_test',         'rzhs440', 'seminar.test');
    ensure_link('rzhs184_opk_prod',             'rzhs184', 'opk.prod');
    ensure_link('rzhs440_opk_prod',             'rzhs440', 'opk.prod');
    ensure_link('rzhs184_opk_entw',             'rzhs184', 'opk.entw');
    ensure_link('rzhs440_opk_entw',             'rzhs440', 'opk.entw');
    ensure_link('rzhs184_opk_int',              'rzhs184', 'opk.int');
    ensure_link('rzhs440_opk_int',              'rzhs440', 'opk.int');
    ensure_link('rzhs184_support_free_prod',    'rzhs184', 'SUPPORT_FREE.PROD');
    ensure_link('rzhs440_support_free_prod',    'rzhs440', 'SUPPORT_FREE.PROD');
    ensure_link('rzhs184_support_free_entw',    'rzhs184', 'SUPPORT_FREE.ENTW');
    ensure_link('rzhs440_support_free_entw',    'rzhs440', 'SUPPORT_FREE.ENTW');
    ensure_link('rzhs184_support_free_int',     'rzhs184', 'SUPPORT_FREE.INT');
    ensure_link('rzhs440_support_free_int',     'rzhs440', 'SUPPORT_FREE.INT');
    ensure_link('rzhs184_pingo_prod',           'rzhs184', 'PINGO.PROD');
    ensure_link('rzhs440_pingo_prod',           'rzhs440', 'PINGO.PROD');
    ensure_link('rzhs184_pingo_int',            'rzhs184', 'PINGO.INT');
    ensure_link('rzhs440_pingo_int',            'rzhs440', 'PINGO.INT');
    ensure_link('rzhs184_pingo_entw',           'rzhs184', 'PINGO.ENTW');
    ensure_link('rzhs440_pingo_entw',           'rzhs440', 'PINGO.ENTW');
    ensure_link('rzhs159_itprod',               'rzhs159', 'ITPROD.WORLD');
    ensure_link('rzhs441_itfallprod',           'rzhs441', 'itfallprod.WORLD');
    ensure_link('rzhs441_itfalint',             'rzhs441', 'itfalint.WORLD');
    ensure_link('rzhs441_itfallentw',           'rzhs441', 'itfallentw.WORLD');
    ensure_link('rzhs406_paradox_prod',         'rzhs406', 'paradox.PROD');
    ensure_link('rzhs440_ggprod',               'rzhs440', 'ggprod.prod');
end;
/

select db_link, username, host
from   user_db_links
order  by db_link;

--------------------------------------------------------------------------------
-- Optional manual tests:
-- select 1 from dual@rzhs184_opk_entw;
-- select 1 from dual@rzhs440_opk_entw;
-- select 1 from dual@rzhs406_paradox_prod;
-- select 1 from dual@rzhs440_ggprod;
--------------------------------------------------------------------------------
