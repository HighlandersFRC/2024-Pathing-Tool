import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:pathing_tool/Utils/spline.dart';
import 'package:provider/provider.dart';

class SplineOrderer extends StatefulWidget {
  final List<Spline> splines;
  final Function(int) onSplineSelected;
  final Function() onDelete,
      onMoveForward,
      onMoveBackward,
      onBranchedSplineAdded;
  final Function(Spline?, bool, {Function(Spline)? returnSpline}) onEdit;
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
                ))
        ],
      ),
      ElevatedButton(
          onPressed: widget.onBranchedSplineAdded,
          child: const Text('Add Branched Path')),
    ]));
  }
}

class SplineEditor extends StatelessWidget {
  final Spline spline;
  final int splineIndex;
  final int length;
  final Function() onMoveForward, onMoveBackward, onDelete;
  final Function(Spline?, bool, {Function(Spline)? returnSpline}) onEdit;
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
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return spline is BranchedSpline
        ? BranchedSplineEditor(spline as BranchedSpline, splineIndex,
            onMoveForward, onMoveBackward, onEdit, onDelete, length, onChanged)
        : spline.isNull
            ? NullSplineEditor(spline as NullSpline, splineIndex, onEdit,
                onDelete, length, onChanged)
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
                        onPressed: () => onEdit(spline, lastLocked),
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
  final Function(Spline?, bool, {Function(Spline)? returnSpline}) onEdit;
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

  _returnSpline(bool isTrue, {Function(Spline)? returnSpline, Spline? spline}) {
    if (spline != null) {
      if (isTrue) {
        onChanged(this.spline.copyWith(onTrue: spline));
      } else {
        onChanged(this.spline.copyWith(onFalse: spline));
      }
    }
  }

  @override
  State<StatefulWidget> createState() => _BranchedSplineEditorState();
}

class _BranchedSplineEditorState extends State<BranchedSplineEditor> {
  BranchedSpline get spline => widget.spline;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final robotConfigProvider = Provider.of<RobotConfigProvider>(context);
    var robotConditions = robotConfigProvider.robotConfig.conditions;
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
                body: SplineEditor(
                  spline.onTrue,
                  0,
                  widget.onMoveForward,
                  widget.onMoveBackward,
                  (onTrue, isLocked, {Function(Spline)? returnSpline}) {
                    widget.onEdit(onTrue, isLocked,
                        returnSpline: (Spline? newSpline) {
                      widget._returnSpline(true,
                          returnSpline: returnSpline, spline: newSpline);
                    });
                  },
                  () {
                    widget.onChanged(spline.copyWith(onTrue: NullSpline()));
                  },
                  1,
                  (Spline newSpline) =>
                      widget.onChanged(spline.copyWith(onTrue: newSpline)),
                  isBranch: true,
                )),
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
              body: SplineEditor(
                spline.onFalse,
                0,
                widget.onMoveForward,
                widget.onMoveBackward,
                (onFalse, lastLocked, {Function(Spline)? returnSpline}) {
                  widget.onEdit(onFalse, true,
                        returnSpline: (Spline? newSpline) {
                      widget._returnSpline(true,
                          returnSpline: returnSpline, spline: newSpline);
                    });
                },
                () {
                  widget.onChanged(spline.copyWith(onFalse: NullSpline()));
                },
                1,
                (Spline newSpline) =>
                    widget.onChanged(spline.copyWith(onFalse: newSpline)),
                isBranch: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class NullSplineEditor extends StatelessWidget {
  final NullSpline spline;
  final int splineIndex;
  final int length;
  final Function() onDelete;
  final Function(Spline?, bool, {Function(Spline)? returnSpline}) onEdit;
  final Function(Spline) onChanged;
  final bool isBranch;
  const NullSplineEditor(
    this.spline,
    this.splineIndex,
    this.onEdit,
    this.onDelete,
    this.length,
    this.onChanged, {
    super.key,
    this.isBranch = false,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              onPressed: onDelete,
              icon: const Icon(Icons.delete),
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
            ElevatedButton(
              onPressed: () => _newPath(context),
              child: const Text('To Path'),
            ),
          ],
        ),
      ],
    );
  }

  _loadPath() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['polarpath'],
    );
    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      File pathFile = File(path);
      Spline newSpline = Spline.fromPolarPathFile(pathFile);
      onChanged(newSpline);
    }
  }

  _newPath(context) {
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
                    TextButton(
                      onPressed: pathAdded
                          ? () {
                              onChanged(Spline(
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
                          color: pathAdded
                              ? theme.primaryColor
                              : Colors.grey.shade500,
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
  }
}
