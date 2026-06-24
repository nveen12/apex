set echo on
set define off
set serveroutput on
whenever sqlerror exit sql.sqlcode rollback

--------------------------------------------------------------------------------
-- Migration Tracker - DCS invalid-object comparison support
-- Run as: MIGRATION on rzhs440:1521/opk.entw
--
-- Purpose:
--   Dataport/DCS target is not queried live here. Instead, paste the DCS invalid
--   object list into Page 12. The package parses OWNER.OBJECT entries and
--   compares them against the resolved PROD source from local source-schema
--   inventory. The inventory is refreshed separately from active PROD DB links.
--------------------------------------------------------------------------------

declare
    l_count number;
begin
    select count(*)
    into   l_count
    from   all_sequences
    where  sequence_owner = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    sequence_name  = 'SEQ_DCS_INVALID_RUN_ID';

    if l_count = 0 then
        execute immediate q'[
            create sequence seq_dcs_invalid_run_id
                start with 1
                increment by 1
                nocache
                nocycle
        ]';
    end if;
end;
/

declare
    l_count number;
begin
    select count(*)
    into   l_count
    from   all_tables
    where  owner      = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    table_name = 'MT_SOURCE_SCHEMA_INVENTORY';

    if l_count = 0 then
        execute immediate q'[
            create table mt_source_schema_inventory (
                source_dblink_name varchar2(128) not null,
                source_host        varchar2(255),
                source_service     varchar2(255),
                schema_name        varchar2(128),
                refresh_status     varchar2(30)  default 'OK' not null,
                error_message      varchar2(2000),
                refreshed_at       date          default sysdate not null,
                constraint ck_mt_source_schema_inv_status
                    check (refresh_status in ('OK', 'LINK_ERROR')),
                constraint uq_mt_source_schema_inventory
                    unique (source_dblink_name, schema_name, refresh_status)
            )
        ]';
    end if;
end;
/

declare
    l_count number;
begin
    select count(*)
    into   l_count
    from   all_sequences
    where  sequence_owner = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    sequence_name  = 'SEQ_DCS_INVALID_RESULT_ID';

    if l_count = 0 then
        execute immediate q'[
            create sequence seq_dcs_invalid_result_id
                start with 1
                increment by 1
                nocache
                nocycle
        ]';
    end if;
end;
/

declare
    l_count number;
begin
    select count(*)
    into   l_count
    from   all_tables
    where  owner      = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    table_name = 'MT_DCS_INVALID_RUN';

    if l_count = 0 then
        execute immediate q'[
            create table mt_dcs_invalid_run (
                run_id        number        not null,
                run_label     varchar2(200),
                target_scope  varchar2(100) default 'DCS_PROD' not null,
                raw_text      clob,
                created_by    varchar2(255) default user not null,
                created_at    date          default sysdate not null,
                line_count    number        default 0 not null,
                parsed_count  number        default 0 not null,
                result_count  number        default 0 not null,
                status        varchar2(30)  default 'ERFASST' not null,
                constraint pk_mt_dcs_invalid_run
                    primary key (run_id),
                constraint ck_mt_dcs_invalid_run_status
                    check (status in ('ERFASST', 'ANALYSIERT', 'FEHLER'))
            )
        ]';
    end if;
end;
/

declare
    l_count number;
begin
    select count(*)
    into   l_count
    from   all_tables
    where  owner      = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    table_name = 'MT_DCS_INVALID_RESULT';

    if l_count = 0 then
        execute immediate q'[
            create table mt_dcs_invalid_result (
                result_id          number        not null,
                run_id             number        not null,
                line_no            number,
                raw_line           varchar2(4000),
                parsed_schema      varchar2(128),
                object_name        varchar2(128),
                parsed_object_type varchar2(50),
                source_host        varchar2(255),
                source_service     varchar2(255),
                source_dblink_name varchar2(128),
                source_object_type varchar2(50),
                source_status      varchar2(20),
                result_status      varchar2(40)  not null,
                hinweis            varchar2(2000),
                created_at         date          default sysdate not null,
                constraint pk_mt_dcs_invalid_result
                    primary key (result_id),
                constraint fk_mt_dcs_invalid_result_run
                    foreign key (run_id)
                    references mt_dcs_invalid_run (run_id)
                    on delete cascade,
                constraint ck_mt_dcs_invalid_result_status
                    check (result_status in (
                        'SOURCE_VALID_DCS_INVALID',
                        'SOURCE_INVALID_DCS_INVALID',
                        'NOT_FOUND_IN_PROD_SOURCE',
                        'SOURCE_NOT_CONFIGURED',
                        'SOURCE_AMBIGUOUS',
                        'SOURCE_LINK_ERROR',
                        'PARSE_FEHLER'
                    ))
            )
        ]';
    end if;
