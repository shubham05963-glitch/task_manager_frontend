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
      debugPrint("Initializing Notification Service...");
      
      // 1. Initialize Timezones
      tz_data.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      debugPrint("Detected Timezone: $timeZoneName");
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('ic_launcher'); // Removed @mipmap/ to see if it helps

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
        
        debugPrint("Notification Channel 'task_reminders' created");
      }
    } catch (e) {
      debugPrint("Notification Service Init Error: $e");
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      debugPrint("Requesting permissions...");
      
      // 1. Notification Permission (Android 13+)
      final notificationStatus = await Permission.notification.request();
      debugPrint("Notification Permission: $notificationStatus");

      // 2. Exact Alarm Permission (Android 12+)
      final alarmStatus = await Permission.scheduleExactAlarm.request();
      debugPrint("Exact Alarm Permission: $alarmStatus");
      
      // If denied, open settings (optional but helpful for the user)
      if (alarmStatus.isDenied || alarmStatus.isPermanentlyDenied) {
        debugPrint("Exact Alarm permission denied. Some features may not work.");
      }
    }
  }

  int _getNotificationId(String taskId, int offset) {
    return (taskId.hashCode.abs() + offset) & 0x7FFFFFFF;
  }

  Future<void> scheduleTaskNotifications(TaskModel task) async {
    if (!_isInitialized) {
      debugPrint("Service not initialized, initializing now...");
      await init();
    }

    try {
      await cancelTaskNotifications(task.id);

      if (task.isCompleted == 1) {
        debugPrint("Task is completed, skipping notifications.");
        return;
      }

      final now = tz.TZDateTime.now(tz.local);
      final dueAt = tz.TZDateTime.from(task.dueAt, tz.local);
      
      debugPrint("Scheduling notifications for task: ${task.title}");
      debugPrint("Current Time (TZ): $now");
      debugPrint("Due Time (TZ): $dueAt");

      bool scheduledAtLeastOne = false;

      // 1. 12 Hours Before
      final twelveHoursBefore = dueAt.subtract(const Duration(hours: 12));
      if (twelveHoursBefore.isAfter(now)) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 1),
          title: 'Upcoming Task: 12h left',
          body: 'Don\'t forget: "${task.title}" is due in 12 hours.',
          scheduledDate: twelveHoursBefore,
        );
        scheduledAtLeastOne = true;
      }

      // 2. Exactly at Due Time
      if (dueAt.isAfter(now)) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 2),
          title: 'Task Due Now!',
          body: 'Your task "${task.title}" is due right now.',
          scheduledDate: dueAt,
        );
        scheduledAtLeastOne = true;
      }

      // 3. 1 Hour Overdue
      final oneHourAfter = dueAt.add(const Duration(hours: 1));
      if (oneHourAfter.isAfter(now)) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 3),
          title: 'Task Overdue',
          body: 'The task "${task.title}" was due 1 hour ago. Please complete it.',
          scheduledDate: oneHourAfter,
        );
        scheduledAtLeastOne = true;
      }
      
      if (scheduledAtLeastOne) {
        debugPrint("Notifications scheduled successfully for ${task.title}");
      } else {
        debugPrint("No future notifications to schedule for ${task.title} (Time might have already passed)");
      }
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
      debugPrint("Zoned Schedule for ID $id at $scheduledDate");
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

  Future<void> showInstantNotification(String title, String body) async {
    if (!_isInitialized) await init();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminders',
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
