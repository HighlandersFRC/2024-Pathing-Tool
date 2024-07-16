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
          commandName: "branched_command",
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
  final double startTime, endTime;
  ParallelCommandGroup(this.commands, this.startTime, this.endTime)
      : super(
            commandName: "parallelCommand",
            startTime: startTime,
            endTime: endTime);
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
      startTime ?? this.startTime,
      endTime ?? this.endTime,
    );
  }

  static ParallelCommandGroup parallelCommandGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      ...commandJson["commands"].map((commandJson) {
        Command.fromJson(commandJson);
      })
    ];
    double startTime = commandJson["start"], endTime = commandJson["end"];
    return ParallelCommandGroup(
      commands,
      startTime,
      endTime,
    );
  }

  double _getEndTime(List<Command> commands){
    commands.sort((a,b)=>a.endTime.compareTo(b.endTime));
    return commands.last.endTime;
  }
}

class ParallelDeadlineGroup extends Command {
  final List<Command> commands;
  final double startTime, endTime;
  ParallelDeadlineGroup(this.commands, this.startTime, this.endTime)
      : super(
            commandName: "parallelDeadlineCommand",
            startTime: startTime,
            endTime: endTime);
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
      startTime ?? this.startTime,
      endTime ?? this.endTime,
    );
  }

  static ParallelDeadlineGroup parallelDeadlineGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      ...commandJson["commands"].map((commandJson) {
        Command.fromJson(commandJson);
      })
    ];
    double startTime = commandJson["start"], endTime = commandJson["end"];
    return ParallelDeadlineGroup(
      commands,
      startTime,
      endTime,
    );
  }
}

class SequentialCommandGroup extends Command {
  final List<Command> commands;
  final double startTime, endTime;
  SequentialCommandGroup(this.commands, this.startTime, this.endTime)
      : super(
            commandName: "sequentialCommandGroup",
            startTime: startTime,
            endTime: endTime);
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
      startTime ?? this.startTime,
      endTime ?? this.endTime,
    );
  }

  static SequentialCommandGroup sequentialCommandGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      ...commandJson["commands"].map((commandJson) {
        Command.fromJson(commandJson);
      })
    ];
    double startTime = commandJson["start"], endTime = commandJson["end"];
    return SequentialCommandGroup(
      commands,
      startTime,
      endTime,
    );
  }
}