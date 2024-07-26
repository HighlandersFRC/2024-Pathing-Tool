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

  bool get isNull => false;

  Map<String, dynamic> toJson() {
    var json = {
      "meta_data": {"path_name": name},
      "key_points":
          points.map((Waypoint waypoint) => waypoint.toJson()).toList(),
      "commands": commands.map((Command command) => command.toJson()).toList(),
      if (points.length > 1)
        "sampled_points": [
          for (double t = points.first.t; t <= points.last.t; t += 0.01)
            getRobotWaypoint(t)
        ]
    };
    return json;
  }

  (Map<String, dynamic>, int) scheduleItem(int pathIndex) {
    return (
      {
        "branched": false,
        "path": pathIndex,
      },
      pathIndex + 1
    );
  }
}

class BranchedSpline extends Spline {
  final Spline onTrue, onFalse;
  final String condition;
  late bool _isTrue;
  BranchedSpline(this.onTrue, this.onFalse, this.condition,
      {bool isTrue = true})
      : super(isTrue ? onTrue.points : onFalse.points,
            name: "Branched Spline") {
    _isTrue = isTrue;
  }

  bool get isTrue => _isTrue;

  @override
  BranchedSpline copyWith(
      {List<Command>? commands,
      String? name,
      List<Waypoint>? points,
      Spline? onTrue,
      Spline? onFalse,
      String? condition,
      bool? isTrue}) {
    onTrue = onTrue ?? this.onTrue;
    onFalse = onFalse ?? this.onFalse;
    if (points != null) {
      if (this.isTrue) {
        onTrue = onTrue.copyWith(points: points);
        if (onTrue.points.isNotEmpty && (onFalse).points.isNotEmpty) {
          if (!onFalse.points.first.equals(onTrue.points.first)) {
            onFalse = _handleFirstPoint(onFalse, onTrue.points.first);
          }
          if (!onTrue.points.last.equals(onFalse.points.last)) {
            onFalse = _handleLastPoint(onFalse, onTrue.points.last);
          }
        } else {
          if (onTrue.points.isEmpty && onFalse.points.isNotEmpty) {
            onTrue = _handleFirstPoint(onTrue, onFalse.points.first);
            onTrue = _handleLastPoint(onTrue, onFalse.points.last);
          } else if (onFalse.points.isEmpty && onTrue.points.isNotEmpty) {
            onFalse = _handleFirstPoint(onFalse, onTrue.points.first);
            onFalse = _handleLastPoint(onFalse, onTrue.points.last);
          }
        }
      } else {
        onFalse = (onFalse).copyWith(points: points);
        if (onTrue.points.isNotEmpty && (onFalse).points.isNotEmpty) {
          if (!onTrue.points.first.equals(onFalse.points.first)) {
            onTrue = _handleFirstPoint(onTrue, onFalse.points.first);
          }
          if (!onTrue.points.last.equals(onFalse.points.last)) {
            onTrue = _handleLastPoint(onTrue, onFalse.points.last);
          }
        } else {
          if (onTrue.points.isEmpty && onFalse.points.isNotEmpty) {
            onTrue = _handleFirstPoint(onTrue, onFalse.points.first);
            onTrue = _handleLastPoint(onTrue, onFalse.points.last);
          } else if (onFalse.points.isEmpty && onTrue.points.isNotEmpty) {
            onFalse = _handleFirstPoint(onFalse, onTrue.points.first);
            onFalse = _handleLastPoint(onFalse, onTrue.points.last);
          }
        }
      }
    } 
    onTrue = (onTrue).copyWith();
    onFalse = (onFalse).copyWith();
    return BranchedSpline(onTrue, onFalse, condition ?? this.condition,
        isTrue: isTrue ?? this.isTrue);
  }

  Spline _handleFirstPoint(Spline newSpline, Waypoint preferredPoint) {
    if (newSpline.points.isNotEmpty) {
      return newSpline.copyWith(points: [
        preferredPoint.copyWith(t: newSpline.points.first.time - 1),
        ...newSpline.points
      ]);
    } else {
      return newSpline.copyWith(points: [
        preferredPoint.copyWith(t: 0.0),
      ]);
    }
  }

  Spline _handleLastPoint(Spline newSpline, Waypoint preferredPoint) {
    if (newSpline.points.isNotEmpty) {
      return newSpline.copyWith(points: [
        ...newSpline.points,
        preferredPoint.copyWith(t: newSpline.points.last.time + 1),
      ]);
    } else {
      return newSpline.copyWith(points: [
        preferredPoint.copyWith(t: 0.0),
      ]);
    }
  }

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }

  @override
  (Map<String, dynamic>, int) scheduleItem(int pathIndex) {
    return (
      {
        "branched": true,
        "condition": condition,
        "branched_path": {
          "on_true": onTrue is NullSpline ? -1 : pathIndex,
          "on_false": onTrue is NullSpline
              ? onFalse is NullSpline
                  ? -1
                  : pathIndex
              : onFalse is NullSpline
                  ? -1
                  : pathIndex + 1,
        }
      },
      pathIndex +
          (onTrue is NullSpline
              ? onFalse is NullSpline
                  ? 0
                  : 1
              : onFalse is NullSpline
                  ? 1
                  : 2)
    );
  }
}

class NullSpline extends Spline {
  NullSpline() : super([], commands: [], name: "Null Spline");

  @override
  bool get isNull => true;

  @override
  Spline copyWith(
      {List<Command>? commands, String? name, List<Waypoint>? points}) {
    if (points == null && commands == null && name == null) {
      return NullSpline();
    } else {
      return super.copyWith(commands: commands, name: name, points: points);
    }
  }

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }
}
