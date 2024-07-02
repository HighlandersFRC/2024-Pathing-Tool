import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:pathing_tool/Utils/Structs/image_data.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';
import 'dart:math' as math;

import 'package:provider/provider.dart';

class DraggableHandleTheta extends StatefulWidget {
  final Waypoint waypoint;
  final ImageData fieldImageData;
  final double usedWidth;
  final double usedHeight;
  final void Function() saveState;
  final ValueChanged<Waypoint> onUpdate;
  final int opacity;

  const DraggableHandleTheta({
    super.key,
    required this.waypoint,
    required this.fieldImageData,
    required this.usedWidth,
    required this.usedHeight,
    required this.onUpdate,
    required this.opacity,
    required this.saveState,
  });

  @override
  _DraggableHandleThetaState createState() => _DraggableHandleThetaState();
}

class _DraggableHandleThetaState extends State<DraggableHandleTheta> {
  final GlobalKey _positionedKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final robotConfigProvider = Provider.of<RobotConfigProvider>(context);
    double xPixels = widget.waypoint.x /
        widget.fieldImageData.imageWidthInMeters *
        widget.usedWidth;
    double yPixels = widget.usedHeight -
        (widget.waypoint.y /
            widget.fieldImageData.imageHeightInMeters *
            widget.usedHeight);
    double metersToPixelsRatio =
        widget.usedHeight / widget.fieldImageData.imageHeightInMeters;
    double handleLength =
        robotConfigProvider.robotConfig.length * metersToPixelsRatio / 2;
    Offset handlePosition = Offset(
      handleLength * math.cos(widget.waypoint.theta),
      -handleLength * math.sin(widget.waypoint.theta),
    );

    return Positioned(
      key: _positionedKey,
      left: xPixels,
      top: yPixels,
      child: Container(
        transform: Matrix4.translationValues(
            handlePosition.dx - 12, handlePosition.dy - 12, 20),
        width: 24,
        height: 24,
        child: GestureDetector(
          onPanStart: (details) {
            widget.saveState();
          },
          onPanUpdate: (details) {
            setState(() {
              RenderBox box = _positionedKey.currentContext!.findRenderObject()
                  as RenderBox;
              Offset globalPosition = box.localToGlobal(Offset.zero);
              double dx = details.globalPosition.dx - globalPosition.dx;
              double dy = -(details.globalPosition.dy - globalPosition.dy);
              double newTheta = math.atan2(dy, dx);
              Waypoint updatedWaypoint =
                  widget.waypoint.copyWith(theta: newTheta);
              widget.onUpdate(updatedWaypoint);
            });
          },
          child: Container(
              decoration: BoxDecoration(
            border: Border.all(
                color: theme.primaryColor.withAlpha(widget.opacity), width: 5),
            shape: BoxShape.circle,
          )),
        ),
      ),
    );
  }
}
