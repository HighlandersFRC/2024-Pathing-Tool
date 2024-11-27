import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_converter/flutter_image_converter.dart';
import 'package:pathing_tool/Utils/Structs/image_data.dart';

class ImageDataProvider extends ChangeNotifier {
  final List<ImageData> _images = [];
  ImageData _selectedImage = ImageData(
    image: Image.asset("Images/game_field.png"),
    imageHeightInMeters: 8.211,
    imageHeightInPixels: 3812,
    imageName: "2024 FRC Game Field",
    imageWidthInMeters: 16.65,
    imageWidthInPixels: 7680,
  );

  ImageDataProvider() {
    Directory imageDir = Directory("C:/Polar Pathing/Images");
    if (imageDir.existsSync()) {
      imageDir.createSync(recursive: true);
    }
    var imageFiles = imageDir.listSync();
    ZipDecoder decoder = ZipDecoder();
    for (var imageFile in imageFiles) {
      if (imageFile is File) {
        if (imageFile.path.split('.').last == "polarimgprefs") {
          final bytes = imageFile.readAsBytesSync();
          final archive = decoder.decodeBytes(bytes);
          String name = '2024 FRC Game Field';
          double wm = 16.65, wp = 7680, hm = 8.211, hp = 3812;
          Image image = Image.asset("Images/game_field.png");
          for (ArchiveFile file in archive) {
            if (file.name == "image_data.json") {
              String imageDataJsonString = utf8.decode(file.content);
              Map<String, dynamic> imageDataJson =
                  json.decode(imageDataJsonString);
              name = imageDataJson['name'];
              wm = imageDataJson['width_meters'];
              hm = imageDataJson['height_meters'];
              wp = imageDataJson['width_pixels'];
              hp = imageDataJson['height_pixels'];
            } else if (file.name == "image.png") {
              image = Image.memory(file.content);
            }
          }
          _selectedImage = ImageData(
              image: image,
              imageName: name,
              imageWidthInMeters: wm,
              imageHeightInMeters: hm,
              imageWidthInPixels: wp,
              imageHeightInPixels: hp);
        } else {
          final bytes = imageFile.readAsBytesSync();
          final archive = decoder.decodeBytes(bytes);
          String name = '2024 FRC Game Field';
          double wm = 16.65, wp = 7680, hm = 8.211, hp = 3812;
          Image image = Image.asset("Images/game_field.png");
          for (ArchiveFile file in archive) {
            if (file.name == "image_data.json") {
              String imageDataJsonString = utf8.decode(file.content);
              Map<String, dynamic> imageDataJson =
                  json.decode(imageDataJsonString);
              name = imageDataJson['name'];
              wm = imageDataJson['width_meters'];
              hm = imageDataJson['height_meters'];
              wp = imageDataJson['width_pixels'];
              hp = imageDataJson['height_pixels'];
            } else if (file.name == "image.png") {
              image = Image.memory(file.content);
            }
          }
          _images.add(ImageData(
              image: image,
              imageName: name,
              imageWidthInMeters: wm,
              imageHeightInMeters: hm,
              imageWidthInPixels: wp,
              imageHeightInPixels: hp));
        }
      }
    }
  }

  List<ImageData> get images => _images;
  ImageData get selectedImage => _selectedImage;

  Future<void> addImage(ImageData imageData) async {
    _images.add(imageData);
    _selectedImage = imageData;
    notifyListeners();
    Map<String, dynamic> imageDataJson = <String, dynamic>{
      'name': imageData.imageName,
      'width_meters': imageData.imageWidthInMeters,
      'width_pixels': imageData.imageWidthInPixels,
      'height_meters': imageData.imageHeightInMeters,
      'height_pixels': imageData.imageHeightInPixels,
    };
    var imageDataJsonString = json.encode(imageDataJson);
    ArchiveFile jsonArchive = ArchiveFile("image_data.json",
        imageDataJsonString.length, utf8.encode(imageDataJsonString));
    var bytes = await imageData.image.image.pngUint8List;
    ArchiveFile imageArchive = ArchiveFile("image.png", bytes.length, bytes);
    Archive archive = Archive();
    archive.addFile(jsonArchive);
    archive.addFile(imageArchive);
    var zippedArchive = ZipEncoder().encode(archive);
    File outputFile =
        File("C:/Polar Pathing/Images/${imageData.imageName}.polarimg");
    outputFile.writeAsBytesSync(zippedArchive!);
  }

  Future<void> selectImage(ImageData imageData) async {
    _selectedImage = imageData;
    notifyListeners();
    Map<String, dynamic> imageDataJson = <String, dynamic>{
      'name': imageData.imageName,
      'width_meters': imageData.imageWidthInMeters,
      'width_pixels': imageData.imageWidthInPixels,
      'height_meters': imageData.imageHeightInMeters,
      'height_pixels': imageData.imageHeightInPixels,
    };
    var imageDataJsonString = json.encode(imageDataJson);
    ArchiveFile jsonArchive = ArchiveFile("image_data.json",
        imageDataJsonString.length, utf8.encode(imageDataJsonString));
    var bytes = await imageData.image.image.pngUint8List;
    ArchiveFile imageArchive = ArchiveFile("image.png", bytes.length, bytes);
    Archive archive = Archive();
    archive.addFile(jsonArchive);
    archive.addFile(imageArchive);
    var zippedArchive = ZipEncoder().encode(archive);
    File outputFile =
        File("C:/Polar Pathing/Images/ImagePreferences.polarimgprefs");
    outputFile.writeAsBytesSync(zippedArchive!);
  }

  void removeImage(ImageData imageData) {
    _images.remove(imageData);
    var imageDir = Directory("C:/Polar Pathing/Images");
    for (var imageFile in imageDir.listSync()) {
      if (imageFile is File &&
          imageFile.path.endsWith("${imageData.imageName}.polarimg")) {
        imageFile.deleteSync();
      }
    }
    notifyListeners();
  }
}
