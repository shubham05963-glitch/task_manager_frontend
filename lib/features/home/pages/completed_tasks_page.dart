import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/cubit/auth_cubit.dart';
import 'package:frontend/features/home/cubit/tasks_cubit.dart';
import 'package:intl/intl.dart';

class CompletedTasksPage extends StatelessWidget {
  const CompletedTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Completed Tasks"),
        centerTitle: true,
      ),
      body: BlocBuilder<TasksCubit, TasksState>(
        builder: (context, state) {
          /// LOADING
          if (state is TasksLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          /// ERROR
          if (state is TasksError) {
            return Center(
              child: Text(state.error),
            );
          }

          /// SUCCESS
          if (state is GetTasksSuccess) {
            final completedTasks =
                state.tasks.where((task) => task.isCompleted == 1).toList();

            /// EMPTY STATE
            if (completedTasks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.check_circle_outline,
                      size: 70,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "No Completed Tasks Yet",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    )
                  ],
                ),
              );
            }

            /// TASK LIST
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: completedTasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = completedTasks[index];

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 30,
                    ),
                    title: Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: task.completedAt != null
                        ? Text(
                            "Completed on ${DateFormat('dd MMM yyyy, hh:mm a').format(task.completedAt!)}",
                            style: theme.textTheme.bodySmall,
                          )
                        : const Text("Completed"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        /// Show confirmation dialog before deleting
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Delete Task"),
                            content: const Text(
                                "Are you sure you want to permanently delete this task?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () {
                                  final authState = context.read<AuthCubit>().state;
                                  if (authState is AuthLoggedIn) {
                                    context.read<TasksCubit>().deleteTask(
                                          taskId: task.id,
                                          token: authState.user.token,
                                        );
                                  }
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  "Delete",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}
