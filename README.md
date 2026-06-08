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
@13_verify_live_vergleich.sql
```

`12_create_rzhs440_dblinks.sql` asks for the DB-link password interactively. Do not commit passwords.

## Live Vergleich

Page 10 is the launcher. Page 9 runs the comparison.

The comparison uses DB links and compares:

- object counts from `ALL_OBJECTS`
- invalid objects from `ALL_OBJECTS`
- forward changes using `LAST_DDL_TIME`
- tablespace usage from `ALL_TABLES`
- APEX apps/pages from `APEX_APPLICATIONS` and `APEX_APPLICATION_PAGES`

Rows with missing or placeholder DB links are hidden from the runnable dropdown and shown in the TODO report.

## Source Of Truth

`dblinks.docx` and the ALV migration spreadsheet are authoritative for DB links, CDB/PDB/service names, and mappings. Do not invent host, service, schema, PDB, or DB-link names.

## Notes

This repo contains deployable SQL/APEX scripts only. Local ORDS/APEX runtime files, logs, local test scripts, and secrets are intentionally ignored.
