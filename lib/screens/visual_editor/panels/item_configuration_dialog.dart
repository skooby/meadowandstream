import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../db/daos/i18n_dao.dart';
import '../../../db/app_database.dart';
import '../../../constants.dart';

class ItemConfigurationDialog extends StatefulWidget {
  final String? activeCollectionFilter;
  final String activeCollectionName;
  const ItemConfigurationDialog({super.key, this.activeCollectionFilter, this.activeCollectionName = 'Global'});

  @override
  State<ItemConfigurationDialog> createState() => _ItemConfigurationDialogState();
}
class _ItemConfigurationDialogState extends State<ItemConfigurationDialog> {

  int? _selectedStringFolderId;
  late Stream<List<SystemString>> _foldersStream;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _foldersStream = context.read<I18nDao>().watchAllStringFolders();
  }

  String get _prefsKey {
    if (widget.activeCollectionFilter != null) {
      return 'item_title_folder_id_${widget.activeCollectionFilter}';
    }
    return 'global_item_title_folder_id';
  }

  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedStringFolderId = prefs.getInt(_prefsKey);
      });
    }
  }

  void _saveConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selectedStringFolderId != null) {
        await prefs.setInt(_prefsKey, _selectedStringFolderId!);
      } else {
        await prefs.remove(_prefsKey);
      }

      if (mounted) {
        Navigator.of(context).pop(_selectedStringFolderId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save config: $e')));
      }
    }
  }


  


  List<Map<String, dynamic>> _buildHierarchy(List<SystemString> allFolders) {
      List<SystemString> roots = allFolders.where((f) => f.parentId == null || !allFolders.any((a) => a.id == f.parentId)).toList();
      roots.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
      
      List<Map<String, dynamic>> result = [];
      
      void traverse(SystemString node, int depth) {
           result.add({ 'folder': node, 'depth': depth });
           final children = allFolders.where((f) => f.parentId == node.id).toList();
           children.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
           for (var child in children) {
               traverse(child, depth + 1);
           }
      }
      
      for (var root in roots) {
          traverse(root, 0);
      }
      
      return result;
  }
  @override
  Widget build(BuildContext context) {

    return AlertDialog(
      backgroundColor: AppColors.panelBackground,
      title: Text('Configure Items: ${widget.activeCollectionName}', style: TextStyle(color: AppColors.panelTextPrimary)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify which String Folder should populate the standard Title Dropdown for Items currently strictly filtered to [${widget.activeCollectionName}].',
              style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize),
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<SystemString>>(
              stream: _foldersStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final folders = snapshot.data!;

                return DropdownButtonFormField<int?>(
                  decoration: InputDecoration(
                    labelText: 'Target String Folder map',
                    labelStyle: TextStyle(color: AppColors.accent),
                    filled: true,
                    fillColor: AppColors.windowBackground,
                    border: OutlineInputBorder(),
                  ),
                  dropdownColor: AppColors.controlBorder,
                  initialValue: _selectedStringFolderId,
                  selectedItemBuilder: (BuildContext context) {
                    return [
                      Text('Unrestricted (Auto-generate/Manual Entry)', style: TextStyle(color: AppColors.panelTextSecondary)),
                      ..._buildHierarchy(folders).map((node) {
                          final f = node['folder'] as SystemString;
                          return FutureBuilder<String?>(
                             future: context.read<I18nDao>().getTranslationById(f.id, 'en'),
                             builder: (context, strSnap) => Text(strSnap.data ?? f.key, style: TextStyle(color: AppColors.panelTextPrimary))
                          );
                      })
                    ];
                  },
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Unrestricted (Auto-generate/Manual Entry)', style: TextStyle(color: AppColors.panelTextSecondary)),
                    ),
                    ..._buildHierarchy(folders).map((node) {
                          final f = node['folder'] as SystemString;
                          final depth = node['depth'] as int;
                          return DropdownMenuItem<int>(
                            value: f.id,
                            child: Padding(
                               padding: EdgeInsets.only(left: depth * 16.0),
                               child: FutureBuilder<String?>(
                                  future: context.read<I18nDao>().getTranslationById(f.id, 'en'),
                                  builder: (context, strSnap) => Text(strSnap.data ?? f.key, style: TextStyle(color: AppColors.panelTextPrimary))
                               ),
                            ),
                          );
                        })
                   ],
                  onChanged: (val) {
                    setState(() {
                      _selectedStringFolderId = val;
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: AppColors.panelTextSecondary)),
        ),
        ElevatedButton(
          onPressed: _saveConfiguration,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          child: Text('Save Target Context', style: TextStyle(color: AppColors.panelTextPrimary)),
        )
      ],
    );
  }
}



