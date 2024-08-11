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
  final SplineSet onTrue, onFalse;
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
      SplineSet? onTrue,
      SplineSet? onFalse,
      String? condition,
      bool? isTrue}) {
    onTrue = onTrue ?? this.onTrue;
    onFalse = onFalse ?? this.onFalse;
    // print("hi");
    if (this.isTrue) {
      if (points != null) onTrue = _handleFirstPoint(onTrue, points.first);
      // print("hi2");
      if (onTrue.points.isNotEmpty && (onFalse).points.isNotEmpty) {
        if (!onFalse.points.first.equals(onTrue.points.first)) {
          onFalse = _handleFirstPoint(onFalse, onTrue.points.first);
          // print("hi3");
        }
        // print("hi4");
        if (!onTrue.points.last.equals(onFalse.points.last)) {
          onFalse = _handleLastPoint(onFalse, onTrue.points.last);
          // print("hi5");
        }
      } else {
        // print("hi6");
        if (onTrue.points.isEmpty && onFalse.points.isNotEmpty) {
          onTrue = _handleFirstPoint(onTrue, onFalse.points.first);
          onTrue = _handleLastPoint(onTrue, onFalse.points.last);
          // print("hi7");
        } else if (onFalse.points.isEmpty && onTrue.points.isNotEmpty) {
          onFalse = _handleFirstPoint(onFalse, onTrue.points.first);
          onFalse = _handleLastPoint(onFalse, onTrue.points.last);
          // print("hi8");
        }
      }
    } else {
      if (points != null) onFalse = _handleFirstPoint(onFalse, points.first);
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
    return BranchedSpline(onTrue, onFalse, condition ?? this.condition,
        isTrue: isTrue ?? this.isTrue);
  }

  SplineSet _handleFirstPoint(SplineSet newSpline, Waypoint preferredPoint) {
    print("hi");
    if (newSpline.splines.isEmpty) {
      return SplineSet([
        Spline([preferredPoint.copyWith(t: 0)])
      ]);
    }
    if (newSpline.splines.first.points.isEmpty) {
      return SplineSet([
        Spline(([preferredPoint.copyWith(t: 0)])),
        ...[
          for (var spline
              in newSpline.splines.indexed.where((spline) => spline.$1 != 0))
            spline.$2
        ],
      ]);
    }
    return SplineSet([
      newSpline.splines.first.copyWith(points: [
        preferredPoint.copyWith(t: newSpline.points.first.t - 1),
        ...newSpline.splines.first.points
      ]),
      ...[
        for (var spline
            in newSpline.splines.indexed.where((spline) => spline.$1 != 0))
          spline.$2
      ],
    ]);
  }

  SplineSet _handleLastPoint(SplineSet newSpline, Waypoint preferredPoint) {
    if (newSpline.splines.isEmpty) {
      return SplineSet([
        Spline([preferredPoint.copyWith(t: 0)])
      ]);
    }
    if (newSpline.splines.last.points.isEmpty) {
      return SplineSet([
        ...[
          for (var spline in newSpline.splines.indexed
              .where((spline) => spline.$1 != newSpline.splines.length - 1))
            spline.$2
        ],
        Spline(([preferredPoint.copyWith(t: 0)])),
      ]);
    }
    return SplineSet([
      ...[
        for (var spline in newSpline.splines.indexed
            .where((spline) => spline.$1 != newSpline.splines.length - 1))
          spline.$2
      ],
      newSpline.splines.last.copyWith(points: [
        ...newSpline.splines.first.points,
        preferredPoint.copyWith(t: newSpline.points.last.t + 1),
      ]),
    ]);
  }

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }

  @override
  (Map<String, dynamic>, int) scheduleItem(int pathIndex) {
    var (onTrueSchedule, onTruePathIndex) = onTrue.scheduleItems(pathIndex);
    var (onFalseSchedule, onFalsePathIndex) =
        onFalse.scheduleItems(onTruePathIndex);
    pathIndex = onFalsePathIndex;
    return (
      {
        "branched": true,
        "condition": condition,
        "branched_path": {
          "on_true": onTrueSchedule,
          "on_false": onFalseSchedule,
        }
      },
      pathIndex
    );
  }
}

class SplineSet extends Spline {
  final List<Spline> splines;
  SplineSet(this.splines)
      : super(_getWaypointsFromSplineList(splines),
            commands: _getCommandsFromSplineList(splines), name: "Spline Set");
  @override
  List<Waypoint> get points => _getWaypointsFromSplineList(splines);
  @override
  List<Command> get commands => _getCommandsFromSplineList(splines);
  @override
  SplineSet copyWith(
      {List<Command>? commands, String? name, List<Waypoint>? points}) {
    List<Spline> newSplines = List<Spline>.empty(growable: true);
    for (var spline in splines) {
      newSplines.add(spline.copyWith());
    }
    return SplineSet(newSplines);
  }

