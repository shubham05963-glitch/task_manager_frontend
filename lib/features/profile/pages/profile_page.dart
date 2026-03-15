import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/features/auth/cubit/auth_cubit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/constants/constants.dart';
import 'package:frontend/models/user_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      if (!mounted) return;
      context.read<AuthCubit>().updateProfilePic(File(pickedImage.path));
    }
  }

  void _showUserManual() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      "User Manual",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "1. Creating Tasks",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text("Tap the '+' button on the home screen to add a new task. You can set a title, description, color, and due date."),
                  SizedBox(height: 15),
                  Text(
                    "2. Managing Tasks",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text("Click on 3 dot to delete it. Tap a task to edit its details."),
                  SizedBox(height: 15),
                  Text(
                    "3. Completing Tasks",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text("Check the box next to a task to mark it as completed. Completed tasks move to the 'Completed' tab."),
                  SizedBox(height: 15),
                  Text(
                    "4. Profile & Sync",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text("Your tasks are automatically synced with the cloud when you have an internet connection. You can update your profile picture in the Profile tab."),
                  SizedBox(height: 15),
                  Text(
                    "5. Offline Support",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text("You can create, edit, and complete tasks even without internet. They will sync automatically once you're back online."),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Query regarding Task App',
    );
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch email client';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e. Please email manually to $email")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error)),
          );
        }
      },
      builder: (context, state) {
        UserModel? user;
        if (state is AuthLoggedIn) {
          user = state.user;
        } else if (state is AuthLoading) {
          user = state.user;
        }

        String name = user?.name ?? "";
        String email = user?.email ?? "";
        String? profilePic = user?.profilePic;
        bool isLoading = state is AuthLoading;

        if (profilePic != null && profilePic.isNotEmpty && !profilePic.startsWith('http')) {
          profilePic = '${Constants.backendUri}/$profilePic';
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Profile"),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: () {
                  context.read<AuthCubit>().logout();
                },
                icon: const Icon(Icons.logout, color: Colors.red),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: isLoading ? null : pickImage,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: (profilePic != null && profilePic.isNotEmpty)
                              ? NetworkImage(profilePic)
                              : null,
                          child: (profilePic == null || profilePic.isEmpty)
                              ? (isLoading
                                  ? const CircularProgressIndicator()
                                  : const Icon(Icons.person, size: 60, color: Colors.grey))
                              : (isLoading
                                  ? Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black26,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(color: Colors.white),
                                      ),
                                    )
                                  : null),
                        ),
                      ),
                      if (profilePic != null && profilePic.isNotEmpty && !isLoading)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () {
                              context.read<AuthCubit>().deleteProfilePic();
                            },
                            child: const CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.delete, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Tap image to change",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Name",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 30),
                      const Text(
                        "Email Address",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text("User Manual"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showUserManual,
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Support & Queries",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text("shubham singh"),
                  subtitle: const Text("singhshubham29392@gmail.com"),
                  onTap: () => _sendEmail("singhshubham29392@gmail.com"),
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text("Anibesh Singh"),
                  subtitle: const Text("anibeshsingh2@gmail.com"),
                  onTap: () => _sendEmail("anibeshsingh2@gmail.com"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
