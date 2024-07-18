import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';

class EditWaypointMenu extends StatefulWidget {
  final List<Waypoint> waypoints;
  final int selectedWaypoint;
  final Function(Waypoint?) onWaypointSelected;
  final Function(Waypoint) onAttributeChanged;
  final Function(List<Waypoint>) onWaypointsChanged;

  const EditWaypointMenu({
    super.key,
    required this.waypoints,
    required this.onWaypointSelected,
    required this.onAttributeChanged,
    required this.selectedWaypoint,
    required this.onWaypointsChanged,
  });

  @override
  _EditWaypointMenuState createState() => _EditWaypointMenuState();
}

class _EditWaypointMenuState extends State<EditWaypointMenu> {
  @override
  void initState() {
    super.initState();
  }

  Waypoint? get selectedWaypoint => widget.selectedWaypoint != -1
      ? widget.waypoints[widget.selectedWaypoint]
      : null;

  void updateWaypoint(Waypoint newWaypoint) {
    setState(() {
      widget.waypoints[widget.selectedWaypoint] = newWaypoint;
    });
    widget.onAttributeChanged(newWaypoint);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
        width: 350, // Adjust as needed
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Waypoints',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  DropdownButton<int>(
                    value: widget.selectedWaypoint != -1
                        ? widget.selectedWaypoint
                        : null,
                    hint: const Text('Select a waypoint'),
                    onChanged: (int? newIndex) {
                      widget.onWaypointSelected(
                          newIndex != null ? widget.waypoints[newIndex] : null);
                    },
                    items: widget.waypoints.asMap().entries.map((entry) {
                      int idx = entry.key;
                      return DropdownMenuItem<int>(
                        value: idx,
                        child: Text('Waypoint ${idx + 1}'),
                      );
                    }).toList(),
                  ),
                  if (widget.selectedWaypoint != -1)
                    Tooltip(
                      message: "Delete Waypoint",
                      waitDuration: const Duration(milliseconds: 500),
                      child: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          List<Waypoint> newWaypoints = [];
                          widget.waypoints.forEach((Waypoint waypoint) {
                            if (widget.waypoints.isNotEmpty) {
                              if (widget.selectedWaypoint !=
                                  widget.waypoints.indexOf(waypoint)) {
                                if (widget.selectedWaypoint == 0) {
                                  newWaypoints.add(waypoint.copyWith(
                                      t: waypoint.t - widget.waypoints[1].t));
                                } else {
                                  newWaypoints.add(waypoint.copyWith());
                                }
                              }
                            }
                          });
                          if (widget.selectedWaypoint != 0)
                            widget.onWaypointSelected(
                                widget.waypoints[widget.selectedWaypoint - 1]);
                          if (newWaypoints.length == 0)
                            widget.onWaypointSelected(null);
                          widget.onWaypointsChanged(newWaypoints);
                        },
                      ),
                    ),
                  if (widget.selectedWaypoint != -1)
                    Tooltip(
                      message: "Move Backward",
                      waitDuration: const Duration(milliseconds: 500),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: widget.selectedWaypoint != 0
                            ? () {
                                List<Waypoint> newWaypoints = [
                                  ...widget.waypoints
                                ];
                                Waypoint save =
                                    newWaypoints[widget.selectedWaypoint]
                                        .copyWith();
                                newWaypoints[widget.selectedWaypoint] =
                                    newWaypoints[widget.selectedWaypoint - 1]
                                        .copyWith(t: save.t);
                                newWaypoints[widget.selectedWaypoint - 1] =
                                    save.copyWith(
                                        t: newWaypoints[
                                                widget.selectedWaypoint - 1]
                                            .t);
                                widget.onWaypointSelected(widget
                                    .waypoints[widget.selectedWaypoint - 1]);
                                widget.onWaypointsChanged(newWaypoints);
                              }
                            : () {},
                        color: widget.selectedWaypoint != 0
                            ? theme.primaryColor
                            : Colors.grey,
                      ),
                    ),
                  if (widget.selectedWaypoint != -1)
                    Tooltip(
                      message: "Move Forward",
                      waitDuration: const Duration(milliseconds: 500),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: widget.selectedWaypoint !=
                                widget.waypoints.length - 1
                            ? () {
                                List<Waypoint> newWaypoints = [
                                  ...widget.waypoints
                                ];
                                Waypoint save =
                                    newWaypoints[widget.selectedWaypoint]
                                        .copyWith();
                                newWaypoints[widget.selectedWaypoint] =
                                    newWaypoints[widget.selectedWaypoint + 1]
                                        .copyWith(t: save.t);
                                newWaypoints[widget.selectedWaypoint + 1] =
                                    save.copyWith(
                                        t: newWaypoints[
                                                widget.selectedWaypoint + 1]
                                            .t);
                                widget.onWaypointSelected(widget
                                    .waypoints[widget.selectedWaypoint + 1]);
                                widget.onWaypointsChanged(newWaypoints);
                              }
                            : () {},
                        color: widget.selectedWaypoint !=
                                widget.waypoints.length - 1
                            ? theme.primaryColor
                            : Colors.grey,
                      ),
                    ),
                ]),
              ),
              if (selectedWaypoint != null) ...[
                AttributeEditor(
                  attributeName: 'Time',
                  currentValue: selectedWaypoint!.t,
                  onChanged: (value) {
                    updateWaypoint(selectedWaypoint!.copyWith(t: value));
                  },
                ),
                AttributeEditor(
                  attributeName: 'X',
                  currentValue: selectedWaypoint!.x,
                  onChanged: (value) {
                    updateWaypoint(selectedWaypoint!.copyWith(x: value));
                  },
                ),
                AttributeEditor(
                  attributeName: 'Y',
                  currentValue: selectedWaypoint!.y,
                  onChanged: (value) {
                    updateWaypoint(selectedWaypoint!.copyWith(y: value));
                  },
                ),
                AttributeEditor(
                  attributeName: 'Heading',
                  currentValue: selectedWaypoint!.theta,
                  onChanged: (value) {
                    updateWaypoint(selectedWaypoint!.copyWith(theta: value));
                  },
                ),
                AttributeEditor(
                  attributeName: 'X-Vel',
                  currentValue: selectedWaypoint!.dx,
                  onChanged: (value) {
                    updateWaypoint(selectedWaypoint!.copyWith(dx: value));
                  },
                ),
                AttributeEditor(
                  attributeName: 'Y-Vel',
                  currentValue: selectedWaypoint!.dy,
                  onChanged: (value) {
                    updateWaypoint(selectedWaypoint!.copyWith(dy: value));
                  },
                ),
                AttributeEditor(
                  attributeName: 'Ang-Vel',
                  currentValue: selectedWaypoint!.dtheta,
                  onChanged: (value) {
                    updateWaypoint(selectedWaypoint!.copyWith(dtheta: value));
                  },
                ),
                AttributeEditor(
                  attributeName: 'X-Acc',
                  currentValue: selectedWaypoint!.d2x,
                  onChanged: (value) {
                    updateWaypoint(selectedWaypoint!.copyWith(d2x: value));
                  },
                ),
                AttributeEditor(
                  attributeName: 'Y-Acc',
                  currentValue: selectedWaypoint!.d2y,
                  onChanged: (value) {
                    updateWaypoint(selectedWaypoint!.copyWith(d2y: value));
                  },
                ),
                AttributeEditor(
                  attributeName: 'Ang-Acc',
                  currentValue: selectedWaypoint!.d2theta,
                  onChanged: (value) {
                    updateWaypoint(selectedWaypoint!.copyWith(d2theta: value));
                  },
                ),
              ],
            ],
          ),
        ));
  }
}

