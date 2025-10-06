import 'package:flutter/material.dart';

// Stores data to analyze robot pathing capabilities and available commands/conditions
class RobotConfig {
  double width, length;
  double maxVelocity, maxAcceleration, maxCentripetalAcceleration;
  List<IconCommand> commands;
  List<IconCondition> conditions;
  String name;

  RobotConfig(
    this.name,
    this.length,
    this.width,
    this.commands,
    this.conditions, {
    this.maxVelocity = 3.0,
    this.maxAcceleration = 2.0,
    this.maxCentripetalAcceleration = 2.0,
  });

  factory RobotConfig.fromJson(Map<String, dynamic> json) {
    var commandsJson = json['commands'] as List;
    var conditionsJson = json['conditions'] as List;
    List<IconCommand> commandsList =
        commandsJson.map((e) => IconCommand.fromJson(e)).toList();
    List<IconCondition> conditionsList =
        conditionsJson.map((e) => IconCondition.fromJson(e)).toList();
    double maxVelocity = json['max_velocity'] != null
        ? (json['max_velocity'] as num).toDouble()
        : 3.0;
    double maxAcceleration = json['max_acceleration'] != null
        ? (json['max_acceleration'] as num).toDouble()
        : 2.0;
    double maxCentripetalAcceleration =
        json['max_centripetal_acceleration'] != null
            ? (json['max_centripetal_acceleration'] as num).toDouble()
            : 2.0;
    return RobotConfig(
      json['name'],
      json['length'],
      json['width'],
      commandsList,
      conditionsList,
      maxVelocity: maxVelocity,
      maxAcceleration: maxAcceleration,
      maxCentripetalAcceleration: maxCentripetalAcceleration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'length': length,
      'width': width,
      'commands': commands.map((e) => e.toJson()).toList(),
      'conditions': conditions.map((e) => e.toJson()).toList(),
      'max_velocity': maxVelocity,
      'max_acceleration': maxAcceleration,
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
      json['icon'] != null
          ? IconData(json['icon'], fontFamily: 'MaterialIcons')
          : null,
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
      json['icon'] != null
          ? IconData(json['icon'], fontFamily: 'MaterialIcons')
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon': icon?.codePoint,
    };
  }
}
