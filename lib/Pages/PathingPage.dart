import 'package:flutter/material.dart';
import 'package:pathing_tool/Widgets/custom_app_bar.dart';
import 'package:pathing_tool/Widgets/spline_chart.dart';
import '../Widgets/app_drawer.dart';

class PathingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      drawer: AppDrawer(),
      body: const SplineChart(),
    );
  }
}
