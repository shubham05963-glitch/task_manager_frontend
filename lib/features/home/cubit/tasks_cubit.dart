import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/services/notification_service.dart';
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
  final notificationService = NotificationService();

  String? currentUid;

  Future<void> _reloadTasks() async {
    if (currentUid == null) return;
    final tasks = await taskLocalRepository.getTasks(currentUid!);
    emit(GetTasksSuccess(tasks));
  }

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

      await taskLocalRepository.insertTask(taskModel);
      await notificationService.scheduleTaskNotifications(taskModel);
      await _reloadTasks();

      final remoteTask = await taskRemoteRepository.createTask(
        id: taskId,
        uid: uid,
        title: title,
        description: description,
        hexColor: rgbToHex(color),
        token: token,
        dueAt: dueAt,
      );

      if (remoteTask.id != taskId) {
        await notificationService.cancelTaskNotifications(taskId);
        await taskLocalRepository.deleteTask(taskId);
      }

      final finalTask = remoteTask.copyWith(isSynced: 1);
      await taskLocalRepository.insertTask(finalTask);
      await notificationService.scheduleTaskNotifications(finalTask);
      await _reloadTasks();
    } catch (e) {
      debugPrint("Create Task Error: $e");
    }
  }

  Future<void> getAllTasks({
    required String token,
    required String uid,
  }) async {
    currentUid = uid;

    try {
      // 1) show local immediately
      final localTasks = await taskLocalRepository.getTasks(uid);
      if (localTasks.isNotEmpty) {
        emit(GetTasksSuccess(localTasks));
      }

      // 2) sync unsynced local edits
      await syncTasks(token);

      // 3) fetch latest remote
      final remoteTasks = await taskRemoteRepository.getTasks(
        token: token,
        uid: uid,
      );

      // 4) merge remote into local store
      await taskLocalRepository.insertTasks(remoteTasks);

      // 5) final read and rebuild reminder schedule from current task state.
      // This clears stale alarms from older app versions/timezone handling.
      await notificationService.cancelAllNotifications();

      final updatedTasks = await taskLocalRepository.getTasks(uid);
      for (final task in updatedTasks) {
        await notificationService.scheduleTaskNotifications(task);
      }

      emit(GetTasksSuccess(updatedTasks));
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

  Future<void> deleteTask({
    required String taskId,
    required String token,
  }) async {
    try {
      await notificationService.cancelTaskNotifications(taskId);
      await taskLocalRepository.deleteTask(taskId);
      await _reloadTasks();
      await taskRemoteRepository.deleteTask(taskId: taskId, token: token);
    } catch (e) {
      debugPrint("Delete Task Error: $e");
    }
  }

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
      await notificationService.scheduleTaskNotifications(updatedTask);
      await _reloadTasks();

      final remoteTask = await taskRemoteRepository.updateTask(
        task: updatedTask,
        token: token,
      );

      final finalTask = remoteTask.copyWith(isSynced: 1);
      await taskLocalRepository.insertTask(finalTask);
      await notificationService.scheduleTaskNotifications(finalTask);
      await _reloadTasks();
    } catch (e) {
      debugPrint("Update Task Error: $e");
    }
  }

  Future<void> completeTask(TaskModel task, String token) async {
    try {
      final updatedTask = task.copyWith(
        isCompleted: 1,
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: 0,
      );

      await taskLocalRepository.updateTask(updatedTask);
      await notificationService.cancelTaskNotifications(task.id);
      await _reloadTasks();

      final remoteTask = await taskRemoteRepository.updateTask(
        task: updatedTask,
        token: token,
      );

      await taskLocalRepository.insertTask(remoteTask.copyWith(isSynced: 1));
      await _reloadTasks();
    } catch (e) {
      debugPrint("Complete Task Error: $e");
    }
  }

  Future<void> syncTasks(String token) async {
    if (currentUid == null) return;

    try {
      final unsyncedTasks = await taskLocalRepository.getUnsyncedTasks(
        currentUid!,
      );
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
