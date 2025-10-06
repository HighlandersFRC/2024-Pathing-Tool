import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
  ); // Default Image

  ImageDataProvider() {
    _refreshImages();
  }

  String _getRepositoryPath() {
    // Get the path the the connected repository from preferences file
    String repoPath = 'C:';
    try {
      Directory prefDir = Directory("C:/Polar Pathing/Preferences");
      File? preferencesFile;
      ZipDecoder decoder = ZipDecoder();
      prefDir.listSync().forEach((file) {
        if (file.path.split(".").last == "polarprefs") {
          preferencesFile = file as File;
        }
      });
      if (preferencesFile != null) {
        final Uint8List prefBytes = preferencesFile!.readAsBytesSync();
        Archive prefArchive = decoder.decodeBytes(prefBytes);
        for (ArchiveFile file in prefArchive) {
          if (file.name == "config.json") {
            String jsonString = utf8.decode(file.content);
            Map<String, dynamic> preferredConfigJson = json.decode(jsonString);
            repoPath = preferredConfigJson["repository_path"] ?? "C:";
            break;
          }
        }
      }
    } catch (e) {
      // Handle error if necessary
    }
    return repoPath;
  }

  void _refreshImages() {
    // Load Images from the repository
    _images.clear();
    String repoPath = _getRepositoryPath();
    Directory imageDir = Directory("$repoPath/Polar Pathing/Images");
    if (!imageDir.existsSync()) {
      imageDir.createSync(recursive: true);
    }
    var imageFiles = imageDir.listSync();
    ZipDecoder decoder = ZipDecoder();
    File preferencesFile =
        File("C:/Polar Pathing/Images/ImagePreferences.polarimgprefs");
    // Load Selected Image from Preferences
    if (preferencesFile.existsSync()) {
      final bytes = preferencesFile.readAsBytesSync();
      final archive = decoder.decodeBytes(bytes);
      String name = '2024 FRC Game Field';
      double wm = 16.65, wp = 7680, hm = 8.211, hp = 3812;
      Image image = Image.asset("Images/game_field.png");
      for (ArchiveFile file in archive) {
        if (file.name == "image_data.json") {
          String imageDataJsonString = utf8.decode(file.content);
          Map<String, dynamic> imageDataJson = json.decode(imageDataJsonString);
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
    }
    // Load All Images from the Images Directory
    for (var imageFile in imageFiles) {
      if (imageFile is File) {
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
        final data = ImageData(
            image: image,
            imageName: name,
            imageWidthInMeters: wm,
            imageHeightInMeters: hm,
            imageWidthInPixels: wp,
            imageHeightInPixels: hp);
        _images.add(data);
        if (name == _selectedImage.imageName) {
          _selectedImage = data;
        }
      }
    }
    notifyListeners();
  }

  List<ImageData> get images => _images;
  ImageData get selectedImage => _selectedImage;

  Future<void> addImage(ImageData imageData) async {
    // Add a new image to the provider and save it in runtime
    _images.add(imageData);
    _selectedImage = imageData;
    notifyListeners();
    // Save the image to the Images directory
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
    final zippedArchive = ZipEncoder().encode(archive);
    String repoPath = _getRepositoryPath();
    File outputFile =
        File("$repoPath/Polar Pathing/Images/${imageData.imageName}.polarimg");
    outputFile.writeAsBytesSync(zippedArchive!);
  }

  Future<void> selectImage(ImageData imageData) async {
    // Select an image for the current runtime
    _selectedImage = imageData;
    notifyListeners();
    // Save the selected image to the preferences file
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
    final zippedArchive = ZipEncoder().encode(archive);
    File outputFile =
        File("C:/Polar Pathing/Images/ImagePreferences.polarimgprefs");
    outputFile.writeAsBytesSync(zippedArchive!);
  }

  void removeImage(ImageData imageData) {
    // Remove an image from the provider and delete it from the Images directory
    _images.remove(imageData);
    String repoPath = _getRepositoryPath();
    var imageDir = Directory("$repoPath/Polar Pathing/Images");
    for (var imageFile in imageDir.listSync()) {
      if (imageFile is File &&
          imageFile.path.endsWith("${imageData.imageName}.polarimg")) {
        imageFile.deleteSync();
      }
    }
    notifyListeners();
  }

  void refresh() {
    // Refresh the list of images from the Images directory
    _refreshImages();
  }
}
