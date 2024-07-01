import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Structs/image_data.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';

class DraggableHandlePosition extends StatefulWidget {
  final Waypoint waypoint;
  final ImageData fieldImageData;
  final double usedWidth;
  final double usedHeight;
  final ValueChanged<Waypoint> onUpdate;
  final int opacity;

  const DraggableHandlePosition({super.key, 
    required this.waypoint,
    required this.fieldImageData,
    required this.usedWidth,
    required this.usedHeight,
    required this.onUpdate,
    required this.opacity
  });

  @override
  _DraggableHandlePositionState createState() => _DraggableHandlePositionState();
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
    return Positioned(
      key: _positionedKey,
      left: xPixels,
      top: yPixels,
      child: Container(
        transform: 
            Matrix4.translationValues(-12, -12, 20),
        width: 24,
        height: 24,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              RenderBox box = _positionedKey.currentContext!.findRenderObject() as RenderBox;
              Offset globalPosition = box.localToGlobal(Offset.zero);
              double dx = details.globalPosition.dx - globalPosition.dx;
              double dy = -(details.globalPosition.dy - globalPosition.dy);
              Waypoint updatedWaypoint =
                  widget.waypoint.copyWith(x: widget.waypoint.x+dx/metersToPixelsRatio, y: widget.waypoint.y+dy/metersToPixelsRatio);
              widget.onUpdate(updatedWaypoint);
            });
          },
          child: Container(
              decoration: BoxDecoration(
            border: Border.all(color: theme.primaryColor.withAlpha(widget.opacity), width: 3),
            shape: BoxShape.circle,
          )),
        ),
      ),
    );
  }
}
