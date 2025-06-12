import 'dart:convert';
import 'dart:io';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathing_tool/Pages/pathing_page.dart';
import 'package:pathing_tool/Utils/Providers/image_data_provider.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:pathing_tool/Utils/Structs/image_data.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';
import 'package:pathing_tool/Utils/spline.dart';
import 'package:pathing_tool/Widgets/auto_editing/spline_orderer.dart';
import 'package:pathing_tool/Widgets/path_editor.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '../Utils/Providers/preference_provider.dart';

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
    return _AutoEditorState(splines, autoName);
  }

  static AutoEditor fromFile(File file) {
    String jsonString = file.readAsStringSync();
    var pathJson = json.decode(jsonString);
    return fromJson(pathJson);
  }

  static AutoEditor fromJson(Map<String, dynamic> json) {
    String autoName = json['meta_data']['auto_name'];
    List<Spline> splines = [];
    var paths = json['paths'];
    for (var scheduleItem in json['schedule']) {
      if (scheduleItem['branched']) {
        var onTrue = SplineSet.fromJsonList(
            scheduleItem["branched_path"]["on_true"], paths);
        var onFalse = SplineSet.fromJsonList(
            scheduleItem["branched_path"]["on_false"], paths);
        var condition = scheduleItem["condition"];
        splines.add(BranchedSpline(onTrue, onFalse, condition));
      } else {
        splines.add(Spline.fromJson(paths[scheduleItem['path']]));
      }
    }
    return AutoEditor(splines, autoName);
  }
}

