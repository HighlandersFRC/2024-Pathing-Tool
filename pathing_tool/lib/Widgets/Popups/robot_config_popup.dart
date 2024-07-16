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
  final TextEditingController _robotNameController = TextEditingController();
  List<TextEditingController> _commandControllers = [];
  List<TextEditingController> _conditionControllers = [];
  bool fieldsFilled = true;

  @override
  void initState() {
    super.initState();
    final robotConfigProvider = Provider.of<RobotConfigProvider>(context, listen: false);
    final robotConfig = robotConfigProvider.robotConfig;
    _robotNameController.text = robotConfig.name;
    _robotLengthController.text = robotConfig.length.toString();
    _robotWidthController.text = robotConfig.width.toString();
    _commandControllers = robotConfig.commands.map((command) => TextEditingController(text: command)).toList();
    _conditionControllers = robotConfig.conditions.map((condition) => TextEditingController(text: condition)).toList();
  }

  @override
  void dispose() {
    _robotWidthController.dispose();
    _robotLengthController.dispose();
    _robotNameController.dispose();
    for (var controller in _commandControllers) {
      controller.dispose();
    }
    for (var controller in _conditionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addCommandField() {
    setState(() {
      _commandControllers.add(TextEditingController());
    });
  }

  void _removeCommandField(int index) {
    setState(() {
      _commandControllers.removeAt(index);
    });
  }

  void _addConditionField() {
    setState(() {
      _conditionControllers.add(TextEditingController());
    });
  }

  void _removeConditionField(int index) {
    setState(() {
      _conditionControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Robot Configuration'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            TextFormField(
              controller: _robotNameController,
              decoration: InputDecoration(
                labelText: 'Robot Name',
                focusColor: theme.primaryColor,
                hoverColor: theme.primaryColor,
                floatingLabelStyle: TextStyle(color: theme.primaryColor),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.primaryColor),
                ),
              ),
              cursorColor: theme.primaryColor,
            ),
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
            const SizedBox(height: 16.0),
            const Text('Commands:'),
            ..._commandControllers.asMap().entries.map((entry) {
              int index = entry.key;
              TextEditingController controller = entry.value;
              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Command ${index + 1}',
                        focusColor: theme.primaryColor,
                        hoverColor: theme.primaryColor,
                        floatingLabelStyle: TextStyle(color: theme.primaryColor),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: theme.primaryColor),
                        ),
                      ),
                      cursorColor: theme.primaryColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle),
                    color: Colors.red,
                    onPressed: () => _removeCommandField(index),
                  ),
                ],
              );
            }).toList(),
            TextButton(
              onPressed: _addCommandField,
              style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(theme.primaryColor)),
              child: const Text('Add Command'),
            ),
            ..._conditionControllers.asMap().entries.map((entry) {
              int index = entry.key;
              TextEditingController controller = entry.value;
              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Condition ${index + 1}',
                        focusColor: theme.primaryColor,
                        hoverColor: theme.primaryColor,
                        floatingLabelStyle: TextStyle(color: theme.primaryColor),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: theme.primaryColor),
                        ),
                      ),
                      cursorColor: theme.primaryColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle),
                    color: Colors.red,
                    onPressed: () => _removeConditionField(index),
                  ),
                ],
              );
            }).toList(),
            TextButton(
              onPressed: _addConditionField,
              style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(theme.primaryColor)),
              child: const Text('Add Condition'),
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
                _robotLengthController.text.isEmpty ||
                _robotNameController.text.isEmpty ||
                _commandControllers.any((controller) => controller.text.isEmpty)) {
              setState(() {
                fieldsFilled = false;
              });
              return;
            }
            List<String> commands = _commandControllers.map((controller) => controller.text).toList();
            List<String> conditions = _conditionControllers.map((controller) => controller.text).toList();
            RobotConfig robotConfig = RobotConfig(
              _robotNameController.text,
              double.parse(_robotLengthController.text),
              double.parse(_robotWidthController.text),
              commands,
              conditions,
            );
            RobotConfigProvider robotConfigProvider = Provider.of<RobotConfigProvider>(context, listen: false);
            robotConfigProvider.setRobotConfig(robotConfig);
            // Clear input fields
            _robotLengthController.clear();
            _robotWidthController.clear();
            _robotNameController.clear();
            for (var controller in _commandControllers) {
              controller.clear();
            }
            for (var controller in _conditionControllers) {
              controller.clear();
            }

            // Close the dialog
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
