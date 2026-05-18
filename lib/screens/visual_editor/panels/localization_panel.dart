import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../db/daos/i18n_dao.dart';
import '../../../db/app_database.dart';
import '../../../repositories/localization_sync_service.dart';
import '../../../scripts/tenant_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../components/folder_hierarchy_view.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../../../constants.dart';

class LocalizationPanel extends StatefulWidget {
  const LocalizationPanel({super.key});

  @override
  State<LocalizationPanel> createState() => _LocalizationPanelState();
}
class _LocalizationPanelState extends State<LocalizationPanel> {

  GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();
  bool _isSaving = false;
  
  SystemString? _selectedString;
  SystemString? _currentFolder;
  List<SystemString> _folderPath = [];
  bool _isCreatingNew = false;
  bool _isCreatingFolder = false;

  late Stream<List<SystemString>> _stringsStream;
  late Stream<List<SystemLanguage>> _languagesStream;
  List<SystemLanguage> _cachedLanguages = [];
  Map<int, String> _languageNames = {};
  double _leftPanelWidth = 380;

  @override
  void initState() {
    super.initState();
    _stringsStream = const Stream.empty();
    _languagesStream = const Stream.empty();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dao = context.read<I18nDao>();
    _stringsStream = dao.watchAllStrings();

    _languagesStream = dao.watchAllLanguages();
    _languagesStream.listen((langs) async {
       Map<int, String> names = {};
       for (var l in langs) {
          names[l.id] = await dao.getTranslationById(l.nameStringId, 'en') ?? l.code.toUpperCase();
       }
       if (mounted) {
         setState(() {
           _cachedLanguages = langs;
           _languageNames = names;
         });
       }
    });
  }

  void _navigateToFolder(SystemString? folder) async {
    List<SystemString> newPath = [];
    if (folder != null) {
      newPath.add(folder);
      var current = folder;
      while (current.parentId != null && mounted) {
        final parentData = await (context.read<I18nDao>().select(context.read<I18nDao>().db.strings)..where((s) => s.id.equals(current.parentId!))).getSingleOrNull();
        if (parentData == null) break;
        newPath.insert(0, parentData);
        current = parentData;
      }
    }
    if (mounted) {
      setState(() {
        _currentFolder = folder;
        _folderPath = newPath;
        _selectedString = null;
        _isCreatingNew = false;
        _isCreatingFolder = false;
      });
    }
  }

  Future<void> _moveString(int sourceId, int? targetParentId) async {
      if (sourceId == targetParentId) return;
      try {
        await Supabase.instance.client.from('strings').update({'parent_id': targetParentId}).eq('id', sourceId);
        final dao = context.read<I18nDao>();
        final s = await (dao.select(dao.db.strings)..where((x) => x.id.equals(sourceId))).getSingleOrNull();
        if (s != null) {
           await (dao.update(dao.db.strings)..where((x) => x.id.equals(sourceId))).write(
              StringsCompanion(parentId: drift.Value(targetParentId))
           );
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Moved successfully'), backgroundColor: AppColors.accent));
      } catch(e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Move failed: $e'), backgroundColor: Colors.red));
      }
  }

  void _startNewString({bool isFolder = false}) {
    setState(() {
      _selectedString = null;
      _isCreatingNew = true;
      _isCreatingFolder = isFolder;
      _formKey = GlobalKey<FormBuilderState>();
    });
  }

  Future<void> _selectString(SystemString s) async {
    final dao = context.read<I18nDao>();
    final translationsRaw = await (dao.select(dao.db.translations)..where((t) => t.stringId.equals(s.id))).get();
    
    Map<int, String> mapBlock = {};
    for (var t in translationsRaw) {
       mapBlock[t.langId] = t.value;
    }

    setState(() {
      _selectedString = s;
      _isCreatingNew = false;
      _isCreatingFolder = false;
      _formKey = GlobalKey<FormBuilderState>();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_formKey.currentState == null) return;
      
      Map<String, dynamic> patches = {
        'key': _cleanKey(s.key),
        'type': s.type,
        'description': s.description ?? '',
        'color': s.color ?? '',
        'parameter': s.parameter ?? '',
      };
      
      for (var lang in _cachedLanguages) {
         patches['lang_${lang.id}'] = mapBlock[lang.id] ?? '';
      }
      
      _formKey.currentState?.patchValue(patches);
    });
  }

