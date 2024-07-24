import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:pathing_tool/Utils/Structs/command.dart';
import 'package:pathing_tool/Utils/quintic_hermite_spline.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';

class Spline {
  late QuinticHermiteSpline x, y, theta;
  late List<Waypoint> points;
  late List<Vectors> xVectors, yVectors, thetaVectors;
  late List<Command> commands;
  final String name;

  Spline(this.points, {this.commands = const [], this.name = ""}) {
    points.sort((a, b) => a.time.compareTo(b.time));
    var startTime = this.startTime;
    commands = [
      for (var command in commands)
        command.copyWith(
            startTime: command.startTime - startTime,
            endTime: command.endTime - startTime)
    ];
    points = [for (var point in points) point.copyWith(t: point.t - startTime)];
    for (var point in points) {
      point = point.copyWith(t: point.t - startTime);
    }
    optimizeRotation();
    xVectors = List.generate(points.length, (int i) => points[i].getXVectors());
    yVectors = List.generate(points.length, (int i) => points[i].getYVectors());
    thetaVectors =
        List.generate(points.length, (int i) => points[i].getThetaVectors());
    x = QuinticHermiteSpline(xVectors);
    y = QuinticHermiteSpline(yVectors);
    theta = QuinticHermiteSpline(thetaVectors);
  }

  void optimizeRotation() {
    for (int i = 1; i < points.length; i++) {
      var p1 = points[i - 1];
      points[i] = points[i].copyWith(theta: points[i].theta % (2 * pi));
      while (true) {
        if (points[i].theta - p1.theta > pi) {
          points[i] = points[i].copyWith(theta: points[i].theta - 2 * pi);
        } else if (points[i].theta - p1.theta < -pi) {
          points[i] = points[i].copyWith(theta: points[i].theta + 2 * pi);
        } else {
          break;
        }
      }
    }
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
    String name = splineJson["meta_data"]["path_name"];
    return Spline(points, commands: commands, name: name);
  }

  Waypoint getRobotWaypoint(double time) {
    if (time < startTime) {
      return getRobotWaypoint(startTime);
    } else if (time > endTime) {
      return getRobotWaypoint(endTime);
    }
    if (points.length > 1) {
      if (time < points.first.time) {
        return points.first.copyWith();
      } else if (time > points.last.time) {
        return points.last.copyWith();
      }
    }
    return vectorsToWaypoint(
        x.getVectors(time), y.getVectors(time), theta.getVectors(time));
  }

  Spline copyWith(
      {List<Command>? commands, String? name, List<Waypoint>? points}) {
    points = [for (var point in (points ?? this.points)) point.copyWith()];
    commands = [
      for (var command in (commands ?? this.commands)) command.copyWith()
    ];
    return Spline(points, commands: commands, name: name ?? this.name);
  }

  double get duration {
    return endTime - startTime;
  }

  double get startTime {
    if (points.isEmpty) {
      if (commands.isEmpty) return 0.0;
      return getFirstStartTime(commands, 0.0);
    } else {
      if (commands.isEmpty) return points.first.time;
      return min(getFirstStartTime(commands, 0.0), points.first.time);
    }
  }

  double get endTime {
    if (points.isEmpty) {
      if (commands.isEmpty) return 0.0;
      return getLastEndTime(commands, 0.0);
    } else {
      if (commands.isEmpty) return points.last.time;
      return max(getLastEndTime(commands, 0.0), points.last.time);
    }
  }
}

class BranchedSpline extends Spline {
  final Spline onTrue, onFalse;
  final String condition;
  late bool _isTrue;
  BranchedSpline(this.onTrue, this.onFalse, this.condition, {isTrue = true})
      : super([onTrue.points.first, onTrue.points.last],
            name: "Branched Spline") {
    _isTrue = isTrue;
  }

  set isTrue(bool isTrue) {
    _isTrue = isTrue;
    super.points = _isTrue ? onTrue.points : onFalse.points;
    super.commands = _isTrue ? onTrue.commands : onFalse.commands;
  }

  bool get isTrue => _isTrue;
}

class NullSpline extends Spline {
  NullSpline() : super([], commands: [], name: "Null Spline");
}