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


  Map<String, dynamic> toBackendMap() {
    final bool status = isCompleted == 1;
    final String? completedAtStr = completedAt?.toUtc().toIso8601String();
    
    return {
      'id': id,
      'title': title,
      'description': description,
      'hexColor': rgbToHex(color),
      'hex_color': rgbToHex(color),
      'dueAt': dueAt.toUtc().toIso8601String(),
      'due_at': dueAt.toUtc().toIso8601String(),
      'isCompleted': status,
      'is_completed': status,
      'completedAt': completedAtStr,
      'completed_at': completedAtStr,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory TaskModel.fromMap(dynamic raw) {
    final map = (raw is Map<String, dynamic>)
        ? raw
        : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});

    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      final dateStr = value.toString().trim();

      try {
        final parsed = DateTime.parse(dateStr);
        return parsed.isUtc ? parsed.toLocal() : parsed;
      } catch (_) {
        return DateTime.now();
      }
    }

    int parseBoolToInt(dynamic value) {
      if (value is int) return value;
      if (value is bool) return value ? 1 : 0;
      if (value == null) return 0;
      if (value.toString() == '1' || value.toString().toLowerCase() == 'true') return 1;
      return 0;
    }

    return TaskModel(
      id: map['id'] ?? map['_id'] ?? '',
      uid: map['uid'] ?? map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',

      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
      dueAt: parseDate(map['due_at'] ?? map['dueAt']),

      color: hexToRgb(map['hex_color'] ?? map['hexColor'] ?? '#000000'),

      isSynced: parseBoolToInt(map['is_synced'] ?? map['isSynced'] ?? 1),
      isCompleted: parseBoolToInt(map['is_completed'] ?? map['isCompleted'] ?? 0),

      completedAt: (map['completed_at'] != null || map['completedAt'] != null)
          ? parseDate(map['completed_at'] ?? map['completedAt'])
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
