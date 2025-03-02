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
          Image.asset(
            'Images/PolarBearHead.png',
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
