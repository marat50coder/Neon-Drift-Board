import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the cold-start push URL written by SceneDelegate (killed-app tap).
/// The key mirrors SceneDelegate.launchLaneKey — the `flutter.` prefix bridges
/// UserDefaults ↔ SharedPreferences. Keep the two keys in sync.
class ColdTapReader {
  static const String _dartKey = 'ndb_launch_lane';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(_dartKey);
      return value;
    } catch (_) {
      return null;
    }
  }
}
