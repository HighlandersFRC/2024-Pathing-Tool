import 'package:fl_chart/fl_chart.dart';

class Command {
  final double startTime, endTime;
  final String commandName;
  final bool branched;

  static Command unbranchedCommandFromJson(Map<String, dynamic> commandJson) {
    double start = commandJson["start"], end = commandJson["end"];
    String name = commandJson["name"];
    return Command(startTime: start, endTime: end, commandName: name);
  }

  static Command fromJson(Map<String, dynamic> commandJson) {
    return commandJson["branched"]
        ? BranchedCommand.branchedCommandFromJson(commandJson["branchedCommand"])
        : unbranchedCommandFromJson(commandJson["command"]);
  }

  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "branched": branched,
      if (branched)
        "branchedCommand": (this as BranchedCommand).toJson()
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
    this.branched = false,
  });

  Command copyWith({
    double? startTime,
    double? endTime,
    String? commandName,
    bool? branched,
  }) {
    return Command(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      commandName: commandName ?? this.commandName,
      branched: branched ?? this.branched,
    );
  }
}

class BranchedCommand extends Command {
  final String condition;
  final Command onTrue, onFalse;

  static BranchedCommand branchedCommandFromJson(Map<String, dynamic> commandJson) {
    double start = commandJson["start"], end = commandJson["end"];
    String condition = commandJson["branchedCommand"]["condition"];
    Command onTrue =
        Command.unbranchedCommandFromJson(commandJson["branchedCommand"]["on_true"]);
    Command onFalse =
        Command.unbranchedCommandFromJson(commandJson["branchedCommand"]["on_false"]);
    return BranchedCommand(condition, onTrue, onFalse, start, end);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "start": startTime,
      "end": endTime,
      "branched": branched,
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
    double start,
    double end,
  ) : super(
          startTime: start,
          endTime: end,
          commandName: "branched_command",
          branched: true,
        );

  @override
  BranchedCommand copyWith({
    String? condition,
    Command? onTrue,
    Command? onFalse,
    double? startTime,
    double? endTime,
    String? commandName,
    bool? branched,
  }) {
    return BranchedCommand(
      condition ?? this.condition,
      onTrue ?? this.onTrue,
      onFalse ?? this.onFalse,
      startTime ?? this.startTime,
      endTime ?? this.endTime,
    );
  }
}
