import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:frontend/core/constants/utils.dart';
import 'package:frontend/core/theme/theme_cubit.dart';

import 'package:frontend/features/auth/cubit/auth_cubit.dart';
import 'package:frontend/features/auth/pages/login_page.dart';
import 'package:frontend/features/home/cubit/tasks_cubit.dart';
import 'package:frontend/features/home/pages/add_new_task_page.dart';
import 'package:frontend/features/home/pages/completed_tasks_page.dart';
import 'package:frontend/features/home/pages/incomplete_tasks_page.dart';
import 'package:frontend/features/profile/pages/profile_page.dart';
import 'package:frontend/features/home/widgets/date_selector.dart';
import 'package:frontend/features/home/widgets/task_card.dart';

import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  static MaterialPageRoute route() =>
      MaterialPageRoute(builder: (_) => const HomePage());

  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime selectedDate = DateTime.now();

  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;

  bool isSyncing = false;
  bool hasLoaded = false;

  @override
  void initState() {
    super.initState();

    final authState = context.read<AuthCubit>().state;

    if (authState is AuthLoggedIn) {
      final token = authState.user.token;
      final uid = authState.user.id;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!hasLoaded) {
          context.read<TasksCubit>().getAllTasks(
                token: token,
                uid: uid,
              );

          context.read<TasksCubit>().syncTasks(token);

          hasLoaded = true;
        }
      });

      connectivitySubscription =
          Connectivity().onConnectivityChanged.listen((results) async {
        if (results.contains(ConnectivityResult.mobile) ||
            results.contains(ConnectivityResult.wifi)) {
          if (!isSyncing) {
            isSyncing = true;

            await context.read<TasksCubit>().syncTasks(token);

            isSyncing = false;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    connectivitySubscription?.cancel();
    super.dispose();
  }

  bool isSameDate(DateTime a, DateTime b) {
    final aDate = DateTime(a.year, a.month, a.day);
    final bDate = DateTime(b.year, b.month, b.day);
    return aDate == bDate;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial) {
          Navigator.pushAndRemoveUntil(
            context,
            LoginPage.route(),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        /// DRAWER
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 35, color: Colors.black),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Task Manager",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text("Profile"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text("Completed Tasks"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CompletedTasksPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.pending_actions),
                title: const Text("Incomplete Tasks"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const IncompleteTasksPage(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Sign Out"),
                onTap: () {
                  context.read<AuthCubit>().logout();
                },
              ),
            ],
          ),
        ),

        /// APP BAR
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "My Tasks",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          actions: [
            /// DARK MODE BUTTON
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, themeMode) {
                final isDark = themeMode == ThemeMode.dark;

                return IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                  ),
                  onPressed: () {
                    context.read<ThemeCubit>().toggleTheme();
                  },
                );
              },
            ),
          ],
        ),

        /// ADD TASK BUTTON
        floatingActionButton: FloatingActionButton(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            Navigator.push(context, AddNewTaskPage.route());
          },
        ),

        /// BODY
        body: Column(
          children: [
            /// DATE SELECTOR
            DateSelector(
              selectedDate: selectedDate,
              onTap: (date) {
                setState(() {
                  selectedDate = date;
                });
              },
            ),

            /// TASK LIST
            Expanded(
              child: BlocBuilder<TasksCubit, TasksState>(
                builder: (context, state) {
                  if (state is TasksLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (state is TasksError) {
                    return Center(child: Text(state.error));
                  }

                  if (state is GetTasksSuccess) {
                    final filteredTasks = state.tasks
                        .where((task) => isSameDate(task.dueAt, selectedDate))
                        .toList();

                    // SORT: Incomplete tasks first, then completed at the bottom
                    filteredTasks.sort((a, b) => a.isCompleted.compareTo(b.isCompleted));

                    if (filteredTasks.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt, size: 60, color: Colors.grey),
                            SizedBox(height: 10),
                            Text(
                              "No Tasks For This Day",
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: filteredTasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];

                        return Slidable(
                          key: ValueKey(task.id),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            children: [
                              if (task.isCompleted == 0)
                                SlidableAction(
                                  onPressed: (_) {
                                    final auth = context.read<AuthCubit>().state as AuthLoggedIn;
                                    context.read<TasksCubit>().completeTask(task, auth.user.token);
                                  },
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  icon: Icons.check,
                                  label: 'Complete',
                                ),
                              SlidableAction(
                                onPressed: (_) async {
                                  final auth = context.read<AuthCubit>().state
                                      as AuthLoggedIn;

                                  await context.read<TasksCubit>().deleteTask(
                                        taskId: task.id,
                                        token: auth.user.token,
                                      );
                                },
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                                label: 'Delete',
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TaskCard(
                                    color: task.color,
                                    headerText: task.title,
                                    descriptionText: task.description,
                                    isCompleted: task.isCompleted == 1,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  children: [
                                    Container(
                                      height: 12,
                                      width: 12,
                                      decoration: BoxDecoration(
                                        color: task.isCompleted == 1 ? Colors.grey : strengthenColor(task.color, 0.69),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Container(
                                      height: 40,
                                      width: 2,
                                      color: Colors.grey.shade300,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    DateFormat.jm().format(task.dueAt),
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        decoration: task.isCompleted == 1 ? TextDecoration.lineThrough : null,
                                        color: task.isCompleted == 1 ? Colors.grey : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }

                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
