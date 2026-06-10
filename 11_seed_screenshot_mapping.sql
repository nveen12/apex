set echo on
set define off
whenever sqlerror exit sql.sqlcode rollback

--------------------------------------------------------------------------------
-- Migration Tracker - Screenshot Mapping Seed
-- Source: User-provided screenshot on 2026-06-08
-- Scope: Partial mapping only. Do not treat this as complete ALV inventory.
--
-- Loads the shown source -> target -> service rows into mt_server/mt_cdb/mt_pdb
-- and mt_fv_pdb_mapping so Page 10 can present useful comparison choices.
--
-- Must run after 05_schema_object_tracking.sql.
--------------------------------------------------------------------------------

declare
    l_missing varchar2(4000);

    procedure require_column(p_table_name in varchar2, p_column_name in varchar2) is
        l_count number;
    begin
        select count(*)
        into   l_count
        from   all_tab_columns
        where  owner       = sys_context('USERENV', 'CURRENT_SCHEMA')
        and    table_name  = upper(p_table_name)
        and    column_name = upper(p_column_name);

        if l_count = 0 then
            l_missing := l_missing || p_table_name || '.' || p_column_name || ', ';
        end if;
    end;
begin
    require_column('mt_server', 'dblink_name');
    require_column('mt_pdb', 'dblink_name');
    require_column('mt_fv_pdb_mapping', 'mapping_role');

    if l_missing is not null then
        raise_application_error(
            -20011,
            'Required columns missing: ' || rtrim(l_missing, ', ')
            || '. Run 05_schema_object_tracking.sql first as MIGRATION.');
    end if;
end;
/

