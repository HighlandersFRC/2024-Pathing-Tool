import 'package:flutter/material.dart';
import 'package:pathing_tool/Widgets/custom_app_bar.dart';

import '../Widgets/app_drawer.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: CustomAppBar(),
      drawer: AppDrawer(),
      body: Text(
        "Home",
        style: theme.textTheme.titleLarge,
      ),
    );
  }
}
