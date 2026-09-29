Нет необходимости сразу делать полную индексацию vault

Вместо этого мы будем сначала грузить всю файловую иерархию, а при нажатии на конкретную заметку уже подгружать её контент

Структуры данных
- ObsidianNote

- ObsidianRepo
- ObsidianSyncService

Для графа
- GraphNotesRepository
- GraphPositionsRepository

### ObsidianSyncService
- Нужен чтобы синхронизировать ноды, по сути просто просматривает файл и дает возможность что то делать при его изменении
- Функции
    - startWatching(Function(String relativePath) onFileChanged) 
    - stopWatching()
- Его можно соединить с ObsidianRepo и при измении getNoteContent
- По сути нужен только в графе

### ObsidianNote
- modifiedAt, content, title, relativePath, absolutePath
- api
    - Future<String> readContent()
    - copyWith
- Через Note Напрямую можно читать контент заметки


### ObsidianRepository
- notes, isLoading, error
- Api
    - List<HierarchyNode> getHierarchyTree()
    - Future<String> getNoteContent(String absolutePath)
    - Future<void> scanVault(String vaultPath)
        - Заполняет notes
    - Future<void> updateNoteContent(String absolutePath, String newContent)
    - Future<ObsidianNote?> createNote(String vaultPath, String title, String content)
