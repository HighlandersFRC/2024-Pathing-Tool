import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pathing_tool/Pages/pathing_page.dart';
import 'package:pathing_tool/Widgets/custom_app_bar.dart';

import '../Widgets/app_drawer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _newPath(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => const PathingPage([], "")));
  }

  void _loadPath(BuildContext context) async {
    // Allow the user to pick a file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['polarpath'],
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      File pathFile = File(path);
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (BuildContext context) =>
                  PathingPage.fromFile(pathFile)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const CustomAppBar(),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'New Path',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16.0),
                      ElevatedButton(
                        onPressed: () => _newPath(context),
                        child: const Text('Create New Path'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Load Path',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16.0),
                      ElevatedButton(
                        onPressed: () => _loadPath(context),
                        child: const Text('Load Path'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
