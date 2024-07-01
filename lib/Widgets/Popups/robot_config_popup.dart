import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:pathing_tool/Utils/Structs/robot_config.dart';
import 'package:provider/provider.dart';

class RobotConfigPopup extends StatefulWidget {
  const RobotConfigPopup({super.key});

  @override
  RobotConfigPopupState createState() => RobotConfigPopupState();
}

class RobotConfigPopupState extends State<RobotConfigPopup> {
  final TextEditingController _robotWidthController = TextEditingController();
  final TextEditingController _robotLengthController = TextEditingController();
  bool fieldsFilled = true;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    RobotConfigProvider robotConfigProvider = Provider.of<RobotConfigProvider>(context, listen: false);
    _robotLengthController.text = robotConfigProvider.robotConfig.length.toString();
    _robotWidthController.text = robotConfigProvider.robotConfig.width.toString();
    return AlertDialog(
      title: const Text('Robot Configuration'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            // Add your robot configuration options here
            TextFormField(
              controller: _robotLengthController,
              decoration: InputDecoration(
                labelText: 'Robot Length',
                focusColor: theme.primaryColor,
                hoverColor: theme.primaryColor,
                floatingLabelStyle: TextStyle(color: theme.primaryColor),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.primaryColor),
                ),
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              cursorColor: theme.primaryColor,
            ),
            TextFormField(
              controller: _robotWidthController,
              decoration: InputDecoration(
                labelText: 'Robot Width',
                focusColor: theme.primaryColor,
                hoverColor: theme.primaryColor,
                floatingLabelStyle: TextStyle(color: theme.primaryColor),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.primaryColor),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              cursorColor: theme.primaryColor,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all(theme.primaryColor)),
          child: const Text('Close'),
        ),
        ElevatedButton(
          child: const Text('Set'),
          onPressed: () {
            // Validate input
            if (_robotWidthController.text.isEmpty ||
                _robotLengthController.text.isEmpty) {
              setState(() {
                fieldsFilled = false;
              });
              return;
            }
            RobotConfig robotConfig = RobotConfig(double.parse(_robotLengthController.text), double.parse(_robotWidthController.text));
            RobotConfigProvider robotConfigProvider = Provider.of<RobotConfigProvider>(context, listen: false);
            robotConfigProvider.setRobotConfig(robotConfig);
            // Clear input fields
            _robotLengthController.clear();
            _robotWidthController.clear();

            // Close the dialog
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
