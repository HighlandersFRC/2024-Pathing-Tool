import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/spline.dart';
import 'package:pathing_tool/Widgets/auto_editor.dart';
import 'package:pathing_tool/Widgets/custom_app_bar.dart';
import '../Utils/Structs/robot_config.dart';
import '../Widgets/app_drawer.dart';

class AutosPage extends StatelessWidget {
  final List<Spline> splines;
  final String autoName;
  const AutosPage(this.splines, this.autoName, {super.key});
  static AutosPage fromFile(File file, RobotConfig config, int resolution) {
    String jsonString = file.readAsStringSync();
    var autoJson = json.decode(jsonString);
    return fromJson(autoJson, config, resolution);
  }

  static AutosPage fromJson(
      Map<String, dynamic> json, RobotConfig config, int resolution) {
    String autoName = json['meta_data']['auto_name'];
    List<Spline> splines = [];
    var paths = json['paths'];
    // Loop through Splines in the Schedule
    for (var scheduleItem in json['schedule']) {
      if (scheduleItem['branched']) {
        // Branched Splines
        var onTrue = SplineSet.fromJsonList(
            scheduleItem["branched_path"]["on_true"],
            paths,
            config,
            resolution);
        var onFalse = SplineSet.fromJsonList(
            scheduleItem["branched_path"]["on_false"],
            paths,
            config,
            resolution);
        var condition = scheduleItem["condition"];
        splines.add(BranchedSpline(onTrue, onFalse, condition, resolution));
      } else {
        // Single Splines
        splines.add(
            Spline.fromJson(paths[scheduleItem['path']], config, resolution));
      }
    }
    return AutosPage(splines, autoName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      drawer: const AppDrawer(),
      body: AutoEditor(splines, autoName),
    );
  }
}
