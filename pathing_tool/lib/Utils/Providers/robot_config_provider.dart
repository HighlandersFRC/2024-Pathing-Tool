import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:pathing_tool/Utils/Structs/robot_config.dart';

class RobotConfigProvider extends ChangeNotifier {
  late RobotConfig _robotConfig;
  final List<RobotConfig> _robotConfigs = [];

  RobotConfigProvider() {
    _loadConfig();
  }

  void _loadConfig() {
    String repoPath = 'C:';
    try {
      Directory prefDir = Directory("C:/Polar Pathing/Preferences");
      File preferredRobot = prefDir.listSync().first as File;
      File? preferencesFile;
      ZipDecoder decoder = ZipDecoder();
      prefDir.listSync().forEach((file) {
        if (file.path.split(".").last == "polarrc") {
          preferredRobot = file as File;
        }
        if (file.path.split(".").last == "polarprefs") {
          preferencesFile = file as File;
        }
      });
      if (preferencesFile != null) {
        final Uint8List prefBytes = preferencesFile!.readAsBytesSync();
        Archive prefArchive = decoder.decodeBytes(prefBytes);
        for (ArchiveFile file in prefArchive) {
          if (file.name == "config.json") {
            String jsonString = utf8.decode(file.content);
            Map<String, dynamic> preferredConfigJson = json.decode(jsonString);
            repoPath = preferredConfigJson["repository_path"] ?? "C:";
            break;
          }
        }
      }
      final Uint8List bytes = preferredRobot.readAsBytesSync();
      Archive preferencesArchive = decoder.decodeBytes(bytes);
      for (ArchiveFile file in preferencesArchive) {
        if (file.name == "config.json") {
          String jsonString = utf8.decode(file.content);
          Map<String, dynamic> robotConfigJson = json.decode(jsonString);
          _robotConfig = RobotConfig.fromJson(robotConfigJson);
          break;
        }
      }
      String preferredRobotName =
          preferredRobot.path.split("/").last.split(".").first;
      for (var robotConfig in _robotConfigs) {
        if (robotConfig.name == preferredRobotName) {
          preferredRobot = File(
              "$repoPath/Polar Pathing/Robots/${robotConfig.name}.polarrc");
          for (ArchiveFile file in preferencesArchive) {
            if (file.name == "config.json") {
              String jsonString = utf8.decode(file.content);
              Map<String, dynamic> robotConfigJson = json.decode(jsonString);
              _robotConfig = RobotConfig.fromJson(robotConfigJson);
              break;
            }
          }
          break;
        }
      }
      Directory robotDir = Directory("$repoPath/Polar Pathing/Robots");
      _robotConfigs.clear();
      robotDir.listSync().forEach((file) {
        if (file.path.split(".").last == "polarrc") {
          final Uint8List bytes = (file as File).readAsBytesSync();
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
      _robotConfig = RobotConfig("Default Robot", 1, 1, [], [], false);
      _robotConfigs.add(_robotConfig);
      _saveConfig();
    }
  }

  void refresh() {
    _loadConfig();
    notifyListeners();
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
    String repoPath = 'C:';
    Directory prefDir = Directory("C:/Polar Pathing/Preferences");
    File? preferencesFile;
    ZipDecoder decoder = ZipDecoder();
    prefDir.listSync().forEach((file) {
      if (file.path.split(".").last == "polarprefs") {
        preferencesFile = file as File;
      }
    });
    if (preferencesFile != null) {
      final Uint8List prefBytes = preferencesFile!.readAsBytesSync();
      Archive prefArchive = decoder.decodeBytes(prefBytes);
      for (ArchiveFile file in prefArchive) {
        if (file.name == "config.json") {
          String jsonString = utf8.decode(file.content);
          Map<String, dynamic> preferredConfigJson = json.decode(jsonString);
          repoPath = preferredConfigJson["repository_path"] ?? "C:";
          break;
        }
      }
    }
    var robotDir = Directory("$repoPath/Polar Pathing/Robots/");
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
    String repoPath = 'C:';
    try {
      Directory prefDir = Directory("C:/Polar Pathing/Preferences");
      File? preferencesFile;
      ZipDecoder decoder = ZipDecoder();
      prefDir.listSync().forEach((file) {
        if (file.path.split(".").last == "polarprefs") {
          preferencesFile = file as File;
        }
      });
      if (preferencesFile != null) {
        final Uint8List prefBytes = preferencesFile!.readAsBytesSync();
        Archive prefArchive = decoder.decodeBytes(prefBytes);
        for (ArchiveFile file in prefArchive) {
          if (file.name == "config.json") {
            String jsonString = utf8.decode(file.content);
            Map<String, dynamic> preferredConfigJson = json.decode(jsonString);
            repoPath = preferredConfigJson["repository_path"] ?? "C:";
            break;
          }
        }
      }
    } catch (e) {
      // print("Error: $e");
    }
    for (var configJson in configJsons) {
      Archive prefArchive = Archive();
      var themeJsonString = json.encode(configJson);
      ArchiveFile themeArchive = ArchiveFile(
          "config.json", themeJsonString.length, utf8.encode(themeJsonString));
      prefArchive.addFile(themeArchive);
      var zippedArchive = ZipEncoder().encode(prefArchive);
      File outputFile =
          File("$repoPath/Polar Pathing/Robots/${configJson["name"]}.polarrc");
      outputFile.createSync(recursive: true);
      outputFile.writeAsBytesSync(zippedArchive!);
    }
  }
}