declare
    function next_server_id return number is
        l_id number;
    begin
        select nvl(max(server_id), 0) + 1 into l_id from mt_server;
        return l_id;
    end;

    function next_cdb_id return number is
        l_id number;
    begin
        select nvl(max(cdb_id), 0) + 1 into l_id from mt_cdb;
        return l_id;
    end;

    function next_pdb_id return number is
        l_id number;
    begin
        select nvl(max(pdb_id), 0) + 1 into l_id from mt_pdb;
        return l_id;
    end;

    function next_fv_id return number is
        l_id number;
    begin
        select nvl(max(fv_id), 0) + 1 into l_id from mt_fachverfahren;
        return l_id;
    end;

    function next_mapping_id return number is
        l_id number;
    begin
        select nvl(max(mapping_id), 0) + 1 into l_id from mt_fv_pdb_mapping;
        return l_id;
    end;

    procedure ensure_server(
        p_hostname    in varchar2,
        p_umgebung    in varchar2,
        p_dblink_name in varchar2
    ) is
        l_count   number;
        l_id      number;
        l_umgebung mt_server.umgebung%type;
    begin
        select count(*) into l_count
        from   mt_server
        where  lower(regexp_replace(hostname, '\.ofd-h\.de$', '')) =
               lower(regexp_replace(p_hostname, '\.ofd-h\.de$', ''));

        if l_count = 0 then
            l_id := next_server_id;
            l_umgebung := case p_umgebung
                               when 'QUELLE'    then 'QUELLE'
                               when 'WORKBENCH' then 'AEN'
                               when 'ATU'       then 'ATU'
                               when 'PROD'      then 'DCS'
                               when 'DCS'       then 'DCS'
                               when 'AEN'       then 'AEN'
                               else 'AEN'
                           end;

            insert into mt_server (
                server_id, hostname, umgebung, dblink_name, kommentar
            ) values (
                l_id, p_hostname, l_umgebung, p_dblink_name,
                'Aus Screenshot-Mapping 2026-06-08 geladen; Inventar unvollstaendig.'
            );
        else
            update mt_server
            set    dblink_name = nvl(p_dblink_name, dblink_name),
                   kommentar   = nvl(kommentar, 'Aus Screenshot-Mapping 2026-06-08 aktualisiert; Inventar unvollstaendig.')
            where  lower(regexp_replace(hostname, '\.ofd-h\.de$', '')) =
                   lower(regexp_replace(p_hostname, '\.ofd-h\.de$', ''));
        end if;
    end;

    procedure ensure_cdb(
        p_hostname in varchar2,
        p_cdb_name in varchar2
    ) is
        l_server_id number;
        l_count     number;
        l_id        number;
    begin
        select server_id into l_server_id
        from   mt_server
        where  lower(regexp_replace(hostname, '\.ofd-h\.de$', '')) =
               lower(regexp_replace(p_hostname, '\.ofd-h\.de$', ''))
        and    rownum = 1;

        select count(*) into l_count
        from   mt_cdb
        where  server_id = l_server_id
        and    upper(cdb_name) = upper(p_cdb_name);

        if l_count = 0 then
            l_id := next_cdb_id;
            insert into mt_cdb (cdb_id, server_id, cdb_name)
            values (l_id, l_server_id, p_cdb_name);
        end if;
    end;

    procedure ensure_pdb(
        p_hostname     in varchar2,
        p_cdb_name     in varchar2,
        p_pdb_name     in varchar2,
        p_service_name in varchar2,
        p_dblink_name  in varchar2
    ) is
        l_cdb_id number;
        l_count  number;
        l_tier   varchar2(30);
        l_id     number;
    begin
        select c.cdb_id into l_cdb_id
        from   mt_cdb c
        join   mt_server s on s.server_id = c.server_id
        where  lower(regexp_replace(s.hostname, '\.ofd-h\.de$', '')) =
               lower(regexp_replace(p_hostname, '\.ofd-h\.de$', ''))
        and    upper(c.cdb_name) = upper(p_cdb_name);

        if instr(upper(p_service_name), '.PROD') > 0
           or instr(upper(p_service_name), '.PRD') > 0 then
            l_tier := 'PROD';
        elsif instr(upper(p_service_name), '.INT') > 0 then
            l_tier := 'INT';
        elsif instr(upper(p_service_name), '.ENTW') > 0 then
            l_tier := 'ENTW';
        else
            l_tier := null;
        end if;

        select count(*) into l_count
        from   mt_pdb
        where  cdb_id = l_cdb_id
        and    upper(pdb_name) = upper(p_pdb_name);

        if l_count = 0 then
            l_id := next_pdb_id;
            insert into mt_pdb (pdb_id, cdb_id, pdb_name, service_name, tier, dblink_name)
            values (l_id, l_cdb_id, p_pdb_name, p_service_name, l_tier, p_dblink_name);
        else
            update mt_pdb
            set    service_name = p_service_name,
                   tier         = nvl(tier, l_tier),
                   dblink_name  = p_dblink_name
            where  cdb_id = l_cdb_id
            and    upper(pdb_name) = upper(p_pdb_name);
        end if;
    end;

    procedure ensure_fv(
        p_name   in varchar2,
        p_code   in varchar2,
        p_schema in varchar2
    ) is
        l_count number;
        l_id    number;
    begin
        select count(*) into l_count
        from   mt_fachverfahren
        where  upper(fv_kuerzel) = upper(p_code)
        or     upper(fv_name)    = upper(p_name);

        if l_count = 0 then
            l_id := next_fv_id;
            insert into mt_fachverfahren (
                fv_id, fv_name, fv_kuerzel, workspace_name, schema_name,
                konsens_verfahren, migrations_status, kommentar
            ) values (
                l_id, p_name, p_code, p_schema, p_schema,
                'N', 'OFFEN',
                'Aus Screenshot-Mapping 2026-06-08 ergaenzt; gegen ALV-Migration.ods pruefen.'
            );
        end if;
    end;

    procedure ensure_mapping(
        p_fv_code  in varchar2,
        p_hostname in varchar2,
        p_cdb_name in varchar2,
        p_pdb_name in varchar2,
        p_role     in varchar2
    ) is
        l_fv_id  number;
        l_pdb_id number;
        l_count  number;
        l_id     number;
        l_rolle_cols number;
        l_aktiv_cols number;
    begin
        select fv_id into l_fv_id
        from   mt_fachverfahren
        where  upper(fv_kuerzel) = upper(p_fv_code)
        and    rownum = 1;

        select p.pdb_id into l_pdb_id
        from   mt_pdb p
        join   mt_cdb c    on c.cdb_id = p.cdb_id
        join   mt_server s on s.server_id = c.server_id
        where  lower(regexp_replace(s.hostname, '\.ofd-h\.de$', '')) =
               lower(regexp_replace(p_hostname, '\.ofd-h\.de$', ''))
        and    upper(c.cdb_name) = upper(p_cdb_name)
        and    upper(p.pdb_name) = upper(p_pdb_name);

        select count(*) into l_count
        from   mt_fv_pdb_mapping
        where  fv_id = l_fv_id
        and    pdb_id = l_pdb_id
        and    mapping_role = p_role;

        if l_count = 0 then
            l_id := next_mapping_id;

            select count(*) into l_rolle_cols
            from   all_tab_columns
            where  owner       = sys_context('USERENV', 'CURRENT_SCHEMA')
            and    table_name  = 'MT_FV_PDB_MAPPING'
            and    column_name = 'ROLLE';

            if l_rolle_cols > 0 then
                execute immediate
                    'insert into mt_fv_pdb_mapping (mapping_id, fv_id, pdb_id, rolle, mapping_role)
                     values (:1, :2, :3, :4, :5)'
                    using l_id, l_fv_id, l_pdb_id, p_role, p_role;
            else
                insert into mt_fv_pdb_mapping (
                    mapping_id, fv_id, pdb_id, mapping_role
                ) values (
                    l_id, l_fv_id, l_pdb_id, p_role
                );
            end if;
        else
            select count(*) into l_aktiv_cols
            from   all_tab_columns
            where  owner       = sys_context('USERENV', 'CURRENT_SCHEMA')
            and    table_name  = 'MT_FV_PDB_MAPPING'
            and    column_name = 'AKTIV';

            if l_aktiv_cols > 0 then
                execute immediate
                    'update mt_fv_pdb_mapping
                     set    aktiv = ''J''
                     where  fv_id = :1
                     and    pdb_id = :2
                     and    mapping_role = :3'
                    using l_fv_id, l_pdb_id, p_role;
            end if;
        end if;
    end;

    procedure add_row(
        p_fv_code         in varchar2,
        p_fv_name         in varchar2,
        p_schema_name     in varchar2,
        p_src_host        in varchar2,
        p_src_cdb         in varchar2,
        p_src_pdb         in varchar2,
        p_src_dblink      in varchar2,
        p_tgt_host        in varchar2,
        p_tgt_cdb         in varchar2,
        p_tgt_pdb         in varchar2,
        p_service_name    in varchar2,
        p_tgt_dblink      in varchar2
    ) is
    begin
        ensure_fv(p_fv_name, p_fv_code, p_schema_name);
        ensure_server(p_src_host, 'QUELLE', p_src_dblink);
        ensure_server(p_tgt_host, 'WORKBENCH', null);
        ensure_cdb(p_src_host, p_src_cdb);
        ensure_cdb(p_tgt_host, p_tgt_cdb);
        ensure_pdb(p_src_host, p_src_cdb, p_src_pdb, p_service_name, p_src_dblink);
        ensure_pdb(p_tgt_host, p_tgt_cdb, p_tgt_pdb, p_service_name, p_tgt_dblink);
        ensure_mapping(p_fv_code, p_src_host, p_src_cdb, p_src_pdb, 'QUELLE');
        ensure_mapping(p_fv_code, p_tgt_host, p_tgt_cdb, p_tgt_pdb, 'WORKBENCH');
    end;
