import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pathing_tool/Pages/autos_page.dart';
import 'package:pathing_tool/Widgets/custom_app_bar.dart';
import 'package:simple_snowfall/snows/snowfall_widget.dart';

import '../Widgets/app_drawer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _newPath(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => const AutosPage([], "")));
  }

  void _loadPath(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title:
              Text("Load File From Where?", style: theme.textTheme.titleLarge),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                ListTile(
                  title: const Text("From Computer"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _loadPathFromFiles(context);
                  },
                ),
                ListTile(
                  title: const Text("From Robot"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _loadPathFromRobot(context);
                  },
                )
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                "Close",
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        );
      },
    );
  }

  void _loadPathFromFiles(BuildContext context) async {
    final navigator = Navigator.of(context);
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['polarauto'],
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      File pathFile = File(path);
      navigator.push(
          MaterialPageRoute(
              builder: (BuildContext context) => AutosPage.fromFile(pathFile)));
    }
  }

  void _loadPathFromRobot(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        List<String> robotIPs = ["10.44.99.2", "172.22.11.2", "42.42.42.42"];

        Future<List<SftpName>> _getClientAndListFiles() async {
          SSHClient? robotClient;
          for (String robotIP in robotIPs) {
            try {
              robotClient = SSHClient(await SSHSocket.connect(robotIP, 22),
                  username: "lvuser");
              break;
            } catch (error) {
              print("Error connecting to $robotIP: $error");
            }
          }
          if (robotClient == null) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to connect to any robot")),
            );
            return [];
          }

          try {
            final robotSFTP = await robotClient.sftp();
            final fileList = await robotSFTP.listdir("./deploy/");
            return fileList.where((file) {
              return file.filename.split(".").last == "polarauto";
            }).toList();
          } catch (e) {
            print("Error listing files: $e");
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to list files on robot")),
            );
            return [];
          }
        }
        
        return FutureBuilder<List<SftpName>>(
          future: _getClientAndListFiles(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                title: Text("Robot Files", style: theme.textTheme.titleLarge),
                content: const Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return AlertDialog(
                title: Text("Robot Files", style: theme.textTheme.titleLarge),
                content:
                    const Text("No files found or failed to retrieve files."),
              );
            } else {
              final polarAutoList = snapshot.data!;
              return AlertDialog(
                title: Text("Robot Files", style: theme.textTheme.titleLarge),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: polarAutoList.map((autoFile) {
                      return ListTile(
                        title: Text(autoFile.filename),
                        onTap: () {
                          _newAutoEditorFromSftpName(autoFile, context);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  void _newAutoEditorFromSftpName(SftpName name, BuildContext context) async {
    List<String> robotIPs = ["10.44.99.2", "172.22.11.2", "42.42.42.42"];
    final navigator = Navigator.of(context);
    SSHClient? robotClient;
    for (String robotIP in robotIPs) {
      try {
        robotClient =
            SSHClient(await SSHSocket.connect(robotIP, 22), username: "lvuser");
        break;
      } catch (error) {}
    }
    if (robotClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to connect to any robot")),
      );
      return;
    }
    final robotSFTP = await robotClient.sftp();
    final file = await robotSFTP.open("./deploy/${name.filename}");
    final fileContent = await file.readBytes();
    final fileContentJSON = json.decode(utf8.decode(fileContent));
    robotSFTP.close();
    navigator.push(
      MaterialPageRoute(
        builder: (context) => AutosPage.fromJson(fileContentJSON),
      ),);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(children: [
          SnowfallWidget(
            gravity: 1,
            windIntensity: 1,
            numberOfSnowflakes: 250,
            size: MediaQuery.of(context).size,
            // Change the snowflake size or other properties if needed
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 16.0),
                        ElevatedButton(
                          onPressed: () => _newPath(context),
                          child: const Text('Create New Auto'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 16.0),
                        ElevatedButton(
                          onPressed: () => _loadPath(context),
                          child: const Text('Load Auto'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          )
        ]),
      ),
    );
  }
}