  SplineSet changeSpline(int index, Spline newSpline) {
    return SplineSet([
      ...splines.indexed
          .map((spline) => spline.$1 == index ? newSpline : spline.$2)
    ]);
  }

  SplineSet moveSplineForward(int index) {
    Spline movedSpline = splines[index];
    splines[index] = splines[index + 1];
    splines[index + 1] = movedSpline;
    if (index != 0) {
      _handleFirstPoint(splines[index], splines[index - 1].points.last);
    }
    _handleFirstPoint(splines[index + 1], splines[index].points.last);
    if (index != splines.length - 2) {
      _handleFirstPoint(splines[index + 2], splines[index + 1].points.last);
    }
    return SplineSet(splines);
  }

  SplineSet moveSplineBackward(int index) {
    Spline movedSpline = splines[index];
    splines[index] = splines[index - 1];
    splines[index - 1] = movedSpline;
    if (index != 1) {
      splines[index - 1] =
          _handleFirstPoint(splines[index - 1], splines[index - 2].points.last);
    }
    splines[index] =
        _handleFirstPoint(splines[index], splines[index - 1].points.last);
    if (index != splines.length - 1) {
      splines[index + 1] =
          _handleFirstPoint(splines[index + 1], splines[index].points.last);
    }
    return SplineSet(splines);
  }

  SplineSet onSplineChanged(int index, Spline newSpline) {
    Spline updatedSpline = splines[index].copyWith(points: newSpline.points);
    splines[index] = updatedSpline;
    if (index != 0) {
      splines[index] =
          _handleFirstPoint(splines[index], splines[index - 1].points.last);
    }
    if (index != splines.length - 1) {
      splines[index + 1] =
          _handleFirstPoint(splines[index + 1], splines[index].points.last);
    }
    return SplineSet(splines);
  }

  SplineSet addSpline(Spline newSpline) {
    if (splines.isEmpty) {
      return SplineSet([newSpline]);
    }
    newSpline = _handleFirstPoint(newSpline, splines.last.points.last);
    return SplineSet([...splines, newSpline]);
  }

  SplineSet removeSpline(int index) {
    if (index == 0) {
      return SplineSet(splines.sublist(1));
    }
    if (index == splines.length - 1) {
      return SplineSet(splines.sublist(0, splines.length - 1));
    }
    splines.removeAt(index);
    if (index != splines.length - 1) {
      splines[index + 1] =
          _handleFirstPoint(splines[index + 1], splines[index].points.last);
    }
    if (index != 0) {
      splines[index] =
          _handleFirstPoint(splines[index], splines[index - 1].points.last);
    }
    return SplineSet(splines);
  }

  Spline _handleFirstPoint(Spline newSpline, Waypoint preferredPoint) {
    if (newSpline.points.isEmpty) {
      return Spline(([preferredPoint]));
    }
    if (newSpline.points.first.equals(preferredPoint)) {
      return newSpline;
    }
    return newSpline.copyWith(points: [preferredPoint, ...newSpline.points]);
  }

  (List<Map<String, dynamic>>, int) scheduleItems(int pathIndex) {
    List<Map<String, dynamic>> scheduleItems = [];
    for (var spline in splines) {
      var (splineScheduleItems, newPathIndex) = spline.scheduleItem(pathIndex);
      scheduleItems.add(splineScheduleItems);
      pathIndex = newPathIndex;
    }
    return (scheduleItems, pathIndex);
  }

  List<Map<String, dynamic>> toJsonList() {
    List<Map<String, dynamic>> jsonList = [];
    for (var spline in splines) {
      jsonList.add(spline.toJson());
    }
    return jsonList;
  }

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }

  static SplineSet fromJsonList(List scheduleList, List paths) {
    List<Spline> splines = [];
    for (var scheduleItem in scheduleList) {
      if (scheduleItem['branched']) {
        var onTrue = SplineSet.fromJsonList(
            scheduleItem["branched_path"]["on_true"], paths);
        var onFalse = SplineSet.fromJsonList(
            scheduleItem["branched_path"]["on_false"], paths);
        var condition = scheduleItem["condition"];
        splines.add(BranchedSpline(onTrue, onFalse, condition));
      } else {
        splines.add(Spline.fromJson(paths[scheduleItem['path']]));
      }
    }
    return SplineSet(splines);
  }
}

List<Waypoint> _getWaypointsFromSplineList(List<Spline> splines) {
  double duration = 0;
  List<Waypoint> waypoints = [];
  for (var spline in splines) {
    for (var point in spline.points) {
      waypoints.add(point.copyWith(t: duration + point.t));
    }
    duration += spline.duration;
  }
  return waypoints;
}

List<Command> _getCommandsFromSplineList(List<Spline> splines) {
  double duration = 0;
  List<Command> commands = [];
  for (var spline in splines) {
    for (var command in spline.commands) {
      commands.add(command.copyWith(startTime: duration + command.startTime));
      commands.add(command.copyWith(endTime: duration + command.endTime));
    }
  }
  return commands;
}
