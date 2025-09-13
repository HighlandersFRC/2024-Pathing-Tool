import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_iconpicker/Models/configuration.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:pathing_tool/Utils/Structs/robot_config.dart';
import 'package:provider/provider.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';

class RobotConfigPopup extends StatefulWidget {
  final bool newRobot;
  final RobotConfig startingConfig;
  const RobotConfigPopup(
      {super.key, this.newRobot = false, required this.startingConfig});

  @override
  RobotConfigPopupState createState() => RobotConfigPopupState();
}

class RobotConfigPopupState extends State<RobotConfigPopup> {
  final TextEditingController _robotWidthController = TextEditingController();
  final TextEditingController _robotLengthController = TextEditingController();
  final TextEditingController _robotNameController = TextEditingController();
  final TextEditingController _maxVelocityController = TextEditingController();
  final TextEditingController _maxAccelerationController =
      TextEditingController();
  final TextEditingController _maxCentripetalAccelerationController =
      TextEditingController();
  List<IconData?> _commandIcons = [];
  List<TextEditingController> _commandControllers = [];
  List<IconData?> _conditionIcons = [];
  List<TextEditingController> _conditionControllers = [];
  bool fieldsFilled = true;
  Future<IconData?> _pickIcon(int index) async {
    final theme = Theme.of(context);
    final IconPickerIcon? icon = await showIconPicker(context,
        configuration: SinglePickerConfiguration(
            iconPackModes: [IconPack.allMaterial],
            closeChild:
                Text("Close", style: TextStyle(color: theme.primaryColor))));
    return icon?.data;
  }

  @override
  void initState() {
    super.initState();
    // final robotConfigProvider =
    //     Provider.of<RobotConfigProvider>(context, listen: false);
    final robotConfig = widget.startingConfig;
    _robotNameController.text = widget.newRobot ? "" : robotConfig.name;
    _robotLengthController.text =
        widget.newRobot ? "1.0" : robotConfig.length.toString();
    _robotWidthController.text =
        widget.newRobot ? "1.0" : robotConfig.width.toString();
    _maxVelocityController.text = widget.newRobot
        ? "3.0"
        : robotConfig.maxVelocity.toString(); // <-- Added
    _maxAccelerationController.text = widget.newRobot
        ? "2.0"
        : robotConfig.maxAcceleration.toString(); // <-- Added
    _maxCentripetalAccelerationController.text = widget.newRobot
        ? "2.0"
        : robotConfig.maxCentripetalAcceleration.toString(); // <-- Added
    _commandControllers = (!widget.newRobot
            ? robotConfig.commands
            : List<IconCommand>.empty(growable: true))
        .map((command) => TextEditingController(text: command.name))
        .toList();
    _commandIcons = widget.newRobot
        ? List<IconData?>.empty(growable: true)
        : [...robotConfig.commands.map((e) => e.icon)];
    _conditionIcons = widget.newRobot
        ? List<IconData?>.empty(growable: true)
        : [...robotConfig.conditions.map((e) => e.icon)];
    _conditionControllers = (!widget.newRobot
            ? robotConfig.conditions
            : List<IconCondition>.empty(growable: true))
        .map((condition) => TextEditingController(text: condition.name))
        .toList();
  }

