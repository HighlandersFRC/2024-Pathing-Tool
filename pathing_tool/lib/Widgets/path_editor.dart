import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathing_tool/Utils/Providers/image_data_provider.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:pathing_tool/Utils/Structs/command.dart';
import 'package:pathing_tool/Utils/Structs/image_data.dart';
import 'package:pathing_tool/Utils/Structs/robot_config.dart';
import 'package:pathing_tool/Utils/spline.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';
import 'package:pathing_tool/Widgets/spline_editing/draggable_handle_position.dart';
import 'package:pathing_tool/Widgets/spline_editing/draggable_handle_theta.dart';
import 'package:pathing_tool/Widgets/spline_editing/draggable_handle_velocity.dart';
import 'package:pathing_tool/Widgets/spline_editing/edit_command_menu.dart';
import 'package:pathing_tool/Widgets/spline_editing/edit_waypoint_menu.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:path/path.dart' as p;

class PathEditor extends StatefulWidget {
  final List<Waypoint> startingWaypoints;
  final String pathName;
  final Function(Spline)? returnSpline;
  const PathEditor(this.startingWaypoints, this.pathName,
      {super.key, this.returnSpline});
  static PathEditor fromFile(File file, Function(Spline)? returnSpline) {
    String jsonString = file.readAsStringSync();
    var pathJson = json.decode(jsonString);
    var pointsJsonList = pathJson["key_points"];
    List<Waypoint> waypoints = [];
    pointsJsonList.forEach((point) {
      waypoints.add(Waypoint.fromJson(point));
    });
    String pathName = pathJson["meta_data"]["path_name"];
    return PathEditor(waypoints, pathName, returnSpline: returnSpline);
  }

  @override
  _PathEditorState createState() =>
      _PathEditorState(startingWaypoints, pathName);
}

