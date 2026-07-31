import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity + reachability checks for the gridlink pipeline.
class SignalProbe {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Time-boxed reachability check against well-known hosts (never our own
  /// domain) so a VPN or a not-yet-propagated app domain cannot produce a
  /// false "offline", and the retry button can never hang forever.
  Future<bool> canReachNetwork() async {
    if (!await hasInterface()) return false;
    for (final host in const <String>['apple.com', 'google.com']) {
      try {
        final records = await InternetAddress.lookup(
          host,
        ).timeout(const Duration(seconds: 3));
        if (records.any((record) => record.rawAddress.isNotEmpty)) {
          return true;
        }
      } catch (_) {
        // Try the next host before declaring offline.
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