end;
/

declare
    l_count number;
begin
    select count(*)
    into   l_count
    from   user_constraints
    where  table_name = 'MT_DCS_INVALID_RESULT'
    and    constraint_name = 'CK_MT_DCS_INVALID_RESULT_STATUS';

    if l_count > 0 then
        execute immediate 'alter table mt_dcs_invalid_result drop constraint ck_mt_dcs_invalid_result_status';
    end if;

    execute immediate q'[
        alter table mt_dcs_invalid_result add constraint ck_mt_dcs_invalid_result_status
            check (result_status in (
                'SOURCE_VALID_DCS_INVALID',
                'SOURCE_INVALID_DCS_INVALID',
                'NOT_FOUND_IN_PROD_SOURCE',
                'SOURCE_NOT_CONFIGURED',
                'SOURCE_AMBIGUOUS',
                'SOURCE_LINK_ERROR',
                'PARSE_FEHLER'
            ))
    ]';
end;
/

declare
    l_count number;
begin
    select count(*)
    into   l_count
    from   all_tables
    where  owner      = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    table_name = 'MT_DCS_SCHEMA_SOURCE_RULE';

    if l_count = 0 then
        execute immediate q'[
            create table mt_dcs_schema_source_rule (
                dcs_schema         varchar2(128) not null,
                source_dblink_name varchar2(128) not null,
                aktiv              varchar2(1)   default 'J' not null,
                kommentar          varchar2(1000),
                erfasst_am         date          default sysdate not null,
                constraint pk_mt_dcs_schema_source_rule
                    primary key (dcs_schema, source_dblink_name),
                constraint ck_mt_dcs_schema_source_rule_aktiv
                    check (aktiv in ('J', 'N'))
            )
        ]';
    end if;
end;
/

comment on table mt_dcs_invalid_run is
    'One pasted Dataport/DCS invalid-object list and its analysis metadata.';
comment on table mt_dcs_invalid_result is
    'Parsed DCS invalid objects compared against active PROD source DB links.';
comment on table mt_dcs_schema_source_rule is
    'Optional DCS schema -> PROD source DB-link rules. Prevents broad DB-link scans and ORA-02020.';
comment on table mt_source_schema_inventory is
    'Cached schema inventory from active PROD source DB links. Used to route DCS invalid-object comparisons without broad live scans.';

merge into mt_dcs_schema_source_rule r
using (
    select 'AED' as dcs_schema,
           'RZHS184_SUPPORT_FREE_PROD' as source_dblink_name,
           'J' as aktiv,
           'Aus DCS-Invalid-Test bestaetigt: AED-Objekte liegen auf SUPPORT_FREE.PROD.' as kommentar
    from dual
    union all
    select 'MBF',
           'RZHS184_SEMINAR_PROD',
           'J',
           'Aus DCS-Invalid-Test beobachtet: MBF-Objekte wurden auf SEMINAR.PROD gefunden.'
    from dual
    union all
    select 'OPK',
           'RZHS184_OPK_PROD',
           'J',
           'Aus Screenshot-Mapping: OPK PROD-Quelle.'
    from dual
    union all
    select 'RZ782',
           'RZHS406_PARADOX_PROD',
           'J',
           'Aus Screenshot-Mapping: GG/RZ782 PROD-Quelle paradox.PROD.'
    from dual
    union all
    select 'SEMINAR',
           'RZHS184_SEMINAR_PROD',
           'J',
           'Aus Screenshot-Mapping: SEMINAR PROD-Quelle.'
    from dual
    union all
    select 'VOLLSTRECKUNG',
           'RZHS407_VOLLSTRP_PROD',
           'J',
           'Vom DBA bestaetigt: VOSTAT.PRD Quelle fuer Schema VOLLSTRECKUNG ist rzhs407/VOLLSTRP.PROD.'
    from dual
) src
on (
    r.dcs_schema = src.dcs_schema
    and r.source_dblink_name = src.source_dblink_name
)
when matched then
    update set r.aktiv = src.aktiv,
               r.kommentar = src.kommentar
