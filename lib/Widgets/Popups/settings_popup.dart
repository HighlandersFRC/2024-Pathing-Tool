import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pathing_tool/Theme/theme_notifier.dart';
import 'package:pathing_tool/Utils/Structs/image_data.dart';
import 'package:pathing_tool/Utils/Providers/image_data_provider.dart';
import 'package:pathing_tool/Widgets/Popups/new_image_popup.dart';
import 'package:pathing_tool/Widgets/Popups/robot_config_popup.dart';
import 'package:provider/provider.dart';

// Import your ImageData class here

class SettingsPopup extends StatelessWidget {
  const SettingsPopup({super.key});


  void _openAddImagePopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddImagePopup(),
    );
  }

  void _openChangeImagePopup(BuildContext context) {
    final imageDataProvider =
        Provider.of<ImageDataProvider>(context, listen: false);
    final List<ImageData> images = imageDataProvider.images;

    final theme = Theme.of(context);
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Pick a Field Image"),
              content: SingleChildScrollView(
                child: images.isNotEmpty
                    ? ListBody(
                        children: [
                          ...images.map((ImageData imageData) {
                            return ListTile(
                              title: Image(image: imageData.image.image, height: 250,),
                              trailing: Text(imageData.imageName),
                              onTap: () {
                                imageDataProvider.selectImage(imageData);
                                Navigator.pop(context);
                              },
                            );
                          }),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _openAddImagePopup(context);
                            },
                            child: Text(
                              "Add an Image",
                              style: TextStyle(color: theme.primaryColor),
                            ),
                          )
                        ],
                      )
                    : ListBody(children: [
                        const Text("No Field Image Files"),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _openAddImagePopup(context);
                          },
                          child: Text(
                            "Add an Image",
                            style: TextStyle(color: theme.primaryColor),
                          ),
                        )
                      ]),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ButtonStyle(
                    foregroundColor:
                        WidgetStateProperty.all(theme.primaryColor),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ));
  }

  void _openColorPicker(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        Color pickerColor = theme.primaryColor;
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                pickerColor = Colors.blue;
                themeNotifier.setTheme(pickerColor);
                Navigator.of(context).pop();
              },
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(theme.primaryColor),
              ),
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () {
                themeNotifier.setTheme(pickerColor);
                Navigator.of(context).pop();
              },
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(theme.primaryColor),
              ),
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  void _openRobotConfigPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RobotConfigPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Change Theme Color'),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              onTap: () {
                _openColorPicker(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: themeNotifier.themeData.brightness == Brightness.dark,
                onChanged: (value) {
                  themeNotifier.toggleTheme();
                },
                activeColor: theme.primaryColor,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Change Field Image'),
              onTap: () {
                _openChangeImagePopup(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Robot Config'),
              onTap: () {
                _openRobotConfigPopup(context);
              },
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
            foregroundColor: WidgetStateProperty.all(theme.primaryColor),
          ),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
