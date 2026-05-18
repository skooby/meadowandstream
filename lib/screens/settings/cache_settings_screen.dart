import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../db/app_database.dart';
import '../../db/daos/audio_cache_dao.dart';
import '../../db/daos/assets_dao.dart';
import '../../state/offline_cache_settings_controller.dart';
import '../../services/auto_cache_manager.dart';
import '../../engine/ui_inspector/element_registry.dart';

class CacheSettingsScreen extends StatefulWidget {
  const CacheSettingsScreen({super.key});

  @override
  State<CacheSettingsScreen> createState() => _CacheSettingsScreenState();
}

class _CacheSettingsScreenState extends State<CacheSettingsScreen> {
  int _usedBytes = 0;
  List<AudioCacheEntry> _cachedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    if (!mounted) return;
    final audioCacheDao = context.read<AudioCacheDao>();
    _usedBytes = await audioCacheDao.totalCachedBytes();

    final allEntries = await audioCacheDao.getAllEntries();
    _cachedItems = allEntries.where((e) => e.status == 3).toList();

    // Sort by score descending
    _cachedItems.sort((a, b) => b.cacheScore.compareTo(a.cacheScore));

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeItem(AudioCacheEntry entry) async {
    final audioCacheDao = context.read<AudioCacheDao>();

    if (entry.localPath != null) {
      final file = File(entry.localPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await audioCacheDao.remove(entry.itemId);
    _loadData();
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: Text('Delete ${_formatBytes(_usedBytes)} of cached audio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final audioCacheDao = context.read<AudioCacheDao>();
    for (final entry in _cachedItems) {
      if (entry.localPath != null) {
        final file = File(entry.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await audioCacheDao.remove(entry.itemId);
    }
    _loadData();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<OfflineCacheSettingsController>();
    final maxBytes = settings.audioCacheMaxBytes;

    final usedFraction =
        maxBytes > 0 ? (_usedBytes / maxBytes).clamp(0.0, 1.0) : 0.0;

    return ActiveScreenScope(
      screenName: 'Settings',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Playback & Display',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      RegisteredElement(
                        id: 'settings_config_lyrics_mode',
                        meta: const {'type': 'Button'},
                        child: ListTile(
                          dense: true,
                          title: const Text('Lyrics Display Mode'),
                          subtitle: const Text(
                              'Choose how many lines to show in full screen'),
                          trailing: DropdownButton<int>(
                            value: settings.lyricsLineMode,
                            isDense: true,
                            onChanged: (int? newValue) {
                              if (newValue != null) {
                                settings.setLyricsLineMode(newValue);
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 Line')),
                              DropdownMenuItem(value: 3, child: Text('3 Lines')),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 32),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          'Offline Cache',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      RegisteredElement(
                        id: 'settings_config_auto_cache',
                        meta: const {'type': 'Button'},
                        child: SwitchListTile(
                          dense: true,
                          title: const Text('Automatic offline cache'),
                          subtitle: const Text(
                              'Download items for offline playback in the background'),
                          value: settings.autoCacheEnabled,
                          onChanged: (val) {
                            settings.setAutoCacheEnabled(val);
                            if (val) {
                              context.read<AutoCacheManager>().start();
                            } else {
                              context.read<AutoCacheManager>().stop();
                            }
                          },
                        ),
                      ),
                      RegisteredElement(
                        id: 'settings_config_max_cache',
                        meta: const {'type': 'Button'},
                        child: ListTile(
                          dense: true,
                          title: const Text('Cache size limit'),
                          subtitle: const Text(
                              'Maximum storage used for downloaded audio'),
                          trailing: DropdownButton<int>(
                            value: maxBytes,
                            isDense: true,
                            onChanged: (int? newValue) {
                              if (newValue != null) {
                                settings.setAudioCacheMaxBytes(newValue);
                                context.read<AutoCacheManager>().scheduleSoon();
                              }
                            },
                            items: const [
                              DropdownMenuItem(
                                  value: 536870912, child: Text('500 MB')),
                              DropdownMenuItem(
                                  value: 1073741824, child: Text('1 GB')),
                              DropdownMenuItem(
                                  value: 2147483648, child: Text('2 GB')),
                              DropdownMenuItem(
                                  value: 5368709120, child: Text('5 GB')),
                            ],
                          ),
                        ),
                      ),
                      RegisteredElement(
                        id: 'settings_config_wifi_only',
                        meta: const {'type': 'Button'},
                        child: SwitchListTile(
                          dense: true,
                          title: const Text('Wi-Fi only'),
                          subtitle: const Text(
                              'Pause automatic downloads on cellular data'),
                          value: settings.autoCacheWifiOnly,
                          onChanged: (val) {
                            settings.setAutoCacheWifiOnly(val);
                            context.read<AutoCacheManager>().scheduleSoon();
                          },
                        ),
                      ),
                      RegisteredElement(
                        id: 'settings_btn_clear_cache',
                        meta: const {'type': 'Button'},
                        child: ListTile(
                            dense: true,
                            title: const Text('Clear cached audio',
                                style: TextStyle(color: Colors.red)),
                            leading:
                                const Icon(Icons.delete_sweep, color: Colors.red),
                            onTap: () {
                              _clearCache();
                            }),
                      ),
                      const Divider(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Storage Used',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: usedFraction,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              color: usedFraction > 0.9
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_formatBytes(_usedBytes)} used',
                                    style: theme.textTheme.bodySmall),
                                Text('${_formatBytes(maxBytes)} limit',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Text(
                              'Cached Items (${_cachedItems.length})',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _cachedItems.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(child: Text('No items cached offline.')))
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry = _cachedItems[index];

                            final parsedId = int.tryParse(entry.itemId);
                            return FutureBuilder<Asset?>(
                              future: parsedId != null ? context
                                  .read<AssetsDao>()
                                  .getAssetById(parsedId) : Future.value(null),
                              builder: (context, snapshot) {
                                final title =
                                    snapshot.data?.name ?? 'Unknown Item';
                                const artist = 'Unknown Artist';

                                return ListTile(
                                  dense: true,
                                  title: Text(title),
                                  subtitle: Text(
                                      '$artist • ${_formatBytes(entry.fileBytes ?? 0)} • Score: ${entry.cacheScore.toStringAsFixed(0)}'),
                                  trailing: IconButton(
                                    icon:
                                        const Icon(Icons.remove_circle_outline),
                                    onPressed: () => _removeItem(entry),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: _cachedItems.length,
                        ),
                      ),
              ],
            ),
      ),
    );
  }
}
