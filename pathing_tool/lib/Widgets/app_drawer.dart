import 'package:flutter/material.dart';
import 'Popups/settings_popup.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

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
                    'Drawer Header',
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
                  title: const Text('Autos'),
                  leading: const Icon(Icons.draw),
                  onTap: () {
                    Navigator.pushNamed(context, '/autos');
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
                    // Handle button press
                  },
                  style: theme.elevatedButtonTheme.style,
                  child: const Text('Button 1'),
                ),
              ),
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
