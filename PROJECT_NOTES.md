# Migration Tracker Project Notes

## DB Link mapping

Each known source server has a fixed DB Link name:

| Source server | DB Link |
| --- | --- |
| `rzhs184.ofd-h.de` | `RZHS184_LINK` |
| `rzhs406.ofd-h.de` | `RZHS406_LINK` |
| `rzhs407.ofd-h.de` | `RZHS407_LINK` |
| `rzhs185.ofd-h.de` | `RZHS185_LINK` |

This list is not complete. The full server and DB Link inventory will be provided later or confirmed by the DBA during implementation.

Rules for implementation:

- Do not hardcode or assume this is the complete DB Link inventory.
- Add/derive DB Link usage through `mt_server.dblink_name` when the feature is implemented.
- If server or DB Link information is missing, add an explicit TODO comment.
- Use placeholders such as `##SERVER_RZHS4XX_LINK##` for missing values.
- Ask the DBA before proceeding with any part that needs an unconfirmed server or DB Link.
- Do not invent server names or DB Link names.

The same rule applies to schema names, PDB names, CDB names, and service names. `ALV-Migration.ods` is the authoritative source, but it has not been fully loaded into the app yet. Any Fachverfahren, schema, PDB, CDB, service, or server list from the current conversation is illustrative, not exhaustive.

## Live comparison constraints

- DB Links do not exist yet and will be created manually by the DBA before the live comparison feature is used.
- Remote source queries should use `ALL_OBJECTS`, not `DBA_OBJECTS`, because the DB Link user may only have schema-level SELECT.
- Local rzhs440/migration-side queries may use `DBA_OBJECTS` where the schema has privileges.
- SQL/code remains English; APEX labels should be German.
- Dates should be formatted as `DD.MM.YYYY`.
