set echo on
set define off
whenever sqlerror continue

--------------------------------------------------------------------------------
-- Migration Tracker - Live DB Link Query Library
-- Projekt: Doppelter Dreisprung / STrausS APEX-Landesverfahren
-- Schema: migration
--
-- This file is intentionally a query library/template.
--
-- Replace ##DBLINK## with the confirmed DB Link name, normally derived from:
-- mt_fachverfahren -> mt_fv_pdb_mapping (QUELLE) -> mt_pdb -> mt_cdb
-- -> mt_server.dblink_name
--
-- Bind variables expected by APEX Page 9:
--   :P9_SCHEMA_NAME     Database schema name to compare
--   :P9_MIGRATION_DATE  Migration/import date for forward-change detection
--
-- TODO DBA: Do not invent missing DB Link, schema, PDB, CDB, or service names.
-- Use placeholders such as ##SERVER_RZHS4XX_LINK## until DBA confirmation.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- A) Object count by type: source vs target
--------------------------------------------------------------------------------
select coalesce(src.object_type, tgt.object_type) as object_type,
       nvl(src.object_count, 0)                   as source_count,
       nvl(tgt.object_count, 0)                   as target_count,
       case
           when nvl(src.object_count, 0) = nvl(tgt.object_count, 0)
           then 'OK'
           else 'DIFF'
       end                                        as diff_flag
from (
    select object_type,
           count(*) as object_count
    from   all_objects@##DBLINK##
    where  owner = upper(:P9_SCHEMA_NAME)
    and    object_type in (
               'TABLE', 'VIEW', 'PROCEDURE', 'FUNCTION', 'PACKAGE',
               'PACKAGE BODY', 'TRIGGER', 'SEQUENCE', 'INDEX',
               'SYNONYM', 'TYPE', 'TYPE BODY')
    and    object_name not like 'BIN$%'
    group  by object_type
) src
full outer join (
    select object_type,
           count(*) as object_count
    from   dba_objects
    where  owner = upper(:P9_SCHEMA_NAME)
    and    object_type in (
               'TABLE', 'VIEW', 'PROCEDURE', 'FUNCTION', 'PACKAGE',
               'PACKAGE BODY', 'TRIGGER', 'SEQUENCE', 'INDEX',
               'SYNONYM', 'TYPE', 'TYPE BODY')
    and    object_name not like 'BIN$%'
    group  by object_type
) tgt
on tgt.object_type = src.object_type
order by object_type;

--------------------------------------------------------------------------------
-- B) Invalid objects: source vs target
--------------------------------------------------------------------------------
select 'QUELLE'             as seite,
       object_name,
       object_type,
       status,
       last_ddl_time
from   all_objects@##DBLINK##
where  owner = upper(:P9_SCHEMA_NAME)
and    status <> 'VALID'
and    object_name not like 'BIN$%'
union all
select 'ZIEL'               as seite,
       object_name,
       object_type,
       status,
       last_ddl_time
from   dba_objects
where  owner = upper(:P9_SCHEMA_NAME)
and    status <> 'VALID'
and    object_name not like 'BIN$%'
order by seite, object_type, object_name;

--------------------------------------------------------------------------------
-- C) Forward changes on source after migration date
--------------------------------------------------------------------------------
select object_name,
       object_type,
       status,
       last_ddl_time
from   all_objects@##DBLINK##
where  owner = upper(:P9_SCHEMA_NAME)
and    last_ddl_time > :P9_MIGRATION_DATE
and    object_name not like 'BIN$%'
order by last_ddl_time desc, object_type, object_name;

--------------------------------------------------------------------------------
-- D) Tablespace usage: source vs target
--------------------------------------------------------------------------------
select coalesce(src.tablespace_name, tgt.tablespace_name) as tablespace_name,
       nvl(src.table_count, 0)                            as source_table_count,
       nvl(tgt.table_count, 0)                            as target_table_count,
       case
           when src.tablespace_name is null then 'NUR_ZIEL'
           when tgt.tablespace_name is null then 'NUR_QUELLE'
           when src.table_count = tgt.table_count then 'OK'
           else 'DIFF'
       end                                                as diff_flag
from (
    select nvl(tablespace_name, '<NULL>') as tablespace_name,
           count(*)                      as table_count
    from   all_tables@##DBLINK##
    where  owner = upper(:P9_SCHEMA_NAME)
    group  by nvl(tablespace_name, '<NULL>')
) src
full outer join (
    select nvl(tablespace_name, '<NULL>') as tablespace_name,
           count(*)                      as table_count
    from   dba_tables
    where  owner = upper(:P9_SCHEMA_NAME)
    group  by nvl(tablespace_name, '<NULL>')
) tgt
on tgt.tablespace_name = src.tablespace_name
order by tablespace_name;

--------------------------------------------------------------------------------
-- E) APEX application comparison
--
-- TODO DBA/APEX: Confirm whether workspace name equals schema name for each
-- Fachverfahren. If not, add/use a dedicated workspace bind item/table column.
--------------------------------------------------------------------------------
select coalesce(src.application_id, tgt.application_id)       as application_id,
       coalesce(src.application_name, tgt.application_name)   as application_name,
       src.workspace                                         as source_workspace,
       tgt.workspace                                         as target_workspace,
       src.page_count                                        as source_page_count,
       tgt.page_count                                        as target_page_count,
       src.last_updated_on                                   as source_last_updated_on,
       tgt.last_updated_on                                   as target_last_updated_on,
       case
           when src.application_id is null then 'NUR_ZIEL'
           when tgt.application_id is null then 'NUR_QUELLE'
           when nvl(src.page_count, -1) = nvl(tgt.page_count, -1) then 'OK'
           else 'DIFF'
       end                                                   as diff_flag
from (
    select a.application_id,
           a.application_name,
           a.workspace,
           (select count(*)
            from   apex_application_pages@##DBLINK## p
            where  p.application_id = a.application_id) as page_count,
           a.last_updated_on
    from   apex_applications@##DBLINK## a
    where  upper(a.workspace) = upper(:P9_SCHEMA_NAME)
) src
full outer join (
    select a.application_id,
           a.application_name,
           a.workspace,
           (select count(*)
            from   apex_application_pages p
            where  p.application_id = a.application_id) as page_count,
           a.last_updated_on
    from   apex_applications a
    where  upper(a.workspace) = upper(:P9_SCHEMA_NAME)
) tgt
on tgt.application_id = src.application_id
order by application_id;

--------------------------------------------------------------------------------
-- Verify DB Link reachability
--------------------------------------------------------------------------------
select 'OK' as dblink_status
from   dual@##DBLINK##;
