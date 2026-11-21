# Life OS

A personal life management app built with Flutter. Life OS brings your tasks, projects, goals, habits, and life spheres together in one place — with a local-first architecture and no backend required.

## Features

- **Pulse** — a life graph dashboard that visualizes your current state across life spheres
- **Today** — a date-based dashboard composed of independent task, habit, and project panels
- **Tasks** — fast task management with quick completion from anywhere in the app
- **Projects** — group related work into projects and track their progress
- **Resources** — a personal library of notes, links, and reference material
- **Goals & Habits** — long-term goals and daily habit tracking
- **Timer** — focused work sessions
- **Life Spheres** — organize everything by areas of your life
- **Dark theme** — carefully crafted dark UI with custom typography (Inter, Space Grotesk, JetBrains Mono)

### Task drag and drop

Long-press a task and drag it to a highlighted day, time slot, status column,
parent task, or the Unscheduled panel. The destination determines what changes.
[Task drag-and-drop guide (Russian)](docs/task-drag-and-drop.md).

### Graph view

- Move/collapse business cards and edit them through registered module forms.
- Use text stickers or Markdown files, rename files inline, and select existing notes from Notes or Obsidian.
- Store sphere boards as Canvas in a vault or a local Pulse folder, with conflict copies and exports.
- [Full Graph/Pulse guide: features, settings, API and limitations](docs/lifegraph-plugin.md).
- [Canvas format and Obsidian integration](docs/obsidian-canvas.md).

## Tech Stack

| Category | Technology |
|---|---|
| Framework | Flutter (Dart SDK ^3.12) |
| Database | [Drift](https://drift.simonbinder.eu/) (SQLite), local-first storage |
| Reactive | [rxdart](https://pub.dev/packages/rxdart) |
| Preferences | shared_preferences |
| Testing | flutter_test, mockito |

## Architecture

The modular migration introduces a Pub workspace with shared contracts, pure Dart task/note/sphere/goal/project/habits APIs, spheres, goals, projects, habits, tasks, LifeGraph/Pulse and resources plugins with explicit storage and UI adapters, a reusable graph canvas and generic graph cards/forms, public task/habit/project panels and a composed Today plugin, optional Telegram/Obsidian plugins, registered screens/panels/actions/settings, and extensible graph contributions. See [the migration guide](docs/modular-architecture.md) for current boundaries, validation, and remaining steps.

### Application adapters

The Pub workspace owns public contracts and module logic. The application keeps storage and presentation adapters in `lib/features` and connects them in `lib/app`. Consumers import the public package entry points directly; retired paths are checked by architecture tests.

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

For example, task contracts and logic are separate from their application adapters:

```
packages/tasks_api/       # Models and query/command contracts
packages/tasks_plugin/    # Logic, graph contributions, public panels
lib/features/tasks/
├── data/                 # Drift adapters
└── presentation/         # Application screens, forms and visual adapters
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

### Build an Android APK with optional modules

Run the build from the repository root. Pass one `--dart-define=FLAG=true` or
`--dart-define=FLAG=false` per module you want to configure. Omitted flags use
the defaults below. Changing a flag requires a rebuild.

| Module | Build flag | Default |
| --- | --- | --- |
| Telegram bot | `ENABLE_TELEGRAM` | `true` |
| [Local device sync](docs/local-sync.md) | `ENABLE_SYNC` | `false` |
| [Obsidian integration](docs/obsidian-canvas.md) | `ENABLE_OBSIDIAN` | `true` |
| [Local MCP server](docs/agent-access.md) | `ENABLE_MCP` | `false` |
| [Local OpenVINO assistant](docs/local-assistant.md) | `ENABLE_ASSISTANT` | `false` |

```bash
# Default APK: Telegram and Obsidian enabled
flutter build apk --release

# Enable local sync and keep Telegram enabled
flutter build apk --release --dart-define=ENABLE_SYNC=true

# Enable local sync and disable Telegram
flutter build apk --release --dart-define=ENABLE_SYNC=true --dart-define=ENABLE_TELEGRAM=false
```

Each command writes to `build/app/outputs/flutter-apk/app-release.apk`.
To start the Telegram bot, enter its token and the allowed Telegram user IDs
in the app's Telegram settings, then press **TG**.

For Windows ↔ Android sync, enable `ENABLE_SYNC=true` in both builds. Build the
Windows app with `flutter build windows --release --dart-define=ENABLE_SYNC=true`,
then pair the devices from **Pulse → Локальная синхронизация → Настройки**. See the
[local sync setup guide](docs/local-sync.md#подключение-двух-устройств).

The MCP server and OpenVINO assistant have separate Windows runtime setup guides
linked in the table.

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

