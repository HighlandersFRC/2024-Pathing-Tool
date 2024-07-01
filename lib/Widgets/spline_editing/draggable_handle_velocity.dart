import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Structs/image_data.dart';
import 'package:pathing_tool/Utils/Structs/waypoint.dart';

class VelocityHandle extends StatefulWidget {
  final Waypoint waypoint;
  final ImageData fieldImageData;
  final double usedWidth;
  final double usedHeight;
  final ValueChanged<Waypoint> onUpdate;
  final int opacity;

  const VelocityHandle({super.key, 
    required this.waypoint,
    required this.fieldImageData,
    required this.usedWidth,
    required this.usedHeight,
    required this.onUpdate, required this.opacity,
  });

  @override
  _VelocityHandleState createState() => _VelocityHandleState();
}

class _VelocityHandleState extends State<VelocityHandle> {
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

    Offset handlePosition = Offset(
      metersToPixelsRatio * widget.waypoint.dx,
      -metersToPixelsRatio * widget.waypoint.dy,
    );

    return 
      // fit: StackFit.passthrough,
      // clipBehavior: Clip.none,
        Positioned(
            key: _positionedKey,
            left: xPixels,
            top: yPixels,
            child: Container(
              transform: Matrix4.translationValues(
                  handlePosition.dx - 6, handlePosition.dy - 6, 20),
              width: 12,
              height: 12,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    RenderBox box = _positionedKey.currentContext!
                        .findRenderObject() as RenderBox;
                    Offset globalPosition = box.localToGlobal(Offset.zero);
                    double dx =
                        (details.globalPosition.dx - globalPosition.dx) /
                            metersToPixelsRatio;
                    double dy =
                        -(details.globalPosition.dy - globalPosition.dy) /
                            metersToPixelsRatio;
                    Waypoint updatedWaypoint =
                        widget.waypoint.copyWith(dx: dx, dy: dy);
                    widget.onUpdate(updatedWaypoint);
                  });
                },
                child: Container(
                    decoration: BoxDecoration(
                  color: theme.primaryColor.withAlpha(widget.opacity),
                  shape: BoxShape.circle,
                )),
              ),
            ));
  }
}

class VelocityPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final int opacity;
  final Color color;

  VelocityPainter({required this.start, required this.end, required this.opacity, required this.color, });

  @override
  void paint(Canvas canvas, Size size) {
    
    final paint = Paint()
      ..color = color.withAlpha(opacity)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
