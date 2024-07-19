import 'dart:convert';
import 'dart:io';
import 'package:pathing_tool/Utils/Structs/command.dart';
import 'package:pathing_tool/Utils/quintic_hermite_spline.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';

class Spline {
  late QuinticHermiteSpline x, y, theta;
  late List<Waypoint> points;
  late List<Vectors> xVectors, yVectors, thetaVectors;
  final List<Command> commands;

  Spline(this.points, {this.commands = const []}) {
    xVectors = List.generate(points.length, (int i) => points[i].getXVectors());
    yVectors = List.generate(points.length, (int i) => points[i].getYVectors());
    thetaVectors =
        List.generate(points.length, (int i) => points[i].getThetaVectors());
    x = QuinticHermiteSpline(xVectors);
    y = QuinticHermiteSpline(yVectors);
    theta = QuinticHermiteSpline(thetaVectors);
  }

  static Spline fromPolarPathFile(File file) {
    String jsonString = file.readAsStringSync();
    Map<String, dynamic> splineJson = json.decode(jsonString);
    return fromJson(splineJson);
  }

  static Spline fromJson(Map<String, dynamic> splineJson) {
    List<Waypoint> points = [];
    splineJson["key_points"].forEach((waypointJson) {
      points.add(Waypoint.fromJson(waypointJson));
    });
    List<Command> commands = [];
    splineJson["commands"].forEach((commandJson) {
      commands.add(Command.fromJson(commandJson));
    });
    return Spline(points, commands: commands);
  }

  Waypoint getRobotWaypoint(double time) {
    return vectorsToWaypoint(
        x.getVectors(time), y.getVectors(time), theta.getVectors(time));
  }
}
