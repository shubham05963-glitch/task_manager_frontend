import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frontend/core/constants/constants.dart';
import 'package:frontend/features/home/repository/task_local_repository.dart';
import 'package:frontend/models/task_model.dart';
import 'package:http/http.dart' as http;

class TaskRemoteRepository {
  final TaskLocalRepository taskLocalRepository = TaskLocalRepository();

  /// CREATE TASK
  Future<TaskModel> createTask({
    required String id,
    required String title,
    required String description,
    required String hexColor,
    required String token,
    required String uid,
    required DateTime dueAt,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("${Constants.backendUri}/tasks"),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({
          'id': id,
          'title': title,
          'description': description,
          'hexColor': hexColor,
          'dueAt': dueAt.toIso8601String(),
        }),
      );

      if (res.statusCode != 201) {
        throw jsonDecode(res.body)['error'];
      }

      final data = jsonDecode(res.body);
      return TaskModel.fromMap(data);
    } catch (e) {
      rethrow;
    }
  }

  /// GET TASKS
  Future<List<TaskModel>> getTasks({
    required String token,
    required String uid,
  }) async {
    try {
      final res = await http.get(
        Uri.parse("${Constants.backendUri}/tasks"),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (res.statusCode != 200) {
        throw jsonDecode(res.body)['error'];
      }

      final List data = jsonDecode(res.body);

      final tasks = data.map((e) => TaskModel.fromMap(e)).toList();

      return tasks;
    } catch (e) {
      rethrow;
    }
  }

  /// UPDATE TASK
  Future<TaskModel> updateTask({
    required TaskModel task,
    required String token,
  }) async {
    try {
      final res = await http.put(
        Uri.parse("${Constants.backendUri}/tasks/${task.id}"),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode(task.toBackendMap()),
      );

      if (res.statusCode != 200) {
        throw jsonDecode(res.body)['error'];
      }

      final data = jsonDecode(res.body);

      final updatedTask = TaskModel.fromMap(data);

      return updatedTask;
    } catch (e) {
      rethrow;
    }
  }

  /// DELETE TASK
  Future<bool> deleteTask({
    required String taskId,
    required String token,
  }) async {
    try {
      final res = await http.delete(
        Uri.parse("${Constants.backendUri}/tasks/$taskId"),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (res.statusCode != 200) {
        throw jsonDecode(res.body)['error'];
      }

      return true;
    } catch (e) {
      debugPrint("Delete Task Error: $e");
      return false;
    }
  }

  /// SYNC OFFLINE TASKS
  Future<bool> syncTasks({
    required String token,
    required List<TaskModel> tasks,
  }) async {
    try {
      final taskListInMap = tasks.map((task) => task.toBackendMap()).toList();

      final res = await http.post(
        Uri.parse("${Constants.backendUri}/tasks/sync"),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode(taskListInMap),
      );

      if (res.statusCode != 201) {
        throw jsonDecode(res.body)['error'];
      }

      return true;
    } catch (e) {
      debugPrint("Sync Error: $e");
      return false;
    }
  }
}
