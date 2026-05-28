# Project Summary

* **Overview**: The overall system is called **Gorilla Engine**, which acts as a platform enabling the creation and management of localized projects. The active project, `music_app`, is built within Gorilla Engine as a dedicated media library manager and visual task management suite.
* **Primary Purpose**: It serves as an integrated media library controller and visual workspace task manager that synchronizes development progress directly with AI coding assistants (e.g., Antigravity).
* **Core Problem Solved**: It bridges the gap between IDE code-editing sessions and visual task management, coordinating state files seamlessly so that autonomous AI agents and developers stay aligned on task progress, verification criteria, and workspace context in real-time.

# Project Scope

* **Major Capabilities**:
  * Local media indexing and library organization (managing assets, folder hierarchies, and playlists).
  * Audio playback (supporting formats like MP3 and lyrics parsing with LRC).
  * Interactive task management interface (a visual task manager showing task worksheets, checklists, priorities, and statuses).
  * AI assistant integration via a custom sync queue and bidirectional file bridge.
  * Version control system (Git) integration and local database replication/migration helpers.
* **Main Feature Areas**:
  * **Media Workspace**: Assets, Tags, Languages folders, and custom music playlists.
  * **AI Bridge & CLI Sync**: Real-time task queuing, background status polling, and agent state monitoring.
  * **Visual Editor & Configuration**: Advanced UI customizations, hot reload/restart triggers, and API settings (Ollama and Antigravity SDK).
* **Intended Users**: Software developers and content managers who use AI-agent pipelines paired with a graphical manager interface.

# Architecture Overview

* **System Structure**: A Flutter desktop application utilizing a local database layer, service registry/providers, and dynamic widget panels.
* **Major Modules & Folders**:
  * [lib/db/](file:///c:/Development/Music/Project/lib/db/): Local database schema and Drift table mappings.
  * [lib/services/](file:///c:/Development/Music/Project/lib/services/): Core business logic including the AI Bridge service, macro executor, and system logs manager.
  * [lib/screens/visual_editor/](file:///c:/Development/Music/Project/lib/screens/visual_editor/): Visual workspace layout, system panels, and docking managers.
* **Key Application Layers**:
  * **Presentation**: Flutter UI widgets and panels (e.g., `AiTaskManagerPanel`).
  * **Service/Domain**: Singleton service instances managing background coordination (`AiBridgeService`).
  * **Persistence**: Local database using Drift (`AppDatabase`) and configuration preferences via `SharedPreferences`.
* **Important Services**:
  * **`AiBridgeService`**: Manages the task execution queue, writes state files, and listens for status updates from the agent.
  * **`MacroService`**: Executes system automation scripts and macro files.
  * **`SandboxService`**: Manages the isolation directory for executing tasks safely.

# Program Flow

* **Runtime Flow**:
  1. The application starts, initializing `SharedPreferences`, `Drift` database, and starting core services.
  2. The UI renders the visual workspace, task editor, and the AI Assistant panels.
  3. The `AiBridgeService` begins polling the `.ai_bridge/agent_status.txt` file and checking task queues.
  4. When a user queues or submits a checklist item, the bridge builds the dynamic prompt, saves the current task context to `current_task.json`, writes `BUSY` to `agent_status.txt`, and dispatches the prompt.
  5. The external agent runs, executes instructions, writes `latest_notes.json` and `latest_verification.json`, and updates `agent_status.txt` to `IDLE` (or `PREVIEW`).
  6. The visual editor detects the status change, ingests the output files, applies task modifications, deletes the temporary files, and restarts/reloads the UI.

# Key Technologies

* **Language**: Dart (Flutter SDK)
* **Databases**: Drift (SQLite wrapper for Dart)
* **Integrations & APIs**:
  * **Antigravity SDK / Client**: High-tier agent invocation API.
  * **Ollama API**: Local LLM connection for task/checklist generation and rewriting.
  * **Git / GitHub API**: Version control and sync.
* **State Management**: ChangeNotifier & ValueNotifier provider patterns.

# User Interface Overview

* **Main Structure**: Tabbed docking panels allowing developers to customize their active workspace layout.
* **Major Screens/Panels**:
  * **`AiTaskManagerPanel`**: The task checklist, worksheet manager, and AI Bridge queue viewer.
  * **`ProjectConfigurationPanel`**: Configuration settings for Ollama, Antigravity, Git repositories, and theme customizations.
  * **`GlobalTaskEditorWindow`**: Window interface to edit, ignore, color-code, or add checklist criteria to tasks.
* **State Approach**: Native Flutter listeners and notifier bindings ensuring synchronous updates.

# Key Terms and Concepts

* **Gorilla Engine**: The parent platform architecture enabling modular projects and workspaces.
* **AI Bridge**: The file-based interface and protocol situated in the `.ai_bridge/` folder.
* **Worksheet**: A high-level category or list grouping multiple tasks/folders together.
* **Verification Criteria**: Specific checklist items bound to a task that the AI agent must verify and provide evidence/proof for.
* **Context Drift**: Occurs when active task instructions deviate from the master project summary goals.

# Task System Overview

* **`tasks.json`**: The central task repository tracking all worksheets, folders, tasks, and verification items.
* **Task Lifecycle**: `open` ➔ `inProgress` ➔ `inTesting` ➔ `inReview` ➔ `completed`.
* **Verification Lifecycle**: `none` ➔ `submitted` ➔ `pendingReview` ➔ `verified`.

# Development Notes

* **Conventions**: Temporary files and scratch code must go into the `.ai_scratch/` directory.
* **AI Workflow Details**: Agents are strictly bound to read `.ai_bridge/primary_directives.md` and context files before running, and must write `latest_notes.json` and `latest_verification.json` and release the queue with `agent_status.txt = IDLE`.