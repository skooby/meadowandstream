import '../db/app_database.dart';
import 'package:collection/collection.dart';

class AppTrack {
  final Asset trackFolder;
  final List<Asset> files;

  const AppTrack({
    required this.trackFolder,
    required this.files,
  });

  Asset? get audioFile {
     return files.firstWhereOrNull((t) => (t.mimeType ?? '').startsWith('audio/') || t.name.toLowerCase().endsWith('.mp3') || t.name.toLowerCase().endsWith('.wav'));
  }
}

class AppAlbum {
  final Asset albumFolder;
  final List<AppTrack> tracks;
  final List<Asset> albumFiles;

  const AppAlbum({
    required this.albumFolder,
    required this.tracks,
    required this.albumFiles,
  });

  bool get hasCoverArt {
     return albumFiles.any((t) => (t.mimeType ?? '').startsWith('image/')) || tracks.expand((tr) => tr.files).any((t) => (t.mimeType ?? '').startsWith('image/'));
  }

  Asset? get coverArt {
     try {
       return albumFiles.firstWhere((t) => (t.mimeType ?? '').startsWith('image/'));
     } catch (_) {
       try {
          return tracks.expand((tr) => tr.files).firstWhere((t) => (t.mimeType ?? '').startsWith('image/'));
       } catch (_) {
          return null;
       }
     }
  }

  List<AppTrack> get audioTracks {
     return tracks.where((t) => t.audioFile != null).toList();
  }
}
