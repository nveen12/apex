set echo on
set define off
set pagesize 200
set linesize 240
whenever sqlerror exit sql.sqlcode rollback

--------------------------------------------------------------------------------
-- Migration Tracker - Live Vergleich Verification
-- Run as MIGRATION on rzhs440/opk.entw.
-- Read-only verification after 07/10 page scripts and DB link setup.
--------------------------------------------------------------------------------

prompt === APEX PAGES ===
select page_id, page_name
from   apex_application_pages
where  application_id = 114
and    page_id in (9, 10)
order  by page_id;

prompt === PAGE 10 REGIONS ===
select region_name, display_sequence
from   apex_application_page_regions
where  application_id = 114
and    page_id = 10
order  by display_sequence;

prompt === PAGE 9 STATUS ITEMS ===
select item_name, display_sequence
from   apex_application_page_items
where  application_id = 114
and    page_id = 9
and    item_name in (
           'P9_MAPPING_ID',
           'P9_FV_ID',
           'P9_SCHEMA_NAME',
           'P9_SRC_DBLINK_NAME',
           'P9_TGT_DBLINK_NAME',
           'P9_COMPARE_OK',
           'P9_STATUS_TEXT'
       )
order  by display_sequence;

prompt === PRIVATE DB LINKS ===
select db_link, username, host
from   user_db_links
order  by db_link;

prompt === RUNNABLE LIVE VERGLEICH MAPPINGS ===
select fv.fv_name,
       tp.service_name,
       sp.dblink_name as src_link,
       tp.dblink_name as tgt_link
from   mt_fachverfahren fv
join   mt_fv_pdb_mapping tm on tm.fv_id = fv.fv_id and tm.mapping_role = 'WORKBENCH'
join   mt_pdb tp            on tp.pdb_id = tm.pdb_id
join   mt_fv_pdb_mapping sm on sm.fv_id = fv.fv_id and sm.mapping_role = 'QUELLE'
join   mt_pdb sp            on sp.pdb_id = sm.pdb_id
where  (nvl(sp.tier, '-') = nvl(tp.tier, '-') or fv.fv_kuerzel in ('GG', 'IT_FALL'))
and    nvl(tm.aktiv, 'J') = 'J'
and    nvl(sm.aktiv, 'J') = 'J'
and    sp.dblink_name is not null
and    tp.dblink_name is not null
and    sp.dblink_name not like '##%##'
and    tp.dblink_name not like '##%##'
order  by fv.fv_name, tp.service_name;

prompt === TODO: DB LINKS MISSING / PLACEHOLDER ===
select fv.fv_name,
       tp.service_name,
       sp.dblink_name as src_link,
       tp.dblink_name as tgt_link
from   mt_fachverfahren fv
join   mt_fv_pdb_mapping tm on tm.fv_id = fv.fv_id and tm.mapping_role = 'WORKBENCH'
join   mt_pdb tp            on tp.pdb_id = tm.pdb_id
join   mt_fv_pdb_mapping sm on sm.fv_id = fv.fv_id and sm.mapping_role = 'QUELLE'
join   mt_pdb sp            on sp.pdb_id = sm.pdb_id
where  (nvl(sp.tier, '-') = nvl(tp.tier, '-') or fv.fv_kuerzel in ('GG', 'IT_FALL'))
and    nvl(tm.aktiv, 'J') = 'J'
and    nvl(sm.aktiv, 'J') = 'J'
and    (sp.dblink_name is null
        or tp.dblink_name is null
        or sp.dblink_name like '##%##'
        or tp.dblink_name like '##%##')
order  by fv.fv_name, tp.service_name;

prompt === VERIFY COMPLETE ===
