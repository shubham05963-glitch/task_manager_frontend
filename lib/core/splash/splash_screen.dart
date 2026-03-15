import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/cubit/auth_cubit.dart';
import 'package:frontend/features/auth/pages/login_page.dart';
import 'package:frontend/features/home/pages/home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _startSplashTimer();
  }

  void _startSplashTimer() {
    Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _navigateToNext();
    });
  }

  void _navigateToNext() {
    final authState = context.read<AuthCubit>().state;

    if (authState is AuthLoggedIn) {
      Navigator.pushReplacement(
        context,
        HomePage.route(),
      );
    } else {
      Navigator.pushReplacement(
        context,
        LoginPage.route(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        color: const Color(0xff000000),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Image.asset(
              "assets/icon/logo.png",
              width: 140,
            ),
            const SizedBox(height: 20),
            const Text(
              "MyTask",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Text(
                "Build with ❤️ by Anibesh & Shubham",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
