import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../../../db/daos/assets_dao.dart';

import '../../../db/daos/asset_tags_dao.dart';
import '../../../db/app_database.dart';

import '../../../scripts/tenant_service.dart';
import '../../../db/daos/i18n_dao.dart';
import '../../../repositories/assets_sync_service.dart';
import '../../../models/app_collection.dart';

import 'package:drift/drift.dart' as drift;
import '../components/folder_hierarchy_view.dart';

import '../../../widgets/draggable_alert_dialog.dart';
import '../../../constants.dart';

class AssetsPanelSessionCache {
  static final Map<String, Uint8List> modifiedFiles = {};
}

class AssetsPanel extends StatefulWidget {
  final Function(String id, String type, String name) onOpenTimeline;
  const AssetsPanel({super.key, required this.onOpenTimeline});

  @override
  State<AssetsPanel> createState() => _AssetsPanelState();
}
class _AssetsPanelState extends State<AssetsPanel> {

  Asset? _currentFolder;
  Asset? _selectedAsset;
  late Stream<List<Asset>> _assetsStream;
  double _leftPanelWidth = 380;
  bool _isUploading = false;
  String? _uploadProgressText;

  // Filtering states
  String _searchQuery = '';
  final List<int> _selectedTagFilterIds = [];
  String? _selectedCollectionType;
  int? _projectTagsFolderId;

  @override
  void initState() {
    super.initState();
    _assetsStream = const Stream.empty();
    _loadState();
  }

  List<Asset> _folderPath = [];

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final folderId = prefs.getInt('assets_current_folder_id');
    final assetId = prefs.getInt('assets_selected_asset_id');
    final strId = prefs.getString('project_tags_folder_id');
    _projectTagsFolderId = strId != null ? int.tryParse(strId) : null;

    if (mounted && folderId != null) {
      final folder = await context.read<AssetsDao>().getAssetById(folderId);
      if (mounted) _navigateToFolder(folder);
    } else if (mounted) {
      _loadStream();
    }

