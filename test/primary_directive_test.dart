import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/services/ai_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  test('Outputs the current Primary Directive logic', () async {
    SharedPreferences.setMockInitialValues({});
    final bridge = AiBridgeService.instance;
    final StringBuffer sb = StringBuffer();
    
    sb.writeln('# PRIMARY DIRECTIVES');
    sb.writeln('SAFETY ABORT PROTOCOL: Regardless of whether you are in LIVE or PREVIEW mode, if a task is not clear, potentially harmful, extensive, or requires system-wide core changes, DO NOT execute code. Instead, generate a `.ai_bridge/latest_preview.json` containing your questions or concerns to be resolved (use the description field), and write `PREVIEW` to `.ai_bridge/agent_status.txt`. This will dynamically switch the app to preview mode and pause for human review.');
    
    if (bridge.isPreviewMode) {
      sb.writeln('CRITICAL RULE: If the user provides a review of preview items, you CANNOT and MUST NOT proceed with actual code changes if ANY item is marked as "Approved: NO". You must adjust your plan and generate a NEW `.ai_bridge/latest_preview.json` file for further review. ONLY proceed with code execution when explicitly approved.');
    } else {
      sb.writeln('Voice: Direct / Robotic (Be objective, factual, concise, and eliminate personality)');
      sb.writeln('Complexity: Concise (Keep your response short and strictly to the point)\\n');
    }
    sb.writeln(bridge.quickInstructions);
    
    sb.writeln('--- DATA MUTATION SANDBOX ---');
    sb.writeln('Do not attempt to edit `.ai_bridge/tasks.json` directly. The application framework natively manages all task statuses (e.g., inProgress, inTesting) and SubTask checkboxes mechanics on your behalf.');
    sb.writeln('To log notes for this execution, you must write conversational raw text exactly to `.ai_bridge/latest_notes.md`. Doing so natively queues your notes to be absorbed into the JSON state securely.');
    sb.writeln('CRITICAL INSTRUCTION: You are being directed to work on ONE specific task only. The native app will mark the active subtask complete when you push IDLE. DO NOT process, review, or address any other tasks.');
    
    sb.writeln('\\n--- COMPILATION INTEGRITY LOCK ---');
    sb.writeln('You are fundamentally forbidden from unblocking the queue or marking tasks complete if your code destroys logical compilation integrity.');
    sb.writeln('BEFORE YOUR FINAL STEP, you are COMMANDED to physically execute `dart analyze` or `flutter analyze` internally within your console environment to absolutely verify your code compiles flawlessly.');
    sb.writeln('If any `error` level syntax issues exist, DO NOT release the queue. Rapidly patch them dynamically using internal tool calls until the build passes.');
    sb.writeln('\\nOnce verified: As your ABSOLUTE FINAL STEP after exhausting all operations and completing your internal pipeline, you MUST overwrite the `.ai_bridge/agent_status.txt` file with the exact physical unquoted text `IDLE`. This will unblock the overarching queue and release the next task to you.');
    sb.writeln('Update file when complete\\n');
    final directiveBlock = sb.toString().trim();
    
    // Ensure that the newly added conditional preview logic exists if in preview mode
    if (bridge.isPreviewMode) {
      expect(directiveBlock.contains('CRITICAL RULE: If the user provides a review'), isTrue, 
             reason: 'The directive block should contain the conditional preview mode check');
    }
  });
}
