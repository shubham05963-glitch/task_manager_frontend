import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/cubit/auth_cubit.dart';
import 'package:frontend/features/auth/pages/login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  static MaterialPageRoute route(String email) =>
      MaterialPageRoute(builder: (_) => ResetPasswordPage(email: email));

  final String email;
  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final otpController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    otpController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.error)));
          }
          if (state is AuthActionSuccess) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
            Navigator.pushAndRemoveUntil(context, LoginPage.route(), (_) => false);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  Text(widget.email, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: "Enter OTP"),
                    validator: (value) =>
                        (value == null || value.trim().length != 6) ? "Enter valid OTP" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: "New Password"),
                    validator: (value) => (value == null || value.trim().length < 6)
                        ? "Password must be at least 6 characters"
                        : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              if (formKey.currentState!.validate()) {
                                context.read<AuthCubit>().resetPassword(
                                      email: widget.email,
                                      otp: otpController.text.trim(),
                                      newPassword: passwordController.text.trim(),
                                    );
                              }
                            },
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("RESET PASSWORD"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
