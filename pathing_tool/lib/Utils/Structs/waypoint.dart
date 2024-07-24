import 'dart:math';

class Waypoint {
  final double x;
  final double y;
  final double theta;
  final double dx;
  final double dy;
  final double dtheta;
  final double d2x;
  final double d2y;
  final double d2theta;
  final double t;

  Waypoint({
    required this.x,
    required this.y,
    required this.theta,
    required this.dx,
    required this.dy,
    required this.dtheta,
    required this.d2x,
    required this.d2y,
    required this.d2theta,
    required this.t,
  });

  double get time => t;

  double get velocityMag => sqrt(pow(dx, 2) + pow(dy, 2));

  double get accelerationMag => sqrt(pow(d2x, 2) + pow(d2y, 2));

  Vectors getXVectors() {
    return Vectors(position: x, velocity: dx, acceleration: d2x, time: t);
  }

  Vectors getYVectors() {
    return Vectors(position: y, velocity: dy, acceleration: d2y, time: t);
  }

  Vectors getThetaVectors() {
    return Vectors(
        position: theta, velocity: dtheta, acceleration: d2theta, time: t);
  }

  static Waypoint fromJson(Map<String, dynamic> waypointJson){
    return Waypoint(
          x: waypointJson["x"],
          y: waypointJson["y"],
          theta: waypointJson["angle"],
          dx: waypointJson["x_velocity"],
          dy: waypointJson["y_velocity"],
          dtheta: waypointJson["angular_velocity"],
          d2x: waypointJson["x_acceleration"],
          d2y: waypointJson["y_acceleration"],
          d2theta: waypointJson["angular_acceleration"],
          t: waypointJson["time"]);
  }

  Waypoint copyWith({
    double? x,
    double? y,
    double? theta,
    double? dx,
    double? dy,
    double? dtheta,
    double? d2x,
    double? d2y,
    double? d2theta,
    double? t,
  }) {
    return Waypoint(
      x: x ?? this.x,
      y: y ?? this.y,
      theta: theta ?? this.theta,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      dtheta: dtheta ?? this.dtheta,
      d2x: d2x ?? this.d2x,
      d2y: d2y ?? this.d2y,
      d2theta: d2theta ?? this.d2theta,
      t: t ?? this.t,
    );
  }
  
  bool equals(Waypoint other) {
    return (x == other.x &&
        y == other.y &&
        theta == other.theta &&
        dx == other.dx &&
        dy == other.dy &&
        dtheta == other.dtheta &&
        d2x == other.d2x &&
        d2y == other.d2y &&
        d2theta == other.d2theta);
  }
}

class Vectors {
  final double position, velocity, acceleration, time;
  Vectors(
      {required this.position,
      required this.velocity,
      required this.acceleration,
      required this.time});
}

Waypoint vectorsToWaypoint(Vectors x, Vectors y, Vectors theta) {
  return Waypoint(
      x: x.position,
      y: y.position,
      theta: theta.position,
      dx: x.velocity,
      dy: y.velocity,
      dtheta: theta.velocity,
      d2x: x.acceleration,
      d2y: y.acceleration,
      d2theta: theta.acceleration,
      t: x.time);
}
