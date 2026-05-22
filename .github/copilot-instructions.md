# GitHub Copilot Instructions - AI Bridge Integration & Context Sync Protocol

You are an AI Coding Assistant operating in a workspace that is synchronized in real-time with a visual editor GUI application. 
To ensure you have full alignment and do not "start from scratch" or lack project context, you MUST follow this startup and execution protocol.

## 1. Startup Context Synchronization (CRITICAL)
Before you do anything else in a new conversation, or when responding to a prompt, you MUST read the following state files inside the `.ai_bridge/` directory using your file-reading tools:

1. **Active Task Context**: Read `.ai_bridge/current_task.json` to understand the task you are currently assigned to, including its name, description, priority, and checklist/verification items.
2. **Master Directives**: Read `.ai_bridge/primary_directives.md` to understand safety constraints, execution modes, and hooks.
3. **Database Schema & Data**: Read `.ai_bridge/db_dump.json` to inspect the taxonomy, strings/tags, and library assets from the local database.
4. **Recent Conversation Logs**: Read `.ai_bridge/conversation_history.md` to understand what has been discussed previously between the user and visual editor subagents.
5. **Global Workspace Tasks**: Read `.ai_bridge/tasks.json` to view the worksheets and task hierarchies.

## 2. CLI Context Sync Protocol (How to Communicate Back to the GUI)
When you make progress or complete a task, you MUST update the GUI state files so the visual editor knows you have finished:

1. **Log Notes & Summaries**: Write task summaries and notes to `.ai_bridge/latest_notes.json` formatted as:
   ```json
   {
     "notes": "detailed markdown updates of what you did",
     "summary": "short commit summary style title"
   }
   ```
2. **Verification Proof**: Write proof/evidence for the verification criteria to `.ai_bridge/latest_verification.json` formatted as:
   ```json
   [
     {
       "description": "the criteria description exactly matching the one from current_task.json",
       "isVerified": false,
       "proof": "evidence/action details of how it was verified"
     }
   ]
   ```
   *Note: `isVerified` must always be `false` (the user reviews and verifies in the UI).*
3. **Release Queue**: When finished, write `IDLE` (or `PREVIEW` if awaiting user review of planned changes) to `.ai_bridge/agent_status.txt` to release the visual editor's queue execution lock.

## 3. General Project Guidelines
- Keep temporary/scratch files inside the `.ai_scratch/` directory. Never drop temporary files in the root folder.
- Maintain comment integrity. Preserve all existing comments and docstrings.
