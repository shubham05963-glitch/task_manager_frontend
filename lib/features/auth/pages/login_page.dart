import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/cubit/auth_cubit.dart';
import 'package:frontend/features/auth/pages/email_verification_page.dart';
import 'package:frontend/features/auth/pages/reset_password_page.dart';
import 'package:frontend/features/auth/pages/signup_page.dart';
import 'package:frontend/features/home/pages/home_page.dart';

class LoginPage extends StatefulWidget {
  static MaterialPageRoute route() =>
      MaterialPageRoute(builder: (_) => const LoginPage());

  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool isPasswordVisible = false;
  bool forgotLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void loginUser() {
    if (formKey.currentState!.validate()) {
      context.read<AuthCubit>().login(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );
    }
  }

  void openForgotPasswordDialog() {
    final forgotEmailController = TextEditingController(text: emailController.text.trim());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Forgot Password"),
        content: TextField(
          controller: forgotEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: "Enter your email"),
        ),
        actions: [
          TextButton(
            onPressed: forgotLoading ? null : () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: forgotLoading
                ? null
                : () {
                    final email = forgotEmailController.text.trim();
                    if (email.isEmpty || !email.contains("@")) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Enter a valid email")),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    context.read<AuthCubit>().forgotPassword(email: email);
                  },
            child: const Text("Send OTP"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error)),
              );
            }

            if (state is AuthLoggedIn) {
              Navigator.pushAndRemoveUntil(
                context,
                HomePage.route(),
                (_) => false,
              );
            }
            if (state is AuthOtpSent && state.isResetPassword) {
              Navigator.push(context, ResetPasswordPage.route(state.email));
            }
            if (state is AuthOtpSent && !state.isResetPassword) {
              Navigator.push(context, EmailVerificationPage.route(state.email));
            }
            if (state is AuthError &&
                state.error.toLowerCase().contains("not verified") &&
                emailController.text.trim().contains("@")) {
              context
                  .read<AuthCubit>()
                  .resendVerificationOtp(email: emailController.text.trim());
            }
          },
          builder: (context, state) {
            forgotLoading = state is AuthLoading;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 40,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      /// TITLE
                      Text(
                        "Login",
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "Welcome back!",
                        style: theme.textTheme.bodyMedium,
                      ),

                      const SizedBox(height: 40),

                      /// EMAIL FIELD
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          hintText: "Email",
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty ||
                              !value.contains("@")) {
                            return "Enter a valid email";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      /// PASSWORD FIELD
                      TextFormField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        decoration: InputDecoration(
                          hintText: "Password",
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty ||
                              value.trim().length < 6) {
                            return "Password must be at least 6 characters";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 30),

                      /// LOGIN BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: state is AuthLoading ? null : loginUser,
                          child: state is AuthLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "LOGIN",
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: state is AuthLoading ? null : openForgotPasswordDialog,
                          child: const Text("Forgot Password?"),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// SIGNUP LINK
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            SignupPage.route(),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            text: "Don't have an account? ",
                            style: theme.textTheme.bodyMedium,
                            children: const [
                              TextSpan(
                                text: "Sign Up",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
