set echo on
set define off
whenever sqlerror exit sql.sqlcode rollback

-- =============================================================================
-- Migration Tracker - Final navigation cleanup
-- Anwendung: Migration_Tracker  Workspace: MIGRATION
--
-- Zweck:
--   Alte Navigationseintraege (Fachverfahren, Caesar Orders, Checkliste,
--   Service Name Audit, Server Inventory, Home) direkt aus der APEX-Metadaten-
--   Tabelle entfernen, damit sie auch nicht kurz beim Seitenwechsel aufblitzen.
--
-- WICHTIG:
--   Dieses Skript muss als SYS, APEX_240100 oder ein entsprechend privilegierter
--   DBA-User laufen. Als MIGRATION wird es wahrscheinlich ORA-01031 liefern.
--
-- Scope:
--   Nur App "Migration_Tracker" im Workspace "MIGRATION".
-- =============================================================================

declare
    l_workspace_id number;
    l_app_id       number;
    l_apex_owner   varchar2(128);
    l_sql          varchar2(32767);
begin
    select workspace_id
    into   l_workspace_id
    from   apex_workspaces
    where  workspace = 'MIGRATION';

    select application_id
    into   l_app_id
    from (
        select application_id
        from   apex_applications
        where  workspace = 'MIGRATION'
        and    application_name = 'Migration_Tracker'
        order  by application_id
    )
    where rownum = 1;

    select owner
    into   l_apex_owner
    from (
        select owner
        from   all_tables
        where  table_name = 'WWV_FLOW_LIST_ITEMS'
        and    owner like 'APEX\_%' escape '\'
        order  by owner desc
    )
    where rownum = 1;

    -- Delete stale menu entries from removed/hidden pages.
    -- The app scripts can recreate the two final entries if needed.
    l_sql :=
        'delete from ' || dbms_assert.schema_name(l_apex_owner) || '.wwv_flow_list_items i ' ||
        'where  i.flow_id = :app_id ' ||
        'and    ( ' ||
        '          i.list_item_link_text in (''Home'', ' ||
        '                                    ''Fachverfahren'', ' ||
        '                                    ''Caesar Orders'', ' ||
        '                                    ''Checkliste'', ' ||
        '                                    ''Service Name Audit'', ' ||
        '                                    ''Server Inventory'') ' ||
        '       or regexp_like(i.list_item_link_target, ''[:.]([2-8])[:.]'') ' ||
        '       )';
    execute immediate l_sql using l_app_id;

    -- Ensure the two final visible entries remain visible.
    l_sql :=
        'update ' || dbms_assert.schema_name(l_apex_owner) || '.wwv_flow_list_items i ' ||
        'set    item_displayed = ''ALWAYS'', ' ||
        '       list_item_status = ''PUBLIC'', ' ||
        '       list_item_disp_cond_type = null, ' ||
        '       list_item_display_sequence = case ' ||
        '           when i.list_item_link_text like ''APEX Migration%'' then 10 ' ||
        '           when i.list_item_link_text = ''Live Vergleich'' then 20 ' ||
        '           else i.list_item_display_sequence ' ||
        '       end, ' ||
        '       last_updated_by = ''MIGRATION_CLEANUP'', ' ||
        '       last_updated_on = sysdate ' ||
        'where  i.flow_id = :app_id ' ||
        'and    (i.list_item_link_text like ''APEX Migration%'' ' ||
        '        or i.list_item_link_text = ''Live Vergleich'' ' ||
        '        or regexp_like(i.list_item_link_target, ''[:.]1[:.]'') ' ||
        '        or regexp_like(i.list_item_link_target, ''[:.]10[:.]''))';
    execute immediate l_sql using l_app_id;

    commit;
end;
/

select entry_text,
       entry_target,
       display_sequence
from   apex_application_list_entries
where  application_id = (
           select min(application_id)
           from   apex_applications
           where  workspace = 'MIGRATION'
           and    application_name = 'Migration_Tracker'
       )
and    list_name = 'Navigation Menu'
order  by display_sequence, entry_text;
