import 'dart:io';
import 'package:flutter/foundation.dart';
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
          debugPrint("Notification tapped with payload: ${response.payload}");
        },
      );

      _isInitialized = true;
      debugPrint("Notification Service Initialized Successfully");

      // Request Permissions
      await requestPermissions();
      
      // Setup Notification Channel
      if (Platform.isAndroid) {
        final androidPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
          'task_reminders',
          'Task Reminders',
          description: 'Notifications for task reminders and deadlines',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        ));
      }
    } catch (e) {
      debugPrint("Notification Service Init Error: $e");
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      // 1. Notification Permission (Android 13+)
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      // 2. Exact Alarm Permission (Android 12+)
      // This is absolutely required for scheduled notifications to work accurately
      if (await Permission.scheduleExactAlarm.isDenied) {
        debugPrint("Requesting Exact Alarm Permission...");
        await Permission.scheduleExactAlarm.request();
      }
      
      // Also request via plugin implementation for Android 12+
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  int _getNotificationId(String taskId, int offset) {
    // Generate a unique positive 31-bit integer for Android
    return (taskId.hashCode.abs() + offset) & 0x7FFFFFFF;
  }

  Future<void> scheduleTaskNotifications(TaskModel task) async {
    if (!_isInitialized) await init();

    try {
      // Clear any existing notifications for this task first
      await cancelTaskNotifications(task.id);

      // Don't schedule for completed tasks
      if (task.isCompleted == 1) return;

      final now = tz.TZDateTime.now(tz.local);
      final dueAt = tz.TZDateTime.from(task.dueAt, tz.local);

      // Use a 5-second buffer to ensure we don't schedule in the very immediate past
      final buffer = const Duration(seconds: 5);

      // 1. 12 Hours Before
      final twelveHoursBefore = dueAt.subtract(const Duration(hours: 12));
      if (twelveHoursBefore.isAfter(now.add(buffer))) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 1),
          title: 'Upcoming Task: 12h left',
          body: 'Don\'t forget: "${task.title}" is due in 12 hours.',
          scheduledDate: twelveHoursBefore,
        );
      }

      // 2. Exactly at Due Time
      if (dueAt.isAfter(now.add(buffer))) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 2),
          title: 'Task Due Now!',
          body: 'Your task "${task.title}" is due right now.',
          scheduledDate: dueAt,
        );
      }

      // 3. 1 Hour Overdue
      final oneHourAfter = dueAt.add(const Duration(hours: 1));
      if (oneHourAfter.isAfter(now.add(buffer))) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 3),
          title: 'Task Overdue',
          body: 'The task "${task.title}" was due 1 hour ago. Please complete it.',
          scheduledDate: oneHourAfter,
        );
      }
      
      debugPrint("Notifications successfully scheduled for task: ${task.title}");
    } catch (e) {
      debugPrint("Error scheduling task notifications: $e");
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
            'task_reminders',
            'Task Reminders',
            channelDescription: 'Notifications for task reminders and deadlines',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint("zonedSchedule Failure (ID: $id): $e");
    }
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(_getNotificationId(taskId, 1));
      await flutterLocalNotificationsPlugin.cancel(_getNotificationId(taskId, 2));
      await flutterLocalNotificationsPlugin.cancel(_getNotificationId(taskId, 3));
    } catch (e) {
      debugPrint("Error cancelling notifications for task $taskId: $e");
    }
  }

  Future<void> showTestNotification() async {
    if (!_isInitialized) await init();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await flutterLocalNotificationsPlugin.show(
      0,
      'Notification Test',
      'Success! If you see this, notifications are working.',
      details,
    );
  }
}
