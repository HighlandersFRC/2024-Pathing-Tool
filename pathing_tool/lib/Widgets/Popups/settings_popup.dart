import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pathing_tool/Theme/theme_notifier.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:pathing_tool/Utils/Structs/image_data.dart';
import 'package:pathing_tool/Utils/Providers/image_data_provider.dart';
import 'package:pathing_tool/Utils/Structs/robot_config.dart';
import 'package:pathing_tool/Widgets/Popups/new_image_popup.dart';
import 'package:pathing_tool/Widgets/Popups/robot_config_popup.dart';
import 'package:provider/provider.dart';

// Import your ImageData class here

class SettingsPopup extends StatelessWidget {
  const SettingsPopup({super.key});

  void _openAddImagePopup(BuildContext context,
      {String? name,
      Image? image,
      double widthPixels = 0,
      double heightPixels = 0,
      double widthMeters = 0,
      double heightMeters = 0,
      void Function()? onSubmit}) {
    showDialog(
      context: context,
      builder: (context) => AddImagePopup(
        name: name ?? "",
        image: image,
        widthMeters: widthMeters,
        widthPixels: widthPixels,
        heightMeters: heightMeters,
        heightPixels: heightPixels,
        onSubmit: onSubmit,
      ),
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
                              title: Image(
                                image: imageData.image.image,
                                height: 250,
                              ),
                              leading: Text(imageData.imageName),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _openAddImagePopup(context,
                                      name: imageData.imageName,
                                      image: imageData.image,
                                      widthMeters: imageData.imageWidthInMeters,
                                      widthPixels: imageData.imageWidthInPixels,
                                      heightMeters:
                                          imageData.imageHeightInMeters,
                                      heightPixels: imageData
                                          .imageHeightInPixels, onSubmit: () {
                                    imageDataProvider.removeImage(imageData);
                                  });
                                },
                                child: const Text("Edit"),
                              ),
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

  void _openChangeRobotPopup(BuildContext context) {
    final robotConfigProvider =
        Provider.of<RobotConfigProvider>(context, listen: false);
    final List<RobotConfig> robotConfigs = robotConfigProvider.robotConfigs;
    final theme = Theme.of(context);
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Pick a Robot"),
              content: SingleChildScrollView(
                child: robotConfigs.isNotEmpty
                    ? ListBody(
                        children: [
                          ...robotConfigs.map((RobotConfig robotConfig) {
                            return ListTile(
                              title: Text(robotConfig.name),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _openRobotConfigPopup(context, robotConfig, newRobot: false);
                                },
                                child: const Text("Edit"),
                              ),
                              onTap: () {
                                robotConfigProvider.setRobotConfig(robotConfig);
                                Navigator.pop(context);
                              },
                            );
                          }),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _openRobotConfigPopup(context, RobotConfig("", 1, 1, List<IconCommand>.empty(), List<IconCondition>.empty()), newRobot: true);
                            },
                            child: Text(
                              "Add a Robot",
                              style: TextStyle(color: theme.primaryColor),
                            ),
                          )
                        ],
                      )
                    : ListBody(children: [
                        const Text("No Robots Found"),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _openRobotConfigPopup(context, RobotConfig("", 1, 1, List<IconCommand>.empty(), List<IconCondition>.empty()), newRobot: true);
                          },
                          child: Text(
                            "Add a Robot",
                            style: TextStyle(color: theme.primaryColor),
                          ),
                        )
                      ]),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
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

  void _openRobotConfigPopup(BuildContext context, RobotConfig startingConfig, {bool newRobot = true}) {
    showDialog(
      context: context,
      builder: (context) => RobotConfigPopup(
        newRobot: newRobot,
        startingConfig: startingConfig,
      ),
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
              title: const Text('Change Robot'),
              onTap: () {
                _openChangeRobotPopup(context);
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
