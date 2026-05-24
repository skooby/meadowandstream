# GitHub Copilot Instructions - AI Bridge Integration & Context Sync Protocol

You are an AI Coding Assistant operating in a workspace that is synchronized in real-time with a visual editor GUI application. 
To ensure you have full alignment and do not "start from scratch" or lack project context, you MUST follow this startup and execution protocol.

## 1. Startup Context Synchronization (CRITICAL)
Before you do anything else in a new conversation, or when responding to a prompt, you MUST perform these tasks:
- [ ] CRITICAL: Read `.ai_bridge/primary_directives.md` natively using your tool to understand the GLOBAL CONSTRAINTS and NATIVE SYSTEM HOOKS before proceeding. Failure to do so will break the application.
- [ ] Read the recent conversation history in `.ai_bridge/conversation_history.md` using your file-reading tools to align context with the current workspace state.
- [ ] Read the database dump in `.ai_bridge/db_dump.json` using your file-reading tools.
- [ ] Read the active task context in `.ai_bridge/current_task.json`.
- [ ] Read the global workspace tasks in `.ai_bridge/tasks.json`.

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
