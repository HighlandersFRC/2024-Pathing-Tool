import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pathing_tool/Pages/autos_page.dart';
import 'package:pathing_tool/Utils/Providers/image_data_provider.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:provider/provider.dart';
import 'Pages/home_page.dart';
import 'Theme/theme_notifier.dart';

void main() {
  Directory("C:/Polar Pathing/Robots").createSync(recursive: true);
  Directory("C:/Polar Pathing/Saves").createSync(recursive: true);
  Directory("C:/Polar Pathing/Images").createSync(recursive: true);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => RobotConfigProvider()),
        ChangeNotifierProvider(create: (_) => ImageDataProvider()),
      ],
      child: MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
   
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          home: Builder(
            builder: (context) => const HomePage(), // Wrap your home page with Builder
          ),
          theme: themeNotifier.themeData,
          routes: {
            '/home': (context) => const HomePage(),
            '/autos': (context) => const AutosPage([], ""),
          },
        );
      }
    );
  }
}


// Helper function to create a MaterialColor from a Color
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}
