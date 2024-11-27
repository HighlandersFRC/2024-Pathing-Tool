import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pathing_tool/Pages/autos_page.dart';
import 'Popups/settings_popup.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

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
      navigator.push(MaterialPageRoute(
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
        robotClient = SSHClient(
            await SSHSocket.connect(robotIP, 22, timeout: Duration(seconds: 5)),
            username: "lvuser");
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                DrawerHeader(
                  decoration: BoxDecoration(color: theme.primaryColor),
                  child: const Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('Home'),
                  leading: const Icon(Icons.home),
                  onTap: () {
                    Navigator.pushNamed(context, '/home');
                  },
                ),
                ListTile(
                  title: const Text('New Auto'),
                  leading: const Icon(Icons.add_circle),
                  onTap: () {
                    _newPath(context);
                  },
                ),
                ListTile(
                  title: const Text('Load Auto From Computer'),
                  leading: const Icon(Icons.computer),
                  onTap: () {
                    _loadPathFromFiles(context);
                  },
                ),
                ListTile(
                  title: const Text('Load Auto From Robot'),
                  leading: const Icon(Icons.smart_toy),
                  onTap: () {
                    _loadPathFromRobot(context);
                  },
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return const SettingsPopup();
                      },
                    );
                  },
                  style: theme.elevatedButtonTheme.style,
                  child: const Row(
                    children: [
                      Icon(Icons.settings),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
