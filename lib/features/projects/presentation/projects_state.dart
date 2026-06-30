import '../domain/project_model.dart';

sealed class ProjectsScreenState {
  const ProjectsScreenState();

  R when<R>({
    required R Function() loading,
    required R Function(List<Project> projects, bool isProcessing, Project? curProject) loaded,
    required R Function(String message) error,
  }) {
    return switch (this) {
      ProjectsLoading() => loading(),
      ProjectsLoaded(projects: final projects, isProcessing: final isProcessing, curProject: final curProject) =>
        loaded(projects, isProcessing, curProject),
      ProjectsError(message: final message) => error(message),
    };
  }

  R? maybeWhen<R>({
    R Function()? loading,
    R Function(List<Project> projects, bool isProcessing, Project? curProject)? loaded,
    R Function(String message)? error,
    required R Function() orElse,
  }) {
    return switch (this) {
      ProjectsLoading() => loading?.call() ?? orElse(),
      ProjectsLoaded(projects: final projects, isProcessing: final isProcessing, curProject: final curProject) =>
        loaded?.call(projects, isProcessing, curProject) ?? orElse(),
      ProjectsError(message: final message) => error?.call(message) ?? orElse(),
    };
  }

  bool get isLoading => this is ProjectsLoading;
  bool get isLoaded => this is ProjectsLoaded;
  bool get isError => this is ProjectsError;
}

final class ProjectsLoading extends ProjectsScreenState {
  const ProjectsLoading();
}

final class ProjectsLoaded extends ProjectsScreenState {
  const ProjectsLoaded({
    required this.projects,
    this.isProcessing = false,
    this.curProject,
  });

  final List<Project> projects;
  final Project? curProject;
  final bool isProcessing;
}

final class ProjectsError extends ProjectsScreenState {
  const ProjectsError(this.message);

  final String message;
}
