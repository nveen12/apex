set echo on
set define off

--------------------------------------------------------------------------------
-- Migration Tracker - AEN source DB-link coverage check
-- Source: "Source target mapping.docx" provided 2026-06-26
--
-- Purpose:
--   Lists the PROD source DB links needed by the seeded DCS schema rules and
--   shows whether they exist in the current schema (MIGRATION.USER_DB_LINKS).
--
-- Notes:
--   - This script does not create or drop anything.
--   - Rows with TODO in service_name need DBA confirmation before a DB link is
--     created. Do not invent service names from Host_DB_PDB screenshots.
--------------------------------------------------------------------------------

column required_dblink format a32
column source_host format a24
column source_service format a28
column status format a12
column used_for_schemas format a70
column note format a80

with required_links as (
    select 'RZHS184_SEMINAR_PROD' required_dblink,
           'rzhs184' source_host,
           'SEMINAR.PROD' source_service,
           'SEMINAR, SEMINAR_JN, MBF, MBF_JN, KANBAN' used_for_schemas,
           'Confirmed in AEN mapping: SEMINR PROD.' note
    from dual
    union all
    select 'RZHS184_OPK_PROD',
           'rzhs184',
           'OPK.PROD',
           'OPK, OPK_JN',
           'Confirmed in AEN mapping: DBAE21/OPK PROD.'
    from dual
    union all
    select 'RZHS184_SUPPORT_FREE_PROD',
           'rzhs184',
           'SUPPORT_FREE.PROD',
           'AED, AED_JN, AUS_STM, BSA, GIOLJN, HAL, INFUST_BS, SV_PERLE, UTILS',
           'Confirmed in AEN mapping: SUPPORTFR PROD.'
    from dual
    union all
    select 'RZHS184_PINGO_PROD',
           'rzhs184',
           'PINGO.PROD',
           'PINGO, PINGO_JN',
           'Confirmed in AEN mapping: PNGO PROD.'
    from dual
    union all
    select 'RZHS406_PARADOX_PROD',
           'rzhs406',
           'PARADOX.PROD',
           'GOETTINGER, MASSENDRUCK_2018, RZ782, RZ782_JN',
           'Confirmed in AEN mapping: PARADO/GG PROD.'
    from dual
    union all
    select 'RZHS406_STAPOPDB_PROD',
           'rzhs406.ofd-h.de',
           'STAPOPDB.PROD',
           'STATIST, STATIST_JN, STATTEST',
           'Confirmed in AEN mapping: VOSTAT.PRD source #2.'
    from dual
    union all
    select 'RZHS407_VOLLSTRP_PROD',
           'rzhs407',
           'VOLLSTRP.PROD',
           'VOLLSTRECKUNG, VOLLSTRECKUNG_JN',
           'Confirmed in AEN mapping: VOSTAT.PRD source #1.'
    from dual
    union all
    select 'RZHS159_ITPROD',
           'rzhs159',
           'ITPROD.WORLD',
           'IT_FALL, CSALZBRUNN',
           'Confirmed in AEN mapping: ITPROD PROD.'
    from dual
    union all
    select 'RZHS184_CONTROLLING_PROD',
           'rzhs184',
           'TODO_CONFIRM_SERVICE',
           'USTSPR, USTSPR_JN',
           'AEN mapping shows Host_DB_PDB rzhs184_CNTRLNG_CONTROLLINGPROD. Confirm service before creating link.'
    from dual
    union all
    select 'RZHS184_VOPROD',
           'rzhs184',
           'TODO_CONFIRM_SERVICE',
           'VOLLSTRECKUNG, VOLLSTRECKUNG_JN for VO.PROD only',
           'AEN mapping shows Host_DB_PDB rzhs184_VLLSTR_VOPROD. Not activated as a schema rule because VOSTAT.PRD already uses VOLLSTRECKUNG from rzhs407/VOLLSTRP.PROD.'
    from dual
    union all
    select 'RZHS407_ANSPZPDB_PROD',
           'rzhs407',
           'TODO_CONFIRM_SERVICE',
           'ANSPZ, PERLE, PERLE_JN, MBF',
           'AEN mapping shows rzhs407_ANSPZ_ANSPZPDB; screenshot says schema clarification still needed.'
    from dual
)
select r.required_dblink,
       r.source_host,
       r.source_service,
       case
           when l.db_link is not null then 'OK'
           when r.source_service like 'TODO%' then 'TODO'
           else 'MISSING'
       end as status,
       r.used_for_schemas,
       r.note
from   required_links r
left join user_db_links l
       on l.db_link = r.required_dblink
       or l.db_link like r.required_dblink || '.%'
order by case
             when l.db_link is not null then 3
             when r.source_service like 'TODO%' then 2
             else 1
         end,
         r.required_dblink;

prompt
prompt Active DCS schema source rules pointing to missing USER_DB_LINKS:

select r.dcs_schema,
       r.source_dblink_name,
       r.kommentar
from   mt_dcs_schema_source_rule r
where  r.aktiv = 'J'
and    not exists (
           select 1
           from   user_db_links l
           where  l.db_link = upper(r.source_dblink_name)
           or     l.db_link like upper(r.source_dblink_name) || '.%'
       )
order  by r.source_dblink_name, r.dcs_schema;