  String _cleanKey(String raw) {
    final idx = raw.lastIndexOf('___');
    if (idx == -1) return raw;
    return raw.substring(0, idx);
  }
  @override
  Widget build(BuildContext context) {

    return Container(
      color: AppColors.windowBackground,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar: List of Strings
          Container(
            width: _leftPanelWidth,
            decoration: BoxDecoration(
              color: AppColors.panelBackground,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CATALOG STRINGS',
                        style: TextStyle(
                          color: AppColors.panelTextSecondary,
                          fontSize: AppUIConfig.rootFontSize,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recursively mapping dictionaries from Cloud...')));
                              await context.read<LocalizationSyncService>().sync();
                            },
                            icon: Icon(Icons.sync, color: AppColors.panelTextSecondary, size: 20),
                            tooltip: 'Pull Master Server Dictionaries',
                            padding: const EdgeInsets.only(right: 8),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            onPressed: () => _startNewString(isFolder: true),
                            icon: const Icon(Icons.create_new_folder, color: Colors.amberAccent, size: 20),
                            tooltip: 'Create New Folder',
                            padding: const EdgeInsets.only(right: 8),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            onPressed: () => _startNewString(isFolder: false),
                            icon: Icon(Icons.add, color: AppColors.accent, size: 20),
                            tooltip: 'Create New Localization Object',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<SystemString>>(
                    stream: _stringsStream,
                    builder: (context, snapshot) {
                      final strings = snapshot.data ?? [];
                      
                      var filteredStrings = strings.where((s) {
                          return s.parentId == _currentFolder?.id;
                      }).toList();
                      
                      return FolderHierarchyView<SystemString, SystemString>(
                        currentPath: _folderPath,
                        currentFolder: _currentFolder,
                        getFolderId: (f) => f.id.toString(),
                        getFolderName: (f) => _cleanKey(f.key),
                        rootName: 'Root Dictionaries',
                        items: filteredStrings,
                        selectedItem: _selectedString,
                        isItemFolder: (s) => s.type == 'FOLDER',
                        getItemId: (s) => s.id.toString(),
                        buildItemName: (s) => Text(_cleanKey(s.key), style: TextStyle(color: AppColors.panelTextPrimary, fontWeight: FontWeight.bold)),
                        getItemSubtitle: (s) => (s.description != null && s.description!.isNotEmpty) ? s.description : null,
                        getItemColor: (s) => s.type == 'FOLDER' ? Colors.amberAccent : Colors.greenAccent,
                        isItemSelected: (s) => _selectedString?.id == s.id && !_isCreatingNew,
                        getItemLeading: (s) => Icon(
                           s.type == 'FOLDER' ? Icons.folder : Icons.translate,
                           color: s.type == 'FOLDER' ? Colors.amberAccent : Colors.greenAccent,
                           size: s.type == 'FOLDER' ? 20 : 16
                        ),
                        onNavigateToFolder: _navigateToFolder,
                        onNavigateToItemFolder: _navigateToFolder,
                        onSelectItem: _selectString,
                        onMoveItem: (srcId, tgtId) => _moveString(int.parse(srcId), tgtId == null ? null : int.parse(tgtId)),
                        onReorder: (oldIndex, newIndex) {
                           if (oldIndex < newIndex) newIndex -= 1;
                           final List<SystemString> newStringsOrder = List.from(filteredStrings);
                           final movedString = newStringsOrder.removeAt(oldIndex);
                           newStringsOrder.insert(newIndex, movedString);
                           
                           final dao = context.read<I18nDao>();
                           for (int i = 0; i < newStringsOrder.length; i++) {
                              final stringId = newStringsOrder[i].id;
                              
                              Supabase.instance.client.from('strings').update({'sort_order': i}).eq('id', stringId).then((_) {}).catchError((e) {
                                print('Supabase sort_order cache error ignored: $e');
                              });
                              
                              (dao.update(dao.db.strings)..where((s) => s.id.equals(stringId))).write(StringsCompanion(sortOrder: drift.Value(i)));
                           }
                        },
                        isLoading: !snapshot.hasData,
                        emptyWidget: Center(child: Text('No strings in this directory.', style: TextStyle(color: AppColors.panelTextSecondary))),
                      );
                    }
                  ),
                ),
              ],
            ),
          ),
          
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _leftPanelWidth += details.delta.dx;
                  if (_leftPanelWidth < 380) _leftPanelWidth = 380;
                  if (_leftPanelWidth > MediaQuery.of(context).size.width - 300) {
                     _leftPanelWidth = MediaQuery.of(context).size.width - 300;
                  }
                });
              },
              child: Container(
                width: 8,
                color: const Color(0xFF2D2D30),
                child: Center(
                  child: Container(
                      width: 2,
                      height: 32,
                      color: AppColors.borderSubtle),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isCreatingNew
               ? _buildFormArea()
               : (_selectedString != null
                   ? _buildFormArea(actingItem: _selectedString)
                   : (_currentFolder != null
                       ? _buildFormArea(actingItem: _currentFolder)
                       : Center(child: Text('Inspect an item or root.', style: TextStyle(color: AppColors.panelTextSecondary)))
                     )
                 ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormArea({SystemString? actingItem}) {
    final typeVal = _isCreatingNew ? (_isCreatingFolder ? 'FOLDER' : 'STRING') : (actingItem?.type ?? 'STRING');
    final targetId = actingItem?.id;
    
    return Container(
      key: ValueKey('string_details_$targetId'),
      padding: const EdgeInsets.all(32.0),
      child: FormBuilder(
          key: _formKey,
        initialValue: _isCreatingNew ? {'type': _isCreatingFolder ? 'FOLDER' : 'STRING'} : {
          'key': actingItem?.key != null ? _cleanKey(actingItem!.key) : '',
          'type': actingItem?.type ?? 'STRING',
          'description': actingItem?.description ?? '',
          'color': actingItem?.color ?? '',
          'parameter': actingItem?.parameter ?? '',
        },
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(
                   _isCreatingNew ? 'Create Localization String' : (actingItem?.type == 'FOLDER' ? 'Folder Details: ${_cleanKey(actingItem!.key)}' : 'Editing: ${_cleanKey(actingItem!.key)}'),
                   style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                 ),
                 TextButton.icon(
                   onPressed: () {
                      // Add Language Flow stub
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Language Configurator opens here!')));
                   },
                   icon: Icon(Icons.language, color: AppColors.accent),
                   label: Text('Manage Languages', style: TextStyle(color: AppColors.accent)),
                 )
               ],
             ),
             const SizedBox(height: 32),
             
             Expanded(
               child: SingleChildScrollView(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('MASTER STRUCT', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                     const SizedBox(height: 12),

                     FormBuilderTextField(
                       name: 'key',
                       style: TextStyle(color: AppColors.panelTextPrimary),
                       decoration: _inputDecoration(typeVal == 'FOLDER' ? 'Folder Name (e.g. core)' : 'Localization Asset Name (e.g. Save Button)', typeVal == 'FOLDER' ? Icons.folder : Icons.key),
                       validator: (val) {
                         if (val == null || val.trim().isEmpty) return 'Asset Name is required.';
                         return null;
                       },
                     ),
                     const SizedBox(height: 16),

                     FormBuilderTextField(
                       name: 'description',
                       style: TextStyle(color: AppColors.panelTextPrimary),
                       maxLines: 2,
                       decoration: _inputDecoration('Context Description (For Translators)', Icons.info_outline),
                     ),
                     const SizedBox(height: 16),
                     
                     Row(
                        children: [
                           Expanded(
                              child: FormBuilderField<String>(
                                name: 'color',
                                builder: (FormFieldState<String> field) {
                                  Color? currentColor;
                                  if (field.value != null && field.value!.isNotEmpty) {
                                    try {
                                      String hex = field.value!.replaceAll('#', '');
                                      if (hex.length == 6) hex = 'FF$hex';
                                      currentColor = Color(int.parse(hex, radix: 16));
                                    } catch (_) {}
                                  }
                                  
                                  return InkWell(
                                    onTap: () async {
                                      final Color newColor = await showColorPickerDialog(
                                        context,
                                        currentColor ?? AppColors.accent,
                                        title: Text('Select Hex Assignment', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.panelTextPrimary)),
                                        heading: Text('Select visual asset representation color', style: TextStyle(color: AppColors.panelTextSecondary)),
                                        backgroundColor: AppColors.panelBackground,
                                        actionButtons: const ColorPickerActionButtons(
                                            dialogActionButtons: true,
                                        ),
                                        pickersEnabled: const <ColorPickerType, bool>{
                                          ColorPickerType.both: false,
                                          ColorPickerType.primary: false,
                                          ColorPickerType.accent: false,
                                          ColorPickerType.bw: false,
                                          ColorPickerType.custom: false,
                                          ColorPickerType.wheel: true,
                                        },
                                      );
                                      field.didChange('#${newColor.value.toRadixString(16).substring(2).toUpperCase()}');
                                    },
                                    child: InputDecorator(
                                      decoration: _inputDecoration('Visual Color Payload', Icons.color_lens),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24, height: 24,
                                            decoration: BoxDecoration(
                                              color: currentColor ?? Colors.transparent,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppColors.panelTextSecondary)
                                            )
                                          ),
                                          const SizedBox(width: 12),
                                          Text(field.value?.isNotEmpty == true ? field.value! : 'No Tag Color', style: TextStyle(color: currentColor ?? AppColors.panelTextSecondary, fontWeight: FontWeight.bold)),
                                        ]
                                      )
                                    )
                                  );
                                }
                              )
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                              child: FormBuilderTextField(
                                 name: 'parameter',
                                 style: TextStyle(color: AppColors.panelTextPrimary),
                                 decoration: _inputDecoration('Config Parameter', Icons.settings_input_component),
                              ),
                           ),
                        ],
                     ),
                     
                     if (typeVal != 'FOLDER') ...[
                         const SizedBox(height: 48),
                         Text('LOCALIZATION TRANSLATIONS', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold, letterSpacing: 2)),
                         const SizedBox(height: 12),

                         if (_cachedLanguages.isEmpty)
                            Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No language endpoints generated inside your database. Creating this string will initialize baseline English (en) mapping.', style: TextStyle(color: AppColors.panelTextSecondary, fontStyle: FontStyle.italic)),
                            ),

                         ..._cachedLanguages.map((lang) {
                            final name = _languageNames[lang.id] ?? lang.code.toUpperCase();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: FormBuilderTextField(
                                name: 'lang_${lang.id}',
                                style: TextStyle(color: AppColors.panelTextPrimary),
                                decoration: _inputDecoration('Translation for $name [${lang.code}]', Icons.translate),
                              ),
                            );
                         }),
                     ],
                     
                     const SizedBox(height: 48),
                     
                     Row(
                       children: [
                         Expanded(
                           child: SizedBox(
                             height: 50,
                             child: ElevatedButton.icon(
                               onPressed: () => _saveForm(actingItem),
                               icon: const Icon(Icons.sync),
                               label: Text(_isCreatingNew ? 'Create New Blueprint' : 'Synchronize Database'),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: AppColors.accent,
                                 foregroundColor: AppColors.panelTextPrimary,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius)),
                               ),
                             ),
                           ),
                         ),
                         if (!_isCreatingNew && actingItem != null) ...[
                           const SizedBox(width: 16),
                           Container(
                             height: 50,
                             clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: AppColors.controlBorder, width: AppUIConfig.windowBorderWidth) : null,
                                color: AppColors.overlaySubtle,
                                borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius)
                             ),
                             child: IconButton(
                               onPressed: () => _duplicateSelected(actingItem),
                               icon: Icon(Icons.copy, color: AppColors.panelTextPrimary),
                               tooltip: 'Duplicate Struct Blueprint',
                             ),
                           ),
                           const SizedBox(width: 8),
                           Container(
                             height: 50,
                             clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: AppColors.controlBorder, width: AppUIConfig.windowBorderWidth) : null,
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius)
                             ),
                             child: IconButton(
                               onPressed: () => _deleteSelected(actingItem),
                               icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                               tooltip: 'Delete Globally',
                             ),
                           ),
                         ]
                       ],
                     )
                   ],
                 ),
               ),
             ),
           ]
        ),
      ),
    );
  }
  
  void _saveForm(SystemString? actingItem) async {
    if (_isSaving) return;
    if (_formKey.currentState?.saveAndValidate() ?? false) {
       _isSaving = true;
       final values = _formKey.currentState!.value;
       
       final keyValRaw = values['key'] as String;
       String finalKey = keyValRaw;
       if (_isCreatingNew) {
           finalKey = '${keyValRaw}___${const Uuid().v4()}';
       } else if (actingItem != null) {
           final matchIdx = actingItem.key.lastIndexOf('___');
           final oldSuffix = matchIdx != -1 ? actingItem.key.substring(matchIdx) : '';
           finalKey = '$keyValRaw$oldSuffix';
       }

       final typeVal = _isCreatingNew ? (_isCreatingFolder ? 'FOLDER' : 'STRING') : (actingItem?.type ?? 'STRING');
       final descVal = values['description'] as String?;
       final colorValRaw = values['color'] as String?;
       final colorVal = (colorValRaw != null && colorValRaw.isNotEmpty) ? colorValRaw : null;
       final paramValRaw = values['parameter'] as String?;
       final paramVal = (paramValRaw != null && paramValRaw.isNotEmpty) ? paramValRaw : null;
       
       final dao = context.read<I18nDao>();
       final client = Supabase.instance.client;
       final tid = TenantService.currentTenantId ?? 0;
       
       await dao.getOrCreateLangId('en');

       bool didPushRealChanges = false;

       try {
         int strId;
         if (_isCreatingNew) {
             didPushRealChanges = true;
             final resp = await client.from('strings').upsert({
                'tenant_id': tid,
                'key': finalKey,
                'parent_id': _currentFolder?.id,
                'type': typeVal,
                'description': descVal,
                'color': colorVal,
                'parameter': paramVal,
                'updated_at': DateTime.now().toUtc().toIso8601String()
             }, onConflict: 'tenant_id,key').select().single();
             strId = resp['id'] as int;

             await dao.into(dao.db.strings).insert(
                StringsCompanion(
                   id: drift.Value(strId),
                   key: drift.Value(finalKey),
                   parentId: drift.Value(_currentFolder?.id),
                   type: drift.Value(typeVal),
                   description: drift.Value(descVal),
                   color: drift.Value(colorVal),
                   parameter: drift.Value(paramVal),
                   tenantId: drift.Value(tid),
                   createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
                   updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch)
                ),
                mode: drift.InsertMode.insertOrReplace
             );
             if (mounted) {
                 setState(() {
                     _isCreatingNew = false;
                     // Optional: auto-select the newly created string? Focus remains in the folder view anyway.
                 });
             }
         } else {
             strId = actingItem!.id;
             didPushRealChanges = true;
                 await client.from('strings').update({
                'key': finalKey,
                'type': typeVal,
                'description': descVal,
                'color': colorVal,
                'parameter': paramVal,
                'updated_at': DateTime.now().toUtc().toIso8601String()
             }).eq('id', strId);

             await (dao.update(dao.db.strings)..where((s) => s.id.equals(strId))).write(
                StringsCompanion(
                   key: drift.Value(finalKey),
                   type: drift.Value(typeVal),
                   description: drift.Value(descVal),
                   color: drift.Value(colorVal),
                   parameter: drift.Value(paramVal),
                   updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch)
                )
             );
         }
         
         if (typeVal != 'FOLDER') {
             List<Map<String, dynamic>> upsertPayloads = [];
             List<int> deleteIds = [];
             
             for (var lang in _cachedLanguages) {
                 final transVal = values['lang_${lang.id}'] as String?;
                 final existingDao = await (dao.select(dao.db.translations)..where((t) => t.stringId.equals(strId) & t.langId.equals(lang.id))).getSingleOrNull();

                 if (transVal != null && transVal.isNotEmpty) {
                    if (existingDao != null && existingDao.value == transVal) {
                        // Skip completely unchanged translation maps
                    } else {
                        upsertPayloads.add({
                        if (existingDao != null) 'id': existingDao.id,
                        'tenant_id': tid,
                        'string_id': strId,
                        'lang_id': lang.id,
                        'value': transVal,
                        'updated_at': DateTime.now().toUtc().toIso8601String()
                    });
                    }
                 } else if (existingDao != null) {
                    deleteIds.add(existingDao.id);
                 }
             }

             if (upsertPayloads.isNotEmpty) {
                 didPushRealChanges = true;
                 final transRespList = await client.from('translations').upsert(upsertPayloads, onConflict: 'string_id,lang_id').select();
                 
                 List<TranslationsCompanion> driftInserts = [];
                 for (var transResp in transRespList) {
                    driftInserts.add(TranslationsCompanion(
                       id: drift.Value(transResp['id'] as int),
                       tenantId: drift.Value(tid),
                       stringId: drift.Value(strId),
                       langId: drift.Value(transResp['lang_id'] as int),
                       value: drift.Value(transResp['value'] as String),
                       updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch)
                    ));
                 }
                 await dao.batch((batch) {
                    batch.insertAll(dao.db.translations, driftInserts, mode: drift.InsertMode.insertOrReplace);
                 });
             }

             if (deleteIds.isNotEmpty) {
                 didPushRealChanges = true;
                 await client.from('translations').delete().inFilter('id', deleteIds);
                 await (dao.delete(dao.db.translations)..where((t) => t.id.isIn(deleteIds))).go();
             }
         }

         if (didPushRealChanges && context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Globally verified taxonomy map: $keyValRaw'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
             ));
         }
       } catch (e, stack) {
         print('=== [LocalizationPanel] Server Upload Error ===');
         print(e);
         print(stack);
         print('===============================================');
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Storage Rejection (See Log): $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
           ));
         }
        } finally {
          _isSaving = false;
        }
    }
  }

  void _duplicateSelected(SystemString actingItem) {
     setState(() {
         _selectedString = null;
         _isCreatingNew = true;
         _isCreatingFolder = actingItem.type == 'FOLDER';
         _formKey = GlobalKey<FormBuilderState>();
     });
     
     final currentKey = _formKey.currentState?.value['key'] as String? ?? '';
     _formKey.currentState?.patchValue({
         'key': '${currentKey}_copy'
     });
  }

  void _deleteSelected(SystemString actingItem) async {
     final dao = context.read<I18nDao>();
     final client = Supabase.instance.client;
     final id = actingItem.id;

     try {
        await client.from('strings').delete().eq('id', id);
        await (dao.delete(dao.db.translations)..where((t) => t.stringId.equals(id))).go();
        await (dao.delete(dao.db.strings)..where((t) => t.id.equals(id))).go();

        setState(() {
           if (_selectedString?.id == id) _selectedString = null;
           if (_currentFolder?.id == id) {
               _navigateToFolder(_folderPath.isNotEmpty && _folderPath.length > 1 ? _folderPath[_folderPath.length - 2] : null);
           }
        });
        Future.microtask(() => _formKey.currentState?.reset());
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Successfully deleted array node globally!'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
           ));
        }
     } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Cloud Native Rejection: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
           ));
        }
     }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.panelTextSecondary),
      prefixIcon: Icon(icon, color: AppColors.accent.withOpacity(0.5)),
      filled: true,
      fillColor: AppColors.panelBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
        borderSide: BorderSide(color: AppColors.accent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}