class _PathEditorState extends State<PathEditor>
    with SingleTickerProviderStateMixin {
  List<(List<Waypoint>, bool)> undoStack = [];
  List<(List<Waypoint>, bool)> redoStack = [];
  List<Waypoint> waypoints = [];
  List<Command> commands = [];
  Waypoint? playbackWaypoint;
  bool smooth = false;
  int editMode = 0;
  int selectedWaypoint = -1;
  int selectedCommand = -1;
  String pathName = "";
  late AnimationController _animationController;

  _PathEditorState(List<Waypoint> startingWaypoints, this.pathName) {
    waypoints = [...startingWaypoints];
  }
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration:
          Duration(seconds: waypoints.isNotEmpty ? waypoints.last.t.ceil() : 0),
    )..addListener(() {
        setState(() {
          playbackWaypoint = _getPlaybackWaypoint();
        });
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Waypoint _getPlaybackWaypoint() {
    var robot = Spline(waypoints);
    return robot
        .getRobotWaypoint(_animationController.value * waypoints.last.t);
  }

  void playPath() {
    if (!_animationController.isAnimating) {
      _animationController.forward(from: 0.0);
    }
  }

  void _addWaypoint(double x, double y) { 
    setState(() {
      double t = waypoints.isNotEmpty ? waypoints.last.t + 1 : 0;
      double dx = waypoints.isNotEmpty
          ? (x - waypoints.last.x) / (t - waypoints.last.t)
          : 0;
      double dy = waypoints.isNotEmpty
          ? (y - waypoints.last.y) / (t - waypoints.last.t)
          : 0;
      waypoints.add(Waypoint(
          x: x,
          y: y,
          theta: waypoints.isNotEmpty ? waypoints.last.theta : 0,
          dx: dx,
          dy: dy,
          dtheta: 0,
          d2x: 0,
          d2y: 0,
          d2theta: 0,
          t: t));
      smooth = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    _animationController.duration =
        Duration(seconds: waypoints.isNotEmpty ? waypoints.last.t.ceil() : 0);
    ImageDataProvider imageDataProvider =
        Provider.of<ImageDataProvider>(context);
    ImageData fieldImageData = imageDataProvider.selectedImage;
    List<FlSpot> fullSpline = [];
    List<FlSpot> commandSpline = [];
    final theme = Theme.of(context);
    final robotConfigProvider = Provider.of<RobotConfigProvider>(context);
    if (waypoints.length > 1) {
      Spline robot = Spline(waypoints);
      double timeStep = 0.01; // Adjust for desired granularity
      double endTime = robot.points.last.t;
      for (double t = 0; t <= endTime; t += timeStep) {
        Waypoint point = robot.getRobotWaypoint(t);
        fullSpline.add(FlSpot(point.x, point.y));
      }
    }
    if (waypoints.length > 1 && selectedCommand != -1) {
      Spline robot = Spline(waypoints);
      double timeStep = 0.01; // Adjust for desired granularity
      double start = commands[selectedCommand].startTime;
      double endTime = commands[selectedCommand].endTime;
      for (double t = start; t <= endTime; t += timeStep) {
        Waypoint point = robot.getRobotWaypoint(t);
        commandSpline.add(FlSpot(point.x, point.y));
      }
    }
    void savePathToFile() async {
      if (pathName == "") {
        await showDialog(
            builder: (BuildContext context) => AlertDialog(
                  title: const Text("Name the path first"),
                  content: TextField(
                    controller: TextEditingController(text: pathName),
                    onSubmitted: (value) {
                      setState(() {
                        pathName = value;
                        Navigator.pop(context);
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter path name',
                      focusColor: theme.primaryColor,
                      hoverColor: theme.primaryColor,
                      floatingLabelStyle: TextStyle(color: theme.primaryColor),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: theme.primaryColor)),
                    ),
                    cursorColor: theme.primaryColor,
                  ),
                ),
            context: context);
      }
      double timeStep = 0.01;
      Spline robot = Spline(waypoints);
      List<Map<String, dynamic>> sampledPoints = [];
      for (double t = 0; t <= robot.points.last.t; t += timeStep) {
        Waypoint waypoint = robot.getRobotWaypoint(t);
        Map<String, dynamic> sampledPoint = {
          "time": waypoint.t,
          "x": waypoint.x,
          "y": waypoint.y,
          "angle": waypoint.theta,
          "x_velocity": waypoint.dx,
          "y_velocity": waypoint.dy,
          "angular_velocity": waypoint.dtheta,
          "x_acceleration": waypoint.d2x,
          "y_acceleration": waypoint.d2y,
          "angular_acceleration": waypoint.d2theta
        };
        sampledPoints.add(sampledPoint);
      }
      final Map<String, dynamic> pathData = {
        "meta_data": {"path_name": pathName, "sample_rate": timeStep},
        "commands": commands.map((Command command) {
          return command.toJson();
        }).toList(),
        "key_points": waypoints
            .map((waypoint) => {
                  "index": waypoints.indexOf(waypoint),
                  "delta_time": waypoint.t,
                  "time": waypoint.t,
                  "x": waypoint.x,
                  "y": waypoint.y,
                  "angle": waypoint.theta,
                  "x_velocity": waypoint.dx,
                  "y_velocity": waypoint.dy,
                  "angular_velocity": waypoint.dtheta,
                  "x_acceleration": waypoint.d2x,
                  "y_acceleration": waypoint.d2y,
                  "angular_acceleration": waypoint.d2theta
                })
            .toList(),
        "sampled_points": sampledPoints // Populate with actual sampled points
      };

      // Allow the user to pick a directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: "Save to which folder?",
          initialDirectory: "C:\\Polar Pathing\\Saves");

      if (selectedDirectory == null) {
        // User canceled the picker
        return;
      }

      // Define the file path
      final String path = p.join(selectedDirectory, '$pathName.polarpath');

      // Write the JSON object to a file
      final File file = File(path);
      await file.writeAsString(jsonEncode(pathData));

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Path data saved to $path')));
    }

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
                    leading: widget.returnSpline != null
                        ? Tooltip(
                            message: "Back",
                            waitDuration: const Duration(milliseconds: 500),
                            child: TextButton(
                                onPressed: () {
                                  savePathToFile();
                                  widget.returnSpline!(Spline(waypoints));
                                  Navigator.pop(context);
                                },
                                style: ButtonStyle(
                                    foregroundColor: WidgetStateProperty.all(
                                        theme.primaryColor)),
                                child: const Icon(Icons.arrow_back)),
                          )
                        : null,
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
                            borderSide: BorderSide(color: theme.primaryColor)),
                      ),
                      cursorColor: theme.primaryColor,
                    ),
                    automaticallyImplyLeading: false,
                    actions: [
                      Tooltip(
                        message: "Play Path",
                        waitDuration: const Duration(milliseconds: 500),
                        child: TextButton(
                          onPressed: waypoints.length > 1
                              ? () {
                                  playPath();
                                }
                              : null,
                          style: ButtonStyle(
                            foregroundColor:
                                WidgetStateProperty.all(theme.primaryColor),
                          ),
                          child: const Icon(Icons.play_arrow_rounded),
                        ),
                      ),
                      Tooltip(
                        message: "Smoothen",
                        waitDuration: const Duration(milliseconds: 500),
                        child: TextButton(
                          onPressed: waypoints.length > 1 && !smooth
                              ? () {
                                  _averageAll();
                                }
                              : null,
                          style: ButtonStyle(
                              foregroundColor: waypoints.length > 1 && !smooth
                                  ? WidgetStateProperty.all(theme.primaryColor)
                                  : const WidgetStatePropertyAll(Colors.grey)),
                          child: const Icon(Icons.switch_access_shortcut),
                        ),
                      ),
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
                                  ? WidgetStateProperty.all(theme.primaryColor)
                                  : const WidgetStatePropertyAll(Colors.grey)),
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
                                  ? WidgetStateProperty.all(theme.primaryColor)
                                  : const WidgetStatePropertyAll(Colors.grey)),
                          child: const Icon(Icons.redo),
                        ),
                      ),
                      Tooltip(
                        message: "Save Path to File",
                        waitDuration: const Duration(milliseconds: 500),
                        child: ElevatedButton(
                            onPressed: savePathToFile,
                            child: const Icon(Icons.save)),
                      ),
                    ],
                  ),
                  bottomNavigationBar: NavigationBar(
                    onDestinationSelected: (idx) => setState(() {
                      editMode = idx;
                    }),
                    selectedIndex: editMode,
                    indicatorColor: theme.primaryColor,
                    destinations: const [
                      NavigationDestination(
                        selectedIcon: Icon(Icons.draw),
                        icon: Icon(Icons.draw_outlined),
                        label: "Draw",
                      ),
                      NavigationDestination(
                        selectedIcon: Icon(Icons.edit),
                        icon: Icon(Icons.edit_outlined),
                        label: "Edit",
                      ),
                      NavigationDestination(
                        selectedIcon: Icon(Icons.precision_manufacturing),
                        icon: Icon(Icons.precision_manufacturing_outlined),
                        label: "Commands",
                      ),
                    ],
                  ),
                  body: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: LayoutBuilder(
                            builder: (BuildContext context,
                                BoxConstraints constraints) {
                              var availableWidth = constraints.maxWidth;
                              var availableHeight = constraints.maxHeight;
                              double usedWidth = availableWidth;
                              double usedHeight = availableHeight;
                              if (usedHeight /
                                      fieldImageData.imageHeightInPixels >
                                  usedWidth /
                                      fieldImageData.imageWidthInPixels) {
                                usedHeight =
                                    fieldImageData.imageHeightInPixels *
                                        (usedWidth /
                                            fieldImageData.imageWidthInPixels);
                              } else {
                                usedWidth = fieldImageData.imageWidthInPixels *
                                    (usedHeight /
                                        fieldImageData.imageHeightInPixels);
                              }
                              Image fieldImage = Image(
                                image: fieldImageData.image.image,
                                width: usedWidth,
                                height: usedHeight,
                                fit: BoxFit.contain,
                              );
                              var widthOffset =
                                  (availableWidth - usedWidth) / 2;
                              var heightOffset =
                                  (availableHeight - usedHeight) / 2;
                              void onClick(BuildContext context,
                                  TapDownDetails details) {
                                if (editMode == 0) {
                                  // TODO Add detection for when you click on a point
                                  // int pointIdx = -1;
                                  // waypoints.forEach((Waypoint waypoint) {});

                                  _saveState();
                                  var xPixels =
                                      details.localPosition.dx - widthOffset;
                                  var yPixels =
                                      details.localPosition.dy - heightOffset;
                                  var xMeters = xPixels /
                                      usedWidth *
                                      fieldImageData.imageWidthInMeters;
                                  var yMeters = (usedHeight - yPixels) /
                                      usedHeight *
                                      fieldImageData.imageHeightInMeters;
                                  _addWaypoint(xMeters, yMeters);
                                }
                              }

                              CustomPaint? playbackPaint = playbackWaypoint !=
                                      null
                                  ? CustomPaint(
                                      size:
                                          Size(availableHeight, availableWidth),
                                      painter: RobotPainter(
                                          playbackWaypoint!,
                                          fieldImageData,
                                          usedWidth,
                                          usedHeight,
                                          context,
                                          robotConfigProvider.robotConfig,
                                          theme.brightness == Brightness.dark
                                              ? Colors.white
                                              : Colors.grey,
                                          255,
                                          constraints),
                                    )
                                  : null;
                              return Center(
                                child: GestureDetector(
                                  onTapDown: (details) =>
                                      onClick(context, details),
                                  child: Stack(children: [
                                    SizedBox(
                                      height: availableHeight,
                                      width: availableWidth,
                                      child: fieldImage,
                                    ),
                                    Container(
                                        alignment: Alignment.center,
                                        child: SizedBox(
                                          height: usedHeight,
                                          width: usedWidth,
                                          child: LineChart(
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.decelerate,
                                            LineChartData(
                                              lineBarsData: [
                                                LineChartBarData(
                                                  spots: fullSpline,
                                                  isCurved: true,
                                                  barWidth: 3,
                                                  color: theme.brightness ==
                                                          Brightness.dark
                                                      ? Colors.grey.shade500
                                                      : Colors.black,
                                                  dotData: const FlDotData(
                                                      show: false),
                                                ),
                                              ],
                                              minX: 0,
                                              minY: 0,
                                              maxX: fieldImageData
                                                  .imageWidthInMeters,
                                              maxY: fieldImageData
                                                  .imageHeightInMeters,
                                              gridData:
                                                  const FlGridData(show: false),
                                              titlesData: const FlTitlesData(
                                                  show: false),
                                              borderData:
                                                  FlBorderData(show: false),
                                              lineTouchData:
                                                  const LineTouchData(
                                                      enabled: false),
                                            ),
                                          ),
                                        )),
                                    if (editMode == 2)
                                      Container(
                                          alignment: Alignment.center,
                                          child: SizedBox(
                                            height: usedHeight,
                                            width: usedWidth,
                                            child: LineChart(
                                              LineChartData(
                                                lineBarsData: [
                                                  LineChartBarData(
                                                    spots: commandSpline,
                                                    isCurved: true,
                                                    barWidth: 5,
                                                    color: theme.primaryColor,
                                                    dotData: const FlDotData(
                                                        show: false),
                                                  ),
                                                ],
                                                minX: 0,
                                                minY: 0,
                                                maxX: fieldImageData
                                                    .imageWidthInMeters,
                                                maxY: fieldImageData
                                                    .imageHeightInMeters,
                                                gridData: const FlGridData(
                                                    show: false),
                                                titlesData: const FlTitlesData(
                                                    show: false),
                                                borderData:
                                                    FlBorderData(show: false),
                                                lineTouchData:
                                                    const LineTouchData(
                                                        enabled: false),
                                              ),
                                            ),
                                          )),
                                    Stack(
                                      children: [
                                        ...waypoints.map((Waypoint waypoint) {
                                          return CustomPaint(
                                            size: Size(availableHeight,
                                                availableWidth),
                                            painter: RobotPainter(
                                                waypoint,
                                                fieldImageData,
                                                usedWidth,
                                                usedHeight,
                                                context,
                                                robotConfigProvider.robotConfig,
                                                theme.primaryColor,
                                                selectedWaypoint ==
                                                        waypoints
                                                            .indexOf(waypoint)
                                                    ? 255
                                                    : 100,
                                                constraints),
                                          );
                                        }),
                                        if (playbackPaint != null)
                                          playbackPaint,
                                        if (editMode == 1)
                                          ...waypoints.map((Waypoint waypoint) {
                                            double xPixels = waypoint.x /
                                                fieldImageData
                                                    .imageWidthInMeters *
                                                usedWidth;
                                            double yPixels = usedHeight -
                                                (waypoint.y /
                                                    fieldImageData
                                                        .imageHeightInMeters *
                                                    usedHeight);
                                            double metersToPixelsRatio =
                                                usedWidth /
                                                    fieldImageData
                                                        .imageWidthInMeters;

                                            Offset handlePosition = Offset(
                                              metersToPixelsRatio * waypoint.dx,
                                              -metersToPixelsRatio *
                                                  waypoint.dy,
                                            );
                                            return CustomPaint(
                                              size: Size(availableWidth,
                                                  availableHeight),
                                              painter: VelocityPainter(
                                                opacity: waypoints.indexOf(
                                                            waypoint) ==
                                                        selectedWaypoint
                                                    ? 255
                                                    : 150,
                                                start: Offset(
                                                    xPixels + widthOffset,
                                                    yPixels + heightOffset),
                                                end: Offset(
                                                    xPixels +
                                                        handlePosition.dx +
                                                        widthOffset,
                                                    yPixels +
                                                        handlePosition.dy +
                                                        heightOffset),
                                                color: theme.primaryColor,
                                              ),
                                            );
                                          }),
                                        if (editMode == 1)
                                          ...waypoints.map((waypoint) =>
                                              DraggableHandleTheta(
                                                constraints: constraints,
                                                waypoint: waypoint,
                                                fieldImageData: fieldImageData,
                                                usedWidth: usedWidth,
                                                usedHeight: usedHeight,
                                                onUpdate: (updatedWaypoint) {
                                                  setState(() {
                                                    int index = waypoints
                                                        .indexOf(waypoint);
                                                    if (index != -1) {
                                                      waypoints[index] =
                                                          updatedWaypoint;
                                                      waypoints = waypoints;
                                                      editMode = 1;
                                                      selectedWaypoint = index;
                                                    }
                                                  });
                                                },
                                                opacity: waypoints.indexOf(
                                                            waypoint) ==
                                                        selectedWaypoint
                                                    ? 255
                                                    : 150,
                                                saveState: () {
                                                  _saveState();
                                                  setState(() {
                                                    smooth = false;
                                                  });
                                                },
                                              )),
                                        if (editMode == 1)
                                          ...waypoints.map((waypoint) =>
                                              DraggableHandlePosition(
                                                constraints: constraints,
                                                waypoint: waypoint,
                                                fieldImageData: fieldImageData,
                                                usedWidth: usedWidth,
                                                usedHeight: usedHeight,
                                                onUpdate: (updatedWaypoint) {
                                                  setState(() {
                                                    int index = waypoints
                                                        .indexOf(waypoint);
                                                    if (index != -1) {
                                                      waypoints[index] =
                                                          updatedWaypoint;
                                                      waypoints = waypoints;
                                                      editMode = 1;
                                                      selectedWaypoint = index;
                                                    }
                                                  });
                                                },
                                                opacity: waypoints.indexOf(
                                                            waypoint) ==
                                                        selectedWaypoint
                                                    ? 255
                                                    : 150,
                                                saveState: () {
                                                  _saveState();
                                                  setState(() {
                                                    smooth = false;
                                                  });
                                                },
                                              )),
                                        if (editMode == 1)
                                          ...waypoints.map((waypoint) =>
                                              VelocityHandle(
                                                constraints: constraints,
                                                waypoint: waypoint,
                                                fieldImageData: fieldImageData,
                                                usedWidth: usedWidth,
                                                usedHeight: usedHeight,
                                                onUpdate: (updatedWaypoint) {
                                                  setState(() {
                                                    int index = waypoints
                                                        .indexOf(waypoint);
                                                    if (index != -1) {
                                                      waypoints[index] =
                                                          updatedWaypoint;
                                                      waypoints = waypoints;
                                                      editMode = 1;
                                                      selectedWaypoint = index;
                                                    }
                                                  });
                                                },
                                                opacity: waypoints.indexOf(
                                                            waypoint) ==
                                                        selectedWaypoint
                                                    ? 255
                                                    : 150,
                                                saveState: () {
                                                  _saveState();
                                                  setState(() {
                                                    smooth = false;
                                                  });
                                                },
                                              )),
                                      ],
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                          width: 350,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Container(
                                  height: constraints.maxHeight,
                                  color: theme.primaryColor.withOpacity(0.2),
                                  child: SingleChildScrollView(
                                      child: Column(children: [
                                    if (editMode != 2)
                                      EditWaypointMenu(
                                        waypoints: waypoints,
                                        onWaypointSelected: _onWaypointSelected,
                                        onAttributeChanged: _onAttributeChanged,
                                        selectedWaypoint: waypoints.length >=
                                                selectedWaypoint - 1
                                            ? selectedWaypoint
                                            : -1,
                                        onWaypointsChanged: _onWaypointsChanged,
                                      )
                                    else
                                      EditCommandMenu(
                                          commands: commands,
                                          onCommandSelected: _onCommandSelected,
                                          onAttributeChanged:
                                              _onCommandAttributeChanged,
                                          selectedCommand: selectedCommand,
                                          onCommandsChanged: _onCommandChanged),
                                  ])));
                            },
                          )),
                    ],
                  ),
                ))));
  }

  _onAttributeChanged(Waypoint waypoint) {
    if (selectedWaypoint != -1) {
      _saveState();
      setState(() {
        waypoints[selectedWaypoint] = waypoint;
        waypoints.sort((a, b) => a.t.compareTo(b.t));
        selectedWaypoint = waypoints.indexOf(waypoint);
        smooth = false;
      });
    }
  }

  _onWaypointSelected(Waypoint? waypoint) {
    setState(() {
      selectedWaypoint = waypoint != null ? waypoints.indexOf(waypoint) : -1;
    });
  }

  _onCommandSelected(Command? command) {
    setState(() {
      selectedCommand = command != null ? commands.indexOf(command) : -1;
    });
  }

  _onCommandAttributeChanged(Command command) {
    if (selectedCommand != -1) {
      setState(() {
        List<Command> newCommands = [];
        for (var existingCommand in commands) {
          if (commands[selectedCommand] == existingCommand) {
            newCommands.add(command);
          } else {
            newCommands.add(existingCommand);
          }
        }
        commands = [...newCommands];
      });
    }
  }

  _saveState() {
    setState(() {
      undoStack = [
        ...undoStack,
        ([...waypoints], smooth)
      ];
      redoStack.clear();
    });
  }

  _undo() {
    if (undoStack.isNotEmpty) {
      setState(() {
        redoStack = [
          ...redoStack,
          ([...this.waypoints], this.smooth)
        ];
        var (waypoints, smooth) = undoStack.last;
        this.waypoints = waypoints;
        this.smooth = smooth;
        undoStack.removeLast();
        selectedWaypoint = -1;
      });
    }
  }

  _redo() {
    if (redoStack.isNotEmpty) {
      setState(() {
        undoStack = [...undoStack, (this.waypoints, this.smooth)];
        var (waypoints, smooth) = redoStack.removeLast();
        this.waypoints = waypoints;
        this.smooth = smooth;
      });
    }
  }

  _onWaypointsChanged(List<Waypoint> waypoints) {
    _saveState();
    setState(() {
      waypoints.sort((a, b) => a.t.compareTo(b.t));
      this.waypoints = [...waypoints];
      smooth = false;
    });
  }

  _onCommandChanged(List<Command> commands) {
    _saveState();
    setState(() {
      this.commands = [...commands];
    });
  }

  (double, double) _averageLinearVelocity(int index) {
    double dy = 0, dx = 0;
    if (index != 0 && index != waypoints.length - 1) {
      Waypoint p0 = waypoints[index - 1];
      Waypoint p2 = waypoints[index + 1];
      double dt = p2.time - p0.time;
      double vTheta = atan2(p2.y - p0.y, p2.x - p0.x);
      double dist = _getDistance(p0.x, p0.y, p2.x, p2.y);
      double vMag = dist / dt;
      double deltaX = vMag * cos(vTheta);
      double deltaY = vMag * sin(vTheta);
      dx = deltaX * (dt / 2);
      dy = deltaY * (dt / 2); // Approximate mid-point
    } else {
      dy = 0;
      dx = 0;
    }
    return (dy, dx);
  }

  double _averageAngularVelocity(int index) {
    double angVel;
    if (index != 0 && index != waypoints.length - 1) {
      Waypoint p0 = waypoints[index - 1];
      Waypoint p1 = waypoints[index];
      Waypoint p2 = waypoints[index + 1];
      double dt = p2.time - p0.time;
      double da = p2.theta - p0.theta;
      if (p2.theta - p0.theta > pi) {
        da = pi - da;
      } else if (p2.theta - p0.theta < -pi) {
        da = pi + da;
      }
      int sine1 = _getOptimizedRotationSign(p0.theta, waypoints[index].theta);
      int sine2 = _getOptimizedRotationSign(waypoints[index].theta, p2.theta);
      if (sine1 != sine2) {
        angVel = 0;
      } else {
        angVel = da / dt;
      }
      if ((p0.theta - p1.theta).abs() < pi / 8) {
        angVel = 0;
      } else if ((p1.theta - p2.theta).abs() < pi / 8) {
        angVel = 0;
      }
    } else {
      angVel = 0;
    }
    return angVel;
  }

  _averageAll() {
    List<Waypoint> newWaypoints = [];
    for (int i = 0; i < waypoints.length; i++) {
      var (dy, dx) = _averageLinearVelocity(i);
      var dtheta = _averageAngularVelocity(i);
      newWaypoints.add(waypoints[i].copyWith(dy: dy, dx: dx, dtheta: dtheta));
    }
    _onWaypointsChanged(newWaypoints);
    setState(() {
      smooth = true;
    });
  }

  double _getDistance(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  int _getOptimizedRotationSign(double angle1, double angle2) {
    double op1, op2;
    if (angle1 >= angle2) {
      op2 = ((2 * pi) - (angle1 - angle2));
      op1 = (angle1 - angle2);
    } else {
      op1 = ((2 * pi) - (angle2 - angle1));
      op2 = (angle2 - angle1);
    }
    return op1 <= op2 ? -1 : 1;
  }
}

