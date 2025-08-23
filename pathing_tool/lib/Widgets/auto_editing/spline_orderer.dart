import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:pathing_tool/Utils/spline.dart';
import 'package:provider/provider.dart';

import '../../Utils/Providers/preference_provider.dart';

class SplineOrderer extends StatefulWidget {
  final List<Spline> splines;
  final Function(int) onSplineSelected;
  final Function() onDelete,
      onMoveForward,
      onMoveBackward,
      onBranchedSplineAdded,
      onSplineAdded;
  final Function(Spline?, bool,
      {Function(Spline)? returnSpline, Spline? previous}) onEdit;
  final Function(Spline, int) onChanged;
  final int splineIndex;
  const SplineOrderer(
    this.splines,
    this.onSplineSelected,
    this.onEdit,
    this.onDelete,
    this.splineIndex,
    this.onMoveForward,
    this.onMoveBackward,
    this.onBranchedSplineAdded,
    this.onSplineAdded,
    this.onChanged, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() {
    return _SplineOrdererState();
  }
}

class _SplineOrdererState extends State<SplineOrderer> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
        child: Column(children: [
      ExpansionPanelList(
        elevation: 0,
        dividerColor: theme.primaryColor,
        materialGapSize: 0,
        expansionCallback: (idx, isExpanded) {
          if (!isExpanded) {
            widget.onSplineSelected(-1);
          } else {
            widget.onSplineSelected(idx);
          }
        },
        children: [
          for (var spline in widget.splines.asMap().entries)
            ExpansionPanel(
                canTapOnHeader: true,
                backgroundColor: theme.primaryColor.withOpacity(0.2),
                headerBuilder: (context, isExpanded) {
                  return ListTile(
                    title: Text(
                      "${spline.value.name} - ${spline.value.duration} seconds",
                    ),
                  );
                },
                isExpanded: spline.key == widget.splineIndex,
                body: SplineEditor(
                  spline.value,
                  spline.key,
                  widget.onMoveForward,
                  widget.onMoveBackward,
                  widget.onEdit,
                  widget.onDelete,
                  widget.splines.length,
                  (Spline newSpline) => widget.onChanged(newSpline, spline.key),
                  previous:
                      spline.key > 0 ? widget.splines[spline.key - 1] : null,
                ))
        ],
      ),
      ElevatedButton(
          onPressed: widget.onBranchedSplineAdded,
          child: const Text('Add Branched Path')),
      ElevatedButton(
          onPressed: widget.onSplineAdded, child: const Text('Add Path')),
    ]));
  }
}

class SplineEditor extends StatelessWidget {
  final Spline spline;
  final Spline? previous;
  final int splineIndex;
  final int length;
  final Function() onMoveForward, onMoveBackward, onDelete;
  final Function(Spline?, bool,
      {Function(Spline)? returnSpline, Spline? previous}) onEdit;
  final Function(Spline) onChanged;
  final bool isBranch, lastLocked;
  const SplineEditor(
    this.spline,
    this.splineIndex,
    this.onMoveForward,
    this.onMoveBackward,
    this.onEdit,
    this.onDelete,
    this.length,
    this.onChanged, {
    super.key,
    this.isBranch = false,
    this.lastLocked = false,
    this.previous,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return spline is BranchedSpline
        ? BranchedSplineEditor(spline as BranchedSpline, splineIndex,
            onMoveForward, onMoveBackward, onEdit, onDelete, length, onChanged)
        : Column(
            children: [
              Text(
                spline.name,
                style: theme.textTheme.headlineLarge,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isBranch)
                    IconButton(
                      onPressed: splineIndex != 0 ? onMoveBackward : null,
                      icon: const Icon(Icons.keyboard_arrow_left_rounded),
                      color: splineIndex != 0
                          ? theme.primaryColor
                          : Colors.grey[500],
                    ),
                  IconButton(
                    onPressed: () =>
                        onEdit(spline, lastLocked, previous: previous),
                    icon: const Icon(Icons.edit),
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  if (!isBranch)
                    IconButton(
                      onPressed:
                          splineIndex != length - 1 ? onMoveForward : null,
                      icon: const Icon(Icons.keyboard_arrow_right_rounded),
                      color: splineIndex != length - 1
                          ? theme.primaryColor
                          : Colors.grey[500],
                    )
                ],
              ),
            ],
          );
  }
}

class BranchedSplineEditor extends StatefulWidget {
  final BranchedSpline spline;
  final int splineIndex;
  final int length;
  final Function() onMoveForward, onMoveBackward, onDelete;
  final Function(Spline?, bool,
      {Function(Spline)? returnSpline, Spline? previous}) onEdit;
  final Function(Spline) onChanged;
  final bool lastLocked;
  const BranchedSplineEditor(
      this.spline,
      this.splineIndex,
      this.onMoveForward,
      this.onMoveBackward,
      this.onEdit,
      this.onDelete,
      this.length,
      this.onChanged,
      {super.key,
      this.lastLocked = false});

