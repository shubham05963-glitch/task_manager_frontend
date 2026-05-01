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
  bool _canUseExactAlarms = true;
  static const String _channelId = 'task_priority_channel_v3';
  static const String _channelName = 'Task Reminders';

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      debugPrint("--- Notification Service: Init Started ---");
      
      // 1. Initialize Timezones
      tz_data.initializeTimeZones();
      final String rawTimeZoneName = await FlutterTimezone.getLocalTimezone();
      // Force all task reminder scheduling to Indian Standard Time.
      const String timeZoneName = "Asia/Kolkata";
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        debugPrint(
          "Notification Service: Unknown timezone '$rawTimeZoneName', fallback to UTC",
        );
        tz.setLocalLocation(tz.UTC);
      }
      
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

      // 2. Request Permissions
      await requestPermissions();
      
      // 3. Create Fresh High-Priority Channel
      if (Platform.isAndroid) {
        final androidPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'High priority alerts for your tasks',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        ));
      }
      _isInitialized = true;
      debugPrint("--- Notification Service: Init Finished ---");
    } catch (e) {
      debugPrint("Notification Service: Init Error: $e");
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      // 1) Notifications: Allow
      final notificationStatus = await Permission.notification.request();
      if (!notificationStatus.isGranted) {
        debugPrint(
          "Notification permission denied. Please enable: Notifications -> Allow",
        );
        await openAppSettings();
      }

      // 2) Exact alarms: Allow
      final exactAlarmStatus = await Permission.scheduleExactAlarm.request();
      if (!exactAlarmStatus.isGranted) {
        debugPrint(
          "Exact alarm permission denied. Please enable: Exact alarms -> Allow",
        );
        await openAppSettings();
      }

      // 3) Battery optimization exemption (important on many OEM phones
      // to allow alarms/notifications when app is closed).
      final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
      if (!batteryStatus.isGranted) {
        debugPrint(
          "Battery optimization is enabled. For reliable kill-state notifications, disable battery optimization for this app.",
        );
        await openAppSettings();
      }

      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();

      try {
        _canUseExactAlarms =
            await androidPlugin?.canScheduleExactNotifications() ?? false;
      } catch (_) {
        _canUseExactAlarms = false;
      }

      debugPrint(
        "Notification permissions -> notification: ${notificationStatus.isGranted}, exactAlarm: ${exactAlarmStatus.isGranted}, batteryOptimizationIgnored: ${batteryStatus.isGranted}, canUseExactAlarms: $_canUseExactAlarms",
      );
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
      final before12h = dueAt.subtract(const Duration(hours: 12));
      final after1h = dueAt.add(const Duration(hours: 1));

      // 1) 12 hours before deadline
      if (before12h.isAfter(now)) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 90),
          title: 'Task Reminder',
          body: 'Your task "${task.title}" is due in 12 hours.',
          scheduledDate: before12h,
        );
      }

      // 2) Exactly at deadline
      if (dueAt.isAfter(now)) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 100),
          title: 'Task Due Now!',
          body: 'Your task "${task.title}" is due now.',
          scheduledDate: dueAt,
        );
      } else if (now.difference(dueAt) <= const Duration(minutes: 2)) {
        // Catch-up path: if app sync happens slightly after deadline,
        // still notify immediately so due alert is not missed.
        await showInstantNotification(
          'Task Due Now!',
          'Your task "${task.title}" is due now.',
        );
      }

      // 3) 1 hour after deadline (for still-incomplete tasks)
      // Completion flow cancels this reminder when task is marked complete.
      if (after1h.isAfter(now)) {
        await _scheduleNotification(
          id: _getNotificationId(task.id, 110),
          title: 'Task Pending',
          body: 'Your task "${task.title}" is still incomplete (1 hour overdue).',
          scheduledDate: after1h,
        );
      }

      debugPrint("Notification Service: Scheduled reminders for '${task.title}'");
      await _logPendingCount();
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
            _channelId,
            _channelName,
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            autoCancel: true,
            visibility: NotificationVisibility.public,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        androidScheduleMode: _canUseExactAlarms
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
        "Notification Service: Scheduled id=$id mode=${_canUseExactAlarms ? "exact" : "inexact"} at $scheduledDate",
      );
    } catch (e) {
      debugPrint("Notification Service: zonedSchedule Failure (exact/inexact): $e");
    }
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(_getNotificationId(taskId, 90));
      await flutterLocalNotificationsPlugin.cancel(_getNotificationId(taskId, 100));
      await flutterLocalNotificationsPlugin.cancel(_getNotificationId(taskId, 110));
    } catch (e) {
      debugPrint("Notification Service: Cancel Error: $e");
    }
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> _logPendingCount() async {
    try {
      final pending =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      debugPrint("Notification Service: Pending notifications = ${pending.length}");
    } catch (e) {
      debugPrint("Notification Service: Pending read error: $e");
    }
  }

  // Use this for a quick test
  Future<void> showInstantNotification(String title, String body) async {
    if (!_isInitialized) await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      autoCancel: true,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
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
