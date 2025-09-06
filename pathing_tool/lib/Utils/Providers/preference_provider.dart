import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:provider/provider.dart';

class PreferenceProvider extends ChangeNotifier {
  late Map<String, dynamic> _preferences;

  PreferenceProvider() {
    try {
      Directory prefDir = Directory("C:/Polar Pathing/Preferences");
      File preferencesFile = prefDir.listSync().firstWhere(
              (file) => file.path.split(".").last == "polarrc" && file is File)
          as File;

      ZipDecoder decoder = ZipDecoder();
      final Uint8List bytes = preferencesFile.readAsBytesSync();
      Archive preferencesArchive = decoder.decodeBytes(bytes);

      for (ArchiveFile file in preferencesArchive) {
        if (file.name == "config.json") {
          String jsonString = utf8.decode(file.content);
          _preferences = json.decode(jsonString);
          break;
        }
      }
    } on Exception {
      _preferences = {};
    }
  }

  Map<String, dynamic> get preferences {
    try {
      Directory prefDir = Directory("C:/Polar Pathing/Preferences");
      File preferencesFile = prefDir.listSync().firstWhere((file) =>
          file.path.split(".").last == "polarprefs" && file is File) as File;

      ZipDecoder decoder = ZipDecoder();
      final Uint8List bytes = preferencesFile.readAsBytesSync();
      Archive preferencesArchive = decoder.decodeBytes(bytes);

      for (ArchiveFile file in preferencesArchive) {
        if (file.name == "config.json") {
          String jsonString = utf8.decode(file.content);
          _preferences = json.decode(jsonString);
          break;
        }
      }
    } catch (e) {
      _preferences = {};
    }
    return _preferences;
  }

  String get repositoryPath => preferences["repository_path"] ?? "C:";
  int get pathResolution => preferences["path_resolution"] ?? 144;

  void savePreferences(
      Map<String, dynamic> newPreferences, BuildContext context) {
    _preferences = newPreferences;

    Archive prefArchive = Archive();
    var jsonString = json.encode(_preferences);
    ArchiveFile archiveFile =
        ArchiveFile("config.json", jsonString.length, utf8.encode(jsonString));
    prefArchive.addFile(archiveFile);

    var zippedArchive = ZipEncoder().encode(prefArchive);
    File outputFile =
        File("C:/Polar Pathing/Preferences/Preferences.polarprefs");
    outputFile.writeAsBytesSync(zippedArchive!);
    Provider.of<RobotConfigProvider>(context, listen: false).refresh();
  }
}
