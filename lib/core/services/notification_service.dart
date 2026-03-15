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
      debugPrint("--- Notification Service: Initialization Started ---");
      
      // 1. Initialize Timezones
      tz_data.initializeTimeZones();
      try {
        final String timeZoneName = await FlutterTimezone.getLocalTimezone();
        debugPrint("Notification Service: Detected Timezone: $timeZoneName");
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        debugPrint("Notification Service: Timezone detection failed, using UTC: $e");
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
      
      // Using @mipmap/ic_launcher as it exists in mipmap folders
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      bool? initialized = await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Notification Service: Notification tapped: ${response.payload}");
        },
      );

      debugPrint("Notification Service: Plugin initialized status: $initialized");
      _isInitialized = true;

      // 2. Request Permissions
      await requestPermissions();
      
      // 3. Create Notification Channel
      if (Platform.isAndroid) {
        final androidPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
          'task_reminders',
          'Task Reminders',
          description: 'High priority notifications for task deadlines',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        ));
        
        debugPrint("Notification Service: Android channel 'task_reminders' created");
      }
      debugPrint("--- Notification Service: Initialization Completed ---");
    } catch (e) {
      debugPrint("Notification Service: CRITICAL INIT ERROR: $e");
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      debugPrint("Notification Service: Requesting permissions...");
      
      // Notification Permission (Android 13+)
      final notificationStatus = await Permission.notification.request();
      debugPrint("Notification Service: Notification Permission Status: $notificationStatus");

      // Exact Alarm Permission (Android 12+)
      // Note: USE_EXACT_ALARM is in manifest, but checking status is good practice
      final alarmStatus = await Permission.scheduleExactAlarm.request();
      debugPrint("Notification Service: Exact Alarm Permission Status: $alarmStatus");

      // Specific plugin-based request for Android 12+
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  int _getNotificationId(String taskId, int offset) {
    // Generate a unique 31-bit positive integer
    return (taskId.hashCode.abs() + offset) & 0x7FFFFFFF;
  }

  Future<void> scheduleTaskNotifications(TaskModel task) async {
    if (!_isInitialized) await init();

    try {
      await cancelTaskNotifications(task.id);

      if (task.isCompleted == 1) return;

      final now = tz.TZDateTime.now(tz.local);
      final dueAt = tz.TZDateTime.from(task.dueAt, tz.local);
      
      debugPrint("Notification Service: Scheduling for '${task.title}' at $dueAt (Now is $now)");

      // 1. 12 Hours Before
      final twelveHoursBefore = dueAt.subtract(const Duration(hours: 12));
      if (twelveHoursBefore.isAfter(now)) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 1),
          title: 'Upcoming Task: 12h left',
          body: 'Reminder: "${task.title}" is due in 12 hours.',
          scheduledDate: twelveHoursBefore,
        );
      }

      // 2. Due Time (The most important one)
      if (dueAt.isAfter(now)) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 2),
          title: 'Task Due Now!',
          body: 'Your task "${task.title}" is due now.',
          scheduledDate: dueAt,
        );
        debugPrint("Notification Service: Scheduled 'Due Time' notification for ID ${_getNotificationId(task.id, 2)}");
      } else {
        debugPrint("Notification Service: SKIPPED 'Due Time' because it's in the past: $dueAt");
      }

      // 3. Overdue (1 Hour After)
      final oneHourAfter = dueAt.add(const Duration(hours: 1));
      if (oneHourAfter.isAfter(now)) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 3),
          title: 'Task Overdue',
          body: 'The task "${task.title}" was due 1 hour ago.',
          scheduledDate: oneHourAfter,
        );
      }
    } catch (e) {
      debugPrint("Notification Service: Scheduling Error for ${task.id}: $e");
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
      debugPrint("Notification Service: zonedSchedule Failure (ID $id): $e");
    }
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(_getNotificationId(taskId, 1));
      await flutterLocalNotificationsPlugin.cancel(_getNotificationId(taskId, 2));
      await flutterLocalNotificationsPlugin.cancel(_getNotificationId(taskId, 3));
    } catch (e) {
      debugPrint("Notification Service: Cancel Error for $taskId: $e");
    }
  }

  Future<void> showInstantNotification(String title, String body) async {
    if (!_isInitialized) await init();
    
    debugPrint("Notification Service: Showing instant notification: $title");
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
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
