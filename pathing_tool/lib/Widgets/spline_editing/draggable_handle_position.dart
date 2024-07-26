import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Structs/image_data.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';

class DraggableHandlePosition extends StatefulWidget {
  final Waypoint waypoint;
  final ImageData fieldImageData;
  final double usedWidth;
  final double usedHeight;
  final ValueChanged<Waypoint> onUpdate;
  final void Function() saveState;
  final int opacity;
  final BoxConstraints constraints;

  const DraggableHandlePosition(
      {super.key,
      required this.waypoint,
      required this.fieldImageData,
      required this.usedWidth,
      required this.usedHeight,
      required this.onUpdate,
      required this.opacity,
      required this.saveState,
       required this.constraints
       });

  @override
  _DraggableHandlePositionState createState() =>
      _DraggableHandlePositionState();
}

class _DraggableHandlePositionState extends State<DraggableHandlePosition> {
  final GlobalKey _positionedKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    double xPixels = widget.waypoint.x /
        widget.fieldImageData.imageWidthInMeters *
        widget.usedWidth;
    double yPixels = widget.usedHeight -
        (widget.waypoint.y /
            widget.fieldImageData.imageHeightInMeters *
            widget.usedHeight);
    double metersToPixelsRatio =
        widget.usedWidth / widget.fieldImageData.imageWidthInMeters;
    var widthOffset =
        (widget.constraints.maxWidth - widget.usedWidth) / 2;
    var heightOffset =
        (widget.constraints.maxHeight - widget.usedHeight) / 2;
    return Positioned(
      key: _positionedKey,
      left: xPixels + widthOffset,
      top: yPixels + heightOffset,
      child: Container(
        transform: Matrix4.translationValues(-12, -12, 20),
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
              Waypoint updatedWaypoint = widget.waypoint.copyWith(
                  x: widget.waypoint.x + dx / metersToPixelsRatio,
                  y: widget.waypoint.y + dy / metersToPixelsRatio);
              widget.onUpdate(updatedWaypoint);
            });
          },
          child: Container(
              decoration: BoxDecoration(
            border: Border.all(
                color: theme.primaryColor.withAlpha(widget.opacity), width: 3),
            shape: BoxShape.circle,
          )),
        ),
      ),
    );
  }
}
