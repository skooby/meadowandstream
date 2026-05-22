import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:music_app/db/app_database.dart';
import 'package:music_app/db/daos/i18n_dao.dart';
import 'package:music_app/db/daos/assets_dao.dart';
import 'package:music_app/db/daos/asset_tags_dao.dart';
import 'package:music_app/utils/ai_command_parser.dart';
import 'package:music_app/scripts/tenant_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return FailHttpClient();
  }
}

class FailHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> postUrl(Uri url) => Future.error(const SocketException("Offline"));
  @override
  Future<HttpClientRequest> getUrl(Uri url) => Future.error(const SocketException("Offline"));
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => Future.error(const SocketException("Offline"));
  
  @override
  void close({bool force = false}) {}
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return Future.error(const SocketException("Offline"));
  }
}

void main() {
  HttpOverrides.global = FailHttpOverrides();
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AiCommandParser executeBatch tag/folder creation test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'stored_tenant_id': 1,
    });
    
    // Initialize Supabase with test credentials
    try {
      await Supabase.initialize(
        url: 'https://lswberciytrkxjftryei.supabase.co',
        anonKey: 'sb_publishable__oj8jDk8aa8fs9q7UGFkLg_1px6aaVN',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
        ),
      );
    } catch (_) {
      // Already initialized
    }
    
    final db = AppDatabase(NativeDatabase.memory());
    final i18nDao = I18nDao(db);
    final assetsDao = AssetsDao(db);
    final assetTagsDao = AssetTagsDao(db);
    
    await TenantService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          Provider<I18nDao>.value(value: i18nDao),
          Provider<AssetsDao>.value(value: assetsDao),
          Provider<AssetTagsDao>.value(value: assetTagsDao),
        ],
        child: Builder(
          builder: (context) {
            return Container();
          },
        ),
      ),
    );

    final context = tester.element(find.byType(Container));
    
    await tester.runAsync(() async {
      // 1. Create a folder with table tags
      final logs1 = await AiCommandParser.executeBatch('folder create "Mood" --table tags', context);
      expect(logs1.any((l) => l.contains('[OK] Folder "Mood"')), isTrue);
      
      // 2. Create a tag under the folder
      final logs2 = await AiCommandParser.executeBatch('tag create "Inspirational" --folder "Mood" --color "#FFAA55"', context);
      expect(logs2.any((l) => l.contains('[OK] Tag "Inspirational"')), isTrue);
      
      // 3. Verify tag exists in local database
      final tag = await (i18nDao.select(i18nDao.strings)
        ..where((s) => s.key.equals('tag.mood.inspirational'))).getSingleOrNull();
        
      expect(tag, isNotNull);
      final nonNullTag = tag!;
      expect(nonNullTag.color, equals('#FFAA55'));
      expect(nonNullTag.type, equals('STRING'));
      
      // 4. Verify translation exists
      final trans = await i18nDao.getTranslation('tag.mood.inspirational', 'en');
      expect(trans, equals('Inspirational'));
    });
    
    await db.close();
  });

  test('I18nDao getOrCreateLangId does not enter infinite recursion', () async {
    SharedPreferences.setMockInitialValues({
      'stored_tenant_id': 1,
    });
    
    final db = AppDatabase(NativeDatabase.memory());
    final i18nDao = I18nDao(db);
    
    // Clear languages table to ensure it is empty
    await db.delete(db.languages).go();
    
    // Call getOrCreateLangId which previously caused infinite recursion
    final langId = await i18nDao.getOrCreateLangId('es');
    expect(langId, isNotNull);
    
    // Verify it exists in DB
    final lang = await (i18nDao.select(i18nDao.languages)..where((l) => l.code.equals('es'))).getSingleOrNull();
    expect(lang, isNotNull);
    final nonNullLang = lang!;
    expect(nonNullLang.code, equals('es'));
    
    await db.close();
  });
}