    if (mounted && assetId != null) {
      final asset = await context.read<AssetsDao>().getAssetById(assetId);
      if (mounted) setState(() => _selectedAsset = asset);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _loadStream() {
    if (_searchQuery.isNotEmpty ||
        _selectedTagFilterIds.isNotEmpty ||
        _selectedCollectionType != null) {
      _assetsStream = context.read<AssetTagsDao>().watchAssetsByFilters(
            tenantId: TenantService.currentTenantId ?? 0,
            stringIds:
                _selectedTagFilterIds.isNotEmpty ? _selectedTagFilterIds : null,
            searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
            collectionType: _selectedCollectionType,
          );
    } else {
      _assetsStream = context.read<AssetsDao>().watchAssetsInFolder(
          TenantService.currentTenantId ?? 0, _currentFolder?.id);
    }
  }

  void _navigateToFolder(Asset? folder) async {
    List<Asset> newPath = [];
    if (folder != null) {
      newPath.add(folder);
      var current = folder;
      while (current.parentId != null && mounted) {
        final parent =
            await context.read<AssetsDao>().getAssetById(current.parentId!);
        if (parent == null) break;
        newPath.insert(0, parent);
        current = parent;
      }
    }

    if (!mounted) return;

    setState(() {
      _currentFolder = folder;
      _folderPath = newPath;
      _selectedAsset = null;
    });

    final prefs = await SharedPreferences.getInstance();
    if (folder == null) {
      await prefs.remove('assets_current_folder_id');
    } else {
      await prefs.setInt('assets_current_folder_id', folder.id);
    }
    await prefs.remove('assets_selected_asset_id');
    _loadStream();
  }

  Future<void> _createNewFolder() async {
    final TextEditingController ctrl = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => DraggableAlertDialog(
              backgroundColor: AppColors.panelBackground,
              title: Text('Create Folder', style: TextStyle(color: AppColors.panelTextPrimary)),
              content: TextField(
                controller: ctrl,
                style: TextStyle(color: AppColors.panelTextPrimary),
                decoration: InputDecoration(
                    hintText: 'Folder Name',
                    hintStyle: TextStyle(color: AppColors.panelTextSecondary)),
                autofocus: true,
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Create')),
              ],
            ));

    if (confirmed == true && ctrl.text.isNotEmpty && mounted) {
      final name = ctrl.text.trim();
      final supabase = Supabase.instance.client;
      final tid = TenantService.currentTenantId ?? 0;

      try {
        final resp = await supabase
            .from('assets')
            .insert({
              'tenant_id': tid,
              'parent_id': _currentFolder?.id,
              'type': 'FOLDER',
              'name': name,
            })
            .select()
            .single();

        final dao = context.read<AssetsDao>();
        await dao.insertAsset(AssetsCompanion(
          id: drift.Value(resp['id'] as int),
          tenantId: drift.Value(tid),
          parentId: drift.Value(_currentFolder?.id),
          type: const drift.Value('FOLDER'),
          name: drift.Value(name),
        ));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _createNewJsonElement() async {
    final TextEditingController ctrl = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => DraggableAlertDialog(
              backgroundColor: AppColors.panelBackground,
              title: Text('New UI Element (JSON)', style: TextStyle(color: AppColors.panelTextPrimary)),
              content: TextField(
                controller: ctrl,
                style: TextStyle(color: AppColors.panelTextPrimary),
                decoration: InputDecoration(
                    hintText: 'e.g. hero_card',
                    hintStyle: TextStyle(color: AppColors.panelTextSecondary)),
                autofocus: true,
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Create')),
              ],
            ));

    if (confirmed == true && ctrl.text.isNotEmpty && mounted) {
      String name = ctrl.text.trim();
      if (!name.endsWith('.json')) name += '.json';

      setState(() {
        _isUploading = true;
        _uploadProgressText = 'Generating $name...';
      });

      final supabase = Supabase.instance.client;
      final tid = TenantService.currentTenantId ?? 0;

      try {
        final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
        final storagePath = '$tid/$uniqueId.json';
        const initialContent =
            '{\n  "version": "1.0",\n  "layers": [],\n  "config": {\n    "fps": 30,\n    "width": 1920,\n    "height": 1080\n  }\n}';

        await supabase.storage.from('tenant-assets').uploadBinary(
            storagePath, Uint8List.fromList(utf8.encode(initialContent)));

        try {
          final localBase = await _resolveLocalFolderPath();
          final localFile = File('$localBase\\$name');
          if (!await localFile.parent.exists()) {
            await localFile.parent.create(recursive: true);
          }
          await localFile.writeAsString(initialContent);
        } catch (ex) {
          debugPrint('Failed to initialize local JSON replica: $ex');
        }

        final resp = await supabase
            .from('assets')
            .insert({
              'tenant_id': tid,
              'parent_id': _currentFolder?.id,
              'type': 'FILE',
              'mime_type': 'application/json',
              'name': name,
              'storage_path': storagePath,
              'size_bytes': utf8.encode(initialContent).length
            })
            .select()
            .single();

        final dao = context.read<AssetsDao>();
        await dao.insertAsset(AssetsCompanion(
            id: drift.Value(resp['id'] as int),
            tenantId: drift.Value(tid),
            parentId: drift.Value(_currentFolder?.id),
            type: const drift.Value('FILE'),
            mimeType: const drift.Value('application/json'),
            name: drift.Value(name),
            storagePath: drift.Value(storagePath),
            sizeBytes: drift.Value(utf8.encode(initialContent).length)));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Created Element JSON!'),
              backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      } finally {
        setState(() {
          _isUploading = false;
          _uploadProgressText = null;
        });
      }
    }
  }

  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String originalName = result.files.single.name;
      String ext = originalName.split('.').last;

      setState(() {
        _isUploading = true;
        _uploadProgressText = 'Uploading $originalName...';
      });

      try {
        final tid = TenantService.currentTenantId ?? 0;
        final supabase = Supabase.instance.client;

        // 1. Upload to Storage
        final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
        final storagePath = '$tid/$uniqueId.$ext';

        await supabase.storage.from('tenant-assets').upload(storagePath, file);

        try {
          final localBase = await _resolveLocalFolderPath();
          final localFile = File('$localBase\\$originalName');
          if (!await localFile.parent.exists()) {
            await localFile.parent.create(recursive: true);
          }
          await file.copy(localFile.path);
        } catch (ex) {
          debugPrint('Failed to replicate file natively: $ex');
        }

        // 2. Insert into Database
        final resp = await supabase
            .from('assets')
            .insert({
              'tenant_id': tid,
              'parent_id': _currentFolder?.id,
              'type': 'FILE',
              'mime_type': _getMimeType(ext),
              'name': originalName,
              'storage_path': storagePath,
              'size_bytes': await file.length()
            })
            .select()
            .single();

        final dao = context.read<AssetsDao>();
        await dao.insertAsset(AssetsCompanion(
            id: drift.Value(resp['id'] as int),
            tenantId: drift.Value(tid),
            parentId: drift.Value(_currentFolder?.id),
            type: const drift.Value('FILE'),
            mimeType: drift.Value(_getMimeType(ext)),
            name: drift.Value(originalName),
            storagePath: drift.Value(storagePath),
            sizeBytes: drift.Value(await file.length())));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Upload Complete!'),
              backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Upload Failed: $e'), backgroundColor: Colors.red));
        }
      } finally {
        setState(() {
          _isUploading = false;
          _uploadProgressText = null;
        });
      }
    }
  }

  Future<void> _deleteAsset(Asset asset) async {
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => DraggableAlertDialog(
              backgroundColor: AppColors.panelBackground,
              title: Text(
                  'Delete ${asset.type == 'FOLDER' ? 'Folder' : 'File'}',
                  style: TextStyle(color: AppColors.panelTextPrimary)),
              content: Text(
                  'Are you sure you want to delete "${asset.name}"? This cannot be undone.',
                  style: TextStyle(color: AppColors.panelTextSecondary)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
              ],
            ));

    if (confirm != true || !mounted) return;

    final supabase = Supabase.instance.client;
    try {
      if (asset.type == 'FILE' && asset.storagePath != null) {
        await supabase.storage
            .from('tenant-assets')
            .remove([asset.storagePath!]);

        try {
          final localBase = await _resolveLocalFolderPath();
          final localFile = File('$localBase\\${asset.name}');
          if (await localFile.exists()) await localFile.delete();
        } catch (e) {}
      } else if (asset.type == 'FOLDER') {
        try {
          final targetUri = await _resolveLocalFolderPath(asset);
          final localDir = Directory(targetUri);
          if (await localDir.exists()) await localDir.delete(recursive: true);
        } catch (e) {}
      }

      await supabase.from('assets').delete().eq('id', asset.id);
      await context.read<AssetsDao>().deleteAsset(asset.id);

      if (_selectedAsset?.id == asset.id) {
        setState(() => _selectedAsset = null);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Deleted successfully'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _moveAsset(int sourceId, int? targetParentId) async {
    if (sourceId == targetParentId) return;

    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('assets')
          .update({'parent_id': targetParentId}).eq('id', sourceId);
      final dao = context.read<AssetsDao>();
      final asset = await dao.getAssetById(sourceId);
      if (asset != null) {
        await dao.updateAsset(asset
            .toCompanion(true)
            .copyWith(parentId: drift.Value(targetParentId)));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Moved successfully'),
            backgroundColor: AppColors.accent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Move failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'mp4':
        return 'video/mp4';
      case 'frag':
        return 'text/x-fragment-shader';
      case 'json':
        return 'application/json';
      case 'riv':
        return 'application/rive';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _showTrackBindingsForm(
      Asset layoutAsset, List<Asset> folderAssets) async {
    try {
      setState(() {
        _isUploading = true;
        _uploadProgressText = "Loading Bindings...";
      });
      final supabase = Supabase.instance.client;

      Uint8List bytes;
      if (AssetsPanelSessionCache.modifiedFiles
          .containsKey(layoutAsset.storagePath!)) {
        bytes =
            AssetsPanelSessionCache.modifiedFiles[layoutAsset.storagePath!]!;
      } else {
        bytes = await supabase.storage
            .from('tenant-assets')
            .download(layoutAsset.storagePath!);
      }
      final jsonString = utf8.decode(bytes);
      final payload = jsonDecode(jsonString);

      if (!mounted) return;
      setState(() => _isUploading = false);

      final globalItems = payload['globalItems'] ?? {};
      String currentAudio = globalItems['AUDIO_TRACK_OVERRIDE']?['keyframes']
              ?[0]?['value'] ??
          'null';
      String currentLyrics = globalItems['LYRICS_TRACK_OVERRIDE']?['keyframes']
              ?[0]?['value'] ??
          'null';
      String currentArt = globalItems['ALBUM_ART_OVERRIDE']?['keyframes']?[0]
              ?['value'] ??
          'null';

      final audioList = folderAssets
          .where((a) =>
              a.name.toLowerCase().endsWith('.mp3') ||
              a.name.toLowerCase().endsWith('.wav'))
          .map((a) => a.name)
          .toList();
      final lyricList = folderAssets
          .where((a) => a.name.toLowerCase().endsWith('.lrc'))
          .map((a) => a.name)
          .toList();
      final artList = folderAssets
          .where((a) =>
              a.name.toLowerCase().endsWith('.png') ||
              a.name.toLowerCase().endsWith('.jpg'))
          .map((a) => a.name)
          .toList();

      audioList.insert(0, 'null');
      lyricList.insert(0, 'null');
      artList.insert(0, 'null');

      if (!audioList.contains(currentAudio)) audioList.add(currentAudio);
      if (!lyricList.contains(currentLyrics)) lyricList.add(currentLyrics);
      if (!artList.contains(currentArt)) artList.add(currentArt);

      showDialog(
          context: context,
          builder: (ctx) {
            String sAudio = currentAudio;
            String sLyrics = currentLyrics;
            String sArt = currentArt;

            return StatefulBuilder(builder: (ctx, setModalState) {
              return DraggableAlertDialog(
                  backgroundColor: AppColors.panelBackground,
                  title: Text('Edit Track Bindings', style: TextStyle(color: AppColors.panelTextPrimary)),
                  content: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Primary Audio File', style: TextStyle(
                                color: Colors.amberAccent, fontSize: AppUIConfig.rootFontSize)),
                        DropdownButton<String>(
                            value: sAudio,
                            isExpanded: true,
                            dropdownColor: AppColors.windowBackground,
                            style: TextStyle(color: AppColors.panelTextPrimary),
                            onChanged: (v) => setModalState(() => sAudio = v!),
                            items: audioList
                                .map((str) => DropdownMenuItem(
                                    value: str, child: Text(str)))
                                .toList()),
                        const SizedBox(height: 16),
                        Text('Primary Lyrics File', style: TextStyle(
                                color: Colors.amberAccent, fontSize: AppUIConfig.rootFontSize)),
                        DropdownButton<String>(
                            value: sLyrics,
                            isExpanded: true,
                            dropdownColor: AppColors.windowBackground,
                            style: TextStyle(color: AppColors.panelTextPrimary),
                            onChanged: (v) => setModalState(() => sLyrics = v!),
                            items: lyricList
                                .map((str) => DropdownMenuItem(
                                    value: str, child: Text(str)))
                                .toList()),
                        const SizedBox(height: 16),
                        Text('Album Art Overlay', style: TextStyle(
                                color: Colors.amberAccent, fontSize: AppUIConfig.rootFontSize)),
                        DropdownButton<String>(
                            value: sArt,
                            isExpanded: true,
                            dropdownColor: AppColors.windowBackground,
                            style: TextStyle(color: AppColors.panelTextPrimary),
                            onChanged: (v) => setModalState(() => sArt = v!),
                            items: artList
                                .map((str) => DropdownMenuItem(
                                    value: str, child: Text(str)))
                                .toList()),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel')),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          setState(() {
                            _isUploading = true;
                            _uploadProgressText = "Saving Bindings...";
                          });

                          payload['globalItems'] ??= {};
                          payload['globalItems']['AUDIO_TRACK_OVERRIDE'] = {
                            "type": "STRING",
                            "keyframes": [
                              {"timeMs": 0, "value": sAudio}
                            ]
                          };
                          payload['globalItems']['LYRICS_TRACK_OVERRIDE'] = {
                            "type": "STRING",
                            "keyframes": [
                              {"timeMs": 0, "value": sLyrics}
                            ]
                          };
                          payload['globalItems']['ALBUM_ART_OVERRIDE'] = {
                            "type": "STRING",
                            "keyframes": [
                              {"timeMs": 0, "value": sArt}
                            ]
                          };

                          final newBytes = Uint8List.fromList(
                              utf8.encode(jsonEncode(payload)));

                          AssetsPanelSessionCache
                                  .modifiedFiles[layoutAsset.storagePath!] =
                              newBytes;

                          await Supabase.instance.client.storage
                              .from('tenant-assets')
                              .uploadBinary(layoutAsset.storagePath!, newBytes,
                                  fileOptions: const FileOptions(
                                      upsert: true, cacheControl: '0'));

                          await Supabase.instance.client
                              .from('assets')
                              .update({'size_bytes': newBytes.length}).eq(
                                  'id', layoutAsset.id);
                          final dao = context.read<AssetsDao>();
                          final localAst =
                              await dao.getAssetById(layoutAsset.id);
                          if (localAst != null) {
                            await dao.updateAsset(localAst
                                .toCompanion(true)
                                .copyWith(
                                    sizeBytes: drift.Value(newBytes.length)));
                          }

                          _bindingsCache[layoutAsset.storagePath!] =
                              (sAudio != 'null' && sAudio.trim() != '');

                          if (mounted) {
                            setState(() {
                              _isUploading = false;
                              _uploadProgressText = null;
                            });
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Bindings successfully saved to Layout JSON!'),
                                    backgroundColor: Colors.green));
                          }
                        },
                        child: Text('Save to Layout JSON', style: TextStyle(color: AppColors.panelTextPrimary)))
                  ]);
            });
          });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgressText = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to read config: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  final Map<String, bool> _bindingsCache = {};

  Future<bool> _hasValidBindings(String storagePath) async {
    if (_bindingsCache.containsKey(storagePath)) {
      return _bindingsCache[storagePath]!;
    }

    try {
      final supabase = Supabase.instance.client;
      Uint8List bytes;
      if (AssetsPanelSessionCache.modifiedFiles.containsKey(storagePath)) {
        bytes = AssetsPanelSessionCache.modifiedFiles[storagePath]!;
      } else {
        bytes =
            await supabase.storage.from('tenant-assets').download(storagePath);
      }
      final payload = jsonDecode(utf8.decode(bytes));
      final audio = payload['globalItems']?['AUDIO_TRACK_OVERRIDE']
          ?['keyframes']?[0]?['value'];
      final isValid =
          (audio != null && audio != 'null' && audio.toString().trim() != '');

      _bindingsCache[storagePath] = isValid;
      return isValid;
    } catch (e) {
      return false;
    }
  }
  @override
  Widget build(BuildContext context) {

    return Container(
      color: AppColors.windowBackground,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar: Asset Hierarchy
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
                        'ASSETS BUCKET',
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Syncing Assets...')));
                              await context.read<AssetsSyncService>().sync();
                            },
                            icon: Icon(Icons.sync,
                                color: AppColors.panelTextSecondary, size: 20),
                            tooltip: 'Sync Server Directory',
                            padding: const EdgeInsets.only(right: 8),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            onPressed: _createNewFolder,
                            icon: const Icon(Icons.create_new_folder,
                                color: Colors.amberAccent, size: 20),
                            tooltip: 'Create New Folder',
                            padding: const EdgeInsets.only(right: 8),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            onPressed: _createNewJsonElement,
                            icon: const Icon(Icons.note_add,
                                color: Colors.greenAccent, size: 20),
                            tooltip: 'Create UI Element JSON',
                            padding: const EdgeInsets.only(right: 8),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            onPressed: _uploadFile,
                            icon: Icon(Icons.upload_file,
                                color: AppColors.accent, size: 20),
                            tooltip: 'Upload File Asset',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StreamBuilder<List<AssetTag>>(
                          stream:
                              context.read<AssetTagsDao>().watchAllAssetTags(),
                          builder: (context, atSnap) {
                            final usedTagIds = (atSnap.data ?? [])
                                .map((at) => at.stringId)
                                .toSet();
                            return StreamBuilder<List<SystemString>>(
                                stream:
                                    context.read<I18nDao>().watchAllStrings(),
                                builder: (context, tagsSnap) {
                                  final allTags = _filterStringsByRoot(
                                      tagsSnap.data ?? [],
                                      _projectTagsFolderId);
                                  final usedTags = allTags
                                      .where((t) => usedTagIds.contains(t.id))
                                      .toList();
                                  if (usedTags.isEmpty) return const SizedBox();

                                  Map<int?, List<SystemString>> grouped = {};
                                  for (var t in usedTags) {
                                    grouped
                                        .putIfAbsent(t.parentId, () => [])
                                        .add(t);
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: grouped.entries.map((e) {
                                      final parentId = e.key;
                                      final children = e.value;
                                      final SystemString? parentTag =
                                          parentId != null
                                              ? allTags
                                                  .cast<SystemString?>()
                                                  .firstWhere(
                                                      (t) => t?.id == parentId,
                                                      orElse: () => null)
                                              : null;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (parentTag != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 4, top: 4),
                                              child: FutureBuilder<String?>(
                                                future: context
                                                    .read<I18nDao>()
                                                    .getTranslationById(
                                                        parentTag.id, 'en'),
                                                builder: (context, strSnap) =>
                                                    Text(
                                                        (strSnap.data ??
                                                                parentTag.key)
                                                            .toUpperCase(),
                                                        style: TextStyle(
                                                            color: Colors
                                                                .amberAccent,
                                                            fontSize: AppUIConfig.smallFontSize,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            letterSpacing:
                                                                1.2)),
                                              ),
                                            )
                                          else if (grouped.length > 1)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                  bottom: 4, top: 4),
                                              child: Text('UNGROUPED',
                                                  style: TextStyle(
                                                      color: AppColors.panelTextSecondary,
                                                      fontSize: AppUIConfig.smallFontSize,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1.2)),
                                            ),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: Wrap(
                                              spacing: 8.0,
                                              children: children.map((t) {
                                                final bool isSelected =
                                                    _selectedTagFilterIds
                                                        .contains(t.id);
                                                return FilterChip(
                                                  label: FutureBuilder<String?>(
                                                    future: context
                                                        .read<I18nDao>()
                                                        .getTranslationById(
                                                            t.id, 'en'),
                                                    builder: (context, strSnap) =>
                                                        Text(
                                                            (strSnap.data ??
                                                                    t.key)
                                                                .toUpperCase(),
                                                            style: TextStyle(
                                                                color: isSelected
                                                                    ? Colors
                                                                        .black
                                                                    : Colors
                                                                        .white70,
                                                                fontSize: AppUIConfig.smallFontSize,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                  ),
                                                  selected: isSelected,
                                                  selectedColor:
                                                      Colors.amberAccent,
                                                  backgroundColor:
                                                      AppColors.windowBackground,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      side: BorderSide(
                                                          color: isSelected
                                                              ? Colors
                                                                  .amberAccent
                                                              : Colors
                                                                  .white24)),
                                                  padding: EdgeInsets.zero,
                                                  labelPadding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 0),
                                                  onSelected: (selected) {
                                                    setState(() {
                                                      if (selected) {
                                                        _selectedTagFilterIds
                                                            .add(t.id);
                                                      } else {
                                                        _selectedTagFilterIds
                                                            .remove(t.id);
                                                      }
                                                    });
                                                    _loadStream();
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  );
                                });
                          }),
                      const SizedBox(height: 8),
                      TextField(
                        style:
                            TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                        decoration: InputDecoration(
                          hintText: 'Search by filename or desc...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          prefixIcon: Icon(Icons.search,
                              color: AppColors.textMuted, size: 16),
                          filled: true,
                          fillColor: AppColors.windowBackground,
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                              borderSide: BorderSide.none),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val.trim());
                          _loadStream();
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedCollectionType,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Collection Type',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.windowBackground,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                              borderSide: BorderSide.none),
                        ),
                        dropdownColor: AppColors.panelBackground,
                        icon: Icon(Icons.filter_list,
                            color: AppColors.textMuted, size: 16),
                        items: [
                          DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Any Type',
                                  style: TextStyle(
                                      color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize))),
                          ...AppCollectionType.values
                              .map((v) => DropdownMenuItem<String?>(
                                    value: v.name,
                                    child: Text(v.name,
                                        style: TextStyle(
                                            color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                                        overflow: TextOverflow.ellipsis),
                                  )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedCollectionType = val);
                          _loadStream();
                        },
                      ),
                    ],
                  ),
                ),
                if (_isUploading)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_uploadProgressText ?? 'Uploading...',
                            style: TextStyle(
                                color: AppColors.accent, fontSize: AppUIConfig.rootFontSize)),
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                Expanded(
                  child: StreamBuilder<List<Asset>>(
                      stream: _assetsStream,
                      builder: (context, snapshot) {
                        final assets = snapshot.data ?? [];

                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  child: FolderHierarchyView<Asset, Asset>(
                                currentPath: _folderPath,
                                currentFolder: _currentFolder,
                                getFolderId: (f) => f.id.toString(),
                                getFolderName: (f) => f.name,
                                rootName: 'Root Assets',
                                items: assets,
                                selectedItem: _selectedAsset,
                                isItemFolder: (a) => a.type == 'FOLDER',
                                getItemId: (a) => a.id.toString(),
                                buildItemName: (a) => Text(a.name,
                                    style: TextStyle(
                                        color: AppColors.panelTextPrimary,
                                        fontWeight: FontWeight.w500)),
                                getItemSubtitle: (a) => a.type == 'FILE'
                                    ? (a.mimeType ?? 'Unknown File')
                                    : null,
                                getItemColor: (a) => a.type == 'FOLDER'
                                    ? Colors.amberAccent
                                    : AppColors.accent,
                                isItemSelected: (a) =>
                                    _selectedAsset?.id == a.id,
                                getItemLeading: (a) => Icon(
                                    a.type == 'FOLDER'
                                        ? Icons.folder
                                        : Icons.insert_drive_file,
                                    color: a.type == 'FOLDER'
                                        ? Colors.amberAccent
                                        : AppColors.panelTextSecondary,
                                    size: 20),
                                getItemTrailing: (a) => IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: AppColors.borderSubtle, size: 18),
                                  onPressed: () => _deleteAsset(a),
                                  tooltip: 'Delete ${a.type}',
                                  hoverColor: Colors.redAccent.withOpacity(0.2),
                                ),
                                onNavigateToFolder: _navigateToFolder,
                                onNavigateToItemFolder: _navigateToFolder,
                                onSelectItem: (a) async {
                                  setState(() => _selectedAsset = a);
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setInt(
                                      'assets_selected_asset_id', a.id);
                                },
                                onMoveItem: (srcId, tgtId) => _moveAsset(
                                    int.parse(srcId),
                                    tgtId == null ? null : int.parse(tgtId)),
                                onReorder: (oldIndex, newIndex) {
                                  if (oldIndex < newIndex) newIndex -= 1;
                                  final List<Asset> newAssetsList =
                                      List.from(assets);
                                  final movedItem =
                                      newAssetsList.removeAt(oldIndex);
                                  newAssetsList.insert(newIndex, movedItem);

                                  final dao = context.read<AssetsDao>();
                                  for (int i = 0;
                                      i < newAssetsList.length;
                                      i++) {
                                    final itemId = newAssetsList[i].id;
                                    Supabase.instance.client
                                        .from('assets')
                                        .update({'sort_order': i})
                                        .eq('id', itemId)
                                        .then((_) {});
                                    dao.getAssetById(itemId).then((dbAsset) {
                                      if (dbAsset != null) {
                                        dao.updateAsset(dbAsset
                                            .toCompanion(true)
                                            .copyWith(
                                                sortOrder: drift.Value(i)));
                                      }
                                    });
                                  }
                                },
                                isLoading: !snapshot.hasData,
                                emptyWidget: Center(
                                    child: Text('Bucket is empty.',
                                        style:
                                            TextStyle(color: AppColors.panelTextSecondary))),
                              ))
                            ]);
                      }),
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
                  if (_leftPanelWidth >
                      MediaQuery.of(context).size.width - 300) {
                    _leftPanelWidth = MediaQuery.of(context).size.width - 300;
                  }
                });
              },
              child: Container(
                width: 8,
                color: const Color(0xFF2D2D30),
                child: Center(
                  child: Container(width: 2, height: 32, color: AppColors.borderSubtle),
                ),
              ),
            ),
          ),

          // Right Content: Selected Asset Options
          Expanded(
            child: _selectedAsset != null
                ? _buildSelectedAssetArea(_selectedAsset!)
                : (_currentFolder != null
                    ? _buildSelectedAssetArea(_currentFolder!)
                    : Center(
                        child: Text(
                            'Select a file or folder to inspect metadata.',
                            style: TextStyle(color: AppColors.panelTextSecondary)))),
          ),
        ],
      ),
    );
  }

  Future<Asset?> _showAssetSearchPicker(BuildContext context, {bool foldersOnly = false}) async {
    Asset? currentFolder;
    List<Asset> path = [];
    
    return await showDialog<Asset>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return DraggableAlertDialog(
            backgroundColor: AppColors.panelBackground,
            title: Text('Browse for Track Folder', style: TextStyle(color: AppColors.panelTextPrimary)),
            content: SizedBox(
              width: 500, height: 400,
              child: StreamBuilder<List<Asset>>(
                 stream: context.read<AssetsDao>().watchAssetsInFolder(TenantService.currentTenantId ?? 0, currentFolder?.id),
                 builder: (context, snapshot) {
                    final items = (snapshot.data ?? []).where((a) => !foldersOnly || a.type == 'FOLDER').toList();
                    return Column(
                       children: [
                          if (currentFolder != null) ...[
                             Row(
                                children: [
                                   IconButton(
                                      icon: const Icon(Icons.arrow_upward, color: Colors.amberAccent),
                                      onPressed: () {
                                         setModalState(() {
                                            if (path.isNotEmpty) {
                                               currentFolder = path.removeLast();
                                            } else {
                                               currentFolder = null;
                                            }
                                         });
                                      }
                                   ),
                                   Expanded(child: Text(currentFolder!.name.toUpperCase(), style: TextStyle(color: AppColors.panelTextPrimary, fontWeight: FontWeight.bold))),
                                   ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                                      onPressed: () => Navigator.pop(ctx, currentFolder),
                                      child: Text('LINK THIS FOLDER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                                   )
                                ]
                             ),
                             Divider(color: AppColors.borderSubtle),
                          ] else ...[
                             Padding(
                                 padding: EdgeInsets.all(8.0),
                                 child: Text('ROOT ASSETS DIRECTORY', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                             ),
                             Divider(color: AppColors.borderSubtle),
                          ],
                          Expanded(
                             child: items.isEmpty
                                ? Center(child: Text('Empty Directory', style: TextStyle(color: AppColors.panelTextSecondary)))
                                : ListView.builder(
                                   itemCount: items.length,
                                   itemBuilder: (context, index) {
                                      final ast = items[index];
                                      final isFolder = ast.type == 'FOLDER';
                                      return ListTile(
                                         leading: Icon(isFolder ? Icons.folder : Icons.insert_drive_file, color: isFolder ? Colors.amberAccent : AppColors.panelTextSecondary),
                                         title: Text(ast.name.toUpperCase(), style: TextStyle(color: AppColors.panelTextPrimary)),
                                         trailing: isFolder ? Icon(Icons.chevron_right, color: AppColors.panelTextSecondary) : IconButton(
                                            icon: const Icon(Icons.add_link, color: Colors.cyanAccent),
                                            onPressed: () => Navigator.pop(ctx, ast),
                                            tooltip: 'Link this file',
                                         ),
                                         onTap: () {
                                            if (isFolder) {
                                               setModalState(() {
                                                  if (currentFolder != null) path.add(currentFolder!);
                                                  currentFolder = ast;
                                               });
                                            } else {
                                               Navigator.pop(ctx, ast);
                                            }
                                         },
                                      );
                                   }
                                )
                          ),
                       ]
                    );
                 }
              )
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary)))
            ]
          );
        }
      )
    );
  }

  Future<String> _resolveLocalFolderPath([Asset? appendAsset]) async {
    final prefs = await SharedPreferences.getInstance();
    String baseDir = prefs.getString('project_local_repository_path') ?? '';
    baseDir = baseDir.trim();
    if (baseDir.endsWith('/') || baseDir.endsWith('\\')) {
      baseDir = baseDir.substring(0, baseDir.length - 1);
    }

    String targetUri = baseDir;
    for (final f in _folderPath) {
      targetUri += '\\${f.name}';
    }

    if (appendAsset != null && appendAsset.type == 'FOLDER') {
      targetUri += '\\${appendAsset.name}';
    }

    return targetUri;
  }

  Widget _buildSelectedAssetArea(Asset asset) {
    final sizeMB = asset.sizeBytes != null
        ? (asset.sizeBytes! / (1024 * 1024)).toStringAsFixed(2)
        : '0.00';

    return ListView(
      key: ValueKey('asset_details_${asset.id}'),
      padding: const EdgeInsets.all(32.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${asset.type == 'FOLDER' ? 'Folder' : 'File'} Details',
                style: TextStyle(
                    color: AppColors.panelTextPrimary,
                    fontSize: AppUIConfig.rootFontSize,
                    fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                  onPressed: () async {
                    String targetUri = await _resolveLocalFolderPath(asset);

                    final dir = Directory(targetUri);
                    if (!dir.existsSync()) {
                      try {
                        dir.createSync(recursive: true);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  'Failed to create local path: $targetUri')));
                        }
                        return;
                      }
                    }

                    if (asset.type == 'FILE' && asset.storagePath != null) {
                      final fileToCheck = File('$targetUri\\${asset.name}');
                      if (!fileToCheck.existsSync()) {
                        try {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Downloading file from cloud...')));
                          }
                          final bytes = await Supabase.instance.client.storage
                              .from('tenant-assets')
                              .download(asset.storagePath!);
                          fileToCheck.writeAsBytesSync(bytes);
                        } catch (e) {
                          debugPrint(
                              'Failed to auto-download asset for local sync: $e');
                        }
                      }
                    }

                    Process.start('explorer.exe', [dir.path]);
                  },
                  icon: const Icon(Icons.folder_open),
                  color: Colors.amberAccent,
                  tooltip: 'Open Physical Containing Folder',
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteAsset(asset),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.redAccent,
                  tooltip: 'Delete Asset',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (asset.type == 'FOLDER') ...[
          StreamBuilder<List<SystemString>>(
              stream: context.read<I18nDao>().watchAllStringFolders(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final folders = snapshot.data!;

                Map<int, List<SystemString>> childrenMap = {};
                for (var f in folders) {
                  final pid = f.parentId ?? 0;
                  childrenMap.putIfAbsent(pid, () => []).add(f);
                }

                List<DropdownMenuItem<int?>> treeItems = [
                  DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None (Mapped freeform)',
                          style: TextStyle(color: AppColors.panelTextSecondary)))
                ];
                List<Widget> selectedWidgets = [
                  Text('None (Mapped freeform)', style: TextStyle(color: AppColors.panelTextSecondary))
                ];

                void traverse(int pid, int depth) {
                  final children = childrenMap[pid] ?? [];
                  children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                  for (var child in children) {
                    final cleanKey = child.key.contains('___')
                        ? child.key.substring(0, child.key.lastIndexOf('___'))
                        : child.key;
                    final indent = '   ' * depth;
                    treeItems.add(DropdownMenuItem<int?>(
                      value: child.id,
                      child: Text('$indent$cleanKey',
                          style: TextStyle(
                              color: depth == 0
                                  ? Colors.amberAccent
                                  : AppColors.panelTextPrimary)),
                    ));
                    selectedWidgets.add(Text(cleanKey,
                        style: const TextStyle(color: Colors.amberAccent)));
                    traverse(child.id, depth + 1);
                  }
                }

                traverse(0, 0);

                return DropdownButtonFormField<int?>(
                  key: ValueKey('asset_mapped_str_folder_${asset.id}'),
                  initialValue: asset.mappedStringFolderId,
                  decoration: InputDecoration(
                    labelText: 'Target Strings Folder (Folder Mapping)',
                    labelStyle: TextStyle(color: Colors.amberAccent),
                    filled: true,
                    fillColor: AppColors.panelBackground,
                    border: OutlineInputBorder(),
                  ),
                  dropdownColor: AppColors.panelBackground,
                  items: treeItems,
                  selectedItemBuilder: (context) => selectedWidgets,
                  onChanged: (val) async {
                     await Supabase.instance.client.from('assets').update({'mapped_string_folder_id': val}).eq('id', asset.id);
                     final dao = context.read<AssetsDao>();
                     await dao.updateAsset(asset.toCompanion(true).copyWith(mappedStringFolderId: drift.Value(val)));
                     if (mounted) {
                        setState(() {
                           if (_selectedAsset?.id == asset.id) _selectedAsset = _selectedAsset!.copyWith(mappedStringFolderId: drift.Value(val));
                           if (_currentFolder?.id == asset.id) _currentFolder = _currentFolder!.copyWith(mappedStringFolderId: drift.Value(val));
                        });
                     }
                  },
                );
              }),
        ],

        const SizedBox(height: 16),

        TextFormField(
          key: ValueKey('asset_name_${asset.id}'),
          initialValue: asset.name,
          style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
          decoration: InputDecoration(
            labelText: 'Asset Name',
            labelStyle: TextStyle(color: AppColors.accent),
            filled: true,
            fillColor: AppColors.panelBackground,
            border: OutlineInputBorder(),
          ),
          onFieldSubmitted: (finalName) async {
            try {
              await Supabase.instance.client
                  .from('assets')
                  .update({'name': finalName}).eq('id', asset.id);
              final dao = context.read<AssetsDao>();
              await dao.updateAsset(asset
                  .toCompanion(true)
                  .copyWith(name: drift.Value(finalName)));
              if (mounted) {
                setState(() {
                  if (_selectedAsset?.id == asset.id) {
                    _selectedAsset = _selectedAsset!.copyWith(name: finalName);
                  }
                  final idx = _folderPath.indexWhere((p) => p.id == asset.id);
                  if (idx >= 0) {
                    _folderPath[idx] = _folderPath[idx].copyWith(name: finalName);
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Renamed successfully to $finalName'),
                    backgroundColor: Colors.green));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Failed to rename: $e'),
                    backgroundColor: Colors.red));
              }
            }
          },
        ),

        const SizedBox(height: 16),

        TextFormField(
          key: ValueKey('asset_desc_${asset.id}'),
          initialValue: asset.description ?? '',
          style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
          decoration: InputDecoration(
            labelText: 'Asset Description',
            labelStyle: TextStyle(color: AppColors.accent),
            filled: true,
            fillColor: AppColors.panelBackground,
            border: OutlineInputBorder(),
          ),
          onFieldSubmitted: (val) async {
            await Supabase.instance.client
                .from('assets')
                .update({'description': val}).eq('id', asset.id);
            final dao = context.read<AssetsDao>();
            await dao.updateAsset(asset
                .toCompanion(true)
                .copyWith(description: drift.Value(val)));
            if (mounted) {
              setState(() {
                if (_selectedAsset?.id == asset.id) {
                  _selectedAsset =
                      _selectedAsset!.copyWith(description: drift.Value(val));
                }
                if (_currentFolder?.id == asset.id) {
                  _currentFolder =
                      _currentFolder!.copyWith(description: drift.Value(val));
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Description saved successfully'),
                  backgroundColor: Colors.green));
            }
          },
        ),

        const SizedBox(height: 16),
        TextFormField(
          key: ValueKey('asset_keywords_${asset.id}'),
          initialValue: asset.searchKeywords ?? '',
          style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
          decoration: InputDecoration(
            labelText: 'Search Keywords (Space-Delimited)',
            labelStyle: TextStyle(color: Colors.purpleAccent),
            filled: true,
            fillColor: AppColors.panelBackground,
            border: OutlineInputBorder(),
          ),
          onFieldSubmitted: (val) async {
            await Supabase.instance.client
                .from('assets')
                .update({'search_keywords': val}).eq('id', asset.id);
            final dao = context.read<AssetsDao>();
            await dao.updateAsset(asset
                .toCompanion(true)
                .copyWith(searchKeywords: drift.Value(val)));
            if (mounted) {
              setState(() {
                if (_selectedAsset?.id == asset.id) {
                  _selectedAsset = _selectedAsset!
                      .copyWith(searchKeywords: drift.Value(val));
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Keywords successfully saved'),
                  backgroundColor: Colors.green));
            }
          },
        ),
        if (asset.type == 'FILE' && (asset.name.toLowerCase().endsWith('.lrc') || asset.name.toLowerCase().endsWith('.json')))
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                label: Text('Auto-Extract Keywords from Lyrics', style: TextStyle(color: AppColors.panelTextPrimary)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.controlBorder),
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading lyrics chunk & parsing...')));
                    final bytes = await Supabase.instance.client.storage.from('tenant-assets').download(asset.storagePath!);
                    final content = utf8.decode(bytes);
                    final exp = RegExp(r'\b[a-zA-Z]{4,}\b');
                    final matchedText = exp.allMatches(content).map((m) => m.group(0)!.toLowerCase()).toSet();
                    
                    // Exclude massive common token noise words
                    final exclusionList = {'that', 'this', 'with', 'from', 'your', 'have', 'they', 'will', 'what', 'when', 'just'};
                    matchedText.removeWhere((word) => exclusionList.contains(word));
                    
                    final keywords = matchedText.join(' ');

                    final dao = context.read<AssetsDao>();
                    await Supabase.instance.client.from('assets').update({'search_keywords': keywords}).eq('id', asset.id);
                    await dao.updateAsset(asset.toCompanion(true).copyWith(searchKeywords: drift.Value(keywords)));
                    
                    if (asset.parentId != null) {
                       await Supabase.instance.client.from('assets').update({'search_keywords': keywords}).eq('id', asset.parentId!);
                       final parent = await dao.getAssetById(asset.parentId!);
                       if (parent != null) await dao.updateAsset(parent.toCompanion(true).copyWith(searchKeywords: drift.Value(keywords)));
                    }

                    if (mounted) {
                       setState(() {
                          if (_selectedAsset?.id == asset.id) {
                             _selectedAsset = _selectedAsset!.copyWith(searchKeywords: drift.Value(keywords));
                          }
                       });
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully parsed ${matchedText.length} unique lyrics mapping to File & Track Directory!'), backgroundColor: Colors.purpleAccent));
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                  }
                }),
          ),
        const SizedBox(height: 16),
        _AlternateVersionsEditor(
          asset: asset,
          onNavigate: _navigateToFolder,
          showSearchPicker: _showAssetSearchPicker,
          onAssetUpdate: (updatedAsset) {
            if (mounted) {
              setState(() {
                if (_selectedAsset?.id == asset.id) _selectedAsset = updatedAsset;
                if (_currentFolder?.id == asset.id) _currentFolder = updatedAsset;
              });
            }
          },
        ),
        const SizedBox(height: 24),
        _AssetTagsEditor(asset: asset),
        const SizedBox(height: 24),

        ExpansionTile(
            title: Text('Actual File Details (Storage Envelope)', style: TextStyle(color: Colors.amberAccent)),
            initiallyExpanded: true,
            collapsedIconColor: Colors.amberAccent,
            iconColor: Colors.amberAccent,
            childrenPadding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Text('Original Name: ', style: TextStyle(color: AppColors.panelTextSecondary)),
                Text(asset.name.toUpperCase(), style: TextStyle(color: AppColors.panelTextPrimary))
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text('Size: ', style: TextStyle(color: AppColors.panelTextSecondary)),
                Text('$sizeMB MB', style: TextStyle(color: AppColors.panelTextPrimary))
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text('MIME Base: ', style: TextStyle(color: AppColors.panelTextSecondary)),
                Text(asset.mimeType ?? "N/A",
                    style: TextStyle(color: AppColors.panelTextPrimary))
              ]),
            ]),

        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: AppColors.controlBorder, width: AppUIConfig.windowBorderWidth) : null,
              color: Colors.black26,
              borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius)),
          child: Text('Bucket Uniform Path: \n${asset.storagePath ?? "N/A"}',
              style: TextStyle(
                  color: AppColors.accent, fontFamily: 'monospace')),
        ),
        const SizedBox(height: 48),
        Row(children: [
          if (asset.type == 'FILE' &&
              asset.name.toLowerCase().endsWith('.json')) ...[
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.panelTextSecondary,
                    side: BorderSide(color: AppColors.textMuted),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius)),
                  ),
                  onPressed: () async {
                    final dao = context.read<AssetsDao>();
                    final folderAssets = await dao.select(dao.assets).get();
                    final localSiblings = folderAssets
                        .where((a) => a.parentId == asset.parentId)
                        .toList();
                    _showTrackBindingsForm(asset, localSiblings);
                  },
                  icon: const Icon(Icons.tune),
                  label: Text('Edit Track Bindings', style: TextStyle(fontSize: AppUIConfig.rootFontSize)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FutureBuilder<bool>(
                    key: ValueKey(
                        '${asset.storagePath}_${_bindingsCache[asset.storagePath ?? '']}'),
                    future: _hasValidBindings(asset.storagePath ?? ''),
                    builder: (context, snapshot) {
                      final hasBindings = snapshot.data ?? false;
                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasBindings
                              ? AppColors.accent
                              : Colors.grey[850],
                          foregroundColor:
                              hasBindings ? AppColors.panelTextPrimary : AppColors.textMuted,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius)),
                        ),
                        onPressed: hasBindings
                            ? () {
                                widget.onOpenTimeline(asset.storagePath ?? '',
                                    'asset', asset.name);
                              }
                            : null,
                        icon: const Icon(Icons.dashboard_customize),
                        label: Text(
                            hasBindings
                                ? 'Open in Timeline Editor'
                                : 'Missing Bindings',
                            style: TextStyle(
                                fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
                      );
                    }),
              ),
            ),
          ],
        ]),
      ],
    );
  }

  Future<List<MapEntry<SystemString, String>>> _fetchInheritedStringOptions(
      Asset asset) async {
    int? folderId;
    if (asset.type == 'FOLDER' && asset.mappedStringFolderId != null) {
      folderId = asset.mappedStringFolderId;
    } else if (_currentFolder?.mappedStringFolderId != null) {
      folderId = _currentFolder!.mappedStringFolderId;
    } else {
      for (var p in _folderPath.reversed) {
        if (p.mappedStringFolderId != null) {
          folderId = p.mappedStringFolderId;
          break;
        }
      }
    }

    if (folderId == null) return [];

    final i18nDao = context.read<I18nDao>();
    final List<SystemString> strings = await (i18nDao.select(i18nDao.db.strings)
          ..where((s) => s.parentId.equals(folderId!)))
        .get();

    final List<MapEntry<SystemString, String>> results = [];
    for (var s in strings) {
      final enTrans = await i18nDao.getTranslationById(s.id, 'en');
      final cleanFallback = s.key.contains('___')
          ? s.key.substring(0, s.key.lastIndexOf('___'))
          : s.key;
      results.add(MapEntry(s, enTrans ?? cleanFallback));
    }
    results.sort((a, b) => a.value.compareTo(b.value));
    return results;
  }
}

