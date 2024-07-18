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
      return normalCommandFromJson(commandJson);
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
    if (startTime != null) {
      onTrue = (onTrue ?? this.onTrue).copyWith(startTime: startTime);
      onFalse = (onFalse ?? this.onFalse).copyWith(startTime: startTime);
      if (onTrue.endTime < onTrue.startTime){
        onTrue = onTrue.copyWith(endTime: onTrue.startTime);
      }
      if (onFalse.endTime < onFalse.startTime){
        onFalse = onFalse.copyWith(endTime: onFalse.startTime);
      }
    }
    return BranchedCommand(
      condition ?? this.condition,
      onTrue ?? this.onTrue,
      onFalse ?? this.onFalse,
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
  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "commands": [...commands.map((command) => command.toJson())]
    };
  }

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
          startTime: _getFirstStartTime(commands, start),
          endTime: _getLastEndTime(commands, start),
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
      commands =[...(commands ?? this.commands).map((subCommand){
        if (subCommand.endTime<startTime){
          return subCommand.copyWith(startTime: startTime, endTime: startTime);
        }
        return subCommand.copyWith(startTime: startTime);
      })];
    }
    return ParallelCommandGroup(
      commands ?? this.commands,
      start: startTime ?? 0
    );
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
          startTime: _getFirstStartTime(commands, start),
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
      commands =[...(commands ?? this.commands).map((subCommand){
        if (subCommand.endTime<startTime){
          return subCommand.copyWith(startTime: startTime, endTime: startTime);
        }
        return subCommand.copyWith(startTime: startTime);
      })];
    }
    return ParallelDeadlineGroup(
      commands ?? this.commands,
      start: startTime ?? 0
    );
  }

  static ParallelDeadlineGroup parallelDeadlineGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      for (var cmdJson in commandJson["commands"]) Command.fromJson(cmdJson)
    ];
    return ParallelDeadlineGroup(commands);
  }
}

class ParallelRaceGroup extends MultipleCommand {
  ParallelRaceGroup(List<Command> commands, {double start = 0})
      : super(
          commands: commands,
          startTime: _getFirstStartTime(commands, start),
          endTime: _getFirstEndTime(commands, start),
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
      commands =[...(commands ?? this.commands).map((subCommand){
        if (subCommand.endTime<startTime){
          return subCommand.copyWith(startTime: startTime, endTime: startTime);
        }
        return subCommand.copyWith(startTime: startTime);
      })];
    }
    return ParallelRaceGroup(
      commands ?? this.commands,
      start: startTime ?? 0
    );
  }

  static ParallelRaceGroup parallelRaceGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      for (var cmdJson in commandJson["commands"]) Command.fromJson(cmdJson)
    ];
    return ParallelRaceGroup(commands);
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
    if (commands != null) commands.sort((a,b)=>a.startTime.compareTo(b.startTime));
    commands =[...(commands ?? this.commands).map((subCommand){
        if (subCommand.endTime< subCommand.startTime){
          return subCommand.copyWith(endTime: subCommand.startTime);
        }else {
          return subCommand;
        }
      })];
    if (startTime != null) {
      if (commands.isNotEmpty) {
        commands.first = commands.first.copyWith(startTime: startTime);
      }
    }
    commands =[...(commands).map((subCommand){
        if (subCommand.endTime< subCommand.startTime){
          return subCommand.copyWith(endTime: subCommand.startTime);
        }else {
          return subCommand;
        }
      })];
    
    return SequentialCommandGroup(
      commands,
      start: startTime ?? 0
    );
  }

  static SequentialCommandGroup sequentialCommandGroupFromJson(
      Map<String, dynamic> commandJson) {
    List<Command> commands = [
      for (var cmdJson in commandJson["commands"]) Command.fromJson(cmdJson)
    ];
    return SequentialCommandGroup(commands);
  }
}

double _getLastEndTime(List<Command> commands, double defaultNum) {
  commands.sort((a, b) => a.endTime.compareTo(b.endTime));
  return commands.isNotEmpty ? commands.last.endTime : defaultNum;
}

double _getFirstEndTime(List<Command> commands, double defaultNum) {
  commands.sort((a, b) => a.endTime.compareTo(b.endTime));
  return commands.isNotEmpty ? commands.first.endTime : defaultNum;
}

double _getFirstStartTime(List<Command> commands, double defaultNum) {
  commands.sort((a, b) => a.startTime.compareTo(b.startTime));
  return commands.isNotEmpty ? commands.first.startTime : defaultNum;
}