class RobotPainter extends CustomPainter {
  final Waypoint waypoint;
  final ImageData fieldImageData;
  final double usedWidth;
  final double usedHeight;
  final BuildContext context;
  final RobotConfig robotConfig;
  final Color color;
  final int opacity;
  late double metersToPixelsRatio;
  final BoxConstraints constraints;

  RobotPainter(
      this.waypoint,
      this.fieldImageData,
      this.usedWidth,
      this.usedHeight,
      this.context,
      this.robotConfig,
      this.color,
      this.opacity,
      this.constraints) {
    metersToPixelsRatio = usedWidth / fieldImageData.imageWidthInMeters;
  }

  @override
  void paint(Canvas canvas, Size size) {
    var widthOffset = (constraints.maxWidth - usedWidth) / 2;
    var heightOffset = (constraints.maxHeight - usedHeight) / 2;
    final Paint paint = Paint()
      ..color = color.withAlpha(opacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint fillPaint = Paint()
      ..color = color.withOpacity(0.0)
      ..style = PaintingStyle.fill;

    double xPixels =
        (waypoint.x / fieldImageData.imageWidthInMeters * usedWidth) +
            widthOffset;
    double yPixels = usedHeight -
        ((waypoint.y / fieldImageData.imageHeightInMeters * usedHeight) -
            heightOffset);
    double angle = waypoint.theta;

    double boxWidth = robotConfig.length *
        metersToPixelsRatio; // Width of the robot box in pixels
    double boxHeight = robotConfig.width *
        metersToPixelsRatio; // Height of the robot box in pixels

    // Calculate the four corners of the box
    List<Offset> corners = [
      Offset(-boxWidth / 2, -boxHeight / 2),
      Offset(boxWidth / 2, -boxHeight / 2),
      Offset(boxWidth / 2, boxHeight / 2),
      Offset(-boxWidth / 2, boxHeight / 2),
    ];

    // Rotate and translate the corners
    List<Offset> rotatedCorners = corners.map((corner) {
      double rotatedX =
          corner.dx * math.cos(angle) - corner.dy * math.sin(angle);
      double rotatedY =
          -(corner.dx * math.sin(angle) + corner.dy * math.cos(angle));
      return Offset(rotatedX + xPixels, rotatedY + yPixels);
    }).toList();

    // Draw the box
    Path path = Path()..addPolygon(rotatedCorners, true);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    // Draw the angle line
    double angleLineLength = boxWidth / 2;
    Offset angleLineEnd = Offset(
      xPixels + angleLineLength * math.cos(angle),
      yPixels - angleLineLength * math.sin(angle),
    );
    canvas.drawLine(Offset(xPixels, yPixels), angleLineEnd, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

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
