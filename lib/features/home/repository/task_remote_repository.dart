import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:frontend/core/constants/constants.dart';
import 'package:frontend/features/home/repository/task_local_repository.dart';
import 'package:frontend/models/task_model.dart';
import 'package:http/http.dart' as http;

class TaskRemoteRepository {
  final TaskLocalRepository taskLocalRepository = TaskLocalRepository();

  String _responseError(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic> && body["error"] != null) {
        return body["error"].toString();
      }
    } catch (_) {}
    return fallback;
  }

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
      final res = await http
          .post(
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
              'dueAt': dueAt.toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (res.statusCode != 201) {
        throw _responseError(res, "Failed to create task (${res.statusCode})");
      }

      final data = jsonDecode(res.body);
      return TaskModel.fromMap(data);
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on HttpException {
      throw "Network request failed. Please try again.";
    } on FormatException {
      throw "Server returned invalid response format.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } catch (e) {
      throw e.toString();
    }
  }

  /// GET TASKS
  Future<List<TaskModel>> getTasks({
    required String token,
    required String uid,
  }) async {
    try {
      final res = await http
          .get(
            Uri.parse("${Constants.backendUri}/tasks"),
            headers: {
              'Content-Type': 'application/json',
              'x-auth-token': token,
            },
          )
          .timeout(const Duration(seconds: 40));

      if (res.statusCode != 200) {
        throw _responseError(res, "Failed to fetch tasks (${res.statusCode})");
      }

      final List data = jsonDecode(res.body);

      final tasks = data.map((e) => TaskModel.fromMap(e)).toList();

      return tasks;
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on HttpException {
      throw "Network request failed. Please try again.";
    } on FormatException {
      throw "Server returned invalid response format.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } catch (e) {
      throw e.toString();
    }
  }

  /// UPDATE TASK
  Future<TaskModel> updateTask({
    required TaskModel task,
    required String token,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse("${Constants.backendUri}/tasks/${task.id}"),
            headers: {
              'Content-Type': 'application/json',
              'x-auth-token': token,
            },
            body: jsonEncode(task.toBackendMap()),
          )
          .timeout(const Duration(seconds: 40));

      if (res.statusCode != 200) {
        throw _responseError(res, "Failed to update task (${res.statusCode})");
      }

      final data = jsonDecode(res.body);

      final updatedTask = TaskModel.fromMap(data);

      return updatedTask;
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on HttpException {
      throw "Network request failed. Please try again.";
    } on FormatException {
      throw "Server returned invalid response format.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } catch (e) {
      throw e.toString();
    }
  }

  /// DELETE TASK
  Future<bool> deleteTask({
    required String taskId,
    required String token,
  }) async {
    try {
      final res = await http
          .delete(
            Uri.parse("${Constants.backendUri}/tasks/$taskId"),
            headers: {
              'Content-Type': 'application/json',
              'x-auth-token': token,
            },
          )
          .timeout(const Duration(seconds: 40));

      if (res.statusCode != 200) {
        throw _responseError(res, "Failed to delete task (${res.statusCode})");
      }

      return true;
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on HttpException {
      throw "Network request failed. Please try again.";
    } on FormatException {
      throw "Server returned invalid response format.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
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

      final res = await http
          .post(
            Uri.parse("${Constants.backendUri}/tasks/sync"),
            headers: {
              'Content-Type': 'application/json',
              'x-auth-token': token,
            },
            body: jsonEncode(taskListInMap),
          )
          .timeout(const Duration(seconds: 40));

      if (res.statusCode != 201) {
        throw _responseError(res, "Failed to sync tasks (${res.statusCode})");
      }

      return true;
    } on SocketException {
      throw "No internet connection or server unreachable.";
    } on HttpException {
      throw "Network request failed. Please try again.";
    } on FormatException {
      throw "Server returned invalid response format.";
    } on TimeoutException {
      throw "Server timed out. Please try again.";
    } catch (e) {
      debugPrint("Sync Error: $e");
      return false;
    }
  }
}