class _AutoEditorState extends State<AutoEditor>
    with SingleTickerProviderStateMixin {
  List<List<Spline>> undoStack = [];
  List<List<Spline>> redoStack = [];
  List<Spline> splines = [];
  int selectedSpline = -1;
  late FocusNode _focusNode;
  String autoName = "";
  Waypoint? playbackWaypoint;
  double duration = 0;
  bool playing = false;
  late AnimationController _animationController;
  _AutoEditorState(List<Spline> splines, String autoName) {
    this.splines = [...splines];
    this.autoName = autoName;
  }
  Waypoint? _getPlaybackWaypoint() {
    double wantedTime = _animationController.value * duration;
    RobotConfigProvider? robotConfigProvider =
        Provider.of<RobotConfigProvider>(context, listen: false);
    double currentDuration = 0;
    for (var spline in splines) {
      currentDuration += spline.duration;
      if (wantedTime <= currentDuration) {
        if (robotConfigProvider.robotConfig.tank) {
          return spline.getTankWaypoint(_animationController.value * duration -
              (currentDuration) +
              spline.startTime +
              spline.duration);
        }
        return spline.getRobotWaypoint(_animationController.value * duration -
            (currentDuration) +
            spline.startTime +
            spline.duration);
      }
    }
    return null;
  }

  @override
  void initState() {
    for (var spline in splines) {
      duration += spline.duration;
    }
    _focusNode = FocusNode();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(microseconds: (duration * 1000000).round()),
    )..addListener(() {
        setState(() {
          playbackWaypoint = _getPlaybackWaypoint();
        });
      });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final robotConfigProvider = Provider.of<RobotConfigProvider>(context);
    duration = 0;
    for (var spline in splines) {
      duration += spline.duration;
    }
    // print('duration: $duration');
    _animationController.duration =
        Duration(microseconds: (duration * 1000000).round());
    _animationController.stop();
    if (playing && splines.length > 0) {
      _animationController.repeat();
    }
    // print(_animationController.duration);
    var theme = Theme.of(context);
    final focusScope = FocusScope.of(context);
    if (!(focusScope.focusedChild?.ancestors.contains(_focusNode) ?? false) &&
        !(focusScope.focusedChild.hashCode == _focusNode.hashCode)) {
      focusScope.requestFocus(_focusNode);
    }

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
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.space):
              PlayIntent(),
        },
        child: Actions(
            actions: <Type, Action<Intent>>{
              UndoIntent: UndoAction(_undo),
              RedoIntent: RedoAction(_redo),
              SaveIntent: SaveAction(() => _saveAutoToFile()),
              PlayIntent: PlayAction(() => _playPath()),
            },
            child: Focus(
                autofocus: true,
                focusNode: _focusNode,
                child: Scaffold(
                    persistentFooterButtons: [
                      ProgressBar(
                        baseBarColor: theme.primaryColor.withOpacity(0.3),
                        thumbColor: theme.primaryColor,
                        thumbGlowColor: theme.primaryColor.withOpacity(0.2),
                        progress: Duration(
                            microseconds: (_animationController.value *
                                    duration *
                                    1000000)
                                .round()),
                        total: Duration(
                            microseconds: (duration * 1000000).round()),
                        progressBarColor: theme.primaryColor,
                        onDragStart: (details) {
                          _animationController.stop();
                          var pathTime =
                              details.timeStamp.inMicroseconds / 1000000;
                          _animationController.value = pathTime / duration;
                        },
                        onDragUpdate: (details) {
                          var pathTime =
                              details.timeStamp.inMicroseconds / 1000000;
                          _animationController.value = pathTime / duration;
                        },
                        onDragEnd: () {
                          if (playing) {
                            _animationController.repeat();
                          }
                        },
                      ),
                    ],
                    appBar: AppBar(
                      automaticallyImplyLeading: false,
                      title: TextField(
                        controller: TextEditingController(text: autoName),
                        onSubmitted: (value) {
                          setState(() {
                            autoName = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter auto name',
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
                      actions: [
                        Tooltip(
                          message: "Play Path",
                          waitDuration: const Duration(milliseconds: 500),
                          child: TextButton(
                            onPressed: duration > 0
                                ? () {
                                    _playPath();
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
                        Tooltip(
                          message: "Send to Robot",
                          waitDuration: const Duration(milliseconds: 500),
                          child: IconButton(
                              onPressed: _sendFileToRobotFRC,
                              color: theme.primaryColor,
                              icon: const Icon(Icons.folder_open)),
                        ),
                        Tooltip(
                          message: "Save Path to File",
                          waitDuration: const Duration(milliseconds: 500),
                          child: ElevatedButton(
                              onPressed: _saveAutoToFile,
                              child: const Icon(Icons.save)),
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
                        CustomPaint? playbackPaint = playbackWaypoint != null
                            ? CustomPaint(
                                size: Size(availableHeight, availableWidth),
                                painter: RobotPainter(
                                    playbackWaypoint!,
                                    fieldImageData,
                                    usedWidth,
                                    usedHeight,
                                    context,
                                    robotConfigProvider.robotConfig,
                                    theme.brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    255,
                                    constraints),
                              )
                            : null;
                        return Center(
                            child: GestureDetector(
                                child: Stack(
                                    alignment: AlignmentDirectional.center,
                                    children: [
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
                                  for (double t = spline.points.first.t;
                                      t <= endTime;
                                      t += timeStep) {
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
                                          color: theme.brightness ==
                                                  Brightness.dark
                                              ? Colors.grey.shade500
                                                  .withOpacity(
                                                      splines.indexOf(spline) ==
                                                              selectedSpline
                                                          ? 1
                                                          : 0.3)
                                              : Colors.black.withOpacity(
                                                  splines.indexOf(spline) ==
                                                          selectedSpline
                                                      ? 1
                                                      : 0.3),
                                          dotData: const FlDotData(show: false),
                                        ),
                                      ],
                                      minX: 0,
                                      minY: 0,
                                      maxX: fieldImageData.imageWidthInMeters,
                                      maxY: fieldImageData.imageHeightInMeters,
                                      gridData: const FlGridData(show: false),
                                      titlesData:
                                          const FlTitlesData(show: false),
                                      borderData: FlBorderData(show: false),
                                      lineTouchData:
                                          const LineTouchData(enabled: false),
                                    ),
                                  ),
                                );
                              }),
                              if (playbackPaint != null)
                                Container(
                                  alignment: AlignmentDirectional.topStart,
                                  child: playbackPaint,
                                )
                            ])));
                      }))),
                      Container(
                          width: 350,
                          decoration: BoxDecoration(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(15)),
                            color: theme.primaryColor.withOpacity(0.2),
                          ),
                          child: LayoutBuilder(builder: (context, constraints) {
                            return SizedBox(
                                height: constraints.maxHeight,
                                child: SplineOrderer(
                                    splines,
                                    _onSplineSelected,
                                    _onEdit,
                                    _onDelete,
                                    selectedSpline,
                                    _onMoveForward,
                                    _onMoveBackward,
                                    _onBranchedPathAdded,
                                    _newPath,
                                    _onChanged));
                          })),
                    ])))));
  }

  _onSplineSelected(int index) {
    setState(() {
      selectedSpline = index;
    });
  }

  _onEdit(Spline? spline, bool lastLocked, {Function(Spline)? returnSpline}) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return PathingPage.fromSpline(spline ?? splines[selectedSpline],
          returnSpline: returnSpline ?? _returnSpline,
          firstLocked: selectedSpline != 0 || returnSpline != null,
          lastLocked: lastLocked);
    }));
  }

  _returnSpline(Spline spline) {
    _saveState();
    setState(() {
      splines[selectedSpline] = spline;
    });
  }

  _onChanged(Spline spline, int index) {
    setState(() {
      _saveState();
      splines[index] = spline;
      selectedSpline = index;
    });
  }

  _onDelete() {
    setState(() {
      if (selectedSpline != -1) {
        _saveState();
        splines.removeAt(selectedSpline);
        selectedSpline -= 1;
      }
    });
  }

  _onMoveForward() {
    _saveState();
    setState(() {
      if (selectedSpline < splines.length - 1) {
        // Move the spline forward
        var spline = splines[selectedSpline];
        splines.remove(spline);
        splines.insert(selectedSpline + 1, spline);
        selectedSpline += 1;
      }
    });
  }

  _onMoveBackward() {
    _saveState();
    setState(() {
      if (selectedSpline > 0) {
        // Move the spline backward
        var spline = splines[selectedSpline];
        splines.remove(spline);
        splines.insert(selectedSpline - 1, spline);
        selectedSpline -= 1;
      }
    });
  }

  _saveState() {
    setState(() {
      undoStack = [
        ...undoStack,
        [for (var spline in splines) spline.copyWith()]
      ];
      redoStack.clear();
    });
  }

  _undo() {
    if (undoStack.isNotEmpty) {
      setState(() {
        redoStack = [
          ...redoStack,
          [for (var spline in splines) spline.copyWith()]
        ];
        if (splines.length != undoStack.last.length) {
          selectedSpline = -1;
        }
        splines = undoStack.last;
        undoStack.removeLast();
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
        Spline newSpline = Spline.fromPolarPathFile(pathFile);
        splines.add(newSpline);
      }
      selectedSpline = splines.length - 1;
    });
  }

  _newPath() {
    bool pathAdded = false;
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("New Path", style: theme.textTheme.titleLarge),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      onChanged: (value) {
                        setState(() {
                          pathAdded = value.trim().isNotEmpty;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Path Name',
                        focusColor: theme.primaryColor,
                        hoverColor: theme.primaryColor,
                        floatingLabelStyle:
                            TextStyle(color: theme.primaryColor),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: theme.primaryColor),
                        ),
                      ),
                      cursorColor: theme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: pathAdded
                          ? () {
                              splines.add(Spline(
                                [],
                                commands: [],
                                name: controller.text,
                              ));
                              Navigator.pop(context);
                            }
                          : null,
                      child: Text(
                        "Add Path",
                        style: TextStyle(
                          color: pathAdded ? null : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadPath();
                    },
                    child: const Text("Load From File")),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: theme.primaryColor),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    setState(() {
      _saveState();
      if (pathAdded) selectedSpline = splines.length - 1;
    });
  }

  _onBranchedPathAdded() {
    setState(() {
      _saveState();
      splines.add(BranchedSpline(
        SplineSet([]),
        SplineSet([]),
        "",
        isTrue: true,
      ));
      selectedSpline = splines.length - 1;
    });
  }

  String _toJSON() {
    List<Map<String, dynamic>> schedule = [];
    List<Map<String, dynamic>> paths = [];
    int pathIndex = 0;
    for (var spline in splines) {
      var (scheduleItem, newIndex) = spline.scheduleItem(pathIndex);
      pathIndex = newIndex;
      schedule.add(scheduleItem);
      if (spline is BranchedSpline) {
        paths.addAll(spline.onTrue.toJsonList());
        paths.addAll(spline.onFalse.toJsonList());
      } else {
        paths.add(spline.toJson());
      }
    }
    final robotConfigProvider =
        Provider.of<RobotConfigProvider>(context, listen: false);
    final fieldConfigProvider =
        Provider.of<ImageDataProvider>(context, listen: false);
    Map<String, dynamic> metaData = {
      "auto_name": autoName,
      "robot_name": robotConfigProvider.robotConfig.name,
      "field_name": fieldConfigProvider.selectedImage.imageName,
    };
    Map<String, dynamic> jsonAuto = {
      "meta_data": metaData,
      "schedule": schedule,
      "paths": paths,
    };
    String jsonString = json.encode(jsonAuto);
    return jsonString;
  }

  _saveAutoToFile() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "Save to which folder?",
        initialDirectory:
            "${Provider.of<PreferenceProvider>(context, listen: false).repositoryPath}\\src\\main\\deploy\\");
    if (selectedDirectory == null) {
      // User canceled the picker
      return;
    }
    // Define the file path
    final String path = p.join(selectedDirectory, '$autoName.polarauto');
    // Write the JSON object to a file
    File savePathFile = File(path);
    savePathFile.writeAsString(_toJSON()).then((value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Auto saved to ${savePathFile.path}")),
      );
    });
  }

  _playPath() {
    if (!playing) {
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

  // Spline _handleFirstPoint(Spline newSpline, Waypoint preferredPoint) {
  //   // print("hi, I'm handling the first point");
  //   if (newSpline.points.isNotEmpty) {
  //     // print(newSpline.points.first.time);
  //     return newSpline.copyWith(points: [
  //       preferredPoint.copyWith(t: newSpline.points.first.time - 1),
  //       ...newSpline.points
  //     ]);
  //   }
  //   // print("Returning new spline with first point at 0.0");
  //   return newSpline.copyWith(points: [preferredPoint.copyWith(t: 0.0)]);
  // }

  _sendFileToRobotFRC() async {
    List<String> robotIPs = ["10.44.99.2", "172.22.11.2", "42.42.42.42"];
    SSHClient? robotClient;
    for (String robotIP in robotIPs) {
      try {
        robotClient =
            SSHClient(await SSHSocket.connect(robotIP, 22), username: "lvuser");
        break;
      } catch (error) {}
    }
    if (robotClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to connect to any robot")),
      );
      return;
    }
    var robotSFTP = await robotClient.sftp();
    var file;
    try {
      await robotSFTP.open(
        './deploy/$autoName.polarauto',
        mode: SftpFileOpenMode.create,
      );
      file = await robotSFTP.open('./deploy/$autoName.polarauto',
          mode: SftpFileOpenMode.write);
    } catch (e) {
      await robotSFTP.remove(
        './deploy/$autoName.polarauto',
      );
      await robotSFTP.open(
        './deploy/$autoName.polarauto',
        mode: SftpFileOpenMode.create,
      );
      file = await robotSFTP.open('./deploy/$autoName.polarauto',
          mode: SftpFileOpenMode.write);
    }
    await file.writeBytes(utf8.encode(_toJSON()));
    robotClient.close();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Auto saved to robot")),
    );
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
