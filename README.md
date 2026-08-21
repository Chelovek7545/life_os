# Life OS

A personal life management app built with Flutter. Life OS brings your tasks, projects, goals, habits, and life spheres together in one place — with a local-first architecture and no backend required.

## Features

- **Pulse** — a life graph dashboard that visualizes your current state across life spheres
- **Tasks** — fast task management with quick completion from anywhere in the app
- **Projects** — group related work into projects and track their progress
- **Resources** — a personal library of notes, links, and reference material
- **Goals & Habits** — long-term goals and daily habit tracking
- **Timer** — focused work sessions
- **Life Spheres** — organize everything by areas of your life
- **Dark theme** — carefully crafted dark UI with custom typography (Inter, Space Grotesk, JetBrains Mono)

### Graph view
Features
- Move, Collapse, Remove nodes

## Tech Stack

| Category | Technology |
|---|---|
| Framework | Flutter (Dart SDK ^3.12) |
| Database | [Drift](https://drift.simonbinder.eu/) (SQLite), local-first storage |
| Reactive | [rxdart](https://pub.dev/packages/rxdart) |
| Preferences | shared_preferences |
| Testing | flutter_test, mockito |

## Architecture

The project follows a **feature-first** structure with clear layer separation (`data` → `domain` → `presentation`) and a lightweight manual DI container.

```
lib/
├── core/               # Database, DI container, theme, UI primitives, utils
├── features/
│   ├── goals/
│   ├── habits/
│   ├── lifegraph/      # Pulse dashboard
│   ├── projects/
│   ├── resources/
│   ├── settings/
│   ├── spheres/
│   ├── tasks/
│   └── timer/
├── navigation/         # Route names & navigation setup
├── app.dart            # Root widget & theming
└── main_screen.dart    # Bottom navigation shell
```

Each feature is self-contained:

```
features/tasks/
├── data/           # Drift tables, DAOs, data sources
├── domain/         # Models & business logic
└── presentation/   # Screens, widgets, view models
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x (Dart ^3.12)
- An enabled platform target: `android`, `ios`, `windows`, `macos`, `linux`, or `web`

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd life_os

# Install dependencies
flutter pub get

# Run code generation (Drift database)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

## Testing

```bash
# Run all unit & widget tests
flutter test
```

## Roadmap

- [ ] Goals & habits deep integration with the Pulse screen
- [ ] Focus timer with session history
- [ ] Settings: themes, backups, data export
- [ ] Cloud sync (optional)

## License

All rights reserved. Not licensed for distribution without permission.
