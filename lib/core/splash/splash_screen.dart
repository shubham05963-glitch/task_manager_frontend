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
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authCubit = context.read<AuthCubit>();
      final currentState = authCubit.state;

      // If state is already resolved, navigate immediately.
      if (currentState is AuthLoggedIn || currentState is AuthError) {
        _navigateToNext(currentState);
        return;
      }

      authCubit.getUserData();
    });
  }

  void _navigateToNext(AuthState authState) {
    if (!mounted || _navigated) return;
    _navigated = true;

    if (authState is AuthLoggedIn || (authState is AuthError && authState.user != null)) {
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
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) return;
        _navigateToNext(state);
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          color: const Color(0xff000000),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Image.asset(
                'assets/icon/logo.png',
                width: 140,
              ),
              const SizedBox(height: 20),
              const Text(
                'MyTask',
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
                  'Build with love by Anibesh & Shubham',
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
