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
    if (commandJson.containsKey("branchedCommand")) {
      return BranchedCommand.branchedCommandFromJson(
          commandJson["branchedCommand"]);
    } else if (commandJson.containsKey("parallelCommandGroup")) {
      return ParallelCommandGroup.parallelCommandGroupFromJson(commandJson);
    } else if (commandJson.containsKey("parallelDeadlineGroup")) {
      return ParallelDeadlineGroup.parallelDeadlineGroupFromJson(commandJson);
    } else if (commandJson.containsKey("parallelRaceGroup")) {
      return ParallelRaceGroup.parallelRaceGroupFromJson(commandJson);
    } else if (commandJson.containsKey("sequentialCommandGroup")) {
      return SequentialCommandGroup.sequentialCommandGroupFromJson(commandJson);
    } else {
      return normalCommandFromJson(commandJson["command"]);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      if (this is BranchedCommand)
        "branchedCommand": (this as BranchedCommand).toJson()
      else if (this is ParallelCommandGroup)
        "parallelCommandGroup": (this as ParallelCommandGroup).toJson()
      else if (this is ParallelRaceGroup)
        "parallelRaceGroup": (this as ParallelRaceGroup).toJson()
        else if (this is ParallelDeadlineGroup)
        "parallelDeadlineGroup": (this as ParallelDeadlineGroup).toJson()
      else if (this is SequentialCommandGroup)
        "sequentialCommandGroup": (this as SequentialCommandGroup).toJson()
      else
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
    String condition = commandJson["branchedCommand"]["condition"];
    Command onTrue = Command.normalCommandFromJson(
        commandJson["branchedCommand"]["on_true"]);
    Command onFalse = Command.normalCommandFromJson(
        commandJson["branchedCommand"]["on_false"]);
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
      "branchedCommand": {
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
    return BranchedCommand(
      condition ?? this.condition,
      onTrue ?? this.onTrue,
      onFalse ?? this.onFalse,
    );
  }
}

class ParallelCommandGroup extends Command {
  final List<Command> commands;
  ParallelCommandGroup(this.commands)
      : super(
            commandName: "Parallel Command Group",
            startTime: _getFirstStartTime(commands),
            endTime: _getLastEndTime(commands));
  @override
  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "commands": [...commands.map((command) => command.toJson())]
    };
  }

  @override
  ParallelCommandGroup copyWith({
    List<Command>? commands,
    double? startTime,
    double? endTime,
    String? commandName,
  }) {
    return ParallelCommandGroup(
      commands ?? this.commands,
    );
  }

  static ParallelCommandGroup parallelCommandGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      ...commandJson["commands"].map((commandJson) {
        Command.fromJson(commandJson);
      })
    ];
    return ParallelCommandGroup(
      commands,
    );
  }
}

class ParallelDeadlineGroup extends Command {
  final List<Command> commands;
  ParallelDeadlineGroup(this.commands)
      : super(
            commandName: "Parallel Deadline Group",
            startTime: _getFirstStartTime(commands),
            endTime: commands.firstOrNull?.endTime ?? 0);
  @override
  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "commands": [...commands.map((command) => command.toJson())]
    };
  }

  @override
  ParallelDeadlineGroup copyWith({
    List<Command>? commands,
    double? startTime,
    double? endTime,
    String? commandName,
  }) {
    return ParallelDeadlineGroup(
      commands ?? this.commands,
    );
  }

  static ParallelDeadlineGroup parallelDeadlineGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      ...commandJson["commands"].map((commandJson) {
        Command.fromJson(commandJson);
      })
    ];
    return ParallelDeadlineGroup(
      commands,
    );
  }
}

class ParallelRaceGroup extends Command {
  final List<Command> commands;
  ParallelRaceGroup(this.commands,)
      : super(
            commandName: "Parallel Race Group",
            startTime: _getFirstStartTime(commands),
            endTime: _getFirstEndTime(commands));
  @override
  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "commands": [...commands.map((command) => command.toJson())]
    };
  }

  @override
  ParallelRaceGroup copyWith({
    List<Command>? commands,
    double? startTime,
    double? endTime,
    String? commandName,
  }) {
    return ParallelRaceGroup(
      commands ?? this.commands,
    );
  }

  static ParallelRaceGroup parallelRaceGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      ...commandJson["commands"].map((commandJson) {
        Command.fromJson(commandJson);
      })
    ];
    return ParallelRaceGroup(
      commands,
    );
  }
}

class SequentialCommandGroup extends Command {
  final List<Command> commands;
  SequentialCommandGroup(this.commands)
      : super(
            commandName: "Sequential Command Group",
            startTime: commands.firstOrNull?.startTime ?? 0,
            endTime: commands.lastOrNull?.endTime ?? 0);
  @override
  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "commands": [...commands.map((command) => command.toJson())]
    };
  }

  @override
  SequentialCommandGroup copyWith({
    List<Command>? commands,
    double? startTime,
    double? endTime,
    String? commandName,
  }) {
    return SequentialCommandGroup(
      commands ?? this.commands,
    );
  }

  static SequentialCommandGroup sequentialCommandGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      ...commandJson["commands"].map((commandJson) {
        Command.fromJson(commandJson);
      })
    ];
    return SequentialCommandGroup(
      commands,
    );
  }
}

double _getLastEndTime(List<Command> commands) {
  commands.sort((a, b) => a.endTime.compareTo(b.endTime));
  return commands.lastOrNull != null ? commands.last.endTime: 0;
}

double _getFirstEndTime(List<Command> commands) {
  commands.sort((a, b) => a.endTime.compareTo(b.endTime));
  return commands.firstOrNull != null ? commands.first.endTime: 0;
}

double _getFirstStartTime(List<Command> commands) {
  commands.sort((a, b) => a.endTime.compareTo(b.endTime));
  return commands.firstOrNull != null ? commands.first.startTime: 0;
}