List<SystemString> _filterStringsByRoot(
    List<SystemString> sourceTags, int? rootId) {
  if (rootId == null) return sourceTags;
  Set<int> validIds = {};
  List<int> q = [rootId];
  while (q.isNotEmpty) {
    int curr = q.removeLast();
    for (var t in sourceTags) {
      if (t.parentId == curr && !validIds.contains(t.id)) {
        validIds.add(t.id);
        if (t.type == 'FOLDER') q.add(t.id);
      }
    }
  }
  return sourceTags.where((t) => validIds.contains(t.id)).toList();
}

class _AssetTagsEditor extends StatefulWidget {
  final Asset asset;
  const _AssetTagsEditor({required this.asset});

  @override
  State<_AssetTagsEditor> createState() => _AssetTagsEditorState();
}

class _AssetTagsEditorState extends State<_AssetTagsEditor> {
  List<SystemString> _allTags = [];
  Map<int, String> _resolvedNames = {};
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final i18n = context.read<I18nDao>();
    final prefs = await SharedPreferences.getInstance();

    final tagsRaw = await i18n.watchAllStrings().first;
    final tagsStrId = prefs.getString('project_tags_folder_id');
    final tagsRootId = tagsStrId != null ? int.tryParse(tagsStrId) : null;
    final tags = _filterStringsByRoot(tagsRaw, tagsRootId);

