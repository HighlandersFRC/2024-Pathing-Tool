import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
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
  final List<Command> startingCommands;
  final String pathName;
  final Function(Spline)? returnSpline;
  final bool firstLocked, lastLocked;
  const PathEditor(this.startingWaypoints, this.pathName, this.startingCommands,
      {super.key,
      this.returnSpline,
      this.firstLocked = false,
      this.lastLocked = false});
  static PathEditor fromFile(File file, Function(Spline)? returnSpline) {
    String jsonString = file.readAsStringSync();
    var pathJson = json.decode(jsonString);
    var pointsJsonList = pathJson["key_points"];
    List<Waypoint> waypoints = [];
    pointsJsonList.forEach((point) {
      waypoints.add(Waypoint.fromJson(point));
    });
    List<Command> commands = [];
    var commandsJsonList = pathJson["commands"];
    commandsJsonList.forEach((command) {
      commands.add(Command.fromJson(command));
    });
    String pathName = pathJson["meta_data"]["path_name"];
    return PathEditor(waypoints, pathName, commands,
        returnSpline: returnSpline);
  }

  @override
  _PathEditorState createState() =>
      _PathEditorState(startingWaypoints, startingCommands, pathName);
}

class _PathEditorState extends State<PathEditor>
    with SingleTickerProviderStateMixin {
  List<(List<Waypoint>, List<Command>, bool)> undoStack = [];
  List<(List<Waypoint>, List<Command>, bool)> redoStack = [];
  List<Waypoint> waypoints = [];
  List<Command> commands = [];
  Waypoint? playbackWaypoint;
  bool smooth = false;
  bool playing = false;
  int editMode = 0;
  int selectedWaypoint = -1;
  int selectedCommand = -1;
  String pathName = "";
  late AnimationController _animationController;
  late FocusNode _focusNode;
  _PathEditorState(List<Waypoint> startingWaypoints,
      List<Command> startingCommands, this.pathName) {
    waypoints = [...startingWaypoints];
    commands = [...startingCommands];
  }
  @override
  void initState() {
    _focusNode = FocusNode();
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration:
          Duration(microseconds: ((endTime - startTime) * 1000000).round()),
    )..addListener(() {
        setState(() {
          playbackWaypoint = _getPlaybackWaypoint();
        });
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Waypoint _getPlaybackWaypoint() {
    var robot = Spline(waypoints, commands: commands);
    return robot.getRobotWaypoint(
        _animationController.value * (endTime - startTime) + startTime);
  }

  void playPath() {
    if (!_animationController.isAnimating) {
      _animationController.repeat();
      setState(() {
        playing = true;
      });
    } else {
      _animationController.stop();
      setState(() {
        playing = false;
      });
    }
  }

  void _backward() {
    _animationController.value = math.max(
        0,
        waypoints.length > 1
            ? waypoints
                    .lastWhere(
                        (waypoint) =>
                            waypoint.t <
                            _animationController.value * waypoints.last.t,
                        orElse: () => waypoints.first)
                    .t /
                waypoints.last.t
            : 0);
    setState(() {
      playing = false;
    });
  }

  void _forward() {
    _animationController.value = math.min(
        1,
        waypoints.length > 1
            ? waypoints
                    .firstWhere(
                        (waypoint) =>
                            waypoint.t >
                            _animationController.value * waypoints.last.t,
                        orElse: () => waypoints.last)
                    .t /
                waypoints.last.t
            : 0);
    setState(() {
      playing = false;
    });
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
    final focusScope = FocusScope.of(context);
    if (!(focusScope.focusedChild?.ancestors.contains(_focusNode) ?? false) &&
        !(focusScope.focusedChild.hashCode == _focusNode.hashCode)) {
      focusScope.requestFocus(_focusNode);
    }
    _animationController.duration =
        Duration(microseconds: ((endTime - startTime) * 1000000).round());
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
      for (double t = waypoints.first.t; t <= endTime; t += timeStep) {
        Waypoint point = robot.getRobotWaypoint(t);
        fullSpline.add(FlSpot(point.x, point.y));
      }
    }
    if (waypoints.length > 1 && selectedCommand != -1) {
      Spline robot = Spline(waypoints);
      double timeStep = 0.01; // Adjust for desired granularity
      double start =
          max(commands[selectedCommand].startTime, robot.points.first.t);
      double endTime = commands[selectedCommand].endTime;
      for (double t = start;
          t <= endTime && t <= robot.points.last.t;
          t += timeStep) {
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
        "meta_data": {
          "path_name": pathName,
          "sample_rate": timeStep,
          "robot_name": robotConfigProvider.robotConfig.name,
          "field_name": imageDataProvider.selectedImage.imageName
        },
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
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.tab):
              SwitchModeIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.space):
              PlayIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): BackwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): ForwardIntent(),
        },
        child: Actions(
            actions: <Type, Action<Intent>>{
              UndoIntent: UndoAction(_undo),
              RedoIntent: RedoAction(_redo),
              SaveIntent: SaveAction(() => savePathToFile()),
              SwitchModeIntent: SwitchModeAction(() => setState(() {
                    switch (editMode) {
                      case 0:
                        editMode = 1;
                        break;
                      case 1:
                        editMode = 2;
                        break;
                      default:
                        editMode = 0;
                    }
                  })),
              PlayIntent: PlayAction(() => playPath()),
              BackwardIntent: BackwardAction(_backward),
              ForwardIntent: ForwardAction(_forward),
            },
            child: Focus(
                focusNode: _focusNode,
                child: Scaffold(
                  persistentFooterButtons: [
                    ProgressBar(
                      baseBarColor: theme.primaryColor.withOpacity(0.3),
                      thumbColor: theme.primaryColor,
                      thumbGlowColor: theme.primaryColor.withOpacity(0.2),
                      progress: Duration(
                          microseconds: waypoints.isNotEmpty
                              ? ((_animationController.value *
                                          (endTime - startTime)) *
                                      1000000)
                                  .floor()
                              : 0),
                      total: Duration(
                          microseconds: waypoints.isNotEmpty
                              ? ((endTime - startTime) * 1000000).floor()
                              : 0),
                      progressBarColor: theme.primaryColor,
                      onDragStart: (details) {
                        _animationController.stop();
                        var pathTime =
                            details.timeStamp.inMicroseconds / 1000000;
                        _animationController.value =
                            pathTime / waypoints.last.t;
                      },
                      onDragUpdate: (details) {
                        var pathTime =
                            details.timeStamp.inMicroseconds / 1000000;
                        _animationController.value =
                            pathTime / waypoints.last.t;
                      },
                      onDragEnd: () {
                        if (playing) {
                          _animationController.repeat();
                        }
                      },
                    ),
                  ],
                  appBar: AppBar(
                    leading: widget.returnSpline != null
                        ? Tooltip(
                            message: "Back",
                            waitDuration: const Duration(milliseconds: 500),
                            child: TextButton(
                                onPressed: () {
                                  widget.returnSpline!(Spline(waypoints,
                                      commands: commands, name: pathName));
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
                          child: Icon(!playing
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded),
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
                                          editMode == 2 &&
                                                  selectedCommand != -1 &&
                                                  playbackWaypoint!.t >
                                                      commands[selectedCommand]
                                                          .startTime &&
                                                  playbackWaypoint!.t <
                                                      commands[selectedCommand]
                                                          .endTime
                                              ? theme.primaryColor
                                              : theme.brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : Colors.grey.shade700,
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
                                            duration: const Duration(
                                                milliseconds: 250),
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
                                                    barWidth: 10,
                                                    color: theme.brightness ==
                                                            Brightness.dark
                                                        ? theme.primaryColor
                                                            .withOpacity(0.5)
                                                        : theme.primaryColor
                                                            .withOpacity(0.4),
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
                                          ...waypoints
                                              .asMap()
                                              .entries
                                              .map((value) {
                                            Waypoint waypoint = value.value;
                                            int index = value.key;
                                            if (!((widget.lastLocked &&
                                                    index ==
                                                        waypoints.length - 1) ||
                                                ((widget.firstLocked || widget.lastLocked) &&
                                                    index == 0))) {
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
                                                metersToPixelsRatio *
                                                    waypoint.dx,
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
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                          }),
                                        if (editMode == 1)
                                          ...waypoints
                                              .asMap()
                                              .entries
                                              .map((value) {
                                            Waypoint waypoint = value.value;
                                            int index = value.key;
                                            if (!((widget.lastLocked &&
                                                    index ==
                                                        waypoints.length - 1) ||
                                                ((widget.firstLocked || widget.lastLocked) &&
                                                    index == 0))) {
                                              return DraggableHandleTheta(
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
                                              );
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                          }),
                                        if (editMode == 1)
                                          ...waypoints
                                              .asMap()
                                              .entries
                                              .map((value) {
                                            Waypoint waypoint = value.value;
                                            int index = value.key;
                                            if (!((widget.lastLocked &&
                                                    index ==
                                                        waypoints.length - 1) ||
                                                ((widget.firstLocked || widget.lastLocked) &&
                                                    index == 0))) {
                                              return DraggableHandlePosition(
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
                                              );
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                          }),
                                        if (editMode == 1)
                                          ...waypoints
                                              .asMap()
                                              .entries
                                              .map((value) {
                                            Waypoint waypoint = value.value;
                                            int index = value.key;
                                            if (!((widget.lastLocked &&
                                                    index ==
                                                        waypoints.length - 1) ||
                                                ((widget.firstLocked || widget.lastLocked) &&
                                                    index == 0))) {
                                              return VelocityHandle(
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
                                              );
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                          }),
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
                                        waypoints: [
                                          for (var waypoint in waypoints)
                                            waypoint.copyWith()
                                        ],
                                        onWaypointSelected: _onWaypointSelected,
                                        onAttributeChanged: _onAttributeChanged,
                                        selectedWaypoint: waypoints.length >=
                                                selectedWaypoint - 1
                                            ? selectedWaypoint
                                            : -1,
                                        onWaypointsChanged: _onWaypointsChanged,
                                        firstLocked: (widget.firstLocked || widget.lastLocked),
                                        lastLocked: widget.lastLocked,
                                      )
                                    else
                                      EditCommandMenu(
                                          commands: [
                                            for (var command in commands)
                                              command.copyWith()
                                          ],
                                          onCommandSelected: _onCommandSelected,
                                          onAttributeChanged:
                                              _onCommandAttributeChanged,
                                          selectedCommand: selectedCommand,
                                          onCommandsChanged:
                                              _onCommandsChanged),
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
        waypoints[selectedWaypoint] = waypoint.copyWith();
        waypoint = waypoints[selectedWaypoint];
        waypoints.sort((a, b) => a.t.compareTo(b.t));
        selectedWaypoint = waypoints.indexOf(waypoint);
        smooth = false;
      });
    }
  }

  _onWaypointSelected(int index) {
    setState(() {
      selectedWaypoint = index;
    });
  }

  _onCommandSelected(int index) {
    setState(() {
      selectedCommand = index;
    });
  }

  _onCommandAttributeChanged(Command command) {
    // print("command attribute changed");
    if (selectedCommand != -1) {
      _saveState();
      setState(() {
        List<Command> newCommands = [];
        for (var existingCommand in commands) {
          if (commands[selectedCommand] == existingCommand) {
            newCommands.add(command.copyWith());
          } else {
            newCommands.add(existingCommand);
          }
        }
        commands = [for (var command in newCommands) command.copyWith()];
      });
    }
  }

  _saveState() {
    // print("saving state");
    setState(() {
      undoStack = [
        ...undoStack,
        (
          [for (var waypoint in waypoints) waypoint.copyWith()],
          [for (var command in commands) command.copyWith()],
          smooth
        )
      ];
      redoStack.clear();
    });
  }

  _undo() {
    if (undoStack.isNotEmpty) {
      setState(() {
        redoStack = [
          ...redoStack,
          (
            [...this.waypoints],
            [for (var command in this.commands) command.copyWith()],
            this.smooth
          )
        ];
        var (waypoints, commands, smooth) = undoStack.last;
        if (!(this.waypoints.length == waypoints.length)) {
          selectedWaypoint = -1;
        }
        if (!(this.commands.length == commands.length)) {
          selectedCommand = -1;
        }
        this.waypoints = waypoints;
        this.commands = commands;
        this.smooth = smooth;
        undoStack.removeLast();
      });
    }
  }

  _redo() {
    if (redoStack.isNotEmpty) {
      setState(() {
        undoStack = [
          ...undoStack,
          (
            [...this.waypoints],
            [for (var command in this.commands) command.copyWith()],
            this.smooth
          )
        ];
        var (waypoints, commands, smooth) = redoStack.removeLast();
        this.waypoints = waypoints;
        this.commands = commands;
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

  _onCommandsChanged(List<Command> commands) {
    // print("commands changed");
    _saveState();
    setState(() {
      this.selectedCommand = -1;
      this.commands = [for (var command in commands) command.copyWith()];
    });
  }

  (double, double) _averageLinearVelocity(int index) {
    double dy = 0, dx = 0;
    if (index != 0 && index != waypoints.length - 1) {
      Waypoint p0 = waypoints[index - 1];
      Waypoint p2 = waypoints[index + 1];
      double dt = p2.time - p0.time;
      double deltaX = p2.x - p0.x;
      double deltaY = p2.y - p0.y;
      dx = deltaX / dt;
      dy = deltaY / dt;
    } else {
      if (index == 0 && (widget.firstLocked || widget.lastLocked) ||
          index == waypoints.length - 1 && widget.lastLocked) {
        Waypoint p1 = waypoints[index];
        dy = p1.dy;
        dx = p1.dx;
      } else {
        dy = 0;
        dx = 0;
      }
    }
    return (dy, dx);
  }

  (double, double) _averageLinearAcceleration(
      int index, List<Waypoint> waypoints) {
    double d2y = 0, d2x = 0;
    if (index != 0 && index != waypoints.length - 1) {
      Waypoint p0 = waypoints[index - 1];
      Waypoint p2 = waypoints[index + 1];
      double dt = p2.time - p0.time;
      double deltaX = p2.dx - p0.dx;
      double deltaY = p2.dy - p0.dy;
      d2x = deltaX / pow(dt, 2);
      d2y = deltaY / pow(dt, 2);
    } else {
      if (index == 0 && (widget.firstLocked || widget.lastLocked) ||
          index == waypoints.length - 1 && widget.lastLocked) {
        Waypoint p1 = waypoints[index];
        d2y = p1.d2y;
        d2x = p1.d2x;
      } else {
        d2y = 0;
        d2x = 0;
      }
    }
    return (d2y, d2x);
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
      if (index == 0 && (widget.firstLocked || widget.lastLocked) ||
          index == waypoints.length - 1 && widget.lastLocked) {
        Waypoint p1 = waypoints[index];
        angVel = p1.dtheta;
      } else {
        angVel = 0;
      }
    }
    return angVel;
  }

  double _averageAngularAcceleration(int index, List<Waypoint> waypoints) {
    double angAcc;
    if (index != 0 && index != waypoints.length - 1) {
      Waypoint p0 = waypoints[index - 1];
      Waypoint p2 = waypoints[index + 1];
      double dt = p2.time - p0.time;
      double d2a = p2.dtheta - p0.dtheta;
      angAcc = d2a / pow(dt, 2);
    } else {
      if (index == 0 && (widget.firstLocked || widget.lastLocked) ||
          index == waypoints.length - 1 && widget.lastLocked) {
        Waypoint p1 = waypoints[index];
        angAcc = p1.d2theta;
      } else {
        angAcc = 0;
      }
    }
    return angAcc;
  }

  _averageAll() {
    List<Waypoint> newWaypoints = [];
    for (int i = 0; i < waypoints.length; i++) {
      var (dy, dx) = _averageLinearVelocity(i);
      var dtheta = _averageAngularVelocity(i);
      newWaypoints.add(waypoints[i].copyWith(dy: dy, dx: dx, dtheta: dtheta));
    }
    for (int i = 0; i < newWaypoints.length; i++) {
      var (d2y, d2x) = _averageLinearAcceleration(i, newWaypoints);
      var d2theta = _averageAngularAcceleration(i, newWaypoints);
      newWaypoints[i] =
          newWaypoints[i].copyWith(d2y: d2y, d2x: d2x, d2theta: d2theta);
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

  double get startTime {
    if (waypoints.isEmpty) {
      if (commands.isEmpty) return 0.0;
      return getFirstStartTime(commands, 0.0);
    } else {
      if (commands.isEmpty) return waypoints.first.time;
      return min(getFirstStartTime(commands, 0.0), waypoints.first.time);
    }
  }

  double get endTime {
    if (waypoints.isEmpty) {
      if (commands.isEmpty) return 0.0;
      return getLastEndTime(commands, 0.0);
    } else {
      if (commands.isEmpty) return waypoints.last.time;
      return max(getLastEndTime(commands, 0.0), waypoints.last.time);
    }
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

class SwitchModeAction extends Action<Intent> {
  final VoidCallback onCommands;

  SwitchModeAction(this.onCommands);

  @override
  Object? invoke(covariant Intent intent) {
    onCommands();
    return null;
  }
}

class PlayAction extends Action<Intent> {
  final VoidCallback onPlay;

  PlayAction(this.onPlay);

  @override
  Object? invoke(covariant Intent intent) {
    onPlay();
    return null;
  }
}

class ForwardAction extends Action<Intent> {
  final VoidCallback onForward;

  ForwardAction(this.onForward);

  @override
  Object? invoke(covariant Intent intent) {
    onForward();
    return null;
  }
}

class BackwardAction extends Action<Intent> {
  final VoidCallback onBackward;

  BackwardAction(this.onBackward);

  @override
  Object? invoke(covariant Intent intent) {
    onBackward();
    return null;
  }
}

class UndoIntent extends Intent {}

class RedoIntent extends Intent {}

class SaveIntent extends Intent {}

class SwitchModeIntent extends Intent {}

class PlayIntent extends Intent {}

class ForwardIntent extends Intent {}

class BackwardIntent extends Intent {}
