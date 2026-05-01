import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/services/fcm_service.dart';
import 'package:frontend/core/services/notification_service.dart';
import 'package:frontend/core/theme/theme_cubit.dart';
import 'package:frontend/features/auth/cubit/auth_cubit.dart';
import 'package:frontend/features/home/cubit/tasks_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("FlutterError: ${details.exceptionAsString()}");
  };

  runZonedGuarded(() {
    runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthCubit()),
          BlocProvider(create: (_) => TasksCubit()),
          BlocProvider(create: (_) => ThemeCubit()),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint("Uncaught zone error: $error");
    debugPrintStack(stackTrace: stack);
  });

  // Keep heavy startup services off the critical render path.
  unawaited(_bootstrapServices());
}

Future<void> _bootstrapServices() async {
  try {
    await Firebase.initializeApp();
    await NotificationService().init();
    await FcmService.instance.init();

    final prefs = await SharedPreferences.getInstance();
    const welcomeShownKey = 'welcome_notification_shown';
    final welcomeShown = prefs.getBool(welcomeShownKey) ?? false;

    if (!welcomeShown) {
      await NotificationService().showInstantNotification(
        "Welcome",
        "Welcome to MyTask app",
      );
      await prefs.setBool(welcomeShownKey, true);
    }
  } catch (e, st) {
    debugPrint("Startup services init error: $e");
    debugPrintStack(stackTrace: st);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp(
          title: 'Task App',
          debugShowCheckedModeBanner: false,

          themeMode: themeMode,

          theme: ThemeData(
            brightness: Brightness.light,
            fontFamily: "Cera Pro",
            useMaterial3: true,

            scaffoldBackgroundColor: Colors.white,

            inputDecorationTheme: InputDecorationTheme(
              contentPadding: const EdgeInsets.all(27),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(width: 3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          darkTheme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: "Cera Pro",
            scaffoldBackgroundColor: const Color(0xff121212),
            useMaterial3: true,
          ),

          home: const SplashPage(),
        );
      },
    );
  }
}
