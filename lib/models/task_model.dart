import 'dart:convert';
import 'dart:ui';

import 'package:frontend/core/constants/utils.dart';

class TaskModel {
  final String id;
  final String uid;
  final String title;
  final Color color;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime dueAt;
  final int isSynced;

  final int isCompleted;
  final DateTime? completedAt;

  TaskModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.dueAt,
    required this.color,
    required this.isSynced,
    this.isCompleted = 0,
    this.completedAt,
  });

  TaskModel copyWith({
    String? id,
    String? uid,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueAt,
    Color? color,
    int? isSynced,
    int? isCompleted,
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueAt: dueAt ?? this.dueAt,
      color: color ?? this.color,
      isSynced: isSynced ?? this.isSynced,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'due_at': dueAt.toIso8601String(),
      'hex_color': rgbToHex(color),
      'is_synced': isSynced,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',

      /// Fix snake_case backend fields
      createdAt: DateTime.parse(
        map['created_at'] ?? map['createdAt'],
      ).toLocal(),

      updatedAt: DateTime.parse(
        map['updated_at'] ?? map['updatedAt'],
      ).toLocal(),

      dueAt: DateTime.parse(
        map['due_at'] ?? map['dueAt'],
      ).toLocal(),

      color: hexToRgb(map['hex_color'] ?? map['hexColor']),

      isSynced: map['is_synced'] ?? map['isSynced'] ?? 1,
      isCompleted: map['is_completed'] ?? map['isCompleted'] ?? 0,

      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at']).toLocal()
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory TaskModel.fromJson(String source) =>
      TaskModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'TaskModel(id: $id, uid: $uid, title: $title, description: $description, dueAt: $dueAt)';
  }

  @override
  bool operator ==(covariant TaskModel other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.uid == uid &&
        other.title == title &&
        other.description == description &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.dueAt == dueAt &&
        other.color == color &&
        other.isSynced == isSynced &&
        other.isCompleted == isCompleted &&
        other.completedAt == completedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    uid.hashCode ^
    title.hashCode ^
    description.hashCode ^
    createdAt.hashCode ^
    updatedAt.hashCode ^
    dueAt.hashCode ^
    color.hashCode ^
    isSynced.hashCode ^
    isCompleted.hashCode ^
    completedAt.hashCode;
  }
}