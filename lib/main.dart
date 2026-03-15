import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/services/notification_service.dart';
import 'package:frontend/core/theme/theme_cubit.dart';
import 'package:frontend/features/auth/cubit/auth_cubit.dart';
import 'package:frontend/features/home/cubit/tasks_cubit.dart';


import 'core/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  
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
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    context.read<AuthCubit>().getUserData();
  }

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
