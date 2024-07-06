import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathing_tool/Utils/Providers/image_data_provider.dart';
import 'package:pathing_tool/Utils/Structs/image_data.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';
import 'package:pathing_tool/Utils/spline.dart';
import 'package:provider/provider.dart';

class AutoEditor extends StatefulWidget {
  final List<Spline> splines;
  final String autoName;
  const AutoEditor(
    this.splines,
    this.autoName, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() {
    return _AutoEditorState(splines);
  }
}

class _AutoEditorState extends State<AutoEditor> {
  List<List<Spline>> undoStack = [];
  List<List<Spline>> redoStack = [];
  List<Spline> splines = [];
  int selectedSpline = -1;
  _AutoEditorState(List<Spline> splines) {
    this.splines = [...splines];
  }
  String pathName = "";
  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    ImageDataProvider imageDataProvider =
        Provider.of<ImageDataProvider>(context);
    ImageData fieldImageData = imageDataProvider.selectedImage;
    return Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
              UndoIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY):
              RedoIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
              SaveIntent(),
        },
        child: Actions(
            actions: <Type, Action<Intent>>{
              UndoIntent: UndoAction(_undo),
              RedoIntent: RedoAction(_redo),
              SaveIntent: SaveAction(() => savePathToFile()),
            },
            child: Focus(
                autofocus: true,
                child: Scaffold(
                    appBar: AppBar(
                      title: TextField(
                        controller: TextEditingController(text: pathName),
                        onSubmitted: (value) {
                          setState(() {
                            pathName = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter path name',
                          focusColor: theme.primaryColor,
                          hoverColor: theme.primaryColor,
                          floatingLabelStyle:
                              TextStyle(color: theme.primaryColor),
                          focusedBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: theme.primaryColor)),
                        ),
                        cursorColor: theme.primaryColor,
                      ),
                      automaticallyImplyLeading: false,
                      actions: [
                        Tooltip(
                          message: "Undo",
                          waitDuration: const Duration(milliseconds: 500),
                          child: TextButton(
                            onPressed: undoStack.isNotEmpty
                                ? () {
                                    _undo();
                                  }
                                : null,
                            style: ButtonStyle(
                                foregroundColor: undoStack.isNotEmpty
                                    ? WidgetStateProperty.all(
                                        theme.primaryColor)
                                    : const WidgetStatePropertyAll(
                                        Colors.grey)),
                            child: const Icon(Icons.undo),
                          ),
                        ),
                        Tooltip(
                          message: "Redo",
                          waitDuration: const Duration(milliseconds: 500),
                          child: TextButton(
                            onPressed: redoStack.isNotEmpty
                                ? () {
                                    _redo();
                                  }
                                : null,
                            style: ButtonStyle(
                                foregroundColor: redoStack.isNotEmpty
                                    ? WidgetStateProperty.all(
                                        theme.primaryColor)
                                    : const WidgetStatePropertyAll(
                                        Colors.grey)),
                            child: const Icon(Icons.redo),
                          ),
                        ),
                        const Tooltip(
                          message: "Save Path to File",
                          waitDuration: Duration(milliseconds: 500),
                          child: ElevatedButton(
                              onPressed: savePathToFile,
                              child: Icon(Icons.save)),
                        ),
                        Tooltip(
                          message: "Load Path",
                          waitDuration: const Duration(milliseconds: 500),
                          child: ElevatedButton(
                              onPressed: _loadPath,
                              child: const Icon(Icons.folder_open)),
                        ),
                      ],
                    ),
                    body: Row(children: [
                      Expanded(child: Center(child: LayoutBuilder(builder:
                          (BuildContext context, BoxConstraints constraints) {
                        var availableWidth = constraints.maxWidth;
                        var availableHeight = constraints.maxHeight;
                        double usedWidth = availableWidth;
                        double usedHeight = availableHeight;
                        if (usedHeight / fieldImageData.imageHeightInPixels >
                            usedWidth / fieldImageData.imageWidthInPixels) {
                          usedHeight = fieldImageData.imageHeightInPixels *
                              (usedWidth / fieldImageData.imageWidthInPixels);
                        } else {
                          usedWidth = fieldImageData.imageWidthInPixels *
                              (usedHeight / fieldImageData.imageHeightInPixels);
                        }
                        Image fieldImage = Image(
                          image: fieldImageData.image.image,
                          width: usedWidth,
                          height: usedHeight,
                          fit: BoxFit.contain,
                        );

                        return Center(
                            child: GestureDetector(
                                child: Stack(children: [
                          SizedBox(
                            height: usedHeight,
                            width: usedWidth,
                            child: fieldImage,
                          ),
                          ...splines.map((Spline spline) {
                            List<FlSpot> xSpots = [];
                            if (spline.points.length > 1) {
                              double timeStep = 0.01;
                              double endTime = spline.points.last.t;
                              for (double t = 0; t <= endTime; t += timeStep) {
                                Waypoint point = spline.getRobotWaypoint(t);
                                xSpots.add(FlSpot(point.x, point.y));
                              }
                            }
                            return SizedBox(
                              height: usedHeight,
                              width: usedWidth,
                              child: LineChart(
                                LineChartData(
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: xSpots,
                                      isCurved: true,
                                      barWidth: 3,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.grey.shade500.withOpacity( splines.indexOf(spline) == selectedSpline? 1: 0.3)
                                          : Colors.grey.shade800.withOpacity( splines.indexOf(spline) == selectedSpline? 1: 0.3),
                                      dotData: const FlDotData(show: false),
                                    ),
                                  ],
                                  minX: 0,
                                  minY: 0,
                                  maxX: fieldImageData.imageWidthInMeters,
                                  maxY: fieldImageData.imageHeightInMeters,
                                  gridData: const FlGridData(show: false),
                                  titlesData: const FlTitlesData(show: false),
                                  borderData: FlBorderData(show: false),
                                  lineTouchData:
                                      const LineTouchData(enabled: false),
                                ),
                              ),
                            );
                          }),
                        ])));
                      })))
                    ])))));
  }
  _saveState() {
    setState(() {
      undoStack = [
        ...undoStack,
        [...splines]
      ];
      redoStack.clear();
    });
  }

  _undo() {
    if (undoStack.isNotEmpty) {
      setState(() {
        redoStack = [
          ...redoStack,
          [...splines]
        ];
        splines = undoStack.last;
        undoStack.removeLast();
        selectedSpline = -1;
      });
    }
  }

  _redo() {
    if (redoStack.isNotEmpty) {
      setState(() {
        undoStack = [...undoStack, splines];
        splines = redoStack.removeLast();
      });
    }
  }

  _loadPath() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['polarpath'],
    );
    setState(() {
      if (result != null && result.files.single.path != null) {
        _saveState();
        String path = result.files.single.path!;
        File pathFile = File(path);
        splines.add(Spline.fromPolarPathFile(pathFile));
      }
      selectedSpline = splines.length - 1;
    });
  }
}

savePathToFile() {}

class UndoAction extends Action<Intent> {
  final VoidCallback onUndo;

  UndoAction(this.onUndo);

  @override
  Object? invoke(covariant Intent intent) {
    onUndo();
    return null;
  }
}

class RedoAction extends Action<Intent> {
  final VoidCallback onRedo;

  RedoAction(this.onRedo);

  @override
  Object? invoke(covariant Intent intent) {
    onRedo();
    return null;
  }
}

class SaveAction extends Action<Intent> {
  final VoidCallback onSave;

  SaveAction(this.onSave);

  @override
  Object? invoke(covariant Intent intent) {
    onSave();
    return null;
  }
}

class UndoIntent extends Intent {}

class RedoIntent extends Intent {}

class SaveIntent extends Intent {}
