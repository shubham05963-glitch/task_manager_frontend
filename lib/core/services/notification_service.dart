import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:frontend/models/task_model.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      debugPrint("--- Notification Service: Init Started ---");
      
      // 1. Initialize Timezones
      tz_data.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Notification Service: Tapped - ${response.payload}");
        },
      );

      _isInitialized = true;

      // 2. Request Permissions
      await requestPermissions();
      
      // 3. Create Fresh High-Priority Channel
      if (Platform.isAndroid) {
        final androidPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
          'task_priority_channel_v2',
          'Task Reminders',
          description: 'High priority alerts for your tasks',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        ));
      }
      debugPrint("--- Notification Service: Init Finished ---");
    } catch (e) {
      debugPrint("Notification Service: Init Error: $e");
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      // Notification Permission (Android 13+)
      await Permission.notification.request();

      // Exact Alarm Permission (Android 12+)
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }

      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  int _getNotificationId(String taskId, int offset) {
    return (taskId.hashCode.abs() + offset) & 0x7FFFFFFF;
  }

  Future<void> scheduleTaskNotifications(TaskModel task) async {
    if (!_isInitialized) await init();

    try {
      await cancelTaskNotifications(task.id);

      if (task.isCompleted == 1) return;

      final now = tz.TZDateTime.now(tz.local);
      final dueAt = tz.TZDateTime.from(task.dueAt, tz.local);
      
      // Schedule only if the due time is at least 5 seconds in the future
      if (dueAt.isAfter(now.add(const Duration(seconds: 5)))) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 100),
          title: 'Task Due Now!',
          body: 'Your task "${task.title}" is due now.',
          scheduledDate: dueAt,
        );
        debugPrint("Notification Service: Scheduled '${task.title}' for $dueAt");
      }
    } catch (e) {
      debugPrint("Notification Service: Scheduling Error: $e");
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_priority_channel_v2',
            'Task Reminders',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint("Notification Service: zonedSchedule Failure: $e");
    }
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(_getNotificationId(taskId, 100));
    } catch (e) {
      debugPrint("Notification Service: Cancel Error: $e");
    }
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Use this for a quick test
  Future<void> showInstantNotification(String title, String body) async {
    if (!_isInitialized) await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_priority_channel_v2',
      'Task Reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }
}
