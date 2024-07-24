import 'dart:math';

class Command {
  final double startTime, endTime;
  final String commandName;

  static Command normalCommandFromJson(Map<String, dynamic> commandJson) {
    double start = commandJson["start"], end = commandJson["end"];
    String name = commandJson["name"];
    return Command(startTime: start, endTime: end, commandName: name);
  }

  static Command fromJson(Map<String, dynamic> commandJson) {
    if (commandJson.containsKey("branched_command")) {
      return BranchedCommand.branchedCommandFromJson(
          commandJson["branched_command"]);
    } else if (commandJson.containsKey("parallel_command_group")) {
      return ParallelCommandGroup.parallelCommandGroupFromJson(
          commandJson["parallel_command_group"]);
    } else if (commandJson.containsKey("parallel_deadline_group")) {
      return ParallelDeadlineGroup.parallelDeadlineGroupFromJson(
          commandJson["parallel_deadline_group"]);
    } else if (commandJson.containsKey("parallel_race_group")) {
      return ParallelRaceGroup.parallelRaceGroupFromJson(
          commandJson["parallel_race_group"]);
    } else if (commandJson.containsKey("sequential_command_group")) {
      return SequentialCommandGroup.sequentialCommandGroupFromJson(
          commandJson["sequential_command_group"]);
    } else {
      return normalCommandFromJson(commandJson["command"]);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "command": {
        "start": startTime,
        "end": endTime,
        "name": commandName,
      }
    };
  }

  Command({
    required this.startTime,
    required this.endTime,
    required this.commandName,
  });

  Command copyWith({
    double? startTime,
    double? endTime,
    String? commandName,
  }) {
    if (!(startTime == null)) {
      if ((endTime ?? this.endTime) < startTime) {
        endTime = startTime;
      }
    }
    return Command(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      commandName: commandName ?? this.commandName,
    );
  }
}

class BranchedCommand extends Command {
  final String condition;
  final Command onTrue, onFalse;

  static BranchedCommand branchedCommandFromJson(
      Map<String, dynamic> commandJson) {
    String condition = commandJson["condition"];
    Command onTrue = Command.fromJson(commandJson["on_true"]);
    Command onFalse = Command.fromJson(commandJson["on_false"]);
    return BranchedCommand(
      condition,
      onTrue,
      onFalse,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "branched_command": {
        "condition": condition,
        "on_true": onTrue.toJson(),
        "on_false": onFalse.toJson(),
      }
    };
  }

  BranchedCommand(
    this.condition,
    this.onTrue,
    this.onFalse,
  ) : super(
          startTime: min(onTrue.startTime, onFalse.startTime),
          endTime: max(onTrue.endTime, onFalse.endTime),
          commandName: "Branched Command",
        );

  @override
  BranchedCommand copyWith({
    String? condition,
    Command? onTrue,
    Command? onFalse,
    double? startTime,
    double? endTime,
    String? commandName,
  }) {
    if (startTime != null) {
      onTrue = (onTrue ?? this.onTrue).copyWith(startTime: startTime);
      onFalse = (onFalse ?? this.onFalse).copyWith(startTime: startTime);
      double deltaStart = startTime - this.startTime;
      onTrue = onTrue.copyWith(endTime: onTrue.endTime + deltaStart);
      onFalse = onFalse.copyWith(endTime: onFalse.startTime + deltaStart);
    }
    onTrue = (onTrue ?? this.onTrue).copyWith();
    onFalse = (onFalse ?? this.onFalse).copyWith();
    return BranchedCommand(
      condition ?? this.condition,
      onTrue,
      onFalse,
    );
  }
}

abstract class MultipleCommand extends Command {
  final List<Command> commands;

  MultipleCommand({
    required this.commands,
    required double startTime,
    required double endTime,
    required String commandName,
  }) : super(
          startTime: startTime,
          endTime: endTime,
          commandName: commandName,
        );

  @override
  MultipleCommand copyWith({
    List<Command>? commands,
    double? startTime,
    double? endTime,
    String? commandName,
  });
}

class ParallelCommandGroup extends MultipleCommand {
  ParallelCommandGroup(List<Command> commands, {double start = 0})
      : super(
          commands: commands,
          startTime: getFirstStartTime(commands, start),
          endTime: getLastEndTime(commands, start),
          commandName: "Parallel Command Group",
        );

  @override
  ParallelCommandGroup copyWith({
    List<Command>? commands,
    double? startTime,
    double? endTime,
    String? commandName,
  }) {
    if (startTime != null) {
      if ((commands ?? this.commands).isNotEmpty) {
        double deltaStart =
            startTime - (commands ?? this.commands)[0].startTime;
        commands = [
          for (var command in (commands ?? this.commands))
            command.copyWith(
                startTime: command.startTime + deltaStart,
                endTime: command.endTime + deltaStart)
        ];
      }
    }
    commands = [
      for (var command in (commands ?? this.commands)) command.copyWith()
    ];
    return ParallelCommandGroup(commands, start: startTime ?? 0);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "parallel_command_group": {
        "commands": [...commands.map((command) => command.toJson())]
      }
    };
  }

  static ParallelCommandGroup parallelCommandGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      for (var cmdJson in commandJson["commands"]) Command.fromJson(cmdJson)
    ];
    return ParallelCommandGroup(commands);
  }
}

