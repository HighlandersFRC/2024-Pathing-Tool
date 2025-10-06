import 'package:flutter/material.dart';

import '../Utils/utils.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  final Size preferredSize;

  const CustomAppBar({super.key})
      : preferredSize = const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      title: Row(
        children: [
          Image.asset(
            'Images/PolarBearHead.png',
            height: 80,
            width: 80,
          ),
          const Text(
            "Polar Pathing",
            style: TextStyle(
                color: Colors.white, fontSize: 40, fontFamily: "OpenSans"),
          ),
          const SizedBox(width: 16),
          FutureBuilder(
              // Show version from pubspec.yaml
              builder: (BuildContext context, AsyncSnapshot snapshot) => Text(
                    snapshot.hasData ? "v${snapshot.data}" : "",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: "OpenSans"),
                  ),
              future: Utils.getVersionFromPubspec()),
        ],
      ),
      backgroundColor: theme.primaryColor,
    );
  }
}
