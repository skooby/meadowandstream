import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/db/app_database.dart';
import 'package:music_app/services/ai_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AiBridgeService database initialization and sync bypasses in unit tests', () async {
    final service = AiBridgeService.instance;
    final db = AppDatabase(NativeDatabase.memory());

    // Initialize with a mock database
    service.initialize(db);

    // Verify it doesn't throw and safely bypasses writing to disk in tests
    await expectLater(service.syncDatabaseDump(), completes);
    await expectLater(service.syncConversationHistory(), completes);

    await db.close();
  });
}