class ParallelDeadlineGroup extends MultipleCommand {
  ParallelDeadlineGroup(List<Command> commands, {double start = 0})
      : super(
          commands: commands,
          startTime: getFirstStartTime(commands, start),
          endTime: commands.isNotEmpty ? commands[0].endTime : start,
          commandName: "Parallel Deadline Group",
        );

  @override
  ParallelDeadlineGroup copyWith({
    List<Command>? commands,
    double? startTime,
    double? endTime,
    String? commandName,
  }) {
    if (startTime != null) {
      if ((commands ?? this.commands).isNotEmpty) {
        double deltaStart =
            startTime - (commands ?? this.commands)[0].startTime;
        commands = [
          for (var command in (commands ?? this.commands))
            command.copyWith(
                startTime: command.startTime + deltaStart,
                endTime: command.endTime + deltaStart)
        ];
      }
    }
    commands = [
      for (var command in (commands ?? this.commands)) command.copyWith()
    ];
    return ParallelDeadlineGroup(commands, start: startTime ?? 0);
  }

  static ParallelDeadlineGroup parallelDeadlineGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      for (var cmdJson in commandJson["commands"]) Command.fromJson(cmdJson)
    ];
    return ParallelDeadlineGroup(commands);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "parallel_deadline_group": {
        "commands": [...commands.map((command) => command.toJson())]
      }
    };
  }
}

class ParallelRaceGroup extends MultipleCommand {
  ParallelRaceGroup(List<Command> commands, {double start = 0})
      : super(
          commands: commands,
          startTime: getFirstStartTime(commands, start),
          endTime: getFirstEndTime(commands, start),
          commandName: "Parallel Race Group",
        );

  @override
  ParallelRaceGroup copyWith({
    List<Command>? commands,
    double? startTime,
    double? endTime,
    String? commandName,
  }) {
    if (startTime != null) {
      if ((commands ?? this.commands).isNotEmpty) {
        double deltaStart =
            startTime - (commands ?? this.commands)[0].startTime;
        commands = [
          for (var command in (commands ?? this.commands))
            command.copyWith(
                startTime: command.startTime + deltaStart,
                endTime: command.endTime + deltaStart)
        ];
      }
    }
    commands = [
      for (var command in (commands ?? this.commands)) command.copyWith()
    ];
    return ParallelRaceGroup(commands, start: startTime ?? 0);
  }

  static ParallelRaceGroup parallelRaceGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      for (var cmdJson in commandJson["commands"]) Command.fromJson(cmdJson)
    ];
    return ParallelRaceGroup(commands);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "parallel_race_group": {
        "commands": [...commands.map((command) => command.toJson())]
      }
    };
  }
}

class SequentialCommandGroup extends MultipleCommand {
  SequentialCommandGroup(List<Command> commands, {double start = 0})
      : super(
          commands: commands,
          startTime: commands.isNotEmpty ? commands[0].startTime : start,
          endTime: commands.isNotEmpty ? commands.last.endTime : start,
          commandName: "Sequential Command Group",
        );

  @override
  SequentialCommandGroup copyWith({
    List<Command>? commands,
    double? startTime,
    double? endTime,
    String? commandName,
  }) {
    commands = [
      ...(commands ?? this.commands).map((subCommand) {
        if (subCommand.endTime < subCommand.startTime) {
          return subCommand.copyWith(endTime: subCommand.startTime);
        } else {
          return subCommand;
        }
      })
    ];
    if (startTime != null) {
      if (commands.isNotEmpty) {
        double deltaStart = startTime - commands[0].startTime;
        commands = [
          for (var command in (commands))
            command.copyWith(
                startTime: command.startTime + deltaStart,
                endTime: command.endTime + deltaStart)
        ];
      }
    }
    commands = [
      ...commands.map((subCommand) {
        if (subCommand.endTime < subCommand.startTime) {
          return subCommand.copyWith(endTime: subCommand.startTime);
        } else {
          return subCommand;
        }
      })
    ];
    commands = [
      ...commands.asMap().entries.map((value) {
        var subCommand = value.value;
        var idx = value.key;
        if (idx > 0) {
          return subCommand.copyWith(startTime: commands![idx - 1].endTime);
        } else {
          return subCommand;
        }
      })
    ];
    commands = [for (var command in (commands)) command.copyWith()];
    return SequentialCommandGroup(commands, start: startTime ?? 0);
  }

  static SequentialCommandGroup sequentialCommandGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      for (var cmdJson in commandJson["commands"]) Command.fromJson(cmdJson)
    ];
    return SequentialCommandGroup(commands);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "sequential_command_group": {
        "commands": [...commands.map((command) => command.toJson())]
      }
    };
  }
}

double getLastEndTime(List<Command> commands, double defaultNum) {
  commands.sort((a, b) => a.endTime.compareTo(b.endTime));
  return commands.isNotEmpty ? commands.last.endTime : defaultNum;
}

double getFirstEndTime(List<Command> commands, double defaultNum) {
  commands.sort((a, b) => a.endTime.compareTo(b.endTime));
  return commands.isNotEmpty ? commands.first.endTime : defaultNum;
}

double getFirstStartTime(List<Command> commands, double defaultNum) {
  commands.sort((a, b) => a.startTime.compareTo(b.startTime));
  return commands.isNotEmpty ? commands.first.startTime : defaultNum;
}
