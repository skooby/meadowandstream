import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();

  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    if (Platform.isWindows) {
      return const Stream.empty();
    }
    return _connectivity.onConnectivityChanged;
  }

  Future<List<ConnectivityResult>> checkConnectivity() =>
      _connectivity.checkConnectivity();

  Future<bool> isWifi() async {
    final results = await checkConnectivity();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }
}
