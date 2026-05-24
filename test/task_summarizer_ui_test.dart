import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:music_app/services/local_ai_service.dart';
import 'package:music_app/services/ai_bridge_service.dart';
import 'package:music_app/state/global_task_editor_state.dart';
import 'package:music_app/screens/visual_editor/panels/global_task_editor_window.dart';

// Mock HttpOverrides implementation to intercept and stub the API endpoints
class MockHttpOverrides extends HttpOverrides {
  final String mockContent;
  MockHttpOverrides(this.mockContent);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient(mockContent);
  }
}

class MockHttpClient implements HttpClient {
  final String mockContent;
  MockHttpClient(this.mockContent);

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return MockHttpClientRequest(url, mockContent);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return MockHttpClientRequest(url, mockContent);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName.toString();
    if (memberName.contains('getUrl') || memberName.contains('postUrl') || memberName.contains('openUrl')) {
      Uri uri;
      if (memberName.contains('openUrl')) {
        uri = invocation.positionalArguments[1] as Uri;
      } else {
        uri = invocation.positionalArguments.first as Uri;
      }
      return Future.value(MockHttpClientRequest(uri, mockContent));
    }
    return super.noSuchMethod(invocation);
  }
}

class MockHttpClientRequest implements HttpClientRequest {
  final Uri uri;
  final String mockContent;
  MockHttpClientRequest(this.uri, this.mockContent);

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = 0;

  @override
  int maxRedirects = 5;

  @override
  bool bufferOutput = true;

  @override
  void add(List<int> data) {}

  @override
  void write(Object? obj) {}

  @override
  void writeAll(Iterable objects, [String separator = ""]) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? obj = ""]) {}

  @override
  Future<HttpClientResponse> get done => Future.value(MockHttpClientResponse(200, ''));

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) async {
    await stream.drain();
  }

  @override
  Future<HttpClientResponse> close() async {
    // Delay the mock response by 100ms so we can capture the processing/loading state
    await Future.delayed(const Duration(milliseconds: 100));
    if (uri.path == '/api/chat') {
      final responseBody = jsonEncode({
        'message': {
          'content': mockContent,
        }
      });
      return MockHttpClientResponse(200, responseBody);
    }
    // Always return 200 OK for healthchecks
    return MockHttpClientResponse(200, 'OK');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpClientResponse implements HttpClientResponse {
  @override
  final int statusCode;
  final String body;
  MockHttpClientResponse(this.statusCode, this.body);

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  int get contentLength => body.length;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => false;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final bytes = utf8.encode(body);
    return Stream<List<int>>.fromIterable([bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String name, List<String> values) f) {}
  @override
  List<String>? operator [](String name) => null;
  @override
  String? value(String name) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockResponseText = 'Mocked task summary report:\n- **Objectives**: Done\n- **Completed**: Done\n- **Pending/Next Actions**: None\n- **Blockers (if any)**: None';

  group('Task Summarizer UI and Native AI Integration Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dotenv.testLoad(fileInput: 'OPENAI_API_KEY=mock_key_for_testing');
      HttpOverrides.global = MockHttpOverrides(mockResponseText);
    });

    tearDown(() {
      HttpOverrides.global = null;
    });

    testWidgets('GlobalTaskEditorWindow task summarization flow works end-to-end', (WidgetTester tester) async {
      // Set larger screen size to avoid flex overflows in widget test
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Set up target task model
      final mockTask = AiTask(
        id: 'test_task_123',
        name: 'Test Task',
        description: 'Implement a new audio parser module.',
        notes: 'Notes:\n- Added parsing logic.\n- Fixed a regression in lrc formatting.\n- Verified layout rendering.',
        summary: '',
      );

      // Populate GlobalTaskEditorState with task request and AiBridgeService with tasks
      AiBridgeService.instance.tasks.clear();
      AiBridgeService.instance.tasks.add(mockTask);
      GlobalTaskEditorState.instance.requestEdit(existingTask: mockTask);

      // 2. Pump the widget
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: NoSplash.splashFactory,
          ),
          home: Scaffold(
            body: GlobalTaskEditorWindow(
              key: const ValueKey('task_editor'),
              isDocked: true,
              onClose: () {},
            ),
          ),
        ),
      );

      // Let the SharedPreferences _loadPreferences finish
      await tester.pumpAndSettle();

      // Verify that description field is populated with our mockup text
      expect(find.text('Implement a new audio parser module.'), findsOneWidget);

      // Find the Generate Summary with AI button by tooltip
      final summaryBtnFinder = find.byTooltip('Generate Summary with AI');
      expect(summaryBtnFinder, findsOneWidget);

      // 3. Tap the Generate Summary button
      await tester.tap(summaryBtnFinder);
      
      // Pump to trigger processing state (first frame where button is disabled and loading indicator is shown)
      await tester.pump();
      
      // Verify processing state shows loading indicators on both AI action buttons
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      expect(find.byTooltip('Generating...'), findsOneWidget);
      expect(find.byTooltip('Reviewing...'), findsOneWidget);

      // Pump until the summary field is updated or timeout is reached
      int retries = 0;
      while (find.text(mockResponseText).evaluate().isEmpty && retries < 100) {
        await tester.pump(const Duration(milliseconds: 50));
        retries++;
      }

      // Verify summary is updated with mocked response text
      expect(find.text(mockResponseText), findsOneWidget, 
          reason: 'Summary text did not match mock response. lastError: ${LocalAiService.instance.lastError}');

      // Verify progress indicators are gone and buttons are restored
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byTooltip('Generate Summary with AI'), findsOneWidget);
      expect(find.byTooltip('Review Prompt with AI'), findsOneWidget);
    });

    testWidgets('GlobalTaskEditorWindow name field is single line and blocks newlines', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockTask = AiTask(
        id: 'test_task_456',
        name: 'Single Line Task Name',
        description: 'Testing the name field constraints.',
      );

      AiBridgeService.instance.tasks.clear();
      AiBridgeService.instance.tasks.add(mockTask);
      GlobalTaskEditorState.instance.requestEdit(existingTask: mockTask);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: GlobalTaskEditorWindow(
              key: const ValueKey('task_editor_name_test'),
              isDocked: true,
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the TextField by its initial/hint text or containing value
      final nameTextFieldFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          widget.controller != null &&
          widget.controller!.text == 'Single Line Task Name');

      expect(nameTextFieldFinder, findsOneWidget);

      final TextField nameTextField = tester.widget<TextField>(nameTextFieldFinder);
      expect(nameTextField.maxLines, equals(1));
      expect(nameTextField.minLines, equals(1));
      expect(nameTextField.keyboardType, equals(TextInputType.text));
      expect(nameTextField.textInputAction, equals(TextInputAction.done));
      
      // Verify singleLineFormatter is present in inputFormatters
      expect(nameTextField.inputFormatters, isNotNull);
      expect(nameTextField.inputFormatters!.contains(FilteringTextInputFormatter.singleLineFormatter), isTrue);
    });
  });
}
