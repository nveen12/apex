set echo on
set define off
whenever sqlerror exit sql.sqlcode rollback

--------------------------------------------------------------------------------
-- Migration Tracker - Schema/Object Tracking
-- Projekt: Doppelter Dreisprung / STrausS APEX-Landesverfahren
-- Schema: migration
--
-- TODO DBA: DB Link inventory is incomplete. Only the explicitly confirmed
-- source server mappings below are seeded. Do not infer additional DB Links
-- from server names before DBA confirmation / ALV-Migration.ods load.
--
-- This script is idempotent so it can be rerun during local tests.
--------------------------------------------------------------------------------

declare
    l_count number;
begin
    select count(*)
    into   l_count
    from   all_tab_columns
    where  owner       = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    table_name  = 'MT_SERVER'
    and    column_name = 'DBLINK_NAME';

    if l_count = 0 then
        execute immediate 'alter table mt_server add (dblink_name varchar2(100))';
    end if;
end;
/

declare
    l_count number;
begin
    select count(*)
    into   l_count
    from   all_tab_columns
    where  owner       = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    table_name  = 'MT_PDB'
    and    column_name = 'DBLINK_NAME';

    if l_count = 0 then
        execute immediate 'alter table mt_pdb add (dblink_name varchar2(100))';
    end if;
end;
/

comment on column mt_server.dblink_name is
    'DB Link for live source comparison. NULL for AEN/DCS/ATU or unknown/unconfirmed servers.';

comment on column mt_pdb.dblink_name is
    'Service-level DB Link for live comparison. Needed because the app may run on opk.entw while targets live on other services.';

declare
    l_count      number;
    l_rolle_cols number;
begin
    select count(*)
    into   l_count
    from   all_tab_columns
    where  owner       = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    table_name  = 'MT_FV_PDB_MAPPING'
    and    column_name = 'MAPPING_ROLE';

    if l_count = 0 then
        execute immediate 'alter table mt_fv_pdb_mapping add (mapping_role varchar2(30))';
    end if;

    select count(*)
    into   l_rolle_cols
    from   all_tab_columns
    where  owner       = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    table_name  = 'MT_FV_PDB_MAPPING'
    and    column_name = 'ROLLE';

    if l_rolle_cols > 0 then
        execute immediate
            'update mt_fv_pdb_mapping set mapping_role = rolle where mapping_role is null and rolle is not null';
        commit;
    end if;
end;
/

comment on column mt_fv_pdb_mapping.mapping_role is
    'Mapping role, e.g. QUELLE or WORKBENCH. Added for live comparison compatibility.';

update mt_server
set    dblink_name = case lower(hostname)
           when 'rzhs184.ofd-h.de' then 'RZHS184_LINK'
           when 'rzhs184'          then 'RZHS184_LINK'
           when 'rzhs406.ofd-h.de' then 'RZHS406_LINK'
           when 'rzhs406'          then 'RZHS406_LINK'
           when 'rzhs407.ofd-h.de' then 'RZHS407_LINK'
           when 'rzhs407'          then 'RZHS407_LINK'
           when 'rzhs185.ofd-h.de' then 'RZHS185_LINK'
           when 'rzhs185'          then 'RZHS185_LINK'
           else null
       end;

commit;

declare
    l_count number;
begin
    select count(*)
    into   l_count
    from   all_sequences
    where  sequence_owner = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    sequence_name  = 'SEQ_SCHEMA_ID';

    if l_count = 0 then
        execute immediate q'[
            create sequence seq_schema_id
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
    and    table_name = 'MT_SCHEMA_MIGRATION';

    if l_count = 0 then
        execute immediate q'[
            create table mt_schema_migration (
                schema_id       number         not null,
                pdb_id          number         not null,
                schema_name     varchar2(128)  not null,
                obj_count_src   number,
                obj_count_tgt   number,
                invalid_obj_src number,
                invalid_obj_tgt number,
                import_status   varchar2(20)   default 'OFFEN' not null,
                import_datum    date,
                erfasst_am      date           default sysdate not null,
                fehler_notiz    varchar2(2000),
                constraint pk_mt_schema_migration
                    primary key (schema_id),
                constraint fk_mt_schema_migration_pdb
                    foreign key (pdb_id)
                    references mt_pdb (pdb_id),
                constraint uq_mt_schema_migration_pdb_schema
                    unique (pdb_id, schema_name),
                constraint ck_mt_schema_migration_status
                    check (import_status in ('OFFEN', 'OK', 'FEHLER', 'IN_ARBEIT'))
            )
        ]';
    end if;
end;
/

comment on table mt_schema_migration is
    'Schema-level migration/import tracking and saved object-count summary.';
comment on column mt_schema_migration.schema_name is
    'Database schema name. Authoritative inventory comes from ALV-Migration.ods.';
comment on column mt_schema_migration.obj_count_src is
    'Saved source object count at import/check time.';
comment on column mt_schema_migration.obj_count_tgt is
    'Saved target object count at import/check time.';

declare
    l_count number;
begin
    select count(*)
    into   l_count
    from   all_sequences
    where  sequence_owner = sys_context('USERENV', 'CURRENT_SCHEMA')
    and    sequence_name  = 'SEQ_DIFF_ID';

    if l_count = 0 then
        execute immediate q'[
            create sequence seq_diff_id
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
    and    table_name = 'MT_OBJECT_DIFF';

    if l_count = 0 then
        execute immediate q'[
            create table mt_object_diff (
                diff_id       number        not null,
                schema_id     number        not null,
                object_name   varchar2(128) not null,
                object_type   varchar2(50)  not null,
                status_quelle varchar2(10),
                status_ziel   varchar2(10),
                diff_typ      varchar2(20)  not null,
                erfasst_am    date          default sysdate not null,
                constraint pk_mt_object_diff
                    primary key (diff_id),
                constraint fk_mt_object_diff_schema
                    foreign key (schema_id)
                    references mt_schema_migration (schema_id),
                constraint ck_mt_object_diff_typ
                    check (diff_typ in ('GLEICH', 'NUR_QUELLE', 'NUR_ZIEL', 'INVALID_ZIEL'))
            )
        ]';
    end if;
end;
/

comment on table mt_object_diff is
    'Saved object-level diff snapshot for a schema migration.';
comment on column mt_object_diff.diff_typ is
    'Diff classification from source/target comparison.';

select table_name
from   all_tables
where  owner = sys_context('USERENV', 'CURRENT_SCHEMA')
and    table_name in ('MT_SCHEMA_MIGRATION', 'MT_OBJECT_DIFF')
order  by table_name;

select sequence_name
from   all_sequences
where  sequence_owner = sys_context('USERENV', 'CURRENT_SCHEMA')
and    sequence_name in ('SEQ_SCHEMA_ID', 'SEQ_DIFF_ID')
order  by sequence_name;

select hostname, dblink_name
from   mt_server
order  by hostname;

select c.cdb_name, p.pdb_name, p.service_name, p.dblink_name
from   mt_pdb p
join   mt_cdb c on c.cdb_id = p.cdb_id
order  by c.cdb_name, p.pdb_name;
