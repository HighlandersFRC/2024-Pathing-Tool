import 'package:flutter/material.dart';

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
          Image.network(
            'https://student.polarforecastfrc.com/static/media/PolarbearHead.ec128d026b435e983504.png',
            height: 80,
            width: 80,
          ),
          const Text(
            "Polar Pathing",
            style: TextStyle(color: Colors.white, fontSize: 40, fontFamily: "OpenSans"),
          )
        ],
      ),
      backgroundColor: theme.primaryColor,
    );
  }
}