class AttributeEditor extends StatefulWidget {
  final String attributeName;
  final double currentValue;
  final Function(double) onChanged;

  const AttributeEditor({
    super.key,
    required this.attributeName,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  _AttributeEditorState createState() => _AttributeEditorState();
}

class _AttributeEditorState extends State<AttributeEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.currentValue.toStringAsFixed(3));
  }

  @override
  void didUpdateWidget(covariant AttributeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentValue != oldWidget.currentValue) {
      _controller.text = widget.currentValue.toStringAsFixed(3);
    }
  }

  void increment() {
    setState(() {
      double value = double.parse(_controller.text);
      value += 0.1;
      _controller.text = value.toStringAsFixed(3);
      widget.onChanged(value);
    });
  }

  void decrement() {
    setState(() {
      double value = double.parse(_controller.text);
      value -= 0.1;
      _controller.text = value.toStringAsFixed(3);
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.attributeName),
          Row(
            children: [
              Tooltip(
                message: "-0.1",
                waitDuration: const Duration(milliseconds: 500),
                child: IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: decrement,
                ),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    focusColor: theme.primaryColor,
                    hoverColor: theme.primaryColor,
                    floatingLabelStyle: TextStyle(color: theme.primaryColor),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: theme.primaryColor)),
                  ),
                  cursorColor: theme.primaryColor,
                ),
              ),
              Tooltip(
                message: "+0.1",
                waitDuration: const Duration(milliseconds: 500),
                child: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: increment,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.onChanged(double.parse(_controller.text));
                },
                child: const Text('Set'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
