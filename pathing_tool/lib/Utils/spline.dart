import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:pathing_tool/Utils/Structs/command.dart';
import 'package:pathing_tool/Utils/quintic_hermite_spline.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';

import 'Structs/robot_config.dart';

class Spline {
  late QuinticHermiteSpline x, y, theta;
  late List<Waypoint> points;
  final RobotConfig config;
  late List<Vectors> xVectors, yVectors, thetaVectors;
  late List<Command> commands;
  List<(double t, double s)> arcLengthMap = [];
  List<(double t, double maxVel)> maxVelocityMap = [];
  List<Waypoint> path = [];
  final String name;
  final int resolution;

  Spline(
    this.points,
    this.config,
    this.resolution, {
    this.commands = const [],
    this.name = "",
  }) {
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
    if (points.length > 1) {
      double length = 0.0;
      for (int i = (points.first.time * resolution).floor();
          i < (points.last.time * resolution).ceil();
          i++) {
        double time = i / resolution;
        if (time >= points.last.time) break;
        double dx = x.getVectors(time).velocity;
        double dy = y.getVectors(time).velocity;
        length += sqrt(dx * dx + dy * dy) / resolution;
        arcLengthMap.add((time, length));
      }
      for (int i = 0; i < arcLengthMap.length; i++) {
        double time = arcLengthMap[i].$1;
        Waypoint? point;
        for (int j = 1; j < points.length; j++) {
          if (points[j].time >= time) {
            point = points[j];
            break;
          }
        }
        double vMax = _computeVMax(
          vRobotMax: config.maxVelocity,
          aMax: config.maxAcceleration,
          aCentripetalMax: config.maxCentripetalAcceleration,
          curvature: getCurvature(time),
          distanceRemaining: getArcLength(point!.t) - getArcLength(time),
          endVelocity: point.velocityMag,
        );
        maxVelocityMap.add((time, vMax));
      }
      path.add(points.first);
      // Forward pass: compute velocity profile with acceleration limits
      for (int i = 1; i < arcLengthMap.length; i++) {
        double ds = arcLengthMap[i].$2 - arcLengthMap[i - 1].$2;
        double prevV = path[i - 1].velocityMag;
        double prevT = path[i - 1].t;
        double maxV = maxVelocityMap[i].$2;
        double newV = sqrt(prevV * prevV + 2 * config.maxAcceleration * ds);
        newV = min(newV, maxV);
        double acceleration = (newV - prevV) / (ds / prevV);
        if (acceleration.isNaN || acceleration.isInfinite) {
          acceleration = 0.0;
        }
        Vectors xVectors = x.getVectors(arcLengthMap[i].$1),
            yVectors = y.getVectors(arcLengthMap[i].$1),
            thetaVectors = theta.getVectors(arcLengthMap[i].$1);
        double aDirection = atan2(yVectors.acceleration, xVectors.acceleration);
        double vDirection = atan2(yVectors.velocity, xVectors.velocity);
        double nextT = (prevT + (ds / prevV));
        if (nextT.isNaN || nextT.isInfinite) {
          nextT = prevT;
        }
        Waypoint newWaypoint = Waypoint(
            x: xVectors.position,
            y: yVectors.position,
            theta: thetaVectors.position,
            dx: newV * cos(vDirection),
            dy: newV * sin(vDirection),
            dtheta: thetaVectors.velocity,
            d2x: acceleration * cos(aDirection),
            d2y: acceleration * sin(aDirection),
            d2theta: thetaVectors.acceleration,
            t: nextT);
        path.add(newWaypoint);
      }

      // Backward pass: enforce deceleration limits
      path[path.length - 1] = path[path.length - 1].copyWith(
        dx: path.last.velocityMag * cos(atan2(path.last.dy, path.last.dx)),
        dy: path.last.velocityMag * sin(atan2(path.last.dy, path.last.dx)),
      );
      for (int i = path.length - 2; i >= 0; i--) {
        double ds = arcLengthMap[i + 1].$2 - arcLengthMap[i].$2;
        double nextV = path[i + 1].velocityMag;
        double maxV = maxVelocityMap[i].$2;
        double newV = sqrt(nextV * nextV + 2 * config.maxAcceleration * ds);
        newV = min(path[i].velocityMag, newV);
        newV = min(newV, maxV);
        double vDirection = atan2(path[i].dy, path[i].dx);
        path[i] = path[i].copyWith(
          dx: newV * cos(vDirection),
          dy: newV * sin(vDirection),
        );
      }
    }
  }

