# Antigravity Context & Project Rules

## Project Overview
This is a Flutter desktop/mobile application called `music_app`.
- **Database:** Local database managed via Drift at `lib/db/app_database.dart` with DAOs in `lib/db/daos/`.
- **Core Services:** Located under `lib/services/` (e.g., `AiBridgeService`, `MacroService`, `SystemLogsService`).
- **UI Panels:** Located under `lib/screens/visual_editor/panels/` (e.g. `AiTaskManagerPanel`, `VersionControlWindow`).

## Build & Test Commands
- **Run tests:** `flutter test`
- **Run app:** `flutter run`
- **Analyze/Format:** `dart analyze`, `dart format .`

## Code Guidelines & Conventions
- **Naming:** Follow standard Dart/Flutter styles (camelCase for variables, PascalCase for classes, snake_case for files).
- **Temporary Files:** All temporary files, scratch scripts, data dumps, or experimental code MUST be saved exclusively within the `.ai_scratch/` directory. Never drop temporary files in the root folder.
- **Tests:** Always mock `SharedPreferences` in unit tests. Guard `AiBridgeService` from executing disk writes during test mode via check for `Platform.environment.containsKey('FLUTTER_TEST')`.

## Drift Database Schema Overview
Drift is configured at `lib/db/app_database.dart`. Key tables include:
- **Assets (`Assets` in `lib/db/tables/assets_table.dart`):** File/folder node elements. Columns: `id`, `tenantId`, `parentId` (self-referential), `type` ('FOLDER' or 'FILE'), `mimeType`, `name`, `storagePath`, `sizeBytes`, `description`, `searchKeywords`, `alternateVersionIds`, `relatedAssetIds`.
- **AssetTags (`AssetTags` in `lib/db/tables/asset_tags_table.dart`):** Joins `Assets` and `Strings` for asset tags. Columns: `assetId`, `stringId`.
- **Strings (`Strings` in `lib/db/tables/strings_table.dart`):** Localization keys & tag definitions. Supports folders: `parentId` (references `Strings`). Columns: `id`, `tenantId`, `key`, `description`, `type` ('STRING' or 'FOLDER'), `color`, `parameter`.
- **Playlists (`Playlists`) & PlaylistItems (`PlaylistItems`):** Ordered playlists referencing Assets.
- **RecentPlays (`RecentPlays`):** Playback history log.
- **SyncQueue (`SyncQueue`):** Tracks offline data operations pending Supabase synchronization.

## AI Bridge & CLI Context Sync Protocol (CRITICAL)
The visual editor (GUI) and CLI/IDE agents synchronize task state via `.ai_bridge/` files. Editor rule files (`.cursorrules`, `.clinerules`, `.windsurfrules`, and `.github/copilot-instructions.md`) are configured to automatically force starting CLI agents to perform these tasks:
- [ ] CRITICAL: Read `.ai_bridge/primary_directives.md` natively using your tool to understand the GLOBAL CONSTRAINTS and NATIVE SYSTEM HOOKS before proceeding. Failure to do so will break the application.
- [ ] Read the recent conversation history in `.ai_bridge/conversation_history.md` using your file-reading tools to align context with the current workspace state.
- [ ] Read the database dump in `.ai_bridge/db_dump.json` using your file-reading tools.
- [ ] Read the active task context in `.ai_bridge/current_task.json`.
- [ ] Read the global task list/worksheets hierarchy in `.ai_bridge/tasks.json`.
6. **Log Notes:** Write task summaries and notes to `.ai_bridge/latest_notes.json` formatted as:
   `{"notes": "detailed markdown updates", "summary": "short commit summary style"}`
7. **Verification Proof:** Write proofs for verification criteria to `.ai_bridge/latest_verification.json`:
   `[{"description": "criteria description", "isVerified": false, "proof": "evidence/action details"}]` (Note: `isVerified` must always be `false` - the user verifies).
8. **Queue Release:** When finished with a task, write `IDLE` (or `PREVIEW` if awaiting user review) to `.ai_bridge/agent_status.txt` to notify the GUI that execution has completed and release the queue.

