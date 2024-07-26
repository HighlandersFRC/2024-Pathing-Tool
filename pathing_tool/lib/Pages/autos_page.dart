import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/spline.dart';
import 'package:pathing_tool/Widgets/auto_editor.dart';
import 'package:pathing_tool/Widgets/custom_app_bar.dart';
import '../Widgets/app_drawer.dart';

class AutosPage extends StatelessWidget {
  final List<Spline> splines;
  final String autoName;
  const AutosPage(this.splines, this.autoName, {super.key});
  static AutosPage fromFile(File file) {
    String jsonString = file.readAsStringSync();
    var autoJson = json.decode(jsonString);
    return fromJson(autoJson);
  }

  static AutosPage fromJson(Map<String, dynamic> json) {
    String autoName = json['meta_data']['auto_name'];
    List<Spline> splines = [];
    var paths = json['paths'];
    for (var scheduleItem in json['schedule']) {
      if (scheduleItem['branched']) {
        var onTrue = scheduleItem["branched_path"]["on_true"] == -1
            ? NullSpline()
            : Spline.fromJson(paths[scheduleItem["branched_path"]["on_true"]]);
        var onFalse = scheduleItem["branched_path"]["on_false"] == -1
            ? NullSpline()
            : Spline.fromJson(paths[scheduleItem["branched_path"]["on_false"]]);
        var condition = scheduleItem["condition"];
        splines.add(BranchedSpline(onTrue, onFalse, condition));
      } else {
        splines.add(Spline.fromJson(paths[scheduleItem['path']]));
      }
    }
    return AutosPage(splines, autoName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      drawer: const AppDrawer(),
      body: AutoEditor(splines, autoName),
    );
  }
}
