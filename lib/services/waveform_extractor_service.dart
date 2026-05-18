import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:just_waveform/just_waveform.dart';
import '../models/item_source.dart';

class WaveformExtractorService extends ChangeNotifier {
  static final WaveformExtractorService _instance =
      WaveformExtractorService._internal();
  factory WaveformExtractorService() => _instance;
  WaveformExtractorService._internal();

  final Map<String, Waveform> _waveforms = {};
  final Map<String, int> _maxAmplitudes = {};

  Waveform? getWaveform(String itemId) => _waveforms[itemId];
  int getMaxAmplitude(String itemId) => _maxAmplitudes[itemId] ?? 32768;

  Future<void> extractForItem(ItemSource item) async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Platform unsupported natively by just_waveform. We bypass it seamlessly.
      // E.g., NowPlayingScreen gracefully handles missing waveforms via 0.0 fallbacks.
      return;
    }
    
    if (_waveforms.containsKey(item.id)) return;

    debugPrint(
        "WaveformExtractorService: Start extracting for item ${item.id}");

    try {
      final tempDir = await getTemporaryDirectory();
      final waveFile = File('${tempDir.path}/${item.id}.wave');

      // If we already extracted it previously, just read it
      if (await waveFile.exists()) {
        final parsed = await JustWaveform.parse(waveFile);
        _waveforms[item.id] = parsed;
        _calculateAndStoreMaxAmp(item.id, parsed);
        notifyListeners();
        return;
      }

      File audioFile;

      if (item.sourceType == SourceType.asset) {
        audioFile = File('${tempDir.path}/${item.id}_temp.mp3');
        debugPrint(
            "WaveformExtractorService: Extracting from Asset URL: ${item.source}. Temp file: ${audioFile.path}");

        if (!await audioFile.exists()) {
          debugPrint(
              "WaveformExtractorService: Cache Miss. Loading rootBundle Asset: ${item.source}");
          try {
            final byteData = await rootBundle.load(item.source);
            await audioFile.writeAsBytes(byteData.buffer
                .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
            debugPrint(
                "WaveformExtractorService: Built temp asset file ${audioFile.path} (Length: ${await audioFile.length()})");
          } catch (e) {
            debugPrint(
                "WaveformExtractorService: FAILED to load and write Asset: $e");
          }
        }
      } else if (item.sourceType == SourceType.file) {
        audioFile = File(item.source);
        debugPrint(
            "WaveformExtractorService: Extracting directly from File: ${audioFile.path}");
      } else {
        debugPrint(
            "WaveformExtractorService: Extraction for network sources not implemented yet.");
        return;
      }

      debugPrint(
          "WaveformExtractorService: Dispatching JustWaveform.extract...");

      final stream = JustWaveform.extract(
        audioInFile: audioFile,
        waveOutFile: waveFile,
        zoom: const WaveformZoom.pixelsPerSecond(
            60), // 60 frames/sec of resolution
      );

      await stream.last; // Wait for extraction to finish

      final parsed = await JustWaveform.parse(waveFile);
      _waveforms[item.id] = parsed;
      _calculateAndStoreMaxAmp(item.id, parsed);

      debugPrint(
          "WaveformExtractorService: Extraction finished for ${item.id}, data length: ${_waveforms[item.id]?.data.length}, maxAmp: ${_maxAmplitudes[item.id]}");
      notifyListeners();

      if (item.sourceType == SourceType.asset && await audioFile.exists()) {
        await audioFile.delete(); // cleanup temp audio file
      }
    } catch (e) {
      debugPrint("WaveformExtractorService Error: $e");
    }
  }

  void _calculateAndStoreMaxAmp(String itemId, Waveform waveform) {
    int maxAmp = 1; // Prevent division by zero
    for (int i = 1; i < waveform.data.length; i += 2) {
      final val = waveform.data[i].abs();
      if (val > maxAmp) {
        maxAmp = val;
      }
    }
    _maxAmplitudes[itemId] = maxAmp;
  }
}