  @override
  void dispose() {
    _robotWidthController.dispose();
    _robotLengthController.dispose();
    _robotNameController.dispose();
    _maxAccelerationController.dispose();
    _maxVelocityController.dispose();
    _maxCentripetalAccelerationController.dispose();
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
      _commandControllers.add(TextEditingController(text: "Command"));
      _commandIcons.add(null);
    });
  }

  void _removeCommandField(int index) {
    setState(() {
      _commandControllers.removeAt(index);
      _commandIcons.removeAt(index);
    });
  }

  void _addConditionField() {
    setState(() {
      _conditionControllers.add(TextEditingController());
      _conditionIcons.add(null);
    });
  }

  void _removeConditionField(int index) {
    setState(() {
      _conditionControllers.removeAt(index);
      _conditionIcons.removeAt(index);
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              cursorColor: theme.primaryColor,
            ),
            TextFormField(
              controller: _maxVelocityController,
              decoration: InputDecoration(
                labelText: 'Max Velocity',
                focusColor: theme.primaryColor,
                hoverColor: theme.primaryColor,
                floatingLabelStyle: TextStyle(color: theme.primaryColor),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.primaryColor),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              cursorColor: theme.primaryColor,
            ),
            TextFormField(
              controller: _maxAccelerationController,
              decoration: InputDecoration(
                labelText: 'Max Acceleration',
                focusColor: theme.primaryColor,
                hoverColor: theme.primaryColor,
                floatingLabelStyle: TextStyle(color: theme.primaryColor),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.primaryColor),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              cursorColor: theme.primaryColor,
            ),
            TextFormField(
              controller: _maxCentripetalAccelerationController,
              decoration: InputDecoration(
                labelText: 'Max Centripetal Acceleration',
                focusColor: theme.primaryColor,
                hoverColor: theme.primaryColor,
                floatingLabelStyle: TextStyle(color: theme.primaryColor),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.primaryColor),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
                  Icon(_commandIcons[index]),
                  IconButton(
                    onPressed: () async {
                      var newIcon = await _pickIcon(entry.key);
                      setState(() {
                        _commandIcons[index] = newIcon;
                      });
                    },
                    icon: const Icon(Icons.arrow_drop_down),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Command ${index + 1}',
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
                  Icon(_conditionIcons[index]),
                  IconButton(
                    onPressed: () async {
                      var newIcon = await _pickIcon(entry.key);
                      setState(() {
                        _conditionIcons[index] = newIcon;
                      });
                    },
                    icon: const Icon(Icons.arrow_drop_down),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Condition ${index + 1}',
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
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle),
                    color: Colors.red,
                    onPressed: () => _removeConditionField(index),
                  ),
                ],
              );
            }),
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
          child: widget.newRobot ? const Text('Add') : const Text('Save'),
          onPressed: () {
            // Validate input
            if (_robotWidthController.text.isEmpty ||
                _robotLengthController.text.isEmpty ||
                _robotNameController.text.isEmpty ||
                _maxVelocityController.text.isEmpty ||
                _maxAccelerationController.text.isEmpty ||
                _maxCentripetalAccelerationController.text.isEmpty ||
                _commandControllers
                    .any((controller) => controller.text.isEmpty)) {
              setState(() {
                fieldsFilled = false;
              });
              return;
            }
            List<IconCommand> commands =
                _commandControllers.asMap().entries.map((entry) {
              return IconCommand(entry.value.text, _commandIcons[entry.key]);
            }).toList();
            List<IconCondition> conditions =
                _conditionControllers.asMap().entries.map((entry) {
              return IconCondition(
                  entry.value.text, _conditionIcons[entry.key]);
            }).toList();
            RobotConfig robotConfig = RobotConfig(
                _robotNameController.text,
                double.parse(_robotLengthController.text),
                double.parse(_robotWidthController.text),
                commands,
                conditions,
                maxVelocity: double.parse(_maxVelocityController.text),
                maxAcceleration: double.parse(_maxAccelerationController.text),
                maxCentripetalAcceleration:
                    double.parse(_maxCentripetalAccelerationController.text));
            RobotConfigProvider robotConfigProvider =
                Provider.of<RobotConfigProvider>(context, listen: false);
            if (widget.newRobot) {
              robotConfigProvider.addRobot(robotConfig);
            } else {
              robotConfigProvider.removeRobot(widget.startingConfig);
              robotConfigProvider.addRobot(robotConfig);
            }
            robotConfigProvider.setRobotConfig(robotConfig);
            // Clear input fields
            _robotLengthController.clear();
            _robotWidthController.clear();
            _robotNameController.clear();
            _maxVelocityController.clear();
            _maxAccelerationController.clear();
            _maxCentripetalAccelerationController.clear();
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
