import 'dart:collection';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class AppProfilerService extends ChangeNotifier {
  static final AppProfilerService instance = AppProfilerService._internal();

  AppProfilerService._internal();

  bool _initialized = false;
  
  int _maxHistory = 200;
  int get maxHistory => _maxHistory;

  void updateTimescale(int newScale) {
    if (_maxHistory == newScale) return;
    _maxHistory = newScale;
    
    // Prune existing
    while(fpsHistory.length > _maxHistory) {
      fpsHistory.removeFirst();
    }
    while(renderTimeHistory.length > _maxHistory) {
      renderTimeHistory.removeFirst();
    }
    while(dbLatencyHistory.length > _maxHistory) {
      dbLatencyHistory.removeFirst();
    }
    while(syncLatencyHistory.length > _maxHistory) {
      syncLatencyHistory.removeFirst();
    }
    while(audioDecodingHistory.length > _maxHistory) {
      audioDecodingHistory.removeFirst();
    }

    notifyListeners();
  }

  // Telemetry Queues
  final DoubleLinkedQueue<double> fpsHistory = DoubleLinkedQueue();
  final DoubleLinkedQueue<double> renderTimeHistory = DoubleLinkedQueue();
  final DoubleLinkedQueue<double> dbLatencyHistory = DoubleLinkedQueue();
  final DoubleLinkedQueue<double> syncLatencyHistory = DoubleLinkedQueue();
  final DoubleLinkedQueue<double> audioDecodingHistory = DoubleLinkedQueue();

  double currentFps = 0.0;
  double currentRenderTime = 0.0;
  bool isEnabled = false;

  int _simulatorFramesPending = 0;
  int? _lastFrameStartUs;

  void init() {
    if (_initialized) return;
    _initialized = true;

    if (!kReleaseMode) {
      SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
        if (!isEnabled) return;
        
        bool processedAny = false;
        
        for (final timing in timings) {
          if (_simulatorFramesPending <= 0) continue;
          _simulatorFramesPending--;
          processedAny = true;

          final renderTime = timing.totalSpan.inMicroseconds.toDouble() / 1000.0;
          
          final startUs = timing.timestampInMicroseconds(FramePhase.buildStart);
          if (_lastFrameStartUs != null) {
            final diffUs = startUs - _lastFrameStartUs!;
            if (diffUs > 0) {
              final double fps = 1000000.0 / diffUs;
              fpsHistory.addLast(fps.clamp(0.0, 240.0));
              if (fpsHistory.length > _maxHistory) fpsHistory.removeFirst();
              currentFps = fps.clamp(0.0, 240.0);
            }
          }
          _lastFrameStartUs = startUs;

          renderTimeHistory.addLast(renderTime);
          if (renderTimeHistory.length > _maxHistory) renderTimeHistory.removeFirst();
          currentRenderTime = renderTime;
        }

        if (processedAny) {
          notifyListeners();
        }
      });
    }
  }

  void markSimulatorFrame() {
    if (!isEnabled) return;
    _simulatorFramesPending++;
  }

  void toggleProfiler() {
     isEnabled = !isEnabled;
     if (!isEnabled) {
        fpsHistory.clear();
        renderTimeHistory.clear();
        dbLatencyHistory.clear();
        syncLatencyHistory.clear();
        audioDecodingHistory.clear();
     }
     notifyListeners();
  }

  void recordDbLatency(double ms) {
    if (!isEnabled) return;
    dbLatencyHistory.addLast(ms);
    if (dbLatencyHistory.length > _maxHistory) dbLatencyHistory.removeFirst();
    notifyListeners();
  }

  void recordSyncLatency(double ms) {
    if (!isEnabled) return;
    syncLatencyHistory.addLast(ms);
    if (syncLatencyHistory.length > _maxHistory) syncLatencyHistory.removeFirst();
    notifyListeners();
  }

  void recordAudioLatency(double ms) {
    if (!isEnabled) return;
    audioDecodingHistory.addLast(ms);
    if (audioDecodingHistory.length > _maxHistory) audioDecodingHistory.removeFirst();
    notifyListeners();
  }

  double get averageFps => fpsHistory.isEmpty ? 0 : fpsHistory.reduce((a, b) => a + b) / fpsHistory.length;
  double get averageRender => renderTimeHistory.isEmpty ? 0 : renderTimeHistory.reduce((a, b) => a + b) / renderTimeHistory.length;
  double get averageDb => dbLatencyHistory.isEmpty ? 0 : dbLatencyHistory.reduce((a, b) => a + b) / dbLatencyHistory.length;
  double get averageSync => syncLatencyHistory.isEmpty ? 0 : syncLatencyHistory.reduce((a, b) => a + b) / syncLatencyHistory.length;
  double get averageAudio => audioDecodingHistory.isEmpty ? 0 : audioDecodingHistory.reduce((a, b) => a + b) / audioDecodingHistory.length;
}
