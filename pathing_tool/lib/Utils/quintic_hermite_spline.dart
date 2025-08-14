import 'package:matrices/matrices.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';

/// A class representing a Quintic Hermite Spline, which is a type of spline
/// interpolation that uses quintic (fifth-degree) polynomials to smoothly
/// interpolate between points. This spline ensures continuity of position,
/// velocity, and acceleration at the control points, making it suitable for
/// smooth path generation in robotics, animation, and other applications
/// requiring smooth motion profiles.
class QuinticHermiteSpline {
  late int numSegments;
  late List<Matrix> segmentCoefficients;
  late List<Vectors> vectors;
  late List<Matrix> segmentVectors;
  late List<double> segmentDurations;
  final Matrix scale = Matrix.fromList(
    [
      [1, 0, 0, 0, 0, 0],
      [0, 1, 0, 0, 0, 0],
      [0, 0, 0.5, 0, 0, 0],
      [-10, -6, -1.5, 10, -4, 0.5],
      [15, 8, 1.5, -15, 7, -1],
      [-6, -3, -0.5, 6, -3, 0.5],
    ],
  );

  QuinticHermiteSpline(this.vectors) {
    numSegments = vectors.length - 1;
    if (numSegments >= 1) {
      segmentVectors = List.generate(numSegments, (int index) {
        return Matrix.fromList([
          [vectors[index].position],
          [vectors[index].velocity],
          [vectors[index].acceleration],
          [vectors[index + 1].position],
          [vectors[index + 1].velocity],
          [vectors[index + 1].acceleration],
        ]);
      });
      segmentCoefficients = List.generate(numSegments, (int index) {
        return scale * segmentVectors[index];
      });
      segmentDurations = List.generate(numSegments, (int index) {
        if (vectors.length - 1 > index) {
          return vectors[index + 1].time - vectors[index].time;
        }
        return 1;
      });
    }
  }

  Vectors getVectors(double time) {
    if (numSegments == 0) return vectors[0];

    int segmentIdx = 0;
    for (int i = 1; i < numSegments + 1; i++) {
      if (time < vectors[i].time) {
        segmentIdx = i - 1;
        break;
      }
    }

    double dt = segmentDurations[segmentIdx];
    double adjustedTime = (time - vectors[segmentIdx].time) / dt;

    // Precompute powers
    List<double> tPowers = List.filled(6, 1.0);
    for (int i = 1; i < 6; i++) {
      tPowers[i] = tPowers[i - 1] * adjustedTime;
    }

    // Direct evaluation
    double pos = 0, vel = 0, acc = 0;
    for (int i = 0; i < 6; i++) {
      double c = segmentCoefficients[segmentIdx][i][0];
      pos += c * tPowers[i];
      if (i > 0) vel += c * i * tPowers[i - 1];
      if (i > 1) acc += c * i * (i - 1) * tPowers[i - 2];
    }

    return Vectors(position: pos, velocity: vel, acceleration: acc, time: time);
  }

  List<double> getPositionFunction(int segmentIndex) {
    if (segmentIndex < 0 || segmentIndex >= numSegments) {
      throw RangeError('Segment index out of range');
    }
    List<double> row = segmentCoefficients[segmentIndex].column(0);
    return row;
  }

  int getNumSegments() {
    return numSegments;
  }
}
