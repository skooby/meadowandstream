import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../choreography/choreography_engine.dart';

class EditorStateController extends ChangeNotifier {
  ChoreographyConfig? config;
  String? currentFilePath;
  String? selectedLayerId; 
  String? selectedPropertyKey;
  
  String loadedTargetType = 'item';
  String loadedTargetName = 'The Bionic Man';
  String? localMirrorPath;

  final List<String> _history = [];
  int _historyIndex = -1;
  Timer? _debounceUploadTimer;
  
  bool _hasUnsavedCloudChanges = false;
  bool get hasUnsavedCloudChanges => _hasUnsavedCloudChanges;
  
  bool _isUploadingToCloud = false;
  bool get isUploadingToCloud => _isUploadingToCloud;
  void loadConfig(String path, ChoreographyConfig loadedConfig, {String targetType = 'item', String targetName = 'The Bionic Man', String? localPath}) {
    currentFilePath = path;
    localMirrorPath = localPath;
    config = loadedConfig;
    loadedTargetType = targetType;
    loadedTargetName = targetName;
    selectedLayerId = null;
    _history.clear();
    _historyIndex = -1;
    pushHistoryState();
    notifyListeners();
    _saveSessionBookmark();
  }

  Future<void> _saveSessionBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ve_last_opened_path', currentFilePath!);
    await prefs.setString('ve_last_opened_type', loadedTargetType);
    await prefs.setString('ve_last_opened_name', loadedTargetName);
    if (localMirrorPath != null) {
      await prefs.setString('ve_last_opened_mirror', localMirrorPath!);
    } else {
      await prefs.remove('ve_last_opened_mirror');
    }
  }

  Future<bool> tryRestoreLastSession() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastPath = prefs.getString('ve_last_opened_path');
    final String? lastType = prefs.getString('ve_last_opened_type');
    final String? lastName = prefs.getString('ve_last_opened_name');

    if (lastPath == null || lastType == null) return false;

    try {
      String jsonStr;
      if (lastType == 'asset') {
         final bytes = await Supabase.instance.client.storage.from('tenant-assets').download(lastPath);
         jsonStr = utf8.decode(bytes);
      } else {
         final file = File(lastPath);
         if (!await file.exists()) return false;
         jsonStr = await file.readAsString();
      }

      final configObj = ChoreographyConfig.fromJson(jsonDecode(jsonStr));
      final String? mirror = prefs.getString('ve_last_opened_mirror');
      loadConfig(lastPath, configObj, targetType: lastType, targetName: lastName ?? lastPath.split('/').last, localPath: mirror);
      return true;
    } catch (e) {
      debugPrint("Failed to restore previous editor session natively: $e");
      return false;
    }
  }

  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  void undo() {
    if (canUndo) {
      _historyIndex--;
      _restoreState(_history[_historyIndex]);
    }
  }

  void redo() {
    if (canRedo) {
      _historyIndex++;
      _restoreState(_history[_historyIndex]);
    }
  }

  void _restoreState(String serialized) {
    if (currentFilePath == null) return;
    config = ChoreographyConfig.fromJson(jsonDecode(serialized));
    notifyListeners();
  }

  void pushHistoryState() {
    if (config == null) return;
    final serialized = jsonEncode(config!.toJson());
    
    // Truncate future history if we're branching from the past
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    
    // Avoid double saves
    if (_history.isNotEmpty && _history.last == serialized) return;

    _history.add(serialized);
    if (_history.length > 50) { // Keep last 50 actions to save memory
      _history.removeAt(0);
    } else {
      _historyIndex++;
    }
    
    saveToDisk(); // Auto-commit to disk immediately
  }
  
  void selectLayer(String? id) {
    if (selectedLayerId != id) {
      selectedLayerId = id;
      selectedPropertyKey = null;
      notifyListeners();
    }
  }

  void selectProperty(String? key) {
    if (selectedPropertyKey != key) {
      selectedPropertyKey = key;
      notifyListeners();
    }
  }

  void updateItemValue({
    required String? layerId, // null for global items
    required String varName,
    required dynamic value,
    required String dataType,
    required int timeMs,
  }) {
    if (config == null) return;
    
    // Find or create item
    Map<String, PropertyItem> items;
    if (layerId == null) {
      items = config!.globalItems;
    } else {
      if (!config!.layers.containsKey(layerId)) return;
      items = config!.layers[layerId]!.items;
    }

    if (!items.containsKey(varName)) {
      items[varName] = PropertyItem(
        propertyName: varName,
        dataType: dataType,
        keyframes: [],
      );
    }

    final item = items[varName]!;
    
    // Exact match mutation or newly inserted keyframe
    int existingIndex = item.keyframes.indexWhere((k) => k.timeMs == timeMs);
    if (existingIndex >= 0) {
      item.keyframes[existingIndex] = TimelineKeyframe(
        timeMs: timeMs,
        value: value,
        easing: item.keyframes[existingIndex].easing,
      );
    } else {
      item.keyframes.add(TimelineKeyframe(
        timeMs: timeMs,
        value: value,
      ));
      item.keyframes.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    }
    
    notifyListeners();
  }

  void deleteKeyframe({
    required String? layerId,
    required String varName,
    required int timeMs,
  }) {
    if (config == null) return;
    
    Map<String, PropertyItem> items;
    if (layerId == null) {
      items = config!.globalItems;
    } else {
      if (!config!.layers.containsKey(layerId)) return;
      items = config!.layers[layerId]!.items;
    }

    if (!items.containsKey(varName)) return;

    items[varName]!.keyframes.removeWhere((k) => k.timeMs == timeMs);
    notifyListeners();
  }

  void _injectItem(Map<String, PropertyItem> items, String name, String type, dynamic val) {
    items[name] = PropertyItem(
      propertyName: name,
      dataType: type,
      keyframes: [TimelineKeyframe(timeMs: 0, value: val)],
    );
  }

  void toggleLayerActive(String layerId, bool active) {
    if (config == null || !config!.layers.containsKey(layerId)) return;
    final old = config!.layers[layerId]!;
    config!.layers[layerId] = LayerElement(
      targetId: old.targetId,
      type: old.type,
      path: old.path,
      active: active,
      blendMode: old.blendMode,
      items: old.items,
      parentId: old.parentId,
      isExpanded: old.isExpanded,
    );
    notifyListeners();
  }

  void addLayer() {
    if (config == null) return;
    int index = 1;
    while(config!.layers.containsKey('NEW_LAYER_$index')) {
      index++;
    }
    String id = 'NEW_LAYER_$index';
    
    Map<String, PropertyItem> initialItems = {};
    _injectItem(initialItems, 'LAYER_OPACITY', 'NUMBER', 1.0);
    _injectItem(initialItems, 'ACTIVE', 'BOOLEAN', true);
    _injectItem(initialItems, 'LAYER_POS_X', 'NUMBER', 0.0);
    _injectItem(initialItems, 'LAYER_POS_Y', 'NUMBER', 0.0);
    _injectItem(initialItems, 'LAYER_SCALE_X', 'NUMBER', 1.0);
    _injectItem(initialItems, 'LAYER_SCALE_Y', 'NUMBER', 1.0);
    _injectItem(initialItems, 'LAYER_ROTATION', 'NUMBER', 0.0);
    _injectItem(initialItems, 'LAYER_ANCHOR_X', 'NUMBER', 0.0);
    _injectItem(initialItems, 'LAYER_ANCHOR_Y', 'NUMBER', 0.0);
    
    config!.layers[id] = LayerElement(
      targetId: id,
      type: 'IMAGE',
      items: initialItems,
    );
    selectedLayerId = id;
    notifyListeners();
  }

  void addFolder() {
    if (config == null) return;
    int index = 1;
    while(config!.layers.containsKey('FOLDER_$index')) {
      index++;
    }
    String id = 'FOLDER_$index';
    
    Map<String, PropertyItem> initialItems = {};
    _injectItem(initialItems, 'ACTIVE', 'BOOLEAN', true);
    _injectItem(initialItems, 'LAYER_POS_X', 'NUMBER', 0.0);
    _injectItem(initialItems, 'LAYER_POS_Y', 'NUMBER', 0.0);
    _injectItem(initialItems, 'LAYER_SCALE_X', 'NUMBER', 1.0);
    _injectItem(initialItems, 'LAYER_SCALE_Y', 'NUMBER', 1.0);
    _injectItem(initialItems, 'LAYER_ROTATION', 'NUMBER', 0.0);
    _injectItem(initialItems, 'LAYER_ANCHOR_X', 'NUMBER', 0.0);
    _injectItem(initialItems, 'LAYER_ANCHOR_Y', 'NUMBER', 0.0);

    config!.layers[id] = LayerElement(
      targetId: id,
      type: 'FOLDER',
      items: initialItems,
    );
    selectedLayerId = id;
    notifyListeners();
  }

  void toggleFolderExpanded(String layerId) {
    if (config == null || !config!.layers.containsKey(layerId)) return;
    config!.layers[layerId]!.isExpanded = !config!.layers[layerId]!.isExpanded;
    notifyListeners();
  }

  void deleteLayer(String layerId) {
    if (config == null) return;
    config!.layers.remove(layerId);
    if (selectedLayerId == layerId) selectedLayerId = null;
    notifyListeners();
  }

  void reorderLayer(int oldIndex, int newIndex) {
    if (config == null) return;
    if (oldIndex < newIndex) newIndex -= 1;
    
    final entries = config!.layers.entries.toList();
    final item = entries.removeAt(oldIndex);
    entries.insert(newIndex, item);
    
    config!.layers.clear();
    config!.layers.addEntries(entries);
    notifyListeners();
  }

  void dropLayerAbsoluteTop(String draggingId) {
    if (config == null) return;
    
    final entries = config!.layers.entries.toList();
    int oldMapIndex = entries.indexWhere((e) => e.key == draggingId);
    if (oldMapIndex == -1) return;
    
    LayerElement draggedLayer = config!.layers[draggingId]!;
    draggedLayer.parentId = null; // Absolute root!
    
    final item = entries.removeAt(oldMapIndex);
    entries.insert(0, item); // Inject functionally securely exactly at absolute global 0 natively
    
    config!.layers.clear();
    config!.layers.addEntries(entries);
    notifyListeners();
  }

  void dropLayerBefore(String draggingId, String targetId) {
    if (config == null || draggingId == targetId) return;

    final entries = config!.layers.entries.toList();
    int oldMapIndex = entries.indexWhere((e) => e.key == draggingId);
    int targetMapIndex = entries.indexWhere((e) => e.key == targetId);
    if (oldMapIndex == -1 || targetMapIndex == -1) return;

    LayerElement targetLayer = config!.layers[targetId]!;
    LayerElement draggedLayer = config!.layers[draggingId]!;

    // Inherit the exact parent properties natively preventing cyclical overrides
    String? newParentId = targetLayer.parentId;
    
    // Cycle Guard
    bool isCycle(String layerId, String? parent) {
       String? current = parent;
       while(current != null) {
          if (current == layerId) return true;
          current = config!.layers[current]?.parentId;
       }
       return false;
    }

    if (isCycle(draggingId, newParentId)) return;
    
    draggedLayer.parentId = newParentId;

    final item = entries.removeAt(oldMapIndex);
    targetMapIndex = entries.indexWhere((e) => e.key == targetId);
    
    // Place strictly before the matched target mapping structural dependencies accurately natively
    entries.insert(targetMapIndex, item);

    config!.layers.clear();
    config!.layers.addEntries(entries);
    notifyListeners();
  }

  void dropLayer(String draggingId, String targetId) {
    if (config == null || draggingId == targetId) return;

    final entries = config!.layers.entries.toList();
    int oldMapIndex = entries.indexWhere((e) => e.key == draggingId);
    int targetMapIndex = entries.indexWhere((e) => e.key == targetId);
    if (oldMapIndex == -1 || targetMapIndex == -1) return;

    LayerElement targetLayer = config!.layers[targetId]!;
    LayerElement draggedLayer = config!.layers[draggingId]!;

    String? newParentId;
    if (targetLayer.type == 'FOLDER') {
       newParentId = targetId;
    } else {
       newParentId = targetLayer.parentId;
    }

    // Cycle Detection Guard!
    bool isCycle(String layerId, String? parent) {
       String? current = parent;
       while(current != null) {
          if (current == layerId) return true;
          current = config!.layers[current]?.parentId;
       }
       return false;
    }

    if (isCycle(draggingId, newParentId)) {
        return; // Completely reject structurally breaking drags automatically
    }

    draggedLayer.parentId = newParentId;

    final item = entries.removeAt(oldMapIndex);
    
    // Recalculate target post-removal
    targetMapIndex = entries.indexWhere((e) => e.key == targetId);
    
    // Place it exactly after the target securely!
    entries.insert(targetMapIndex + 1, item);
    
    config!.layers.clear();
    config!.layers.addEntries(entries);
    
    // Expand the folder automatically if we dropped onto one
    if (targetLayer.type == 'FOLDER' && !targetLayer.isExpanded) {
        targetLayer.isExpanded = true;
    }
    
    notifyListeners();
  }

  void updateLayerProperties({
    required String layerId,
    String? newType,
    String? newPath,
    String? newId,
    String? newBlendMode,
    String? newParentId,
    bool clearParent = false,
    String? newPlatform,
    String? newOrientation,
    bool clearPlatform = false,
    bool clearOrientation = false,
    String? newScript,
  }) {
    if (config == null || !config!.layers.containsKey(layerId)) return;
    final old = config!.layers[layerId]!;
    
    Map<String, PropertyItem> newItems = old.items;

    if (newPath != null && newPath != old.path) {
      newItems = Map.from(old.items);
      
      final preservedKeys = ['LAYER_OPACITY'];
      final preserved = { for (var k in preservedKeys) if (newItems.containsKey(k)) k: newItems[k]! };
      
      newItems.clear();
      newItems.addAll(preserved);
      
      if (!newItems.containsKey('LAYER_OPACITY')) _injectItem(newItems, 'LAYER_OPACITY', 'NUMBER', 1.0);
      
      if (newPath.contains('bg_gradient')) {
        _injectItem(newItems, 'SPEED', 'NUMBER', 0.1);
        _injectItem(newItems, 'ZOOM', 'NUMBER', 1.0);
        _injectItem(newItems, 'SHIFT_SPEED', 'NUMBER', 0.5);
        _injectItem(newItems, 'WAVE_INTENSITY', 'NUMBER', 0.5);
        _injectItem(newItems, 'BASE_COLOR', 'COLOR', const Color(0xFF000000));
        _injectItem(newItems, 'ACCENT_COLOR', 'COLOR', const Color(0xFF222222));
      } else if (newPath.contains('audio_ring')) {
        _injectItem(newItems, 'RADIUS', 'NUMBER', 0.5);
        _injectItem(newItems, 'THICKNESS', 'NUMBER', 0.1);
        _injectItem(newItems, 'ROT_SPEED', 'NUMBER', 1.0);
        _injectItem(newItems, 'PULSE_STRENGTH', 'NUMBER', 1.0);
        _injectItem(newItems, 'RING_COLOR', 'COLOR', const Color(0xFFFFFFFF));
        _injectItem(newItems, 'GLOW_COLOR', 'COLOR', const Color(0x00000000));
      } else if (newPath.contains('fire')) {
        _injectItem(newItems, 'BURN_SPEED', 'NUMBER', 1.0);
        _injectItem(newItems, 'INTENSITY', 'NUMBER', 1.0);
        _injectItem(newItems, 'HEAT', 'NUMBER', 1.0);
        _injectItem(newItems, 'FLAME_BOUNCE', 'NUMBER', 1.0);
        _injectItem(newItems, 'CORE_COLOR', 'COLOR', const Color(0xAAFFFFFF));
        _injectItem(newItems, 'EDGE_COLOR', 'COLOR', const Color(0xFFFF0000));
      } else if (newPath.contains('vignette')) {
        _injectItem(newItems, 'INTENSITY', 'NUMBER', 15.0);
        _injectItem(newItems, 'SPREAD', 'NUMBER', 0.35);
        _injectItem(newItems, 'VIGNETTE_COLOR', 'COLOR', const Color(0xFF000000));
      } else if (newPath.contains('bg_kaleidoscope')) {
        _injectItem(newItems, 'SPEED', 'NUMBER', 0.2);
        _injectItem(newItems, 'COMPLEXITY', 'NUMBER', 3.0);
        _injectItem(newItems, 'ZOOM', 'NUMBER', 1.0);
        _injectItem(newItems, 'STRANDS', 'NUMBER', 6.0);
        _injectItem(newItems, 'AUDIO_REACTIVE', 'NUMBER', 1.0);
        _injectItem(newItems, 'BASE_COLOR', 'COLOR', const Color(0xFF660000));
        _injectItem(newItems, 'ACCENT_COLOR', 'COLOR', const Color(0xAA0000FF));
      } else if (newPath.contains('cool_ocean_wave')) {
        _injectItem(newItems, 'WAVE_SPEED', 'NUMBER', 1.0);
        _injectItem(newItems, 'WAVE_HEIGHT', 'NUMBER', 0.2);
        _injectItem(newItems, 'TIDE', 'NUMBER', 0.5);
        _injectItem(newItems, 'SHORE_COLOR', 'COLOR', const Color(0xFF00FFFF));
        _injectItem(newItems, 'DEEP_COLOR', 'COLOR', const Color(0xFF000033));
      } else if (newPath == 'CLOUDS') {
        _injectItem(newItems, 'SPEED', 'NUMBER', 1.0);
        _injectItem(newItems, 'FLOW', 'NUMBER', 0.1);
        _injectItem(newItems, 'DENSITY', 'NUMBER', 1.0);
        _injectItem(newItems, 'NOISE', 'NUMBER', 0.35);
        _injectItem(newItems, 'COLOR_1', 'COLOR', const Color(0xFF88AADD));
        _injectItem(newItems, 'COLOR_2', 'COLOR', const Color(0xFFFFFFFF));
      }
    }

    final updated = LayerElement(
      targetId: newId ?? old.targetId,
      type: (newType ?? old.type).toUpperCase(),
      path: newPath ?? old.path,
      active: old.active,
      blendMode: newBlendMode ?? old.blendMode,
      items: newItems,
      parentId: clearParent ? null : (newParentId ?? old.parentId),
      isExpanded: old.isExpanded,
      platform: clearPlatform ? null : (newPlatform ?? old.platform),
      orientation: clearOrientation ? null : (newOrientation ?? old.orientation),
      script: newScript ?? old.script,
    );
    
    config!.layers[layerId] = updated;

    if (newId != null && newId != layerId) {
      config!.layers[newId] = updated;
      config!.layers.remove(layerId);
      if (selectedLayerId == layerId) selectedLayerId = newId;
    }
    
    notifyListeners();
  }

  void moveKeyframe({
    required String? layerId,
    required String varName,
    required int oldTimeMs,
    required int newTimeMs,
  }) {
    if (config == null) return;
    
    Map<String, PropertyItem> items;
    if (layerId == null) {
      items = config!.globalItems;
    } else {
      if (!config!.layers.containsKey(layerId)) return;
      items = config!.layers[layerId]!.items;
    }

    if (!items.containsKey(varName)) return;

    final item = items[varName]!;
    int index = item.keyframes.indexWhere((k) => k.timeMs == oldTimeMs);
    if (index >= 0) {
      if (item.keyframes.any((k) => k.timeMs == newTimeMs && k.timeMs != oldTimeMs)) return;
      
      item.keyframes[index] = TimelineKeyframe(
        timeMs: newTimeMs,
        value: item.keyframes[index].value,
        easing: item.keyframes[index].easing,
      );
      item.keyframes.sort((a, b) => a.timeMs.compareTo(b.timeMs));
      notifyListeners();
    }
  }

  Future<void> saveToDisk() async {
    if (config == null || currentFilePath == null) return;
    try {
      final jsonMap = config!.toJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
      
      // Sync it to the Host PC Clipboard mapping dynamically!
      await Clipboard.setData(ClipboardData(text: jsonString));
      
      // Mirror physical OS boundaries effortlessly silently allowing live-reload tracking logic natively fast offline!
      if (localMirrorPath != null) {
         try {
            final mirrorFile = File(localMirrorPath!);
            if (!await mirrorFile.parent.exists()) await mirrorFile.parent.create(recursive: true);
            await mirrorFile.writeAsString(jsonString);
         } catch(ex) {
            debugPrint("Failed to mirror save locally: $ex");
         }
      }
      
      // If path is a Supabase bucket ID, quietly track that the cloud is technically out of sync locally!
      if (!currentFilePath!.startsWith('C:') && !currentFilePath!.startsWith('/')) {
         if (!_hasUnsavedCloudChanges) {
             _hasUnsavedCloudChanges = true;
             notifyListeners();
         }
         return;
      }

      // Attempt standard write for Native Desktop testing targets
      final file = File(currentFilePath!);
      if (!await file.parent.exists()) await file.parent.create(recursive: true);
      await file.writeAsString(jsonString);
      debugPrint("Saved visual choreography to $currentFilePath");
    } catch (e) {
      debugPrint("Failed to save choreography to local file: $e");
    }
  }

  Future<void> pushToCloud() async {
    if (config == null || currentFilePath == null || currentFilePath!.startsWith('C:') || currentFilePath!.startsWith('/')) return;
    
    _isUploadingToCloud = true;
    notifyListeners();
    
    try {
        final jsonMap = config!.toJson();
        final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
        final bytes = Uint8List.fromList(utf8.encode(jsonString));
        
        await Supabase.instance.client.storage.from('tenant-assets').uploadBinary(
            currentFilePath!,
            bytes,
            fileOptions: const FileOptions(upsert: true)
        );
        
        try {
            await Supabase.instance.client.from('assets').update({
               'size_bytes': bytes.length,
               'updated_at': DateTime.now().toUtc().toIso8601String()
            }).eq('storage_path', currentFilePath!);
        } catch(ex) {
            debugPrint("Failed to update asset metadata: $ex");
        }
        
        debugPrint("Manually synced visual choreography to Supabase Storage.");
        _hasUnsavedCloudChanges = false;
    } catch(e) {
        debugPrint("Failed to upload to Supabase: $e");
    } finally {
        _isUploadingToCloud = false;
        notifyListeners();
    }
  }
}
