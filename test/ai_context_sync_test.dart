import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:music_app/db/app_database.dart';
import 'package:music_app/db/daos/assets_dao.dart';
import 'package:music_app/services/storage_url_resolver.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:music_app/services/antigravity_status_service.dart';

class FakeSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBridgeDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempBridgeDir = Directory.systemTemp.createTempSync('ai_bridge_test_dir');
    AiBridgeService.instance.testDirPath = tempBridgeDir.path;
    AiBridgeService.instance.testFilePath = '${tempBridgeDir.path}/tasks.json';
    AntigravityStatusService.instance.statusFilePath = '${tempBridgeDir.path}/agent_status.txt';
    AntigravityStatusService.instance.resetState();
  });

  tearDown(() {
    AiBridgeService.instance.testDirPath = '.ai_bridge';
    AiBridgeService.instance.testFilePath = '.ai_bridge/tasks.json';
    AntigravityStatusService.instance.statusFilePath = '.ai_bridge/agent_status.txt';
    AntigravityStatusService.instance.resetState();
    if (tempBridgeDir.existsSync()) {
      tempBridgeDir.deleteSync(recursive: true);
    }
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

  test('StorageUrlResolver resolves flat category paths and logical paths', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final assetsDao = AssetsDao(db);
    final resolver = StorageUrlResolver(FakeSupabaseClient(), assetsDao);

    // Set local repository path in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('project_local_repository_path', tempBridgeDir.path);

    // Create a physical mock audio file in <tempBridgeDir>/audio/TheBionicMan.mp3
    final audioDir = Directory('${tempBridgeDir.path}/audio');
    await audioDir.create(recursive: true);
    final audioFile = File('${audioDir.path}/TheBionicMan.mp3');
    await audioFile.writeAsString('mock audio bytes');

    // Create a logical parent folder tree in the database:
    // Collections -> Music -> Deviation Noted -> The Bionic Man
    final collectionsId = await assetsDao.insertAsset(const AssetsCompanion(
      tenantId: drift.Value(1),
      name: drift.Value('Collections'),
      type: drift.Value('FOLDER'),
    ));
    final musicId = await assetsDao.insertAsset(AssetsCompanion(
      tenantId: const drift.Value(1),
      parentId: drift.Value(collectionsId),
      name: const drift.Value('Music'),
      type: const drift.Value('FOLDER'),
    ));
    final deviationId = await assetsDao.insertAsset(AssetsCompanion(
      tenantId: const drift.Value(1),
      parentId: drift.Value(musicId),
      name: const drift.Value('Deviation Noted'),
      type: const drift.Value('FOLDER'),
    ));
    final bionicFolderId = await assetsDao.insertAsset(AssetsCompanion(
      tenantId: const drift.Value(1),
      parentId: drift.Value(deviationId),
      name: const drift.Value('The Bionic Man'),
      type: const drift.Value('FOLDER'),
    ));

    // Insert the asset file under the logical folder
    await assetsDao.insertAsset(AssetsCompanion(
      tenantId: const drift.Value(1),
      parentId: drift.Value(bionicFolderId),
      name: const drift.Value('TheBionicMan.mp3'),
      storagePath: const drift.Value('1/1774497778581.mp3'),
      type: const drift.Value('FILE'),
    ));

    // 1. Verify resolving via storage path maps to the flat physical category folder:
    final resolvedFlat = await resolver.resolvePlayableUrl('1/1774497778581.mp3');
    expect(resolvedFlat, isNotNull);
    expect(resolvedFlat, endsWith('audio${Platform.pathSeparator}TheBionicMan.mp3'));

    // 2. Verify resolving a stale/non-existing local path fallbacks to database lookup:
    final staleLocalPath = '${tempBridgeDir.path}/Collections/Music/Deviation Noted/The Bionic Man/TheBionicMan.mp3';
    final resolvedFallback = await resolver.resolvePlayableUrl(staleLocalPath);
    expect(resolvedFallback, isNotNull);
    expect(resolvedFallback, endsWith('audio${Platform.pathSeparator}TheBionicMan.mp3'));

    await db.close();
  });
}
