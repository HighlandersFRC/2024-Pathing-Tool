import 'package:flutter/material.dart';

class ImageData {
  Image image;
  String imageName;
  double imageWidthInMeters;
  double imageHeightInMeters;
  double imageWidthInPixels;
  double imageHeightInPixels;

  ImageData({
    required this.image,
    required this.imageName,
    required this.imageWidthInMeters,
    required this.imageHeightInMeters,
    required this.imageWidthInPixels,
    required this.imageHeightInPixels,
  });
}