when not matched then
    insert (dcs_schema, source_dblink_name, aktiv, kommentar)
    values (src.dcs_schema, src.source_dblink_name, src.aktiv, src.kommentar);

commit;

create or replace package mt_dcs_invalid_pkg authid definer as
    procedure refresh_source_inventory;

    function analyze(
        p_raw_text   in clob,
        p_created_by in varchar2 default user
    ) return number;
end mt_dcs_invalid_pkg;
/

create or replace package body mt_dcs_invalid_pkg as

    type t_cache is table of varchar2(1) index by varchar2(4000);
    g_schema_link_cache t_cache;

    function is_app_schema(p_schema in varchar2) return boolean is
        l_schema varchar2(128) := upper(p_schema);
    begin
        if l_schema is null then
            return false;
        end if;

        if l_schema in (
            'ANONYMOUS', 'APEX_PUBLIC_USER', 'APPQOSSYS', 'AUDSYS',
            'CTXSYS', 'DBSFWUSER', 'DBSNMP', 'DIP', 'DVF', 'DVSYS',
            'GGSYS', 'GSMADMIN_INTERNAL', 'GSMCATUSER', 'GSMUSER',
            'LBACSYS', 'MDSYS', 'OJVMSYS', 'OLAPSYS', 'ORACLE_OCM',
            'ORDDATA', 'ORDPLUGINS', 'ORDSYS', 'OUTLN', 'REMOTE_SCHEDULER_AGENT',
            'SI_INFORMTN_SCHEMA', 'SYS', 'SYS$UMF', 'SYSBACKUP', 'SYSDG',
            'SYSKM', 'SYSRAC', 'SYSTEM', 'WMSYS', 'XDB', 'XS$NULL'
        ) then
            return false;
        end if;

        if l_schema like 'APEX\_%' escape '\'
           or l_schema like 'FLOWS\_%' escape '\'
           or l_schema like 'ORDS\_%' escape '\'
           or l_schema like 'OAUTH%'
           or l_schema like 'AQ$%'
           or l_schema like 'MLOG$%' then
            return false;
        end if;

        return true;
    end;

    procedure close_db_link(p_link in varchar2) is
    begin
        execute immediate
            'alter session close database link ' ||
            dbms_assert.simple_sql_name(p_link);
    exception
        when others then
            null;
    end;

    function schema_exists_on_link(
        p_schema in varchar2,
        p_link   in varchar2
    ) return boolean is
        l_key   varchar2(4000) := upper(p_schema) || '@' || upper(p_link);
        l_count number;
        l_link  varchar2(261);
    begin
        if g_schema_link_cache.exists(l_key) then
            return g_schema_link_cache(l_key) = 'Y';
        end if;

        l_link := dbms_assert.simple_sql_name(p_link);
        execute immediate
            'select count(*) from all_users@' || l_link ||
            ' where username = :schema_name'
            into l_count
            using upper(p_schema);

        close_db_link(l_link);
        g_schema_link_cache(l_key) := case when l_count > 0 then 'Y' else 'N' end;
        return l_count > 0;
    exception
        when others then
            close_db_link(p_link);
            raise;
    end;

    procedure refresh_source_inventory is
        l_link   varchar2(261);
        l_sql    varchar2(32767);
        l_schema varchar2(128);
        l_rc     sys_refcursor;
    begin
        delete from mt_source_schema_inventory;
        commit;

        for s in (
            select distinct
                   upper(p.dblink_name) as dblink_name,
                   src.hostname as source_host,
                   nvl(p.service_name, p.pdb_name) as source_service
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
                       from   user_db_links l
                       where  l.db_link = upper(p.dblink_name)
                       or     l.db_link like upper(p.dblink_name) || '.%'
                   )
            order  by src.hostname, nvl(p.service_name, p.pdb_name), upper(p.dblink_name)
        ) loop
            begin
                l_link := dbms_assert.simple_sql_name(s.dblink_name);
                l_sql := 'select username from all_users@' || l_link || ' order by username';
                open l_rc for l_sql;
                loop
                    fetch l_rc into l_schema;
                    exit when l_rc%notfound;

                    if is_app_schema(l_schema) then
                        begin
                            insert into mt_source_schema_inventory (
                                source_dblink_name, source_host, source_service,
                                schema_name, refresh_status, refreshed_at)
                            values (
                                upper(s.dblink_name), s.source_host, s.source_service,
                                upper(l_schema), 'OK', sysdate);
                        exception
                            when dup_val_on_index then
                                null;
                        end;
                    end if;
                end loop;
                close l_rc;
                close_db_link(l_link);
                commit;
            exception
                when others then
                    if l_rc%isopen then
                        close l_rc;
                    end if;
                    close_db_link(s.dblink_name);
                    insert into mt_source_schema_inventory (
                        source_dblink_name, source_host, source_service,
                        schema_name, refresh_status, error_message, refreshed_at)
                    values (
                        upper(s.dblink_name), s.source_host, s.source_service,
                        null, 'LINK_ERROR', substr(sqlerrm, 1, 2000), sysdate);
                    commit;
            end;
        end loop;
    end refresh_source_inventory;

    procedure add_result(
        p_run_id             in number,
        p_line_no            in number,
        p_raw_line           in varchar2,
        p_schema             in varchar2,
        p_object_name        in varchar2,
        p_parsed_object_type in varchar2,
        p_source_host        in varchar2,
        p_source_service     in varchar2,
        p_source_dblink_name in varchar2,
        p_source_object_type in varchar2,
        p_source_status      in varchar2,
        p_result_status      in varchar2,
        p_hinweis            in varchar2
    ) is
    begin
        insert into mt_dcs_invalid_result (
            result_id, run_id, line_no, raw_line, parsed_schema, object_name,
            parsed_object_type, source_host, source_service, source_dblink_name,
            source_object_type, source_status, result_status, hinweis)
        values (
            seq_dcs_invalid_result_id.nextval, p_run_id, p_line_no,
            substr(p_raw_line, 1, 4000), upper(p_schema), upper(p_object_name),
            upper(p_parsed_object_type), p_source_host, p_source_service,
            upper(p_source_dblink_name), p_source_object_type, p_source_status,
            p_result_status, substr(p_hinweis, 1, 2000));
    end;

    function object_type_from_line(p_line in varchar2) return varchar2 is
        l_line varchar2(4000) := upper(p_line);
    begin
        if regexp_like(l_line, '(^|[^A-Z])PACKAGE BODY([^A-Z]|$)') then return 'PACKAGE BODY'; end if;
        if regexp_like(l_line, '(^|[^A-Z])MATERIALIZED VIEW([^A-Z]|$)') then return 'MATERIALIZED VIEW'; end if;
        if regexp_like(l_line, '(^|[^A-Z])PROCEDURE([^A-Z]|$)') then return 'PROCEDURE'; end if;
        if regexp_like(l_line, '(^|[^A-Z])FUNCTION([^A-Z]|$)') then return 'FUNCTION'; end if;
        if regexp_like(l_line, '(^|[^A-Z])PACKAGE([^A-Z]|$)') then return 'PACKAGE'; end if;
        if regexp_like(l_line, '(^|[^A-Z])TRIGGER([^A-Z]|$)') then return 'TRIGGER'; end if;
        if regexp_like(l_line, '(^|[^A-Z])SEQUENCE([^A-Z]|$)') then return 'SEQUENCE'; end if;
        if regexp_like(l_line, '(^|[^A-Z])SYNONYM([^A-Z]|$)') then return 'SYNONYM'; end if;
        if regexp_like(l_line, '(^|[^A-Z])INDEX([^A-Z]|$)') then return 'INDEX'; end if;
        if regexp_like(l_line, '(^|[^A-Z])TABLE([^A-Z]|$)') then return 'TABLE'; end if;
        if regexp_like(l_line, '(^|[^A-Z])VIEW([^A-Z]|$)') then return 'VIEW'; end if;
        if regexp_like(l_line, '(^|[^A-Z])TYPE BODY([^A-Z]|$)') then return 'TYPE BODY'; end if;
        if regexp_like(l_line, '(^|[^A-Z])TYPE([^A-Z]|$)') then return 'TYPE'; end if;
        return null;
    end;

    procedure compare_one_object(
        p_run_id      in number,
        p_line_no     in number,
        p_raw_line    in varchar2,
        p_schema      in varchar2,
        p_object_name in varchar2,
        p_object_type in varchar2
    ) is
        l_found       boolean := false;
        l_sql         varchar2(32767);
        l_rc          sys_refcursor;
        l_obj_type    varchar2(50);
        l_status      varchar2(20);
        l_link        varchar2(261);
        l_status_code varchar2(40);
        l_link_error  boolean := false;
        l_candidate_seen boolean := false;
        l_rule_count number := 0;
        l_inventory_count number := 0;
        l_source_list varchar2(2000);
    begin
        select count(distinct r.source_dblink_name),
               listagg(r.source_dblink_name, ', ') within group (order by r.source_dblink_name)
        into   l_rule_count,
               l_source_list
        from   mt_dcs_schema_source_rule r
        where  r.dcs_schema = upper(p_schema)
        and    r.aktiv = 'J';

        if l_rule_count = 0 then
            select count(distinct i.source_dblink_name),
                   listagg(i.source_dblink_name, ', ') within group (order by i.source_dblink_name)
            into   l_inventory_count,
                   l_source_list
            from   mt_source_schema_inventory i
            where  i.schema_name = upper(p_schema)
            and    i.refresh_status = 'OK';

            if l_inventory_count = 0 then
                add_result(
                    p_run_id             => p_run_id,
                    p_line_no            => p_line_no,
                    p_raw_line           => p_raw_line,
                    p_schema             => p_schema,
                    p_object_name        => p_object_name,
                    p_parsed_object_type => p_object_type,
                    p_source_host        => null,
                    p_source_service     => null,
                    p_source_dblink_name => null,
                    p_source_object_type => null,
                    p_source_status      => null,
                    p_result_status      => 'SOURCE_NOT_CONFIGURED',
                    p_hinweis            => 'Schema nicht im PROD-Quellinventar gefunden. Quellinventar aktualisieren oder Quellregel manuell setzen.');
                return;
            elsif l_inventory_count > 1 then
                add_result(
                    p_run_id             => p_run_id,
                    p_line_no            => p_line_no,
                    p_raw_line           => p_raw_line,
                    p_schema             => p_schema,
                    p_object_name        => p_object_name,
                    p_parsed_object_type => p_object_type,
                    p_source_host        => null,
                    p_source_service     => null,
                    p_source_dblink_name => null,
                    p_source_object_type => null,
                    p_source_status      => null,
                    p_result_status      => 'SOURCE_AMBIGUOUS',
                    p_hinweis            => 'Schema in mehreren PROD-Quellen gefunden: ' || substr(l_source_list, 1, 1800) || '. Bitte Quellregel setzen.');
                return;
            end if;
        elsif l_rule_count > 1 then
            add_result(
                p_run_id             => p_run_id,
                p_line_no            => p_line_no,
                p_raw_line           => p_raw_line,
                p_schema             => p_schema,
                p_object_name        => p_object_name,
                p_parsed_object_type => p_object_type,
                p_source_host        => null,
                p_source_service     => null,
                p_source_dblink_name => null,
                p_source_object_type => null,
                p_source_status      => null,
                p_result_status      => 'SOURCE_AMBIGUOUS',
                p_hinweis            => 'Mehrere aktive Quellregeln gefunden: ' || substr(l_source_list, 1, 1800) || '. Bitte eine Regel aktiv lassen.');
            return;
        end if;

        for s in (
            select distinct p.dblink_name,
                   src.hostname as source_host,
                   nvl(p.service_name, p.pdb_name) as source_service,
                   case
                       when upper(nvl(fv.schema_name, '-')) = upper(p_schema) then 1
                       when upper(nvl(fv.workspace_name, '-')) = upper(p_schema) then 2
                       when upper(nvl(fv.fv_kuerzel, '-')) = upper(p_schema) then 3
                       else 9
                   end as match_rank
            from   mt_fv_pdb_mapping m
            join   mt_fachverfahren fv on fv.fv_id = m.fv_id
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
                       from   user_db_links l
                       where  l.db_link = upper(p.dblink_name)
                       or     l.db_link like upper(p.dblink_name) || '.%'
                   )
            and    (
                       (l_rule_count > 0 and exists (
                           select 1
                           from   mt_dcs_schema_source_rule r
                           where  r.dcs_schema = upper(p_schema)
                           and    r.aktiv = 'J'
                           and    r.source_dblink_name = upper(p.dblink_name)
                       ))
                    or (l_rule_count = 0 and exists (
                           select 1
                           from   mt_source_schema_inventory i
                           where  i.schema_name = upper(p_schema)
                           and    i.refresh_status = 'OK'
                           and    i.source_dblink_name = upper(p.dblink_name)
                       ))
                   )
            order  by match_rank, src.hostname, nvl(p.service_name, p.pdb_name), p.dblink_name
        ) loop
            l_candidate_seen := true;
            begin
                l_link := dbms_assert.simple_sql_name(s.dblink_name);
                if not schema_exists_on_link(p_schema, l_link) then
                    continue;
                end if;

                l_sql :=
                    'select object_type, status' ||
                    ' from all_objects@' || l_link ||
                    ' where owner = :owner_name' ||
                    ' and object_name = :object_name' ||
                    ' and object_name not like ''BIN$%''';

                if p_object_type is not null then
                    l_sql := l_sql || ' and object_type = :object_type';
                    open l_rc for l_sql using upper(p_schema), upper(p_object_name), upper(p_object_type);
                else
                    open l_rc for l_sql using upper(p_schema), upper(p_object_name);
                end if;

                loop
                    fetch l_rc into l_obj_type, l_status;
                    exit when l_rc%notfound;
                    l_found := true;
                    l_status_code :=
                        case
                            when l_status = 'VALID' then 'SOURCE_VALID_DCS_INVALID'
                            else 'SOURCE_INVALID_DCS_INVALID'
                        end;

                    add_result(
                        p_run_id             => p_run_id,
                        p_line_no            => p_line_no,
                        p_raw_line           => p_raw_line,
                        p_schema             => p_schema,
                        p_object_name        => p_object_name,
                        p_parsed_object_type => p_object_type,
                        p_source_host        => s.source_host,
                        p_source_service     => s.source_service,
                        p_source_dblink_name => s.dblink_name,
                        p_source_object_type => l_obj_type,
                        p_source_status      => l_status,
                        p_result_status      => l_status_code,
                        p_hinweis            => case
                                                   when l_status = 'VALID'
                                                   then 'DCS ungueltig, PROD-Quelle gueltig: Import/Compile in DCS pruefen.'
                                                   else 'DCS ungueltig und PROD-Quelle ebenfalls ungueltig: vermutlich Altlast oder fachlich klaeren.'
                                                end);
                end loop;
                close l_rc;
                close_db_link(l_link);
                if l_found then
                    exit;
                end if;
            exception
                when others then
                    l_link_error := true;
                    if l_rc%isopen then
                        close l_rc;
                    end if;
                    close_db_link(l_link);
                    add_result(
                        p_run_id             => p_run_id,
                        p_line_no            => p_line_no,
                        p_raw_line           => p_raw_line,
                        p_schema             => p_schema,
                        p_object_name        => p_object_name,
                        p_parsed_object_type => p_object_type,
                        p_source_host        => s.source_host,
                        p_source_service     => s.source_service,
                        p_source_dblink_name => s.dblink_name,
                        p_source_object_type => null,
                        p_source_status      => null,
                        p_result_status      => 'SOURCE_LINK_ERROR',
                        p_hinweis            => sqlerrm);
            end;
        end loop;

        if not l_candidate_seen then
            add_result(
                p_run_id             => p_run_id,
                p_line_no            => p_line_no,
                p_raw_line           => p_raw_line,
                p_schema             => p_schema,
                p_object_name        => p_object_name,
                p_parsed_object_type => p_object_type,
                p_source_host        => null,
                p_source_service     => null,
                p_source_dblink_name => null,
                p_source_object_type => null,
                p_source_status      => null,
                p_result_status      => case when l_rule_count > 0 then 'SOURCE_LINK_ERROR' else 'SOURCE_NOT_CONFIGURED' end,
                p_hinweis            => case
                                           when l_rule_count > 0
                                           then 'Quellregel vorhanden, aber kein passender aktiver USER_DB_LINK/Mapping-Kandidat gefunden: ' || substr(l_source_list, 1, 1600)
                                           else 'Keine PROD-Quelle fuer dieses Schema gefunden. Quellinventar aktualisieren oder Quellregel setzen.'
                                        end);
        elsif not l_found and not l_link_error then
            add_result(
                p_run_id             => p_run_id,
                p_line_no            => p_line_no,
                p_raw_line           => p_raw_line,
                p_schema             => p_schema,
                p_object_name        => p_object_name,
                p_parsed_object_type => p_object_type,
                p_source_host        => null,
                p_source_service     => null,
                p_source_dblink_name => null,
                p_source_object_type => null,
                p_source_status      => null,
                p_result_status      => 'NOT_FOUND_IN_PROD_SOURCE',
                p_hinweis            => 'Objekt in keiner aktiven PROD-Quelle gefunden. Schema/Object-Mapping oder DCS-Liste pruefen.');
        end if;
    end;

    procedure parse_invalid_line(
        p_line        in varchar2,
        p_schema      out varchar2,
        p_object_name out varchar2,
        p_object_type out varchar2,
        p_is_data     out boolean,
        p_is_continue out boolean
    ) is
        l_line        varchar2(4000) := replace(replace(p_line, '"'), '`');
        l_trim        varchar2(4000) := trim(l_line);
        l_after_owner varchar2(4000);
    begin
        p_schema      := null;
        p_object_name := null;
        p_object_type := null;
        p_is_data     := false;
        p_is_continue := false;

        if l_trim is null
           or regexp_like(l_trim, '^OWNER[[:space:]]+OBJECT_TYPE', 'i')
           or regexp_like(l_trim, '^[-[:space:]]+$')
           or regexp_like(l_trim, '^[0-9]+[[:space:]]+(Zeilen|rows)', 'i') then
            return;
        end if;

        -- SQL*Plus wraps long OBJECT_NAME values onto the next indented line.
        if regexp_like(l_line, '^[[:space:]]+[A-Za-z0-9_$#]+[[:space:]]*$') then
            p_object_name := l_trim;
            p_is_continue := true;
            return;
        end if;

        -- SQL*Plus fixed-column output:
        -- OWNER          OBJECT_TYPE             OBJECT_NAME
        p_schema := regexp_substr(
            l_line,
            '^[[:space:]]*([A-Za-z][A-Za-z0-9_$#]{0,127})[[:space:]]+',
            1, 1, 'i', 1);

        if p_schema is not null then
            l_after_owner := regexp_replace(
                l_line,
                '^[[:space:]]*[A-Za-z][A-Za-z0-9_$#]{0,127}[[:space:]]+',
                '',
                1, 1, 'i');
            p_object_type := regexp_substr(
                l_after_owner,
                '^(MATERIALIZED VIEW|PACKAGE BODY|JAVA SOURCE|JAVA CLASS|TYPE BODY|DATABASE LINK|PROCEDURE|FUNCTION|PACKAGE|TRIGGER|SYNONYM|SEQUENCE|INDEX|TABLE|VIEW|TYPE)[[:space:]]+',
                1, 1, 'i', 1);

            if p_object_type is not null then
                p_object_name := trim(regexp_replace(
                    l_after_owner,
                    '^(MATERIALIZED VIEW|PACKAGE BODY|JAVA SOURCE|JAVA CLASS|TYPE BODY|DATABASE LINK|PROCEDURE|FUNCTION|PACKAGE|TRIGGER|SYNONYM|SEQUENCE|INDEX|TABLE|VIEW|TYPE)[[:space:]]+',
                    '',
                    1, 1, 'i'));
                p_is_data := p_object_name is not null;
                return;
            end if;
        end if;

        -- Fallback for simple pasted lines containing SCHEMA.OBJECT_NAME.
        p_schema := regexp_substr(
            l_line,
            '(^|[^A-Za-z0-9_$#])([A-Za-z][A-Za-z0-9_$#]{0,127})\.([A-Za-z][A-Za-z0-9_$#]{0,127})',
            1, 1, 'i', 2);
        p_object_name := regexp_substr(
            l_line,
            '(^|[^A-Za-z0-9_$#])([A-Za-z][A-Za-z0-9_$#]{0,127})\.([A-Za-z][A-Za-z0-9_$#]{0,127})',
            1, 1, 'i', 3);
        p_object_type := object_type_from_line(l_line);
        p_is_data := p_schema is not null and p_object_name is not null;
    end;

    function analyze(
        p_raw_text   in clob,
        p_created_by in varchar2 default user
    ) return number is
        l_run_id       number;
        l_text         clob;
        l_len          number;
        l_pos          number := 1;
        l_next         number;
        l_line         varchar2(4000);
        l_line_no      number := 0;
        l_line_count   number := 0;
        l_parsed_count number := 0;
        l_schema       varchar2(128);
        l_object_name  varchar2(128);
        l_object_type  varchar2(50);
        l_is_data      boolean;
        l_is_continue  boolean;
        l_pending      boolean := false;
        l_p_schema     varchar2(128);
        l_p_object     varchar2(128);
        l_p_type       varchar2(50);
        l_p_raw        varchar2(4000);
        l_p_line_no    number;

        procedure flush_pending is
        begin
            if l_pending then
                l_parsed_count := l_parsed_count + 1;
                compare_one_object(
                    p_run_id      => l_run_id,
                    p_line_no     => l_p_line_no,
                    p_raw_line    => l_p_raw,
                    p_schema      => l_p_schema,
                    p_object_name => l_p_object,
                    p_object_type => l_p_type);
                l_pending := false;
                l_p_schema := null;
                l_p_object := null;
                l_p_type := null;
                l_p_raw := null;
                l_p_line_no := null;
            end if;
        end;
    begin
        l_run_id := seq_dcs_invalid_run_id.nextval;
        l_text := replace(replace(p_raw_text, chr(13) || chr(10), chr(10)), chr(13), chr(10));

        insert into mt_dcs_invalid_run (
            run_id, run_label, raw_text, created_by, status)
        values (
            l_run_id,
            'DCS Invalid Analyse ' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS'),
            p_raw_text,
            nvl(p_created_by, user),
            'ERFASST');

        l_len := nvl(dbms_lob.getlength(l_text), 0);

        while l_pos <= l_len + 1 loop
            l_next := dbms_lob.instr(l_text, chr(10), l_pos);
            if l_next = 0 then
                l_line := dbms_lob.substr(l_text, least(4000, l_len - l_pos + 1), l_pos);
                l_pos := l_len + 2;
            else
                l_line := dbms_lob.substr(l_text, least(4000, l_next - l_pos), l_pos);
                l_pos := l_next + 1;
            end if;

            l_line_no := l_line_no + 1;
            if trim(l_line) is null then
                continue;
            end if;

            l_line_count := l_line_count + 1;
            parse_invalid_line(
                p_line        => l_line,
                p_schema      => l_schema,
                p_object_name => l_object_name,
                p_object_type => l_object_type,
                p_is_data     => l_is_data,
                p_is_continue => l_is_continue);

            if l_is_continue then
                if l_pending then
                    l_p_object := substr(l_p_object || l_object_name, 1, 128);
                    l_p_raw := substr(l_p_raw || ' ' || trim(l_line), 1, 4000);
                end if;
            elsif l_is_data then
                flush_pending;
                l_pending := true;
                l_p_schema := upper(l_schema);
                l_p_object := upper(l_object_name);
                l_p_type := upper(l_object_type);
                l_p_raw := l_line;
                l_p_line_no := l_line_no;
            elsif not regexp_like(trim(l_line), '^OWNER[[:space:]]+OBJECT_TYPE', 'i')
                  and not regexp_like(trim(l_line), '^[-[:space:]]+$')
                  and not regexp_like(trim(l_line), '^[0-9]+[[:space:]]+(Zeilen|rows)', 'i') then
                flush_pending;
                add_result(
                    p_run_id             => l_run_id,
                    p_line_no            => l_line_no,
                    p_raw_line           => l_line,
                    p_schema             => null,
                    p_object_name        => null,
                    p_parsed_object_type => null,
                    p_source_host        => null,
                    p_source_service     => null,
                    p_source_dblink_name => null,
                    p_source_object_type => null,
                    p_source_status      => null,
                    p_result_status      => 'PARSE_FEHLER',
                    p_hinweis            => 'Keine OWNER/OBJECT_TYPE/OBJECT_NAME- oder OWNER.OBJECT-Struktur erkannt.');
            end if;
        end loop;

        flush_pending;

        update mt_dcs_invalid_run r
        set    line_count   = l_line_count,
               parsed_count = l_parsed_count,
               result_count = (select count(*) from mt_dcs_invalid_result x where x.run_id = l_run_id),
               status       = 'ANALYSIERT'
        where  r.run_id = l_run_id;

        commit;
        return l_run_id;
    exception
        when others then
            rollback;
            raise;
    end analyze;
end mt_dcs_invalid_pkg;
/

show errors package mt_dcs_invalid_pkg
show errors package body mt_dcs_invalid_pkg

select object_name, object_type, status
from   user_objects
where  object_name = 'MT_DCS_INVALID_PKG'
order  by object_type;
