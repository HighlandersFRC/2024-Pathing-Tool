import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Providers/image_data_provider.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:pathing_tool/Utils/Structs/command.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';
import 'package:pathing_tool/Utils/spline.dart';
import 'package:pathing_tool/Widgets/custom_app_bar.dart';
import 'package:pathing_tool/Widgets/path_editor.dart';
import 'package:provider/provider.dart';
import '../Widgets/app_drawer.dart';

class PathingPage extends StatelessWidget {
  final List<Waypoint> waypoints;
  final List<Command> commands;
  final String pathName;
  final String? robotName, fieldName;
  final Function(Spline)? returnSpline;
  final bool firstLocked, lastLocked;
  const PathingPage(this.waypoints, this.commands, this.pathName,
      {super.key,
      this.robotName,
      this.fieldName,
      this.returnSpline,
      this.firstLocked = false,
      this.lastLocked = false});

  static PathingPage fromFile(File file) {
    String jsonString = file.readAsStringSync();
    var pathJson = json.decode(jsonString);
    var pointsJsonList = pathJson["key_points"];
    List<Waypoint> waypoints = [];
    pointsJsonList.forEach((point) {
      waypoints.add(Waypoint.fromJson(point as Map<String, dynamic>));
    });
    List<Command> commands = [];
    var commandsJsonList = pathJson["commands"];
    commandsJsonList.forEach((command) {
      var newCommand = Command.fromJson(command);
      commands.add(newCommand);
    });
    String pathName = pathJson["meta_data"]["path_name"];
    String? robotName = pathJson["meta_data"]["robot_name"],
        fieldName = pathJson["meta_data"]["field_name"];
    return PathingPage(
      waypoints,
      commands,
      pathName,
      robotName: robotName,
      fieldName: fieldName,
    );
  }

  static PathingPage fromSpline(Spline spline,
      {Function(Spline)? returnSpline,
      bool firstLocked = false,
      bool lastLocked = false}) {
    return PathingPage(spline.points, spline.commands, spline.name,
        returnSpline: returnSpline,
        firstLocked: firstLocked,
        lastLocked: lastLocked);
  }

  @override
  Widget build(BuildContext context) {
    if (robotName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final robotProvider =
            Provider.of<RobotConfigProvider>(context, listen: false);
        if (robotProvider.robotConfigs
            .any((config) => config.name == robotName)) {
          robotProvider.setRobotConfig(robotProvider.robotConfigs
              .firstWhere((config) => config.name == robotName));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Robot "$robotName"not found')));
        }
      });
    }
    if (fieldName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final fieldProvider =
            Provider.of<ImageDataProvider>(context, listen: false);
        if (fieldProvider.images
            .any((config) => config.imageName == fieldName)) {
          fieldProvider.selectImage(fieldProvider.images
              .firstWhere((config) => config.imageName == fieldName));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Field "$fieldName" not found')));
        }
      });
    }
    return Scaffold(
      appBar: const CustomAppBar(),
      drawer: const AppDrawer(),
      body: PathEditor(
        waypoints,
        pathName,
        commands,
        returnSpline: returnSpline,
        firstLocked: firstLocked,
        lastLocked: lastLocked,
      ),
    );
  }
}