  double getArcLength(double t) {
    if (arcLengthMap.isEmpty) return 0.0;
    if (t < points.first.time ||
        (t - points.first.time).round() * resolution < 0) return 0.0;
    if (t > points.last.time ||
        (t - points.first.time).floor() * resolution > arcLengthMap.length - 1)
      return arcLengthMap.last.$2;
    return arcLengthMap[((t - points.first.time) * resolution).floor()].$2;
  }

  double getCurvature(double t) {
    if (t < points.first.time || t > points.last.time) return 0.0;
    var x = this.x.getVectors(t);
    var y = this.y.getVectors(t);
    var curvature =
        (x.velocity * y.acceleration - y.velocity * x.acceleration) /
            pow(x.velocity * x.velocity + y.velocity * y.velocity, 1.5);
    return curvature;
  }

  double _computeVMax(
      {required double vRobotMax, // Max linear velocity of robot
      required double aMax, // Max linear acceleration
      required double aCentripetalMax, // Max centripetal acceleration
      required double curvature, // Local curvature kappa(u)
      required double
          distanceRemaining, // Remaining distance to stop or next constraint
      required double endVelocity}) {
    // Curvature-based velocity limit (centripetal acceleration)
    double vCurveMax = curvature.abs() < 1e-6
        ? double.infinity // Straight line, no centripetal limit
        : sqrt(aCentripetalMax / curvature.abs());

    // Acceleration-based velocity limit (kinematics)
    double vAccelMax = sqrt(2 * aMax * distanceRemaining) + endVelocity;
    // Final velocity limit
    return min(vRobotMax, min(vCurveMax, vAccelMax));
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

  static Spline fromPolarPathFile(
      File file, RobotConfig config, int resolution) {
    String jsonString = file.readAsStringSync();
    Map<String, dynamic> splineJson = json.decode(jsonString);
    return fromJson(splineJson, config, resolution);
  }

  static Spline fromJson(
      Map<String, dynamic> splineJson, RobotConfig config, int resolution) {
    List<Waypoint> points = [];
    splineJson["key_points"].forEach((waypointJson) {
      points.add(Waypoint.fromJson(waypointJson));
    });
    List<Command> commands = [];
    splineJson["commands"].forEach((commandJson) {
      commands.add(Command.fromJson(commandJson));
    });
    String name = splineJson["meta_data"]["path_name"];
    return Spline(points, config, resolution, commands: commands, name: name);
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
    double timeRatio =
        (path.last.t - path.first.t) / (points.last.time - points.first.time);
    double scaledTime = timeRatio * (time - points.first.time) + path.first.t;
    // print(scaledTime);
    for (var point in path) {
      if (point.t >= scaledTime) {
        return point.copyWith();
      }
    }
    return vectorsToWaypoint(
        x.getVectors(time), y.getVectors(time), theta.getVectors(time));
  }

  Waypoint getTankWaypoint(double time) {
    if (time < startTime) {
      return getTankWaypoint(startTime);
    } else if (time > endTime) {
      return getTankWaypoint(endTime);
    }
    if (points.isNotEmpty) {
      if (time < points.first.time) {
        return tankifyWaypoint(points.first.copyWith());
      } else if (time > points.last.time) {
        return tankifyWaypoint(points.last.copyWith());
      }
    }
    return vectorsToTankWaypoint(
        x.getVectors(time), y.getVectors(time), theta.getVectors(time));
  }

  Spline copyWith(
      {List<Command>? commands,
      String? name,
      List<Waypoint>? points,
      int? resolution}) {
    points = [for (var point in (points ?? this.points)) point.copyWith()];
    commands = [
      for (var command in (commands ?? this.commands)) command.copyWith()
    ];
    return Spline(points, config, resolution ?? this.resolution,
        commands: commands, name: name ?? this.name);
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
      if (points.isNotEmpty)
        "sampled_points": [
          for (double t = points.first.t; t <= points.last.t; t += 0.01)
            getRobotWaypoint(t)
        ]
    };
    return json;
  }

