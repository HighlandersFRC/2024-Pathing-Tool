import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Structs/robot_config.dart';

class RobotConfigProvider extends ChangeNotifier {
  late RobotConfig _robotConfig;
  
  RobotConfigProvider() {
    try {
      Directory prefDir = Directory("C:/Polar Pathing/Preferences");
      File preferencesFile = prefDir.listSync().first as File;
      prefDir.listSync().forEach((file) {
        if (file.path.split(".").last == "polarrc") {
          preferencesFile = file as File;
        }
      });
      ZipDecoder decoder = ZipDecoder();
      final Uint8List bytes = preferencesFile.readAsBytesSync();
      Archive preferencesArchive = decoder.decodeBytes(bytes);
      for (ArchiveFile file in preferencesArchive) {
        if (file.name == "config.json") {
          String jsonString = utf8.decode(file.content);
          Map<String, dynamic> robotConfigJson = json.decode(jsonString);
          _robotConfig = RobotConfig.fromJson(robotConfigJson);
          break;
        }
      }
    } on Exception {
      _robotConfig = RobotConfig("", 1, 1, [], []);
      _saveConfig();
    }
  }

  void setRobotConfig(RobotConfig robotConfig) {
    _robotConfig = robotConfig;
    notifyListeners();
    _saveConfig();
  }

  RobotConfig get robotConfig => _robotConfig;

  void _saveConfig() {
    Map<String, dynamic> configJson = _robotConfig.toJson();
    Archive prefArchive = Archive();
    var themeJsonString = json.encode(configJson);
    ArchiveFile themeArchive = ArchiveFile(
        "config.json", themeJsonString.length, utf8.encode(themeJsonString));
    prefArchive.addFile(themeArchive);
    var zippedArchive = ZipEncoder().encode(prefArchive);
    File outputFile = File("C:/Polar Pathing/Preferences/Robot.polarrc");
    outputFile.writeAsBytesSync(zippedArchive!);
  }
}