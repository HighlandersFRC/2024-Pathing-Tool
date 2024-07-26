import 'dart:math';
import 'package:matrices/matrices.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';

class QuinticHermiteSpline {
  late int numSegments;
  late List<Matrix> segmentCoefficients;
  late List<Vectors> vectors;
  late List<Matrix> segmentVectors;
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
    }
  }

  Vectors getVectors(double time) {
    int segmentIdx = 0;
    for (int i = 1; i < numSegments + 1; i++) {
      if (time < vectors[i].time) {
        segmentIdx = i - 1;
        break;
      }
    }
    double adjustedTime = (time - vectors[segmentIdx].time) /
        (vectors[segmentIdx + 1].time -
            vectors[segmentIdx].time); // Making a time between 0 and 1
    Matrix position = Matrix.fromList([
          List.generate(6, (int index) {
            return pow(adjustedTime, index) as double;
          }),
        ]) *
        segmentCoefficients[segmentIdx];
    Matrix velocity = Matrix.fromList([
          List.generate(6, (int index) {
            return index == 0
                ? 0
                : index * pow(adjustedTime, index - 1) as double;
          }),
        ]) *
        segmentCoefficients[segmentIdx];
    Matrix acceleration = Matrix.fromList([
          List.generate(6, (int index) {
            return index <= 1
                ? 0
                : index * (index - 1) * pow(adjustedTime, index - 2) as double;
          }),
        ]) *
        segmentCoefficients[segmentIdx];
    return Vectors(
        position: position[0][0],
        velocity: velocity[0][0],
        acceleration: acceleration[0][0],
        time: time);
  }
}
