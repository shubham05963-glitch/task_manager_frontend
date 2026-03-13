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
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // Wait for getUserData to finish and decide where to go
        if (state is AuthLoggedIn) {
          Navigator.pushReplacement(
            context,
            HomePage.route(),
          );
        } else if (state is AuthInitial || state is AuthError) {
          Navigator.pushReplacement(
            context,
            LoginPage.route(),
          );
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          color: const Color(0xff0F0F0F),
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
      ),
    );
  }
}