    final Map<int, String> names = {};

    for (var t in tags) {
      final trans = await i18n.getTranslationById(t.id, 'en');
      names[t.id] = (trans ??
          (t.key.contains('___')
              ? t.key.substring(0, t.key.lastIndexOf('___'))
              : t.key));
    }

    if (mounted) {
      setState(() {
        _allTags = tags;
        _resolvedNames = names;
        _isExpanded = prefs.getBool('tags_editor_expanded') ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTag(int tagId, bool selected) async {
    final dao = context.read<AssetTagsDao>();
    final activeTags = await dao.watchStringsForAsset(widget.asset.id).first;
    final items = activeTags.map((t) => t.id).toSet();

    if (selected) {
      items.add(tagId);
    } else {
      items.remove(tagId);
    }

    await dao.replaceStringsForAsset(widget.asset.id, items.toList());

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('asset_tags')
          .delete()
          .eq('asset_id', widget.asset.id);
      if (items.isNotEmpty) {
        await supabase.from('asset_tags').insert(items
            .map((tid) => {'asset_id': widget.asset.id, 'string_id': tid})
            .toList());
      }
    } catch (e) {
      debugPrint('Supabase tag sync fail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
          padding: EdgeInsets.all(16), child: CircularProgressIndicator());
    }

    final folders = _allTags.where((t) => t.type == 'FOLDER').toList();
    folders.sort((a, b) {
      final cmp = (a.sortOrder).compareTo(b.sortOrder);
      return cmp == 0 ? a.key.compareTo(b.key) : cmp;
    });
    final orphans = _allTags
        .where((t) => t.type != 'FOLDER' && t.parentId == null)
        .toList();
    orphans.sort((a, b) {
      final cmp = (a.sortOrder).compareTo(b.sortOrder);
      return cmp == 0 ? a.key.compareTo(b.key) : cmp;
    });

    return StreamBuilder<List<SystemString>>(
        stream:
            context.read<AssetTagsDao>().watchStringsForAsset(widget.asset.id),
        builder: (context, snapshot) {
          final activeIds = (snapshot.data ?? []).map((t) => t.id).toSet();

          return ExpansionTile(
              title: Text('Manage Assigned Tags (${activeIds.length})',
                  style: const TextStyle(
                      color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              collapsedIconColor: Colors.amberAccent,
              iconColor: Colors.amberAccent,
              initiallyExpanded: _isExpanded,
              onExpansionChanged: (val) async {
                setState(() => _isExpanded = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('tags_editor_expanded', val);
              },
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              childrenPadding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...folders.map((folder) {
                  Color parsedColor(SystemString s) {
                     if (s.color != null && s.color!.isNotEmpty) {
                        try {
                           String hex = s.color!.replaceAll('#', '');
                           if (hex.length == 6) hex = 'FF$hex';
                           return Color(int.parse(hex, radix: 16));
                        } catch (_) {}
                     }
                     return Colors.amberAccent;
                  }
                  
                  final folderColor = parsedColor(folder);
                  final children = _allTags
                      .where(
                          (t) => t.type != 'FOLDER' && t.parentId == folder.id)
                      .toList();
                  children.sort((a, b) {
                    final cmp = (a.sortOrder).compareTo(b.sortOrder);
                    return cmp == 0 ? a.key.compareTo(b.key) : cmp;
                  });
                  if (children.isEmpty) return const SizedBox.shrink();

                  return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(children: [
                                  Icon(Icons.folder,
                                      color: folderColor, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                      (_resolvedNames[folder.id] ?? folder.key)
                                          .toUpperCase(),
                                      style: TextStyle(
                                          color: folderColor,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1)),
                                ])),
                            Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: children.map((t) {
                                  final isSelected = activeIds.contains(t.id);
                                  Color parsedColor(SystemString s) {
                                     if (s.color != null && s.color!.isNotEmpty) {
                                        try {
                                           String hex = s.color!.replaceAll('#', '');
                                           if (hex.length == 6) hex = 'FF$hex';
                                           return Color(int.parse(hex, radix: 16));
                                        } catch (_) {}
                                     }
                                     return folderColor;
                                  }
                                  final color = parsedColor(t);
                                  final baseBg = Theme.of(context).scaffoldBackgroundColor;
                                  final unselectedBg = Color.lerp(color, baseBg, 0.85)!;
                                  final activeBg = isSelected ? color : unselectedBg;
                                  final textColor = activeBg.computeLuminance() > 0.45 ? Colors.black87 : AppColors.panelTextPrimary;

                                  return ChoiceChip(
                                      label: Text(_resolvedNames[t.id] ?? t.key, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                      selected: isSelected,
                                      selectedColor: color,
                                      backgroundColor: unselectedBg,
                                      side: BorderSide(color: isSelected ? color : Color.lerp(color, baseBg, 0.7)!),
                                      checkmarkColor: textColor,
                                      showCheckmark: false,
                                      onSelected: (val) => _toggleTag(t.id, val));
                                }).toList())
                          ]));
                }),
                if (orphans.isNotEmpty)
                  Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text('UNGROUPED / OTHER',
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1)),
                            ),
                            Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: orphans.map((t) {
                                  final isSelected = activeIds.contains(t.id);
                                  Color parsedColor(SystemString s) {
                                     if (s.color != null && s.color!.isNotEmpty) {
                                        try {
                                           String hex = s.color!.replaceAll('#', '');
                                           if (hex.length == 6) hex = 'FF$hex';
                                           return Color(int.parse(hex, radix: 16));
                                        } catch (_) {}
                                     }
                                     return AppColors.panelTextSecondary;
                                  }
                                  final color = parsedColor(t);
                                  final baseBg = Theme.of(context).scaffoldBackgroundColor;
                                  final unselectedBg = Color.lerp(color, baseBg, 0.85)!;
                                  final activeBg = isSelected ? color : unselectedBg;
                                  final textColor = activeBg.computeLuminance() > 0.45 ? Colors.black87 : AppColors.panelTextPrimary;

                                  return ChoiceChip(
                                      label: Text(_resolvedNames[t.id] ?? t.key, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                      selected: isSelected,
                                      selectedColor: color,
                                      backgroundColor: unselectedBg,
                                      side: BorderSide(color: isSelected ? color : Color.lerp(color, baseBg, 0.7)!),
                                      checkmarkColor: textColor,
                                      showCheckmark: false,
                                      onSelected: (val) => _toggleTag(t.id, val));
                                }).toList())
                          ]))
              ]);
        });
  }
}

