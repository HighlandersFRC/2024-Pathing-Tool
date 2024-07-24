import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/spline.dart';

class SplineOrderer extends StatefulWidget {
  final List<Spline> splines;
  final Function(int) onSplineSelected;
  final Function() onEdit, onDelete, onMoveForward, onMoveBackward;
  final int splineIndex;
  const SplineOrderer(this.splines, this.onSplineSelected, this.onEdit,
      this.onDelete, this.splineIndex, this.onMoveForward, this.onMoveBackward,
      {super.key});

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
      child: ExpansionPanelList(
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
                body: Column(
                  children: [
                    Text(
                      spline.value.name,
                      style: theme.textTheme.headlineLarge,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed:
                              spline.key != 0 ? widget.onMoveBackward : () {},
                          icon: const Icon(Icons.keyboard_arrow_left_rounded),
                          color: spline.key != 0
                              ? theme.primaryColor
                              : Colors.grey[500],
                        ),
                        IconButton(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit),
                          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                        IconButton(
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete),
                          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                        IconButton(
                          onPressed:
                              spline.key != widget.splines.length-1 ? widget.onMoveForward : () {},
                          icon: const Icon(Icons.keyboard_arrow_right_rounded),
                          color: spline.key != widget.splines.length-1
                              ? theme.primaryColor
                              : Colors.grey[500],
                        )
                      ],
                    ),
                  ],
                ))
        ],
      ),
    );
  }
}
