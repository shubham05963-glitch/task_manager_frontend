import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.light) {
    loadTheme();
  }

  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();

    if (state == ThemeMode.dark) {
      emit(ThemeMode.light);
      prefs.setBool("darkMode", false);
    } else {
      emit(ThemeMode.dark);
      prefs.setBool("darkMode", true);
    }
  }

  void loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    bool isDark = prefs.getBool("darkMode") ?? false;

    if (isDark) {
      emit(ThemeMode.dark);
    } else {
      emit(ThemeMode.light);
    }
  }
}