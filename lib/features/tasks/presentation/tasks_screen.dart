import 'package:flutter/material.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.viewModel});
  final TasksViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => viewModel.addTask(Task.blank()),
      ),
      body: StreamBuilder<TaskScreenState>(
        stream: viewModel.state,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          }
          return snapshot.data!.when(
            loading: () => Center(child: CircularProgressIndicator()),
            empty: (_, __) => Text("empty"),
            error: (e) => Text(e),
            loaded: (tasks, _, curTask) {
              if (tasks.isEmpty) {
                return const Center(
                  child: Text(
                    'No tasks available yet.',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(task.title),
                    subtitle: Text(task.description),
                    trailing: Icon(
                      task.isCompleted
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: task.isCompleted ? Colors.green : Colors.grey,
                    ),
                    onTap: () async {
                      await viewModel.toggleTask(task);
                    },
                    onLongPress: () async {
                      await viewModel.deleteTask(task.id);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