  _returnSpline(bool isTrue, int index, BuildContext context,
      {Function(Spline)? returnSpline, Spline? spline}) {
    RobotConfigProvider configProvider =
        Provider.of<RobotConfigProvider>(context);
    PreferenceProvider preferencesProvider =
        Provider.of<PreferenceProvider>(context);
    if (spline != null) {
      if (isTrue) {
        var splineList = [
          for (var spline in this
              .spline
              .onTrue
              .splines
              .indexed
              .where((spline) => spline.$1 != index))
            spline.$2
        ];
        splineList.insert(index, spline);
        onChanged(this.spline.copyWith(
            onTrue: SplineSet(splineList, configProvider.robotConfig,
                preferencesProvider.pathResolution)));
      } else {
        var splineList = [
          for (var spline in this
              .spline
              .onFalse
              .splines
              .indexed
              .where((spline) => spline.$1 != index))
            spline.$2
        ];
        splineList.insert(index, spline);
        onChanged(this.spline.copyWith(
            onFalse: SplineSet(splineList, configProvider.robotConfig,
                preferencesProvider.pathResolution)));
      }
    }
  }

  @override
  State<StatefulWidget> createState() => _BranchedSplineEditorState();
}

class _BranchedSplineEditorState extends State<BranchedSplineEditor> {
  BranchedSpline get spline => widget.spline;
  int selectedOnTrue = -1, selectedOnFalse = -1;
  _loadPath(bool isTrue) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['polarpath'],
    );
    setState(() {
      RobotConfigProvider configProvider =
          Provider.of<RobotConfigProvider>(context, listen: false);
      PreferenceProvider preferencesProvider =
          Provider.of<PreferenceProvider>(context, listen: false);
      var splines = spline.onTrue.splines;
      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        File pathFile = File(path);
        Spline newSpline = Spline.fromPolarPathFile(pathFile,
            configProvider.robotConfig, preferencesProvider.pathResolution);
        widget.onChanged(
          isTrue
              ? spline.copyWith(onTrue: spline.onTrue.addSpline(newSpline))
              : spline.copyWith(onFalse: spline.onFalse.addSpline(newSpline)),
        );
        setState(() {
          if (isTrue) {
            selectedOnTrue = splines.length - 1;
          } else {
            selectedOnFalse = splines.length - 1;
          }
        });
      }
    });
  }

  _newPath(bool isTrue) {
    bool pathAdded = false;
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        RobotConfigProvider configProvider =
            Provider.of<RobotConfigProvider>(context);
        PreferenceProvider preferencesProvider =
            Provider.of<PreferenceProvider>(context);
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
                              isTrue
                                  ? widget.onChanged(spline.copyWith(
                                      onTrue: spline.onTrue.addSpline(Spline(
                                      [],
                                      configProvider.robotConfig,
                                      preferencesProvider.pathResolution,
                                      name: controller.text,
                                    ))))
                                  : widget.onChanged(spline.copyWith(
                                      onFalse: spline.onFalse.addSpline(Spline(
                                      [],
                                      configProvider.robotConfig,
                                      preferencesProvider.pathResolution,
                                      name: controller.text,
                                    ))));
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
                      _loadPath(isTrue);
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
      if (pathAdded) {
        if (isTrue) {
          selectedOnTrue = spline.onTrue.splines.length - 1;
        } else {
          selectedOnFalse = spline.onFalse.splines.length - 1;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final robotConfigProvider = Provider.of<RobotConfigProvider>(context);
    var robotConditions = robotConfigProvider.robotConfig.conditions;
    final preferencesProvider = Provider.of<PreferenceProvider>(context);
    return Column(
      children: [
        Text(
          spline.name,
          style: theme.textTheme.headlineLarge,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: widget.splineIndex != 0 ? widget.onMoveBackward : null,
              icon: const Icon(Icons.keyboard_arrow_left_rounded),
              color: widget.splineIndex != 0
                  ? theme.primaryColor
                  : Colors.grey[500],
            ),
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete),
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
            IconButton(
              onPressed: widget.splineIndex != widget.length - 1
                  ? widget.onMoveForward
                  : null,
              icon: const Icon(Icons.keyboard_arrow_right_rounded),
              color: widget.splineIndex != widget.length - 1
                  ? theme.primaryColor
                  : Colors.grey[500],
            )
          ],
        ),
        DropdownButton<String>(
          value: spline.condition != '' ? spline.condition : null,
          hint: const Text('Select Condition'),
          onChanged: (value) {
            widget.onChanged(spline.copyWith(condition: value ?? ''));
          },
          items: robotConditions.map((robotCondition) {
            return DropdownMenuItem(
              value: robotCondition.name,
              child: Row(children: [
                Icon(robotCondition.icon),
                Text(" - ${robotCondition.name}")
              ]),
            );
          }).toList(),
        ),
        ExpansionPanelList(
          elevation: 0,
          dividerColor: theme.primaryColor,
          materialGapSize: 16,
          expansionCallback: (idx, isExpanded) {
            widget.onChanged(spline.copyWith(isTrue: !spline.isTrue));
          },
          children: [
            ExpansionPanel(
                canTapOnHeader: true,
                backgroundColor: theme.primaryColor.withOpacity(0.2),
                headerBuilder: (context, isExpanded) {
                  return ListTile(
                    tileColor: !isExpanded
                        ? theme.primaryColor.withOpacity(0.2)
                        : null,
                    title: Text(
                      "${spline.onTrue.name} - ${spline.onTrue.duration} seconds",
                    ),
                  );
                },
                isExpanded: spline.isTrue,
                body: SplineOrderer(
                    spline.onTrue.splines,
                    (int index) {
                      setState(() {
                        selectedOnTrue = index;
                      });
                    },
                    (spline, lastLocked,
                        {Function(Spline)? returnSpline, Spline? previous}) {
                      widget.onEdit(spline, true,
                          returnSpline: (Spline? newSpline) {
                        widget._returnSpline(true, selectedOnTrue, context,
                            returnSpline: returnSpline, spline: newSpline);
                      }, previous: previous);
                    },
                    () {
                      widget.onChanged(spline.copyWith(
                          onTrue: spline.onTrue.removeSpline(selectedOnTrue)));
                    },
                    selectedOnTrue,
                    () {
                      widget.onChanged(spline.copyWith(
                          onTrue:
                              spline.onTrue.moveSplineForward(selectedOnTrue)));
                    },
                    () {
                      widget.onChanged(spline.copyWith(
                          onTrue: spline.onTrue
                              .moveSplineBackward(selectedOnTrue)));
                    },
                    () {
                      var newSplines = spline.onTrue.splines;
                      newSplines.add(BranchedSpline(
                        SplineSet([], robotConfigProvider.robotConfig,
                            preferencesProvider.pathResolution),
                        SplineSet([], robotConfigProvider.robotConfig,
                            preferencesProvider.pathResolution),
                        "",
                        preferencesProvider.pathResolution,
                        isTrue: true,
                      ));
                      widget.onChanged(spline.copyWith(
                          onTrue: SplineSet(
                              newSplines,
                              robotConfigProvider.robotConfig,
                              preferencesProvider.pathResolution)));
                    },
                    () {
                      _newPath(true);
                    },
                    (spline, index) {
                      widget.onChanged(this.spline.copyWith(
                          onTrue: this
                              .spline
                              .onTrue
                              .onSplineChanged(index, spline)));
                    })),
            ExpansionPanel(
              canTapOnHeader: true,
              backgroundColor: theme.primaryColor.withOpacity(0.2),
              headerBuilder: (context, isExpanded) {
                return ListTile(
                  tileColor:
                      !isExpanded ? theme.primaryColor.withOpacity(0.2) : null,
                  title: Text(
                    "${spline.onFalse.name} - ${spline.onFalse.duration} seconds",
                  ),
                );
              },
              isExpanded: !spline.isTrue,
              body: SplineOrderer(
                  spline.onFalse.splines,
                  (int index) {
                    setState(() {
                      selectedOnFalse = index;
                    });
                  },
                  (spline, lastLocked,
                      {Function(Spline)? returnSpline, Spline? previous}) {
                    widget.onEdit(spline, false,
                        returnSpline: (Spline? newSpline) {
                      widget._returnSpline(false, selectedOnFalse, context,
                          returnSpline: returnSpline, spline: newSpline);
                    });
                  },
                  () {
                    widget.onChanged(spline.copyWith(
                        onFalse: spline.onFalse.removeSpline(selectedOnFalse)));
                  },
                  selectedOnFalse,
                  () {
                    widget.onChanged(spline.copyWith(
                        onFalse:
                            spline.onFalse.moveSplineForward(selectedOnFalse)));
                  },
                  () {
                    widget.onChanged(spline.copyWith(
                        onFalse: spline.onFalse
                            .moveSplineBackward(selectedOnFalse)));
                  },
                  () {
                    var newSplines = spline.onFalse.splines;
                    newSplines.add(BranchedSpline(
                      SplineSet([], robotConfigProvider.robotConfig,
                          preferencesProvider.pathResolution),
                      SplineSet([], robotConfigProvider.robotConfig,
                          preferencesProvider.pathResolution),
                      "",
                      preferencesProvider.pathResolution,
                      isTrue: false,
                    ));
                    widget.onChanged(spline.copyWith(
                        onFalse: SplineSet(
                            newSplines,
                            robotConfigProvider.robotConfig,
                            preferencesProvider.pathResolution)));
                  },
                  () {
                    _newPath(false);
                  },
                  (spline, index) {
                    widget.onChanged(this.spline.copyWith(
                        onFalse: this
                            .spline
                            .onFalse
                            .onSplineChanged(index, spline)));
                  }),
            ),
          ],
        ),
      ],
    );
  }
}
