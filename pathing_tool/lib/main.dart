import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pathing_tool/Pages/autos_page.dart';
import 'package:pathing_tool/Utils/Providers/image_data_provider.dart';
import 'package:pathing_tool/Utils/Providers/preference_provider.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:provider/provider.dart';
import 'Pages/home_page.dart';
import 'Theme/theme_notifier.dart';

void main() {
  Directory("C:/Polar Pathing/Robots").createSync(
      recursive: true); // Create necessary directories if they don't exist
  Directory("C:/Polar Pathing/Saves").createSync(recursive: true);
  Directory("C:/Polar Pathing/Images").createSync(recursive: true);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) =>
                ThemeNotifier()), // Manages app theme (light/dark), Colors
        ChangeNotifierProvider(
            create: (_) =>
                RobotConfigProvider()), // Manages robot configuration (dimensions, max speeds, etc)
        ChangeNotifierProvider(
            create: (_) =>
                ImageDataProvider()), // Manages field image data (images, dimensions, etc)
        ChangeNotifierProvider(
            create: (_) =>
                PreferenceProvider()), // Manages user preferences (settings, selected configurations, etc)
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(builder: (context, themeNotifier, child) {
      return MaterialApp(
        home: const HomePage(),
        theme: themeNotifier.themeData,
        routes: {
          // Routing is not used for navigation
          '/home': (context) => const HomePage(),
          '/autos': (context) => const AutosPage([], ""),
        },
      );
    });
  }
}
