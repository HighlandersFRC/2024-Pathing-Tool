import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';
import 'package:pathing_tool/Widgets/custom_app_bar.dart';
import 'package:pathing_tool/Widgets/path_editor.dart';
import '../Widgets/app_drawer.dart';

class PathingPage extends StatelessWidget {
  final List<Waypoint> waypoints;
  final String pathName;
  const PathingPage(this.waypoints, this.pathName, {super.key});
  static PathingPage fromFile(File file) {
    String jsonString = file.readAsStringSync();
    var pathJson = json.decode(jsonString);
    var pointsJsonList = pathJson["key_points"];
    List<Waypoint> waypoints = [];
    pointsJsonList.forEach((point) {
      waypoints.add(Waypoint.fromJson(point as Map<String, dynamic>));
    });
    String pathName = pathJson["meta_data"]["path_name"];
    return PathingPage(waypoints, pathName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      drawer: const AppDrawer(),
      body: PathEditor(waypoints, pathName),
    );
  }
}
