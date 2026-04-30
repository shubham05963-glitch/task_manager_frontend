import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/services/notification_service.dart';
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
  int _selectedIndex = 0;
  DateTime selectedDate = DateTime.now();
  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
  bool isSyncing = false;
  bool hasLoaded = false;

  final List<Widget> _pages = [
    const HomeContent(),
    const CompletedTasksPage(),
    const IncompleteTasksPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthCubit>().state;

    if (authState is AuthLoggedIn) {
      final token = authState.user.token;
      final uid = authState.user.id;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!hasLoaded) {
          context.read<TasksCubit>().getAllTasks(token: token, uid: uid);
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
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: 'Completed'),
            BottomNavigationBarItem(icon: Icon(Icons.pending_actions), label: 'Pending'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  DateTime selectedDate = DateTime.now();

  bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "My Tasks",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: "Test Notification",
            icon: const Icon(Icons.notifications_active),
            onPressed: () async {
              await NotificationService().showInstantNotification(
                "Test Notification",
                "If you see this in system tray, notifications are working.",
              );
            },
          ),
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              final isDark = themeMode == ThemeMode.dark;
              return IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => context.read<ThemeCubit>().toggleTheme(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(context, AddNewTaskPage.route()),
      ),
      body: Column(
        children: [
          DateSelector(
            selectedDate: selectedDate,
            onTap: (date) => setState(() => selectedDate = date),
          ),
          Expanded(
            child: BlocBuilder<TasksCubit, TasksState>(
              builder: (context, state) {
                if (state is TasksLoading) return const Center(child: CircularProgressIndicator());
                if (state is TasksError) return Center(child: Text(state.error));

                if (state is GetTasksSuccess) {
                  final filteredTasks = state.tasks
                      .where((task) => isSameDate(task.dueAt, selectedDate))
                      .toList();
                  filteredTasks.sort((a, b) => a.isCompleted.compareTo(b.isCompleted));

                  if (filteredTasks.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.task_alt, size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("No Tasks For This Day", style: TextStyle(fontSize: 18, color: Colors.grey)),
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
                      return Padding(
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
                            Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (context) {
                                          return Wrap(
                                            children: [
                                              if (task.isCompleted == 0)
                                                ListTile(
                                                  leading: const Icon(Icons.check, color: Colors.green),
                                                  title: const Text('Complete Task'),
                                                  onTap: () {
                                                    final auth = context.read<AuthCubit>().state as AuthLoggedIn;
                                                    context.read<TasksCubit>().completeTask(task, auth.user.token);
                                                    Navigator.pop(context);
                                                  },
                                                ),
                                              ListTile(
                                                leading: const Icon(Icons.delete, color: Colors.red),
                                                title: const Text('Delete Task'),
                                                onTap: () async {
                                                  final auth = context.read<AuthCubit>().state as AuthLoggedIn;
                                                  await context.read<TasksCubit>().deleteTask(
                                                    taskId: task.id,
                                                    token: auth.user.token,
                                                  );
                                                  Navigator.pop(context);
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                Text(
                                  DateFormat.jm().format(task.dueAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    decoration: task.isCompleted == 1 ? TextDecoration.lineThrough : null,
                                    color: task.isCompleted == 1 ? Colors.grey : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    );
  }
}
