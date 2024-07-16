import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:pathing_tool/Utils/Structs/command.dart';
import 'package:pathing_tool/Utils/Structs/robot_config.dart';
import 'package:provider/provider.dart';

class EditCommandMenu extends StatefulWidget {
  final List<Command> commands;
  final int selectedCommand;
  final Function(Command?) onCommandSelected;
  final Function(Command) onAttributeChanged;
  final Function(List<Command>) onCommandChanged;

  const EditCommandMenu({
    super.key,
    required this.commands,
    required this.onCommandSelected,
    required this.onAttributeChanged,
    required this.selectedCommand,
    required this.onCommandChanged,
  });

  @override
  _EditCommandMenuState createState() => _EditCommandMenuState();
}

class _EditCommandMenuState extends State<EditCommandMenu> {
  Command? get selectedCommand => widget.selectedCommand != -1
      ? widget.commands[widget.selectedCommand]
      : null;

  void updateCommand(Command newCommand) {
    widget.onAttributeChanged(newCommand);
  }

  void deleteCommand(int index) {
    setState(() {
      widget.commands.removeAt(index);
    });
    widget.onCommandSelected((index != 0 ? widget.commands[index - 1] : null));
    widget.onCommandChanged(widget.commands);
  }

  void addCommand(Command command) {
    setState(() {
      widget.commands.add(command);
    });
    widget.onCommandChanged(widget.commands);
  }

