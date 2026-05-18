import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../visual_editor_screen.dart';
import '../../../services/ai_bridge_service.dart';
import '../../../constants.dart';

final ValueNotifier<bool> showProjectModulesNotifier = ValueNotifier(false);

void showProjectModulesWindow() {
  showProjectModulesNotifier.value = true;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showProjectModules'), true));
}

void hideProjectModulesWindow() {
  showProjectModulesNotifier.value = false;
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool(VisualEditorScreen.getPrefKey('showProjectModules'), false));
}

class ModuleItem {
  String id;
  String title;
  bool isIncluded;
  bool isRequired;
  String note;

  String description;
  int? color;
  int? iconCodePoint;
  List<String> hyperlinks;

  ModuleItem({
    required this.id,
    required this.title,
    this.isIncluded = false,
    this.isRequired = false,
    this.note = '',
    this.description = '',
    this.color,
    this.iconCodePoint,
    this.hyperlinks = const [],
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'id': id,
      'title': title,
      'isIncluded': isIncluded,
      'isRequired': isRequired,
      'note': note,
      'description': description,
      'hyperlinks': hyperlinks,
    };
    if (color != null) map['color'] = color;
    if (iconCodePoint != null) map['iconCodePoint'] = iconCodePoint;
    return map;
  }

  factory ModuleItem.fromJson(Map<String, dynamic> json) => ModuleItem(
    id: json['id'],
    title: json['title'],
    isIncluded: json['isIncluded'] ?? false,
    isRequired: json['isRequired'] ?? false,
    note: json['note'] ?? '',
    description: json['description'] ?? '',
    color: json['color'],
    iconCodePoint: json['iconCodePoint'],
    hyperlinks: json['hyperlinks'] != null ? List<String>.from(json['hyperlinks']) : [],
  );
}

class ModuleGroup {
  String id;
  String title;
  String note;
  String description;
  int? color;
  int? iconCodePoint;
  List<String> hyperlinks;
  List<ModuleItem> items;

  ModuleGroup({
    required this.id,
    required this.title,
    this.note = '',
    this.description = '',
    this.color,
    this.iconCodePoint,
    this.hyperlinks = const [],
    List<ModuleItem>? items,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'id': id,
      'title': title,
      'note': note,
      'description': description,
      'hyperlinks': hyperlinks,
      'items': items.map((i) => i.toJson()).toList(),
    };
    if (color != null) map['color'] = color;
    if (iconCodePoint != null) map['iconCodePoint'] = iconCodePoint;
    return map;
  }

  factory ModuleGroup.fromJson(Map<String, dynamic> json) => ModuleGroup(
    id: json['id'],
    title: json['title'],
    note: json['note'] ?? '',
    description: json['description'] ?? '',
    color: json['color'],
    iconCodePoint: json['iconCodePoint'],
    hyperlinks: json['hyperlinks'] != null ? List<String>.from(json['hyperlinks']) : [],
    items: (json['items'] as List?)?.map((i) => ModuleItem.fromJson(i)).toList() ?? [],
  );
}

class ProjectModulesWindow extends StatefulWidget {
  final bool isDocked;
  final VoidCallback onClose;
  final VoidCallback? onFocus;

  const ProjectModulesWindow({
    super.key,
    required this.onClose,
    this.onFocus,
    this.isDocked = false,
  });

  @override
  State<ProjectModulesWindow> createState() => _ProjectModulesWindowState();
}
class _ProjectModulesWindowState extends State<ProjectModulesWindow> {

  double _width = 600;
  double _height = 500;
  Offset _offset = const Offset(100, 100);
  double _bgOpacity = 0.5;

  List<ModuleGroup> _groups = [];
  final Set<String> _collapsedGroups = {};

  static const Map<String, int> _presetColors = {
    'White': 0xFFFFFFFF,
    'Green': 0xB269F0AE,
    'Blue': 0xB2448AFF,
    'Amber': 0xB2FFD740,
    'Purple': 0xB2E040FB,
    'Red': 0xB2FF5252,
    'Yellow': 0xB2FFFF00,
    'Cyan': 0xB218FFFF,
  };

