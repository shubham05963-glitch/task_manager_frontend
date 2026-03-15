import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:frontend/models/task_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );

    // Request permission for Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleTaskNotifications(TaskModel task) async {
    // Cancel existing notifications for this task first
    await cancelTaskNotifications(task.id);

    if (task.isCompleted == 1) return;

    final now = DateTime.now();
    final dueAt = task.dueAt;

    // 1. 12 Hours Before Notification
    final twelveHoursBefore = dueAt.subtract(const Duration(hours: 12));
    if (twelveHoursBefore.isAfter(now)) {
      await _scheduleNotification(
        id: task.id.hashCode + 1,
        title: 'Task Reminder: 12h left',
        body: 'You have 12 hours remaining to complete: ${task.title}',
        scheduledDate: twelveHoursBefore,
      );
    }

    // 2. Current Time (Due Time) Notification
    if (dueAt.isAfter(now)) {
      await _scheduleNotification(
        id: task.id.hashCode + 2,
        title: 'Task Due Now',
        body: 'The task "${task.title}" is due now and is still incomplete.',
        scheduledDate: dueAt,
      );
    }

    // 3. 1 Hour After Notification
    final oneHourAfter = dueAt.add(const Duration(hours: 1));
    if (oneHourAfter.isAfter(now)) {
      await _scheduleNotification(
        id: task.id.hashCode + 3,
        title: 'Task Overdue',
        body: 'The task "${task.title}" was due 1 hour ago and is still incomplete.',
        scheduledDate: oneHourAfter,
      );
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_notifications',
          'Task Notifications',
          channelDescription: 'Notifications for task reminders and deadlines',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    final baseId = taskId.hashCode;
    await flutterLocalNotificationsPlugin.cancel(baseId + 1);
    await flutterLocalNotificationsPlugin.cancel(baseId + 2);
    await flutterLocalNotificationsPlugin.cancel(baseId + 3);
  }
}
