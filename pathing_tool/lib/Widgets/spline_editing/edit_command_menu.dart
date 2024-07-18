import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Providers/robot_config_provider.dart';
import 'package:pathing_tool/Utils/Structs/command.dart';
import 'package:provider/provider.dart';

class EditCommandMenu extends StatefulWidget {
  final List<Command> commands;
  final int selectedCommand;
  final Function(Command?) onCommandSelected;
  final Function(Command) onAttributeChanged;
  final Function(List<Command>) onCommandsChanged;
  final bool startTimeLocked;

  const EditCommandMenu({
    super.key,
    required this.commands,
    required this.onCommandSelected,
    required this.onAttributeChanged,
    required this.selectedCommand,
    required this.onCommandsChanged,
    this.startTimeLocked = false,
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
    widget.onCommandsChanged(widget.commands);
  }

  void addCommand(Command command) {
    setState(() {
      widget.commands.insert(widget.commands.length, command);
    });
    widget.onCommandsChanged(widget.commands);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
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
                  child: ExpansionPanelList(
                    dividerColor: theme.primaryColor.withOpacity(0.2),
                    expandIconColor: theme.primaryColor.withOpacity(0.2),
                    expansionCallback: (int index, bool isExpanded) {
                      if (isExpanded) {
                        widget.onCommandSelected(widget.commands[index]);
                      } else {
                        widget.onCommandSelected(null);
                      }
                    },
                    children: [...widget.commands.asMap().entries.map((entry) {
                      int idx = entry.key;
                      Command command = entry.value;
                      return ExpansionPanel(
                        backgroundColor: theme.primaryColor.withOpacity(0.2),
                        canTapOnHeader: true,
                        headerBuilder:
                            (BuildContext context, bool isExpanded) {
                          return ListTile(
                            tileColor: theme.primaryColor.withOpacity(0.2),
                            focusColor: theme.primaryColor.withOpacity(0.2),
                            title: Text(command.commandName.isNotEmpty
                                ? "${command.commandName} \n${command.startTime.toStringAsFixed(1)} - ${command.endTime.toStringAsFixed(1)}"
                                : "Command"),
                          );
                        },
                        body: Container(
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.2),
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
                                startTimeLocked: widget.startTimeLocked,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => deleteCommand(idx),
                              ),
                            ],
                          ),
                        ),
                        isExpanded: widget.selectedCommand == idx,
                      );
                    })],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => showAddCommandMenu(context, addCommand),
                  child: const Text('Add Command'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommandEditor extends StatelessWidget {
  final Command command;
  final Function(Command) onChanged;
  final bool startTimeLocked;

  const CommandEditor({
    super.key,
    required this.onChanged,
    required this.command,
    this.startTimeLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    if (command is BranchedCommand) {
      return BranchedCommandEditor(
        command: command as BranchedCommand,
        onChanged: onChanged,
        startTimeLocked: startTimeLocked,
      );
    } else if (command is ParallelCommandGroup) {
      return MultipleCommandEditor(
        command: command as ParallelCommandGroup,
        onChanged: onChanged,
        startTimeLocked: startTimeLocked,
      );
    } else if (command is ParallelDeadlineGroup) {
      return MultipleCommandEditor(
        command: command as ParallelDeadlineGroup,
        onChanged: onChanged,
        startTimeLocked: startTimeLocked,
      );
    } else if (command is ParallelRaceGroup) {
      return MultipleCommandEditor(
        command: command as ParallelRaceGroup,
        onChanged: onChanged,
        startTimeLocked: startTimeLocked,
      );
    } else if (command is SequentialCommandGroup) {
      return MultipleCommandEditor(
        command: command as SequentialCommandGroup,
        onChanged: onChanged,
        startTimeLocked: startTimeLocked,
      );
    } else {
      return NormalCommandEditor(
        command: command,
        onChanged: onChanged,
        startTimeLocked: startTimeLocked,
      );
    }
  }
}

class NormalCommandEditor extends StatelessWidget {
  final Command command;
  final Function(Command) onChanged;
  final bool startTimeLocked;

  const NormalCommandEditor({
    super.key,
    required this.onChanged,
    required this.command,
    this.startTimeLocked = false,
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

    FocusNode startTimeFocusNode = FocusNode();
    FocusNode endTimeFocusNode = FocusNode();

    void updateStartTime() {
      final value = startTimeController.text;
      if (value.isNotEmpty) {
        if (double.parse(value) > command.endTime) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Start Time must be less than end time!"),
              backgroundColor: Colors.red,
            ),
          );
          startTimeController.value =
              TextEditingValue(text: command.startTime.toString());
        } else {
          onChanged(command.copyWith(startTime: double.parse(value)));
        }
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

    return Column(
      children: [
        TextField(
          readOnly: startTimeLocked,
          controller: startTimeController,
          focusNode: startTimeFocusNode,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => updateStartTime(),
          style: TextStyle(color: startTimeLocked? Colors.grey:null),
          decoration: InputDecoration(
            hintText: 'Start Time',
            focusColor: theme.primaryColor,
            hoverColor: theme.primaryColor,
            floatingLabelStyle: TextStyle(color: theme.primaryColor),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.primaryColor)),
          ),
          cursorColor: theme.primaryColor,
        ),
        TextField(
          controller: endTimeController,
          focusNode: endTimeFocusNode,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => updateEndTime(),
          decoration: InputDecoration(
            hintText: 'End Time',
            focusColor: theme.primaryColor,
            hoverColor: theme.primaryColor,
            floatingLabelStyle: TextStyle(color: theme.primaryColor),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.primaryColor)),
          ),
          cursorColor: theme.primaryColor,
        ),
        DropdownButton<String>(
          value: selectedCommandName.isNotEmpty ? selectedCommandName : null,
          hint: const Text('Select Command'),
          onChanged: (value) {
            onChanged(command.copyWith(commandName: value ?? ''));
          },
          items: commandNames.map((commandName) {
            return DropdownMenuItem(
              value: commandName,
              child: Text(commandName),
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
  final bool startTimeLocked;

  const BranchedCommandEditor({
    super.key,
    required this.command,
    required this.onChanged,
    this.startTimeLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final robotConfigProvider = Provider.of<RobotConfigProvider>(context);
    var conditionNames = robotConfigProvider.robotConfig.conditions;
    return Column(
      children: [
        DropdownButton<String>(
          value: command.condition != '' ? command.condition : null,
          hint: const Text('Select Condition'),
          onChanged: (value) {
            onChanged(command.copyWith(condition: value ?? ''));
          },
          items: conditionNames.map((conditionName) {
            return DropdownMenuItem(
              value: conditionName,
              child: Text(conditionName),
            );
          }).toList(),
        ),
        NormalCommandEditor(
          command: command.onTrue,
          onChanged: (updatedCommand) {
            onChanged(command.copyWith(onTrue: updatedCommand));
          },
          startTimeLocked: startTimeLocked,
        ),
        NormalCommandEditor(
          command: command.onFalse,
          onChanged: (updatedCommand) {
            onChanged(command.copyWith(onFalse: updatedCommand));
          },
          startTimeLocked: startTimeLocked,
        ),
      ],
    );
  }
}

void showAddCommandMenu(BuildContext context, Function(Command) addCommand) {
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
      const PopupMenuItem(
        value: 'parallelCommandGroup',
        child: Text('Add Parallel Command Group'),
      ),
      const PopupMenuItem(
        value: 'parallelDeadlineGroup',
        child: Text('Add Parallel Deadline Group'),
      ),
      const PopupMenuItem(
        value: 'parallelRaceGroup',
        child: Text('Add Parallel Race Group'),
      ),
      const PopupMenuItem(
        value: 'sequentialCommandGroup',
        child: Text('Add Sequential Command Group'),
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
        '',
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
    } else if (value == 'parallelCommandGroup') {
      addCommand(ParallelCommandGroup([]));
    } else if (value == 'parallelDeadlineGroup') {
      addCommand(ParallelDeadlineGroup([]));
    } else if (value == 'parallelRaceGroup') {
      addCommand(ParallelRaceGroup([]));
    } else if (value == 'sequentialCommandGroup') {
      addCommand(SequentialCommandGroup([]));
    }
  });
}

class MultipleCommandEditor extends StatefulWidget {
  final MultipleCommand command;
  final Function(Command) onChanged;
  final bool startTimeLocked;

  const MultipleCommandEditor({
    super.key,
    required this.command,
    required this.onChanged,
    this.startTimeLocked = false,
  });

  void addCommand(Command command) {
    var newCommands = [...this.command.commands, command];
    onChanged(this.command.copyWith(commands: newCommands));
  }

  @override
  State<StatefulWidget> createState() {
    return _MultipleCommandEditorState();
  }
}

class _MultipleCommandEditorState extends State<MultipleCommandEditor> {
  int selectedCommand = -1;
  @override
  Widget build(BuildContext context) {
    FocusNode startTimeFocusNode = FocusNode();
    TextEditingController startTimeController =
        TextEditingController(text: widget.command.startTime.toString());
    final theme = Theme.of(context);
    void updateStartTime() {
      final value = startTimeController.text;
      // print("value: ${value}");
      if (value.isNotEmpty) {
        widget
            .onChanged(widget.command.copyWith(startTime: double.parse(value)));
      }
    }
    startTimeFocusNode.addListener(() {
      if (!startTimeFocusNode.hasFocus) {
        updateStartTime();
      }
    });
    return Column(children: [
      TextField(
        readOnly: widget.startTimeLocked,
        controller: startTimeController,
        focusNode: startTimeFocusNode,
        keyboardType: TextInputType.number,
        style: TextStyle(color: widget.startTimeLocked? Colors.grey:null),
        onSubmitted: (_) => updateStartTime(),
        decoration: InputDecoration(
          helperText: 'Start Time',
          hintText: 'Start Time',
          focusColor: theme.primaryColor,
          hoverColor: theme.primaryColor,
          floatingLabelStyle: TextStyle(color: theme.primaryColor),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.primaryColor)),
        ),
        cursorColor: theme.primaryColor,
      ),
      EditCommandMenu(
        commands: widget.command.commands,
        onCommandSelected: (command) => {
          setState(() {
            selectedCommand =
                command != null ? widget.command.commands.indexOf(command) : -1;
          })
        },
        onAttributeChanged: (command) {
          if (widget.command is ParallelCommandGroup ||
              widget.command is ParallelDeadlineGroup ||
              widget.command is ParallelRaceGroup) {
            if (widget.command.commands[selectedCommand].startTime !=
                command.startTime) {
              for (var command in widget.command.commands) {
                command = command.copyWith(startTime: command.startTime);
              }
            }
          } else if (widget.command.commands.length - 1 != selectedCommand &&
              widget.command.commands[selectedCommand + 1].startTime !=
                  command.endTime) {
            widget.command.commands[selectedCommand + 1] = widget
                .command.commands[selectedCommand + 1]
                .copyWith(startTime: command.endTime);
          }
          widget.command.commands[selectedCommand] = command;
          widget.onChanged(
              widget.command.copyWith(commands: widget.command.commands));
        },
        selectedCommand: selectedCommand,
        onCommandsChanged: (commands) {
          widget.onChanged(widget.command.copyWith(commands: commands));
        },
        startTimeLocked: true,
      )
    ]);
  }
}
