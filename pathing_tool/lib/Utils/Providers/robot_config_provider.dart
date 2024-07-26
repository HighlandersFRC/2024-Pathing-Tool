import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:pathing_tool/Utils/Structs/robot_config.dart';

class RobotConfigProvider extends ChangeNotifier {
  late RobotConfig _robotConfig;
  List<RobotConfig> _robotConfigs = [];

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
      Directory robotDir = Directory("C:/Polar Pathing/Robots");
      File robotFile = prefDir.listSync().first as File;
      robotDir.listSync().forEach((file) {
        if (file.path.split(".").last == "polarrc") {
          robotFile = file as File;
          final Uint8List bytes = robotFile.readAsBytesSync();
          Archive archive = decoder.decodeBytes(bytes);
          for (ArchiveFile file in archive) {
            if (file.name == "config.json") {
              String jsonString = utf8.decode(file.content);
              Map<String, dynamic> robotConfigJson = json.decode(jsonString);
              _robotConfigs.add(RobotConfig.fromJson(robotConfigJson));
              break;
            }
          }
        }
      });
    } on Exception {
      _robotConfig = RobotConfig("Default Robot", 1, 1, [], []);
      _robotConfigs.add(_robotConfig);
      _saveConfig();
    }
  }

  void setRobotConfig(RobotConfig robotConfig) {
    _robotConfig = robotConfig;
    notifyListeners();
    _saveConfig();
  }

  RobotConfig get robotConfig => _robotConfig;
  List<RobotConfig> get robotConfigs => _robotConfigs;

  void addRobot(RobotConfig robotConfig) {
    _robotConfigs.add(robotConfig);
    notifyListeners();
    _saveConfig();
  }

  void removeRobot(RobotConfig robotConfig) {
    _robotConfigs.remove(robotConfig);
    if (_robotConfig == robotConfig) {
      _robotConfig = _robotConfigs.firstOrNull ?? _robotConfig;
    }
    notifyListeners();
    var robotDir = Directory("C:/Polar Pathing/Robots/");
    for (var file in robotDir.listSync()) {
      if (file.path.split(".").last == "polarrc" &&
          file.path.split("/").last == '${robotConfig.name}.polarrc') {
        file.deleteSync();
        break;
      }
    }
    _saveConfig();
  }

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
    List<Map<String, dynamic>> configJsons = [
      ..._robotConfigs.map((robotConfig) => robotConfig.toJson())
    ];
    for (var configJson in configJsons) {
      Archive prefArchive = Archive();
      var themeJsonString = json.encode(configJson);
      ArchiveFile themeArchive = ArchiveFile(
          "config.json", themeJsonString.length, utf8.encode(themeJsonString));
      prefArchive.addFile(themeArchive);
      var zippedArchive = ZipEncoder().encode(prefArchive);
      File outputFile =
          File("C:/Polar Pathing/Robots/${configJson["name"]}.polarrc");
      outputFile.writeAsBytesSync(zippedArchive!);
    }
  }
}
