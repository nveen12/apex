set echo on
set define off
set pagesize 200
set linesize 240
whenever sqlerror exit sql.sqlcode rollback

--------------------------------------------------------------------------------
-- Migration Tracker - rzhs440 Preflight
-- Purpose: Read-only schema shape check before running seed/page scripts.
-- Run as MIGRATION on rzhs440/opk.entw.
--------------------------------------------------------------------------------

prompt === CURRENT USER / CONTAINER ===
select user as current_user,
       sys_context('USERENV', 'CURRENT_SCHEMA') as current_schema,
       sys_context('USERENV', 'CON_NAME') as con_name
from   dual;

prompt === CORE TABLES PRESENT ===
select table_name
from   user_tables
where  table_name in (
           'MT_SERVER',
           'MT_CDB',
           'MT_PDB',
           'MT_FACHVERFAHREN',
           'MT_FV_PDB_MAPPING',
           'MT_SCHEMA_MIGRATION',
           'MT_OBJECT_DIFF'
       )
order  by table_name;

prompt === COLUMN SHAPE / NULLABILITY ===
select table_name,
       column_id,
       column_name,
       data_type,
       data_length,
       nullable,
       data_default
from   user_tab_columns
where  table_name in (
           'MT_SERVER',
           'MT_CDB',
           'MT_PDB',
           'MT_FACHVERFAHREN',
           'MT_FV_PDB_MAPPING'
       )
order  by table_name, column_id;

prompt === CHECK CONSTRAINTS ON CORE TABLES ===
select c.table_name,
       c.constraint_name,
       c.status,
       c.validated,
       c.search_condition_vc as search_condition
from   user_constraints c
where  c.constraint_type = 'C'
and    c.table_name in (
           'MT_SERVER',
           'MT_CDB',
           'MT_PDB',
           'MT_FACHVERFAHREN',
           'MT_FV_PDB_MAPPING'
       )
order  by c.table_name, c.constraint_name;

prompt === CURRENT SERVER VALUES ===
select server_id, hostname, umgebung, dblink_name
from   mt_server
order  by server_id;

prompt === CURRENT MAPPING ROLE VALUES ===
select 'ROLLE' as column_name, rolle as value, count(*) as anzahl
from   mt_fv_pdb_mapping
group  by rolle
union all
select 'MAPPING_ROLE' as column_name, mapping_role as value, count(*) as anzahl
from   mt_fv_pdb_mapping
group  by mapping_role
order  by column_name, value;

prompt === PREFLIGHT COMPLETE ===