class _AlternateVersionsEditor extends StatefulWidget {
  final Asset asset;
  final Function(Asset?) onNavigate;
  final Future<Asset?> Function(BuildContext context, {bool foldersOnly}) showSearchPicker;
  final Function(Asset) onAssetUpdate;

  const _AlternateVersionsEditor({
    Key? key,
    required this.asset,
    required this.onNavigate,
    required this.showSearchPicker,
    required this.onAssetUpdate,
  }) : super(key: key);

  @override
  State<_AlternateVersionsEditor> createState() => _AlternateVersionsEditorState();
}

class _AlternateVersionsEditorState extends State<_AlternateVersionsEditor> {
  List<Asset> _linkedAssets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  @override
  void didUpdateWidget(covariant _AlternateVersionsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.alternateVersionIds != widget.asset.alternateVersionIds) {
      _loadLinks();
    }
  }

  Future<void> _loadLinks() async {
    final idsText = widget.asset.alternateVersionIds ?? '';
    final idStrings = idsText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (idStrings.isEmpty) {
      if (mounted) setState(() { _linkedAssets = []; _isLoading = false; });
      return;
    }
    
    final dao = context.read<AssetsDao>();
    List<Asset> loaded = [];
    for (String idStr in idStrings) {
      final id = int.tryParse(idStr);
      if (id != null) {
        final a = await dao.getAssetById(id);
        if (a != null) loaded.add(a);
      }
    }
    
    if (mounted) {
      setState(() {
        _linkedAssets = loaded;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _removeLink(Asset linkedAsset) async {
     try {
       List<String> current = (widget.asset.alternateVersionIds ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
       if (!current.contains('${linkedAsset.id}')) return;
       current.remove('${linkedAsset.id}');
       final newVal = current.join(', ');
       final valToSave = newVal.isEmpty ? null : newVal;
       
       await Supabase.instance.client.from('assets').update({'alternate_version_ids': valToSave}).eq('id', widget.asset.id);
       await context.read<AssetsDao>().updateAsset(widget.asset.toCompanion(true).copyWith(alternateVersionIds: drift.Value(valToSave)));
       widget.onAssetUpdate(widget.asset.copyWith(alternateVersionIds: drift.Value(valToSave)));
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unlinked ${linkedAsset.name}'), backgroundColor: Colors.orange));
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unlink: $e'), backgroundColor: Colors.red));
     }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
            clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: AppColors.controlBorder, width: AppUIConfig.windowBorderWidth) : null,
         color: AppColors.panelBackground,
         borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text('Alternate Track Versions', style: TextStyle(color: Colors.cyanAccent, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
               TextButton.icon(
                  icon: const Icon(Icons.add, color: Colors.cyanAccent, size: 16),
                  label: Text('Add Link', style: TextStyle(color: Colors.cyanAccent)),
                  onPressed: () async {
                     final ast = await widget.showSearchPicker(context, foldersOnly: true);
                     if (ast != null) {
                        try {
                           List<String> current = (widget.asset.alternateVersionIds ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                           if (!current.contains('${ast.id}')) {
                               current.add('${ast.id}');
                           }
                           final newVal = current.join(', ');
                           await Supabase.instance.client.from('assets').update({'alternate_version_ids': newVal}).eq('id', widget.asset.id);
                           await context.read<AssetsDao>().updateAsset(widget.asset.toCompanion(true).copyWith(alternateVersionIds: drift.Value(newVal)));
                           widget.onAssetUpdate(widget.asset.copyWith(alternateVersionIds: drift.Value(newVal)));
                           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Linked ${ast.name}'), backgroundColor: Colors.green));
                        } catch (e) {
                           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to link: $e'), backgroundColor: Colors.red));
                        }
                     }
                  }
               )
             ]
          ),
          const SizedBox(height: 8),
          if (_isLoading)
             Center(child: CircularProgressIndicator())
          else if (_linkedAssets.isEmpty)
             Text('No alternate versions connected.', style: TextStyle(color: AppColors.panelTextSecondary, fontStyle: FontStyle.italic))
          else
             Wrap(
               spacing: 8,
               runSpacing: 8,
               children: _linkedAssets.map((la) {
                  return InputChip(
                     avatar: Icon(la.type == 'FOLDER' ? Icons.folder : Icons.insert_drive_file, color: Colors.amberAccent, size: 16),
                     label: Text(la.name.toUpperCase(), style: TextStyle(color: AppColors.panelTextPrimary)),
                     backgroundColor: AppColors.controlBorder,
                     deleteIconColor: Colors.redAccent,
                     onDeleted: () => _removeLink(la),
                     onPressed: () => widget.onNavigate(la),
                  );
               }).toList()
             )
        ]
      )
    );
  }
}



