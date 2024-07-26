import 'package:flutter/material.dart';

class RobotConfig {
  double width, length;
  List<IconCommand> commands;
  List<IconCondition> conditions;
  String name;

  RobotConfig(this.name, this.length, this.width, this.commands, this.conditions);

  factory RobotConfig.fromJson(Map<String, dynamic> json) {
    var commandsJson = json['commands'] as List;
    var conditionsJson = json['conditions'] as List;
    List<IconCommand> commandsList = commandsJson.map((e) => IconCommand.fromJson(e)).toList();
    List<IconCondition> conditionsList = conditionsJson.map((e) => IconCondition.fromJson(e)).toList();
    return RobotConfig(
      json['name'],
      json['length'],
      json['width'],
      commandsList,
      conditionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'length': length,
      'width': width,
      'commands': commands.map((e) => e.toJson()).toList(),
      'conditions': conditions.map((e) => e.toJson()).toList(),
    };
  }
}

class IconCommand {
  String name;
  IconData? icon;

  IconCommand(this.name, this.icon);

  factory IconCommand.fromJson(Map<String, dynamic> json) {
    return IconCommand(
      json['name'],
      json['icon'] != null ? IconData(json['icon'], fontFamily: 'MaterialIcons'): null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon': icon?.codePoint,
    };
  }
}

class IconCondition {
  String name;
  IconData? icon;

  IconCondition(this.name, this.icon);

  factory IconCondition.fromJson(Map<String, dynamic> json) {
    return IconCondition(
      json['name'],
      json['icon'] != null ? IconData(json['icon'], fontFamily: 'MaterialIcons'): null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon': icon?.codePoint,
    };
  }
}