  static const Map<String, IconData> _presetIcons = {
    'Folder': Icons.folder,
    'Task': Icons.task,
    'Bug': Icons.bug_report,
    'Code': Icons.code,
    'Terminal': Icons.terminal,
    'Database': Icons.dataset,
    'API': Icons.api,
    'Web': Icons.web,
    'Phone': Icons.phone_iphone,
    'Shield': Icons.security,
  };
  final TextEditingController _newItemController = TextEditingController();
  final TextEditingController _newGroupController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadState();
    VisualEditorScreen.currentWorkspace.addListener(_loadState);
  }

  @override
  void dispose() {
    VisualEditorScreen.currentWorkspace.removeListener(_loadState);
    _newItemController.dispose();
    _newGroupController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _width = prefs.getDouble(VisualEditorScreen.getPrefKey('pm_width')) ?? 600;
        _height = prefs.getDouble(VisualEditorScreen.getPrefKey('pm_height')) ?? 500;
        _offset = Offset(
          prefs.getDouble(VisualEditorScreen.getPrefKey('pm_dx')) ?? 100,
          prefs.getDouble(VisualEditorScreen.getPrefKey('pm_dy')) ?? 100,
        );
        _bgOpacity = prefs.getDouble('ve_toolWindowOpacity') ?? 0.5;

        final savedGroups = prefs.getString(VisualEditorScreen.getPrefKey('pm_groups'));
        if (savedGroups != null) {
          try {
            final List decoded = jsonDecode(savedGroups);
            _groups = decoded.map((e) => ModuleGroup.fromJson(e)).toList();
            
            // Deduplicate IDs safely
            final seenIds = <String>{};
            for (var g in _groups) {
               if (seenIds.contains(g.id)) {
                 g.id = '\${g.id}_\${UniqueKey().toString()}';
               }
               seenIds.add(g.id);
               for (var i in g.items) {
                 if (seenIds.contains(i.id)) {
                   i.id = '\${i.id}_\${UniqueKey().toString()}';
                 }
                 seenIds.add(i.id);
               }
            }
          } catch (_) {}
        }
        if (_groups.isEmpty) {
          _loadDefaultSections();
        }
      });
    }
  }

  void _loadDefaultSections() {
    setState(() {
      _groups = [
        ModuleGroup(id: 'auth_identity', title: 'AUTHENTICATION & IDENTITY', color: 0xB269F0AE, iconCodePoint: Icons.security.codePoint, note: 'Manage user security, access rules, and token pipelines natively.', description: 'The overall purpose of this module is to securely govern who can access the system and what they are allowed to do. It integrates robust cryptography and session management to prevent unauthorized access while maintaining a frictionless user experience.\\n\\nIncorporation: This will be incorporated into the core application shell before routing logic takes over, acting as a global middleware gateway.', items: [
          ModuleItem(id: 'auth_1', title: 'User Registration (Email/Password)', color: 0xFFFFFFFF, iconCodePoint: Icons.task.codePoint, note: 'Secure encrypted credential onboarding for localized or remote databases.', description: 'Allows users to create native accounts using standard credentials gracefully. It will store hashed values using robust encryption routines and issue secure session tokens.', hyperlinks: ['https://supabase.com/docs/guides/auth']),
          ModuleItem(id: 'auth_2', title: 'OAuth / Social Login (Apple, Google)', color: 0xFFFFFFFF, iconCodePoint: Icons.api.codePoint, note: 'Third-party unified platform login gateways for rapid user onboarding.', description: 'Reduces user friction by utilizing trusted OAuth 2.0 providers like Apple or Google.', hyperlinks: ['https://firebase.google.com/docs/auth']),
          ModuleItem(id: 'auth_3', title: 'Session & Token Management', color: 0xFFFFFFFF, iconCodePoint: Icons.terminal.codePoint, note: 'Continuous security refresh pipelines validating remote tokens safely.', description: 'Automatic background polling validating network tokens and managing expiring JSON Web Tokens securely without kicking out active users.'),
          ModuleItem(id: 'auth_4', title: 'Role-Based Access Control (RBAC)', color: 0xFFFFFFFF, iconCodePoint: Icons.code.codePoint, note: 'Restrict specific application capabilities based on assigned active user roles.', description: 'Maintains tiered logic access rules (Admin, Premium, Free) mapping specific application views selectively based on backend privileges.'),
        ]),
        ModuleGroup(id: 'core_arch', title: 'CORE ARCHITECTURE & INFRASTRUCTURE', color: 0xB2448AFF, iconCodePoint: Icons.code.codePoint, note: 'Foundational framework logic for local databases, state, and routing layers.', description: 'Serves as the central communication highway across the entire mobile client. Handles internal data propagation, network requests, and structural application routing safely.', items: [
          ModuleItem(id: 'core_1', title: 'Local Offline Persistence', color: 0xFFFFFFFF, iconCodePoint: Icons.dataset.codePoint, note: 'Ensures the app operates seamlessly without remote connectivity utilizing local caches.', description: 'Stores user-critical application state into robust offline caches (SQLite/Drift).', hyperlinks: ['https://drift.simonbinder.eu/docs/']),
          ModuleItem(id: 'core_2', title: 'State Management Engine', color: 0xFFFFFFFF, iconCodePoint: Icons.task.codePoint, note: 'Centralized observable reactive stores maintaining UI coherence globally.', description: 'Utilizes dependency injection via provider or native inherently observable variables natively coordinating complex Widget trees.', hyperlinks: ['https://pub.dev/packages/provider']),
          ModuleItem(id: 'core_3', title: 'API Client & Service Gateway', color: 0xFFFFFFFF, iconCodePoint: Icons.api.codePoint, note: 'Centralized network handler intercepting outbound REST or graph traffic safely.', description: 'Global unified HTTP interceptor resolving all backend network API communications gracefully with native retry and offline queuing structures.'),
        ]),
        ModuleGroup(id: 'database', title: 'DATABASE ARCHITECTURE', color: 0xB2FFD740, iconCodePoint: Icons.dataset.codePoint, note: 'Underlying data schema modeling and remote/local synchronization configuration logic.', description: 'Maps out structured data objects and properties, governing how relational objects integrate across client UI models and backend tables.', items: [
          ModuleItem(id: 'db_1', title: 'Schema Migrations Logic', color: 0xFFFFFFFF, iconCodePoint: Icons.code.codePoint, note: 'Automatic incremental database structural updates rolling gracefully on client patches.', description: 'Generates robust delta upgrades mapping outdated client DB schemas to fresh representations securely upon local application updates.'),
          ModuleItem(id: 'db_2', title: 'Relational or Document Logic', color: 0xFFFFFFFF, iconCodePoint: Icons.dataset.codePoint, note: 'Define strict foreign constraints, joins, or remote NoSQL document indexing rules.', description: 'Determines the backend data modeling paradigm for relational SQL or hierarchical NOSQL mapping.', hyperlinks: ['https://supabase.com/docs/guides/database']),
          ModuleItem(id: 'db_3', title: 'Data Obfuscation & Security', color: 0xFFFFFFFF, iconCodePoint: Icons.security.codePoint, note: 'AES local encryption protocols explicitly mapped to user isolated sandbox schemas.', description: 'Masking localized storage blocks natively hiding application critical parameters away from arbitrary user system inspections.', hyperlinks: ['https://pub.dev/packages/flutter_secure_storage']),
        ]),
        ModuleGroup(id: 'web_dev', title: 'WEB DEVELOPMENT & PWA', color: 0xB218FFFF, iconCodePoint: Icons.web.codePoint, note: 'Web-specific algorithmic logic ensuring optimal browser and search engine integration.', description: 'Responsible for augmenting native mobile applications natively exported onto standard web standards allowing indexable fast-loading sites.', items: [
          ModuleItem(id: 'web_1', title: 'Search Engine Optimization (SEO)', color: 0xFFFFFFFF, iconCodePoint: Icons.web.codePoint, note: 'Header generation and meta-tag injecting routes indexing effectively globally.', description: 'Injects specific document configurations rendering metadata efficiently readable by web indexing spiders.'),
          ModuleItem(id: 'web_2', title: 'Progressive Web App Logic (PWA)', color: 0xFFFFFFFF, iconCodePoint: Icons.task.codePoint, note: 'Service workers enabling installable native-like cache web interactions locally.', description: 'Generates local manifest files tracking background service worker loops creating an offline installable browser experience.', hyperlinks: ['https://web.dev/explore/progressive-web-apps']),
          ModuleItem(id: 'web_3', title: 'Server-Side Rendering (SSR)', color: 0xFFFFFFFF, iconCodePoint: Icons.api.codePoint, note: 'Delivering pre-assembled HTML node caches minimizing initial load delays rapidly.', description: 'Compiles primary user payloads remotely bypassing large Javascript load requirements for initial client browser parses.'),
        ]),
        ModuleGroup(id: 'marketing_ads', title: 'MARKETING & ADVERTISEMENTS', color: 0xB2FF5252, iconCodePoint: Icons.folder.codePoint, note: 'Funnel engagements, programmatic ad placements, and organic conversion paths actively.', description: 'Generates organic revenue natively deploying user growth trackers targeting specific application usage demographics.', items: [
          ModuleItem(id: 'mkt_1', title: 'Programmatic Advertising (AdMob)', color: 0xFFFFFFFF, iconCodePoint: Icons.task.codePoint, note: 'Banner, interstitial, and dynamic rewarded ad inventory rendering logic hooks.', description: 'Integrates natively built Google advertising pipelines streaming media banners based on active geographical markers contextually.', hyperlinks: ['https://developers.google.com/admob/flutter/quick-start']),
          ModuleItem(id: 'mkt_2', title: 'Onboarding Drip Campaigns', color: 0xFFFFFFFF, iconCodePoint: Icons.terminal.codePoint, note: 'Sequenced notification pipelines designed to progressively educate and retain users.', description: 'Automatically maps time-based email sequences retaining organic customer engagement paths upon initial registrations.'),
          ModuleItem(id: 'mkt_3', title: 'A/B Engagement Testing', color: 0xFFFFFFFF, iconCodePoint: Icons.code.codePoint, note: 'Splitting user exposure automatically to validate UX/UI workflow variants statistically.', description: 'Remotely swaps out logic components gathering interaction statistics natively tracking conversion boundaries explicitly.'),
        ]),
        ModuleGroup(id: 'sandbox_testing', title: 'SANDBOX & TESTING ENVIRONMENTS', color: 0xB2FFFF00, iconCodePoint: Icons.bug_report.codePoint, note: 'Quality assurance isolated staging workflow paths guaranteeing zero user corruption.', description: 'Isolating native functionality from live production targets allowing developers specific routes actively asserting programmatic rules safely.', items: [
          ModuleItem(id: 'qa_1', title: 'Automated Unit Tests', color: 0xFFFFFFFF, iconCodePoint: Icons.code.codePoint, note: 'Local logic assertions explicitly confirming fundamental business architectural rules.', description: 'Testing granular classes isolating explicit programmatic functions verifying standard inputs and mathematical behaviors mathematically.', hyperlinks: ['https://docs.flutter.dev/testing/overview']),
          ModuleItem(id: 'qa_2', title: 'End-to-End Integration Tests', color: 0xFFFFFFFF, iconCodePoint: Icons.terminal.codePoint, note: 'Remote driver evaluation simulating the physical UI user journey autonomous clicking.', description: 'Spawns local native application sandboxes allowing macro drivers native simulated accessibility interaction workflows recursively.', hyperlinks: ['https://docs.flutter.dev/cookbook/testing/integration/introduction']),
          ModuleItem(id: 'qa_3', title: 'Remote Staging Environment', color: 0xFFFFFFFF, iconCodePoint: Icons.dataset.codePoint, note: 'Separated secondary network domain mimicking production perfectly prior to rollouts.', description: 'Points local configuration instances explicitly onto a mirror remote network mapping staging data safely safely analyzing data bugs.'),
        ]),
        ModuleGroup(id: 'hardware_device', title: 'HARDWARE & DEVICE INTEGRATIONS', color: 0xB2448AFF, iconCodePoint: Icons.phone_iphone.codePoint, note: 'Bridging software layers to physical underlying native-layer protocols natively.', description: 'Invoking internal physical device drivers triggering localized features directly via hardware channels successfully bypassing basic software sandboxes.', items: [
          ModuleItem(id: 'hw_1', title: 'Push Notifications Pipeline', color: 0xFFFFFFFF, iconCodePoint: Icons.task.codePoint, note: 'Triggering APNS/FCM tokens dynamically maintaining passive user engagements safely.', description: 'Listens passively upon local background networks accepting standardized OS payloads tracking notification tray executions accurately.', hyperlinks: ['https://firebase.google.com/docs/cloud-messaging/flutter/client']),
          ModuleItem(id: 'hw_2', title: 'Biometrics & Encrypted Enclaves', color: 0xFFFFFFFF, iconCodePoint: Icons.security.codePoint, note: 'Unlocking restricted scopes using local Apple FaceID or Android fingerprint APIs.', description: 'Interacts gracefully directly against internal cryptography processors asserting biological matches mapped locally internally.', hyperlinks: ['https://pub.dev/packages/local_auth']),
        ]),
        ModuleGroup(id: 'media_files', title: 'MEDIA & FILE SYSTEMS', color: 0xB2E040FB, iconCodePoint: Icons.folder.codePoint, note: 'Storage logic ensuring compressed offline data blocks perform correctly locally.', description: 'Manages physical byte reading explicitly resolving media parsing workflows rendering natively fast graphical assets properly.', items: [
          ModuleItem(id: 'media_1', title: 'Image Processing & Caching', color: 0xFFFFFFFF, iconCodePoint: Icons.task.codePoint, note: 'Dynamic thumbnail downsampling saving network loads substantially globally.', description: 'Actively intercepts application raw image bytes downscaling large asset requirements structurally storing low-res copies gracefully.', hyperlinks: ['https://pub.dev/packages/cached_network_image']),
          ModuleItem(id: 'media_2', title: 'Background Audio Playback', color: 0xFFFFFFFF, iconCodePoint: Icons.terminal.codePoint, note: 'Persistent threaded loops rendering audio streams while minimized securely.', description: 'Triggers explicit OS background threads locking audio decoders rendering physical byte waveforms without graphical process overhead.', hyperlinks: ['https://pub.dev/packages/just_audio']),
        ]),
        ModuleGroup(id: 'design_ui', title: 'DESIGN & PRESENTATION UI', color: 0xB269F0AE, iconCodePoint: Icons.web.codePoint, note: 'Custom painting components ensuring standard visual coherence flawlessly globally.', description: 'Global visual hierarchy defining application branding logically ensuring crisp accessibility metrics rendered efficiently utilizing GPU optimizations natively.', items: [
          ModuleItem(id: 'ui_1', title: 'Dynamic Dark/Light Theming', color: 0xFFFFFFFF, iconCodePoint: Icons.code.codePoint, note: 'Contextual tokenized color shifts listening to native device brightness explicitly.', description: 'Swaps out native palette dictionaries responding automatically when users switch their global iOS or Android system brightness configurations.', hyperlinks: ['https://api.flutter.dev/flutter/material/ThemeData-class.html']),
          ModuleItem(id: 'ui_2', title: 'Responsive Global Layouts', color: 0xFFFFFFFF, iconCodePoint: Icons.web.codePoint, note: 'Matrix resizing logic scaling perfectly across mobile and desktop boundaries.', description: 'Intercepts root device boundaries scaling relative flex elements perfectly mathematically managing orientation thresholds efficiently.', hyperlinks: ['https://docs.flutter.dev/ui/layout/responsive']),
        ]),
      ];
    });
    _saveState();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VisualEditorScreen.getPrefKey('pm_width'), _width);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('pm_height'), _height);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('pm_dx'), _offset.dx);
    await prefs.setDouble(VisualEditorScreen.getPrefKey('pm_dy'), _offset.dy);
    await prefs.setString(VisualEditorScreen.getPrefKey('pm_groups'), jsonEncode(_groups.map((g) => g.toJson()).toList()));
  }

  void _sendToAiBridge(dynamic item) {
    AiBridgeService.instance.addTask(
      item.title,
      item.description,
      notes: item.note,
      isFolder: item is ModuleGroup,
      highlightColor: item.color,
      iconBackgroundColor: item.color,
      iconCodePoint: item.iconCodePoint,
      hyperlinks: List.from(item.hyperlinks),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${item.title}" to AI Tasks'), duration: const Duration(seconds: 2), backgroundColor: Colors.amberAccent),
    );
  }

  Future<void> _showEditEntryDialog(dynamic item) async {
    final titleCtrl = TextEditingController(text: item.title);
    final descCtrl = TextEditingController(text: item.description);
    final notesCtrl = TextEditingController(text: item.note);
    int? selectedColor = item.color;
    int? selectedIcon = item.iconCodePoint;
    List<String> links = List.from(item.hyperlinks);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, ss) {
          return AlertDialog(
            backgroundColor: AppColors.windowBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius), side: BorderSide(color: AppColors.overlaySubtle)),
            title: Row(
               children: [
                   Icon(Icons.edit, size: 18, color: AppColors.accent),
                   const SizedBox(width: 8),
                   Text('Edit ${item is ModuleGroup ? 'Group' : 'Item'}', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize)),
               ]
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: titleCtrl, style: TextStyle(color: AppColors.panelTextPrimary), decoration: InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: AppColors.panelTextSecondary))),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descCtrl, 
                      style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize), 
                      minLines: 4, 
                      maxLines: 12, 
                      decoration: InputDecoration(
                        labelText: 'Description', 
                        labelStyle: TextStyle(color: AppColors.panelTextSecondary),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius), borderSide: BorderSide(color: AppColors.borderSubtle)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius), borderSide: BorderSide(color: AppColors.overlaySubtle)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius), borderSide: BorderSide(color: AppColors.accent)),
                        contentPadding: const EdgeInsets.all(12),
                      )
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesCtrl, 
                      style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize), 
                      minLines: 3, 
                      maxLines: 8, 
                      decoration: InputDecoration(
                        labelText: 'Notes', 
                        labelStyle: TextStyle(color: AppColors.panelTextSecondary),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius), borderSide: BorderSide(color: AppColors.borderSubtle)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius), borderSide: BorderSide(color: AppColors.overlaySubtle)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius), borderSide: const BorderSide(color: Colors.amberAccent)),
                        contentPadding: const EdgeInsets.all(12),
                      )
                    ),
                    const SizedBox(height: 12),
                    Row(
                       children: [
                          Expanded(
                             child: DropdownButtonFormField<int>(
                               decoration: InputDecoration(labelText: 'Color', labelStyle: TextStyle(color: AppColors.panelTextSecondary)),
                               dropdownColor: const Color(0xFF2C2C2C),
                               initialValue: selectedColor,
                               items: [
                                  DropdownMenuItem<int>(value: null, child: Text('Default', style: TextStyle(color: AppColors.panelTextPrimary))),
                                  ..._presetColors.entries.map((e) => DropdownMenuItem(value: e.value, child: Row(children: [Container(width: 12, height: 12, color: Color(e.value)), SizedBox(width: 8), Text(e.key, style: TextStyle(color: AppColors.panelTextPrimary))]))),
                               ],
                               onChanged: (v) => ss(() => selectedColor = v),
                             )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                             child: DropdownButtonFormField<int>(
                               decoration: InputDecoration(labelText: 'Icon', labelStyle: TextStyle(color: AppColors.panelTextSecondary)),
                               dropdownColor: const Color(0xFF2C2C2C),
                               initialValue: selectedIcon,
                               items: [
                                  DropdownMenuItem<int>(value: null, child: Text('Default', style: TextStyle(color: AppColors.panelTextPrimary))),
                                  ..._presetIcons.entries.map((e) => DropdownMenuItem(value: e.value.codePoint, child: Row(children: [Icon(e.value, size: 16, color: AppColors.panelTextPrimary), SizedBox(width: 8), Text(e.key, style: TextStyle(color: AppColors.panelTextPrimary))]))),
                               ],
                               onChanged: (v) => ss(() => selectedIcon = v),
                             )
                          ),
                       ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                          Text('Hyperlinks', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)),
                          IconButton(
                             icon: const Icon(Icons.add, size: 16, color: Colors.lightBlue),
                             onPressed: () => ss(() => links.add('')),
                             padding: EdgeInsets.zero,
                             constraints: const BoxConstraints(),
                          )
                       ],
                    ),
                    const SizedBox(height: 8),
                    ...links.asMap().entries.map((e) {
                       int idx = e.key;
                       return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                             children: [
                                Icon(Icons.link, size: 14, color: AppColors.borderSubtle),
                                const SizedBox(width: 8),
                                Expanded(
                                   child: TextFormField(
                                      initialValue: e.value,
                                      style: TextStyle(color: Colors.lightBlue, fontSize: AppUIConfig.rootFontSize, decoration: TextDecoration.underline),
                                      decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none),
                                      onChanged: (v) => links[idx] = v,
                                   )
                                ),
                                IconButton(
                                   icon: Icon(Icons.close, size: 14, color: AppColors.borderSubtle),
                                   onPressed: () => ss(() => links.removeAt(idx)),
                                   padding: EdgeInsets.zero,
                                   constraints: const BoxConstraints(),
                                )
                             ]
                          )
                       );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent.withOpacity(0.2)),
                onPressed: () {
                  setState(() {
                    item.title = titleCtrl.text;
                    item.description = descCtrl.text;
                    item.note = notesCtrl.text;
                    item.color = selectedColor;
                    item.iconCodePoint = selectedIcon;
                    item.hyperlinks = links.where((l) => l.trim().isNotEmpty).toList();
                  });
                  _saveState();
                  Navigator.pop(ctx);
                }, 
                child: Text('Save', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          );
        });
      }
    );
  }

  void _addGroup() {
    final title = _newGroupController.text.trim();
    if (title.isNotEmpty) {
      setState(() {
        _groups.add(ModuleGroup(id: '\${DateTime.now().microsecondsSinceEpoch}_\${UniqueKey().toString()}', title: title));
        _newGroupController.clear();
      });
      _saveState();
    }
  }

  void _addItemToGroup(String groupId) {
    final title = _newItemController.text.trim();
    if (title.isNotEmpty) {
      setState(() {
        final group = _groups.firstWhere((g) => g.id == groupId);
        group.items.add(ModuleItem(id: '\${DateTime.now().microsecondsSinceEpoch}_\${UniqueKey().toString()}', title: title));
        _newItemController.clear();
      });
      _saveState();
    }
  }

  Widget _buildContent() {
    List<dynamic> flattened = [];

    for (var group in _groups) {
      flattened.add(group);
      
      if (!_collapsedGroups.contains(group.id)) {
        for (var item in group.items) {
          flattened.add(item);
        }
      }
    }

    return Column(
      children: [
        if (!widget.isDocked)
          GestureDetector(
            onPanUpdate: (d) => setState(() => _offset += d.delta),
            onPanEnd: (_) => _saveState(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: AppColors.controlBorder, width: AppUIConfig.windowBorderWidth) : null,
                color: AppColors.titleBarBackground.withOpacity(_bgOpacity),
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppUIConfig.windowBorderRadius)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.view_module, size: 16, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  Text(AppUIConfig.formatWindowTitle('Project Modules & Capabilities'), style: TextStyle(color: AppColors.titleBarTextPrimary, fontSize: AppUIConfig.windowTitleFontSize, fontWeight: AppUIConfig.windowTitleFontWeight)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: AppColors.titleBarTextSecondary),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        Container(
          color: AppColors.overlaySubtle,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add_task, size: 14, color: Colors.lightBlue),
                label: Text('Add Default Sections', style: TextStyle(color: Colors.lightBlue, fontSize: AppUIConfig.rootFontSize)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(0, 24),
                ),
                onPressed: _loadDefaultSections,
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.unfold_less, size: 14, color: Colors.orangeAccent),
                label: Text('Collapse All', style: TextStyle(color: Colors.orangeAccent, fontSize: AppUIConfig.rootFontSize)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(0, 24),
                ),
                onPressed: () {
                  setState(() {
                    for (var g in _groups) {
                      _collapsedGroups.add(g.id);
                    }
                  });
                  _saveState();
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever, size: 14, color: Colors.redAccent),
                label: Text('Delete All', style: TextStyle(color: Colors.redAccent, fontSize: AppUIConfig.rootFontSize)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(0, 24),
                ),
                onPressed: () {
                  setState(() => _groups.clear());
                  _saveState();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: AppColors.windowBackground.withOpacity(_bgOpacity),
            child: Column(
              children: [
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor: Colors.transparent,
                    ),
                    child: ReorderableListView.builder(
                      proxyDecorator: (child, index, animation) {
                        return Material(color: Colors.grey[900], child: child);
                      },
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      itemCount: flattened.length,
                      onReorder: (oldIndex, newIndex) {
                        if (oldIndex < newIndex) newIndex -= 1;
                        final dragged = flattened[oldIndex];
                        
                        setState(() {
                          if (dragged is ModuleGroup) {
                            int oldGIdx = _groups.indexOf(dragged);
                            dynamic target = flattened[newIndex];
                            if (target is ModuleItem) {
                              var targetGroup = _groups.firstWhere((g) => g.items.contains(target));
                              int targetGIdx = _groups.indexOf(targetGroup);
                              _groups.removeAt(oldGIdx);
                              _groups.insert(targetGIdx + 1, dragged);
                            } else if (target is ModuleGroup) {
                              int targetGIdx = _groups.indexOf(target);
                              _groups.removeAt(oldGIdx);
                              _groups.insert(targetGIdx, dragged);
                            }
                          } else if (dragged is ModuleItem) {
                            var sourceGroup = _groups.firstWhere((g) => g.items.contains(dragged));
                            sourceGroup.items.remove(dragged);
                            
                            dynamic target = flattened[newIndex];
                            if (target is ModuleGroup) {
                              target.items.insert(0, dragged);
                              _collapsedGroups.remove(target.id);
                            } else if (target is ModuleItem) {
                              var targetGroup = _groups.firstWhere((g) => g.items.contains(target));
                              int targetIIdx = targetGroup.items.indexOf(target);
                              
                              if (sourceGroup == targetGroup && oldIndex < newIndex) {
                                targetGroup.items.insert(targetIIdx + 1, dragged);
                              } else {
                                targetGroup.items.insert(targetIIdx, dragged);
                              }
                            }
                          }
                        });
                        _saveState();
                      },
                      itemBuilder: (context, index) {
                        final item = flattened[index];
                        if (item is ModuleGroup) {
                          bool isCollapsed = _collapsedGroups.contains(item.id);
                          return Container(
                            key: ObjectKey(item),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppColors.overlaySubtle)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isCollapsed) {
                                      _collapsedGroups.remove(item.id);
                                    } else {
                                      _collapsedGroups.add(item.id);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
                                            size: 16,
                                            color: AppColors.panelTextSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            item.iconCodePoint != null ? IconData(item.iconCodePoint!, fontFamily: 'MaterialIcons') : Icons.folder,
                                            size: 16,
                                            color: item.color != null ? Color(item.color!) : AppColors.panelTextSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => _showEditEntryDialog(item),
                                              child: Text(
                                                item.title.toUpperCase(),
                                                style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.add, size: 16, color: AppColors.panelTextSecondary),
                                            tooltip: 'Add Item',
                                            onPressed: () {
                                              _newItemController.clear();
                                              showDialog(context: context, builder: (ctx) => AlertDialog(
                                                backgroundColor: AppColors.panelBackground,
                                                title: Text('Add Item to \${item.title}', style: TextStyle(color: AppColors.panelTextPrimary)),
                                                content: TextField(
                                                  controller: _newItemController,
                                                  style: TextStyle(color: AppColors.panelTextPrimary),
                                                  decoration: InputDecoration(hintText: 'Item Title', hintStyle: TextStyle(color: AppColors.panelTextSecondary)),
                                                  autofocus: true,
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                                                  TextButton(onPressed: () {
                                                    _addItemToGroup(item.id);
                                                    setState(() => _collapsedGroups.remove(item.id));
                                                    Navigator.pop(ctx);
                                                  }, child: Text('Add')),
                                                ],
                                              ));
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            splashRadius: 16,
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: Icon(Icons.add_task, size: 16, color: AppColors.panelTextSecondary),
                                            tooltip: 'Send to AI Bridge',
                                            onPressed: () => _sendToAiBridge(item),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            splashRadius: 16,
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, size: 16, color: AppColors.panelTextSecondary),
                                            tooltip: 'Delete Group',
                                            onPressed: () {
                                              setState(() { _groups.remove(item); });
                                              _saveState();
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            splashRadius: 16,
                                          ),
                                          const SizedBox(width: 12),
                                          ReorderableDragStartListener(
                                            index: index,
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors.grab,
                                              child: Icon(Icons.drag_handle, color: AppColors.borderSubtle, size: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!isCollapsed && item.note.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 28, right: 28, bottom: 4),
                                          child: Text(
                                            item.note,
                                            style: TextStyle(color: Colors.white60, fontSize: AppUIConfig.rootFontSize),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        } else if (item is ModuleItem) {
                          return Container(
                            key: ObjectKey(item),
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(width: 8), // Removed heavy 38 indent from folder
                                ReorderableDragStartListener(
                                  index: index,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.grab,
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Icon(Icons.drag_handle, color: AppColors.borderSubtle, size: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Is Required',
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: item.isRequired,
                                      onChanged: (v) { setState(() => item.isRequired = v!); _saveState(); },
                                      activeColor: Colors.amberAccent,
                                      checkColor: Colors.black,
                                      side: BorderSide(color: AppColors.borderSubtle),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Is Included',
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: item.isIncluded,
                                      onChanged: (v) { setState(() => item.isIncluded = v!); _saveState(); },
                                      activeColor: Colors.cyanAccent,
                                      checkColor: Colors.black,
                                      side: BorderSide(color: AppColors.borderSubtle),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Icon(
                                    item.iconCodePoint != null ? IconData(item.iconCodePoint!, fontFamily: 'MaterialIcons') : Icons.article,
                                    size: 14,
                                    color: item.color != null ? Color(item.color!) : AppColors.borderSubtle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showEditEntryDialog(item),
                                    child: Container(
                                      color: Colors.transparent,
                                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              color: AppColors.panelTextPrimary, 
                                              fontSize: AppUIConfig.rootFontSize,
                                              decoration: item.isIncluded ? TextDecoration.lineThrough : null,
                                              decorationColor: Colors.cyanAccent,
                                              decorationThickness: 1.5,
                                            ),
                                          ),
                                          if (item.note.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                item.note,
                                                style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.add_task, size: 14, color: AppColors.borderSubtle),
                                  tooltip: 'Send to AI Bridge',
                                  onPressed: () => _sendToAiBridge(item),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 16,
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(Icons.close, size: 14, color: AppColors.borderSubtle),
                                  onPressed: () {
                                    setState(() {
                                      for (var g in _groups) {
                                        g.items.removeWhere((i) => i.id == item.id);
                                      }
                                    });
                                    _saveState();
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 16,
                                ),
                              ],
                            ),
                          );
                        }
                        return SizedBox.shrink(key: UniqueKey());
                      },
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.overlaySubtle)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newGroupController,
                          style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                          decoration: InputDecoration(
                            hintText: 'Add a new group...',
                            hintStyle: TextStyle(color: AppColors.panelTextSecondary),
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onSubmitted: (_) => _addGroup(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addGroup,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent.withOpacity(0.2)),
                        child: Text('Add Group', style: TextStyle(color: Colors.amberAccent, fontSize: AppUIConfig.rootFontSize)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {

    if (widget.isDocked) return _buildContent();

    Widget rz({
      double? t, double? b, double? l, double? r, double? w, double? h,
      required SystemMouseCursor cursor,
      required void Function(DragUpdateDetails) pan,
    }) => Positioned(
      top: t, bottom: b, left: l, right: r, width: w, height: h,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: pan,
          onPanEnd: (_) => _saveState(),
          child: Container(color: Colors.transparent),
        ),
      ),
    );

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      width: _width,
      height: _height,
      child: Listener(
        onPointerDown: (_) {
          widget.onFocus?.call();
        },
        behavior: HitTestBehavior.deferToChild,
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          child: Container(
            clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: AppColors.controlBorder, width: AppUIConfig.windowBorderWidth) : null,
              borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
              
            ),
            child: Stack(
              children: [
                _buildContent(),
                rz(t: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height - d.delta.dy;
                    if (nH >= 300 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(b: 0, l: 12, r: 12, h: 12, cursor: SystemMouseCursors.resizeUpDown, pan: (d) => setState((){
                    double nH = _height + d.delta.dy;
                    if (nH >= 300 && nH <= 1200) { _height = nH; }
                })),
                rz(l: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width - d.delta.dx;
                    if (nW >= 400 && nW <= 1200) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                })),
                rz(r: 0, t: 12, b: 12, w: 12, cursor: SystemMouseCursors.resizeLeftRight, pan: (d) => setState((){
                    double nW = _width + d.delta.dx;
                    if (nW >= 400 && nW <= 1200) { _width = nW; }
                })),
                rz(t: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width - d.delta.dx; double nH = _height - d.delta.dy;
                    if (nW >= 400 && nW <= 1200) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                    if (nH >= 300 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(t: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width + d.delta.dx; double nH = _height - d.delta.dy;
                    if (nW >= 400 && nW <= 1200) { _width = nW; }
                    if (nH >= 300 && nH <= 1200) { _height = nH; _offset += Offset(0, d.delta.dy); }
                })),
                rz(b: 0, l: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpRightDownLeft, pan: (d) => setState((){
                    double nW = _width - d.delta.dx; double nH = _height + d.delta.dy;
                    if (nW >= 400 && nW <= 1200) { _width = nW; _offset += Offset(d.delta.dx, 0); }
                    if (nH >= 300 && nH <= 1200) { _height = nH; }
                })),
                rz(b: 0, r: 0, w: 16, h: 16, cursor: SystemMouseCursors.resizeUpLeftDownRight, pan: (d) => setState((){
                    double nW = _width + d.delta.dx; double nH = _height + d.delta.dy;
                    if (nW >= 400 && nW <= 1200) { _width = nW; }
                    if (nH >= 300 && nH <= 1200) { _height = nH; }
                })),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



