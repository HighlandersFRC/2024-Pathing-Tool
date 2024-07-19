import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';
import 'package:pathing_tool/Utils/spline.dart';
import 'package:pathing_tool/Widgets/auto_editor.dart';
import 'package:pathing_tool/Widgets/custom_app_bar.dart';
import '../Widgets/app_drawer.dart';

class AutosPage extends StatelessWidget {
  final List<Spline> splines;
  final String autoName;
  const AutosPage(this.splines, this.autoName, {super.key});
  static AutosPage fromFile(File file) {
    String jsonString = file.readAsStringSync();
    var autoJson = json.decode(jsonString);
    var splineList = autoJson["paths"];
    List<Spline> splines = [];
    splineList.forEach((spline) {
      List<Waypoint> waypoints = [];
      var pointsList = spline["key_points"];
      for (var point in pointsList) {
        waypoints.add(Waypoint(
          x: point["x"],
          y: point["y"],
          theta: point["angle"],
          dx: point["x_velocity"],
          dy: point["y_velocity"],
          dtheta: point["angular_velocity"],
          d2x: point["x_acceleration"],
          d2y: point["y_acceleration"],
          d2theta: point["angular_acceleration"],
          t: point["time"]));
      }
      splines.add(Spline(waypoints));
    });
    String pathName = autoJson["meta_data"]["path_name"];
    return AutosPage(splines, pathName);
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
