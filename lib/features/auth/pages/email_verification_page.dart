import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/cubit/auth_cubit.dart';
import 'package:frontend/features/auth/pages/login_page.dart';

class EmailVerificationPage extends StatefulWidget {
  static MaterialPageRoute route(String email) =>
      MaterialPageRoute(builder: (_) => EmailVerificationPage(email: email));

  final String email;
  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final otpController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Email")),
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
          if (state is AuthOtpSent) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("OTP sent to your email.")),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "We sent an OTP to",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: "Enter 6-digit OTP"),
                    validator: (value) {
                      if (value == null || value.trim().length != 6) {
                        return "Enter valid OTP";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              if (formKey.currentState!.validate()) {
                                context.read<AuthCubit>().verifyEmailOtp(
                                      email: widget.email,
                                      otp: otpController.text.trim(),
                                    );
                              }
                            },
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("VERIFY"),
                    ),
                  ),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            context
                                .read<AuthCubit>()
                                .resendVerificationOtp(email: widget.email);
                          },
                    child: const Text("Resend OTP"),
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
