set echo on
set define off
set serveroutput on size unlimited
whenever sqlerror exit sql.sqlcode rollback

--------------------------------------------------------------------------------
-- Diagnose ORA-02019 for Live Vergleich DB links
-- Run as: MIGRATION on rzhs440:1521/opk.entw
--
-- ORA-02019 usually means an active mapping points to a DB link that does not
-- exist in the current schema, or the DB link uses an unresolved TNS alias.
--------------------------------------------------------------------------------

prompt
prompt === Active Live Vergleich mappings and DB link existence ===

column fv_name format a30
column role_name format a12
column endpoint format a45
column dblink_name format a32
column link_status format a12

with active_links as (
    select fv.fv_name,
           m.mapping_role as role_name,
           s.hostname || ' / ' || c.cdb_name || ' / ' || p.pdb_name as endpoint,
           p.service_name,
           p.dblink_name
    from   mt_fv_pdb_mapping m
    join   mt_fachverfahren fv on fv.fv_id = m.fv_id
    join   mt_pdb p            on p.pdb_id = m.pdb_id
    join   mt_cdb c            on c.cdb_id = p.cdb_id
    join   mt_server s         on s.server_id = c.server_id
    where  nvl(m.aktiv, 'J') = 'J'
    and    m.mapping_role in ('QUELLE', 'WORKBENCH')
    and    p.dblink_name is not null
    and    p.dblink_name not like '##%##'
)
select a.fv_name,
       a.role_name,
       a.endpoint,
       a.service_name,
       a.dblink_name,
       case
           when exists (
                    select 1
                    from   user_db_links l
                    where  l.db_link = upper(a.dblink_name)
                    or     l.db_link like upper(a.dblink_name) || '.%'
                )
           then 'EXISTS'
           else 'MISSING'
       end as link_status
from   active_links a
order  by a.fv_name, a.role_name, a.service_name;

prompt
prompt === Active mappings with missing DB links only ===

with active_links as (
    select fv.fv_name,
           m.mapping_role as role_name,
           s.hostname || ' / ' || c.cdb_name || ' / ' || p.pdb_name as endpoint,
           p.service_name,
           p.dblink_name
    from   mt_fv_pdb_mapping m
    join   mt_fachverfahren fv on fv.fv_id = m.fv_id
    join   mt_pdb p            on p.pdb_id = m.pdb_id
    join   mt_cdb c            on c.cdb_id = p.cdb_id
    join   mt_server s         on s.server_id = c.server_id
    where  nvl(m.aktiv, 'J') = 'J'
    and    m.mapping_role in ('QUELLE', 'WORKBENCH')
    and    p.dblink_name is not null
    and    p.dblink_name not like '##%##'
)
select a.fv_name,
       a.role_name,
       a.endpoint,
       a.service_name,
       a.dblink_name
from   active_links a
where  not exists (
           select 1
           from   user_db_links l
           where  l.db_link = upper(a.dblink_name)
           or     l.db_link like upper(a.dblink_name) || '.%'
       )
order  by a.fv_name, a.role_name, a.service_name;

prompt
prompt === Connectivity test for existing active DB links ===

declare
    l_dummy number;
begin
    for r in (
        select distinct p.dblink_name
        from   mt_fv_pdb_mapping m
        join   mt_pdb p on p.pdb_id = m.pdb_id
        where  nvl(m.aktiv, 'J') = 'J'
        and    m.mapping_role in ('QUELLE', 'WORKBENCH')
        and    p.dblink_name is not null
        and    p.dblink_name not like '##%##'
        and    exists (
                   select 1
                   from   user_db_links l
                   where  l.db_link = upper(p.dblink_name)
                   or     l.db_link like upper(p.dblink_name) || '.%'
               )
        order by p.dblink_name
    ) loop
        begin
            execute immediate 'select 1 from dual@' ||
                              dbms_assert.simple_sql_name(r.dblink_name)
                         into l_dummy;
            dbms_output.put_line(r.dblink_name || ' : OK');
        exception
            when others then
                dbms_output.put_line(r.dblink_name || ' : ' || sqlerrm);
        end;
    end loop;
end;
/

prompt
prompt === End diagnose ORA-02019 ===