begin
    -- Korrektur nach finaler DB-Link-Liste aus dblinks.docx:
    -- alte Zielhost-Annahmen aus frueheren Iterationen nicht loeschen, sondern
    -- gezielt deaktivieren, damit sie nicht mehr in der APEX-Auswahl erscheinen.
    update mt_fv_pdb_mapping m
    set    aktiv = 'N',
           kommentar = 'Deaktiviert: Zielhost durch dblinks.docx korrigiert.'
    where  nvl(m.mapping_role, m.rolle) = 'WORKBENCH'
    and    exists (
               select 1
               from   mt_fachverfahren fv
               join   mt_pdb p     on p.pdb_id = m.pdb_id
               join   mt_cdb c     on c.cdb_id = p.cdb_id
               join   mt_server s  on s.server_id = c.server_id
               where  fv.fv_id = m.fv_id
               and    (
                         (fv.fv_kuerzel = 'SUPPORTFR' and regexp_replace(lower(s.hostname), '\.ofd-h\.de$', '') = 'rzhs440')
                      or (fv.fv_kuerzel = 'PINGO'     and regexp_replace(lower(s.hostname), '\.ofd-h\.de$', '') = 'rzhs440')
                      or (fv.fv_kuerzel = 'IT_FALL'   and regexp_replace(lower(s.hostname), '\.ofd-h\.de$', '') = 'rzhs184')
                      )
           );

    -- SEMINR / IuK Veranstaltungsplan
    add_row('SEMINAR', 'IuK Veranstaltungsplan', 'SEMINAR',
            'rzhs184', 'SEMINR', 'SEMINAR.PROD', 'rzhs184_seminar_prod',
            'rzhs440', 'SEMINR', 'SEMINARPROD', 'SEMINAR.PROD', 'rzhs440_seminar_prod');
    add_row('SEMINAR', 'IuK Veranstaltungsplan', 'SEMINAR',
            'rzhs184', 'SEMINR', 'SEMINAR.INT', 'rzhs184_seminar_int',
            'rzhs440', 'SEMINR', 'SEMINARINT', 'SEMINAR.INT', 'rzhs440_seminar_int');
    add_row('SEMINAR', 'IuK Veranstaltungsplan', 'SEMINAR',
            'rzhs184', 'SEMINR', 'SEMINAR.ENTW', 'rzhs184_seminar_entw',
            'rzhs440', 'SEMINR', 'SEMINARENTW', 'SEMINAR.ENTW', 'rzhs440_seminar_entw');

    -- DBAE21 / OPK
    add_row('OPK', 'OPK', 'OPK',
            'rzhs184', 'DBAE21', 'OPKPROD', 'rzhs184_opk_prod',
            'rzhs440', 'DBAE21', 'OPK.PROD', 'OPK.PROD', 'rzhs440_opk_prod');
    add_row('OPK', 'OPK', 'OPK',
            'rzhs184', 'DBAE21', 'OPKINT', 'rzhs184_opk_int',
            'rzhs440', 'DBAE21', 'OPK.INT', 'OPK.INT', 'rzhs440_opk_int');
    add_row('OPK', 'OPK', 'OPK',
            'rzhs184', 'DBAE21', 'OPKENTW', 'rzhs184_opk_entw',
            'rzhs440', 'DBAE21', 'OPK.ENTW', 'OPK.ENTW', 'rzhs440_opk_entw');

    -- SUPPORTFR / SUPPORT_FREE
    add_row('SUPPORTFR', 'SUPPORTFR', 'SUPPORT_FREE',
            'rzhs184', 'SUPPORTFR', 'SUPPORT_FREE.PROD', 'rzhs184_support_free_prod',
            'rzhs441', 'SUPPORTFR', 'SUPPORT_FREE.PROD', 'SUPPORT_FREE.PROD', 'rzhs441_support_free_prod');
    add_row('SUPPORTFR', 'SUPPORTFR', 'SUPPORT_FREE',
            'rzhs184', 'SUPPORTFR', 'SUPPORT_FREE.INT', 'rzhs184_support_free_int',
            'rzhs441', 'SUPPORTFR', 'SUPPORT_FREE.INT', 'SUPPORT_FREE.INT', 'rzhs441_support_free_int');
    add_row('SUPPORTFR', 'SUPPORTFR', 'SUPPORT_FREE',
            'rzhs184', 'SUPPORTFR', 'SUPPORT_FREE.ENTW', 'rzhs184_support_free_entw',
            'rzhs441', 'SUPPORTFR', 'SUPPORT_FREE.ENTW', 'SUPPORT_FREE.ENTW', 'rzhs441_support_free_entw');

    -- PINGO
    add_row('PINGO', 'PINGO', 'PINGO',
            'rzhs184', 'PINGO', 'PINGO.PROD', 'rzhs184_pingo_prod',
            'rzhs442', 'PINGO', 'PINGO.PROD', 'PINGO.PROD', 'rzhs442_pingo_prod');
    add_row('PINGO', 'PINGO', 'PINGO',
            'rzhs184', 'PINGO', 'PINGO.INT', 'rzhs184_pingo_int',
            'rzhs442', 'PINGO', 'PINGO.INT', 'PINGO.INT', 'rzhs442_pingo_int');
    add_row('PINGO', 'PINGO', 'PINGO',
            'rzhs184', 'PINGO', 'PINGO.ENTW', 'rzhs184_pingo_entw',
            'rzhs442', 'PINGO', 'PINGO.ENTW', 'PINGO.ENTW', 'rzhs442_pingo_entw');

    -- IT_FALL
    add_row('IT_FALL', 'IT-Fall-Verwaltung', 'IT_FALL',
            'rzhs159', 'ITPROD', 'ITPROD', 'rzhs159_itprod',
            'rzhs441', 'ITFALL', 'ITPROD', 'IT.PROD', 'rzhs441_itfallprod');
    add_row('IT_FALL', 'IT-Fall-Verwaltung', 'IT_FALL',
            'rzhs159', 'ITPROD', 'ITPROD', 'rzhs159_itprod',
            'rzhs441', 'ITFALL', 'ITINT', 'IT.INT', 'rzhs441_itfallint');
    add_row('IT_FALL', 'IT-Fall-Verwaltung', 'IT_FALL',
            'rzhs159', 'ITPROD', 'ITPROD', 'rzhs159_itprod',
            'rzhs441', 'ITFALL', 'ITENTW', 'IT.ENTW', 'rzhs441_itfallentw');

    -- GG
    add_row('GG', 'Goettinger Gruppe', 'RZ782',
            'rzhs406', 'PARADO', 'PARADOX', 'rzhs406_paradox_prod',
            'rzhs440', 'GG', 'GGPROD', 'GG.PRD', 'rzhs440_ggprod');
    add_row('GG', 'Goettinger Gruppe', 'RZ782',
            'rzhs406', 'PARADO', 'PARADOX', 'rzhs406_paradox_prod',
            'rzhs440', 'GG', 'GGINT', 'GG.INT', 'rzhs440_ggint');
    add_row('GG', 'Goettinger Gruppe', 'RZ782',
            'rzhs406', 'PARADO', 'PARADOX', 'rzhs406_paradox_prod',
            'rzhs440', 'GG', 'GGENTW', 'GG.ENTW', 'rzhs440_ggentw');

    commit;
end;
/

select fv.fv_name,
       src.hostname || '_' || sc.cdb_name || '_' || sp.pdb_name as quelle,
       tgt.hostname || '_' || tc.cdb_name || '_' || tp.pdb_name as ziel,
       tp.service_name,
       sp.dblink_name as quelle_dblink,
       tp.dblink_name as ziel_dblink
from   mt_fachverfahren fv
join   mt_fv_pdb_mapping sm on sm.fv_id = fv.fv_id and sm.mapping_role = 'QUELLE'
join   mt_pdb sp            on sp.pdb_id = sm.pdb_id
join   mt_cdb sc            on sc.cdb_id = sp.cdb_id
join   mt_server src        on src.server_id = sc.server_id
join   mt_fv_pdb_mapping tm on tm.fv_id = fv.fv_id and tm.mapping_role = 'WORKBENCH'
join   mt_pdb tp            on tp.pdb_id = tm.pdb_id
join   mt_cdb tc            on tc.cdb_id = tp.cdb_id
join   mt_server tgt        on tgt.server_id = tc.server_id
where  nvl(sp.tier, '-') = nvl(tp.tier, '-')
or     fv.fv_kuerzel in ('GG', 'IT_FALL')
order  by fv.fv_name, tp.service_name;
