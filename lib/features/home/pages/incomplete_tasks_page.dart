import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/cubit/auth_cubit.dart';
import 'package:frontend/features/home/cubit/tasks_cubit.dart';
import 'package:intl/intl.dart';

class IncompleteTasksPage extends StatelessWidget {
  const IncompleteTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Incomplete Tasks"),
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
            final incompleteTasks =
                state.tasks.where((task) => task.isCompleted == 0).toList();

            /// EMPTY STATE
            if (incompleteTasks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.task_alt_outlined,
                      size: 70,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "No Pending Tasks",
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
              itemCount: incompleteTasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = incompleteTasks[index];

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.pending_actions,
                      color: Colors.orange,
                      size: 30,
                    ),
                    title: Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      "Due ${DateFormat('dd MMM yyyy, hh:mm a').format(task.dueAt)}",
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                      onPressed: () {
                        final authState = context.read<AuthCubit>().state;
                        if (authState is AuthLoggedIn) {
                          context.read<TasksCubit>().completeTask(
                                task,
                                authState.user.token,
                              );
                        }
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