  Map<String, dynamic> toTankJson() {
    var json = {
      "meta_data": {"path_name": name},
      "key_points":
          points.map((Waypoint waypoint) => waypoint.toJson()).toList(),
      "commands": commands.map((Command command) => command.toJson()).toList(),
      if (points.isNotEmpty)
        "sampled_points": [
          for (double t = points.first.t; t <= points.last.t; t += 0.01)
            getTankWaypoint(t)
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
  final int resolution;
  late bool _isTrue;
  BranchedSpline(this.onTrue, this.onFalse, this.condition, this.resolution,
      {bool isTrue = true})
      : super(isTrue ? onTrue.points : onFalse.points, onTrue.config,
            onTrue.resolution,
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
      int? resolution,
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
        resolution ?? this.resolution,
        isTrue: isTrue ?? this.isTrue);
  }

  SplineSet _handleFirstPoint(SplineSet newSpline, Waypoint preferredPoint) {
    if (newSpline.splines.isEmpty) {
      return SplineSet([
        Spline([preferredPoint.copyWith(t: 0)], config, resolution)
      ], config, resolution);
    }
    if (newSpline.splines.first.points.isEmpty) {
      return SplineSet([
        Spline(([preferredPoint.copyWith(t: 0)]), config, resolution),
        ...[
          for (var spline
              in newSpline.splines.indexed.where((spline) => spline.$1 != 0))
            spline.$2
        ],
      ], config, resolution);
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
    ], config, resolution);
  }

  SplineSet _handleLastPoint(SplineSet newSpline, Waypoint preferredPoint) {
    if (newSpline.splines.isEmpty) {
      return SplineSet([
        Spline([preferredPoint.copyWith(t: 0)], config, resolution)
      ], config, resolution);
    }
    if (newSpline.splines.last.points.isEmpty) {
      return SplineSet([
        ...[
          for (var spline in newSpline.splines.indexed
              .where((spline) => spline.$1 != newSpline.splines.length - 1))
            spline.$2
        ],
        Spline(([preferredPoint.copyWith(t: 0)]), config, resolution),
      ], config, resolution);
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
    ], config, resolution);
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
  SplineSet(this.splines, RobotConfig config, int resolution)
      : super(_getWaypointsFromSplineList(splines), config, resolution,
            commands: _getCommandsFromSplineList(splines), name: "Spline Set");
  @override
  List<Waypoint> get points => _getWaypointsFromSplineList(splines);
  @override
  List<Command> get commands => _getCommandsFromSplineList(splines);
  @override
  SplineSet copyWith(
      {List<Command>? commands,
      String? name,
      List<Waypoint>? points,
      int? resolution}) {
    List<Spline> newSplines = <Spline>[];
    for (var spline in splines) {
      newSplines.add(spline.copyWith());
    }
    return SplineSet(newSplines, config, resolution ?? this.resolution);
  }

  SplineSet changeSpline(int index, Spline newSpline) {
    return SplineSet([
      ...splines.indexed
          .map((spline) => spline.$1 == index ? newSpline : spline.$2)
    ], config, resolution);
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
    return SplineSet(splines, config, resolution);
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
    return SplineSet(splines, config, resolution);
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
    return SplineSet(splines, config, resolution);
  }

  SplineSet addSpline(Spline newSpline) {
    if (splines.isEmpty) {
      return SplineSet([newSpline], config, resolution);
    }
    newSpline = _handleFirstPoint(newSpline, splines.last.points.last);
    return SplineSet([...splines, newSpline], config, resolution);
  }

  SplineSet removeSpline(int index) {
    if (index == 0) {
      return SplineSet(splines.sublist(1), config, resolution);
    }
    if (index == splines.length - 1) {
      return SplineSet(
          splines.sublist(0, splines.length - 1), config, resolution);
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
    return SplineSet(splines, config, resolution);
  }

  Spline _handleFirstPoint(Spline newSpline, Waypoint preferredPoint) {
    if (newSpline.points.isEmpty) {
      return Spline(([preferredPoint]), config, resolution);
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

  static SplineSet fromJsonList(
      List scheduleList, List paths, RobotConfig config, int resolution) {
    List<Spline> splines = [];
    for (var scheduleItem in scheduleList) {
      if (scheduleItem['branched']) {
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
        splines.add(
            Spline.fromJson(paths[scheduleItem['path']], config, resolution));
      }
    }
    return SplineSet(splines, config, resolution);
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
