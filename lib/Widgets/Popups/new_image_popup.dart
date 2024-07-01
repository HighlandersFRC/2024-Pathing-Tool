import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathing_tool/Utils/Structs/image_data.dart';
import 'package:pathing_tool/Utils/Providers/image_data_provider.dart';
import 'package:provider/provider.dart';
class AddImagePopup extends StatefulWidget {
  const AddImagePopup({super.key});

  @override
  _AddImagePopupState createState() => _AddImagePopupState();
}

class _AddImagePopupState extends State<AddImagePopup> {
  String _filePath = "";
  bool fieldsFilled = true;
  final TextEditingController _imageNameContreller = TextEditingController();
  final TextEditingController _widthMetersController = TextEditingController();
  final TextEditingController _heightMetersController = TextEditingController();
  final TextEditingController _widthPixelsController = TextEditingController();
  final TextEditingController _heightPixelsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add New Image'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
                onPressed: () async {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles(type: FileType.image);
                  if (result != null) {
                    setState(() {
                      _filePath = result.files.single.path!;
                    });
                  }
                },
                style: ButtonStyle(
                    foregroundColor:
                        WidgetStateProperty.all(theme.primaryColor)),
                child: const Text("Select a File")),
            if (_filePath.isNotEmpty)
              Image.file(
                File(_filePath),
                width: 225,
              ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _imageNameContreller,
              decoration: InputDecoration(
                  labelText: 'Field Name',
                  focusColor: theme.primaryColor,
                  hoverColor: theme.primaryColor,
                  floatingLabelStyle: TextStyle(color: theme.primaryColor),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.primaryColor))),
              keyboardType: TextInputType.text,
              cursorColor: theme.primaryColor,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _widthMetersController,
              decoration: InputDecoration(
                  labelText: 'Image Width (meters)',
                  focusColor: theme.primaryColor,
                  hoverColor: theme.primaryColor,
                  floatingLabelStyle: TextStyle(color: theme.primaryColor),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.primaryColor))),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              cursorColor: theme.primaryColor,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _heightMetersController,
              decoration: InputDecoration(
                  labelText: 'Image Height (meters)',
                  focusColor: theme.primaryColor,
                  hoverColor: theme.primaryColor,
                  floatingLabelStyle: TextStyle(color: theme.primaryColor),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.primaryColor))),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _widthPixelsController,
              decoration: InputDecoration(
                  labelText: 'Image Width (pixels)',
                  focusColor: theme.primaryColor,
                  hoverColor: theme.primaryColor,
                  floatingLabelStyle: TextStyle(color: theme.primaryColor),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.primaryColor))),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _heightPixelsController,
              decoration: InputDecoration(
                  labelText: 'Image Height (pixels)',
                  focusColor: theme.primaryColor,
                  hoverColor: theme.primaryColor,
                  floatingLabelStyle: TextStyle(color: theme.primaryColor),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.primaryColor))),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              keyboardType: TextInputType.number,
            ),
            if (!fieldsFilled)
              const SizedBox(height: 10),
            if (!fieldsFilled)
              const Text(
                "Please Fill All Fields",
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all(theme.primaryColor)),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          child: const Text('Add'),
          onPressed: () {
            // Validate input
            if (_filePath.isEmpty ||
                _widthMetersController.text.isEmpty ||
                _heightMetersController.text.isEmpty ||
                _widthPixelsController.text.isEmpty ||
                _heightPixelsController.text.isEmpty) {
              setState(() {
                fieldsFilled = false;
              });
              return;
            }

            // Create ImageData object
            ImageData newImage = ImageData(
              image: Image.file(File(_filePath)),
              imageName: _imageNameContreller.text,
              imageWidthInMeters: double.parse(_widthMetersController.text),
              imageHeightInMeters: double.parse(_heightMetersController.text),
              imageWidthInPixels: double.parse(_widthPixelsController.text),
              imageHeightInPixels: double.parse(_heightPixelsController.text),
            );

            // Add image using ImageDataProvider
            Provider.of<ImageDataProvider>(context, listen: false)
                .addImage(newImage);

            // Clear input fields
            _imageNameContreller.clear();
            _widthMetersController.clear();
            _heightMetersController.clear();
            _widthPixelsController.clear();
            _heightPixelsController.clear();

            // Close the dialog
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
