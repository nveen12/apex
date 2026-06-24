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
--   checks those objects against all active PROD source DB links.
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
                        'SOURCE_LINK_ERROR',
                        'PARSE_FEHLER'
                    ))
            )
        ]';
    end if;
end;
/

comment on table mt_dcs_invalid_run is
    'One pasted Dataport/DCS invalid-object list and its analysis metadata.';
comment on table mt_dcs_invalid_result is
    'Parsed DCS invalid objects compared against active PROD source DB links.';

create or replace package mt_dcs_invalid_pkg authid definer as
    function analyze(
        p_raw_text   in clob,
        p_created_by in varchar2 default user
    ) return number;
end mt_dcs_invalid_pkg;
/

create or replace package body mt_dcs_invalid_pkg as

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
    begin
        for s in (
            select distinct p.dblink_name,
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
            order  by src.hostname, nvl(p.service_name, p.pdb_name), p.dblink_name
        ) loop
            begin
                l_link := dbms_assert.simple_sql_name(s.dblink_name);
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
            exception
                when others then
                    l_link_error := true;
                    if l_rc%isopen then
                        close l_rc;
                    end if;
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

        if not l_found and not l_link_error then
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
