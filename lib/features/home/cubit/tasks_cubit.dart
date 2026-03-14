import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:frontend/core/constants/utils.dart';
import 'package:frontend/features/home/repository/task_local_repository.dart';
import 'package:frontend/features/home/repository/task_remote_repository.dart';
import 'package:frontend/models/task_model.dart';

part 'tasks_state.dart';

class TasksCubit extends Cubit<TasksState> {
  TasksCubit() : super(TasksInitial());

  final taskRemoteRepository = TaskRemoteRepository();
  final taskLocalRepository = TaskLocalRepository();

  String? currentUid;

  /// Reload tasks from SQLite
  Future<void> _reloadTasks() async {
    if (currentUid == null) return;

    final tasks = await taskLocalRepository.getTasks(currentUid!);

    emit(GetTasksSuccess(tasks));
  }

  /// CREATE NEW TASK (OFFLINE FIRST)
  Future<void> createNewTask({
    required String title,
    required String description,
    required Color color,
    required String token,
    required String uid,
    required DateTime dueAt,
  }) async {
    try {
      currentUid = uid;

      final taskId = const Uuid().v4();

      final taskModel = TaskModel(
        id: taskId,
        uid: uid,
        title: title,
        description: description,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dueAt: dueAt,
        color: color,
        isSynced: 0,
      );

      /// 1. Save locally first
      await taskLocalRepository.insertTask(taskModel);
      await _reloadTasks();

      /// 2. Send to backend
      final remoteTask = await taskRemoteRepository.createTask(
        id: taskId,
        uid: uid,
        title: title,
        description: description,
        hexColor: rgbToHex(color),
        token: token,
        dueAt: dueAt,
      );

      /// 3. If backend returned a different ID (e.g. Mongo ObjectID), replace the local one
      if (remoteTask.id != taskId) {
        await taskLocalRepository.deleteTask(taskId);
      }
      
      // Save the official version from the server
      await taskLocalRepository.insertTask(remoteTask.copyWith(isSynced: 1));
      await _reloadTasks();
    } catch (e) {
      debugPrint("Create Task Error: $e");
    }
  }

  /// GET ALL TASKS
  Future<void> getAllTasks({
    required String token,
    required String uid,
  }) async {
    currentUid = uid;

    try {
      /// 1️⃣ Load local tasks immediately
      final localTasks = await taskLocalRepository.getTasks(uid);
      if (localTasks.isNotEmpty) {
        emit(GetTasksSuccess(localTasks));
      }

      /// 2️⃣ Sync unsynced tasks before fetching (Critical to avoid overwriting)
      await syncTasks(token);

      /// 3️⃣ Fetch backend tasks
      final remoteTasks = await taskRemoteRepository.getTasks(token: token, uid: uid);

      /// 4️⃣ Save backend tasks locally (using smart merge)
      await taskLocalRepository.insertTasks(remoteTasks);

      /// 5️⃣ Final reload
      await _reloadTasks();
    } catch (e) {
      debugPrint("Get All Tasks Error: $e");
      final localTasks = await taskLocalRepository.getTasks(uid);
      if (localTasks.isNotEmpty) {
        emit(GetTasksSuccess(localTasks));
      } else {
        emit(TasksError(e.toString()));
      }
    }
  }

  /// DELETE TASK
  Future<void> deleteTask({
    required String taskId,
    required String token,
  }) async {
    try {
      await taskLocalRepository.deleteTask(taskId);
      await _reloadTasks();
      await taskRemoteRepository.deleteTask(taskId: taskId, token: token);
    } catch (e) {
      debugPrint("Delete Task Error: $e");
    }
  }

  /// UPDATE TASK
  Future<void> updateTask({
    required TaskModel task,
    required String token,
  }) async {
    try {
      final updatedTask = task.copyWith(
        updatedAt: DateTime.now(),
        isSynced: 0,
      );

      await taskLocalRepository.updateTask(updatedTask);
      await _reloadTasks();

      final remoteTask = await taskRemoteRepository.updateTask(
        task: updatedTask,
        token: token,
      );

      await taskLocalRepository.insertTask(remoteTask.copyWith(isSynced: 1));
      await _reloadTasks();
    } catch (e) {
      debugPrint("Update Task Error: $e");
    }
  }

  /// COMPLETE TASK
  Future<void> completeTask(TaskModel task, String token) async {
    try {
      final updatedTask = task.copyWith(
        isCompleted: 1,
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(), // Crucial for merge logic
        isSynced: 0,
      );

      /// 1. Update locally first
      await taskLocalRepository.updateTask(updatedTask);
      await _reloadTasks();

      /// 2. Update backend
      final remoteTask = await taskRemoteRepository.updateTask(
        task: updatedTask,
        token: token,
      );

      /// 3. Update with server confirmed data
      await taskLocalRepository.insertTask(remoteTask.copyWith(isSynced: 1));
      await _reloadTasks();
    } catch (e) {
      debugPrint("Complete Task Error: $e");
    }
  }

  /// SYNC UNSYNCED TASKS
  Future<void> syncTasks(String token) async {
    if (currentUid == null) return;

    try {
      final unsyncedTasks = await taskLocalRepository.getUnsyncedTasks(currentUid!);
      if (unsyncedTasks.isEmpty) return;

      final synced = await taskRemoteRepository.syncTasks(
        token: token,
        tasks: unsyncedTasks,
      );

      if (synced) {
        for (final task in unsyncedTasks) {
          await taskLocalRepository.updateRowValue(task.id, 1);
        }
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }
}
