import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'theme.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeData _lightTheme = lightTheme(Colors.blue),
      _darkTheme = darkTheme(Colors.blue),
      _themeData = darkTheme(Colors.blue);
  ThemeNotifier() {
    try {
      Directory prefDir = Directory("C:/Polar Pathing/Preferences");
      File preferencesFile = prefDir.listSync().first as File;
      prefDir.listSync().forEach((file){
        if (file.path.split(".").last == "polartheme"){
          preferencesFile = file as File;
        } 
      });
      ZipDecoder decoder = ZipDecoder();
      final Uint8List bytes = preferencesFile.readAsBytesSync();
      Archive preferencesArchive = decoder.decodeBytes(bytes);
      for (ArchiveFile file in preferencesArchive) {
        if (file.name == "theme.json") {
          String jsonString = utf8.decode(file.content);
          Map<String, dynamic> themeJson = json.decode(jsonString);
          Color color = Color.fromARGB(
              themeJson["color"]["a"],
              themeJson["color"]["r"],
              themeJson["color"]["g"],
              themeJson["color"]["b"]);
          _lightTheme = lightTheme(color);
          _darkTheme = darkTheme(color);
          _themeData = themeJson["light"] ? _lightTheme : _darkTheme;
          break;
        }
      }
    } on Exception {
      Directory('C:/Polar Pathing/Preferences').createSync(recursive: true);
      Archive prefArchive = Archive();
      Map<String, dynamic> themeJson = <String, dynamic>{
        "color": <String, dynamic>{
          "a": Colors.blue.alpha,
          "r": Colors.blue.red,
          "g": Colors.blue.green,
          "b": Colors.blue.blue,
        },
        "light": false
      };
      var themeJsonString = json.encode(themeJson);
      ArchiveFile themeArchive = ArchiveFile(
          "theme.json", themeJsonString.length, utf8.encode(themeJsonString));
      prefArchive.addFile(themeArchive);
      var zippedArchive = ZipEncoder().encode(prefArchive);
      File outputFile = File("C:/Polar Pathing/Preferences/Theme.polartheme");
      outputFile.writeAsBytesSync(zippedArchive!);
      _lightTheme = lightTheme(Colors.blue);
      _darkTheme = darkTheme(Colors.blue);
      _themeData = darkTheme(Colors.blue);
    }
  }

  ThemeData get themeData => _themeData;

  void setTheme(Color color) {
    _lightTheme = lightTheme(color);
    _darkTheme = darkTheme(color);
    _themeData =
        _themeData.brightness == Brightness.light ? _lightTheme : _darkTheme;
    notifyListeners();
    Map<String, dynamic> themeJson = <String, dynamic>{
      "color": <String, dynamic>{
        "a": color.alpha,
        "r": color.red,
        "g": color.green,
        "b": color.blue,
      },
      "light": _themeData.brightness == Brightness.light
    };
    Archive prefArchive = Archive();
    var themeJsonString = json.encode(themeJson);
    ArchiveFile themeArchive = ArchiveFile(
        "theme.json", themeJsonString.length, utf8.encode(themeJsonString));
    prefArchive.addFile(themeArchive);
    var zippedArchive = ZipEncoder().encode(prefArchive);
    File outputFile = File("C:/Polar Pathing/Preferences/Theme.polartheme");
    outputFile.writeAsBytesSync(zippedArchive!);
  }

  void toggleTheme() {
    if (_themeData.brightness == Brightness.light) {
      _themeData = _darkTheme;
    } else {
      _themeData = _lightTheme;
    }
    notifyListeners();
    Map<String, dynamic> themeJson = <String, dynamic>{
      "color": <String, dynamic>{
        "a": _themeData.primaryColor.alpha,
        "r": _themeData.primaryColor.red,
        "g": _themeData.primaryColor.green,
        "b": _themeData.primaryColor.blue,
      },
      "light": _themeData.brightness == Brightness.light
    };
    Archive prefArchive = Archive();
    var themeJsonString = json.encode(themeJson);
    ArchiveFile themeArchive = ArchiveFile(
        "theme.json", themeJsonString.length, utf8.encode(themeJsonString));
    prefArchive.addFile(themeArchive);
    var zippedArchive = ZipEncoder().encode(prefArchive);
    File outputFile = File("C:/Polar Pathing/Preferences/Theme.polartheme");
    outputFile.writeAsBytesSync(zippedArchive!);
  }
}
