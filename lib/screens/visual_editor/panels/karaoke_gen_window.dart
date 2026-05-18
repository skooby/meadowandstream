import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../state/player_controller.dart';
import '../../../state/lyrics_view_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/karaoke_gen_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../constants.dart';

final ValueNotifier<bool> showKaraokeGenWindowNotifier = ValueNotifier(false);

void showKaraokeGenWindow() {
  showKaraokeGenWindowNotifier.value = true;
}

void hideKaraokeGenWindow() {
  showKaraokeGenWindowNotifier.value = false;
}

class KaraokeGenWindow extends StatefulWidget {
  final VoidCallback onClose;

  const KaraokeGenWindow({super.key, required this.onClose});

  @override
  State<KaraokeGenWindow> createState() => _KaraokeGenWindowState();
}
class _KaraokeGenWindowState extends State<KaraokeGenWindow> {
  bool _isLoaded = false;

  double _width = 400;
  double _height = 500;
  Offset _offset = const Offset(200, 200);

  final TextEditingController _audioPathCtrl = TextEditingController();
  final TextEditingController _referencePathCtrl = TextEditingController();
  final TextEditingController _artistCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  bool _enableSeparation = false;
  bool _uploadToCloud = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    
    _audioPathCtrl.addListener(_savePreferences);
    _referencePathCtrl.addListener(_savePreferences);
    _artistCtrl.addListener(_savePreferences);
    _titleCtrl.addListener(_savePreferences);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) {
          final player = context.read<PlayerController>();
          if (player.currentItem != null) {
              if (_audioPathCtrl.text.isEmpty) _audioPathCtrl.text = player.currentItem!.source;
              if (player.currentItem!.title.isNotEmpty && _titleCtrl.text.isEmpty) _titleCtrl.text = player.currentItem!.title;
          }
       }
    });
  }

  @override
  void dispose() {
    _audioPathCtrl.dispose();
    _referencePathCtrl.dispose();
    _artistCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoaded = true;

        _offset = Offset(prefs.getDouble('kg_dx') ?? 200, prefs.getDouble('kg_dy') ?? 200);
        _width = prefs.getDouble('kg_w') ?? 400;
        _height = prefs.getDouble('kg_h') ?? 500;
        
        final savedAudio = prefs.getString('kg_audio');
        if (savedAudio != null) _audioPathCtrl.text = savedAudio;
        final savedRef = prefs.getString('kg_ref');
        if (savedRef != null) _referencePathCtrl.text = savedRef;
        final savedArtist = prefs.getString('kg_artist') ?? 'Meadow + Stream';
        _artistCtrl.text = savedArtist;
        final savedTitle = prefs.getString('kg_title');
        if (savedTitle != null) _titleCtrl.text = savedTitle;
        
        _enableSeparation = prefs.getBool('kg_sep') ?? false;
        _uploadToCloud = prefs.getBool('kg_up') ?? true;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('kg_dx', _offset.dx);
    await prefs.setDouble('kg_dy', _offset.dy);
    await prefs.setDouble('kg_w', _width);
    await prefs.setDouble('kg_h', _height);
    
    await prefs.setString('kg_audio', _audioPathCtrl.text);
    await prefs.setString('kg_ref', _referencePathCtrl.text);
    await prefs.setString('kg_artist', _artistCtrl.text);
    await prefs.setString('kg_title', _titleCtrl.text);
    await prefs.setBool('kg_sep', _enableSeparation);
    await prefs.setBool('kg_up', _uploadToCloud);
  }

  Future<void> _pickAudioFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res != null && res.files.single.path != null) {
      setState(() => _audioPathCtrl.text = res.files.single.path!);
    }
  }

  Future<void> _pickReferenceFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt']);
    if (res != null && res.files.single.path != null) {
      setState(() => _referencePathCtrl.text = res.files.single.path!);
    }
  }

  void _runPipeline() async {
    if (_audioPathCtrl.text.isEmpty) return;
    
    // We execute the service asynchronously
    KaraokeGenService.instance.runTranscription(
      _audioPathCtrl.text,
      _artistCtrl.text.trim(),
      _titleCtrl.text.trim(),
      enableSeparation: _enableSeparation,
      referenceLyricsPath: _referencePathCtrl.text.trim(),
    ).then((_) {
       if (mounted) {
           final player = context.read<PlayerController>();
           if (player.currentItem != null) {
               // Force internal state LRC re-parsing overwriting native track mapping
               final lrcCtl = context.read<LyricsViewController>();
               lrcCtl.loadForCurrentItem("${player.currentItem!.id}_refresh_override", player.currentItem!.source);
           }
       }
       
       // If cloud sync enabled, we route subsequent uploading
       if (_uploadToCloud) {
          // Typically we would dynamically wait for completion and resolve ID natively.
          final generatedJobId = DateTime.now().millisecondsSinceEpoch.toString();
          // Karaoke-gen normally drops logs in local folder or output var. We mimic the transfer bus
          // KaraokeGenService.instance.uploadResults(generatedJobId, _audioPathCtrl.text + '_output_dir');
       }
    });

    // Intentionally no longer hiding window directly on submit
  }
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      width: _width,
      height: _height,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Container(
                            clipBehavior: Clip.antiAlias, decoration: BoxDecoration(
                      border: AppUIConfig.windowBorderWidth > 0 ? Border.all(color: AppColors.controlBorder, width: AppUIConfig.windowBorderWidth) : null,
                color: AppColors.windowBackground,
                borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
              // Header
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _offset += details.delta;
                    if (_offset.dy < 0) _offset = Offset(_offset.dx, 0);
                  });
                },
                onPanEnd: (_) => _savePreferences(),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.panelBackground,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(7), topRight: Radius.circular(7)),
                    border: Border(bottom: BorderSide(color: AppColors.overlaySubtle)),
                  ),
                  child: Row(
                    children: [
                      Icon(AppToolWindows.getDef('karaoke_gen').icon, size: 16, color: AppToolWindows.getDef('karaoke_gen').color),
                      const SizedBox(width: 8),
                      Text(AppToolWindows.getDef('karaoke_gen').name.toUpperCase(), style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.windowTitleFontSize, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Icon(Icons.close, color: AppColors.panelTextSecondary, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AUDIO SOURCE', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _audioPathCtrl,
                              style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Color(0xFF2D2D30),
                                border: OutlineInputBorder(borderSide: BorderSide.none),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                hintText: 'Absolute file path...',
                                hintStyle: TextStyle(color: AppColors.borderSubtle)
                              ),
                            )
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _audioPathCtrl.text.isEmpty ? _pickAudioFile : () => setState(() => _audioPathCtrl.clear()),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D2D30), padding: const EdgeInsets.symmetric(horizontal: 16)),
                            child: Icon(_audioPathCtrl.text.isEmpty ? Icons.folder_open : Icons.close, color: Colors.amberAccent, size: 16),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _referencePathCtrl,
                              style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Color(0xFF2D2D30),
                                border: OutlineInputBorder(borderSide: BorderSide.none),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                hintText: 'Optional: Reference .txt lyrics file...',
                                hintStyle: TextStyle(color: AppColors.borderSubtle)
                              ),
                            )
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _referencePathCtrl.text.isEmpty ? _pickReferenceFile : () => setState(() => _referencePathCtrl.clear()),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D2D30), padding: const EdgeInsets.symmetric(horizontal: 16)),
                            child: Icon(_referencePathCtrl.text.isEmpty ? Icons.text_snippet : Icons.close, color: Colors.amberAccent, size: 16),
                          )
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      Text('METADATA INJECTION', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _artistCtrl,
                         style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                         decoration: InputDecoration(
                           filled: true,
                           fillColor: Color(0xFF2D2D30),
                           border: OutlineInputBorder(borderSide: BorderSide.none),
                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                           labelText: 'Artist',
                           labelStyle: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)
                         ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleCtrl,
                         style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize),
                         decoration: InputDecoration(
                           filled: true,
                           fillColor: Color(0xFF2D2D30),
                           border: OutlineInputBorder(borderSide: BorderSide.none),
                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                           labelText: 'Track Title',
                           labelStyle: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize)
                         ),
                      ),
                      
                      const SizedBox(height: 24),
                      Text('CONFIGURATION FLAGS', style: TextStyle(color: AppColors.panelTextSecondary, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _enableSeparation,
                        onChanged: (val) {
                           setState(() => _enableSeparation = val ?? false);
                           _savePreferences();
                        },
                        title: Text('Isolate Instrumentals / Vocals', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize)),
                        activeColor: Colors.amberAccent,
                        checkColor: Colors.black,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        value: _uploadToCloud,
                        onChanged: (val) {
                           setState(() => _uploadToCloud = val ?? false);
                           _savePreferences();
                        },
                        title: Text('Export Separated Assets to Bucket', style: TextStyle(color: AppColors.panelTextPrimary, fontSize: AppUIConfig.rootFontSize)),
                        activeColor: Colors.amberAccent,
                        checkColor: Colors.black,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      
                      const SizedBox(height: 16),
                      Builder(builder: (context) {
                          final hasOpenAI = dotenv.env['OPENAI_API_KEY'] != null && dotenv.env['OPENAI_API_KEY']!.trim().isNotEmpty;
                          return Container(
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                                color: hasOpenAI ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppUIConfig.windowBorderRadius),
                                border: Border.all(color: hasOpenAI ? Colors.green.withOpacity(0.3) : Colors.amber.withOpacity(0.3))
                             ),
                             child: Row(
                                children: [
                                   Icon(hasOpenAI ? Icons.check_circle : Icons.warning_amber_rounded, size: 16, color: hasOpenAI ? Colors.greenAccent : Colors.amberAccent),
                                   const SizedBox(width: 8),
                                   Expanded(child: Text(hasOpenAI ? 'OpenAI GPT Correction Active' : 'OpenAI Not Configured (Whisper Raw)', style: TextStyle(color: hasOpenAI ? Colors.greenAccent : Colors.amberAccent, fontSize: AppUIConfig.rootFontSize, fontWeight: FontWeight.bold))),
                                ]
                             )
                          );
                      }),
                      
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: _runPipeline,
                          icon: const Icon(Icons.psychology, color: Colors.black, size: 18),
                          label: Text('EXECUTE ML PIPELINE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
            // Resizing handler
            Positioned(
              right: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _width = (_width + details.delta.dx).clamp(350.0, 1000.0);
                      _height = (_height + details.delta.dy).clamp(400.0, 1000.0);
                    });
                  },
                  onPanEnd: (_) => _savePreferences(),
                  child: Container(
                    width: 20,
                    height: 20,
                    color: Colors.transparent,
                    alignment: Alignment.bottomRight,
                    child: Icon(Icons.arrow_drop_down, color: AppColors.borderSubtle, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


