import 'package:flutter/material.dart';

class AppTheme {

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xffF5F5F5),
    primaryColor: Colors.orange,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
    ),
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xff121212),
    primaryColor: Colors.orange,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xff1E1E1E),
      foregroundColor: Colors.white,
    ),
  );
}