# APEX Migration Tracker

Internal Oracle APEX migration tracker for the Doppelter Dreisprung / ALV migration work.

## Target

- Workspace: `MIGRATION`
- Schema: `MIGRATION`
- Application ID on rzhs440: `114`
- Target connection: `migration@opk.entw`
- APEX: `24.1`

## Deploy Order On rzhs440

Run as `MIGRATION`:

```sql
@00_preflight_rzhs440_schema.sql
@05_schema_object_tracking.sql
@11_seed_screenshot_mapping.sql
@12_create_rzhs440_dblinks.sql
@07_page9_live_vergleich.sql
@10_live_vergleich_start.sql
@15_apex_final_overview.sql
@13_verify_live_vergleich.sql
```

`12_create_rzhs440_dblinks.sql` asks for the DB-link password interactively. Do not commit passwords.

## Live Vergleich

The visible app is intentionally small:

- Page 1: `APEX Migration Übersicht`
- Page 10: `Live Vergleich`

Page 9 remains as the hidden/detail page that runs the comparison after Page 10 starts it.
Old operational pages 2-8 are removed by `15_apex_final_overview.sql`.
The overview rows are stored in `MT_APEX_MIGRATION_OVERVIEW` and Page 1 is an editable
Interactive Grid, so rows can be added or changed directly in APEX.

The comparison uses DB links and compares:

- object counts from `ALL_OBJECTS`
- target invalid objects that are valid on source from `ALL_OBJECTS`
- tablespace usage from `ALL_TABLES`
- APEX apps/pages from `APEX_APPLICATIONS` and `APEX_APPLICATION_PAGES`
- APEX compatibility risk indicators: missing apps, page-count differences, missing pages
- APEX runtime risk indicators: auth differences, custom JS/CSS, plugins, REST/web sources,
  process-count differences, dynamic-action differences

Rows with missing or placeholder DB links are hidden from the runnable dropdown and shown in the TODO report.

The APEX compatibility/runtime sections are static metadata checks. They flag likely migration
risks and tell the team where to test first. They cannot prove browser behavior, real external
system connectivity, Jasper output, authentication success for real users, or functional correctness.
PL/SQL source text scanning for Jasper/URL references is not done in the live DB-link page because
remote APEX dictionary source columns can be CLOBs and may raise LOB-over-DB-link errors.

## Source Of Truth

`dblinks.docx` and the ALV migration spreadsheet are authoritative for DB links, CDB/PDB/service names, and mappings. Do not invent host, service, schema, PDB, or DB-link names.

## Notes

This repo contains deployable SQL/APEX scripts only. Local ORDS/APEX runtime files, logs, local test scripts, and secrets are intentionally ignored.
