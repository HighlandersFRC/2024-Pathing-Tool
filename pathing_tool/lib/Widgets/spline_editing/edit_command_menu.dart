// TODO Need to add add command button

import 'package:flutter/material.dart';
import 'package:pathing_tool/Utils/Structs/command.dart';

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
    setState(() {
      widget.commands[widget.selectedCommand] = newCommand;
    });
    widget.onAttributeChanged(newCommand);
  }

  void deleteCommand() {
    setState(() {
      widget.commands.removeAt(widget.selectedCommand);
    });
    widget.onCommandChanged(widget.commands);
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
                  DropdownButton<int>(
                    value: widget.selectedCommand != -1
                        ? widget.selectedCommand
                        : null,
                    hint: const Text('Select a command'),
                    onChanged: (int? newIndex) {
                      widget.onCommandSelected(newIndex != null
                          ? widget.commands[newIndex]
                          : null);
                    },
                    items: widget.commands.asMap().entries.map((entry) {
                      int idx = entry.key;
                      return DropdownMenuItem<int>(
                        value: idx,
                        child: Text('Command ${idx + 1}'),
                      );
                    }).toList(),
                  ),
                  if (selectedCommand != null)
                    Column(
                      children: [
                        CommandEditor(
                          command: selectedCommand!,
                          onChanged: updateCommand,
                        ),
                        if (selectedCommand is BranchedCommand)
                          BranchedCommandEditor(
                            command: selectedCommand as BranchedCommand,
                            onChanged: updateCommand,
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: deleteCommand,
                        ),
                      ],
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

  const CommandEditor({
    super.key,
    required this.onChanged,
    required this.command,
  });

  @override
  Widget build(BuildContext context) {
    TextEditingController startTimeController = TextEditingController(text: command.startTime.toString());
    TextEditingController endTimeController = TextEditingController(text: command.endTime.toString());
    TextEditingController nameController = TextEditingController(text: command.commandName);

    return Column(
      children: [
        TextField(
          controller: startTimeController,
          decoration: const InputDecoration(labelText: 'Start Time'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) {
            onChanged(command.copyWith(startTime: double.parse(value)));
          },
        ),
        TextField(
          controller: endTimeController,
          decoration: const InputDecoration(labelText: 'End Time'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) {
            onChanged(command.copyWith(endTime: double.parse(value)));
          },
        ),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Command Name'),
          onChanged: (value) {
            onChanged(command.copyWith(commandName: value));
          },
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
    TextEditingController conditionController = TextEditingController(text: command.condition);

    return Column(
      children: [
        TextField(
          controller: conditionController,
          decoration: const InputDecoration(labelText: 'Condition'),
          onChanged: (value) {
            onChanged(command.copyWith(condition: value));
          },
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
