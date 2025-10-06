import 'package:flutter/services.dart';

class Utils {
  // Useful utility functions

  // Get the version of the app from pubspec.yaml
  static Future<String> getVersionFromPubspec() async {
    String yaml = await rootBundle.loadString('pubspec.yaml');
    String versionLine = yaml.split('\n').firstWhere(
          (line) => line.trim().startsWith('version:'),
          orElse: () => '',
        );
    return versionLine.isNotEmpty
        ? versionLine.split(':').last.trim()
        : 'unknown';
  }
}