  void showAddCommandMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(
          value: 'command',
          child: Text('Add Command'),
        ),
        const PopupMenuItem(
          value: 'branchedCommand',
          child: Text('Add Branched Command'),
        ),
      ],
    ).then((value) {
      if (value == 'command') {
        addCommand(Command(
          startTime: 0,
          endTime: 0,
          commandName: '',
        ));
      } else if (value == 'branchedCommand') {
        addCommand(BranchedCommand(
          'New Branched Command',
          Command(
            startTime: 0,
            endTime: 0,
            commandName: '',
          ),
          Command(
            startTime: 0,
            endTime: 0,
            commandName: '',
          ),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 350, // Adjust as needed
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Commands',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                          15.0), // Rounded corners for the whole panel
                      color: theme.primaryColor.withOpacity(0.1),
                    ),
                    child: ExpansionPanelList(
                      expansionCallback: (int index, bool isExpanded) {
                        if (isExpanded) {
                          widget.onCommandSelected(widget.commands[index]);
                        } else {
                          widget.onCommandSelected(null);
                        }
                      },
                      children: widget.commands.asMap().entries.map((entry) {
                        int idx = entry.key;
                        Command command = entry.value;
                        return ExpansionPanel(
                          canTapOnHeader: true,
                          headerBuilder:
                              (BuildContext context, bool isExpanded) {
                            return ListTile(
                              title: Text('Command ${idx + 1}'),
                            );
                          },
                          body: Container(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(8.0), // Rounded corners
                              color: theme.primaryColor.withOpacity(0.1),
                            ),
                            child: Column(
                              children: [
                                CommandEditor(
                                  command: command,
                                  onChanged: (newCommand) {
                                    setState(() {
                                      widget.commands[idx] = newCommand;
                                    });
                                    widget.onAttributeChanged(newCommand);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => deleteCommand(idx),
                                ),
                              ],
                            ),
                          ),
                          isExpanded: selectedCommand == command,
                        );
                      }).toList(),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => showAddCommandMenu(context),
                    child: const Text('Add Command'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommandEditor extends StatelessWidget {
  final Command command;
  final Function(Command) onChanged;

  CommandEditor({
    super.key,
    required this.onChanged,
    required this.command,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final RobotConfigProvider robotProvider =
        Provider.of<RobotConfigProvider>(context);
    var commandNames = [...robotProvider.robotConfig.commands];

    TextEditingController startTimeController =
        TextEditingController(text: command.startTime.toString());
    TextEditingController endTimeController =
        TextEditingController(text: command.endTime.toString());

    String selectedCommandName = command.commandName;

    // Focus nodes to detect when the TextFields lose focus
    FocusNode startTimeFocusNode = FocusNode();
    FocusNode endTimeFocusNode = FocusNode();

    void updateStartTime() {
      final value = startTimeController.text;
      if (value.isNotEmpty) {
        onChanged(command.copyWith(startTime: double.parse(value)));
      }
    }

    void updateEndTime() {
      final value = endTimeController.text;
      if (value.isNotEmpty) {
        if (double.parse(value) < command.startTime) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("End Time must be greater than start time!"),
              backgroundColor: Colors.red,
            ),
          );
          endTimeController.value =
              TextEditingValue(text: command.endTime.toString());
        } else {
          onChanged(command.copyWith(endTime: double.parse(value)));
        }
      }
    }

    startTimeFocusNode.addListener(() {
      if (!startTimeFocusNode.hasFocus) {
        updateStartTime();
      }
    });

    endTimeFocusNode.addListener(() {
      if (!endTimeFocusNode.hasFocus) {
        updateEndTime();
      }
    });

    return command is BranchedCommand
        ? BranchedCommandEditor(
            command: command as BranchedCommand,
            onChanged: onChanged,
          )
        : Column(
            children: [
              TextField(
                controller: startTimeController,
                focusNode: startTimeFocusNode,
                decoration: InputDecoration(
                  hintText: 'Start Time',
                  focusColor: theme.primaryColor,
                  hoverColor: theme.primaryColor,
                  floatingLabelStyle: TextStyle(color: theme.primaryColor),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.primaryColor),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                cursorColor: theme.primaryColor,
                onSubmitted: (value) {
                  updateStartTime();
                },
              ),
              TextField(
                controller: endTimeController,
                focusNode: endTimeFocusNode,
                decoration: InputDecoration(
                  hintText: 'End Time',
                  focusColor: theme.primaryColor,
                  hoverColor: theme.primaryColor,
                  floatingLabelStyle: TextStyle(color: theme.primaryColor),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.primaryColor),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                cursorColor: theme.primaryColor,
                onSubmitted: (value) {
                  updateEndTime();
                },
              ),
              DropdownButton<int>(
                value: !commandNames.contains(selectedCommandName)
                    ? null
                    : commandNames.indexOf(selectedCommandName),
                hint: const Text('Select Command Name'),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    onChanged(
                        command.copyWith(commandName: commandNames[newValue]));
                  }
                },
                items: commandNames.map<DropdownMenuItem<int>>((String name) {
                  return DropdownMenuItem<int>(
                    value: commandNames.indexOf(name),
                    child: Text(name),
                  );
                }).toList(),
              ),
            ],
          );
  }
}

class BranchedCommandEditor extends StatelessWidget {
  final BranchedCommand command;
  final Function(Command) onChanged;

  const BranchedCommandEditor({
    super.key,
    required this.onChanged,
    required this.command,
  });

  @override
  Widget build(BuildContext context) {
    final robotConfig = Provider.of<RobotConfigProvider>(context);
    var conditionNames = robotConfig.robotConfig.conditions;
    String selectedConditionName = command.condition;
    return Column(
      children: [
        DropdownButton<int>(
          value: !conditionNames.contains(selectedConditionName)
              ? null
              : conditionNames.indexOf(selectedConditionName),
          hint: const Text('Select Condition'),
          onChanged: (int? newValue) {
            if (newValue != null) {
              onChanged(command.copyWith(condition: conditionNames[newValue]));
            }
          },
          items: [
            ...conditionNames.map<DropdownMenuItem<int>>((String name) {
              return DropdownMenuItem<int>(
                value: conditionNames.indexOf(name),
                child: Text(name),
              );
            }),
          ],
        ),
        const Text('On True Command'),
        CommandEditor(
          command: command.onTrue,
          onChanged: (onTrueCommand) {
            onChanged(command.copyWith(onTrue: onTrueCommand));
          },
        ),
        const Text('On False Command'),
        CommandEditor(
          command: command.onFalse,
          onChanged: (onFalseCommand) {
            onChanged(command.copyWith(onFalse: onFalseCommand));
          },
        ),
      ],
    );
  }
}
